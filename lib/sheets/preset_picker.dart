import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';

/// Sheet listing all presets. Tapping one returns its id (used when adding a
/// preset to an existing list). Returns null on cancel.
Future<String?> showPresetPicker(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (context) {
      final h = context.harbor;
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
                color: h.line,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Center(
              child: Text('Add Preset',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: h.ink)),
            ),
            const SizedBox(height: 6),
            if (presets.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                child: Text(
                  'No presets yet. Create reusable presets in Settings → '
                  'List Presets, or save any list as a preset from its menu.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: h.mut, height: 1.5),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                  itemCount: presets.length,
                  itemBuilder: (context, i) =>
                      _PresetRow(preset: presets[i]),
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
    final h = context.harbor;
    final catCount = preset.categories.length;
    final itemCount = preset.totalItems;
    return ListTile(
      onTap: () => Navigator.of(context).pop(preset.id),
      leading: Text(preset.icon, style: const TextStyle(fontSize: 24)),
      title: Text(preset.name,
          style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600, color: h.ink)),
      subtitle: Text(
        '$catCount categor${catCount == 1 ? 'y' : 'ies'} · '
        '$itemCount item${itemCount == 1 ? '' : 's'}',
        style: TextStyle(fontSize: 12.5, color: h.mut),
      ),
      trailing: Icon(Icons.add_rounded, color: h.accent),
    );
  }
}
