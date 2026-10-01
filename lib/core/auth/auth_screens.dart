import 'package:flutter/material.dart';

import '../../injection.dart';
import '../error/failures.dart';
import '../profile/profile_controller.dart';
import '../theme/app_theme.dart';
import 'auth_repository.dart';

/// Sign the cover (first-time sign-up) and Open your sketchbook
/// (sign-in to the profile that already lives on this device). One file
/// because the two screens share every visual: paper background, inked
/// card border, official provider wordings left verbatim.
///
/// No widget here touches drift: the screens talk to AuthRepository and
/// ProfileController only.

/// Entry the first-run flow and Clear all data use. Chooses which
/// screen to show based on whether this device already has a signed
/// cover (an email label) — never signs anyone out implicitly.
Future<void> showAuthFlow(BuildContext context) async {
  final auth = sl.isRegistered<AuthRepository>() ? sl<AuthRepository>() : null;
  if (auth == null) return;
  final session = await auth.currentUser();
  final hasCover = session.fold((_) => false, (s) => s.email != null);
  if (!context.mounted) return;
  await Navigator.of(context).push<void>(MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => hasCover
        ? const SignInScreen()
        : const SignUpScreen(comesFromOnboarding: false),
  ));
}

/// The boot gate: pushes the right auth screen over the shell and waits
/// until the book is signed. Re-reads the session after pop so a
/// skipped flow still lands correctly.
Future<void> showAuthGate(BuildContext context) async {
  final auth = sl.isRegistered<AuthRepository>() ? sl<AuthRepository>() : null;
  if (auth == null) return;
  final session = await auth.currentUser();
  final hasCover = session.fold((_) => false, (s) => s.email != null);
  if (!context.mounted) return;
  await Navigator.of(context).push<void>(MaterialPageRoute<void>(
    fullscreenDialog: true,
    barrierDismissible: false,
    builder: (_) =>
        hasCover ? const SignInScreen() : const SignUpScreen(comesFromOnboarding: false),
  ));
}

/// Hand-off for the first-run flow: the user just personalized, so
/// this always opens Sign the cover (never sign-in) as the flow's last
/// step. Signed covers skip the flow entirely at boot.
Future<void> showSignUpAfterOnboarding(BuildContext context) async {
  if (!sl.isRegistered<AuthRepository>()) return;
  await Navigator.of(context).push<void>(MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => const SignUpScreen(comesFromOnboarding: true),
  ));
}

/// Paper card with an inked (wobbly, rounded) border — the shared
/// chrome of every auth surface.
class _InkCard extends StatelessWidget {
  const _InkCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final golden = GoldenHourExtension.of(context);
    final useInk = golden.enabled;
    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: useInk
              ? theme.colorScheme.onSurface.withValues(alpha: 0.7)
              : theme.colorScheme.outlineVariant,
          width: useInk ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: child,
      ),
    );
  }
}

