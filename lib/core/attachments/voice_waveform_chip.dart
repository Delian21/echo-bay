import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../design_system/sketch_kit.dart';
import '../motion/motion_scope.dart';
import '../theme/app_theme.dart';
import 'attachment.dart';
import 'voice_note_player.dart';

/// A voice-note attachment rendered as a playable waveform: real mic
/// peaks when a `.wave` sidecar exists (captured at record time), a
/// deterministic hand-drawn fallback otherwise; a chalk play/pause
/// button; live elapsed/remaining time; and a drag-to-scrub waveform
/// while playing. Playback goes through the shared [VoiceNotePlayer]
/// singleton.
class VoiceWaveformChip extends StatefulWidget {
  const VoiceWaveformChip({
    super.key,
    required this.attachment,
    this.seed = 1,
  });

  final MessageAttachment attachment;
  final int seed;

  @override
  State<VoiceWaveformChip> createState() => _VoiceWaveformChipState();
}

class _VoiceWaveformChipState extends State<VoiceWaveformChip> {
  bool _loading = false;
  Duration _position = Duration.zero;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<MessageAttachment>? _doneSub;
  List<double>? _peaks;
  bool _scrubbing = false;
  double _scrubFraction = 0;

  VoiceNotePlayer get _player => VoiceNotePlayer.instance;

  bool get _isActive => _player.current == widget.attachment;
  bool _playing = false;
  bool get _isPlaying => _isActive && _playing && !_loading;

  @override
  void initState() {
    super.initState();
    _posSub = _player.positionStream.listen((p) {
      if (_isActive && mounted && !_scrubbing) setState(() => _position = p);
    });
    _doneSub = _player.doneStream.listen((finished) {
      if (finished == widget.attachment && mounted) {
        setState(() {
          _playing = false;
          _position = Duration.zero;
        });
      }
    });
    _loadPeaks();
  }

  /// Loads the recorded sidecar waveform (real mic peaks). Absent for
  /// fallback placeholder notes and messages recorded before this
  /// feature — those keep the deterministic hand-drawn bars.
  Future<void> _loadPeaks() async {
    List<double>? loaded;
    try {
      final f = File('${widget.attachment.path}.wave');
      if (await f.exists()) {
        loaded = (await f.readAsString())
            .split(',')
            .where((s) => s.isNotEmpty)
            .map(double.parse)
            .toList(growable: false);
      }
    } on Object catch (_) {
      loaded = null;
    }
    if (mounted && loaded != null) setState(() => _peaks = loaded);
  }

  void _onScrubUpdate(DragUpdateDetails d) {
    // The waveform plane is a fixed 104×22 box (matching the SizedBox in
    // _Waveform), so the local x maps straight to a fraction — no
    // render-object lookup needed.
    const waveWidth = 104.0;
    final fraction = (d.localPosition.dx / waveWidth).clamp(0.0, 1.0);
    setState(() {
      _scrubbing = true;
      _scrubFraction = fraction;
    });
  }

