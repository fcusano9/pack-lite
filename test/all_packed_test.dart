import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pack_lite/models.dart';
import 'package:pack_lite/screens/list_screen.dart';
import 'package:pack_lite/store.dart';
import 'package:pack_lite/theme.dart';

Widget _wrap(AppStore store, Widget child) {
  return ChangeNotifierProvider<AppStore>.value(
    value: store,
    child: MaterialApp(
      theme: harborTheme(Harbor.light, Brightness.light),
      home: child,
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a fully packed list shows the All packed card', (tester) async {
    final store = AppStore();
    await store.load();
    store.lists.insert(
      0,
      PackingList(
        id: 'done',
        name: 'Done Trip',
        icon: '🧳',
        items: [Item(id: 'a', name: 'Toothbrush', checked: true)],
      ),
    );

    await tester.pumpWidget(_wrap(store, const ListScreen(listId: 'done')));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('All packed'), findsOneWidget);
  });

  testWidgets('a partially packed list does NOT show the card', (tester) async {
    final store = AppStore();
    await store.load();
    store.lists.insert(
      0,
      PackingList(
        id: 'wip',
        name: 'In Progress',
        icon: '🧳',
        items: [
          Item(id: 'a', name: 'Toothbrush', checked: true),
          Item(id: 'b', name: 'Socks'),
        ],
      ),
    );

    await tester.pumpWidget(_wrap(store, const ListScreen(listId: 'wip')));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('All packed'), findsNothing);
  });
}
