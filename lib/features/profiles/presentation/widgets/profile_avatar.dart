import 'package:flutter/material.dart';

import '../../../../core/auth/permission.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/session/session_reader.dart';

/// Circle with the profile's initial. Owner and staff are told apart by colour
/// as well as by the role label, so it works without colour perception too.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.profile, this.radius = 28});

  final Profile profile;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final owner = profile.role == Role.owner;
    final background = profile.isActive
        ? (owner ? scheme.primaryContainer : scheme.secondaryContainer)
        : scheme.surfaceContainerHighest;
    final foreground = profile.isActive
        ? (owner ? scheme.onPrimaryContainer : scheme.onSecondaryContainer)
        : scheme.onSurfaceVariant;
    final initial = profile.name.trim().isEmpty
        ? '?'
        : String.fromCharCode(profile.name.trim().runes.first).toUpperCase();

    return CircleAvatar(
      radius: radius,
      backgroundColor: background,
      child: Text(
        initial,
        style: TextStyle(fontSize: radius * 0.8, color: foreground, fontWeight: FontWeight.w600),
      ),
    );
  }
}

String roleLabel(AppLocalizations l10n, Role role) =>
    role == Role.owner ? l10n.profiles_roleOwner : l10n.profiles_roleStaff;