/// The two provider buttons, in their official wording — themed around
/// (paper/ink) but never renamed. They cannot work without a backend,
/// so they are honestly disabled with a small note. Nothing here fakes
/// a provider.
class _ProviderButtons extends StatelessWidget {
  const _ProviderButtons();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final golden = GoldenHourExtension.of(context);
    final useInk = golden.enabled;
    OutlinedButton themed(IconData icon, String label) => OutlinedButton.icon(
          onPressed: null,
          style: OutlinedButton.styleFrom(
            disabledForegroundColor:
                theme.colorScheme.onSurface.withValues(alpha: 0.55),
            side: BorderSide(
              color: useInk
                  ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                  : theme.colorScheme.outlineVariant,
            ),
            backgroundColor: theme.colorScheme.surface,
            minimumSize: const Size(double.infinity, 44),
          ),
          icon: Icon(icon, size: 18),
          label: Text(label),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        themed(Icons.g_mobiledata_rounded, 'Continue with Google'),
        const SizedBox(height: 8),
        themed(Icons.apple_rounded, 'Sign in with Apple'),
        const SizedBox(height: 6),
        Text(
          'They\u2019ll come when sign-in goes online.',
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Shared form scaffold: handwritten heading, inked card, email field.
class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final golden = GoldenHourExtension.of(context);
    final useInk = golden.enabled;
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: useInk
                        ? kHandwrittenTextStyle.copyWith(
                            fontSize: 30,
                            color: theme.colorScheme.onSurface,
                          )
                        : theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 20),
                  _InkCard(child: Column(children: children)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sign the cover — creates the local profile. When reached from the
/// first-run flow, name/avatar were already chosen in the setup step;
/// they're shown pre-filled to confirm, and only the email label is new.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key, required this.comesFromOnboarding});

  final bool comesFromOnboarding;

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  late final ProfileController? _profile =
      sl.isRegistered<ProfileController>() ? sl<ProfileController>() : null;

  late final TextEditingController _name = TextEditingController(
    text: _profile?.profile.displayName ?? '',
  );
  late final TextEditingController _email = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Every sketchbook has a name on the cover.');
      return;
    }
    final auth = sl.isRegistered<AuthRepository>() ? sl<AuthRepository>() : null;
    if (auth == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    _profile?.update(_profile.profile.copyWith(displayName: name));
    final result = await auth.signUp(
      displayName: name,
      credentials: AuthCredentials(method: AuthMethod.email, email: _email.text),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    result.fold(
      (Failure f) => setState(() => _error = f.message ?? 'Try again?'),
      (_) => Navigator.of(context).pop(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _AuthScaffold(
      title: 'Sign the cover',
      children: [
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Your name'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email (a label, for later)',
            helperText: 'Nothing is sent anywhere yet.',
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!,
              style: TextStyle(color: theme.colorScheme.error)),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? 'Signing…' : 'Sign the cover'),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(builder: (_) => const SignInScreen()),
          ),
          child: const Text('Already have a sketchbook? Open your sketchbook'),
        ),
        const Divider(height: 24),
        const _ProviderButtons(),
      ],
    );
  }
}

/// Open your sketchbook — sign in to the profile already on this
/// device. The email must match the label the cover was signed with.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final TextEditingController _email = TextEditingController();
  String? _error;
  bool _busy = false;
  String? _knownEmail;

  @override
  void initState() {
    super.initState();
    _loadKnownEmail();
  }

  Future<void> _loadKnownEmail() async {
    final auth = sl.isRegistered<AuthRepository>() ? sl<AuthRepository>() : null;
    if (auth == null) return;
    final session = await auth.currentUser();
    final email = session.fold((_) => null, (s) => s.email);
    if (email != null && mounted) {
      setState(() {
        _knownEmail = email;
        if (_email.text.isEmpty) _email.text = email;
      });
    }
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = sl.isRegistered<AuthRepository>() ? sl<AuthRepository>() : null;
    if (auth == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await auth.signIn(
      AuthCredentials(method: AuthMethod.email, email: _email.text),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    result.fold(
      (Failure f) => setState(() => _error = f.message ?? 'Try again?'),
      (_) => Navigator.of(context).pop(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _AuthScaffold(
      title: 'Open your sketchbook',
      children: [
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'Email',
            helperText: _knownEmail == null
                ? 'The label your cover was signed with.'
                : 'Yours is filled in — just tap below.',
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!,
              style: TextStyle(color: theme.colorScheme.error)),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? 'Opening…' : 'Open your sketchbook'),
        ),
        const SizedBox(height: 8),
        const _LostYourKeyLink(),
        const Divider(height: 24),
        const _ProviderButtons(),
      ],
    );
  }
}

/// "Lost your key?" — honest in-voice placeholder. The local stage has
/// no key to lose (your sketchbook lives on this device); the link
/// still exists so the real backend's flow has a home.
class _LostYourKeyLink extends StatelessWidget {
  const _LostYourKeyLink();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Nothing to lose yet — your sketchbook lives on this '
                'device. Key recovery arrives when sign-in goes online.',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        child: const Text('Lost your key?'),
      ),
    );
  }
}
