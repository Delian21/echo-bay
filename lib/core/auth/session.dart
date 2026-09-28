import 'package:equatable/equatable.dart';

/// The authenticated local session. The identity is an **opaque id** —
/// by design it carries no meaning to any server (Signal posture:
/// minimize what the backend can learn, including who talks to whom).
/// Nothing else in the app is allowed to hardcode or interpret a user
/// id; everything consumes this session.
class Session extends Equatable {
  const Session({required this.userId, required this.createdAt});

  /// Opaque, randomly generated, device-stable identifier. Not a phone
  /// number, not an email, not derivable from either.
  final String userId;

  final DateTime createdAt;

  @override
  List<Object?> get props => [userId, createdAt];
}
