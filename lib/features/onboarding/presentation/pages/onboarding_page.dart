import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/brand/brand_config.dart';
import '../../../../core/brand/brand_providers.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/l10n/failure_messages.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/session/session_impl.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/brand_logo.dart';
import '../../../profiles/presentation/widgets/pin_entry.dart';
import '../../data/store_providers.dart';

enum _Step { store, owner, pin }

/// First run: store name, currency, language, owner name and PIN.
/// Creates the store, its default branch and the owner in one transaction.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _storeName = TextEditingController();
  final _ownerName = TextEditingController();

  _Step _step = _Step.store;
  String? _currency;
  String? _language;
  String? _firstPin;
  String? _storeNameError;
  String? _ownerNameError;
  String? _pinError;
  bool _busy = false;

  @override
  void dispose() {
    _storeName.dispose();
    _ownerName.dispose();
    super.dispose();
  }

  void _next() {
    final l10n = context.l10n;
    switch (_step) {
      case _Step.store:
        if (_storeName.text.trim().isEmpty) {
          setState(() => _storeNameError = l10n.onboarding_errorStoreName);
          return;
        }
        setState(() {
          _storeNameError = null;
          _step = _Step.owner;
        });
      case _Step.owner:
        if (_ownerName.text.trim().isEmpty) {
          setState(() => _ownerNameError = l10n.onboarding_errorOwnerName);
          return;
        }
        setState(() {
          _ownerNameError = null;
          _step = _Step.pin;
        });
      case _Step.pin:
        break;
    }
  }

  void _back() {
    setState(() {
      _pinError = null;
      _firstPin = null;
      _step = switch (_step) {
        _Step.pin => _Step.owner,
        _Step.owner => _Step.store,
        _Step.store => _Step.store,
      };
    });
  }

  void _onPin(String pin) {
    final first = _firstPin;
    if (first == null) {
      setState(() {
        _firstPin = pin;
        _pinError = null;
      });
      return;
    }
    if (first != pin) {
      setState(() {
        _firstPin = null;
        _pinError = context.l10n.onboarding_pinMismatch;
      });
      return;
    }
    unawaited(_submit(pin));
  }

  Future<void> _submit(String pin) async {
    final brand = ref.read(brandConfigProvider);
    setState(() {
      _busy = true;
      _pinError = null;
    });
    final result = await ref.read(createStoreProvider)(
      storeName: _storeName.text,
      currency: _currency ?? brand.defaultCurrency,
      locale: _language ?? brand.defaultLocale.languageCode,
      ownerName: _ownerName.text,
      pin: pin,
    );
    if (!mounted) return;
    switch (result) {
      case Success(:final value):
        ref.read(sessionControllerProvider.notifier).startSession(value);
      case Err(:final failure):
        setState(() {
          _busy = false;
          _firstPin = null;
          _pinError = _messageFor(failure);
        });
    }
  }

  String _messageFor(Failure failure) {
    final l10n = context.l10n;
    if (failure case ValidationFailure(:final field)) {
      return switch (field) {
        'storeName' => l10n.onboarding_errorStoreName,
        'ownerName' => l10n.onboarding_errorOwnerName,
        _ => l10n.onboarding_errorPin,
      };
    }
    return failureMessage(l10n, failure);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brand = ref.watch(brandConfigProvider);
    final restore = ref.watch(sessionRestoreProvider);

    if (restore.isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: AppSpacing.lg),
              Text(l10n.onboarding_preparing),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.onboarding_title),
        automaticallyImplyLeading: false,
        leading: _step == _Step.store
            ? null
            : IconButton(
                onPressed: _busy ? null : _back,
                icon: const BackButtonIcon(),
                tooltip: l10n.onboarding_back,
              ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: (_Step.values.indexOf(_step) + 1) / 3),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: switch (_step) {
                _Step.store => _storeStep(brand),
                _Step.owner => _ownerStep(),
                _Step.pin => _pinStep(),
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _storeStep(BrandConfig brand) {
    final l10n = context.l10n;
    final currencies = BrandConfig.supportedCurrencies.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: BrandLogo(size: 72)),
        const SizedBox(height: AppSpacing.lg),
        Text(
          l10n.onboarding_welcome(brand.appName),
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.onboarding_welcomeBody, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.xxl),
        TextField(
          controller: _storeName,
          autofocus: true,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: l10n.onboarding_storeName,
            hintText: l10n.onboarding_storeNameHint,
            errorText: _storeNameError,
          ),
          onChanged: (_) {
            if (_storeNameError != null) setState(() => _storeNameError = null);
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        DropdownButtonFormField<String>(
          initialValue: _currency ?? brand.defaultCurrency,
          decoration: InputDecoration(labelText: l10n.onboarding_currency),
          items: [
            for (final c in currencies) DropdownMenuItem(value: c, child: Text(c)),
          ],
          onChanged: (value) => setState(() => _currency = value),
        ),
        const SizedBox(height: AppSpacing.lg),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(l10n.onboarding_language, style: Theme.of(context).textTheme.labelLarge),
        ),
        const SizedBox(height: AppSpacing.sm),
        SegmentedButton<String>(
          segments: [
            for (final locale in brand.supportedLocales)
              ButtonSegment(
                value: locale.languageCode,
                label: Text(
                  locale.languageCode == 'ar'
                      ? l10n.common_languageArabic
                      : l10n.common_languageEnglish,
                ),
              ),
          ],
          selected: {_language ?? brand.defaultLocale.languageCode},
          onSelectionChanged: (s) => setState(() => _language = s.first),
        ),
        const SizedBox(height: AppSpacing.xxl),
        FilledButton(onPressed: _next, child: Text(l10n.onboarding_next)),
      ],
    );
  }

  Widget _ownerStep() {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.onboarding_stepOwner,
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.onboarding_ownerNote, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.xxl),
        TextField(
          controller: _ownerName,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: l10n.onboarding_ownerName,
            hintText: l10n.onboarding_ownerNameHint,
            errorText: _ownerNameError,
          ),
          onChanged: (_) {
            if (_ownerNameError != null) setState(() => _ownerNameError = null);
          },
          onSubmitted: (_) => _next(),
        ),
        const SizedBox(height: AppSpacing.xxl),
        FilledButton(onPressed: _next, child: Text(l10n.onboarding_next)),
      ],
    );
  }

  Widget _pinStep() {
    final l10n = context.l10n;
    if (_busy) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppSpacing.lg),
          Text(l10n.onboarding_preparing, textAlign: TextAlign.center),
        ],
      );
    }
    return Column(
      children: [
        Text(
          l10n.onboarding_stepPin,
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.onboarding_pinExplain, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.xl),
        PinEntry(
          label: _firstPin == null ? l10n.onboarding_stepPin : l10n.onboarding_pinRepeat,
          errorText: _pinError,
          onSubmit: _onPin,
        ),
      ],
    );
  }
}
