import 'package:freezed_annotation/freezed_annotation.dart';

part 'branch.freezed.dart';

@freezed
abstract class Branch with _$Branch {
  const factory Branch({
    required String id,
    required String storeId,
    required String name,
    @Default(false) bool isDefault,
  }) = _Branch;
}
