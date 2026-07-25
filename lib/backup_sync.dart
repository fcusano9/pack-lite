import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// Nudges Android's Auto Backup to upload the app's current data promptly.
///
/// Android backs `shared_prefs` up to the user's Google account roughly once a
/// day, and restores that snapshot when the app is reinstalled. Left alone,
/// that means deleting everything in the app can be silently undone: reinstall
/// within the backup window and the old lists come back.
///
/// Calling this straight after a destructive change asks the system for a
/// backup pass so the empty state replaces the stale snapshot. It is a request,
/// not a guarantee — the system decides when to run, and it cannot run at all
/// if the device is offline or the user has backup switched off.
class BackupSync {
  static const MethodChannel _channel =
      MethodChannel('com.packlite.app/backup');

  /// Best effort: never throws. A failed nudge must not break the delete the
  /// user actually asked for, and there is nothing useful to tell them about
  /// it — the local data is gone either way.
  static Future<void> dataChanged() async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<void>('dataChanged');
    } on MissingPluginException {
      // No native handler: iOS, or a widget test with no mock messenger.
    } on PlatformException {
      // Backup unavailable or disabled on this device.
    }
  }
}
