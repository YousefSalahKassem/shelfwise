import 'package:freezed_annotation/freezed_annotation.dart';

import '../../auth/permission.dart';

part 'profile.freezed.dart';

/// A person using the store device (owner or staff). PIN hashes never leave
/// the data layer, so they are not part of the entity.
@freezed
abstract class Profile with _$Profile {
  const factory Profile({
    required String id,
    required String storeId,
    required String name,
    required Role role,
    String? locale,
    @Default(true) bool isActive,
  }) = _Profile;
}
