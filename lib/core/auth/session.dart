import 'package:equatable/equatable.dart';

/// The authenticated local session. The identity is an **opaque id** —
/// by design it carries no meaning to any server (Signal posture:
/// minimize what the backend can learn, including who talks to whom).
/// Nothing else in the app is allowed to hardcode or interpret a user
/// id; everything consumes this session.
class Session extends Equatable {
  const Session({
    required this.userId,
    required this.createdAt,
    this.email,
  });

  /// Opaque, randomly generated, device-stable identifier. Not a phone
  /// number, not an email, not derivable from either.
  final String userId;

  final DateTime createdAt;

  /// Optional email label from Sign the cover. A label, not a
  /// credential: the local stage verifies nothing, and the real backend
  /// will treat it as the account key instead.
  final String? email;

  Session copyWith({String? email}) => Session(
        userId: userId,
        createdAt: createdAt,
        email: email ?? this.email,
      );

  @override
  List<Object?> get props => [userId, createdAt, email];
}
