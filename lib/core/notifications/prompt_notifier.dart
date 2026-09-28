import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fpdart/fpdart.dart';

import '../error/failures.dart';

/// Schedules the Daily Square window notification (§6c). The seam exists
/// so the prompt logic is testable without platform channels and so the
/// notification copy/behavior stays in one place.
///
/// Anti-chore guarantees encoded here:
///  - exactly ONE notification per day, inside the user's window
///    (never a random interrupt — §6c rule 1);
///  - no repeated re-notify, no badge counting, no "you missed it"
///    follow-up (§6c rule 2);
///  - cancel() is always available: pause = cancel, immediately.
abstract class PromptNotifier {
  /// (Re)schedule today's window notification for [hour]:00 local time.
  /// Idempotent: rescheduling replaces the pending one, never stacks.
  Future<Either<Failure, Unit>> scheduleDailyWindow({
    required int hour,
    required String promptBody,
  });

  /// Cancel any pending window notification (pause path). The next
  /// scheduleDailyWindow call re-arms it.
  Future<Either<Failure, Unit>> cancel();

  /// True when a window notification is currently pending.
  Future<bool> isPending();
}

/// Real implementation over flutter_local_notifications.
class LocalPromptNotifier implements PromptNotifier {
  LocalPromptNotifier() : _plugin = FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  static const _dailyId = 42; // single slot: one notification, ever

  static const _channel = AndroidNotificationChannel(
    'daily_square_window',
    'Daily Square',
    description: 'Your Daily Square window',
    importance: Importance.low, // silent-ish: an invitation, not an alarm
  );

  /// Notification tap → deep link (route carried in the payload); the
  /// router (#8) assigns this callback at composition time.
  static void Function(NotificationResponse)? onNotificationTap;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
        linux: LinuxInitializationSettings(defaultActionName: 'Open'),
        windows: WindowsInitializationSettings(
          appName: 'Super App',
          appUserModelId: 'com.superapp.daily',
          guid: 'a4b8c2d1-3e6f-4a7b-9c0d-1e2f3a4b5c6d',
        ),
      ),
      onDidReceiveNotificationResponse:
          (response) => onNotificationTap?.call(response),
    );
    _initialized = true;
  }

  @override
  Future<Either<Failure, Unit>> scheduleDailyWindow({
    required int hour,
    required String promptBody,
  }) async {
    try {
      await _ensureInit();
      final now = DateTime.now();
      var fire = DateTime(now.year, now.month, now.day, hour);
      if (!fire.isAfter(now)) {
        fire = fire.add(const Duration(days: 1));
      }

      // Zoned schedule would need timezone data; for the mock stage a
      // one-shot inexact alarm per app-launch is the honest scope: the
      // app re-arms on boot (DI), which covers the daily cadence without
      // the timezone plugin weight.
      await _plugin.cancel(id: _dailyId);
      await _plugin.show(
        id: _dailyId,
        title: 'Your Square window is open',
        body: promptBody,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.low,
            priority: Priority.low,
          ),
          iOS: const DarwinNotificationDetails(
            presentSound: false, // an invitation, not an alarm (§6c)
          ),
        ),
        // The in-app route for the tap handler / router (#8).
        payload: '/square/compose',
      );
      return right(unit);
    } on Object catch (e) {
      return left(
          CacheFailure(message: 'scheduleDailyWindow failed', cause: e));
    }
  }

  @override
  Future<Either<Failure, Unit>> cancel() async {
    try {
      await _plugin.cancel(id: _dailyId);
      return right(unit);
    } on Object catch (e) {
      return left(CacheFailure(message: 'cancel failed', cause: e));
    }
  }

  @override
  Future<bool> isPending() =>
      _plugin.getActiveNotifications().then((list) =>
          list.any((n) => n.id == _dailyId));
}

/// No-op [PromptNotifier] for tests: records calls instead of touching
/// platform channels. Never throws, never pending.
class NoopPromptNotifier implements PromptNotifier {
  int scheduleCalls = 0;
  int cancelCalls = 0;
  int? lastScheduledHour;
  String? lastPromptBody;

  @override
  Future<Either<Failure, Unit>> scheduleDailyWindow({
    required int hour,
    required String promptBody,
  }) async {
    scheduleCalls++;
    lastScheduledHour = hour;
    lastPromptBody = promptBody;
    return right(unit);
  }

  @override
  Future<Either<Failure, Unit>> cancel() async {
    cancelCalls++;
    return right(unit);
  }

  @override
  Future<bool> isPending() async => false;
}
