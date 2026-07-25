import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pack_lite/main.dart';
import 'package:pack_lite/store.dart';

/// A fresh install must follow the phone's light/dark setting rather than
/// pinning itself to light. Guards the store default AND the wiring in
/// MaterialApp (a correct `themeMode` still renders light if `darkTheme` is
/// missing or mis-built).
void main() {
  testWidgets('fresh install defaults to ThemeMode.system', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore();
    await store.load();

    expect(store.themeMode, ThemeMode.system);
  });

  testWidgets('fresh install renders dark when the phone is in dark mode',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore();
    await store.load();

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(PackLiteApp(store: store));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(Scaffold).first);
    expect(Theme.of(context).brightness, Brightness.dark);
  });

  testWidgets('fresh install renders light when the phone is in light mode',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore();
    await store.load();

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(PackLiteApp(store: store));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(Scaffold).first);
    expect(Theme.of(context).brightness, Brightness.light);
  });

  testWidgets('a previously saved light choice still wins over system',
      (tester) async {
    SharedPreferences.setMockInitialValues({'flutter.packlite.theme': 'light'});
    final store = AppStore();
    await store.load();

    expect(store.themeMode, ThemeMode.light);
  });
}
