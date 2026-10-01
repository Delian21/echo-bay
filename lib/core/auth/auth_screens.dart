import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../injection.dart';
import '../error/failures.dart';
import '../io/platform_io.dart';
import '../profile/profile_controller.dart';
import '../profile/user_profile.dart';
import '../design_system/sketch_kit.dart';
import '../theme/app_theme.dart';
import 'auth_repository.dart';

/// Sign the cover (first-time sign-up) and Open your sketchbook
/// (sign-in to the profile that already lives on this device). One file
/// because the two screens share every visual: paper background, inked
/// card border, official provider wordings left verbatim.
///
/// No widget here touches drift: the screens talk to AuthRepository and
/// ProfileController only.

/// Which auth screen a gate should open with. A device whose cover was
/// ever signed (surviving sign-out) opens an existing sketchbook; a
/// fresh device signs the cover.
Future<bool> _deviceHasCover() async {
  final auth = sl.isRegistered<AuthRepository>() ? sl<AuthRepository>() : null;
  if (auth == null) return false;
  return auth.hasCoverBeenSigned();
}

/// Entry the first-run flow and Clear all data use. Chooses which
/// screen to show based on whether this device has ever signed a cover
/// — never signs anyone out implicitly.
Future<void> showAuthFlow(BuildContext context) async {
  final hasCover = await _deviceHasCover();
  if (!context.mounted) return;
  await Navigator.of(context).push<void>(MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => hasCover
        ? const SignInScreen()
        : const SignUpScreen(comesFromOnboarding: false),
  ));
}

/// The boot gate: pushes the right auth screen over the shell and waits
/// until the book is signed. Re-reads the cover flag after pop so a
/// skipped flow still lands correctly.
Future<void> showAuthGate(BuildContext context) async {
  final hasCover = await _deviceHasCover();
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

/// A ruled-line input, like writing on the page: handwritten label
/// resting on a single ink rule, no box. Used only by the auth screens —
/// the app's ordinary fields keep the themed filled boxes.
class _RuledField extends StatelessWidget {
  const _RuledField({
    required this.controller,
    required this.label,
    this.helper,
    this.keyboardType,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? helper;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final golden = GoldenHourExtension.of(context);
    final useInk = golden.enabled;
    final rule = useInk
        ? theme.colorScheme.onSurface.withValues(alpha: 0.55)
        : theme.colorScheme.outlineVariant;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: useInk
          ? kHandwrittenTextStyle.copyWith(
              fontSize: 19,
              color: theme.colorScheme.onSurface,
            )
          : theme.textTheme.bodyMedium,
      decoration: InputDecoration(
        filled: false,
        labelText: label,
        labelStyle: useInk
            ? kHandwrittenTextStyle.copyWith(
                fontSize: 17,
                color: theme.colorScheme.onSurfaceVariant,
              )
            : null,
        helperText: helper,
        helperStyle: useInk
            ? kHandwrittenTextStyle.copyWith(
                fontSize: 14,
                color: theme.colorScheme.onSurfaceVariant,
              )
            : null,
        // The ruled line: an underline, heavier than the hairline
        // default — pencil pressure.
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: rule, width: 1.4),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
        ),
      ),
    );
  }
}

