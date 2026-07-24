import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pack_lite/models.dart';
import 'package:pack_lite/screens/home.dart';
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

  testWidgets('swipe-right on a home card duplicates the list', (tester) async {
    final store = AppStore();
    await store.load();
    store.lists
      ..clear()
      ..add(PackingList(id: 'a', name: 'Trip', icon: '🧳'));

    await tester.pumpWidget(_wrap(store, const HomeScreen()));
    await tester.pumpAndSettle();

    expect(store.lists.length, 1);
    expect(find.text('Trip'), findsOneWidget);

    // Swipe the card to the right → duplicate. The card stays (confirmDismiss
    // returns false); the list count grows and a "<name> copy" appears.
    await tester.drag(find.text('Trip'), const Offset(600, 0));
    await tester.pumpAndSettle();

    expect(store.lists.length, 2);
    expect(store.lists.any((list) => list.name == 'Trip copy'), isTrue);
    expect(find.text('Trip'), findsOneWidget);
    expect(find.text('Trip copy'), findsOneWidget);

    // Flush the snackbar's auto-dismiss timer so none is pending at teardown.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}