  Future<void> _onScrubEnd(DragEndDetails _) async {
    final durationMs = widget.attachment.durationMs ?? 0;
    if (durationMs > 0) {
      await _player.seek(Duration(
          milliseconds: (_scrubFraction * durationMs).round()));
      if (mounted) {
        setState(() {
          _position = Duration(
              milliseconds: (_scrubFraction * durationMs).round());
        });
      }
    }
    if (mounted) setState(() => _scrubbing = false);
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _doneSub?.cancel();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      if (_isPlaying) {
        await _player.pause();
        if (mounted) setState(() => _playing = false);
      } else if (_isActive && !_isPlaying) {
        // Paused mid-note — resume from the retained position.
        await _player.resume();
        if (mounted) setState(() => _playing = true);
      } else {
        final ok = await _player.play(widget.attachment);
        if (mounted) setState(() => _playing = ok);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final golden = GoldenHourExtension.of(context);
    final useInk = golden.enabled;
    final durationMs = widget.attachment.durationMs ?? 0;
    final secs = durationMs ~/ 1000;
    final total =
        '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}';

    final shown = _scrubbing
        ? Duration(milliseconds: (_scrubFraction * durationMs).round())
        : _position;
    final progress = durationMs > 0
        ? (shown.inMilliseconds / durationMs).clamp(0.0, 1.0)
        : 0.0;

    // Live clock: elapsed while playing/scrubbing, total when idle —
    // tabular figures so the digits don't jitter as they count.
    final elapsedSecs = shown.inSeconds;
    final elapsedLabel =
        '${elapsedSecs ~/ 60}:${(elapsedSecs % 60).toString().padLeft(2, '0')}';
    final clockLabel = _isPlaying || _scrubbing ? '$elapsedLabel / $total' : total;

    final waveform = _Waveform(
      seed: widget.seed,
      peaks: _peaks,
      playedFraction: progress,
      playing: _isPlaying,
      ink: useInk ? SketchInk.of(context) : theme.colorScheme.outline,
      accent: golden.amberAccent,
    );

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PlayButton(
          playing: _isPlaying,
          loading: _loading,
          useInk: useInk,
          onTap: _toggle,
        ),
        const SizedBox(width: 8),
        // Drag across the waveform to scrub — with a live scrub position
        // preview while dragging.
        GestureDetector(
          onHorizontalDragUpdate: _isPlaying ? _onScrubUpdate : null,
          onHorizontalDragEnd: _isPlaying ? _onScrubEnd : null,
          child: waveform,
        ),
        const SizedBox(width: 8),
        Text(
          clockLabel,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurface,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );

    if (!useInk) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: row,
      );
    }

    return SketchBox(
      seed: widget.seed + 13,
      radius: 6,
      strokeWidth: 2,
      color: SketchInk.of(context),
      fill: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: row,
    );
  }
}

/// The round chalk play/pause affordance: amber disc in ink mode (the
/// paper-plane language), soft pill otherwise.
class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.playing,
    required this.loading,
    required this.useInk,
    required this.onTap,
  });

  final bool playing;
  final bool loading;
  final bool useInk;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final golden = GoldenHourExtension.of(context);
    final child = loading
        ? SizedBox.square(
            dimension: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.6,
              color: useInk
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          )
        : Icon(
            playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: 20,
            color: useInk
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurfaceVariant,
          );

    return InkResponse(
      onTap: onTap,
      radius: 18,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: useInk ? golden.amberAccent : theme.colorScheme.surface,
          shape: BoxShape.circle,
          border: useInk
              ? null
              : Border.all(
                  color: theme.colorScheme.outlineVariant,
                ),
        ),
        child: child,
      ),
    );
  }
}

/// The waveform itself: real mic peaks when available (the `.wave`
/// sidecar recorded at capture time), otherwise ~18 deterministic
/// hand-drawn bars from the seed. Played bars tint amber; unplayed stay
/// ink. Wider when real peaks exist — a true contour earns the space.
class _Waveform extends StatelessWidget {
  const _Waveform({
    required this.seed,
    required this.peaks,
    required this.playedFraction,
    required this.playing,
    required this.ink,
    required this.accent,
  });

  final int seed;
  final List<double>? peaks;
  final double playedFraction;
  final bool playing;
  final Color ink;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final real = peaks;
    final List<double> bars;
    if (real != null && real.length >= 4) {
      // Downsample the recorded peaks (~10/s) to ~36 display bars by
      // averaging — preserves true speech contours.
      const target = 36;
      final bucket = real.length / target;
      bars = List.generate(target, (i) {
        final start = (i * bucket).floor();
        final end = math.min(((i + 1) * bucket).ceil(), real.length);
        var sum = 0.0;
        for (var k = start; k < end; k++) {
          sum += real[k];
        }
        return (sum / math.max(1, end - start)).clamp(0.08, 1.0);
      });
    } else {
      const barCount = 18;
      bars = List.generate(barCount, (i) {
        // Deterministic pseudo-waveform: layered sines per seed produce
        // organic speech-like humps without per-frame randomness.
        final t = i / barCount;
        final h = 0.30 +
            0.26 * math.sin(seed * 0.017 + t * 7.3).abs() +
            0.22 * math.sin(seed * 0.043 + t * 17.9).abs() +
            0.14 * math.sin(seed * 0.089 + t * 29.7).abs();
        return h.clamp(0.12, 1.0);
      });
    }

