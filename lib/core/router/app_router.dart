import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/calls/domain/repositories/calls_repository.dart';
import '../../features/calls/ui/calls_module_view.dart';
import '../../features/nexus/ui/nexus_module_view.dart';
import '../../features/square/ui/square_navigation_shell.dart';
import '../../features/vault/ui/vault_conversation_list.dart';
import '../../features/nexus/domain/repositories/nexus_repository.dart';
import '../../features/vault/domain/repositories/chat_repository.dart';
import '../../injection.dart' as di;

/// Deep-link routes (#8). Every user-facing destination has a stable
/// path; notification payloads and search-result taps resolve through
/// here. Shell modules keep their own internal state — deep links into
/// a module land on the module root plus a navigation hint, since the
/// shells own their master/detail layout.
class AppRoutes {
  static const home = '/';
  static const square = '/square';
  static const squareCompose = '/square/compose';
  static const calls = '/calls';
  static const vault = '/vault';
  static String vaultConversation(String id) => '/vault/conversation/$id';
  static const nexus = '/nexus';
  static String nexusGroup(String id) => '/nexus/group/$id';
}

// NexusModuleView requires a repository — resolved through the same DI
// the shell uses. Builders run lazily at navigation time, after DI.
NexusModuleView _nexusWith({String? deepLinkGroupId}) => NexusModuleView(
      repository: di.sl<NexusRepository>(),
      deepLinkGroupId: deepLinkGroupId,
    );

final appRouter = GoRouter(
  initialLocation: AppRoutes.home,
  routes: [
    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) => const SquareNavigationShell(),
    ),
    GoRoute(
      path: AppRoutes.square,
      builder: (context, state) => const SquareNavigationShell(),
    ),
    GoRoute(
      path: AppRoutes.squareCompose,
      builder: (context, state) => const SquareNavigationShell(
        openComposer: true,
      ),
    ),
    GoRoute(
      path: AppRoutes.calls,
      builder: (context, state) =>
          CallsModuleView(repository: di.sl<CallsRepository>()),
    ),
    GoRoute(
      path: AppRoutes.vault,
      builder: (context, state) =>
          VaultConversationList(repository: di.sl<ChatRepository>()),
    ),
    GoRoute(
      path: '/vault/conversation/:id',
      builder: (context, state) {
        // The conversation list resolves the id on first frame; the
        // route carries the target so the shell preselects it.
        final id = state.pathParameters['id']!;
        return VaultConversationList(
          repository: di.sl<ChatRepository>(),
          deepLinkConversationId: id,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.nexus,
      builder: (context, state) => _nexusWith(),
    ),
    GoRoute(
      path: '/nexus/group/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return _nexusWith(deepLinkGroupId: id);
      },
    ),
  ],
);

/// Resolves a notification payload or raw link into a navigation.
/// Unknown payloads are ignored silently — a malformed notification
/// must never crash the app.
void navigateFromPayload(BuildContext context, String? payload) {
  if (payload == null || payload.isEmpty) return;
  if (!payload.startsWith('/')) return;
  GoRouter.of(context).go(payload);
}
