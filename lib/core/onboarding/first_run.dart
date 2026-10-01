import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/profile/ui/profile_page.dart';
import '../design_system/sketch_kit.dart';
import '../profile/profile_controller.dart';
import '../profile/user_profile.dart' show kAccentPalette;
import '../settings/app_settings_store.dart';
import '../theme/app_theme.dart';
import '../../features/square/domain/repositories/feed_repository.dart';
import '../../injection.dart';
import '../router/app_router.dart';
import '../auth/auth_repository.dart' show AuthRepository;
import '../auth/auth_screens.dart'
    show showAuthGate, showSignUpAfterOnboarding;

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
  ///
  /// Pushes through [rootNavigatorKey] — the caller's context sits above
  /// MaterialApp where no Navigator exists, and `Navigator.of` there
  /// crashed release builds at boot (debug shows a friendly error;
  /// release throws "null check operator used on a null value").
  static Future<void> runIfNeeded(BuildContext context) async {
    if (!sl.isRegistered<AppSettingsStore>()) return;
    final store = sl<AppSettingsStore>();
    final completed = await isCompleted(store);
    if (!completed) {
      final navigator = rootNavigatorKey.currentState;
      if (navigator == null) return; // router not built yet; skip quietly
      await navigator.push(MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => const FirstRunFlow(),
      ));
      // The flow's last step is Sign the cover; if it completed, the
      // book is now signed and the gate below is satisfied.
    }
    // Auth gate: an unsigned cover (no email label) must sign or open
    // before reaching the app. Signing out (Close the book) clears the
    // label, so the same gate handles sign-in on the next boot.
    if (!sl.isRegistered<AuthRepository>()) return;
    final session = await sl<AuthRepository>().currentUser();
    final signed = session.fold((_) => false, (s) => s.email != null);
    if (signed) return;
    final navigator = rootNavigatorKey.currentState;
    if (navigator == null || !navigator.mounted) return;
    await showAuthGate(navigator.context);
  }
}

/// The full-screen flow: 3 intro pages + profile setup. Skippable at
/// every step; the skip still marks completion (rule: no nagging).
class FirstRunFlow extends StatefulWidget {
  const FirstRunFlow({super.key});

  /// The "who are you" step's scroll structure, shared with the
  /// regression test (onboarding_setup_step_test.dart). CustomScrollView
  /// — not SingleChildScrollView+Column: ProfilePage is a ListView, and
  /// a ListView inside a Column inside an unbounded scroll view gets
  /// zero height, which painted this step blank. The heading is a sliver
  /// header; the shrink-wrapped profile list scrolls beneath it.
  static Widget setupProfileStep({
    required ProfileController controller,
    FeedRepository? feedRepository,
    Widget? header,
  }) {
    return Builder(builder: (context) {
      return CustomScrollView(
        slivers: [
          if (header != null)
            SliverToBoxAdapter(child: header),
          SliverToBoxAdapter(
            child: Padding(
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
          ),
          SliverToBoxAdapter(
            child: ProfilePage(
              profileController: controller,
              feedRepository: feedRepository,
              embedInOnboarding: true,
            ),
          ),
        ],
      );
    });
  }

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
    // The flow hands off to Sign the cover — the personalization the
    // user just did (name, avatar, accent) is confirmed there, with the
    // email label as the only new field. Screens live in core/auth.
    Navigator.of(context).pop();
    unawaited(showSignUpAfterOnboarding(context));
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
            // Momentum, honestly earned: arriving here means the app is
            // already set up and seeded — that's step one, done. The
            // bar therefore opens at 20%, never at zero.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.2, end: 0.2 + 0.8 * _page / _pages.length),
                duration: const Duration(milliseconds: 280),
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value.clamp(0.0, 1.0),
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(3),
                ),
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
/// editing surface Settings uses, so nothing is learned twice. Above it
/// sits the setup phase's customization: the accent-color picker, so the
/// app is already theirs before they sign the cover.
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
    return FirstRunFlow.setupProfileStep(
      controller: controller,
      feedRepository:
          sl.isRegistered<FeedRepository>() ? sl<FeedRepository>() : null,
      header: const _SetupAccentPicker(),
    );
  }
}

/// The setup phase's customization row: pick your ink. Reads and writes
/// through the ProfileController — the theme cross-fades live.
class _SetupAccentPicker extends StatelessWidget {
  const _SetupAccentPicker();

  @override
  Widget build(BuildContext context) {
    final controller = sl.isRegistered<ProfileController>()
        ? sl<ProfileController>()
        : null;
    if (controller == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final golden = GoldenHourExtension.of(context);
    final useInk = golden.enabled;
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 4, 40, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pick your ink',
            style: useInk
                ? kHandwrittenTextStyle.copyWith(
                    fontSize: 20, color: theme.colorScheme.onSurface)
                : theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          AnimatedBuilder(
            animation: controller,
            builder: (context, _) => Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final color in kAccentPalette)
                  InkWell(
                    borderRadius: BorderRadius.circular(28),
                    onTap: () => controller
                        .update(controller.profile.copyWith(accentColor: color)),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: controller.profile.accentColor.toARGB32() ==
                                color.toARGB32()
                            ? Border.all(
                                color: theme.colorScheme.onSurface, width: 3)
                            : null,
                      ),
                      child: controller.profile.accentColor.toARGB32() ==
                              color.toARGB32()
                          ? const Icon(Icons.check_rounded,
                              color: Colors.white, size: 22)
                          : null,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }
}
