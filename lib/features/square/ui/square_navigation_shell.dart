import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/design_system/sketch_kit.dart';
import '../../../core/settings/app_settings_store.dart';
import '../../../core/io/platform_io.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../calls/domain/repositories/calls_repository.dart';
import '../../calls/data/repositories/mock_calls_repository.dart';
import '../../calls/ui/calls_module_view.dart';
import '../../nexus/domain/repositories/nexus_repository.dart';
import '../../nexus/ui/nexus_module_view.dart';
import '../../profile/ui/profile_page.dart';
import '../../settings/ui/settings_page.dart';
import '../../square/domain/repositories/feed_repository.dart';
import 'post_composer.dart';
import '../../vault/data/datasources/vault_local_datasource.dart';
import '../../vault/data/repositories/mock_chat_repository.dart';
import '../../vault/domain/repositories/chat_repository.dart';
import '../../vault/ui/vault_conversation_list.dart';
import '../../../core/database/app_database.dart';
import '../../../core/design_system/breakpoints.dart';
import '../../../core/motion/motion_controller.dart';
import '../../../core/motion/motion_scope.dart';
import '../../../core/prompt/prompt.dart';
import '../../../core/prompt/prompt_repository.dart';
import '../../../core/router/app_router.dart';
import '../../../core/profile/profile_controller.dart';
import '../../../core/profile/user_profile.dart';
import '../../../core/search/search_page.dart';
import '../../../core/search/search_repository.dart';
import '../../../injection.dart';
import 'fab_bottom_bar.dart';
import 'square_feed_view.dart';

/// Navigation shell for all modules.
///
/// Wide (>= 600 logical px): [NavigationRail] with the module body swapped
/// in place; Settings lives in the rail's trailing slot.
/// Narrow (mobile): bottom [NavigationBar] — five destinations, the
/// Material-recommended max. The old drawer scaffold is gone; the bottom
/// bar covers module switching and Settings.
class SquareNavigationShell extends StatefulWidget {
  const SquareNavigationShell({
    super.key,
    this.vaultRepository,
    this.callsRepository,
    this.themeController,
    this.openComposer = false,
  });

  /// Injectables for tests; production builds the mock stack lazily.
  final ChatRepository? vaultRepository;
  final CallsRepository? callsRepository;
  final ThemeController? themeController;

  /// Deep-link entry (#8): land on the Square with the post composer
  /// already open (notification payload '/square/compose').
  final bool openComposer;

  @override
  State<SquareNavigationShell> createState() => _SquareNavigationShellState();
}

/// Material fade-through durations for module swaps. Outgoing content
/// fades out over [kFadeThroughOutDuration] while incoming fades in and
/// scales up over [kFadeThroughInDuration].
const kFadeThroughOutDuration = Duration(milliseconds: 90);
const kFadeThroughInDuration = Duration(milliseconds: 210);
const kFadeThroughCurve = Curves.easeOutCubic;

