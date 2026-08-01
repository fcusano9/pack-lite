import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pack_lite/screens/settings_screen.dart';
import 'package:pack_lite/store.dart';
import 'package:pack_lite/theme.dart';

/// The vibration note is only true on Android, where the vibrator is driven
/// directly. iOS falls back to `HapticFeedback`, which *does* obey the system
/// setting — so the Android wording is simply false there (#38).
Widget _wrap(AppStore store) => ChangeNotifierProvider<AppStore>.value(
      value: store,
      child: MaterialApp(
        theme: harborTheme(Harbor.light, Brightness.light),
        home: const SettingsScreen(),
      ),
    );

Future<AppStore> _loadedStore() async {
  final store = AppStore();
  await store.load();
  return store;
}

const _androidCopy = "Works independently of your phone's touch-vibration setting.";
const _iosCopy =
    'Strength is approximate on iPhone, and follows your system haptic settings.';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// The override must be cleared *inside* the test body — flutter_test checks
  /// for stray debug vars before tearDown runs.
  Future<void> onPlatform(WidgetTester tester, TargetPlatform platform,
      Future<void> Function() body) async {
    debugDefaultTargetPlatformOverride = platform;
    try {
      await tester.pumpWidget(_wrap(await _loadedStore()));
      await tester.pumpAndSettle();
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  testWidgets('Android claims independence from the system setting',
      (tester) async {
    await onPlatform(tester, TargetPlatform.android, () async {
      expect(find.text(_androidCopy), findsOneWidget);
      expect(find.text(_iosCopy), findsNothing);
    });
  });

  testWidgets('iOS says the opposite, because it is', (tester) async {
    await onPlatform(tester, TargetPlatform.iOS, () async {
      expect(find.text(_iosCopy), findsOneWidget);
      expect(find.text(_androidCopy), findsNothing);
    });
  });
}
