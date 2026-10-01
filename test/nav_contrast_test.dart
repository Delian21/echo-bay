import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echo_bay/core/profile/user_profile.dart';
import 'package:echo_bay/core/theme/app_theme.dart';

/// #nav-contrast: the selected rail glyph's color comes from
/// [navSelectedIconColor], which picks the higher-contrast of
/// {accent, onSurface} against the indicator pill (primary @22% over
/// surface). The theme sets the rail's indicatorColor to exactly that
/// pill, so the picker's WCAG guarantee must hold for every accent in
/// the palette, in both brightnesses — the "dark-olive glyph on a
/// mustard pill" regression lives here.
void main() {
  const threshold = 3.0; // WCAG AA for large text / UI components.

  for (final brightness in Brightness.values) {
    group('selected rail glyph contrast (${brightness.name})', () {
      for (final accent in kAccentPalette) {
        test(accent.toARGB32().toRadixString(16), () {
          final scheme = (brightness == Brightness.light
                  ? buildLightTheme(accent)
                  : buildDarkTheme(accent))
              .colorScheme;

          // The composite color the glyph actually paints over: the
          // indicator blended onto the rail surface.
          final pill = Color.lerp(scheme.surface, scheme.primary, 0.22)!;

          final chosen = navSelectedIconColor(scheme);
          final ratio = AccentDerivation.contrastRatio(chosen, pill);
          expect(ratio, greaterThanOrEqualTo(threshold),
              reason: 'accent ${accent.toARGB32().toRadixString(16)} '
                  'on ${brightness.name}: picked '
                  '${chosen.toARGB32().toRadixString(16)} at $ratio:1');
        });
      }
    });
  }
}
