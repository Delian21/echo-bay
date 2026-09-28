import 'dart:async';
import 'dart:math';

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/call.dart';
import '../../domain/repositories/calls_repository.dart';

/// The Calls — mock implementation. Generates a seeded recents log and
/// simulates outbound calls. [setOnline] mirrors the other mock repos so
/// offline behavior (call fails to connect) is testable without a backend.
/// [startTicker] is opt-in: periodic timers trip flutter_test's
/// pending-timer invariant (same convention as Square/Vault/Nexus mocks).
class MockCallsRepository implements CallsRepository {
  MockCallsRepository({
    this.startTicker = false,
    this.connectDelay = const Duration(milliseconds: 900),
  }) {
    if (startTicker) {
      // Slow ambient tick: occasionally appends an incoming call so the
      // recents list feels alive. 10 min default is fine for dev sessions.
      _ticker = Timer.periodic(const Duration(minutes: 10), (_) {
        _log.insert(0, _makeEntry(_peers[_rng.nextInt(_peers.length)],
            direction: CallDirection.incoming));
        _emit();
      });
    }
  }

  bool _online = true;

  /// Opt-in ambient ticker: appends an incoming call every 10 min so the
  /// recents list feels alive. Off by default so tests don't trip
  /// flutter_test's pending-timer invariant.
  final bool startTicker;

  Timer? _ticker;
  late final List<CallLogEntry> _log = [
    _makeEntry(_peers[0],
        direction: CallDirection.missed,
        at: DateTime.now().subtract(const Duration(minutes: 12))),
    _makeEntry(_peers[1],
        direction: CallDirection.incoming,
        duration: const Duration(minutes: 4, seconds: 37),
        at: DateTime.now().subtract(const Duration(hours: 3))),
    _makeEntry(_peers[2],
        direction: CallDirection.outgoing,
        duration: const Duration(seconds: 52),
        at: DateTime.now().subtract(const Duration(hours: 26))),
    _makeEntry(_peers[1],
        direction: CallDirection.outgoing,
        duration: const Duration(minutes: 18, seconds: 3),
        wasVideo: true,
        at: DateTime.now().subtract(const Duration(days: 2))),
  ];
  final StreamController<Either<Failure, List<CallLogEntry>>> _controller =
      StreamController.broadcast();

  /// Connect delay for simulated outbound calls; tests shrink or zero it.
  final Duration connectDelay;

  static final Random _rng = Random(7);
  static const _peers = [
    // Unsplash face crops: same host as post media (CORS * — pravatar
    // sends no Access-Control-Allow-Origin and is blocked on web).
    ('Kai Meridian', 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150&h=150&fit=crop&crop=faces&q=80'),
    ('Rune Virtanen', 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=150&h=150&fit=crop&crop=faces&q=80'),
    ('Ada Okafor', 'https://images.unsplash.com/photo-1531123897727-8f129e1688ce?w=150&h=150&fit=crop&crop=faces&q=80'),
    ('Mira Solheim', 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150&h=150&fit=crop&crop=faces&q=80'),
  ];

  void _emit() {
    final snapshot = List<CallLogEntry>.unmodifiable(_log);
    _controller.add(Right(snapshot));
  }

  void setOnline(bool online) {
    _online = online;
  }

  @override
  Stream<Either<Failure, List<CallLogEntry>>> watchRecents() async* {
    // Broadcast controllers drop events added before a listener attaches,
    // so yield the current snapshot on every subscribe before forwarding
    // live appends (the drift-backed mocks replay via their own streams).
    yield Right(List<CallLogEntry>.unmodifiable(_log));
    yield* _controller.stream;
  }

  @override
  Future<Either<Failure, CallLogEntry>> placeCall({
    required String peerName,
    required String peerAvatarUrl,
    bool video = false,
  }) async {
    if (!_online) {
      return const Left(NetworkFailure(message: 'No connection to call out.'));
    }
    await Future<void>.delayed(connectDelay);
    final entry = CallLogEntry(
      id: 'call-${DateTime.now().microsecondsSinceEpoch}',
      peerName: peerName,
      peerAvatarUrl: peerAvatarUrl,
      direction: CallDirection.outgoing,
      at: DateTime.now(),
      duration: Duration(seconds: 20 + _rng.nextInt(400)),
      wasVideo: video,
    );
    _log.insert(0, entry);
    _emit();
    return Right(entry);
  }

  void dispose() {
    _ticker?.cancel();
    _controller.close();
  }
}

CallLogEntry _makeEntry(
  (String, String) peer, {
  required CallDirection direction,
  Duration duration = Duration.zero,
  DateTime? at,
  bool wasVideo = false,
}) {
  return CallLogEntry(
    id: 'seed-${peer.$1}-${direction.name}-${at?.microsecondsSinceEpoch ?? 0}',
    peerName: peer.$1,
    peerAvatarUrl: peer.$2,
    direction: direction,
    at: at ?? DateTime.now(),
    duration: duration,
    wasVideo: wasVideo,
  );
}
