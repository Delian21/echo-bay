import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo_bay/core/design_system/polaroid_frame.dart';
import 'package:echo_bay/features/square/domain/entities/post.dart';
import 'package:echo_bay/features/square/ui/post_share_card.dart';

void main() {
  Post post({
    String body = 'Golden hour found me on the bridge.',
    String? media,
  }) =>
      Post(
        id: 'p1',
        authorId: 'a1',
        authorName: 'Ada Loomis',
        body: body,
        mediaUrl: media,
        createdAt: DateTime(2026, 9, 28, 18, 4),
      );

  // Width/height live in the IHDR chunk: bytes 16..24, big-endian.
  int pngDimension(Uint8List bytes, {required bool width}) {
    final start = width ? 16 : 20;
    var value = 0;
    for (var i = start; i < start + 4; i++) {
      value = (value << 8) | bytes[i];
    }
    return value;
  }

  Future<Uint8List> capture(WidgetTester tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RepaintBoundary(
          key: key,
          child: PostShareCard(post: post()),
        ),
      ),
    ));
    await tester.pump();
    final bytes = await tester.runAsync<Uint8List>(() {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      return captureBoundaryAsPng(boundary);
    });
    return bytes!;
  }

  testWidgets('text-only post becomes a note with the author and footer',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: PostShareCard(post: post())),
    ));

    expect(
      find.text('Golden hour found me on the bridge.'),
      findsOneWidget,
    );
    expect(find.text('Ada Loomis'), findsOneWidget);
    expect(find.text('@ada_loomis'), findsOneWidget);
    expect(find.text('Echo Bay'), findsOneWidget);
    expect(find.text('echo-bay.netlify.app'), findsOneWidget);
    // The paper print is theme-independent: the card is cream in the app's
    // light theme too.
    final page = tester.widget<ColoredBox>(find.descendant(
      of: find.byType(PostShareCard),
      matching: find.byType(ColoredBox),
    ).first);
    expect(page.color, PostShareCard.paper);
  });

  testWidgets('a long caption truncates at four lines', (tester) async {
    const long = 'A caption that keeps going well past four lines, the way '
        'a real note runs over the edge of the paper and needs a second look '
        'to read all of it, and then some more words besides, enough that the '
        'card has to cut it off somewhere sensible.';
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: PostShareCard(post: post(body: long))),
    ));

    final text = tester.widget<Text>(find.text(long));
    expect(text.maxLines, 4);
    expect(text.overflow, TextOverflow.ellipsis);
  });

  testWidgets('a photo post prints the polaroid, not a note', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PostShareCard(
          post: post(media: 'https://example.invalid/photo.jpg'),
        ),
      ),
    ));

    expect(find.byType(PolaroidFrame), findsOneWidget);
    // The author block and footer survive the print.
    expect(find.text('Ada Loomis'), findsOneWidget);
    expect(find.text('Echo Bay'), findsOneWidget);
  });

  testWidgets('captures at exactly 1080 x 1350 px', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final bytes = await capture(tester);

    // PNG magic bytes.
    expect(bytes.sublist(0, 4), equals([0x89, 0x50, 0x4E, 0x47]));
    expect(pngDimension(bytes, width: true), 1080);
    expect(pngDimension(bytes, width: false), 1350);
  });
}
