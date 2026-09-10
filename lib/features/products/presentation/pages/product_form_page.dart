import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/permission.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/l10n/failure_messages.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/platform/impl/platform_providers.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/session/session_impl.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/quantity.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../categories/public.dart';
import '../../domain/entities/product.dart';
import '../../domain/validation/product_validation.dart';
import '../providers/product_providers.dart';
import '../util/product_thumbnail.dart';
import '../util/unit_label.dart';
import '../widgets/barcode_scan_action.dart';
import '../widgets/product_image_field.dart';

/// Create (`/products/new`) and edit (`/products/:id/edit`) a product.
///
/// Price and cost are editable only when creating: afterwards pricing (A3)
/// owns those columns so every change lands in `price_changes`.
class ProductFormPage extends ConsumerWidget {
  const ProductFormPage({super.key, this.productId, this.initialBarcode});

  final String? productId;
  final String? initialBarcode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = productId;
    if (id == null) {
      return _ProductForm(initialBarcode: initialBarcode);
    }
    final product = ref.watch(editableProductProvider(id));
    final image = ref.watch(productImageProvider(id));
    return switch (product) {
      AsyncError(:final error) => Scaffold(
          appBar: AppBar(title: Text(context.l10n.catalogue_editProductTitle)),
          body: ErrorView(
            error: error,
            onRetry: () => ref.invalidate(editableProductProvider(id)),
          ),
        ),
      AsyncData(:final value) => _ProductForm(existing: value, initialImage: image.value),
      _ => Scaffold(
          appBar: AppBar(title: Text(context.l10n.catalogue_editProductTitle)),
          body: const Center(child: CircularProgressIndicator()),
        ),
    };
  }
}

class _ProductForm extends ConsumerStatefulWidget {
  const _ProductForm({this.existing, this.initialBarcode, this.initialImage});

  final Product? existing;
  final String? initialBarcode;
  final Uint8List? initialImage;

  @override
  ConsumerState<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends ConsumerState<_ProductForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _nameAlt;
  late final TextEditingController _sku;
  late final TextEditingController _barcode;
  late final TextEditingController _cost;
  late final TextEditingController _price;

  late String? _categoryId = widget.existing?.categoryId;
  late ProductUnit _unit = widget.existing?.unit ?? ProductUnit.piece;
  late Uint8List? _image = widget.initialImage;
  bool _imageChanged = false;
  bool _busyImage = false;
  bool _saving = false;

  /// Errors reported by the repository (duplicate barcode / SKU), cleared as
  /// soon as the offending field is edited.
  final _serverErrors = <String, String>{};

