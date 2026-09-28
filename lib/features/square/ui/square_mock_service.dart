import 'square_post_model.dart';

/// The Square — mock service for the first vertical slice.
///
/// Generates 20 deterministic, realistic posts with Unsplash placeholder
/// imagery. Returns an immutable list; at integration this class dies and
/// the UI consumes [FeedRepository] streams instead.
class SquareMockService {
  const SquareMockService._();

  /// Unsplash source endpoints resolve to stable, high-quality photos.
  static const _mediaBase = 'https://images.unsplash.com/photo-';
  static const _avatarBase = 'https://i.pravatar.cc/150?img=';

  /// Curated Unsplash photo ids — known-good, landscape/portrait mix.
  static const _photoIds = [
    '1518791841217-8f162f1e1131', // cat
    '1506905925346-21bda4d32df4', // mountain ridge
    '1441974231531-c6227db76b6e', // forest light
    '1529626455594-4ff0802cfb7e', // portrait
    '1470071459604-3b5ec3a7fe05', // foggy valley
    '1500530855697-b586d89ba3ee', // highway dusk
    '1519125323398-675f0ddb6308', // city night
    '1544367567-0f2fcb009e0b', // surfer
    '1469474968028-56623f02e42e', // sunbeam forest
    '1493246507139-91e8fad9978e', // mountains lake
    '1469854523086-cc02fe5d8800', // dancer
    '1517849845537-4d257902454a', // pug
    '1482192596544-9eb780fc7f66', // coffee desk
    '1533738363-b7f9aef128ce', // neon portrait
    '1506744038136-46273834b3fb', // lake reflection
    '1521747116042-5a810fda9664', // skater
    '1469854523086-cc02fe5d8800', // desert highway
    '1519389950473-47ba0277781c', // team laptops
    '1502082553048-f009c37129b9', // green leaves
    '1477959858617-67f85cf4f1df', // skyline
  ];

  static const _authors = [
    (name: 'kai.meridian', caption: 'Shipped the architecture cut today. Clean layers, zero spaghetti. Feels structural, not decorative.'),
    (name: 'nova.okafor', caption: 'Golden hour hits different after a week of rain. Unfiltered, straight from the ridge.'),
    (name: 'rune.virtanen', caption: 'Offline-first is not a feature, it is a posture. Fight me.'),
    (name: 'mila.kang', caption: 'Studio session 03. The dancer moved, the shutter followed.'),
    (name: 'tomas.reyes', caption: 'Morning fog rolled in like it owned the valley. Humbled us all.'),
    (name: 'ada.loomis', caption: 'Highway north, playlist south. Somewhere in between the ideas land.'),
    (name: 'bo.tamm', caption: 'City lights at 1am. The grid never sleeps and neither do the shots.'),
    (name: 'cy.vahtra', caption: 'Wave of the day. Salt in the lens, worth every grain.'),
    (name: 'lina.hoffman', caption: 'Light finding its way through the canopy. Patience is a camera setting.'),
    (name: 'juno.park', caption: 'Alpine mirror. No filter, no edits, no regrets.'),
    (name: 'elias.draeger', caption: 'Movement caught mid-thought. The body decides before the mind votes.'),
    (name: 'sara.lindqvist', caption: 'This is Douglas. Douglas demands treats. Douglas gets treats.'),
    (name: 'petra.novak', caption: 'Desk chaos before the deadline calm. Coffee count: unwise.'),
    (name: 'omer.baraz', caption: 'Neon and rain. The street does the color grading for free.'),
    (name: 'iris.moreau', caption: 'Still water, still mind. Ten minutes of nothing, highly recommended.'),
    (name: 'dante.cruz', caption: 'Concrete waves and scuffed wheels. Session > scroll.'),
    (name: 'yara.haddad', caption: 'Long road, short list of worries. Keep driving.'),
    (name: 'nils.ekberg', caption: 'Sprint retro done, demo shipped, snacks demolished. Team of legends.'),
    (name: 'aiko.tanaka', caption: 'Green on green. The garden is winning and I let it.'),
    (name: 'felix.grant', caption: 'Skyline silhouette hour. The city flexes, I photograph.'),
  ];

  /// 20 deterministic sample posts. Oldest first in the backing list;
  /// the feed view renders newest-first.
  static List<SquarePost> generatePosts() {
    final now = DateTime.now();
    return List.generate(_authors.length, (i) {
      final author = _authors[i];
      final photoId = _photoIds[i];
      return SquarePost(
        id: 'sq-${(i + 1).toString().padLeft(2, '0')}',
        username: author.name,
        userAvatarUrl: '$_avatarBase${i + 1}',
        timestamp: now.subtract(Duration(minutes: 7 * (i + 1))),
        caption: author.caption,
        mediaUrl: '$_mediaBase$photoId?w=1080&q=80&auto=format&fit=crop',
        likesCount: 37 + (i * 613) % 8742,
        isLiked: false,
      );
    });
  }
}
