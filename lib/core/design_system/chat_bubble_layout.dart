import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Chat-layout primitives shared by every conversation surface (the Vault's
/// DMs and the Nexus dorm chats), so a bubble looks and stacks the same
/// wherever it is drawn.

/// A bubble may occupy at most this fraction of the viewport. Past it a
/// message stops reading as a message and starts reading as a paragraph.
const double kChatBubbleMaxWidthFactor = 0.75;

/// Two messages from one sender belong to the same run when they follow
/// each other inside this window.
const Duration kChatRunWindow = Duration(minutes: 2);

/// Vertical gap that opens a sender's run (or follows a day separator).
const double kChatRunGap = 10;

/// Vertical gap between two messages in the same run.
const double kChatRunTightGap = 2;

const EdgeInsets kChatBubblePadding =
    EdgeInsets.symmetric(horizontal: 12, vertical: 8);

/// Bubble corners: generously rounded, except the sender's own side at the
/// end of a run, which tightens to a chat-tail.
BorderRadius chatBubbleRadius({
  required bool isMine,
  required bool closesRun,
}) {
  const rounded = Radius.circular(18);
  const tail = Radius.circular(6);
  return BorderRadius.only(
    topLeft: rounded,
    topRight: rounded,
    bottomLeft: isMine ? rounded : (closesRun ? tail : rounded),
    bottomRight: isMine ? (closesRun ? tail : rounded) : rounded,
  );
}

/// Does [senderId] at [createdAt] start a new run, given what came before?
bool startsChatRun({
  required String senderId,
  required DateTime createdAt,
  String? previousSenderId,
  DateTime? previousCreatedAt,
}) {
  if (previousSenderId == null || previousCreatedAt == null) return true;
  if (previousSenderId != senderId) return true;
  return createdAt.difference(previousCreatedAt) >= kChatRunWindow;
}

/// Do these two moments fall on the same calendar day?
bool isSameChatDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

const List<String> _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "Today", "Yesterday", "12 Mar", or "12 Mar 2025" for another year.
String chatDayLabel(DateTime day, {DateTime? now}) {
  final today = now ?? DateTime.now();
  if (isSameChatDay(day, today)) return 'Today';
  final yesterday = DateTime(today.year, today.month, today.day)
      .subtract(const Duration(days: 1));
  if (isSameChatDay(day, yesterday)) return 'Yesterday';
  final month = _monthNames[day.month - 1];
  return day.year == today.year
      ? '${day.day} $month'
      : '${day.day} $month ${day.year}';
}

/// Centered label drawn where the conversation crosses midnight.
class ChatDaySeparator extends StatelessWidget {
  const ChatDaySeparator({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Center(
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}

/// Body text color for a bubble: a filled accent bubble takes its
/// foreground from `onPrimary`, which the theme derives for WCAG contrast;
/// the neutral bubble uses the surface foreground.
Color chatBubbleForeground(BuildContext context, {required bool isMine}) {
  final scheme = Theme.of(context).colorScheme;
  return isMine ? scheme.onPrimary : scheme.onSurface;
}

/// Meta line (timestamp, edited, ticks) — same foreground, never dimmed by
/// alpha: small text has to clear AA 4.5:1, and alpha drops it under.
Color chatBubbleMetaForeground(BuildContext context, {required bool isMine}) =>
    chatBubbleForeground(context, isMine: isMine);

/// The bubble surface: accent fill for mine, neutral fill for theirs, width
/// capped at [kChatBubbleMaxWidthFactor] of the viewport, corners squared off
/// on the sender's side at the end of a run. No sketchy stroke.
class ChatBubbleFrame extends StatelessWidget {
  const ChatBubbleFrame({
    super.key,
    required this.isMine,
    required this.closesRun,
    required this.child,
  });

  final bool isMine;
  final bool closesRun;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * kChatBubbleMaxWidthFactor,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isMine ? scheme.primary : scheme.surfaceContainerHighest,
          border: isMine
              ? null
              : Border.all(color: context.borderPlain, width: 1),
          borderRadius:
              chatBubbleRadius(isMine: isMine, closesRun: closesRun),
        ),
        child: Padding(
          padding: kChatBubblePadding,
          child: child,
        ),
      ),
    );
  }
}