/// A taped-on polaroid: white frame around the avatar, one strip of
/// paper tape across the top corner — the cover's pasted-on face.
class _TapedPolaroid extends StatelessWidget {
  const _TapedPolaroid({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.4),
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.shadow.withValues(alpha: 0.12),
                blurRadius: 4,
                offset: const Offset(1, 2),
              ),
            ],
          ),
          child: child,
        ),
        // Paper tape, laid slightly askew.
        Positioned(
          top: -8,
          left: 18,
          child: Transform.rotate(
            angle: -0.12,
            child: Container(
              width: 44,
              height: 16,
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.9),
            ),
          ),
        ),
      ],
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

  /// The cover shows a face: picked here, committed to the profile, and
  /// carried into the app. The setup step's avatar (if any) pre-fills it.
  String? _avatarPath;
  final ImagePicker _picker = ImagePicker();
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    _avatarPath = _profile?.profile.avatarPath;
  }

  Future<void> _pickAvatar() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (picked == null) return;
      setState(() => _avatarPath = picked.path);
      _profile?.update(_profile.profile.copyWith(avatarPath: picked.path));
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the image picker')),
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

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
        // The face on the cover: a taped-on polaroid, tap to change.
        Center(
          child: GestureDetector(
            onTap: _pickAvatar,
            child: _TapedPolaroid(
              child: Stack(
                children: [
                  _CoverAvatar(
                    initials: _name.text.trim().isEmpty
                        ? '?'
                        : _name.text.trim().characters.first.toUpperCase(),
                    avatarPath: _avatarPath,
                    accent: _profile?.profile.accentColor ??
                        Theme.of(context).colorScheme.primary,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: _picking
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.add_a_photo_outlined,
                              size: 15, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        // "This sketchbook belongs to ___" — the name written on the
        // ruled line, not typed into a box.
        _RuledField(
          controller: _name,
          label: 'This sketchbook belongs to',
          onChanged: (_) => setState(() {}), // initials keep up
        ),
        const SizedBox(height: 12),
        _RuledField(
          controller: _email,
          label: 'Email (a label, for later)',
          helper: 'Nothing is sent anywhere yet.',
          keyboardType: TextInputType.emailAddress,
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!,
              style: TextStyle(color: theme.colorScheme.error)),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _submit,
          style: FilledButton.styleFrom(
            textStyle: GoldenHourExtension.of(context).enabled
                ? kHandwrittenTextStyle.copyWith(
                    fontSize: 21,
                    color: Theme.of(context).colorScheme.onPrimary,
                  )
                : null,
          ),
          // The confirm action reads as a signature on the line.
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

  /// The sketchbook that lives on this device, shown as a book spine —
  /// tap it to open. Null on a device with no profile yet (then the
  /// email field leads).
  UserProfile? _book;

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
    final profile =
        sl.isRegistered<ProfileController>() ? sl<ProfileController>().profile : null;
    if (!mounted) return;
    setState(() {
      _book = (profile?.displayName.isNotEmpty ?? false) ? profile : null;
      _knownEmail = email;
      if (email != null && _email.text.isEmpty) _email.text = email;
    });
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  /// Tap the shelf spine: open the book directly. The local stage
  /// verifies nothing — the sketchbook already lives on this device.
  Future<void> _openBook() async {
    final auth = sl.isRegistered<AuthRepository>() ? sl<AuthRepository>() : null;
    if (auth == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final email = _knownEmail ??
        (sl.isRegistered<ProfileController>()
            ? sl<ProfileController>().profile.displayName
            : '');
    final result = await auth.signIn(
      AuthCredentials(method: AuthMethod.email, email: email),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    result.fold(
      (Failure f) => setState(() => _error = f.message ?? 'Try again?'),
      (_) => Navigator.of(context).pop(),
    );
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
        // The shelf: the sketchbook kept on this device, spine out.
        // Tapping it fills nothing in and asks nothing — just opens.
        if (_book != null) ...[
          _ShelfBook(
            name: _book!.displayName,
            avatarPath: _book!.avatarPath,
            accent: _book!.accentColor,
            busy: _busy,
            onOpen: _openBook,
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'or enter your label below',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        _RuledField(
          controller: _email,
          label: 'Email',
          helper: _knownEmail == null
              ? 'The label your cover was signed with.'
              : 'Yours is filled in — just tap below.',
          keyboardType: TextInputType.emailAddress,
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

/// One sketchbook on the shelf, spine out: the avatar as the cover
/// motif, the name along the spine. Tapping it opens the book — no
/// form, no password.
class _ShelfBook extends StatelessWidget {
  const _ShelfBook({
    required this.name,
    required this.avatarPath,
    required this.accent,
    required this.busy,
    required this.onOpen,
  });

  final String name;
  final String? avatarPath;
  final Color accent;
  final bool busy;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final golden = GoldenHourExtension.of(context);
    final useInk = golden.enabled;
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: busy ? null : onOpen,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.fromBorderSide(
              BorderSide(
                color: useInk
                    ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                    : theme.colorScheme.outlineVariant,
              ),
            ),
          ),
          child: Row(
            children: [
              _CoverAvatar(
                initials: name.characters.first.toUpperCase(),
                avatarPath: avatarPath,
                accent: accent,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: useInk
                          ? kHandwrittenTextStyle.copyWith(
                              fontSize: 20,
                              color: theme.colorScheme.onSurface,
                            )
                          : theme.textTheme.titleMedium,
                    ),
                    Text(
                      'kept on this device',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              SketchGlyph(
                kind: SketchIconKind.arrowUpRight,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
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

/// The cover's face: the picked photo, or ink initials on the accent
/// color — same rendering rules as the profile avatar, so the two never
/// disagree.
class _CoverAvatar extends StatelessWidget {
  const _CoverAvatar({
    required this.initials,
    required this.avatarPath,
    required this.accent,
  });

  final String initials;
  final String? avatarPath;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (avatarPath != null && avatarPath!.isNotEmpty) {
      return CircleAvatar(
        radius: 44,
        backgroundImage: platformImageProvider(avatarPath!),
        onBackgroundImageError: (_, __) {},
      );
    }
    final derivation =
        AccentDerivation.of(accent, Theme.of(context).brightness);
    return CircleAvatar(
      radius: 44,
      backgroundColor: derivation.container,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          color: derivation.onContainer,
        ),
      ),
    );
  }
}
