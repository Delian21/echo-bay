import 'package:flutter/material.dart';

import '../../../core/auth/auth_screens.dart' show showSignUpScreen;
import '../../../core/onboarding/guest_mode.dart';
import '../../../core/settings/app_settings_store.dart';
import '../../../injection.dart';

/// One slim line at the top of the Square, only for guests: what this mode
/// is, and the way out of it. Dismissible for good (the flag is stored), so
/// someone who understands it is never nagged again.
class GuestBanner extends StatefulWidget {
  const GuestBanner({super.key});

  @override
  State<GuestBanner> createState() => _GuestBannerState();
}

class _GuestBannerState extends State<GuestBanner> {
  bool _visible = false;

  AppSettingsStore? get _store =>
      sl.isRegistered<AppSettingsStore>() ? sl<AppSettingsStore>() : null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final store = _store;
    if (store == null) return;
    final active = await GuestMode.isActive(store);
    final dismissed = await GuestMode.bannerDismissed(store);
    if (!mounted) return;
    setState(() => _visible = active && !dismissed);
  }

  Future<void> _dismiss() async {
    setState(() => _visible = false);
    final store = _store;
    if (store != null) await GuestMode.dismissBanner(store);
  }

  Future<void> _signUp() async {
    final signed = await showSignUpScreen(context);
    if (!mounted) return;
    if (signed) setState(() => _visible = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primary.withValues(alpha: 0.10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                "You're trying Echo Bay as a guest. Sign the cover to keep "
                'your pages.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                  height: 1.3,
                ),
              ),
            ),
            TextButton(
              onPressed: _signUp,
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 44),
                foregroundColor: theme.colorScheme.primary,
              ),
              child: const Text('Sign the cover'),
            ),
            IconButton(
              tooltip: 'Dismiss',
              onPressed: _dismiss,
              icon: const Icon(Icons.close_rounded, size: 18),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}
