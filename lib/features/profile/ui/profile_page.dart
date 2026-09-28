
import 'package:flutter/material.dart';

import '../../../core/design_system/sketch_kit.dart';
import '../../../core/io/platform_io.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/profile/profile_controller.dart';
import '../../../core/profile/user_profile.dart';
import '../../../core/theme/app_theme.dart';

/// Profile — view and edit the local user's identity: display name,
/// avatar, and the app's accent color. Edits apply live (the theme root
/// cross-fades to the new accent) and persist through the controller's
/// storage seam.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.profileController});

  final ProfileController profileController;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final TextEditingController _name =
      TextEditingController(text: widget.profileController.profile.displayName);
  late String? _avatarPath = widget.profileController.profile.avatarPath;
  late Color _accent = widget.profileController.profile.accentColor;

  final ImagePicker _picker = ImagePicker();
  bool _picking = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _commit() {
    widget.profileController.update(UserProfile(
      displayName:
          _name.text.trim().isEmpty ? 'You' : _name.text.trim(),
      avatarPath: _avatarPath,
      accentColor: _accent,
    ));
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
      if (picked == null) return; // user cancelled
      setState(() => _avatarPath = picked.path);
      _commit();
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

  void _clearAvatar() {
    setState(() => _avatarPath = null);
    _commit();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // -- identity preview ------------------------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _Avatar(
                      initials: _PreviewProfile.from(_name.text).initials(),
                      avatarPath: _avatarPath,
                      accent: _accent,
                      radius: 44,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _name.text.trim().isEmpty ? 'You' : _name.text.trim(),
                      style: theme.textTheme.headlineSmall,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // -- editable fields -------------------------------------------
          const _SectionHeader('Display name'),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: TextField(
                  controller: _name,
                  decoration: const InputDecoration(
                    hintText: 'Your name',
                    filled: false,
                    border: InputBorder.none,
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _commit(),
                ),
              ),
            ),
          ),

          const _SectionHeader('Profile picture'),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _pickAvatar,
                      child: _Avatar(
                        initials:
                            _PreviewProfile.from(_name.text).initials(),
                        avatarPath: _avatarPath,
                        accent: _accent,
                        radius: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        _picking
                            ? 'Opening picker…'
                            : _avatarPath == null
                                ? 'No picture — tap the avatar to choose one from your files'
                                : 'Picture set from a local file',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _picking ? null : _pickAvatar,
                      icon: const Icon(Icons.photo_outlined, size: 18),
                      label: const Text('Choose file'),
                    ),
                    if (_avatarPath != null)
                      IconButton(
                        tooltip: 'Use initials avatar',
                        onPressed: _clearAvatar,
                        icon: const SketchIcon(
                            kind: SketchIconKind.closeX, size: 18, seed: 19),
                      ),
                  ],
                ),
              ),
            ),
          ),

          const _SectionHeader('Accent color'),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final color in kAccentPalette)
                          _AccentSwatch(
                            color: color,
                            selected:
                                color.toARGB32() == _accent.toARGB32(),
                            onTap: () {
                              setState(() => _accent = color);
                              _commit();
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _ContainerPreview(accent: _accent),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.initials,
    required this.avatarPath,
    required this.accent,
    required this.radius,
  });

  final String initials;
  final String? avatarPath;
  final Color accent;
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (avatarPath != null && avatarPath!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,                        backgroundImage:
                            platformImageProvider(avatarPath!),
        onBackgroundImageError: (_, __) {},
      );
    }
    final derivation =
        AccentDerivation.of(accent, Theme.of(context).brightness);
    return CircleAvatar(
      radius: radius,
      backgroundColor: derivation.container,
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: TextStyle(
          fontSize: radius * 0.7,
          fontWeight: FontWeight.w800,
          color: derivation.onContainer,
        ),
      ),
    );
  }
}

/// Live preview of the in-editor values (the controller holds only the
/// committed profile).
class _PreviewProfile extends UserProfile {
  const _PreviewProfile(String displayName) : super(displayName: displayName);

  factory _PreviewProfile.from(String name) =>
      _PreviewProfile(name.trim().isEmpty ? 'You' : name.trim());
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
      ),
    );
  }
}

class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selected
              ? Border.all(
                  color: Theme.of(context).colorScheme.onSurface,
                  width: 3,
                )
              : null,
        ),
        child: selected
            ? Icon(Icons.check_rounded,
                color: AccentDerivation.of(color, Theme.of(context).brightness)
                    .onPrimary)
            : null,
      ),
    );
  }
}

/// Shows the auto-derived container family for the current accent —
/// what a chip/avatar background built on the accent will look like,
/// with its contrast-verified foreground.
class _ContainerPreview extends StatelessWidget {
  const _ContainerPreview({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final d = AccentDerivation.of(accent, brightness);
    return Row(
      children: [
        Expanded(
          child: _PreviewChip(
            label: 'primary',
            background: d.primary,
            foreground: d.onPrimary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _PreviewChip(
            label: 'container',
            background: d.container,
            foreground: d.onContainer,
          ),
        ),
      ],
    );
  }
}

class _PreviewChip extends StatelessWidget {
  const _PreviewChip({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}
