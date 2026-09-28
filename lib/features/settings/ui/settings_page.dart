import 'package:flutter/material.dart';

import '../../../core/design_system/sketch_kit.dart';
import '../../../core/motion/motion_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/prompt/prompt_repository.dart';
import '../../../core/theme/theme_controller.dart';
import 'daily_square_settings_card.dart';

/// Settings — read/writes the [ThemeController] registered in get_it.
/// Kept as a plain page (no bloc): it toggles one notifier value; the
/// MaterialApp root rebuilds via AnimatedBuilder.
class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.themeController,
    MotionController? motionController,
    this.promptRepository,
    this.onOpenProfile,
  }) : _motionController = motionController;

  final ThemeController themeController;

  /// Optional for standalone tests; production passes it from the shell.
  final MotionController? _motionController;

  /// Daily Square preferences seam; null hides the card (standalone
  /// tests that don't register a PromptRepository).
  final PromptRepository? promptRepository;

  /// Opens the profile editor; null hides the profile row (tests).
  final VoidCallback? onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        // Title style comes from appBarTheme.titleTextStyle (kDisplayTextStyle).
        title: const Text('Settings'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // -- account -------------------------------------------------------
          if (onOpenProfile != null)
            _SettingsNavTile(
              glyph: SketchGlyph(
                kind: SketchIconKind.personGlyph,
                color: theme.colorScheme.primary,
              ),
              label: 'Profile',
              subtitle: 'Name, picture & accent color',
              trailing: null,
              onTap: onOpenProfile,
            ),

          // -- appearance --------------------------------------------------
          const _SectionHeader('Appearance'),
          AnimatedBuilder(
            animation: themeController,
            builder: (context, _) => _ThemeModeCard(
              current: themeController.value,
              onSelect: themeController.setMode,
            ),
          ),

          // -- Daily Square (§6c): opt-in, window, pause -------------------
          if (promptRepository != null) ...[
            const _SectionHeader('Daily Square'),
            DailySquareSettingsCard(repository: promptRepository!),
          ],

          // -- accessibility ------------------------------------------------
          if (_motionController != null) ...[
            const _SectionHeader('Accessibility'),
            AnimatedBuilder(
              animation: _motionController,
              builder: (context, _) => _ReducedMotionCard(
                reduced: _motionController.reducedMotion,
                onChanged: _motionController.setReducedMotion,
              ),
            ),
          ],

          // -- modules -----------------------------------------------------
          const _SectionHeader('Modules'),
          _SettingsNavTile(
            glyph: SketchGlyph(
              kind: SketchIconKind.slateGrid,
              color: theme.colorScheme.primary,
            ),
            label: 'The Square',
            subtitle: 'Public feed · Active',
          ),
          _SettingsNavTile(
            glyph: SketchGlyph(
              kind: SketchIconKind.padlock,
              color: theme.colorScheme.primary,
            ),
            label: 'The Vault',
            subtitle: 'End-to-end encrypted · Beta',
          ),
          _SettingsNavTile(
            glyph: SketchGlyph(
              kind: SketchIconKind.spiralHub,
              color: theme.colorScheme.primary,
            ),
            label: 'The Hallway',
            subtitle: 'Dorms & the Board · New',
          ),
          _SettingsNavTile(
            glyph: SketchGlyph(
              kind: SketchIconKind.handset,
              color: theme.colorScheme.primary,
            ),
            label: 'The Landline',
            subtitle: 'Voice & video · New',
          ),

          // -- about -------------------------------------------------------
          const _SectionHeader('About'),
          _SettingsNavTile(
            glyph: SketchGlyph(
              kind: SketchIconKind.infoMark,
              color: theme.colorScheme.primary,
            ),
            label: 'Version',
            subtitle: 'Echo Bay 0.1.0 · local-first build',
            trailing: null,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ReducedMotionCard extends StatelessWidget {
  const _ReducedMotionCard({required this.reduced, required this.onChanged});

  final bool reduced;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Card(
        margin: EdgeInsets.zero,
        child: SwitchListTile(
          title: const Text('Reduce motion'),
          subtitle: Text(
            'Disables staggered cascades and transitions. '
            'Content appears instantly.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          value: reduced,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _ThemeModeCard extends StatelessWidget {
  const _ThemeModeCard({required this.current, required this.onSelect});

  final ThemeMode current;
  final ValueChanged<ThemeMode> onSelect;

  /// The segment's leading icon: chalk glyph in ink mode, Material
  /// fallback otherwise. Colorless either way — the segment paints its
  /// own selected foreground.
  Widget themeSwitchIcon(SketchIconKind kind, IconData fallback) {
    return Builder(builder: (context) {
      final useInk = GoldenHourExtension.of(context).enabled;
      return useInk
          ? SketchIcon(kind: kind, size: 20, seed: kind.index * 13 + 3)
          : Icon(fallback, size: 20);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 10),
                child: Text('Theme', style: theme.textTheme.titleMedium),
              ),
              SegmentedButton<ThemeMode>(
                // Chalk glyphs (sun / crescent / circled-A) matching the
                // rest of the chrome; Material icons when ink is off.
                segments: [
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: themeSwitchIcon(
                        SketchIconKind.autoA, Icons.brightness_auto_rounded),
                    label: const Text('System'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: themeSwitchIcon(
                        SketchIconKind.sunMark, Icons.light_mode_outlined),
                    label: const Text('Light'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: themeSwitchIcon(
                        SketchIconKind.moonCrescent, Icons.dark_mode_outlined),
                    label: const Text('Dark'),
                  ),
                ],
                selected: {current},
                // M3 prepends a checkmark to the selected segment, which
                // shoves the chalk glyph half out of the segment. The
                // tinted pill + glyph already communicate selection.
                showSelectedIcon: false,
                onSelectionChanged: (selection) => onSelect(selection.first),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 8),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _SettingsNavTile extends StatelessWidget {
  const _SettingsNavTile({
    required this.glyph,
    required this.label,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  final Widget glyph;
  final String label;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      leading: glyph,
      title: Text(label, style: theme.textTheme.bodyLarge),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
      trailing: trailing,
    );
  }
}
