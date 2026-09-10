import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Leaves a pricing screen: back if there is somewhere to go back to,
/// otherwise to [fallback]. Works in widget tests, where there is no router.
void leaveScreen(BuildContext context, String fallback) {
  final router = GoRouter.maybeOf(context);
  if (router == null) {
    Navigator.of(context).maybePop();
    return;
  }
  if (router.canPop()) {
    router.pop();
  } else {
    router.go(fallback);
  }
}
