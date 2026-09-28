import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';

import 'attachment.dart';

/// Picks / records attachments for chat messages. Photo and video go
/// through the system picker (image_picker, already in the tree); voice
/// notes are real microphone captures via `record` (MediaFoundation on
/// Windows), written as m4a into the attachments dir. If the microphone
/// is unavailable (no device, permission denied, CI), recording degrades
/// to the stopwatch placeholder file with a true duration so the message
/// pipeline still works end-to-end.
class AttachmentPicker {
  final ImagePicker _picker = ImagePicker();

  /// Picks an image or video from the device's files. Returns null when
  /// the user cancels.
  Future<MessageAttachment?> pickPhoto() => _pick(false);

  Future<MessageAttachment?> pickVideo() => _pick(true);

  Future<MessageAttachment?> _pick(bool video) async {
    try {
      final picked = await (video
          ? _picker.pickVideo(source: ImageSource.gallery)
          : _picker.pickImage(source: ImageSource.gallery));
      if (picked == null) return null;
      return MessageAttachment(
        kind: video ? AttachmentKind.video : AttachmentKind.photo,
        path: picked.path,
      );
    } on Object catch (e) {
      debugPrint('AttachmentPicker pick failed: $e');
      return null;
    }
  }

  /// Starts a voice recording. Returns null if recording cannot start.
  /// Stop with the returned handle; the completed attachment carries the
  /// true recorded duration and path.
  Future<VoiceRecording?> startVoiceRecording() async {
    try {
      // Haptic acknowledgment — recording started.
      await HapticFeedback.mediumImpact();
      final recorder = AudioRecorder();
      final dir = Directory(
          '${Directory.current.path}${Platform.pathSeparator}.attachments');
      if (!await dir.exists()) await dir.create(recursive: true);
      final path =
          '${dir.path}${Platform.pathSeparator}voice_${DateTime.now().microsecondsSinceEpoch}.m4a';

      var live = false;
      final peaks = <double>[];
      try {
        if (await recorder.hasPermission()) {
          await recorder.start(
            const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 96000),
            path: path,
          );
          live = true;
          // True waveform capture: sample the mic amplitude ~10×/s into
          // normalized peaks. Written to a sidecar on stop; the voice
          // chips render these real speech contours.
          recorder.onAmplitudeChanged(const Duration(milliseconds: 100)).listen(
            (a) {
              final normalized = ((a.current + 45) / 45).clamp(0.05, 1.0);
              peaks.add(normalized);
            },
            onError: (_) {},
          );
        }
      } on Object catch (e) {
        debugPrint('AttachmentPicker mic unavailable, falling back: $e');
      }

      return VoiceRecording._(
        recorder: recorder,
        path: path,
        live: live,
        peaks: peaks,
        stopwatch: Stopwatch()..start(),
      );
    } on Object catch (e) {
      debugPrint('AttachmentPicker record failed: $e');
      return null;
    }
  }
}

/// An in-progress voice recording. [stop] finalizes it: for a live
/// capture the encoder flushes to the m4a file; for the fallback a small
/// placeholder file is written. Either way the returned attachment
/// carries the true measured duration.
class VoiceRecording {
  VoiceRecording._({
    required AudioRecorder recorder,
    required String path,
    required bool live,
    required List<double> peaks,
    required Stopwatch stopwatch,
  })  : _recorder = recorder,
        _path = path,
        _live = live,
        _peaks = peaks,
        _stopwatch = stopwatch;

  final AudioRecorder _recorder;
  final String _path;
  final bool _live;
  final List<double> _peaks;
  final Stopwatch _stopwatch;

  /// Elapsed recording time — the UI polls this with its own ticker
  /// for the "recording… 0:03" display.
  Duration get elapsed => _stopwatch.elapsed;

  Future<MessageAttachment> stop() async {
    _stopwatch.stop();
    final durationMs = _stopwatch.elapsedMilliseconds;

    if (_live) {
      try {
        final finalPath = await _recorder.stop();
        await _recorder.dispose();
        // The encoder reports its own path; trust it when present.
        final written = finalPath ?? _path;
        final file = File(written);
        if (await file.exists() && await file.length() > 0) {
          // Sidecar waveform: real mic peaks as comma-separated values.
          // Chips load it to draw the true speech contour.
          if (_peaks.isNotEmpty) {
            await File('$written.wave').writeAsString(_peaks.join(','));
          }
          return MessageAttachment(
            kind: AttachmentKind.voice,
            path: written,
            durationMs: durationMs,
          );
        }
      } on Object catch (e) {
        debugPrint('VoiceRecording stop failed, writing placeholder: $e');
      }
    } else {
      await _recorder.dispose();
    }

    // Fallback capture: a tiny placeholder file so the pipeline (persist,
    // render, play-chip) stays real even without a microphone.
    final file = File('$_path.txt');
    await file.writeAsString('voice note placeholder ($durationMs ms)');

    return MessageAttachment(
      kind: AttachmentKind.voice,
      path: file.path,
      durationMs: durationMs,
    );
  }

  void cancel() {
    _stopwatch.stop();
    // Cancel best-effort: discard any partial capture and release the
    // recorder. Errors here must never crash the composer.
    Future(() async {
      try {
        if (_live) await _recorder.stop();
      } on Object catch (_) {}
      try {
        await _recorder.dispose();
      } on Object catch (_) {}
      try {
        final f = File(_path);
        if (await f.exists()) await f.delete();
      } on Object catch (_) {}
    });
  }
}
