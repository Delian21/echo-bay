import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/landing/ui/landing_page.dart';
import '../../features/square/ui/square_navigation_shell.dart';
import '../../injection.dart';
import '../auth/auth_repository.dart';
import '../auth/session.dart';
import '../settings/app_settings_store.dart';
import 'guest_mode.dart';

/// Whether "/" should show the landing page. Two facts decide it, and
/// neither depends on the widget tree: has a cover ever been signed on
/// this device, and is it browsing as a guest. Split out so the rule can
/// be read (and tested) without booting the whole app around it.
bool showsLandingPage({
  required bool hasCoverBeenSigned,
  required bool guestMode,
}) =>
    !hasCoverBeenSigned && !guestMode;

/// What "/" shows. The town square for anyone who already has a sketchbook
/// here (or is browsing as a guest), the front porch for everyone else.
///
/// "Already has a sketchbook" means [AuthRepository.hasCoverBeenSigned] —
/// a flag written once at sign-up that survives sign-out, so a returning
/// member who closed the book still lands inside, on the gate they expect.
/// Guest mode is the second way in: a guest has a profile and a feed, so
/// the landing page would only be in the way.
///
/// Nothing else moves: deep links still go straight to their routes, the
/// intro flow and auth gate still run from the app root, and signing out
/// still drops to Open your sketchbook.
class LaunchGate extends StatefulWidget {
  const LaunchGate({super.key});

  @override
  State<LaunchGate> createState() => _LaunchGateState();
}

class _LaunchGateState extends State<LaunchGate> {
  bool _decided = false;
  bool _landing = false;
  StreamSubscription<Session?>? _authSub;

  @override
  void initState() {
    super.initState();
    _decide();
    // Signing the cover from the landing page flips the gate live; the
    // subscription means the landing never lingers behind a signed session.
    if (sl.isRegistered<AuthRepository>()) {
      _authSub = sl<AuthRepository>().watchCurrentUser().listen((session) {
        if (!mounted) return;
        if (session?.email != null && _landing) {
          setState(() => _landing = false);
        }
      });
    }
  }

  Future<void> _decide() async {
    var landing = false;
    try {
      final hasCover = sl.isRegistered<AuthRepository>()
          ? await sl<AuthRepository>().hasCoverBeenSigned()
          : false;
      final isGuest = sl.isRegistered<AppSettingsStore>()
          ? await GuestMode.isActive(sl<AppSettingsStore>())
          : false;
      landing = showsLandingPage(
        hasCoverBeenSigned: hasCover,
        guestMode: isGuest,
      );
    } on Object {
      // A storage hiccup must not brick the app: fall through to the feed,
      // which is exactly what the app did before the landing page existed.
      landing = false;
    }
    if (!mounted) return;
    setState(() {
      _landing = landing;
      _decided = true;
    });
  }

  @override
  void dispose() {
    unawaited(_authSub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_decided) {
      // One read from the settings table; the paper background keeps the
      // flash invisible when the decision lands in the same frame.
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_landing) {
      return LandingPage(
        onEntered: () => setState(() => _landing = false),
      );
    }
    return const SquareNavigationShell();
  }
}
