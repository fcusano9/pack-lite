import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_info.dart';
import '../data_io.dart';
import '../haptics.dart';
import '../links.dart';
import '../sound.dart';
import '../store.dart';
import '../theme.dart';
import 'presets_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final harbor = context.harbor;
    final store = context.watch<AppStore>();

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.arrow_back_ios_new_rounded,
                        size: 18, color: harbor.accent),
                  ),
                  Text('Settings',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: harbor.ink)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  _label(harbor, 'APPEARANCE'),
                  _seg(context, ['Light', 'Dark', 'System'], switch (store.themeMode) {
                    ThemeMode.light => 0,
                    ThemeMode.dark => 1,
                    ThemeMode.system => 2,
                  }, (index) {
                    store.setThemeMode(switch (index) {
                      0 => ThemeMode.light,
                      1 => ThemeMode.dark,
                      _ => ThemeMode.system,
                    });
                  }),
                  _label(harbor, 'VIBRATION'),
                  _seg(context, ['Off', 'Light', 'Medium', 'Strong'],
                      store.vibration.index, (index) {
                    store.setVibration(VibrationLevel.values[index]);
                    Haptics.tap();
                    SoundEffects.pop();
                  }),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Text(
                      'Works independently of your phone\'s touch-vibration '
                      'setting.',
                      style: TextStyle(fontSize: 12, color: harbor.mut, height: 1.4),
                    ),
                  ),
                  _label(harbor, 'GENERAL'),
                  _card(harbor, [
                    _row(context,
                        label: 'List Presets',
                        trailing: '${store.presets.length}',
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const PresetsScreen()))),
                    _divider(harbor),
                    _row(context,
                        label: 'Language', trailing: 'English', enabled: false),
                  ]),
                  _label(harbor, 'DATA'),
                  _card(harbor, [
                    _row(context,
                        label: 'Export Data',
                        onTap: () => _export(context)),
                    _divider(harbor),
                    _row(context,
                        label: 'Import Data',
                        onTap: () => _import(context)),
                    _divider(harbor),
                    _row(context,
                        label: 'Delete All Data',
                        danger: true,
                        onTap: () => _deleteAll(context)),
                  ]),
                  _label(harbor, 'ABOUT'),
                  _card(harbor, [
                    _row(context,
                        label: 'View Source on GitHub',
                        external: true,
                        onTap: () => _openLink(context, Links.sourceCode)),
                    _divider(harbor),
                    _row(context,
                        label: 'Sponsor on GitHub',
                        external: true,
                        onTap: () => _openLink(context, Links.sponsor)),
                  ]),
                  const SizedBox(height: 28),
                  Center(
                    child: Text(
                      'Pack Lite ${AppInfo.version}'.trim(),
                      style: TextStyle(
                          fontSize: 11.5,
                          color: harbor.mut.withValues(alpha: 0.75)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- outbound links ----

  /// Opens [url] in the browser. Failure is quiet but not silent: a device with
  /// no browser, or a blocked intent, gets a toast rather than a dead tap.
  Future<void> _openLink(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    bool opened;
    try {
      opened = await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('Couldn\'t open the link')));
    }
  }

  // ---- data actions ----

  Future<void> _export(BuildContext context) async {
    try {
      await DataIO.export(context.read<AppStore>());
    } catch (e) {
      if (context.mounted) _toast(context, 'Export failed: $e');
    }
  }

  Future<void> _import(BuildContext context) async {
    final store = context.read<AppStore>();
    String? raw;
    try {
      raw = await DataIO.pickImportFile();
    } catch (e) {
      if (context.mounted) _toast(context, 'Could not read file: $e');
      return;
    }
    if (raw == null) return; // cancelled
    if (!DataIO.looksValid(raw)) {
      if (context.mounted) {
        _toast(context, 'That doesn\'t look like a Pack Lite backup');
      }
      return;
    }
    if (!context.mounted) return;
    final lists = DataIO.countLists(raw);
    final presets = DataIO.countPresets(raw);
    final mode = await showDialog<String>(
      context: context,
      builder: (context) {
        final harbor = context.harbor;
        return AlertDialog(
          title: const Text('Import backup'),
          content: Text(
              'This file has $lists list${lists == 1 ? '' : 's'} and '
              '$presets preset${presets == 1 ? '' : 's'}.\n\n'
              'Add them to your current data, or replace everything?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.of(context).pop('merge'),
                child: Text('Add', style: TextStyle(color: harbor.accent))),
            TextButton(
                onPressed: () => Navigator.of(context).pop('replace'),
                child: Text('Replace', style: TextStyle(color: harbor.danger))),
          ],
        );
      },
    );
    if (mode == null) return;
    final result = store.importJson(raw, replace: mode == 'replace');
    if (context.mounted) {
      _toast(
          context,
          result == null
              ? 'Import failed — file may be corrupt'
              : 'Imported ${result.$1} list${result.$1 == 1 ? '' : 's'} and '
                  '${result.$2} preset${result.$2 == 1 ? '' : 's'}');
    }
  }

  Future<void> _deleteAll(BuildContext context) async {
    final store = context.read<AppStore>();
    final harbor = context.harbor;
    // First confirmation.
    final first = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete all data?'),
        content: const Text(
            'Every list and preset will be permanently deleted. This cannot '
            'be undone. Consider exporting a backup first.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Continue', style: TextStyle(color: harbor.danger))),
        ],
      ),
    );
    if (first != true || !context.mounted) return;
    // Second, type-to-confirm.
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Type DELETE to confirm'),
          content: TextField(
            controller: controller,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(isDense: true, hintText: 'DELETE'),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: controller.text.trim().toUpperCase() == 'DELETE'
                    ? () => Navigator.of(context).pop(true)
                    : null,
                child: Text('Delete Everything',
                    style: TextStyle(
                        color: controller.text.trim().toUpperCase() == 'DELETE'
                            ? harbor.danger
                            : harbor.mut))),
          ],
        ),
      ),
    );
    if (confirmed == true) {
      await store.deleteAllData();
      if (context.mounted) _toast(context, 'All data deleted');
    }
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ---- small UI helpers ----

  Widget _label(Harbor harbor, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Text(text,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                color: harbor.mut)),
      );

  Widget _card(Harbor harbor, List<Widget> children) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
            color: harbor.card, borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      );

  Widget _divider(Harbor harbor) =>
      Divider(height: 1, thickness: 1, color: harbor.line, indent: 14);

  Widget _row(BuildContext context,
      {required String label,
      String? trailing,
      bool danger = false,
      bool enabled = true,
      bool external = false,
      VoidCallback? onTap}) {
    final harbor = context.harbor;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: danger ? FontWeight.w600 : FontWeight.w400,
                      color: danger ? harbor.danger : harbor.ink)),
              const Spacer(),
              if (trailing != null)
                Text(trailing, style: TextStyle(fontSize: 13.5, color: harbor.mut)),
              if (onTap != null && !danger)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  // A chevron reads as "goes deeper in this app", so external
                  // links get the open-in-new glyph instead — the row leaves
                  // Pack Lite entirely.
                  child: Icon(
                      external
                          ? Icons.open_in_new_rounded
                          : Icons.chevron_right_rounded,
                      size: external ? 16 : 20,
                      color: harbor.mut),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _seg(BuildContext context, List<String> labels, int selected,
      ValueChanged<int> onSelect) {
    final harbor = context.harbor;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration:
            BoxDecoration(color: harbor.card, borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            for (var index = 0; index < labels.length; index++)
              Expanded(
                child: GestureDetector(
                  onTap: () => onSelect(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: selected == index ? harbor.accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(labels[index],
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: selected == index ? Colors.white : harbor.mut)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
