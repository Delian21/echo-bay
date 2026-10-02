import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Pushes a full-screen destination.
///
/// Under a [GoRouter] (the real app) the push goes through the router, so
/// the address bar and browser history follow the destination and a deep
/// link to the same path lands on the same screen. Standalone widget
/// tests mount a bare `MaterialApp` with no router above them — there the
/// helper falls back to a plain [Navigator] push, so feature widgets stay
/// testable without wiring a router into every test.
///
/// The returned future completes when the destination is popped, exactly
/// like `Navigator.push`.
///
/// [extra] rides along with the router push only — it reaches the route's
/// builder as `state.extra` and is absent after a reload or a cold deep
/// link. Use it to hand the destination something the URL cannot carry
/// verbatim (e.g. the exact display name behind a slug).
Future<void> pushDestination(
  BuildContext context,
  String location, {
  required Widget Function() fallback,
  Object? extra,
}) async {
  final router = GoRouter.maybeOf(context);
  if (router != null) {
    await router.push(location, extra: extra);
    return;
  }
  await Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => fallback()),
  );
}
