import 'dart:async';

import 'package:get_it/get_it.dart';

import 'core/atmosphere/atmosphere_controller.dart';
import 'core/auth/auth_repository.dart';
import 'core/auth/session_store.dart';
import 'core/backup/backup_service.dart';
import 'core/database/app_database.dart';
import 'core/motion/motion_controller.dart';
import 'core/notifications/prompt_notifier.dart';
import 'core/prompt/drift_prompt_repository.dart';
import 'core/prompt/prompt_repository.dart';
import 'core/search/drift_search_repository.dart';
import 'core/search/search_repository.dart';
import 'core/profile/profile_controller.dart';
import 'core/settings/app_settings_store.dart';
import 'core/settings/draft_store.dart';
import 'core/theme/theme_controller.dart';
import 'core/version/version_checker.dart';
import 'features/calls/data/repositories/mock_calls_repository.dart';
import 'features/calls/domain/repositories/calls_repository.dart';
import 'features/nexus/data/datasources/nexus_local_datasource.dart';
import 'features/nexus/data/repositories/mock_nexus_repository.dart';
import 'features/nexus/domain/repositories/nexus_repository.dart';
import 'features/profile/data/repositories/drift_profile_repository.dart';
import 'features/social/data/repositories/drift_follow_repository.dart';
import 'features/social/data/repositories/drift_social_repository.dart';
import 'features/social/domain/repositories/follow_repository.dart';
import 'features/social/domain/repositories/social_repository.dart';
import 'features/keepsake/data/repositories/drift_keepsake_repository.dart';
import 'features/keepsake/domain/repositories/keepsake_repository.dart';
import 'features/profile/domain/repositories/profile_repository.dart';
import 'features/square/data/datasources/square_local_datasource.dart';
import 'features/square/data/repositories/mock_feed_repository.dart';
import 'features/square/domain/repositories/feed_repository.dart';
import 'features/vault/data/datasources/vault_local_datasource.dart';
import 'features/vault/data/repositories/mock_chat_repository.dart';
import 'features/vault/domain/repositories/chat_repository.dart';

final sl = GetIt.instance;

