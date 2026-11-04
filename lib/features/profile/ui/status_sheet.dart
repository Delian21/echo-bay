import 'package:flutter/material.dart';

import '../../../core/profile/profile_controller.dart';
import '../../../core/profile/status.dart';
import '../../../core/theme/app_theme.dart';

/// The status editor: one line, a fade choice, and Clear.
///
/// Saving is a single [ProfileController.update] through
/// [UserProfile.withStatus], so the two fields always move together (a
/// switch from "24 hours" to "Never" must drop the old expiry, which
/// `copyWith` cannot express with nullable params).
Future<void> showStatusSheet(
  BuildContext context,
  ProfileController controller,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _StatusSheet(controller: controller),
  );
}

class _StatusSheet extends StatefulWidget {
  const _StatusSheet({required this.controller});

  final ProfileController controller;

  @override
  State<_StatusSheet> createState() => _StatusSheetState();
}

class _StatusSheetState extends State<_StatusSheet> {
  late final TextEditingController _text;
  late int _fadeIndex;
  late final bool _hadStatus;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final profile = widget.controller.profile;
    final active = profile.activeStatusTextAt(now);
    _hadStatus = profile.statusText != null && profile.statusText!.isNotEmpty;
    _text = TextEditingController(text: active ?? '');
    _fadeIndex = _initialFadeIndex(profile.statusExpiresAt, active != null);
  }

  /// Preselects the fade that matches what is stored, so reopening the
  /// sheet on a "Never" status does not quietly turn it into 24 hours.
  int _initialFadeIndex(DateTime? expiresAt, bool active) {
    if (!active) return kStatusDefaultFadeIndex;
    final remaining = expiresAt?.difference(DateTime.now());
    final fade = fadeForRemaining(remaining);
    final index = kStatusFades.indexOf(fade);
    return index < 0 ? kStatusDefaultFadeIndex : index;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _save() {
    final text = _text.text.trim();
    final fade = kStatusFades[_fadeIndex];
    final duration = fade.duration;
    widget.controller.update(
      widget.controller.profile.withStatus(
        text.isEmpty ? null : text,
        duration == null || text.isEmpty
            ? null
            : DateTime.now().add(duration),
      ),
    );
    Navigator.of(context).pop();
  }

  void _clear() {
    widget.controller.update(widget.controller.profile.withStatus(null, null));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A line for today',
            style: kHandwrittenTextStyle.copyWith(
              fontSize: 26,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Shows under your name, in the chats you open, and on your squares.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _text,
            autofocus: true,
            maxLength: kStatusMaxLength,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            style: kHandwrittenTextStyle.copyWith(
              fontSize: 20,
              color: theme.colorScheme.onSurface,
            ),
            decoration: const InputDecoration(
              hintText: kStatusPlaceholder,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Fades in',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < kStatusFades.length; i++)
                ChoiceChip(
                  label: Text(kStatusFades[i].label),
                  selected: _fadeIndex == i,
                  onSelected: (_) => setState(() => _fadeIndex = i),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              if (_hadStatus)
                TextButton(
                  onPressed: _clear,
                  child: const Text('Clear'),
                ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Keep it'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _save,
                child: const Text('Set status'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
