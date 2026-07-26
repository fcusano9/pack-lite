import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../motion.dart';
import '../store.dart';
import '../theme.dart';

/// Sheet listing all presets. Tapping one returns its id (used when adding a
/// preset to an existing list). Returns null on cancel.
Future<String?> showPresetPicker(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    // Pick-one-and-dismiss, so it moves at menu pace rather than form pace.
    sheetAnimationStyle: Motion.menu,
    builder: (context) {
      final harbor = context.harbor;
      final presets = context.read<AppStore>().presets;
      return SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 34,
              height: 5,
              margin: const EdgeInsets.only(top: 8, bottom: 10),
              decoration: BoxDecoration(
                color: harbor.line,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Center(
              child: Text('Add Preset',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: harbor.ink)),
            ),
            const SizedBox(height: 6),
            if (presets.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                child: Text(
                  'No presets yet. Create reusable presets in Settings → '
                  'List Presets, or save any list as a preset from its menu.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: harbor.mut, height: 1.5),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                  itemCount: presets.length,
                  itemBuilder: (context, index) =>
                      _PresetRow(preset: presets[index]),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _PresetRow extends StatelessWidget {
  const _PresetRow({required this.preset});

  final Preset preset;

  @override
  Widget build(BuildContext context) {
    final harbor = context.harbor;
    final categoryCount = preset.categories.length;
    final itemCount = preset.totalItems;
    return ListTile(
      onTap: () => Navigator.of(context).pop(preset.id),
      leading: Text(preset.icon, style: const TextStyle(fontSize: 24)),
      title: Text(preset.name,
          style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600, color: harbor.ink)),
      subtitle: Text(
        '$categoryCount categor${categoryCount == 1 ? 'y' : 'ies'} · '
        '$itemCount item${itemCount == 1 ? '' : 's'}',
        style: TextStyle(fontSize: 12.5, color: harbor.mut),
      ),
      trailing: Icon(Icons.add_rounded, color: harbor.accent),
    );
  }
}
