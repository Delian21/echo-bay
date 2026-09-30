import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../injection.dart';
import 'version_checker.dart';

/// The "new version available" banner.
///
/// Mounted once above the router (MaterialApp's `builder`) so it
/// floats over every screen. Appears only when [VersionChecker] has
/// detected a fresh deploy; "Refresh" drops the old service worker +
/// caches and reloads into the new build, "Not now" dismisses until
/// the next deploy is detected. On native the checker never fires, so
/// this renders nothing.
class VersionBanner extends StatelessWidget {
  const VersionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();
    final checker = sl.isRegistered<VersionChecker>()
        ? sl<VersionChecker>()
        : null;
    if (checker == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: checker,
      builder: (context, _) {
        if (!checker.updateAvailable) return const SizedBox.shrink();
        return Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _VersionPill(checker: checker),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _VersionPill extends StatelessWidget {
  const _VersionPill({required this.checker});

  final VersionChecker checker;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primaryContainer,
      elevation: 3,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'A new page was inked — refresh to see it.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.tonal(
              onPressed: () => unawaited(checker.applyUpdate()),
              child: const Text('Refresh'),
            ),
            IconButton(
              tooltip: 'Dismiss until the next update',
              onPressed: checker.dismiss,
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
