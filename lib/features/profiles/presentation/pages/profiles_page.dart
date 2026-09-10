import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/permission.dart';
import '../../../../core/brand/brand_providers.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/l10n/failure_messages.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/session/session_impl.dart';
import '../../../../core/session/session_reader.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/error_view.dart';
import '../../data/profile_providers.dart';
import '../../domain/usecases/manage_profiles.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/profile_form_sheet.dart';

/// Owner-only list of the store's profiles (`/settings/profiles`).
/// Profiles are deactivated, never deleted — stock movements reference them.
class ProfilesPage extends ConsumerWidget {
  const ProfilesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final profiles = ref.watch(allProfilesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profiles_manageTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.person_add_outlined),
        label: Text(l10n.profiles_addStaff),
      ),
      body: switch (profiles) {
        AsyncError(:final error) => ErrorView(
            error: error,
            onRetry: () => ref.invalidate(allProfilesProvider),
          ),
        AsyncData(:final value) => _List(profiles: value),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final result = await _showSheet(context, ref, mode: ProfileFormMode.create);
    if (result?.pin == null || !context.mounted) return;
    final outcome = await ref.read(createStaffProfileProvider)(
      name: result!.name ?? '',
      pin: result.pin!,
      locale: result.locale,
    );
    if (!context.mounted) return;
    _report(context, ref, outcome, context.l10n.profiles_savedAdded);
  }
}

class _List extends ConsumerWidget {
  const _List({required this.profiles});

  final List<Profile> profiles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final active = profiles.where((p) => p.isActive).toList();
    final inactive = profiles.where((p) => !p.isActive).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxxl * 2),
      children: [
        _SectionHeader(label: l10n.profiles_activeSection),
        for (final profile in active) _ProfileTile(profile: profile),
        if (inactive.isNotEmpty) ...[
          _SectionHeader(label: l10n.profiles_inactiveSection),
          for (final profile in inactive) _ProfileTile(profile: profile),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        child: Text(
          label,
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(color: Theme.of(context).colorScheme.primary),
        ),
      );
}

class _ProfileTile extends ConsumerWidget {
  const _ProfileTile({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isOwner = profile.role == Role.owner;
    final isCurrent = ref.watch(sessionControllerProvider).profile?.id == profile.id;

    return ListTile(
      leading: ProfileAvatar(profile: profile, radius: 20),
      title: Text(profile.name),
      subtitle: Text(roleLabel(l10n, profile.role)),
      trailing: PopupMenuButton<_Action>(
        onSelected: (action) => _run(context, ref, action),
        itemBuilder: (context) => [
          PopupMenuItem(value: _Action.edit, child: Text(l10n.common_edit)),
          PopupMenuItem(value: _Action.resetPin, child: Text(l10n.profiles_resetPin)),
          if (!isOwner)
            PopupMenuItem(
              value: profile.isActive ? _Action.deactivate : _Action.reactivate,
              child: Text(
                profile.isActive ? l10n.profiles_deactivate : l10n.profiles_reactivate,
              ),
            ),
        ],
      ),
      selected: isCurrent,
    );
  }

  Future<void> _run(BuildContext context, WidgetRef ref, _Action action) async {
    switch (action) {
      case _Action.edit:
        final result = await _showSheet(
          context,
          ref,
          mode: ProfileFormMode.edit,
          initialName: profile.name,
          initialLocale: profile.locale,
        );
        if (result == null || !context.mounted) return;
        final updated = profile.copyWith(
          name: result.name ?? profile.name,
          locale: result.locale,
        );
        final outcome = await ref.read(updateProfileProvider)(updated);
        if (!context.mounted) return;
        _applyToSession(ref, outcome);
        _report(context, ref, outcome, context.l10n.profiles_savedUpdated);

      case _Action.resetPin:
        final result = await _showSheet(context, ref, mode: ProfileFormMode.resetPin);
        if (result?.pin == null || !context.mounted) return;
        final outcome = await ref.read(resetPinProvider)(profile.id, result!.pin!);
        if (!context.mounted) return;
        _report(context, ref, outcome, context.l10n.profiles_savedPin);

      case _Action.deactivate:
        final l10n = context.l10n;
        final confirmed = await showConfirmDialog(
          context,
          title: l10n.profiles_deactivateTitle(profile.name),
          message: l10n.profiles_deactivateBody,
          confirmLabel: l10n.profiles_deactivate,
          destructive: true,
        );
        if (!confirmed || !context.mounted) return;
        final outcome = await ref.read(deactivateProfileProvider)(profile.id);
        if (!context.mounted) return;
        if (outcome.isSuccess) {
          ref
              .read(sessionControllerProvider.notifier)
              .applyProfile(profile.copyWith(isActive: false));
        }
        _report(context, ref, outcome, context.l10n.profiles_savedUpdated);

      case _Action.reactivate:
        final outcome =
            await ref.read(updateProfileProvider)(profile.copyWith(isActive: true));
        if (!context.mounted) return;
        _report(context, ref, outcome, context.l10n.profiles_savedUpdated);
    }
  }

  void _applyToSession(WidgetRef ref, Result<Profile> outcome) {
    if (outcome case Success(:final value)) {
      ref.read(sessionControllerProvider.notifier).applyProfile(value);
    }
  }
}

enum _Action { edit, resetPin, deactivate, reactivate }

Future<ProfileFormResult?> _showSheet(
  BuildContext context,
  WidgetRef ref, {
  required ProfileFormMode mode,
  String initialName = '',
  String? initialLocale,
}) =>
    showModalBottomSheet<ProfileFormResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ProfileFormSheet(
        mode: mode,
        brand: ref.read(brandConfigProvider),
        initialName: initialName,
        initialLocale: initialLocale,
      ),
    );

/// Shows [successMessage] or a translated failure. The staff limit gets its own
/// message with the upgrade hint (TECHNICAL_STRUCTURE §7).
void _report(BuildContext context, WidgetRef ref, Result<Object?> result, String successMessage) {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final text = switch (result) {
    Success() => successMessage,
    Err(:final failure) => switch (failure) {
        FeatureLockedFailure(feature: final f) when f == staffLimitFeature =>
          l10n.profiles_limitReached(ref.read(featureFlagsProvider).maxStaffProfiles ?? 0),
        ValidationFailure(code: 'owner_protected') => l10n.profiles_ownerProtected,
        ValidationFailure(field: 'name') => l10n.profiles_errorName,
        ValidationFailure(field: 'pin') => l10n.profiles_errorPin,
        _ => failureMessage(l10n, failure),
      },
  };
  messenger.showSnackBar(SnackBar(content: Text(text)));
}
