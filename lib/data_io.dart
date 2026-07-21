import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'store.dart';

/// Backup/restore as a single JSON file, moved around via the system share
/// sheet (export) and file picker (import). No cloud, no account — this is
/// how a list survives a phone migration.
class DataIO {
  /// Writes the store to a temp file and opens the share sheet.
  static Future<void> export(AppStore store) async {
    final json = store.exportJson();
    final stamp = DateTime.now().toIso8601String().split('T').first;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/pack-lite-backup-$stamp.json');
    await file.writeAsString(json);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      subject: 'Pack Lite backup',
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
