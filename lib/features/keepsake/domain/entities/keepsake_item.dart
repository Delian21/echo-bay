import 'package:equatable/equatable.dart';

import '../../../../core/database/app_database.dart' show KeepsakeKind;

/// One item on the keepsake wall. Pure domain — no drift.
class KeepsakeItem extends Equatable {
  const KeepsakeItem({
    required this.id,
    required this.kind,
    required this.posX,
    required this.posY,
    required this.rotation,
    required this.pinnedAt,
    this.postId,
    this.noteText,
    this.strungTo,
    this.unpinnedAt,
  });

  final String id;
  final KeepsakeKind kind;

  /// Square post id when [kind] == post.
  final String? postId;

  /// Handwritten note text when [kind] == note.
  final String? noteText;

  /// Board-relative position of the item's top-left corner, 0..1.
  /// Stored as fractions (not pixels) so the board scales across
  /// phone and desktop without re-layout.
  final double posX;
  final double posY;

  /// Tilt in radians.
  final double rotation;

  /// Id of the item this one is strung to (wobbly ink string), or null.
  final String? strungTo;
  final DateTime pinnedAt;

  /// Soft-unpin tombstone (v14). Non-null = off the board since then;
  /// time travel uses it to reconstruct past boards.
  final DateTime? unpinnedAt;

  KeepsakeItem copyWith({
    double? posX,
    double? posY,
    double? rotation,
    String? strungTo,
    Object? clearString = _sentinel,
  }) {
    return KeepsakeItem(
      id: id,
      kind: kind,
      postId: postId,
      noteText: noteText,
      posX: posX ?? this.posX,
      posY: posY ?? this.posY,
      rotation: rotation ?? this.rotation,
      strungTo: clearString == _sentinel ? (strungTo ?? this.strungTo) : null,
      pinnedAt: pinnedAt,
      unpinnedAt: unpinnedAt,
    );
  }

  static const _sentinel = Object();

  @override
  List<Object?> get props => [
        id, kind, postId, noteText,
        posX, posY, rotation, strungTo, pinnedAt, unpinnedAt,
      ];
}
