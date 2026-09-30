import 'package:flutter/material.dart';

import '../../features/profile/ui/profile_page.dart';
import '../design_system/sketch_kit.dart';
import '../profile/profile_controller.dart';
import '../settings/app_settings_store.dart';
import '../theme/app_theme.dart';
import '../../features/square/domain/repositories/feed_repository.dart';
import '../../injection.dart';

/// First-run onboarding: a three-page handwritten intro (the Square, the
/// Vault, the rewind) plus name/avatar setup, shown once. Tracked in the
/// settings KV table (key [completedKey]); "Replay intro" in Settings
/// clears the flag and re-opens the flow. Clear-all-data wipes the key,
/// so a wiped app lands here again — first run all over.
class FirstRun {
  static const completedKey = 'onboarding_completed_v1';

  static Future<bool> isCompleted(AppSettingsStore store) async {
    final value = await store.readString(completedKey);
    return value == 'true';
  }

  static Future<void> markCompleted(AppSettingsStore store) =>
      store.writeString(completedKey, 'true');

  static Future<void> reset(AppSettingsStore store) =>
      store.writeString(completedKey, 'false');

  /// Runs the flow if it has not completed yet. Called once at app start
  /// (after DI) by the shell host. Silently no-ops when DI is absent
  /// (standalone widget tests pump SuperApp without a settings store).
  static Future<void> runIfNeeded(BuildContext context) async {
    if (!sl.isRegistered<AppSettingsStore>()) return;
    final store = sl<AppSettingsStore>();
    if (await isCompleted(store)) return;
    if (!context.mounted) return;
    await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<
        void>(
      fullscreenDialog: true,
      builder: (_) => const FirstRunFlow(),
    ));
  }
}

/// The full-screen flow: 3 intro pages + profile setup. Skippable at
/// every step; the skip still marks completion (rule: no nagging).
class FirstRunFlow extends StatefulWidget {
  const FirstRunFlow({super.key});

  @override
  State<FirstRunFlow> createState() => _FirstRunFlowState();
}

class _FirstRunFlowState extends State<FirstRunFlow> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = <(SketchIconKind, String, String)>[
    (
      SketchIconKind.slateGrid,
      'The Square',
      'One photo, one sentence, a day at a time. Post in seconds — your squares gather into a journal.',
    ),
    (
      SketchIconKind.padlock,
      'The Vault & the Hallway',
      'Private messages with the people you choose, and dorms where the whole town talks.',
    ),
    (
      SketchIconKind.rewindSpiral,
      'Nothing is forever',
      'Deleted something? The rewind spiral takes it back. Posts can fade in a day — or stay for good.',
    ),
  ];

  void _next() {
    if (_page < _pages.length) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    await FirstRun.markCompleted(sl<AppSettingsStore>());
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final golden = GoldenHourExtension.of(context);
    final useInk = golden.enabled;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                child: const Text('Skip'),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length + 1,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, index) {
                  if (index < _pages.length) {
                    final (icon, title, body) = _pages[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SketchIcon(kind: icon, size: 72, seed: index * 31 + 7),
                          const SizedBox(height: 28),
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: useInk
                                ? kHandwrittenTextStyle.copyWith(
                                    fontSize: 36,
                                    color: theme.colorScheme.onSurface,
                                  )
                                : theme.textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            body,
                            textAlign: TextAlign.center,
                            style: useInk
                                ? kHandwrittenTextStyle.copyWith(
                                    fontSize: 19,
                                    height: 1.5,
                                    color:
                                        theme.colorScheme.onSurfaceVariant,
                                  )
                                : theme.textTheme.bodyLarge?.copyWith(
                                    height: 1.5,
                                    color:
                                        theme.colorScheme.onSurfaceVariant,
                                  ),
                          ),
                        ],
                      ),
                    );
                  }
                  // Last page: profile setup (name + avatar reuse the
                  // profile page itself — one editing surface).
                  return _SetupProfileStep(onDone: _finish);
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i <= _pages.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 12),
                    width: i == _page ? 18 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: i == _page
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  child: Text(_page < _pages.length ? 'Next' : 'Start writing'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The "who are you" step: the profile page itself, embedded — the same
/// editing surface Settings uses, so nothing is learned twice.
class _SetupProfileStep extends StatelessWidget {
  const _SetupProfileStep({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final controller =
        sl.isRegistered<ProfileController>() ? sl<ProfileController>() : null;
    if (controller == null) {
      // DI-less tests: skip setup entirely.
      return const Center(child: Text('Welcome to Echo Bay.'));
    }
    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(40, 8, 40, 0),
            child: Text(
              'What should the town call you?',
              textAlign: TextAlign.center,
              style: kHandwrittenTextStyle.copyWith(
                fontSize: 26,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          ProfilePage(
            profileController: controller,
            feedRepository:
                sl.isRegistered<FeedRepository>() ? sl<FeedRepository>() : null,
            embedInOnboarding: true,
          ),
        ],
      ),
    );
  }
}