    final waveform = SizedBox(
      width: real != null && real.length >= 4 ? 104.0 : 76.0,
      height: 22,
      child: CustomPaint(
        painter: _WaveformPainter(
          bars: bars,
          seed: seed,
          playedFraction: playedFraction,
          playing: playing,
          ink: ink,
          accent: accent,
        ),
      ),
    );

    // The playing pulse: while a note plays, the unplayed bars breathe
    // with a slow travelling-wave amplitude — paper alive under the
    // hand. Reduced motion (or paused): static.
    if (!playing) return waveform;
    final reduced = MotionScope.maybeOf(context)?.reducedMotion ?? false;
    if (reduced) return waveform;
    return _BreathingWaveform(
      seed: seed,
      child: waveform,
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.bars,
    required this.seed,
    required this.playedFraction,
    required this.playing,
    required this.ink,
    required this.accent,
  });

  final List<double> bars;
  final int seed;
  final double playedFraction;
  final bool playing;
  final Color ink;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 2.4;
    final barWidth = (size.width - gap * (bars.length - 1)) / bars.length;
    final midY = size.height / 2;

    final playedPaint = Paint()
      ..strokeWidth = barWidth
      ..strokeCap = StrokeCap.round
      ..color = accent;
    final inkPaint = Paint()
      ..strokeWidth = barWidth
      ..strokeCap = StrokeCap.round
      ..color = ink.withValues(alpha: 0.85);

    for (var i = 0; i < bars.length; i++) {
      final x = i * (barWidth + gap) + barWidth / 2;
      final half = (bars[i] * size.height / 2).clamp(1.5, size.height / 2);
      // Bars rendered at slight hand-drawn angles — a ruler was never
      // involved.
      final tilt = ((i * 37 + seed) % 5 - 2) / 40.0;
      final dx = half * tilt;
      canvas.drawLine(
        Offset(x - dx, midY - half),
        Offset(x + dx, midY + half),
        i / bars.length < playedFraction ? playedPaint : inkPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter old) =>
      old.playedFraction != playedFraction ||
      old.playing != playing ||
      old.ink != ink ||
      old.accent != accent ||
      old.seed != seed;
}

/// Rebuilds ~20×/s while the parent says "playing", advancing a phase
/// value the painter turns into a travelling amplitude wave. Ticker-
/// driven, auto-disposed when playback stops.
class _BreathingWaveform extends StatefulWidget {
  const _BreathingWaveform({required this.seed, required this.child});

  final int seed;
  final Widget child;

  @override
  State<_BreathingWaveform> createState() => _BreathingWaveformState();
}

class _BreathingWaveformState extends State<_BreathingWaveform>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _phase = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      if (!mounted) return;
      setState(() => _phase = elapsed.inMicroseconds / 1e6);
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PulsePainter(phase: _phase, seed: widget.seed),
      child: widget.child,
    );
  }
}

/// A transparent overlay painter that slightly modulates the drawn bars
/// by overpainting the breathing amplitude — cheaper than repainting the
/// whole waveform, and the composite reads as the bars shimmering.
class _PulsePainter extends CustomPainter {
  _PulsePainter({required this.phase, required this.seed});

  final double phase;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    // Soften the tip highlights: a paper-white shimmer that travels with
    // the phase — visible motion without changing layout.
    final shimmer = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.white.withValues(
        alpha: 0.18 + 0.10 * math.sin(phase * 2 * math.pi),
      );
    final midY = size.height / 2;
    // The shimmer tip sweeps horizontally — a highlight moving down the
    // bars, the way graphite catches the light.
    final sweepX = (phase % 1.6) / 1.6 * size.width;
    canvas.drawLine(
      Offset(sweepX, midY - 8),
      Offset(sweepX + 6, midY + 8),
      shimmer,
    );
  }

  @override
  bool shouldRepaint(covariant _PulsePainter old) => old.phase != phase;
}
