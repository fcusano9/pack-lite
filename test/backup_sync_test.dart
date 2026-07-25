import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pack_lite/store.dart';

/// Deleting everything has to push an empty snapshot to Android's Auto Backup,
/// otherwise a reinstall restores the day-old cloud copy and the deleted lists
/// come back (issue #24).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.frankcusano.pack_lite/backup');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('deleteAllData nudges Android to refresh its cloud backup', () async {
    final invokedMethods = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      invokedMethods.add(call.method);
      return null;
    });

    final store = AppStore();
    await store.load();
    expect(store.lists, isNotEmpty); // seeded

    await store.deleteAllData();

    expect(store.lists, isEmpty);
    expect(invokedMethods, ['dataChanged']);
  });

  test('deleteAllData still clears data when no native handler exists',
      () async {
    // No mock handler registered, so the channel throws
    // MissingPluginException — exactly what happens on iOS. The delete the
    // user asked for must go through regardless.
    final store = AppStore();
    await store.load();
    expect(store.lists, isNotEmpty);

    await store.deleteAllData();

    expect(store.lists, isEmpty);
    expect(store.presets, isEmpty);
  });

  test('deleteAllData survives the platform refusing the backup request',
      () async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => throw PlatformException(code: 'BACKUP_UNAVAILABLE'),
    );

    final store = AppStore();
    await store.load();

    await store.deleteAllData();

    expect(store.lists, isEmpty);
  });
}
