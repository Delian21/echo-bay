import 'package:flutter/material.dart';
import 'package:fpdart/fpdart.dart' hide State;

import '../../../../core/error/failures.dart';
import '../../../../core/people/person_sheet.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../injection.dart';
import '../domain/entities/social_entities.dart';
import '../domain/repositories/follow_repository.dart';

/// My Circle / My Window. Two views over one graph:
///  - My Circle — people who keep me close;
///  - My Window — people I keep close.
/// Rows tap through to the peer's profile. Vocabulary is fixed.
class CircleWindowPage extends StatefulWidget {
  const CircleWindowPage({super.key, required this.initiallyCircle});

  /// true = open on My Circle; false = open on My Window.
  final bool initiallyCircle;

  @override
  State<CircleWindowPage> createState() => _CircleWindowPageState();
}

class _CircleWindowPageState extends State<CircleWindowPage> {
  late bool _circle = widget.initiallyCircle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final golden = GoldenHourExtension.of(context);
    final useInk = golden.enabled;
    final repo =
        sl.isRegistered<FollowRepository>() ? sl<FollowRepository>() : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_circle ? 'My Circle' : 'My Window'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('My Circle')),
                ButtonSegment(value: false, label: Text('My Window')),
              ],
              selected: {_circle},
              onSelectionChanged: (s) => setState(() => _circle = s.first),
            ),
          ),
          Expanded(
            child: repo == null
                ? const SizedBox.shrink()
                : StreamBuilder<Either<Failure, List<PeerFollow>>>(
                    stream: _circle ? repo.watchCircle() : repo.watchWindow(),
                    builder: (context, snap) {
                      final people = snap.data
                              ?.fold((_) => const <PeerFollow>[], (l) => l) ??
                          const <PeerFollow>[];
                      if (people.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            _circle
                                ? 'No one keeps you close yet —\npost something true.'
                                : 'You haven\u2019t kept anyone close yet.\nTheir pages are one tap away.',
                            textAlign: TextAlign.center,
                            style: useInk
                                ? kHandwrittenTextStyle.copyWith(
                                    fontSize: 17,
                                    height: 1.4,
                                    color:
                                        theme.colorScheme.onSurfaceVariant,
                                  )
                                : theme.textTheme.bodyMedium?.copyWith(
                                    color:
                                        theme.colorScheme.onSurfaceVariant,
                                  ),
                          ),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: people.length,
                        itemBuilder: (context, i) {
                          final f = people[i];
                          final name = _circle ? f.followerName : f.followedName;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: theme.colorScheme.primary
                                  .withValues(alpha: 0.15),
                              child: Text(
                                name.characters.first,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            title: Text(name),
                            subtitle: Text(
                              _circle
                                  ? 'Keeps you close since ${f.followedAt.day}.${f.followedAt.month}.'
                                  : 'Keeping close since ${f.followedAt.day}.${f.followedAt.month}.',
                            ),
                            onTap: () =>
                                openPerson(context, name: name),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
