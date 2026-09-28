import 'package:equatable/equatable.dart';

/// One Daily Square prompt — an invitation, never an obligation
/// (ARCHITECTURE.md §6c). The [shape] rotates so the ritual cannot
/// calcify into a fixed daily template.
class Prompt extends Equatable {
  const Prompt({
    required this.id,
    required this.shape,
    required this.body,
    required this.rotationIndex,
  });

  final String id;

  /// Shape of the ask: 'photo' | 'sentence' | 'sound' | 'desk' | ...
  /// Presentation maps it to icon/copy; the domain never imports Flutter.
  final String shape;

  /// The prompt's copy ('Show your desk right now.').
  final String body;

  /// Position in the rotation.
  final int rotationIndex;

  @override
  List<Object?> get props => [id, shape, body, rotationIndex];
}

/// The user's prompt preferences. Every field is user-owned — the app
/// never picks a schedule for the user (§6c rule 1) and never nags
/// (rule 5).
class PromptPreferences extends Equatable {
  const PromptPreferences({
    required this.userId,
    required this.windowHour,
    required this.optedIn,
    this.pausedUntil,
  });

  final String userId;

  /// Hour of day (0-23) the user's window opens.
  final int windowHour;

  /// Opt-in flag. Never default-on: the prompt is an opt-in feature.
  final bool optedIn;

  /// Pause-until timestamp; null = not paused. Pausing is one tap and
  /// carries no penalty (§6c rule 5).
  final DateTime? pausedUntil;

  bool get isPaused {
    final until = pausedUntil;
    return until != null && until.isAfter(DateTime.now());
  }

  PromptPreferences copyWith({
    int? windowHour,
    bool? optedIn,
    DateTime? pausedUntil,
    bool clearPause = false,
  }) =>
      PromptPreferences(
        userId: userId,
        windowHour: windowHour ?? this.windowHour,
        optedIn: optedIn ?? this.optedIn,
        pausedUntil: clearPause ? null : (pausedUntil ?? this.pausedUntil),
      );

  @override
  List<Object?> get props =>
      [userId, windowHour, optedIn, pausedUntil];
}