class _SquareNavigationShellState extends State<SquareNavigationShell>
    with SingleTickerProviderStateMixin {
  int _moduleIndex = 0;

  /// Settings lives outside the rail destinations (trailing slot), so the
  /// rail's selectedIndex must stay within 0..3 — passing 4 trips
  /// NavigationRail's assertion and paints the whole shell red.
  static const _railDestinationCount = 4;

  late final AnimationController _fadeController = AnimationController(
    vsync: this,
    duration: kFadeThroughInDuration,
    value: 1,
  );

  @override
  void initState() {
    super.initState();
    // Deep-link entry (#8): the composer opens once on first frame, only
    // when the Square module is the landing module. Prompt-aware: the
    // notification tap carries no explicit shape, so the active prompt
    // (if any) pre-seeds the sheet.
    if (widget.openComposer) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _moduleIndex != 0) return;
        _openComposer();
      });
    }
  }

  @override
  void dispose() {
    _unreadSub?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  /// Aggregate unread total for the Vault badge. Late-final stream (see
  /// the stream-rebind gotcha in ARCHITECTURE.md §8): created once, never
  /// in build. Anti-chore rule: the badge hides the moment the Vault is
  /// open — opening a conversation marks it read through the cursors and
  /// this count falls to zero live.
  Stream<int>? _unreadStream;
  StreamSubscription<int>? _unreadSub;
  int _totalUnread = 0;

  Stream<int> get _totalUnreadStream {
    if (_unreadStream == null && _hasVaultBadgeSource) {
      _unreadStream = _vaultRepository.watchTotalUnread();
      _unreadSub = _unreadStream!.listen((total) {
        if (mounted && total != _totalUnread) {
          setState(() => _totalUnread = total);
        }
      });
    }
    return _unreadStream ?? const Stream<int>.empty();
  }

  void _openProfile() {
    final controller = _profileController;
    if (controller == null) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ProfilePage(
        profileController: controller,
        feedRepository: sl<FeedRepository>(),
      ),
    ));
  }

  /// Settings from the Square app bar (mobile). On the rail this is the
  /// trailing icon's own handler; here it must select the module body.
  void _selectSettings() => _selectModule(4);

  /// Composer entry point shared by the app-bar button, the deep link,
  /// and the FAB quick actions. Fetches the active Daily Square prompt
  /// (§6c) and passes it through: the sheet pre-seeds with the prompt
  /// copy and retires the prompt on publish. A prompt-less open (opted
  /// out / paused / already acted / outside window) is normal — the
  /// composer just shows the generic hint.
  Future<void> _openComposer({String? promptShape}) async {
    Prompt? prompt;
    if (sl.isRegistered<PromptRepository>()) {
      final result = await sl<PromptRepository>().activePrompt();
      prompt = result.fold((_) => null, (p) => p);
      // A quick-action shape wins over the active prompt's shape — the
      // user explicitly picked photo/sentence/sound.
      if (promptShape != null && prompt != null && prompt.shape != promptShape) {
        prompt = null;
      }
    }
    if (!mounted) return;
    await showPostComposer(
      context,
      repository: sl<FeedRepository>(),
      authorName: _profileController?.profile.displayName ?? 'You',
      prompt: prompt,
      promptRepository: sl.isRegistered<PromptRepository>()
          ? sl<PromptRepository>()
          : null,
      promptShape: promptShape,
    );
  }

  void _selectModule(int index) {
    if (index == _moduleIndex) return;
    setState(() => _moduleIndex = index);
    // Restart from the outgoing-fade phase; the body below rebuilds with
    // the new module immediately and fades through via FadeTransition.
    // Reduced motion: jump the transition to its end state — instant swap.
    final reduced =
        MotionScope.maybeOf(context)?.reducedMotion ?? false;
    _fadeController
      ..reset()
      ..forward(from: reduced ? 1 : 0);
  }

  static const _modules = [
    ('The Square', SketchIconKind.slateGrid),
    ('The Vault', SketchIconKind.padlock),
    ('The Hallway', SketchIconKind.spiralHub),
    ('The Landline', SketchIconKind.handset),
    ('Settings', SketchIconKind.cog),
  ];

  ChatRepository get _vaultRepository => widget.vaultRepository ??
      // Prefer the DI singleton: opening a second AppDatabase on the same
      // sqlite file (two background isolates) trips "database is locked"
      // under concurrent reads. The private fallback exists only for
      // standalone tests that pump the shell without full DI.
      (_vaultRepoInstance ??= sl.isRegistered<ChatRepository>()
          ? sl<ChatRepository>()
          : _buildMockChatRepository());

  ChatRepository? _vaultRepoInstance;

  /// Whether a badge source exists without constructing a fallback mock
  /// (tests that pump the shell DI-less must not spin up a database just
  /// to watch unread counts — that leaks drift timers into flutter_test).
  bool get _hasVaultBadgeSource =>
      widget.vaultRepository != null || sl.isRegistered<ChatRepository>();

  CallsRepository get _callsRepository =>
      widget.callsRepository ?? MockCallsRepository();

  ThemeController get _themeController =>
      widget.themeController ??
      // Standalone tests may pump the shell without full DI.
      (sl.isRegistered<ThemeController>()
          ? sl<ThemeController>()
          : ThemeController());

  MotionController? get _motionController => sl.isRegistered<MotionController>()
      ? sl<MotionController>()
      : null;

  ProfileController? get _profileController =>
      sl.isRegistered<ProfileController>() ? sl<ProfileController>() : null;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= AppBreakpoints.wide;
      return wide ? _buildRailScaffold() : _buildBottomNavScaffold();
    });
  }

  // -- shared module bodies ---------------------------------------------------

  Widget _buildModuleBody() {
    final current = _moduleBodyFor(_moduleIndex);

    // No transition needed when first mounting (value already at 1) — the
    // fade-through only plays on module *switches*. Only the incoming body
    // animates: keeping the outgoing body alive to cross-fade would
    // double-mount the stream builders underneath.
    if (_fadeController.value == 1) return current;

    return FadeTransition(
      opacity: _fadeController.drive(
        Tween<double>(begin: 0, end: 1).chain(
          CurveTween(curve: const Interval(0.4, 1, curve: kFadeThroughCurve)),
        ),
      ),
      child: ScaleTransition(
        scale: _fadeController.drive(
          Tween<double>(begin: 0.92, end: 1).chain(
            CurveTween(curve: kFadeThroughCurve),
          ),
        ),
        child: current,
      ),
    );
  }

  Widget _moduleBodyFor(int index) {
    return switch (index) {
      0 => _squareBody(),
      1 => VaultConversationList(
          repository: _vaultRepository,
          embedded: true,
        ),
      2 => NexusModuleView(
          repository: sl<NexusRepository>(),
          embedded: true,
        ),
      3 => CallsModuleView(repository: _callsRepository),
      4 => SettingsPage(
          themeController: _themeController,
          motionController: _motionController,
          // §6c Daily Square prefs. DI-registered since #5; the guard
          // keeps standalone tests that reset DI from crashing.
          promptRepository: sl.isRegistered<PromptRepository>()
              ? sl<PromptRepository>()
              : null,
          onOpenProfile: _openProfile,
        ),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _squareBody() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('The Square'),
        centerTitle: false,
        actions: [
          // Profile entry: the local user's page (identity + pinned grid).
          // AnimatedBuilder so the initials avatar tracks profile edits.
          AnimatedBuilder(
            animation: _profileController ?? ChangeNotifier(),
            builder: (context, _) {
              final profile =
                  _profileController?.profile ?? const UserProfile();
              return IconButton(
                tooltip: 'Your profile',
                onPressed: _openProfile,
                icon: profile.avatarPath != null
                    ? CircleAvatar(
                        radius: 12,
                        backgroundImage:
                            platformImageProvider(profile.avatarPath!),
                        onBackgroundImageError: (_, __) {},
                      )
                    : SketchGlyph(
                        kind: SketchIconKind.personGlyph,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
              );
            },
          ),
          IconButton(
            tooltip: 'Search',
            icon: const SketchGlyph(kind: SketchIconKind.searchGlass),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => SearchPage(
                  searchRepository: sl<SearchRepository>(),
                  settingsStore: sl<AppSettingsStore>(),
                ),
              ));
            },
          ),
          IconButton(
            tooltip: 'New post',
            icon: const SketchGlyph(kind: SketchIconKind.plusCircle),
            onPressed: _openComposer,
          ),
          // Mobile bottom bar has no Settings destination (compose FAB
          // owns the center) — the gear lives here on every platform.
          IconButton(
            tooltip: 'Settings',
            icon: const SketchGlyph(kind: SketchIconKind.cog),
            onPressed: _selectSettings,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SquareFeedView(repository: sl<FeedRepository>()),
    );
  }

  // -- desktop: NavigationRail + body swap ------------------------------------

  Widget _buildRailScaffold() {
    // Subscribe lazily on first build; see _totalUnreadStream.
    _totalUnreadStream;
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            // Settings (index 4) is not a rail destination — pass null so
            // no destination falsely highlights; the trailing icon below
            // carries the selected state. Passing 4 trips NavigationRail's
            // bounds assertion and paints the whole shell red.
            selectedIndex:
                _moduleIndex < _railDestinationCount ? _moduleIndex : null,
            onDestinationSelected: _selectModule,
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 16),
              // Live profile identity: initials on the accent color, or the
              // user's picture URL once set in the profile editor.
              child: AnimatedBuilder(
                animation: _profileController ?? ChangeNotifier(),
                builder: (context, _) {
                  final profile =
                      _profileController?.profile ?? const UserProfile();
                  if (profile.avatarPath != null) {
                    return CircleAvatar(
                      radius: 18,
                      backgroundImage:
                          platformImageProvider(profile.avatarPath!),
                      onBackgroundImageError: (_, __) {},
                    );
                  }
                  return CircleAvatar(
                    radius: 18,
                    backgroundColor:
                        profile.accentColor.withValues(alpha: 0.18),
                    child: Text(
                      profile.initials(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: profile.accentColor,
                      ),
                    ),
                  );
                },
              ),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: IconButton(
                    tooltip: 'Settings',
                    icon: SketchGlyph(
                      kind: SketchIconKind.cog,
                      color: _moduleIndex == 4
                          ? navSelectedIconColor(
                              Theme.of(context).colorScheme)
                          : null,
                    ),
                    isSelected: _moduleIndex == 4,
                    onPressed: () => _selectModule(4),
                  ),
                ),
              ),
            ),
            destinations: [
              for (final (i, (label, kind)) in _modules.take(4).indexed)
                NavigationRailDestination(
                  // Chrome glyphs stay chalk in both states; the selected
                  // color is contrast-tested against the accent pill (an
                  // amber accent on its own pale-amber pill washes out,
                  // so the picker falls back to warm ink per accent).
                  icon: _railIcon(kind, label, i, selected: false),
                  selectedIcon:
                      _railIcon(kind, label, i, selected: true),
                  label: Text(label),
                ),
            ],
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: _buildModuleBody()),
        ],
      ),
    );
  }

  /// Rail destination glyph with the Vault unread dot stacked on it.
  /// Selected state colors via navSelectedIconColor (accent-pill contrast).
  Widget _railIcon(SketchIconKind kind, String label, int index,
      {required bool selected}) {
    final glyph = SketchGlyph(
      kind: kind,
      seed: label.hashCode & 0x7FFFFFFF,
      color: selected
          ? navSelectedIconColor(Theme.of(context).colorScheme)
          : null,
    );
    final badged = index == 1 && _totalUnread > 0 && _moduleIndex != 1;
    if (!badged) return glyph;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        glyph,
        const Positioned(
          right: -3,
          top: -2,
          child: CustomPaint(size: Size(7, 7), painter: UnreadScribbleDot()),
        ),
      ],
    );
  }

  // -- mobile: hybrid bottom bar (compose FAB + 4 destinations) --------------

  /// Mobile shows four destinations; Settings moves to the Square app bar
  /// (gear icon) so the compose FAB can own the bar's center. Labels use
  /// the short forms — the 64dp bar clips "The Hallway"/"The Landline"
  /// at phone widths; full names live on the desktop rail and mastheads.
  static const _mobileModules = [
    ('Square', SketchIconKind.slateGrid),
    ('Vault', SketchIconKind.padlock),
    ('Hallway', SketchIconKind.spiralHub),
    ('Landline', SketchIconKind.handset),
  ];

  Widget _buildBottomNavScaffold() {
    // Subscribe lazily on first build; see _totalUnreadStream.
    _totalUnreadStream;
    return Scaffold(
      body: _buildModuleBody(),
      bottomNavigationBar: FabBottomBar(
        modules: _mobileModules,
        selectedIndex: _moduleIndex,
        onSelected: _selectModule,
        onCompose: () => context.push(AppRoutes.squareCompose),
        // Vault badge (index 1); hidden while the Vault is open — a badge
        // that persists on the screen you're looking at is noise.
        badgedIndexes: _totalUnread > 0 && _moduleIndex != 1
            ? const <int>{1}
            : const <int>{},
      ),
      // The FAB docks into the bar's notch (centerDocked). It navigates
      // via the '/square/compose' deep link — the same route notification
      // taps use — so it lands on the Square with the composer open and
      // Back returns to the originating module.
      //
      // Long-press quick actions open the composer directly with the
      // matching prompt shape (photo / sentence / sound), same hint as
      // the Daily Square notification tap path.
      floatingActionButton: ComposeFab(
        onPressed: () => context.push(AppRoutes.squareCompose),
        onQuickAction: (shape) => _openComposer(promptShape: shape),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

ChatRepository _buildMockChatRepository() {
  // Standalone-test fallback ONLY (DI absent). Never construct a second
  // AppDatabase here when DI is up: two background isolates on the same
  // sqlite file trip "database is locked" under concurrent reads. The
  // caller checks sl.isRegistered<ChatRepository>() before reaching this.
  final db = sl.isRegistered<AppDatabase>()
      ? sl<AppDatabase>()
      : AppDatabase();
  final local = DriftVaultLocalDatasource(db);
  return MockChatRepository(localDatasource: local);
}
