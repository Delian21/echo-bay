import 'package:flutter/material.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'injection.dart';
import 'core/motion/motion_controller.dart';
import 'core/motion/motion_scope.dart';
import 'core/notifications/prompt_notifier.dart';
import 'core/profile/profile_controller.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'core/timetravel/time_travel_scope.dart';

/// Duration + curve of the light/dark cross-fade on theme change.
const _themeTransitionDuration = Duration(milliseconds: 350);
const _themeTransitionCurve = Curves.easeOutCubic;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

class _SuperAppState extends State<SuperApp> {
  // Registered in configureDependencies; the fallback keeps standalone
  // widget tests that pump SuperApp without full DI from crashing.
  late final ThemeController _theme =
      sl.isRegistered<ThemeController>() ? sl<ThemeController>() : ThemeController();

  late final ProfileController _profile = sl.isRegistered<ProfileController>()
      ? sl<ProfileController>()
      : ProfileController();

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
    _theme.addListener(_onThemeChanged);
    // Accent changes ride the same cross-fade as mode changes — picking a
    // new accent fades the whole app instead of snapping.
    _profile.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _theme
      ..removeListener(_onThemeChanged)
      // Only dispose what this State owns — the DI singleton outlives tests
      // that pump SuperApp directly.
      ..disposeIfOwned(!sl.isRegistered<ThemeController>());
    // Same ownership rule for the motion controller.
    if (!sl.isRegistered<MotionController>()) _motion.dispose();
    if (!sl.isRegistered<ProfileController>()) _profile.dispose();
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
