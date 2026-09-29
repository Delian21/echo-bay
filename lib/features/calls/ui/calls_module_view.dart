import 'package:flutter/material.dart';
import 'package:fpdart/fpdart.dart' hide State;

import '../../../core/design_system/loading_skeletons.dart';
import '../../../core/design_system/sketch_kit.dart';
import '../../../core/design_system/staggered_entrance.dart';
import '../../../core/error/failures.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/entities/call.dart';
import '../domain/repositories/calls_repository.dart';

/// The Calls — module view. Stream-first like the Vault list: consumes
/// [CallsRepository.watchRecents] via StreamBuilder; a bloc replaces this
/// at integration without touching the widgets below.
class CallsModuleView extends StatefulWidget {
  const CallsModuleView({super.key, required this.repository});

  final CallsRepository repository;

  @override
  State<CallsModuleView> createState() => _CallsModuleViewState();
}

class _CallsModuleViewState extends State<CallsModuleView> {
  late final Stream<Either<Failure, List<CallLogEntry>>> _recents =
      widget.repository.watchRecents();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('The Landline'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'New call',
            icon: const SketchGlyph(kind: SketchIconKind.dialPad),
            onPressed: () {},
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: StreamBuilder<Either<Failure, List<CallLogEntry>>>(
        stream: _recents,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const TileListSkeleton();
          }
          final either = snapshot.data;
          if (either == null) {
            return const _ModuleEmptyState(
              icon: Icons.wifi_off_rounded,
              message: 'Stream dropped. Reconnect to reload.',
            );
          }
          return either.fold(
            (failure) => _ModuleEmptyState(
              icon: Icons.call_end_rounded,
              message: failure.message ?? 'Call log unavailable.',
            ),
            (List<CallLogEntry> entries) {
              if (entries.isEmpty) {
                return const _ModuleEmptyState(
                  icon: Icons.call_rounded,
                  message: 'No calls yet.',
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 24),
                // +1 for the handwritten masthead pinned above the list.
                itemCount: entries.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return const _LandlineMasthead();
                  }
                  return StaggeredEntrance(
                    index: index - 1,
                    child: _CallTile(
                      entry: entries[index - 1],
                      onRedial: () => _placeCall(context, entries[index - 1]),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _placeCall(BuildContext context, CallLogEntry entry) async {
    final connected = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CallConnectingDialog(entry: entry, repo: widget.repository),
    );
    if (connected ?? false) {
      if (!context.mounted) return;
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => MockCallScreen(entry: entry),
      ));
    }
  }
}

class _CallTile extends StatelessWidget {
  const _CallTile({required this.entry, required this.onRedial});

  final CallLogEntry entry;
  final VoidCallback onRedial;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMissed = entry.direction == CallDirection.missed;

    // Chalk arrows for call direction (ink mode); Material fallback
    // when the analog layer is off.
    final useInk = GoldenHourExtension.of(context).enabled;
    final directionIcon = switch (entry.direction) {
      CallDirection.incoming => SketchIconKind.arrowDownLeft,
      CallDirection.outgoing => SketchIconKind.arrowUpRight,
      CallDirection.missed => SketchIconKind.arrowMissed,
    };
    final directionColor = switch (entry.direction) {
      CallDirection.incoming => theme.colorScheme.secondary,
      CallDirection.outgoing => theme.colorScheme.onSurfaceVariant,
      CallDirection.missed => theme.colorScheme.error,
    };

    return ListTile(
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: theme.colorScheme.primaryContainer,
        backgroundImage: entry.peerAvatarUrl.isEmpty
            ? null
            : NetworkImage(entry.peerAvatarUrl),
        onBackgroundImageError: (_, __) {},
        child: entry.peerAvatarUrl.isEmpty
            ? Text(
                entry.peerName.characters.first.toUpperCase(),
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              )
            : null,
      ),
      title: Text(
        entry.peerName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: isMissed ? theme.colorScheme.error : null,
        ),
      ),
      subtitle: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          useInk
              ? SketchIcon(
                  kind: directionIcon, size: 14, color: directionColor, seed: 13)
              : Icon(
                  switch (entry.direction) {
                    CallDirection.incoming => Icons.call_received_rounded,
                    CallDirection.outgoing => Icons.call_made_rounded,
                    CallDirection.missed =>
                      Icons.call_missed_outgoing_rounded,
                  },
                  size: 14,
                  color: directionColor,
                ),
          const SizedBox(width: 4),
          Text(
            entry.timeLabel,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (entry.wasVideo)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: SketchIcon(
                kind: SketchIconKind.videoCam,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
                seed: 29,
              ),
            ),
          IconButton(
            tooltip: 'Call ${entry.peerName}',
            icon: SketchIcon(
              kind: SketchIconKind.handset,
              size: 20,
              color: theme.colorScheme.secondary,
              seed: 31,
            ),
            onPressed: onRedial,
          ),
        ],
      ),
    );
  }
}

// -- empty/failure state (local; same styling as the other modules) --------

/// Handwritten masthead above the recents list — the Landline's slice of
/// the analog voice (spec §4 keeps Calls the cleanest module: handwriting
/// only, no ink boxes, no paper). Hidden when the analog layer is off.
class _LandlineMasthead extends StatelessWidget {
  const _LandlineMasthead();

