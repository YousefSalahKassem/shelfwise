// // OWNER: A4. Public surface of the alerts feature.
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';

// import '../stock/public.dart';

// /// Wraps a nav icon with the open-alert count.
// class AlertBadge extends ConsumerWidget {
//   const AlertBadge({super.key, required this.child});
//   final Widget child;

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final count = ref.watch(openAlertCountProvider).value ?? 0;
//     return Badge.count(count: count, isLabelVisible: count > 0, child: child);
//   }
// }
