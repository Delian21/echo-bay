import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/attachments/post_navigation.dart';
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

/// The router's root navigator, exposed so code that lives ABOVE the
/// MaterialApp (the SuperApp root) can still push full-screen routes —
/// e.g. the first-run flow. `Navigator.of` from above MaterialApp finds
/// nothing (the navigator is BELOW it) and crashes in release mode.
final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'echoBayRoot');

final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: AppRoutes.home,
  // The browser's swipe-back gesture (edge swipe on mobile browsers) is
  // a history navigation: on the root route there is nothing behind it,
  // so the swipe exits the site entirely. Most shell navigation is
  // module switching inside one route (no history entries), so this
  // mostly bites right after opening the composer deep link. go_router
  // cannot intercept the browser gesture itself; the mitigation is that
  // in-app pushes are rare (see the FAB fix) and the transition
  // vocabulary is vertical, which does not invite horizontal swipes.
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
    // Notification deep link: an exact Square post. Opens its journal
    // day view (the existing post surface) — a bare shell would lose the
    // context the notification promised.
    GoRoute(
      path: '/square/post/:id',
      builder: (context, state) {
        final postId = state.pathParameters['id']!;
        return _PostOpenProxy(postId: postId);
      },
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

/// Pushes a full-screen shell behind the day view for one post, then
/// opens it. A route widget (not a redirect) so the back button returns
/// to the Square, not out of the app.
class _PostOpenProxy extends StatefulWidget {
  const _PostOpenProxy({required this.postId});

  final String postId;

  @override
  State<_PostOpenProxy> createState() => _PostOpenProxyState();
}

class _PostOpenProxyState extends State<_PostOpenProxy> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      openSquarePost(context, widget.postId).then((_) {
        if (mounted && context.mounted) {
          // Replacing: the proxy itself is never a screen to sit on.
          GoRouter.of(context).replace<void>(AppRoutes.square);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
}

/// Resolves a notification payload or raw link into a navigation.
/// Unknown payloads are ignored silently — a malformed notification
/// must never crash the app.
void navigateFromPayload(BuildContext context, String? payload) {
  if (payload == null || payload.isEmpty) return;
  if (!payload.startsWith('/')) return;
  GoRouter.of(context).go(payload);
}
