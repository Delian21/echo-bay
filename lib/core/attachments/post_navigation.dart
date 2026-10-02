import 'package:flutter/material.dart';

import '../../injection.dart';
import '../../features/square/domain/repositories/feed_repository.dart';
import '../../features/square/ui/square_feed_view.dart' show SquareDayViewPage;
import '../router/app_router.dart';
import '../router/route_push.dart';

/// Opens a Square post in context (its journal day view) from anywhere —
/// chat bubbles, keepsake wall, notifications. The navigation shape is
/// pushed here once so features never import each other's widgets: the
/// caller needs only the post id and a FeedRepository in DI.
///
/// This lives next to the domain contracts it consumes; it is glue, not
/// feature UI.
Future<void> openSquarePost(BuildContext context, String postId) async {
  FeedRepository? repo;
  try {
    repo = sl.isRegistered<FeedRepository>() ? sl<FeedRepository>() : null;
  } on Object {
    repo = null;
  }
  if (repo == null || !context.mounted) return;

  // Find the post (tombstones included — a shared post that was since
  // deleted still opens to its day, where the day view shows what
  // remains; the card itself already explains a faded post).
  final either = await repo.findPostById(postId);
  final post = either.fold((_) => null, (p) => p);
  final day = post?.createdAt ?? DateTime.now();
  if (!context.mounted) return;
  await pushDestination(
    context,
    AppRoutes.squareDay(day),
    fallback: () => SquareDayViewPage(repository: repo!, day: day),
  );
}
