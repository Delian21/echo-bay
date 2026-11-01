import 'package:flutter/material.dart';

import '../../../core/auth/auth_screens.dart'
    show showSignInScreen, showSignUpScreen;
import '../../../core/design_system/sketch_kit.dart';
import '../../../core/onboarding/guest_mode.dart';
import '../../../core/profile/profile_controller.dart';
import '../../../core/profile/user_profile.dart';
import '../../../core/settings/app_settings_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../injection.dart';

/// The front porch: what someone sees the first time they open Echo Bay.
///
/// Shown only from the launch gate, and only when this device has never
/// signed a cover and is not already browsing as a guest. Everything here
/// is static — the previews are drawn from widgets, never from anyone's
/// real pages — and every button leads into the existing flows:
/// [showSignUpScreen], [showSignInScreen], or guest mode.
class LandingPage extends StatelessWidget {
  const LandingPage({super.key, required this.onEntered});

  /// Called once the visitor is inside: signed up, signed in, or trying
  /// the app as a guest. The gate swaps to the Square.
  final VoidCallback onEntered;

  static const String tagline = 'A small place for evening pages.';

  Future<void> _signUp(BuildContext context) async {
    final signed = await showSignUpScreen(context);
    if (signed) onEntered();
  }

  Future<void> _signIn(BuildContext context) async {
    final signed = await showSignInScreen(context);
    if (signed) onEntered();
  }

  /// Try it first: a local guest profile, straight into the Square with
  /// the same sample content a new install seeds.
  Future<void> _tryItFirst(BuildContext context) async {
    if (!sl.isRegistered<AppSettingsStore>()) return;
    final store = sl<AppSettingsStore>();
    await GuestMode.start(store);
    if (sl.isRegistered<ProfileController>()) {
      sl<ProfileController>().update(const UserProfile(
        displayName: 'Guest',
        handle: 'guest',
      ));
    }
    onEntered();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 600;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Echo Bay',
                    textAlign: TextAlign.center,
                    style: kHandwrittenTextStyle.copyWith(
                      fontSize: 48,
                      height: 1.1,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tagline,
                    textAlign: TextAlign.center,
                    style: kHandwrittenTextStyle.copyWith(
                      fontSize: 21,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 26),
                  _Previews(wide: wide),
                  const SizedBox(height: 26),
                  const _FeatureLines(),
                  const SizedBox(height: 26),
                  FilledButton(
                    onPressed: () => _signUp(context),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      textStyle: kHandwrittenTextStyle.copyWith(
                        fontSize: 21,
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                    child: const Text('Sign the cover'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () => _tryItFirst(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      side: BorderSide(color: theme.colorScheme.primary),
                      foregroundColor: theme.colorScheme.primary,
                    ),
                    child: const Text('Try it first'),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: TextButton(
                      onPressed: () => _signIn(context),
                      child: const Text('Open your sketchbook'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Four phone-shaped previews of the app, drawn from widgets — no real
/// person's pages are ever used. On phones they scroll sideways; on wide
/// screens all four sit in one row inside the column.
class _Previews extends StatelessWidget {
  const _Previews({required this.wide});

  final bool wide;

  static const double _mobileWidth = 172;
  static const double _aspect = 0.48;

  @override
  Widget build(BuildContext context) {
    const previews = <(String, Widget)>[
      ('The Square', _FeedPreview()),
      ('A polaroid', _PolaroidPreview()),
      ('The Keepsake wall', _KeepsakePreview()),
      ('The Vault', _ChatPreview()),
    ];

    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < previews.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: AspectRatio(
                aspectRatio: _aspect,
                child: _PhoneFrame(child: previews[i].$2),
              ),
            ),
          ],
        ],
      );
    }

    return SizedBox(
      height: _mobileWidth / _aspect,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: previews.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) => SizedBox(
          width: _mobileWidth,
          child: _PhoneFrame(child: previews[index].$2),
        ),
      ),
    );
  }
}

/// A phone: rounded ink edge, paper screen, clipped content.
class _PhoneFrame extends StatelessWidget {
  const _PhoneFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(5),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: ColoredBox(
          color: theme.colorScheme.surface,
          // Each mock screen is composed once at this fixed size and then
          // scaled to whatever the frame's width happens to be (the wide
          // layout fits four in 480px). Scaling, never reflowing, is what
          // keeps the four previews pixel-identical on phone and desktop.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: 168,
              height: 340,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Tiny shared bits for the mock screens below — decorative only.
Widget _bar(BuildContext context, {double widthFactor = 1, double height = 5}) {
  final theme = Theme.of(context);
  return Align(
    alignment: Alignment.centerLeft,
    child: FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    ),
  );
}

Widget _dot(BuildContext context, double size, {Color? color}) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color ??
            Theme.of(context)
                .colorScheme
                .onSurfaceVariant
                .withValues(alpha: 0.35),
        shape: BoxShape.circle,
      ),
    );