  @override
  Widget build(BuildContext context) {
    final golden = GoldenHourExtension.of(context);
    if (!golden.enabled) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'The line is open.',
            style: kHandwrittenTextStyle.copyWith(
              fontSize: 26,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Pick up where you left off.',
            style: kHandwrittenTextStyle.copyWith(
              fontSize: 15,
              color: golden.amberAccent,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleEmptyState extends StatelessWidget {
  const _ModuleEmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final golden = GoldenHourExtension.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            // Calls is the cleanest module (spec §4): the empty state
            // gets the handwriting voice but nothing else.
            style: golden.enabled
                ? kHandwrittenTextStyle.copyWith(
                    fontSize: 19,
                    color: theme.colorScheme.onSurfaceVariant,
                  )
                : theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Simulated connect flow: spinner -> connected -> user taps "Join".
class _CallConnectingDialog extends StatefulWidget {
  const _CallConnectingDialog({
    required this.entry,
    required this.repo,
    this.video = false,
  });

  final CallLogEntry entry;
  final CallsRepository repo;
  final bool video;

  @override
  State<_CallConnectingDialog> createState() => _CallConnectingDialogState();
}

class _CallConnectingDialogState extends State<_CallConnectingDialog> {
  bool _connecting = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.repo
        .placeCall(
      peerName: widget.entry.peerName,
      peerAvatarUrl: widget.entry.peerAvatarUrl,
      video: widget.video,
    )
        .then((result) {
      if (!mounted) return;
      result.fold(
        (f) => setState(() {
          _connecting = false;
          _error = f.message ?? 'Call failed.';
        }),
        (_) => setState(() => _connecting = false),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
          '${widget.video ? 'Video call' : 'Calling'} — ${widget.entry.peerName}'),
      content: _connecting
          ? const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 16),
                Text('Connecting…'),
              ],
            )
          : _error != null
              ? Text(_error!)
              : const Text('Connected.'),
      actions: [
        if (!_connecting && _error == null)
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Join'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

/// Full-screen mock call UI. No transport — it exists to make the slice
/// navigable and to give the settings/theme work a second surface to
/// visually verify against.
class MockCallScreen extends StatefulWidget {
  const MockCallScreen({super.key, required this.entry});

  final CallLogEntry entry;

  @override
  State<MockCallScreen> createState() => _MockCallScreenState();
}

class _MockCallScreenState extends State<MockCallScreen> {
  bool _muted = false;
  bool _speaker = false;
  final Stopwatch _clock = Stopwatch()..start();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.entry.peerName)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 44,
              backgroundColor: theme.colorScheme.primaryContainer,
              backgroundImage: NetworkImage(widget.entry.peerAvatarUrl),
              onBackgroundImageError: (_, __) {},
            ),
            const SizedBox(height: 16),
            Text(widget.entry.peerName, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 4),
            // Ticker-free: rebuilds only when a control toggles, so the
            // elapsed label updates on interaction. Fine for a mock screen.
            Text('00:${_clock.elapsed.inSeconds.toString().padLeft(2, '0')}',
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()])),
            const SizedBox(height: 40),
            Wrap(
              spacing: 16,
              children: [
                _CallControlButton(
                  glyph: SketchIcon(
                    kind: _muted
                        ? SketchIconKind.micOff
                        : SketchIconKind.scribbleMic,
                    size: 24,
                    color: _muted
                        ? theme.colorScheme.onError
                        : theme.colorScheme.onSurface,
                    seed: 37,
                  ),
                  label: _muted ? 'Unmute' : 'Mute',
                  active: _muted,
                  onTap: () => setState(() => _muted = !_muted),
                ),
                _CallControlButton(
                  glyph: SketchIcon(
                    kind: SketchIconKind.speakerWave,
                    size: 24,
                    color: _speaker
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurface,
                    seed: 41,
                  ),
                  label: 'Speaker',
                  active: _speaker,
                  onTap: () => setState(() => _speaker = !_speaker),
                ),
                _CallControlButton(
                  glyph: SketchIcon(
                    kind: SketchIconKind.hangUp,
                    size: 24,
                    color: theme.colorScheme.onError,
                    seed: 43,
                  ),
                  label: 'End',
                  active: true,
                  destructive: true,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CallControlButton extends StatelessWidget {
  const _CallControlButton({
    required this.glyph,
    required this.label,
    required this.active,
    required this.onTap,
    this.destructive = false,
  });

  final Widget glyph;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = destructive
        ? theme.colorScheme.error
        : active
            ? theme.colorScheme.primary
            : theme.colorScheme.surfaceContainerHighest;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkResponse(
          onTap: onTap,
          radius: 28,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Center(child: glyph),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: theme.textTheme.labelSmall),
      ],
    );
  }
}

/// Launch the mock call flow for a peer from anywhere — the Landline's
/// connecting dialog + call screen, shared with the Vault chat app bar
/// (calls belong in the conversation). Records the call in the Landline
/// log through [CallsRepository.placeCall].
Future<void> placeCallToPeer(
  BuildContext context, {
  required CallsRepository repository,
  required String peerName,
  required String peerAvatarUrl,
  bool video = false,
}) async {
  final entry = CallLogEntry(
    id: 'outbound-${DateTime.now().microsecondsSinceEpoch}',
    peerName: peerName,
    peerAvatarUrl: peerAvatarUrl,
    direction: CallDirection.outgoing,
    at: DateTime.now(),
    duration: Duration.zero,
    wasVideo: video,
  );
  final connected = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _CallConnectingDialog(
      entry: entry,
      repo: repository,
      video: video,
    ),
  );
  if (connected ?? false) {
    if (!context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => MockCallScreen(entry: entry),
    ));
  }
}
