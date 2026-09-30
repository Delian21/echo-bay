/// In-app feedback ("tell me what's broken") — the single place to
/// change where feedback goes. Update [feedbackEmail] and everything
/// (Settings tile, About tile, prefilled mailto) follows.
library;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Destination for user feedback / bug reports.
const String feedbackEmail = 'fdlsamadi@gmail.com';

/// App version shown in the prefilled body. Kept as a literal instead
/// of reading package_info (no such dependency; the web build stays
/// lean) — bump alongside pubspec's `version:`.
const String feedbackAppVersion = '0.1.0';

/// Builds the prefilled mailto: URL — subject + body with app version
/// and platform. No personal data: just what's needed to reproduce a
/// report against the right build.
Uri feedbackMailto() => Uri(
      scheme: 'mailto',
      path: feedbackEmail,
      query: 'subject=${Uri.encodeComponent('Echo Bay — what broke?')}&'
          'body=${Uri.encodeComponent(
        'What happened?\n\n\n'
        '—\n'
        'App version: $feedbackAppVersion\n'
        'Platform: ${_platformName()}\n',
      )}',
    );

/// Coarse platform name for bug reports. No device details, no ids.
String _platformName() {
  if (kIsWeb) return 'web';
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'Android',
    TargetPlatform.iOS => 'iOS',
    TargetPlatform.windows => 'Windows',
    TargetPlatform.macOS => 'macOS',
    TargetPlatform.linux => 'Linux',
    TargetPlatform.fuchsia => 'Fuchsia',
  };
}
