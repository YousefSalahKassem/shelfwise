import 'package:freezed_annotation/freezed_annotation.dart';

part 'store.freezed.dart';

@freezed
abstract class Store with _$Store {
  const factory Store({
    required String id,
    required String name,
    /// ISO 4217, e.g. EGP / SAR.
    required String currency,
    /// Language code, e.g. `ar`.
    required String locale,
  }) = _Store;
}
