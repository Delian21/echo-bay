/// The Calls — call log entry. Pure entity; the module's read model is a
/// chronological recents list, mirroring the Square's shape.
enum CallDirection { incoming, outgoing, missed }

class CallLogEntry {
  const CallLogEntry({
    required this.id,
    required this.peerName,
    required this.peerAvatarUrl,
    required this.direction,
    required this.at,
    required this.duration,
    this.wasVideo = false,
  });

  final String id;
  final String peerName;
  final String peerAvatarUrl;
  final CallDirection direction;

  /// When the call happened (or was missed).
  final DateTime at;

  /// Zero for missed calls; the mock generates plausible durations.
  final Duration duration;
  final bool wasVideo;

  String get timeLabel {
    final delta = DateTime.now().difference(at);
    if (delta.inMinutes < 1) return 'now';
    if (delta.inMinutes < 60) return '${delta.inMinutes}m ago';
    if (delta.inHours < 24) return '${delta.inHours}h ago';
    if (delta.inDays < 7) return '${delta.inDays}d ago';
    return '${at.day}/${at.month}';
  }

  String get durationLabel {
    if (direction == CallDirection.missed || duration.inSeconds == 0) return '';
    final m = duration.inMinutes;
    final s = duration.inSeconds % 60;
    return m > 0 ? '${m}m ${s}s' : '${s}s';
  }
}
