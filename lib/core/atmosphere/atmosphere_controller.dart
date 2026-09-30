import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../settings/app_settings_store.dart';

/// What [AtmosphereController.play] is asked for. One entry per analog
/// moment; the controller maps each to its tiny bundled sound.
enum AtmosphereSound { penScratch, pageTurn }

/// Optional analog atmosphere — soft paper/pen sounds on posting and
/// pinning, and a light haptic tap on rewind. **Off by default**; the
/// user opts in from Settings. Nothing here gates functionality: every
/// call site is fire-and-forget, and a failed load or missing audio
/// simply plays nothing.
///
/// Persistence rides the same [AppSettingsStore] seam as theme and
/// reduced-motion (best-effort writes; a failed save keeps the session
/// value).
class AtmosphereController extends ChangeNotifier {
  AtmosphereController({
    Future<void> Function(bool)? onSoundsChanged,
    Future<void> Function(bool)? onHapticsChanged,
  })  : _onSoundsChanged = onSoundsChanged,
        _onHapticsChanged = onHapticsChanged;

  final Future<void> Function(bool)? _onSoundsChanged;
  final Future<void> Function(bool)? _onHapticsChanged;
  AudioPlayer? _player;

  bool _soundsEnabled = false;
  bool _hapticsEnabled = false;

  /// Opt-in flag for the paper/pen sounds.
  bool get soundsEnabled => _soundsEnabled;

  /// Opt-in flag for the light haptic tap on rewind. Off by default;
  /// when on it still yields to reduce-motion (see RewindScope).
  bool get hapticsEnabled => _hapticsEnabled;

  Future<void> setSoundsEnabled(bool enabled) async {
    if (_soundsEnabled == enabled) return;
    _soundsEnabled = enabled;
    notifyListeners();
    try {
      await _onSoundsChanged?.call(enabled);
    } on Object {
      // Preference write failed; the session value still applies.
    }
  }

  Future<void> setHapticsEnabled(bool enabled) async {
    if (_hapticsEnabled == enabled) return;
    _hapticsEnabled = enabled;
    notifyListeners();
    try {
      await _onHapticsChanged?.call(enabled);
    } on Object {
      // Preference write failed; the session value still applies.
    }
  }

  /// Restores the stored opt-ins at boot (null = never set → stays off).
  void restore({bool? sounds, bool? haptics}) {
    var changed = false;
    if (sounds != null && sounds != _soundsEnabled) {
      _soundsEnabled = sounds;
      changed = true;
    }
    if (haptics != null && haptics != _hapticsEnabled) {
      _hapticsEnabled = haptics;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  /// Plays one of the bundled analog sounds. No-ops unless opted in.
  /// Errors are swallowed: atmosphere must never break the moment it
  /// decorates.
  Future<void> play(AtmosphereSound sound) async {
    if (!_soundsEnabled) return;
    try {
      final player = _player ??= AudioPlayer();
      await player.stop();
      await player.play(AssetSource(_assetName(sound)));
    } on Object {
      // Missing audio / no audio device / platform without assets.
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  static String _assetName(AtmosphereSound sound) => switch (sound) {
        AtmosphereSound.penScratch => 'audio/pen_scratch.mp3',
        AtmosphereSound.pageTurn => 'audio/page_turn.mp3',
      };
}
