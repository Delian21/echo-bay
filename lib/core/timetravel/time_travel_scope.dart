import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// The single source of truth for "time travel" mode. Feature screens
/// read the as-of date from this scope — never threaded through widgets.
///
/// While [asOf] is non-null the app renders as it was at that instant.
/// All reads go through timestamp-filtered queries on existing tables;
/// writes are refused via [assertWritable] (time travel is read-only).
class TimeTravelScope extends InheritedNotifier<TimeTravelController> {
  const TimeTravelScope({
    super.key,
    required TimeTravelController controller,
    required super.child,
  }) : super(notifier: controller);

  static TimeTravelController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<TimeTravelScope>();
    assert(scope != null, 'TimeTravelScope missing above this context');
    return scope!.notifier!;
  }

  /// Convenience for non-widget callers (repositories, use cases).
  static TimeTravelController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<TimeTravelScope>()
      ?.notifier;
}

/// Holds the active as-of date. Null = the present.
class TimeTravelController extends ChangeNotifier {
  DateTime? _asOf;

  /// The as-of instant, or null when living in the present.
  DateTime? get asOf => _asOf;

  bool get isActive => _asOf != null;

  /// Enters time travel at [moment]. Clamps to the past; the present is
  /// not a destination.
  void enter(DateTime moment) {
    final now = DateTime.now();
    final clamped = moment.isAfter(now) ? now : moment;
    if (_asOf == clamped) return;
    _asOf = clamped;
    notifyListeners();
  }

  /// Moves the scrubber without exiting (drag updates).
  void scrub(DateTime moment) => enter(moment);

  /// Returns to the present. Callers pair this with the rewind effect.
  void exit() {
    if (_asOf == null) return;
    _asOf = null;
    notifyListeners();
  }

  /// True when the current as-of instant is before [timestamp] — i.e.
  /// [timestamp] has not happened yet in the traveled-to past.
  bool isFuture(DateTime timestamp) {
    final asOf = _asOf;
    return asOf != null && timestamp.isAfter(asOf);
  }
}
