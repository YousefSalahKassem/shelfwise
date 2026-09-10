import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/l10n/failure_messages.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/session/session_impl.dart';
import '../../../../core/session/session_reader.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/brand_logo.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../data/profile_providers.dart';
import '../../domain/value_objects/pin.dart';
import '../widgets/pin_entry.dart';
import '../widgets/profile_avatar.dart';

/// Choose a profile and enter its PIN. Shown on every start and whenever the
/// app locks itself.
class LockPage extends ConsumerStatefulWidget {
  const LockPage({super.key});

  @override
  ConsumerState<LockPage> createState() => _LockPageState();
}

class _LockPageState extends ConsumerState<LockPage> {
  Profile? _selected;
  String? _error;
  int _cooldown = 0;
  Timer? _ticker;
  bool _busy = false;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _select(Profile profile) {
    setState(() {
      _selected = profile;
      _error = null;
      _cooldown = ref.read(unlockProfileProvider).cooldownSeconds(profile.id) ?? 0;
    });
    if (_cooldown > 0) _tick();
  }

  void _tick() {
    _ticker?.cancel();
    _ticker = Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      final profile = _selected;
      final left = profile == null
          ? 0
          : ref.read(unlockProfileProvider).cooldownSeconds(profile.id) ?? 0;
      setState(() {
        _cooldown = left;
        if (left == 0) _error = null;
      });
      if (left > 0) _tick();
    });
  }

  Future<void> _submit(String pin) async {
    final profile = _selected;
    if (profile == null || _busy) return;
    final session = ref.read(sessionControllerProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref.read(unlockProfileProvider)(
      profile.id,
      pin,
      switching: session.profile != null,
    );
    if (!mounted) return;
    switch (result) {
      case Success(:final value):
        setState(() => _busy = false);
        ref.read(sessionControllerProvider.notifier).unlock(value);
      case Err(:final failure):
        final left = ref.read(unlockProfileProvider).cooldownSeconds(profile.id) ?? 0;
        setState(() {
          _busy = false;
          _cooldown = left;
          _error = _messageFor(failure, left);
        });
        if (left > 0) _tick();
    }
  }

  String _messageFor(Failure failure, int cooldown) {
    final l10n = context.l10n;
    if (failure case ValidationFailure(:final code)) {
      if (code == PinFailureCodes.lockedOut || cooldown > 0) {
        return l10n.profiles_lockedOut(cooldown);
      }
      return l10n.profiles_wrongPin;
    }
    return failureMessage(l10n, failure);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final profiles = ref.watch(allProfilesProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: switch (profiles) {
              AsyncError(:final error) => ErrorView(
                  error: error,
                  onRetry: () => ref.invalidate(allProfilesProvider),
                ),
              AsyncData(:final value) => _content(value.where((p) => p.isActive).toList()),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
        ),
      ),
      floatingActionButton: _selected == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _busy ? null : () => setState(() => _selected = null),
              icon: const BackButtonIcon(),
              label: Text(l10n.profiles_lockTitle),
            ),
    );
  }

  Widget _content(List<Profile> active) {
    final l10n = context.l10n;
    if (active.isEmpty) {
      return EmptyState(icon: Icons.lock_outline, title: l10n.profiles_noneActive);
    }
    final selected = _selected;
    if (selected != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            ProfileAvatar(profile: selected, radius: 36),
            const SizedBox(height: AppSpacing.lg),
            Text(selected.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xl),
            PinEntry(
              label: l10n.profiles_unlockTitle(selected.name),
              errorText: _error,
              enabled: !_busy && _cooldown == 0,
              onSubmit: (pin) => unawaited(_submit(pin)),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          const BrandLogo(size: 64),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.profiles_lockTitle,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xxl),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.lg,
            children: [
              for (final profile in active)
                SizedBox(
                  width: 120,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    onTap: () => _select(profile),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        children: [
                          ProfileAvatar(profile: profile),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            profile.name,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Text(
                            roleLabel(l10n, profile.role),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
