import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'core/pwa/install_prompt_service.dart';
import 'injection.dart';
import 'core/auth/auth_repository.dart';
import 'core/auth/auth_screens.dart' show showAuthGate;
import 'core/motion/motion_controller.dart';
import 'core/motion/motion_scope.dart';
import 'core/notifications/prompt_notifier.dart';
import 'core/onboarding/first_run.dart';
import 'core/profile/profile_controller.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'core/timetravel/time_travel_scope.dart';
import 'dart:async';
import 'core/auth/session.dart';
import 'core/version/version_banner.dart';
import 'core/version/version_checker.dart';

/// Duration + curve of the light/dark cross-fade on theme change.
const _themeTransitionDuration = Duration(milliseconds: 350);
const _themeTransitionCurve = Curves.easeOutCubic;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Web: capture Chrome's beforeinstallprompt for the in-app install card.
  if (kIsWeb && !Platform.isAndroid && true) {
    // kIsWeb implies browser; the redundant Platform guard keeps dart:io
    // out of native builds.
    InstallPromptService.instance.init();
  }
  // Composition root: database, datasources, repositories. Must complete
  // before the shell reads sl<FeedRepository>().
  await configureDependencies();
  // Notification tap → deep link (#8): the payload is a route path.
  LocalPromptNotifier.onNotificationTap = (NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && payload.startsWith('/')) {
      appRouter.go(payload);
    }
  };
  runApp(const SuperApp());
}

class SuperApp extends StatefulWidget {
  const SuperApp({super.key});

  @override
  State<SuperApp> createState() => _SuperAppState();
}

class _SuperAppState extends State<SuperApp> with WidgetsBindingObserver {
  // Registered in configureDependencies; the fallback keeps standalone
  // widget tests that pump SuperApp without full DI from crashing.
  late final ThemeController _theme =
      sl.isRegistered<ThemeController>() ? sl<ThemeController>() : ThemeController();

  late final ProfileController _profile = sl.isRegistered<ProfileController>()
      ? sl<ProfileController>()
      : ProfileController();

  StreamSubscription<Session?>? _authSub;
  bool _signedIn = false;

  /// Theme actually rendered. Changes swap the MaterialApp's key so the
  /// AnimatedSwitcher below cross-fades two fully-rendered trees by
  /// opacity alone — pure compositing, no per-frame ThemeData.lerp of the
  /// whole text/icon themes (the old setState-per-tick approach rebuilt
  /// and re-lerped everything every frame, which is where the jank came
  /// from). System mode resolves to concrete light/dark via platform
  /// brightness.
  late ThemeData _displayed = _resolveTheme(_theme.value, _profile.profile.accentColor);

  @override
  void initState() {
    super.initState();
    // Without this registration the didChangeMetrics/Brightness overrides
    // below never fire — the system reduce-motion setting would only be
    // picked up on rebuilds.
    WidgetsBinding.instance.addObserver(this);
    _theme.addListener(_onThemeChanged);
    // Accent changes ride the same cross-fade as mode changes — picking a
    // new accent fades the whole app instead of snapping.
    _profile.addListener(_onThemeChanged);
    // First-run onboarding: once per install (persisted flag); runs on
    // the first frame so the router's shell exists behind it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) FirstRun.runIfNeeded(context);
    });
    // Live auth gate: Close the book closes down to Open your
    // sketchbook immediately; signing back in drops the gate. The
    // stream re-emits after every auth transition.
    _authSub = sl.isRegistered<AuthRepository>()
        ? sl<AuthRepository>().watchCurrentUser().listen((session) {
            final signed = session?.email != null;
            if (signed == _signedIn) return;
            _signedIn = signed;
            if (!signed && mounted) {
              showAuthGate(context);
            }
          })
        : null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _theme
      ..removeListener(_onThemeChanged)
      // Only dispose what this State owns — the DI singleton outlives tests
      // that pump SuperApp directly.
      ..disposeIfOwned(!sl.isRegistered<ThemeController>());
    // Same ownership rule for the motion controller.
    if (!sl.isRegistered<MotionController>()) _motion.dispose();
    if (!sl.isRegistered<ProfileController>()) _profile.dispose();
    unawaited(_authSub?.cancel());
    super.dispose();
  }

  ThemeData _resolveTheme(ThemeMode mode, Color accent) {
    final platformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final useDark = switch (mode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system => platformBrightness == Brightness.dark,
    };
    // Golden Hour identity (docs/ART_DIRECTION.md): the LiS-inspired
    // analog layer is the app's default look. Stock builders remain in
    // app_theme.dart for A/B comparison and fallback.
    return useDark
        ? buildGoldenHourDarkTheme(accent)
        : buildGoldenHourLightTheme(accent);
  }

  void _onThemeChanged() {
    final target = _resolveTheme(_theme.value, _profile.profile.accentColor);
    if (identical(target, _displayed)) return;
    setState(() => _displayed = target);
  }

  // Registered in configureDependencies; fallback keeps standalone tests
  // that pump SuperApp without full DI working.
  late final MotionController _motion = sl.isRegistered<MotionController>()
      ? sl<MotionController>()
      : MotionController();

  // Time travel: one controller above the router; feature screens and
  // datasources read the as-of instant from here.
  final TimeTravelController _timeTravel = TimeTravelController();

  // Web-deploy watcher: a lazy fallback so standalone tests (no DI)
  // still mount, and so the checker only exists where it's useful.
  late final VersionChecker? _versionChecker =
      sl.isRegistered<VersionChecker>() ? sl<VersionChecker>() : null;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Back from another tab/app: the most common moment a deploy that
    // happened in the background is caught.
    if (state == AppLifecycleState.resumed) {
      _versionChecker?.onAppResumed();
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    _syncSystemMotion();
  }

  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    _syncSystemMotion();
  }

  /// The system reduce-motion accessibility setting joins the in-app
  /// toggle (OR): the app honors the OS even when the toggle is off.
  void _syncSystemMotion() {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    _motion.syncSystemReducedMotion(
        view.platformDispatcher.accessibilityFeatures.disableAnimations);
  }

  @override
  Widget build(BuildContext context) {
    // theme/darkTheme: _displayed carries the resolved mode; themeMode stays
    // fixed so MaterialApp never overrides it. The cross-fade is left to
    // MaterialApp's OWN AnimatedTheme: swapping `theme:` triggers a smooth
    // internal ThemeData lerp (themeAnimationDuration below). The previous
    // manual per-tick setState lerp fought that internal animation — two
    // lerps racing toward different targets each frame — which is exactly
    // the jank/stutter seen on theme switches. MotionScope sits above
    // MaterialApp so every motion widget reads the same preference.
    // System reduce-motion is synced before the first frame too.
    _syncSystemMotion();
    // Web-deploy watcher: first check + periodic poll.
    _versionChecker?.start();
    return MotionScope(
      controller: _motion,
      child: TimeTravelScope(
        controller: _timeTravel,
        child: MaterialApp.router(
          title: 'Echo Bay',
          debugShowCheckedModeBanner: false,
          theme: _displayed,
          themeMode: ThemeMode.light,
          themeAnimationDuration:
              _motion.reducedMotion ? Duration.zero : _themeTransitionDuration,
          themeAnimationCurve: _themeTransitionCurve,
          routerConfig: appRouter,
          builder: (context, child) => Stack(
            children: [
              if (child != null) child,
              // New deploy detected: quiet banner offering a refresh.
              const VersionBanner(),
            ],
          ),
        ),
      ),
    );
  }
}

extension on ThemeController {
  void disposeIfOwned(bool owned) {
    if (owned) dispose();
  }
}
