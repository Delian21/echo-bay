import 'package:equatable/equatable.dart';

/// One emoji reaction on one message (Discord lesson: lightweight
/// interaction is a sync row, not a UI ephemeral). Toggling creates or
/// removes the row; the row's sync status lives in the data layer.
class Reaction extends Equatable {
  const Reaction({
    required this.id,
    required this.messageId,
    required this.userId,
    required this.reaction,
  });

  final String id;
  final String messageId;
  final String userId;

  /// Emoji shortcode ('heart', 'laugh', ...) — presentation maps it to
  /// a glyph so the domain never imports Flutter.
  final String reaction;

  @override
  List<Object?> get props => [id, messageId, userId, reaction];
}
