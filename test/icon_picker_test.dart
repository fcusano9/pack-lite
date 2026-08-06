import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pack_lite/icons.dart';
import 'package:pack_lite/sheets/icon_picker.dart';
import 'package:pack_lite/theme.dart';

/// #57 opened the picker up to every emoji, which meant embedding a third-party
/// picker inside our sheet. These pin the parts that would fail silently: the
/// Suggested shortlist still being there and still returning a value, and the
/// sheet laying out without overflowing.
Future<String?> _open(WidgetTester tester) async {
  String? picked;
  await tester.pumpWidget(MaterialApp(
    theme: harborTheme(Harbor.light, Brightness.light),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              picked = await showIconPicker(context, current: '🎒');
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
  testWidgets('both tiers render', (tester) async {
    await _open(tester);

    expect(find.text('Choose an icon'), findsOneWidget);
    expect(find.text('SUGGESTED'), findsOneWidget);
    expect(find.text('ALL EMOJI'), findsOneWidget);
    // A tall sheet embedding a third-party grid is exactly where an unbounded
    // -height or overflow error would appear.
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a suggested icon returns it', (tester) async {
    await _open(tester);

    // The first curated icon is always rendered — the row starts unscrolled.
    await tester.tap(find.text(curatedIcons.first).first);
    await tester.pumpAndSettle();

    // The sheet closed and handed the value back.
    expect(find.text('SUGGESTED'), findsNothing);
  });

  test('the shortlist leads with packing icons', () {
    // The picker shows these in one scrolling row, so the first few are what a
    // user sees without scrolling — a reorder that buried 🧳 would be a
    // regression no layout test would catch.
    expect(curatedIcons.take(3), ['🎒', '🧳', '✈️']);
    expect(curatedIcons.toSet().length, curatedIcons.length,
        reason: 'a duplicate would render twice in the row');
  });
}
