import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Semantic app-specific colors that do not map 1:1 onto Material roles.
///
/// A [ThemeExtension] — not static constants — so values resolve through
/// `Theme.of(context)` and lerp smoothly when the app switches between
/// light and dark. Access via [AppThemeExtension.of].
@immutable
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  const AppThemeExtension({
    required this.encrypted,
    required this.pending,
    required this.readAccent,
  });

  final Color encrypted;
  final Color pending;
  final Color readAccent;

  /// Resolve the themed tokens for [context]. Falls back to the light
  /// tokens when the ambient theme was built without extensions (bare
  /// MaterialApp in widget tests) instead of throwing.
  static AppThemeExtension of(BuildContext context) {
    final tokens = Theme.of(context).extension<AppThemeExtension>();
    if (tokens != null) return tokens;
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? AppColors._tokensDark
        : AppColors._tokensLight;
  }

  @override
  AppThemeExtension copyWith({
    Color? encrypted,
    Color? pending,
    Color? readAccent,
  }) =>
      AppThemeExtension(
        encrypted: encrypted ?? this.encrypted,
        pending: pending ?? this.pending,
        readAccent: readAccent ?? this.readAccent,
      );

  @override
  AppThemeExtension lerp(AppThemeExtension? other, double t) {
    if (other == null) return this;
    return AppThemeExtension(
      encrypted: Color.lerp(encrypted, other.encrypted, t)!,
      pending: Color.lerp(pending, other.pending, t)!,
      readAccent: Color.lerp(readAccent, other.readAccent, t)!,
    );
  }
}

/// "Golden Hour" decorative tokens — the LiS-inspired analog layer from
/// docs/ART_DIRECTION.md. Purely additive: features that ignore these
/// render identically to the stock theme.
@immutable
class GoldenHourExtension extends ThemeExtension<GoldenHourExtension> {
  const GoldenHourExtension({
    required this.enabled,
    required this.polaroidPaper,
    required this.polaroidShadow,
    required this.amberAccent,
  });

  /// Master switch for the analog content layer (polaroid framing,
  /// handwritten display voice, developing reveal). Off = stock look.
  final bool enabled;

  /// The white warm border of a polaroid frame.
  final Color polaroidPaper;

  /// Shadow a physical print casts on the desk beneath it.
  final Color polaroidShadow;

  /// Handwriting-marker amber for annotations/highlights.
  final Color amberAccent;

  static GoldenHourExtension of(BuildContext context) {
    final tokens = Theme.of(context).extension<GoldenHourExtension>();
    if (tokens != null) return tokens;
    // No extension in the tree (bare MaterialApp in widget tests):
    // the analog layer stays OFF — sketches, polaroids, and handwritten
    // headers are theme features, not defaults.
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? AppColors._goldenOffDark : AppColors._goldenOffLight;
  }

  @override
  GoldenHourExtension copyWith({
    bool? enabled,
    Color? polaroidPaper,
    Color? polaroidShadow,
    Color? amberAccent,
  }) =>
      GoldenHourExtension(
        enabled: enabled ?? this.enabled,
        polaroidPaper: polaroidPaper ?? this.polaroidPaper,
        polaroidShadow: polaroidShadow ?? this.polaroidShadow,
        amberAccent: amberAccent ?? this.amberAccent,
      );

  @override
  GoldenHourExtension lerp(GoldenHourExtension? other, double t) {
    if (other == null) return this;
    return GoldenHourExtension(
      enabled: t < 0.5 ? enabled : other.enabled,
      polaroidPaper: Color.lerp(polaroidPaper, other.polaroidPaper, t)!,
      polaroidShadow: Color.lerp(polaroidShadow, other.polaroidShadow, t)!,
      amberAccent: Color.lerp(amberAccent, other.amberAccent, t)!,
    );
  }
}

class AppColors {
  const AppColors._();

  static const dark = ColorScheme.dark(
    primary: Color(0xFF8AB4F8),
    onPrimary: Color(0xFF0A1428),
    secondary: Color(0xFF78D9A0),
    onSecondary: Color(0xFF062415),
    surface: Color(0xFF11151C),
    onSurface: Color(0xFFE4E9F0),
    surfaceContainerHighest: Color(0xFF1C2330),
    onSurfaceVariant: Color(0xFFA8B3C4),
    error: Color(0xFFF28B82),
    onError: Color(0xFF2C0B09),
    outline: Color(0xFF3A4557),
  );