  bool get _isNew => widget.existing == null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name = TextEditingController(text: existing?.name ?? '');
    _nameAlt = TextEditingController(text: existing?.nameAlt ?? '');
    _sku = TextEditingController(text: existing?.sku ?? '');
    _barcode = TextEditingController(text: existing?.barcode ?? widget.initialBarcode ?? '');
    _cost = TextEditingController(text: existing?.cost.toDecimalString() ?? '');
    _price = TextEditingController(text: existing?.price.toDecimalString() ?? '');
  }

  @override
  void dispose() {
    for (final c in [_name, _nameAlt, _sku, _barcode, _cost, _price]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _currency => ref.read(sessionControllerProvider).store?.currency ?? 'EGP';

  Future<void> _pickImage() async {
    setState(() => _busyImage = true);
    try {
      final picked = await ref.read(fileServiceProvider).pick(
        extensions: const ['jpg', 'jpeg', 'png', 'webp'],
      );
      if (picked == null) return;
      final thumb = await encodeProductThumbnail(picked.bytes);
      if (!mounted) return;
      if (thumb == null) {
        _showMessage(context.l10n.catalogue_photoFailed);
        return;
      }
      setState(() {
        _image = thumb;
        _imageChanged = true;
      });
    } finally {
      if (mounted) setState(() => _busyImage = false);
    }
  }

  Future<void> _scanBarcode() async {
    final code = await ref.read(scannerServiceProvider).scan(context);
    if (code == null || !mounted) return;
    setState(() {
      _barcode.text = code.trim();
      _serverErrors.remove('barcode');
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final draft = ProductDraft(
        categoryId: _categoryId,
        name: _name.text,
        nameAlt: _nameAlt.text,
        sku: _sku.text,
        barcode: _barcode.text,
        unit: _unit,
        cost: Money.tryParse(_cost.text, _currency) ?? Money.zero(_currency),
        price: Money.tryParse(_price.text, _currency) ??
            widget.existing?.price ??
            Money.zero(_currency),
      );

      final existing = widget.existing;
      final result = existing == null
          ? await ref.read(createProductProvider)(draft)
          : await ref.read(updateProductProvider)(existing.id, draft);

      if (result case Err(:final failure)) {
        if (!mounted) return;
        _applyFailure(failure);
        return;
      }

      final saved = result.valueOrNull!;
      if (_imageChanged) {
        await ref.read(setProductImageProvider)(saved.id, _image);
        ref.invalidate(productImageProvider(saved.id));
      }
      if (!mounted) return;
      _showMessage(_isNew ? context.l10n.catalogue_created : context.l10n.catalogue_saved);
      context.go(RoutePaths.productDetailFor(saved.id));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _applyFailure(Failure failure) {
    final l10n = context.l10n;
    switch (failure) {
      case ConflictFailure(field: 'barcode'):
        _serverErrors['barcode'] = l10n.catalogue_errorBarcodeTaken;
      case ConflictFailure(field: 'sku'):
        _serverErrors['sku'] = l10n.catalogue_errorSkuTaken;
      case ValidationFailure(:final field, :final code):
        _serverErrors[field] = _validationMessage(field, code);
      default:
        _showMessage(failureMessage(l10n, failure));
        return;
    }
    setState(() {});
    _formKey.currentState?.validate();
  }

  String _validationMessage(String field, String code) {
    final l10n = context.l10n;
    return switch ((field, code)) {
      ('name', 'required') => l10n.catalogue_errorNameRequired,
      ('name', 'too_long') => l10n.catalogue_errorNameTooLong,
      ('nameAlt', 'too_long') => l10n.catalogue_errorNameTooLong,
      ('sku', 'too_long') || ('barcode', 'too_long') => l10n.catalogue_errorCodeTooLong,
      ('price', _) => l10n.catalogue_errorPriceInvalid,
      ('cost', _) => l10n.catalogue_errorCostInvalid,
      _ => l10n.common_errorValidation,
    };
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final canEditPrices = ref.watch(sessionControllerProvider).can(Permission.editPrices);
    final existing = widget.existing;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? l10n.catalogue_newProductTitle : l10n.catalogue_editProductTitle),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(l10n.common_save),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            ProductImageField(
              bytes: _image,
              busy: _busyImage,
              onPick: _pickImage,
              onRemove: () => setState(() {
                _image = null;
                _imageChanged = true;
              }),
            ),
            const SizedBox(height: AppSpacing.xl),
            TextFormField(
              controller: _name,
              autofocus: _isNew,
              textInputAction: TextInputAction.next,
              maxLength: ProductValidation.maxNameLength,
              decoration: InputDecoration(labelText: l10n.catalogue_fieldName),
              onChanged: (_) => _clearError('name'),
              validator: (value) {
                final name = (value ?? '').trim();
                if (name.isEmpty) return l10n.catalogue_errorNameRequired;
                if (name.length > ProductValidation.maxNameLength) {
                  return l10n.catalogue_errorNameTooLong;
                }
                return _serverErrors['name'];
              },
            ),
            TextFormField(
              controller: _nameAlt,
              textInputAction: TextInputAction.next,
              maxLength: ProductValidation.maxNameLength,
              decoration: InputDecoration(labelText: l10n.catalogue_fieldNameAlt),
              onChanged: (_) => _clearError('nameAlt'),
              validator: (_) => _serverErrors['nameAlt'],
            ),
            const SizedBox(height: AppSpacing.sm),
            CategoryField(
              value: _categoryId,
              onChanged: (value) => setState(() => _categoryId = value),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _sku,
              textInputAction: TextInputAction.next,
              maxLength: ProductValidation.maxCodeLength,
              decoration: InputDecoration(labelText: l10n.catalogue_fieldSku),
              onChanged: (_) => _clearError('sku'),
              validator: (_) => _serverErrors['sku'],
            ),
            TextFormField(
              controller: _barcode,
              textInputAction: TextInputAction.next,
              maxLength: ProductValidation.maxCodeLength,
              decoration: InputDecoration(
                labelText: l10n.catalogue_fieldBarcode,
                suffixIcon: BarcodeScanAction(onPressed: _scanBarcode),
              ),
              onChanged: (_) => _clearError('barcode'),
              validator: (_) => _serverErrors['barcode'],
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<ProductUnit>(
              initialValue: _unit,
              decoration: InputDecoration(
                labelText: l10n.catalogue_fieldUnit,
                helperText: _unit.allowsDecimals ? l10n.catalogue_unitDecimalsHint : null,
              ),
              items: [
                for (final unit in ProductUnit.values)
                  DropdownMenuItem(value: unit, child: Text(unitLabel(context, unit))),
              ],
              onChanged: (value) => setState(() => _unit = value ?? ProductUnit.piece),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _cost,
              enabled: _isNew,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.catalogue_fieldCost,
                suffixText: _currency,
              ),
              onChanged: (_) => _clearError('cost'),
              validator: (value) {
                final text = (value ?? '').trim();
                if (text.isEmpty) return null;
                if (Money.tryParse(text, _currency) == null) {
                  return l10n.catalogue_errorCostInvalid;
                }
                return _serverErrors['cost'];
              },
            ),
            TextFormField(
              controller: _price,
              enabled: _isNew,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: l10n.catalogue_fieldPrice,
                suffixText: _currency,
                helperText: _isNew ? null : l10n.catalogue_priceLockedHint,
                helperMaxLines: 3,
              ),
              onChanged: (_) => _clearError('price'),
              validator: (value) {
                if (!_isNew) return null;
                final text = (value ?? '').trim();
                if (text.isEmpty) return l10n.catalogue_errorPriceRequired;
                if (Money.tryParse(text, _currency) == null) {
                  return l10n.catalogue_errorPriceInvalid;
                }
                return _serverErrors['price'];
              },
              onFieldSubmitted: (_) => _save(),
            ),
            if (!_isNew && canEditPrices && existing != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () => context.go(RoutePaths.priceEditFor(existing.id)),
                  icon: const Icon(Icons.sell_outlined, size: 18),
                  label: Text(l10n.catalogue_changePrice),
                ),
              ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(l10n.common_save),
            ),
          ],
        ),
      ),
    );
  }

  void _clearError(String field) {
    if (_serverErrors.remove(field) != null) setState(() {});
  }
}
