import 'package:flutter/material.dart';

import 'user_profile.dart';

/// App-wide profile state. A [ChangeNotifier] like Theme/Motion — the
/// theme root listens for accent changes, the feed composer reads the
/// display name, the rail/settings render the avatar.
///
/// Persistence seam: [onProfileChanged] is invoked on every [update].
/// injection.dart wires it to the drift-backed store; the controller
/// stays storage-agnostic.
class ProfileController extends ChangeNotifier {
  ProfileController({
    this.onProfileChanged,
    UserProfile initialProfile = const UserProfile(),
  }) : _profile = initialProfile;

  final void Function(UserProfile profile)? onProfileChanged;

  UserProfile _profile;
  UserProfile get profile => _profile;

  void update(UserProfile profile) {
    if (profile == _profile) return;
    _profile = profile;
    notifyListeners();
    onProfileChanged?.call(profile);
  }
}
