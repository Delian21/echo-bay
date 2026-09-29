import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/post.dart';
import '../services/post_share_card.dart';

/// Renders a post as a shareable PNG (polaroid on sepia paper).
/// Returns the raw bytes; the presentation layer decides whether they
/// go to the system share sheet (mobile) or a browser download (web).
class SharePostAsImage implements UseCase<Uint8List, Post> {
  SharePostAsImage();

  @override
  Future<Either<Failure, Uint8List>> call(Post params) async {
    try {
      final bytes = await renderPostShareCard(params);
      if (bytes.isEmpty) {
        return left(const CacheFailure(message: 'share card rendered empty'));
      }
      return right(bytes);
    } on Object catch (e) {
      return left(CacheFailure(message: 'share card failed', cause: e));
    }
  }
}
