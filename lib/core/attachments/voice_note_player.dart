import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import 'attachment.dart';

/// Plays voice-note attachments. One shared [AudioPlayer] per app — a
/// chat plays one note at a time, and starting a second stops the first
/// (messenger convention). Exposed through a singleton so every voice
/// chip in every bubble shares the same playback state.
class VoiceNotePlayer {
  VoiceNotePlayer._();
  static final VoiceNotePlayer instance = VoiceNotePlayer._();

  final AudioPlayer _player = AudioPlayer();

  /// The attachment currently loaded/playing, if any.
  MessageAttachment? _current;

  /// Playback position within [_current], emitted continuously while a
  /// note plays.
  final _position = StreamController<Duration>.broadcast();
  Stream<Duration> get positionStream => _position.stream;

  /// Completion / stop events for the currently playing attachment.
  final _done = StreamController<MessageAttachment>.broadcast();
  Stream<MessageAttachment> get doneStream => _done.stream;

  bool get isPlaying => _current != null;
  MessageAttachment? get current => _current;

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<void>? _completeSub;

  /// Starts playing [attachment] (voice kind). Stops whatever was
  /// playing first. Errors (missing file, codec) surface as false —
  /// chips degrade to a static waveform, never a crash.
  Future<bool> play(MessageAttachment attachment) async {
    if (attachment.kind != AttachmentKind.voice) return false;
    await stop();

    try {
      await _player.play(DeviceFileSource(attachment.path));
      _current = attachment;
      _posSub = _player.onPositionChanged.listen(_position.add);
      _completeSub = _player.onPlayerComplete.listen((_) async {
        final finished = _current;
        await _reset();
        if (finished != null) _done.add(finished);
      });
      return true;
    } on Object {
      await _reset();
      return false;
    }
  }

  /// Pauses playback; the chip flips to its paused state with the
  /// position retained for a resume.
  Future<void> pause() async {
    try {
      await _player.pause();
    } on Object catch (_) {
      // Nothing playing — pausing is a no-op.
    }
  }

  /// Resumes a paused note.
  Future<void> resume() async {
    try {
      await _player.resume();
    } on Object catch (_) {
      // Nothing paused — resuming is a no-op.
    }
  }

  /// Seeks the active note to [position] (scrubber support).
  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
    } on Object catch (_) {
      // Nothing loaded — seeking is a no-op.
    }
  }

  /// Stops and unloads. Safe to call when nothing is playing.
  Future<void> stop() async {
    try {
      await _player.stop();
    } on Object catch (_) {
      // Nothing loaded — stopping is a no-op.
    }
    await _reset();
  }

  Future<void> _reset() async {
    await _posSub?.cancel();
    await _completeSub?.cancel();
    _posSub = null;
    _completeSub = null;
    _current = null;
  }

  /// Dispose only at app teardown (tests).
  Future<void> dispose() async {
    await stop();
    await _position.close();
    await _done.close();
    await _player.dispose();
  }
}
