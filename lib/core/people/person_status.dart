import '../../features/social/domain/entities/peer_directory.dart';
import '../../injection.dart';
import '../profile/profile_controller.dart';
import '../profile/status.dart';

/// The status line to show for [name] right now, or null when there is
/// none (or it has lapsed).
///
/// Two sources, one rule: the local user's own value lives on the
/// [ProfileController]; every other name reads the mock cast in
/// [PeerDirectory]. Callers never care which — they get text plus its
/// expiry, or nothing, and [StatusLineData.isActiveAt] stays the single
/// definition of "still up".
StatusLineData? statusForPerson(String name, {DateTime? now}) {
  final moment = now ?? DateTime.now();
  final wanted = name.trim();
  if (wanted.isEmpty) return null;

  if (sl.isRegistered<ProfileController>()) {
    final profile = sl<ProfileController>().profile;
    final ownName = profile.displayName.trim();
    final active = profile.activeStatusTextAt(moment);
    if (active != null && ownName == wanted) {
      return StatusLineData(active, expiresAt: profile.statusExpiresAt);
    }
  }

  final peer = PeerDirectory.bio(wanted);
  if (!statusIsActive(peer.statusText, peer.statusExpiresAt, moment)) {
    return null;
  }
  return StatusLineData(peer.statusText!.trim(),
      expiresAt: peer.statusExpiresAt);
}