  static const light = ColorScheme.light(
    primary: Color(0xFF2C5FDB),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFF1E7D4F),
    onSecondary: Color(0xFFFFFFFF),
    surface: Color(0xFFFBFBFD),
    onSurface: Color(0xFF171B22),
    surfaceContainerHighest: Color(0xFFE9EDF4),
    onSurfaceVariant: Color(0xFF5A6474),
    error: Color(0xFFB3261E),
    onError: Color(0xFFFFFFFF),
    outline: Color(0xFFC4CBD6),
  );

  static const _tokensDark = AppThemeExtension(
    encrypted: Color(0xFF78D9A0),
    pending: Color(0xFFA8B3C4),
    readAccent: Color(0xFF8AB4F8),
  );

  static const _tokensLight = AppThemeExtension(
    encrypted: Color(0xFF1E7D4F),
    pending: Color(0xFF5A6474),
    readAccent: Color(0xFF2C5FDB),
  );

  // -- Golden Hour variants (docs/ART_DIRECTION.md) -------------------------

  /// Light mode as afternoon sun on a warm desk: paper surface, pine-teal
  /// primary, amber highlight. Same contrast discipline as the stock
  /// light scheme — every role swapped, not tinted.
  static const goldenHourLight = ColorScheme.light(
    primary: Color(0xFF2E6D64), // pine teal
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFFB8860B), // dark goldenrod
    onSecondary: Color(0xFFFFFFFF),
    surface: Color(0xFFFAF6EE), // warm paper
    onSurface: Color(0xFF2B2A26), // warm ink
    surfaceContainerHighest: Color(0xFFEFE9DC),
    onSurfaceVariant: Color(0xFF6E6A5E),
    error: Color(0xFFB3261E),
    onError: Color(0xFFFFFFFF),
    outline: Color(0xFFD8D0BE),
  );

  /// Dark mode as dusk in the bay: deep blue-black, never gray.
  static const goldenHourDark = ColorScheme.dark(
    primary: Color(0xFF8FC7BC), // sea-glass teal
    onPrimary: Color(0xFF0E2320),
    secondary: Color(0xFFE3B34C), // lamp amber
    onSecondary: Color(0xFF2A1F04),
    surface: Color(0xFF10151E), // dusk blue-black
    onSurface: Color(0xFFE8E4D8), // warm chalk
    surfaceContainerHighest: Color(0xFF1B2230),
    onSurfaceVariant: Color(0xFFA6A294),
    error: Color(0xFFF28B82),
    onError: Color(0xFF2C0B09),
    outline: Color(0xFF37404F),
  );

  static const _tokensGoldenLight = AppThemeExtension(
    encrypted: Color(0xFF2E6D64),
    pending: Color(0xFF6E6A5E),
    readAccent: Color(0xFF2E6D64),
  );

  static const _tokensGoldenDark = AppThemeExtension(
    encrypted: Color(0xFF8FC7BC),
    pending: Color(0xFFA6A294),
    readAccent: Color(0xFF8FC7BC),
  );

  static const _goldenLight = GoldenHourExtension(
    enabled: true,
    polaroidPaper: Color(0xFFFDFBF5),
    polaroidShadow: Color(0x33806F4A),
    // DarkGoldenrod deepened from #B8860B: the original measured 2.8:1
    // against the warm paper — under WCAG AA for text. #805C08 keeps the
    // golden hue and reads 5.3:1+ on every light surface in use.
    amberAccent: Color(0xFF805C08),
  );

  static const _goldenDark = GoldenHourExtension(
    enabled: true,
    polaroidPaper: Color(0xFF232B38), // print frame stays darker in dusk
    polaroidShadow: Color(0x66000000),
    amberAccent: Color(0xFFE3B34C),
  );

  // Stock-theme variants: the extension is present (so `of` never throws
  // and features can probe `enabled`) but switched off — no polaroid
  // framing, no grain, no developing reveal.
  static const _goldenOffLight = GoldenHourExtension(
    enabled: false,
    polaroidPaper: Color(0xFFFFFFFF),
    polaroidShadow: Color(0x1A000000),
    amberAccent: Color(0xFFB8860B),
  );

  static const _goldenOffDark = GoldenHourExtension(
    enabled: false,
    polaroidPaper: Color(0xFF1C2330),
    polaroidShadow: Color(0x66000000),
    amberAccent: Color(0xFFE3B34C),
  );
}

