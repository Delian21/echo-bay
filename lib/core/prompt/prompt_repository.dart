import 'package:fpdart/fpdart.dart';

import '../error/failures.dart';
import 'prompt.dart';

/// Contract for the Daily Square prompt (§6c). Every method here is
/// shaped by the anti-chore rules: nothing can pressure, count, or gate.
///
/// Sync note: prompts are content the (future) server curates, so the
/// table is a cache; prefs and actions are the local user's own writes.
abstract class PromptRepository {
  /// The prompt currently in the user's window, if any. Null when the
  /// user opted out, paused, already acted on today's prompt, or is
  /// outside their chosen window — all four are *successes*, not errors
  /// (an empty prompt state is a normal, healthy state).
  Future<Either<Failure, Prompt?>> activePrompt();

  /// The user's prompt preferences (window, opt-in, pause).
  Future<Either<Failure, PromptPreferences>> preferences();

  /// Update preferences (window hour, opt-in, pause).
  Future<Either<Failure, PromptPreferences>> updatePreferences(
      PromptPreferences prefs);

  /// Pause the prompt until [until]. One tap, no penalty (§6c rule 5).
  Future<Either<Failure, PromptPreferences>> pauseUntil(DateTime until);

  /// Resume (clear pause). Opt-in stays as the user left it.
  Future<Either<Failure, PromptPreferences>> resume();

  /// Record the user acting on the active prompt without posting —
  /// internal bookkeeping that RETIRES the prompt. No counter, no
  /// history the user is shown, no judgment (§6c rule 2).
  Future<Either<Failure, Unit>> dismissPrompt({required String promptId});

  /// Record that the user posted in response to a prompt (links the
  /// post id for the payoff view). No streaks (§6c rule 2).
  Future<Either<Failure, Unit>> recordPosted({
    required String promptId,
    required String postId,
  });
}
