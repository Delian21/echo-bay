import 'package:flutter/material.dart';
import 'package:fpdart/fpdart.dart' hide State;

import '../../../core/error/failures.dart';
import '../../../core/prompt/prompt.dart';
import '../../../core/prompt/prompt_repository.dart';

/// The Daily Square settings card (§6c). Encodes the anti-chore rules in
/// UI terms:
///  - opt-in is a switch the USER flips (rule 5: never default-on);
///  - the window is the user's pick, offered as honest time-of-day
///    choices, not a dark-pattern schedule;
///  - pause is one tap, with a visible "paused until" line and a resume
///    action — no guilt copy, no counters (rule 5);
///  - copy never promises streaks, scores, or a "done" state (rule 2).
///
/// Reads/writes [PromptRepository] directly (slice-simple, like the rest
/// of the settings page); a bloc replaces this at backend integration
/// without changing the contract.
class DailySquareSettingsCard extends StatefulWidget {
  const DailySquareSettingsCard({super.key, required this.repository});

  final PromptRepository repository;

  @override
  State<DailySquareSettingsCard> createState() =>
      _DailySquareSettingsCardState();
}

class _DailySquareSettingsCardState extends State<DailySquareSettingsCard> {
  PromptPreferences? _prefs;
  Failure? _failure;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    widget.repository.preferences().then(_apply);
  }

  void _apply(Either<Failure, PromptPreferences> result) {
    if (!mounted) return;
    setState(() {
      result.fold(
        (f) => _failure = f,
        (p) {
          _prefs = p;
          _failure = null;
        },
      );
    });
  }

  Future<void> _update(PromptPreferences prefs) async {
    setState(() => _saving = true);
    final result = await widget.repository.updatePreferences(prefs);
    if (!mounted) return;
    setState(() => _saving = false);
    _apply(result);
    result.fold(
      (f) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(f.message ?? 'Could not save'),
          behavior: SnackBarBehavior.floating,
        ),
      ),
      (_) {},
    );
  }

  Future<void> _pause() async {
    // One week, one tap. Arbitrary-but-honest: the card shows exactly
    // when it ends and resuming is the same tap distance away.
    final until = DateTime.now().add(const Duration(days: 7));
    setState(() => _saving = true);
    final result = await widget.repository.pauseUntil(until);
    if (!mounted) return;
    setState(() => _saving = false);
    _apply(result);
  }

  Future<void> _resume() async {
    setState(() => _saving = true);
    final result = await widget.repository.resume();
    if (!mounted) return;
    setState(() => _saving = false);
    _apply(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_failure != null && _prefs == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: Icon(Icons.error_outline_rounded,
                color: theme.colorScheme.error),
            title: const Text('Daily Square unavailable'),
            subtitle: Text(_failure!.message ?? 'Try again later.'),
          ),
        ),
      );
    }

    final prefs = _prefs;
    if (prefs == null) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Card(
          margin: EdgeInsets.zero,
          child: SizedBox(
            height: 88,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Daily Square', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          'One small invitation a day, in a window you '
                          'pick. No streaks, no backlog.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Opt-in switch: the only gate. Turning it off is as
                  // frictionless as on (rule 5).
                  Switch(
                    value: prefs.optedIn,
                    onChanged: _saving
                        ? null
                        : (v) => _update(prefs.copyWith(optedIn: v)),
                  ),
                ],
              ),
              if (prefs.optedIn) ...[
                const SizedBox(height: 10),
                // Window picker (rule 1: user-owned window).
                Row(
                  children: [
                    Text('My window opens at',
                        style: theme.textTheme.bodyMedium),
                    const SizedBox(width: 10),
                    DropdownMenu<int>(
                      width: 108,
                      initialSelection: prefs.windowHour,
                      requestFocusOnTap: false,
                      dropdownMenuEntries: [
                        for (var h = 0; h <= 23; h++)
                          DropdownMenuEntry(value: h, label: _hourLabel(h)),
                      ],
                      onSelected: (h) {
                        if (h == null || h == prefs.windowHour) return;
                        _update(prefs.copyWith(windowHour: h));
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Pause line (rule 5): visible state, zero shame.
                if (prefs.isPaused)
                  Row(
                    children: [
                      Icon(Icons.pause_circle_outline_rounded,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Paused until ${_dateLabel(prefs.pausedUntil!)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _saving ? null : _resume,
                        child: const Text('Resume'),
                      ),
                    ],
                  )
                else
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _saving ? null : _pause,
                      child: const Text('Pause for a week'),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _hourLabel(int h) {
    final period = h < 12 ? 'AM' : 'PM';
    final hour12 = h % 12 == 0 ? 12 : h % 12;
    return '$hour12:00 $period';
  }

  static String _dateLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dt.year, dt.month, dt.day);
    final days = target.difference(today).inDays;
    if (days <= 0) return 'today';
    if (days == 1) return 'tomorrow';
    return '${dt.month}/${dt.day}';
  }
}