ThemeData buildLightTheme([Color? accent]) =>
    _theme(_withAccent(AppColors.light, accent), AppColors._tokensLight,
        AppColors._goldenOffLight);

ThemeData buildDarkTheme([Color? accent]) =>
    _theme(_withAccent(AppColors.dark, accent), AppColors._tokensDark,
        AppColors._goldenOffDark);

/// Golden Hour variants — the LiS-inspired analog identity.
/// Same builder, different palette + the [GoldenHourExtension] with
/// [GoldenHourExtension.enabled] true. Accent selection flows through
/// the same [AccentDerivation] math, so user accents keep working.
ThemeData buildGoldenHourLightTheme([Color? accent]) => _theme(
    _withAccent(AppColors.goldenHourLight, accent),
    AppColors._tokensGoldenLight,
    AppColors._goldenLight);

ThemeData buildGoldenHourDarkTheme([Color? accent]) => _theme(
    _withAccent(AppColors.goldenHourDark, accent),
    AppColors._tokensGoldenDark,
    AppColors._goldenDark);

/// The selected nav-glyph color: the accent only when the accent
/// actually reads against its own indicator pill, otherwise the surface
/// foreground. Some ink-pot accents (golden-hour amber especially) are
/// too close in luminance to their own 22%-alpha pill — amber icon on
/// pale-amber pill washes out. This picks per-accent, per-brightness:
/// the higher-WCAG-contrast of {accent, onSurface} against the pill's
/// *composite* color (pill blended over surface), so dark teal keeps
/// its accent identity while amber falls back to warm ink.
Color navSelectedIconColor(ColorScheme scheme, {double indicatorAlpha = 0.22}) {
  final pill = Color.lerp(scheme.surface, scheme.primary, indicatorAlpha)!;
  return AccentDerivation.higherContrast(
      pill, scheme.primary, scheme.onSurface);
}

/// Replaces the primary role with the user's accent and derives its
/// container colors with contrast-correct math (see [AccentDerivation]).
ColorScheme _withAccent(ColorScheme scheme, Color? accent) {
  if (accent == null) return scheme;
  final d = AccentDerivation.of(accent, scheme.brightness);
  return scheme.copyWith(
    primary: accent,
    onPrimary: d.onPrimary,
    primaryContainer: d.container,
    onPrimaryContainer: d.onContainer,
  );
}

/// Derives the primary-container family for an arbitrary accent color.
///
/// Strategy (WCAG-backed, no HCT dependency):
///  1. Container = the accent's hue at a lightness near the surface —
///     high-lightness tint in light mode, low-lightness shade in dark —
///     so it reads as a soft wash of the accent, not a solid block.
///  2. onContainer = the same hue pushed to the opposite lightness
///     extreme, then verified against the container with the WCAG
///     contrast ratio; the darker/lighter of two candidates wins.
///  3. onPrimary = white or near-black, whichever contrasts harder
///     against the accent itself (crucial for yellow/orange accents).
///
/// Exposed for feature UI (avatar backgrounds, chips) so custom accents
/// render with the same guaranteed contrast as the theme's own widgets.
class AccentDerivation {
  AccentDerivation._(this.primary, this.onPrimary, this.container,
      this.onContainer);

  factory AccentDerivation.of(Color accent, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final hsl = HSLColor.fromColor(accent);
    final onSurfaceFallback =
        isDark ? const Color(0xFFE4E9F0) : const Color(0xFF171B22);

    // Container: accent hue pulled toward the surface's lightness extreme.
    var containerHsl = isDark
        ? hsl.withLightness(hsl.lightness.clamp(0.22, 0.38).toDouble())
        : hsl.withLightness((hsl.lightness + 0.38).clamp(0.0, 0.90))
            .withSaturation(
                (hsl.saturation * 0.85).clamp(0.0, 1.0).toDouble());

    // onContainer: same-hue candidate vs the scheme's onSurface — the
    // higher WCAG contrast ratio wins.
    Color onContainerFor(Color container) {
      final sameHue = (isDark
              ? hsl.withLightness(0.88)
              : hsl.withLightness(
                      (hsl.lightness - 0.45).clamp(0.0, 0.30))
                  .withSaturation((hsl.saturation * 1.15)
                      .clamp(0.0, 1.0)
                      .toDouble()))
          .toColor();
      return _higherContrast(container, sameHue, onSurfaceFallback);
    }

    var container = containerHsl.toColor();
    var onContainer = onContainerFor(container);

    // Hue-lightness math is not perceptual: yellow-family hues keep high
    // relative luminance even at low HSL lightness, so the first cut can
    // miss AA-large (3.0). Walk the container lightness away from the
    // chosen foreground until the pair passes or the range is exhausted.
    const minRatio = 3.0;
    final step = isDark ? -0.03 : 0.03;
    var guard = 0;
    while (AccentDerivation.contrastRatio(onContainer, container) <
            minRatio &&
        guard++ < 24) {
      final newL =
          (containerHsl.lightness + step).clamp(0.0, 1.0).toDouble();
      if (newL == containerHsl.lightness) break;
      containerHsl = containerHsl.withLightness(newL);
      container = containerHsl.toColor();
      onContainer = onContainerFor(container);
    }

    // onPrimary: white vs near-black against the accent itself.
    final onPrimary = _higherContrast(
        accent, const Color(0xFFFFFFFF), const Color(0xFF14181F));

    return AccentDerivation._(accent, onPrimary, container, onContainer);
  }

