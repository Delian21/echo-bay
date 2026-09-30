import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/atmosphere/atmosphere_controller.dart';
import '../../../core/backup/backup_service.dart';
import '../../../core/feedback/feedback.dart';
import '../../../core/design_system/sketch_kit.dart';
import '../../../core/error/failures.dart';
import '../../../core/io/platform_io.dart';
import '../../../core/motion/motion_controller.dart';
import '../../../core/onboarding/first_run.dart';
import '../../../core/settings/app_settings_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/prompt/prompt_repository.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../injection.dart';
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

  /// Opens the prefilled feedback mailto. Failures (no mail app, web
  /// popup blocked) surface as a quiet snackbar with the address spelled
  /// out so the user can still reach it.
  Future<void> _launchFeedback(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final url = feedbackMailto();
    try {
      final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!ok) throw 'launch refused';
    } on Object {
      messenger.showSnackBar(
        // Const interpolation of the const [feedbackEmail] is allowed —
        // the address stays single-sourced in core/feedback.
        const SnackBar(
          content: Text(
            "Couldn't open your mail app. Write to $feedbackEmail directly.",
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

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
                // The toggle reflects the USER's preference; the system
                // reduce-motion setting ORs in on top (shown in the
                // subtitle when active).
                reduced: _motionController.userReducedMotion,
                onChanged: _motionController.setReducedMotion,
              ),
            ),
          ],

          // -- atmosphere ----------------------------------------------------
          if (sl.isRegistered<AtmosphereController>()) ...[
            const _SectionHeader('Atmosphere'),
            AnimatedBuilder(
              animation: sl<AtmosphereController>(),
              builder: (context, _) => _AtmosphereCard(
                controller: sl<AtmosphereController>(),
              ),
            ),
          ],

          // -- onboarding ---------------------------------------------------
          const _SectionHeader('Welcome'),
          _SettingsNavTile(
            glyph: SketchGlyph(
              kind: SketchIconKind.sunMark,
              color: theme.colorScheme.primary,
            ),
            label: 'Replay intro',
            subtitle: 'The three-page welcome again — the Square, the '
                'Vault, the rewind.',
            trailing: null,
            onTap: () async {
              await FirstRun.reset(sl<AppSettingsStore>());
              if (!context.mounted) return;
              Navigator.of(context).push(MaterialPageRoute<void>(
                fullscreenDialog: true,
                builder: (_) => const FirstRunFlow(),
              ));
            },
          ),

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
            subtitle: 'Private · local-first · Beta',
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

          // -- your data ---------------------------------------------------
          const _SectionHeader('Your data'),
          const _BackupCard(),

          // -- danger -------------------------------------------------------
          const _SectionHeader('Start over'),
          const _ClearAllDataCard(),

          // -- about -------------------------------------------------------
          const _SectionHeader('About'),
          _SettingsNavTile(
            glyph:            SketchGlyph(
              kind: SketchIconKind.jaggedBubble,
              color: theme.colorScheme.primary,
            ),
            label: "Tell me what's broken",
            subtitle: 'Opens a prefilled message — version & platform '
                'included, nothing personal.',
            trailing: null,
            onTap: () => _launchFeedback(context),
          ),
          _SettingsNavTile(
            glyph: SketchGlyph(
              kind: SketchIconKind.infoMark,
              color: theme.colorScheme.primary,
            ),
            label: 'Version',
            subtitle: 'Echo Bay $feedbackAppVersion · local-first build',
            trailing: null,
          ),
          _SettingsNavTile(
            glyph: SketchGlyph(
              kind: SketchIconKind.infoMark,
              color: theme.colorScheme.primary,
            ),
            label: 'Credits',
            subtitle: 'Set in Caveat & Roboto (both SIL OFL). '
                'The design is original — drawn for Echo Bay, not borrowed.',
            trailing: null,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Clear-all-data: wipes every table and returns the app to the first-run
/// intro. Double-confirm — typed-phrase free, but two explicit taps and
/// a suggestion to export first.
class _ClearAllDataCard extends StatelessWidget {
  const _ClearAllDataCard();

  Future<void> _confirmAndClear(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      // STALE_CHECK_OK: invoked synchronously from the tap.
      // ignore: use_build_context_synchronously
      context: context,
      builder: (sheetContext) => AlertDialog(
        title: const Text('Turn the page?'),
        content: const Text(
          'Every square, message, and note on this device will be cleared — '
          'a fresh sketchbook. Export a backup first if you want to keep '
          'anything.\n\nThis cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(sheetContext).pop(false),
            child: const Text('Keep everything'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(sheetContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(sheetContext).pop(true),
            child: const Text('Clear it all'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final result = await sl<BackupService>().clearAllData();
    if (!messenger.mounted) return;
    result.fold(
      (Failure f) => messenger.showSnackBar(
        SnackBar(
          content: Text(f.message ?? "Couldn't clear — try again?"),
          behavior: SnackBarBehavior.floating,
        ),
      ),
      (_) => messenger.showSnackBar(
        const SnackBar(
          content: Text('Fresh pages. Welcome back to day one.'),
          behavior: SnackBarBehavior.floating,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: SketchGlyph(
            kind: SketchIconKind.closeX,
            color: Theme.of(context).colorScheme.error,
          ),
          title: const Text('Clear all data'),
          subtitle: const Text(
            'Wipes everything and restarts the welcome. Export first! A '
            'fresh sketchbook, not a lost one.',
          ),
          onTap: () => _confirmAndClear(context),
        ),
      ),
    );
  }
}

/// Export/import of the whole app as one versioned JSON file. Export
/// downloads (web) or saves (native) `echo-bay-backup-<date>.json`;
/// import opens a file picker, confirms replacement, then swaps every
/// table inside a transaction. Failures surface as snackbars in the
/// app's voice; the schema guard rejects newer backups with a clear ask.
class _BackupCard extends StatelessWidget {
  const _BackupCard();

  static const _voice = kHandwrittenTextStyle;

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _export(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final export = await sl<BackupService>().exportBytes();
    final failure = export.fold((f) => f, (_) => null);
    if (failure != null) {
      if (!messenger.mounted) return;
      _toast(messenger.context, 'The pen ran dry — export failed. Try again?');
      return;
    }
    final bytes = export.fold((_) => Uint8List(0), (b) => b);
    final date = DateTime.now();
    final name = 'echo-bay-backup-'
        '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}.json';
    try {
      await writeBytes(name, bytes); // IO seam: download on web, file on native
      if (!messenger.mounted) return;
      _toast(messenger.context, 'Backed up. Every page, safe on paper.');
    } on Object {
      if (!messenger.mounted) return;
      _toast(messenger.context, "Couldn't set that down — export failed.");
    }
  }

  Future<void> _import(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      // IO seam: real <input type=file> on web; native returns null for
      // now (no file-dialog plugin) — surfaced below with a path forward.
      final bytes = await pickFileBytes();
      if (bytes == null) return; // cancelled
      if (!messenger.mounted) return;
      final dialogContext = messenger.context;

      // Confirm: this replaces everything on this device.
      final confirmed = await showDialog<bool>(
        // STALE_CHECK_OK: messenger.mounted was checked right above, and
        // dialogContext was captured from it while mounted.
        // ignore: use_build_context_synchronously
        context: dialogContext,
        builder: (sheetContext) => AlertDialog(
          title: const Text('Replace this Echo Bay?'),
          content: Text(
            'Everything here now — every post, note, and message — will be '
            'traded for what is in that backup file. The old pages stay '
            'unwritten.\n\nThis cannot be undone.',
            style: sheetContext.mounted &&
                    GoldenHourExtension.of(sheetContext).enabled
                ? _voice.copyWith(fontSize: 16)
                : null,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(sheetContext).pop(false),
              child: const Text('Keep mine'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(sheetContext).pop(true),
              child: const Text('Replace it'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      final result = await sl<BackupService>().importBytes(bytes);
      result.fold(
        (Failure f) {
          if (!messenger.mounted) return;
          _toast(
            messenger.context,
            f.message ?? "Couldn't read that backup.",
          );
        },
        (ImportSummary summary) {
          if (!messenger.mounted) return;
          _toast(
            messenger.context,
            'Restored — ${summary.rows} rows of your Echo Bay are back.',
          );
        },
      );
    } on Object {
      if (!messenger.mounted) return;
      _toast(messenger.context, "Couldn't open that file. Try again?");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Card(
        margin: EdgeInsets.zero,
        child: Column(
          children: [
            ListTile(
              leading: SketchGlyph(
                kind: SketchIconKind.paperPlane,
                color: theme.colorScheme.primary,
              ),
              title: const Text('Export my Echo Bay'),
              subtitle: const Text(
                'Every page — posts, messages, notes, the whole wall — as '
                'one file.',
              ),
              trailing: const Icon(Icons.download_rounded),
              onTap: () => _export(context),
            ),
            const Divider(height: 1),
            ListTile(
              leading: SketchGlyph(
                kind: SketchIconKind.plusCircle,
                color: theme.colorScheme.primary,
              ),
              title: const Text('Import from backup'),
              subtitle: const Text(
                'Bring a backup file back. Replaces what is here now.',
              ),
              trailing: const Icon(Icons.upload_rounded),
              onTap: () => _import(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// Atmosphere opt-ins — paper/pen sounds and the rewind haptic tap.
/// Both default OFF; when reduce-motion is on, the haptic toggle shows
/// why it's idle (reduce-motion always wins).
class _AtmosphereCard extends StatelessWidget {
  const _AtmosphereCard({required this.controller});

  final AtmosphereController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reducedMotion = sl.isRegistered<MotionController>()
        ? sl<MotionController>().reducedMotion
        : false;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Card(
        margin: EdgeInsets.zero,
        child: Column(
          children: [
            SwitchListTile(
              secondary: SketchGlyph(
                kind: SketchIconKind.scribbleMic,
                color: theme.colorScheme.primary,
              ),
              title: const Text('Pen & paper sounds'),
              subtitle: Text(
                'A soft scratch when you post or send, a page settling '
                'when you pin. Quiet by default.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              value: controller.soundsEnabled,
              onChanged: controller.setSoundsEnabled,
            ),
            const Divider(height: 1),
            SwitchListTile(
              secondary: SketchGlyph(
                kind: SketchIconKind.rewindSpiral,
                color: theme.colorScheme.primary,
              ),
              title: const Text('Rewind tap'),
              subtitle: Text(
                reducedMotion
                    ? 'Idle while reduce-motion is on — your device\'s '
                        'setting always wins.'
                    : 'A light tick when a moment rewinds. Off by default.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              value: controller.hapticsEnabled && !reducedMotion,
              onChanged: reducedMotion
                  ? null
                  : controller.setHapticsEnabled,
            ),
          ],
        ),
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
            reduced
                ? 'Animations are off. Content appears instantly.'
                : 'Disables staggered cascades and transitions. '
                    'Content appears instantly. Your device\'s own '
                    'reduce-motion setting is always honored.',
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
