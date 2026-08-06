import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pack_lite/icons.dart';
import 'package:pack_lite/sheets/icon_picker.dart';
import 'package:pack_lite/theme.dart';

/// #57 opened the picker up to every emoji by embedding a third-party picker,
/// with the packing shortlist injected as its first tab. These pin the parts
/// that would fail silently: the shortlist still leading, still being complete,
/// and the sheet laying out without overflowing.
Future<String?> _open(WidgetTester tester, {String current = '🎒'}) async {
  String? picked;
  await tester.pumpWidget(MaterialApp(
    theme: harborTheme(Harbor.light, Brightness.light),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              picked = await showIconPicker(context, current: current);
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return picked;
}

void main() {
  group('buildIconSet', () {
    final set = buildIconSet(const Locale('en'));

    test('puts the shortlist first, so it is the tab the sheet opens on', () {
      expect(set.first.category, Category.RECENT);
    });

    test('carries every curated icon, in order', () {
      expect(set.first.emoji.map((e) => e.emoji), curatedIcons);
    });

    test('keeps the full emoji set behind it', () {
      final categories = set.map((c) => c.category);
      expect(categories, containsAll(Category.values.toSet()));
      // Sanity check that the real corpus is there and not just the shortlist.
      final total = set.fold(0, (sum, c) => sum + c.emoji.length);
      expect(total, greaterThan(1000));
    });
  });

  test('the shortlist leads with packing icons', () {
    // These are the first icons visible when the sheet opens, so an
    // accidental reorder that buried 🧳 is a real regression.
    expect(curatedIcons.take(3), ['🎒', '🧳', '✈️']);
    expect(curatedIcons.toSet().length, curatedIcons.length,
        reason: 'a duplicate would render twice in the shortlist tab');
  });

  testWidgets('opens on the shortlist and lays out cleanly', (tester) async {
    await _open(tester);

    expect(find.text('Choose an icon'), findsOneWidget);
    // '🧳' is in the shortlist but is not the current icon, so finding it
    // proves the shortlist tab is the one rendered, not just the header.
    expect(find.text('🧳'), findsWidgets);
    // A tall sheet embedding a third-party grid is exactly where an unbounded
    // -height or overflow error would surface.
    expect(tester.takeException(), isNull);
  });

  testWidgets('the header shows the icon already set', (tester) async {
    await _open(tester, current: '🎿');
    expect(find.text('🎿'), findsWidgets);
  });
}
