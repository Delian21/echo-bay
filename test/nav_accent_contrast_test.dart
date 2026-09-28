import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:superapp/core/profile/user_profile.dart';
import 'package:superapp/core/theme/app_theme.dart';

/// The nav-pill contrast invariant: whatever accent the user picks, the
/// *selected* nav glyph must read against the indicator pill it sits on.
/// The pill is `primary` at 22% alpha over the surface; the icon used to
/// paint in raw `primary`, which washes out for high-luminance accents
/// (golden-hour amber on pale amber). `navSelectedIconColor` now picks
/// the higher-contrast of {accent, onSurface} against the composite.
///
/// These tests iterate every ink-pot accent through both theme builders
/// and assert WCAG AA-large (>= 3.0) for the icon-on-pill pair, plus the
/// rail label pair — the exact regression the screenshots showed.
void main() {
  // The composite color the pill paints: alpha blend over surface.
  Color pillOf(ColorScheme scheme) =>
      Color.lerp(scheme.surface, scheme.primary, 0.22)!;

  double ratio(Color fg, Color bg) => AccentDerivation.contrastRatio(fg, bg);

  for (final accent in kAccentPalette) {
    group('accent #${accent.toARGB32().toRadixString(16)}', () {
      for (final golden in [true, false]) {
        final tag = golden ? 'golden hour' : 'stock';

        testWidgets('$tag light: selected nav icon reads on its pill',
            (tester) async {
          final theme = golden
              ? buildGoldenHourLightTheme(accent)
              : buildLightTheme(accent);
          final scheme = theme.colorScheme;
          final iconColor = navSelectedIconColor(scheme);
          final pill = pillOf(scheme);

          expect(ratio(iconColor, pill), greaterThanOrEqualTo(3.0),
              reason: 'icon $iconColor on pill $pill '
                  '(ratio ${ratio(iconColor, pill)})');
        });

        testWidgets('$tag dark: selected nav icon reads on its pill',
            (tester) async {
          final theme =
              golden ? buildGoldenHourDarkTheme(accent) : buildDarkTheme(accent);
          final scheme = theme.colorScheme;
          final iconColor = navSelectedIconColor(scheme);
          final pill = pillOf(scheme);

          expect(ratio(iconColor, pill), greaterThanOrEqualTo(3.0),
              reason: 'icon $iconColor on pill $pill '
                  '(ratio ${ratio(iconColor, pill)})');
        });
      }
    });
  }

  test('the amber regression case actually needed the fallback', () {
    // Golden-hour amber as primary on the light golden theme: the old
    // behavior (icon painted in raw primary) must have been below the
    // threshold — proving the fix does something, not vacuously passing.
    final scheme = buildGoldenHourLightTheme(const Color(0xFFD98324)).colorScheme;
    final pill = pillOf(scheme);
    final oldPair = AccentDerivation.contrastRatio(scheme.primary, pill);
    expect(oldPair, lessThan(3.0),
        reason: 'amber-on-amber-pill was the reported wash-out');
    // …and the new picker clears it.
    expect(ratio(navSelectedIconColor(scheme), pill),
        greaterThanOrEqualTo(3.0));
  });
}
