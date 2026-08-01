import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Rect;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'store.dart';

/// Backup/restore as a single JSON file, moved around via the system share
/// sheet (export) and file picker (import). No cloud, no account — this is
/// how a list survives a phone migration.
class DataIO {
  /// Writes the store to a temp file and opens the share sheet.
  ///
  /// [sharePositionOrigin] anchors the popover. It is required on iPad — and
  /// omitting it is why export did nothing at all on iOS (#37): the sheet
  /// could not be presented and the call returned quietly rather than
  /// throwing, so the caller's error handling never fired.
  ///
  /// Returns the [ShareResult] so callers can tell "shared" from "the platform
  /// declined to show anything", which are otherwise indistinguishable.
  static Future<ShareResult> export(AppStore store,
      {Rect? sharePositionOrigin}) async {
    final json = store.exportJson();
    final stamp = DateTime.now().toIso8601String().split('T').first;
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/pack-lite-backup-$stamp.json');
    await file.writeAsString(json);
    return Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      subject: 'Pack Lite backup',
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  /// Lets the user pick a JSON backup and returns its contents, or null if
  /// they cancelled. Throws on read failure.
  static Future<String?> pickImportFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    if (file.bytes != null) {
      return utf8.decode(file.bytes!);
    }
    if (file.path != null) {
      return File(file.path!).readAsString();
    }
    return null;
  }

  static bool looksValid(String raw) {
    try {
      final json = jsonDecode(raw);
      return json is Map && (json.containsKey('lists') || json.containsKey('presets'));
    } catch (_) {
      return false;
    }
  }

  static int countLists(String raw) {
    try {
      return ((jsonDecode(raw) as Map)['lists'] as List?)?.length ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static int countPresets(String raw) {
    try {
      return ((jsonDecode(raw) as Map)['presets'] as List?)?.length ?? 0;
    } catch (_) {
      return 0;
    }
  }
}

/// The `share_plus` package needs a small platform hint on some setups; keep
/// this here so we can tell web from native cleanly at call sites.
bool get isNativePlatform => !kIsWeb;