/// Composition root. Only this file knows the concrete types; everything
/// else consumes interfaces. Swapping mocks for real implementations at
/// backend integration is a change here and nowhere else.
Future<void> configureDependencies() async {
  // Identity (Signal posture): opaque device-stable session in secure
  // storage. Everything downstream consumes the AuthRepository contract;
  // no module hardcodes or interprets a user id.
  // Register BEFORE resolving: the session is the seed for every
  // repository below, so this block must come first.
  sl.registerLazySingleton<SessionStore>(() => SecureSessionStore());
  sl.registerLazySingleton<AuthRepository>(
    () => LocalAuthRepository(sl()),
  );

  // Identity resolves FIRST: every repository below attributes writes to
  // this opaque id (authored posts, messages, memberships).
  final session = await sl<AuthRepository>().currentUser();
  final sessionUserId = session.fold((f) => 'local-user', (s) => s.userId);

  // core
  sl.registerLazySingleton<AppDatabase>(() => AppDatabase());
  sl.registerLazySingleton<AppSettingsStore>(
    () => AppSettingsStore(sl()),
  );
  // Unsent-text drafts (composer autosave) over the settings KV table.
  sl.registerLazySingleton<DraftStore>(() => DraftStore(sl()));
  // Full-app export/import (Settings).
  sl.registerLazySingleton<BackupService>(() => BackupService(sl()));
  // Local full-text search over all three modules' content (FTS5).
  sl.registerLazySingleton<SearchRepository>(
    () => DriftSearchRepository(sl()),
  );
  // Daily Square prompt (§6c) + its notification scheduling seam.
  sl.registerLazySingleton<PromptNotifier>(
    () => LocalPromptNotifier(),
  );
  sl.registerLazySingleton<PromptRepository>(
    () => DriftPromptRepository(sl(), sl()),
  );

  // Theme persistence through the factory seam: the controller is created
  // with the stored mode and writes every change back. Fire-and-forget —
  // a failed preference write must never block a theme switch.
  sl.registerLazySingleton<ThemeController>(() {
    final store = sl<AppSettingsStore>();
    return ThemeController(
      onModeChanged: store.writeThemeMode,
    );
  });
  // Reduced-motion preference: restored from storage, changes written
  // back through the same seam as the theme.
  sl.registerLazySingleton<MotionController>(() {
    final store = sl<AppSettingsStore>();
    return MotionController(
      onReducedMotionChanged: store.writeReducedMotion,
    );
  });
  // Web-deploy watcher: notices a fresh version.json (new deploy) and
  // offers a refresh. Web-only; inert on native.
  sl.registerLazySingleton<VersionChecker>(
    () => VersionChecker(),
  );
  // Atmosphere: opt-in paper/pen sounds (posting, pinning). Default off;
  // persisted through the same store seam as theme and reduced-motion.
  sl.registerLazySingleton<AtmosphereController>(() {
    final store = sl<AppSettingsStore>();
    return AtmosphereController(
      onSoundsChanged: store.writeAtmosphereSounds,
      onHapticsChanged: store.writeAtmosphereHaptics,
    );
  });
  // Profile: display name, avatar, accent color. Persisted through the
  // same store; the theme root listens for accent changes.
  sl.registerLazySingleton<ProfileController>(() {
    final store = sl<AppSettingsStore>();
    return ProfileController(
      onProfileChanged: store.writeProfile,
    );
  });
  unawaited(_restorePreferences());

  // calls
  sl.registerLazySingleton<CallsRepository>(
    () => MockCallsRepository(),
  );

  // square
  sl.registerLazySingleton<SquareLocalDatasource>(
    () => DriftSquareLocalDatasource(sl()),
  );
  // Follow graph first (the social layer's peer engine writes through
  // it): who keeps whom close, mock peers, soft-removed rows.
  sl.registerLazySingleton<FollowRepository>(
    () => DriftFollowRepository(sl(), localUserId: sessionUserId)
      ..seedIfEmpty(),
  );
  // Social layer: comments + peer notifications (mock-peer engine).
  sl.registerLazySingleton<SocialRepository>(
    () => DriftSocialRepository(
      sl(),
      follows: sl<FollowRepository>(),
      localUserId: sessionUserId,
    ),
  );
  // Keepsake wall: pinned posts + handwritten notes.
  sl.registerLazySingleton<KeepsakeRepository>(
    () => DriftKeepsakeRepository(sl()),
  );
  // Lazy cleanup of expired ephemeral posts ("fades in 24h"): rows are
  // purged on app start. Visibility never depends on this — reads
  // filter expired rows at query time — this only reclaims storage and
  // drops search-index entries (via the FTS delete trigger).
  unawaited(_purgeExpiredPosts());
  sl.registerLazySingleton<FeedRepository>(
    () => MockFeedRepository(
      localDatasource: sl(),
      db: sl(),
      localUserId: sessionUserId,
      incomingPostInterval: const Duration(seconds: 20),
    ),
  );
  // Profile seam: identity via the settings store, grid via the Square
  // datasource (author-matched live query).
  sl.registerLazySingleton<ProfileRepository>(
    () => DriftProfileRepository(sl(), sl()),
  );

  // vault
  sl.registerLazySingleton<VaultLocalDatasource>(
    () => DriftVaultLocalDatasource(sl()),
  );
  sl.registerLazySingleton<ChatRepository>(
    () => MockChatRepository(
      localDatasource: sl(),
      localUserId: sessionUserId,
      incomingMessageInterval: const Duration(seconds: 15),
    ),
  );

  // nexus
  sl.registerLazySingleton<NexusLocalDatasource>(
    () => DriftNexusLocalDatasource(sl(), localUserId: sessionUserId),
  );
  sl.registerLazySingleton<NexusRepository>(
    () => MockNexusRepository(
      localDatasource: sl(),
      localUserId: sessionUserId,
      channelPostInterval: const Duration(seconds: 25),
      groupMessageInterval: const Duration(seconds: 18),
    ),
  );
}

/// One-shot lazy purge of expired ephemeral posts. Fire-and-forget: a
/// failure here must never block boot (the feed is already correct
/// without it).
Future<void> _purgeExpiredPosts() async {
  try {
    final db = sl<AppDatabase>();
    await db.purgeExpiredPosts(DateTime.now());
  } catch (_) {
    // Cleanup is best-effort; query-time filters keep reads correct.
  }
}

/// Restores persisted preferences into the live controllers. Runs after
/// DI registration; the UI boots on defaults and transitions to stored
/// values when the reads land (local DB, sub-frame in practice).
Future<void> _restorePreferences() async {
  final store = sl<AppSettingsStore>();
  final storedTheme = await store.readThemeMode();
  if (storedTheme != null) {
    sl<ThemeController>().value = storedTheme;
  }
  final storedReduced = await store.readReducedMotion();
  if (storedReduced != null) {
    sl<MotionController>().setReducedMotion(storedReduced);
  }
  sl<AtmosphereController>().restore(
    sounds: await store.readAtmosphereSounds(),
    haptics: await store.readAtmosphereHaptics(),
  );
  final storedProfile = await store.readProfile();
  sl<ProfileController>().update(storedProfile);
}