class _FeedPreview extends StatelessWidget {
  const _FeedPreview();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(9, 10, 9, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'The Square',
            style: kHandwrittenTextStyle.copyWith(
              fontSize: 13,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          for (final post in const [
            ('Kai', 'Golden hour waited for me on the bridge.'),
            ('Nova', 'Fog in the valley all morning, like it paid rent.'),
          ]) ...[
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.borderPlain),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _dot(context, 12, color: theme.colorScheme.primary),
                      const SizedBox(width: 5),
                      Text(
                        post.$1,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    post.$2,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: kHandwrittenTextStyle.copyWith(
                      fontSize: 11,
                      height: 1.15,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _PolaroidPreview extends StatelessWidget {
  const _PolaroidPreview();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Transform.rotate(
        angle: -0.03,
        child: Container(
          margin: const EdgeInsets.all(10),
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 16),
          decoration: BoxDecoration(
            color: const Color(0xFFFBF4E4), // print paper, both themes
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.shadow.withValues(alpha: 0.18),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    // A dusk sky and water — nobody's photograph.
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF8FA3B8), Color(0xFF24566E)],
                    ),
                  ),
                  child: Align(
                    alignment: const Alignment(0.45, -0.55),
                    child: _dot(context, 22, color: const Color(0xFFF6D9A0)),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'the pier, after the rain',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: kHandwrittenTextStyle.copyWith(
                  fontSize: 11,
                  color: const Color(0xFF2B2A26),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KeepsakePreview extends StatelessWidget {
  const _KeepsakePreview();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return ColoredBox(
      color: dark ? const Color(0xFF3B2E24) : const Color(0xFFC8A67A),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Keepsakes',
              style: kHandwrittenTextStyle.copyWith(
                fontSize: 13,
                color: dark ? const Color(0xFFF3E6CF) : const Color(0xFF3A2A1C),
              ),
            ),
            const SizedBox(height: 7),
            for (final note in const ['first page', 'the bench by the pier'])
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBF4E4),
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  note,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: kHandwrittenTextStyle.copyWith(
                    fontSize: 11,
                    color: const Color(0xFF2B2A26),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChatPreview extends StatelessWidget {
  const _ChatPreview();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget bubble(String text, {required bool mine}) => Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
            constraints: const BoxConstraints(maxWidth: 120),
            decoration: BoxDecoration(
              color: mine
                  ? theme.colorScheme.primary
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 9,
                height: 1.2,
                color: mine
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.all(9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _dot(context, 12, color: theme.colorScheme.primary),
              const SizedBox(width: 5),
              Text(
                'The Vault',
                style: kHandwrittenTextStyle.copyWith(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          bubble('Left the light on for you.', mine: false),
          bubble('Walking back now.', mine: true),
          bubble('Take the long way.', mine: false),
          const Spacer(),
          _bar(context, height: 8),
        ],
      ),
    );
  }
}

/// Three short promises, each with one of the app's own hand-drawn icons.
class _FeatureLines extends StatelessWidget {
  const _FeatureLines();

  static const _lines = <(SketchIconKind, String)>[
    (
      SketchIconKind.clockTick,
      'Post it, let it go: squares can fade after 24 hours.',
    ),
    (SketchIconKind.rewindSpiral, 'Time travel: wander back through old pages.'),
    (SketchIconKind.padlock, 'A private Vault, just the people you choose.'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (icon, line) in _lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SketchIcon(
                  kind: icon,
                  size: 26,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    line,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.35,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
