import 'package:flutter/material.dart';

import '../../../core/design_system/sketch_kit.dart';
import '../../../core/theme/app_theme.dart';
import '../../../injection.dart';
import '../../nexus/domain/entities/nexus.dart';
import '../../nexus/domain/repositories/nexus_repository.dart';
import '../../vault/domain/entities/message.dart';
import '../../vault/domain/repositories/chat_repository.dart';
import '../domain/entities/post.dart';

/// "Send this to…" — offers the user's Vault conversations and Hallway
/// dorms as destinations for a Square post. The post travels as a
/// shared-post attachment ([MessageAttachment.sharedPost]); the chat
/// renders it as a small polaroid card that opens the original.
///
/// Dependency rule: this sheet composes CONSUMED contracts (ChatRepository,
/// NexusRepository) from the Square side; the chats never know the Square.
Future<void> showPostShareDestinations(
  BuildContext context,
  Post post,
) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => _DestinationSheet(post: post),
  );
}

class _DestinationSheet extends StatefulWidget {
  const _DestinationSheet({required this.post});

  final Post post;

  @override
  State<_DestinationSheet> createState() => _DestinationSheetState();
}

class _DestinationSheetState extends State<_DestinationSheet> {
  List<Conversation>? _conversations;
  List<NexusGroup>? _groups;
  final _sharing = <String>{}; // destination ids in flight

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final futures = await Future.wait([
      _chatRepo().watchConversations().first,
      _nexusRepo().watchGroups().first,
    ]);
    if (!mounted) return;
    setState(() {
      _conversations = futures[0].fold(
        (_) => const <Conversation>[],
        (list) => List<Conversation>.from(list),
      );
      _groups = futures[1].fold(
        (_) => const <NexusGroup>[],
        (list) => List<NexusGroup>.from(list),
      );
    });
  }

  ChatRepository _chatRepo() => sl<ChatRepository>();
  NexusRepository _nexusRepo() => sl<NexusRepository>();

  Future<void> _sendToVault(Conversation c) async {
    if (_sharing.contains(c.id)) return;
    setState(() => _sharing.add(c.id));
    final result = await _chatRepo().sendMessage(
      conversationId: c.id,
      body: 'From the Square — ${widget.post.authorName}’s post.',
      attachment: MessageAttachment.sharedPost(widget.post.id),
    );
    if (!mounted) return;
    setState(() => _sharing.remove(c.id));
    _finish(result.isRight(), c.title);
  }

  Future<void> _sendToDorm(NexusGroup g) async {
    if (_sharing.contains(g.id)) return;
    setState(() => _sharing.add(g.id));
    final result = await _nexusRepo().sendGroupMessage(
      groupId: g.id,
      body: 'From the Square — ${widget.post.authorName}’s post.',
      attachment: MessageAttachment.sharedPost(widget.post.id),
    );
    if (!mounted) return;
    setState(() => _sharing.remove(g.id));
    _finish(result.isRight(), g.title);
  }

  void _finish(bool ok, String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Sent to $title.'
            : "Couldn't send that one — the line was busy. Try again?"),
        behavior: SnackBarBehavior.floating,
      ),
    );
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final golden = GoldenHourExtension.of(context);
    final useInk = golden.enabled;

    final heading = Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Text(
        'Send this to…',
        style: useInk
            ? kHandwrittenTextStyle.copyWith(
                fontSize: 24, color: theme.colorScheme.onSurface)
            : theme.textTheme.titleMedium,
      ),
    );

    final conversations = _conversations;
    final groups = _groups;

    if (conversations == null || groups == null) {
      return SizedBox(
        height: 160,
        child: Column(
          children: [
            heading,
            const Expanded(
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          ],
        ),
      );
    }

    final vaultTiles = [
      for (final c in conversations)
        ListTile(
          leading: const SketchGlyph(kind: SketchIconKind.padlock),
          title: Text(c.title),
          subtitle: const Text('Vault conversation'),
          trailing: _sharing.contains(c.id)
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.send_rounded, size: 18),
          onTap: () => _sendToVault(c),
        ),
    ];

    final dormTiles = [
      for (final g in groups)
        ListTile(
          leading: const SketchGlyph(kind: SketchIconKind.threeHeads),
          title: Text(g.title),
          subtitle: const Text('Hallway dorm'),
          trailing: _sharing.contains(g.id)
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.send_rounded, size: 18),
          onTap: () => _sendToDorm(g),
        ),
    ];

    final empty = conversations.isEmpty && groups.isEmpty;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          heading,
          if (empty)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Text(
                'No one to send it to yet —\nstart a Vault chat or join a dorm.',
                textAlign: TextAlign.center,
                style: useInk
                    ? kHandwrittenTextStyle.copyWith(
                        fontSize: 17,
                        height: 1.4,
                        color: theme.colorScheme.onSurfaceVariant,
                      )
                    : theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
              ),
            )
          else ...[
            if (vaultTiles.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 2),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('THE VAULT',
                      style: theme.textTheme.labelSmall?.copyWith(
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurfaceVariant,
                      )),
                ),
              ),
            ...vaultTiles,
            if (dormTiles.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 2),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('THE HALLWAY',
                      style: theme.textTheme.labelSmall?.copyWith(
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurfaceVariant,
                      )),
                ),
              ),
            ...dormTiles,
          ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
