import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pack_lite/models.dart';
import 'package:pack_lite/screens/list_screen.dart';
import 'package:pack_lite/store.dart';
import 'package:pack_lite/theme.dart';

/// Collapsed sections are per-list view state owned by the store, so they
/// survive leaving a list and coming back (#61), and "Collapse All" means every
/// section including Packed (#62).

Widget _wrap(AppStore store, String listId) =>
    ChangeNotifierProvider<AppStore>.value(
      value: store,
      child: MaterialApp(
        theme: harborTheme(Harbor.light, Brightness.light),
        home: ListScreen(listId: listId),
      ),
    );

/// A store with the seeded sample lists cleared out, so each test owns the
/// whole model.
Future<AppStore> _emptyStore() async {
  final store = AppStore();
  await store.load();
  for (final list in [...store.lists]) {
    store.deleteList(list.id);
  }
  return store;
}

/// One list, one category, two items, nothing packed — so there is no Packed
/// section on screen.
Future<(AppStore, PackingList, PackCategory)> _unpackedStore() async {
  final store = await _emptyStore();
  final list = store.addList('Trip', '🧳');
  final category = store.addCategory(list.id, 'Clothes', null);
  store.addItem(list.id, category.id, 'Socks');
  store.addItem(list.id, category.id, 'Shirt');
  return (store, list, category);
}

/// The same, with 'Shirt' packed — a category section and a Packed section on
/// screen at the same time.
Future<(AppStore, PackingList, PackCategory)> _packedStore() async {
  final (store, list, category) = await _unpackedStore();
  store.setItemChecked(list.id, category.id, category.items.last.id, true);
  return (store, list, category);
}

/// Drives the ··· menu's Collapse All, so tests exercise the screen's decision
/// about what "all" covers rather than restating it.
Future<void> _collapseAll(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.more_horiz_rounded));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Collapse All'));
  await tester.pumpAndSettle();
}

/// Lets the un-awaited writes inside the store's setters land in the mock
/// preferences before a second store reads them back.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('collapse all (#62)', () {
    testWidgets('collapses the Packed section along with the categories',
        (tester) async {
      final (store, list, category) = await _packedStore();
      await tester.pumpWidget(_wrap(store, list.id));

      await _collapseAll(tester);

      expect(store.isCollapsed(list.id, category.id), isTrue);
      expect(store.isCollapsed(list.id, AppStore.packedSectionKey), isTrue,
          reason: 'Packed is a section the user can fold like any other');
    });

    testWidgets('leaves Packed alone when nothing is packed yet',
        (tester) async {
      final (store, list, _) = await _unpackedStore();
      await tester.pumpWidget(_wrap(store, list.id));

      await _collapseAll(tester);

      expect(store.isCollapsed(list.id, AppStore.packedSectionKey), isFalse,
          reason: 'there is no Packed section on screen to collapse');

      // So the first item packed afterwards is visible rather than folded away
      // into a section the user never saw.
      final category = store.byId(list.id)!.categories.single;
      store.setItemChecked(list.id, category.id, category.items.first.id, true);
      await tester.pumpAndSettle();

      expect(find.text('Socks'), findsOneWidget);
    });

    test('expand all reopens the Packed section too', () async {
      final (store, list, category) = await _packedStore();
      store.setCollapsed(list.id, AppStore.packedSectionKey, true);
      store.setCollapsed(list.id, category.id, true);

      store.setCollapsedAll(list.id, const {});

      expect(store.isCollapsed(list.id, category.id), isFalse);
      expect(store.isCollapsed(list.id, AppStore.packedSectionKey), isFalse);
    });

    testWidgets('the menu hides packed items, not just category items',
        (tester) async {
      final (store, list, _) = await _packedStore();
      await tester.pumpWidget(_wrap(store, list.id));

      expect(find.text('Socks'), findsOneWidget);
      expect(find.text('Shirt'), findsOneWidget);

      await _collapseAll(tester);

      expect(find.text('Socks'), findsNothing);
      expect(find.text('Shirt'), findsNothing,
          reason: 'the packed item is hidden by Collapse All');
      // The headers themselves stay put — collapsed, not gone.
      expect(find.text('PACKED · 1'), findsOneWidget);
    });
  });

  group('persistence (#61)', () {
    test('collapsed sections survive a reload', () async {
      final (store, list, category) = await _packedStore();
      store.setCollapsed(list.id, category.id, true);
      store.setCollapsed(list.id, AppStore.packedSectionKey, true);
      await _settle();

      final reloaded = AppStore();
      await reloaded.load();

      expect(reloaded.isCollapsed(list.id, category.id), isTrue);
      expect(reloaded.isCollapsed(list.id, AppStore.packedSectionKey), isTrue);
    });

    test('expanding again is remembered', () async {
      final (store, list, category) = await _packedStore();
      store.setCollapsed(list.id, category.id, true);
      await _settle();
      store.setCollapsed(list.id, category.id, false);
      await _settle();

      final reloaded = AppStore();
      await reloaded.load();

      expect(reloaded.isCollapsed(list.id, category.id), isFalse);
    });

    test('collapse state stays out of the exported document', () async {
      final (store, list, category) = await _packedStore();
      store.setCollapsedAll(list.id, {category.id});

      final exported = jsonDecode(store.exportJson()) as Map<String, dynamic>;

      expect(exported.keys, isNot(contains('collapsed')));
      expect(store.exportJson(), isNot(contains(AppStore.packedSectionKey)),
          reason: 'an export describes what you pack, not your folded headers');
    });

    test('deleting a list drops its collapse state', () async {
      final (store, list, category) = await _packedStore();
      store.setCollapsed(list.id, category.id, true);
      await _settle();

      store.deleteList(list.id);
      await _settle();

      final reloaded = AppStore();
      await reloaded.load();
      expect(reloaded.isCollapsed(list.id, category.id), isFalse);
    });

    test('state for lists that no longer exist is pruned on load', () async {
      SharedPreferences.setMockInitialValues({
        'flutter.packlite.data':
            '{"v":2,"lists":[{"id":"x","name":"Trip","icon":"🧳","items":[],'
                '"categories":[{"id":"c","name":"Clothes","items":[]}]}],'
                '"categories":[]}',
        'flutter.packlite.collapsed': '{"x":["c"],"gone":["whatever"]}',
      });

      final store = AppStore();
      await store.load();

      expect(store.isCollapsed('x', 'c'), isTrue);
      expect(store.isCollapsed('gone', 'whatever'), isFalse);
    });

    test('an unreadable document just starts everything expanded', () async {
      SharedPreferences.setMockInitialValues({
        'flutter.packlite.collapsed': 'not json at all',
      });

      final store = AppStore();
      await store.load();

      expect(store.isCollapsed('x', 'c'), isFalse);
    });

    testWidgets('a collapsed category is still collapsed on the way back',
        (tester) async {
      final (store, list, _) = await _packedStore();
      await tester.pumpWidget(_wrap(store, list.id));
      expect(find.text('Socks'), findsOneWidget);

      // The name appears twice — the category header and the Packed section's
      // label for it. The header is the first of the two.
      await tester.tap(find.text('CLOTHES').first);
      await tester.pumpAndSettle();
      expect(find.text('Socks'), findsNothing);

      // Leaving the list and coming back builds a brand-new ListScreen State;
      // before #61 that reset the collapse set and everything sprang open.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_wrap(store, list.id));
      await tester.pumpAndSettle();

      expect(find.text('Socks'), findsNothing);
      // Only the category folded — Packed is tracked separately and stays open.
      expect(find.text('Shirt'), findsOneWidget);
    });
  });
}
