import 'package:flutter/material.dart';

import '../../../core/design_system/hand_date.dart';
import '../../../core/design_system/sketch_kit.dart';
import '../../../core/theme/app_theme.dart';

/// The date mark written into the corner of a keepsake card, like the
/// imprint on the back of a passport photo.
///
/// Callers position it — the card body is clipped and must never reflow
/// when the stamp appears. Ink is pinned to charcoal because the card
/// is always cream paper, in both themes.
class KeepsakeStamp extends StatelessWidget {
  const KeepsakeStamp({super.key, required this.at});

  /// The moment being stamped: a post's own time, a note's pin time,
  /// or the pin time when the referenced moment can no longer resolve.
  final DateTime at;

  @override
  Widget build(BuildContext context) {
    return Text(
      handDateTime(at),
      style: kHandwrittenTextStyle.copyWith(
        fontSize: 12,
        color: SketchInk.charcoal.withValues(alpha: 0.65),
      ),
    );
  }
}
