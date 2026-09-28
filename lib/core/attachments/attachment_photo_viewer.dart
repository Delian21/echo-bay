import 'dart:io';

import 'package:flutter/material.dart';

/// Full-screen photo viewer for chat attachments: dark backdrop, the
/// photo centred and letterboxed, pinch to zoom, double-tap to toggle
/// 1×/2.5×, drag to pan while zoomed, tap the backdrop (or system back)
/// to dismiss. Open with [showAttachmentPhotoViewer].
class AttachmentPhotoViewer extends StatefulWidget {
  const AttachmentPhotoViewer({super.key, required this.path});

  final String path;

  static Future<void> show(BuildContext context, String path) {
    return Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      transitionDuration: const Duration(milliseconds: 180),
      reverseTransitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (_, animation, __) => FadeTransition(
        opacity: animation,
        child: AttachmentPhotoViewer(path: path),
      ),
    ));
  }

  @override
  State<AttachmentPhotoViewer> createState() => _AttachmentPhotoViewerState();
}

class _AttachmentPhotoViewerState extends State<AttachmentPhotoViewer> {
  final _transformation = TransformationController();
  TapDownDetails? _lastDoubleTapDown;

  @override
  void dispose() {
    _transformation.dispose();
    super.dispose();
  }

  void _onDoubleTap() {
    final zoomed = _transformation.value.getMaxScaleOnAxis() > 1.2;
    final clamped = Matrix4.identity();
    if (!zoomed) {
      // Zoom toward the tapped point — the natural "let me see that" gesture.
      final position = _lastDoubleTapDown?.localPosition ?? const Offset(0, 0);
      const scale = 2.5;
      clamped
        ..translateByDouble(-position.dx * (scale - 1), -position.dy * (scale - 1), 0, 1)
        ..scaleByDouble(scale, scale, 1, 1);
    }
    _transformation.value = clamped;
  }

  @override
  Widget build(BuildContext context) {
    final image = Image.file(
      File(widget.path),
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.image_not_supported_outlined,
              size: 44, color: Colors.white70),
          const SizedBox(height: 10),
          Text(
            'Photo unavailable',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.94),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        onDoubleTapDown: (details) => _lastDoubleTapDown = details,
        onDoubleTap: () {}, // consumed by the interactive child below
        child: InteractiveViewer(
          transformationController: _transformation,
          maxScale: 5,
          panEnabled: true,
          onInteractionStart: (_) {}, // backdrop tap only fires un-transformed
          child: Center(
            // The inner detector owns the double-tap; the outer one
            // handles single-tap dismiss. Both coexist because the inner
            // wins the arena on double-tap.
            child: GestureDetector(
              onDoubleTap: _onDoubleTap,
              onDoubleTapDown: (details) => _lastDoubleTapDown = details,
              child: image,
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens [path] full-screen. Convenience wrapper so call sites stay
/// one-liners.
Future<void> showAttachmentPhotoViewer(BuildContext context, String path) =>
    AttachmentPhotoViewer.show(context, path);