  final Color primary;
  final Color onPrimary;
  final Color container;
  final Color onContainer;

  /// Feature-UI entry point: derive the accent's container family for
  /// widgets outside the theme (avatars, chips, badges).
  static AccentDerivation derive(Color accent, Brightness brightness) =>
      AccentDerivation.of(accent, brightness);

  /// Contrast ratio of [fg] on [bg] per WCAG 2.1 (1.0 – 21.0).
  static double contrastRatio(Color fg, Color bg) {
    final lf = fg.computeLuminance();
    final lb = bg.computeLuminance();
    final lighter = math.max(lf, lb);
    final darker = math.min(lf, lb);
    return (lighter + 0.05) / (darker + 0.05);
  }

  static Color _higherContrast(Color bg, Color a, Color b) =>
      contrastRatio(a, bg) >= contrastRatio(b, bg) ? a : b;

  /// Public wrapper for feature UI picking between two foregrounds on
  /// one background (nav pills, custom chips).
  static Color higherContrast(Color bg, Color a, Color b) =>
      _higherContrast(bg, a, b);
}

/// Module-title voice: the AppBar [Text] inherits this via
/// `appBarTheme.titleTextStyle`; never hardcode a title style in features.
const TextStyle kDisplayTextStyle = TextStyle(
  fontSize: 18,
  fontWeight: FontWeight.w800,
  letterSpacing: -0.5,
);

/// Golden Hour handwriting voice (Caveat, OFL) — the analog layer's
/// display face for prompt headers and journal-style annotations.
/// Sized up relative to Roboto: handwriting runs visually small.
const TextStyle kHandwrittenTextStyle = TextStyle(
  fontFamily: 'Caveat',
  fontSize: 22,
  fontWeight: FontWeight.w600,
  letterSpacing: 0.2,
  height: 1.1,
);

ThemeData _theme(
  ColorScheme scheme,
  AppThemeExtension tokens,
  GoldenHourExtension goldenHour,
) {
  final isDark = scheme.brightness == Brightness.dark;

  // Golden Hour display voice: module titles render in the handwriting
  // face when the analog layer is on (Square/Vault/Nexus/Calls app bars,
  // prompt headers). Stock theme keeps Roboto everywhere.
  final displayStyle = goldenHour.enabled
      ? kHandwrittenTextStyle.copyWith(color: scheme.onSurface)
      : kDisplayTextStyle.copyWith(color: scheme.onSurface);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    extensions: [tokens, goldenHour],

    // Page transitions: vertical fade-through everywhere. The default
    // horizontal slide makes edge swipes look like a page stack that
    // swipe-back can unwind — on web that gesture exits the site, so the
    // horizontal vocabulary actively invited the accident.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
      },
    ),

    // Typography: single family, fixed scale. No dynamic font surprises.
    // `displaySmall` carries the module-title voice — same definition as
    // [kDisplayTextStyle], themed.
    fontFamily: 'Roboto',
    textTheme: TextTheme(
      displaySmall: displayStyle,
      headlineSmall: TextStyle(
          fontSize: 24, fontWeight: FontWeight.w600, color: scheme.onSurface),
      titleMedium: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w600, color: scheme.onSurface),
      bodyMedium: TextStyle(
          fontSize: 15, height: 1.35, color: scheme.onSurface),
      bodySmall: TextStyle(
          fontSize: 13, color: scheme.onSurfaceVariant),
      labelSmall: TextStyle(
          fontSize: 11, letterSpacing: 0.4, color: scheme.onSurfaceVariant),
    ),

    // Cards: flat, hairline border instead of elevation — cheaper to render
    // in scrolling lists than elevation shadows.
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.35)),
      ),
      margin: EdgeInsets.zero,
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: displayStyle,
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      // Pill must read on dark surface — the M3 default 14% alpha was
      // effectively invisible (the "invisible pill" bug).
      indicatorColor: scheme.primary.withValues(alpha: 0.22),
      elevation: 0,
      labelTextStyle: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface)
              : TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant)),
    ),

    dividerTheme: DividerThemeData(
      color: scheme.outline.withValues(alpha: 0.3),
      thickness: 0.6,
      space: 0.6,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    ),

    splashFactory: InkSparkle.splashFactory,
    visualDensity: VisualDensity.standard,
    platform: isDark ? TargetPlatform.android : TargetPlatform.iOS,

    // Golden Hour, Inked: soften the remaining stock controls. Switches
    // draw square-ish (a chalk tick, not a pill) and keep the amber/
    // accent thumb legible on both surfaces; segmented buttons drop the
    // heavy M3 outline for a hairline, with the selected segment tinted
    // like a marker highlight. Gated on the analog layer so the stock
    // theme stays untouched for A/B comparison.
    switchTheme: goldenHour.enabled
        ? SwitchThemeData(
            thumbColor: WidgetStateProperty.resolveWith((states) => states
                    .contains(WidgetState.selected)
                ? scheme.onPrimary
                : scheme.onSurfaceVariant),
            trackColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.selected)
                    ? scheme.primary
                    : scheme.surfaceContainerHighest),
            trackOutlineColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.selected)
                    ? Colors.transparent
                    : scheme.outline.withValues(alpha: 0.4)),
          )
        : null,
    // The rail's M3 default indicator is secondaryContainer — but
    // navSelectedIconColor computes contrast against primary@22% over
    // surface. Align the pill with the picker's assumption so the
    // selected glyph is always the readable option (white in dark
    // themes, ink in light ones).
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primary.withValues(alpha: 0.22),
    ),
    segmentedButtonTheme: goldenHour.enabled
        ? SegmentedButtonThemeData(
            style: ButtonStyle(
              side: WidgetStatePropertyAll(
                BorderSide(color: scheme.outline.withValues(alpha: 0.4)),
              ),
              // The switch is UI chrome with the handwritten voice —
              // Caveat runs visually small, so size it up a touch.
              textStyle: WidgetStatePropertyAll(
                kHandwrittenTextStyle.copyWith(
                  fontSize: 17,
                  color: scheme.onSurface,
                ),
              ),
              backgroundColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.selected)
                      ? scheme.primary.withValues(alpha: 0.18)
                      : Colors.transparent),
              foregroundColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.selected)
                      ? scheme.onSurface
                      : scheme.onSurfaceVariant),
              overlayColor:
                  WidgetStatePropertyAll(scheme.primary.withValues(alpha: 0.08)),
              shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              )),
            ),
          )
        : null,

    // Golden Hour, Inked surfaces: dialogs and bottom sheets render as
    // warm paper notes (sepia-tinted surface, hairline ink border, no
    // M3 elevation gloss); snackbars become small ink-stamped slips.
    // Gated on the analog layer like every other theme softening.
    dialogTheme: goldenHour.enabled
        ? DialogThemeData(
            backgroundColor: scheme.surface,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: scheme.outline.withValues(alpha: 0.45)),
            ),
            titleTextStyle: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          )
        : null,
    bottomSheetTheme: goldenHour.enabled
        ? const BottomSheetThemeData(
            elevation: 0,
            showDragHandle: true,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
          )
        : null,
    snackBarTheme: goldenHour.enabled
        ? SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
            elevation: 0,
            backgroundColor: isDark
                ? scheme.surfaceContainerHighest
                : const Color(0xFF2B2A26), // SketchInk.charcoal
            contentTextStyle: TextStyle(
              fontSize: 13.5,
              color: isDark ? scheme.onSurface : const Color(0xFFE8E4D8),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: isDark
                    ? scheme.outline.withValues(alpha: 0.5)
                    : Colors.transparent,
              ),
            ),
          )
        : null,
  );
}
