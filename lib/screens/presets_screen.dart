import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../haptics.dart';
import '../models.dart';
import '../sheets/icon_picker.dart';
import '../store.dart';
import '../theme.dart';
import 'preset_editor.dart';

/// Manage List Presets: a card list mirroring the home screen. Tap to edit,
/// swipe to delete, long-press to reorder, + to create.
class PresetsScreen extends StatelessWidget {
  const PresetsScreen({super.key});

  Future<void> _newPreset(BuildContext context) async {
    final store = context.read<AppStore>();
    final result = await _namePresetDialog(context, title: 'New Preset');
    if (result == null) return;
    final preset = store.addPreset(result.$1, result.$2);
    if (context.mounted) {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PresetEditorScreen(presetId: preset.id)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final harbor = context.harbor;
    final store = context.watch<AppStore>();
    final presets = store.presets;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.arrow_back_ios_new_rounded,
                        size: 18, color: harbor.accent),
                  ),
                  Text('List Presets',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: harbor.ink)),
                ],
              ),
            ),
            Expanded(
              child: presets.isEmpty
                  ? _empty(harbor)
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                      buildDefaultDragHandles: false,
                      itemCount: presets.length,
                      onReorderStart: (_) => Haptics.tap(),
                      onReorderItem: (oldIndex, newIndex) =>
                          store.reorderPresets(oldIndex, newIndex),
                      itemBuilder: (context, index) {
                        final preset = presets[index];
                        return Padding(
                          key: ValueKey(preset.id),
                          padding: const EdgeInsets.only(bottom: 10),
                          child: ReorderableDelayedDragStartListener(
                            index: index,
                            child: Dismissible(
                              key: ValueKey('dis-${preset.id}'),
                              direction: DismissDirection.horizontal,
                              background: _delBg(harbor, Alignment.centerLeft),
                              secondaryBackground:
                                  _delBg(harbor, Alignment.centerRight),
                              confirmDismiss: (_) =>
                                  _confirmDelete(context, preset),
                              onDismissed: (_) => store.deletePreset(preset.id),
                              child: _PresetCard(preset: preset),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _newPreset(context),
        backgroundColor: harbor.accent,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }

  Widget _delBg(Harbor harbor, Alignment alignment) => Container(
        decoration: BoxDecoration(
            color: harbor.danger, borderRadius: BorderRadius.circular(12)),
        alignment: alignment,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: const Text('Delete',
            style: TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w700)),
      );

  Future<bool> _confirmDelete(BuildContext context, Preset preset) async {
    final harbor = context.harbor;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${preset.name}"?'),
        content: const Text('This preset will be deleted. Lists already '
            'created from it are not affected.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Delete', style: TextStyle(color: harbor.danger))),
        ],
      ),
    );
    return result ?? false;
  }

  Widget _empty(Harbor harbor) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('📋', style: TextStyle(fontSize: 44)),
              const SizedBox(height: 14),
              Text('No presets yet',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: harbor.ink)),
              const SizedBox(height: 6),
              Text(
                  'Presets are reusable sets of items — like your usual '
                  'toiletries. Tap + to build one, or save any list as a '
                  'preset from its menu.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: harbor.mut, height: 1.5)),
            ],
          ),
        ),
      );
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({required this.preset});

  final Preset preset;

  @override
  Widget build(BuildContext context) {
    final harbor = context.harbor;
    final categoryCount = preset.categories.length;
    final itemCount = preset.totalItems;
    return Container(
      decoration: BoxDecoration(
        color: harbor.card,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF17202B).withValues(alpha: 0.06),
              blurRadius: 3,
              offset: const Offset(0, 1)),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => PresetEditorScreen(presetId: preset.id))),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Text(preset.icon, style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(preset.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w600,
                              color: harbor.ink)),
                      const SizedBox(height: 3),
                      Text(
                        '$categoryCount categor${categoryCount == 1 ? 'y' : 'ies'} · '
                        '$itemCount item${itemCount == 1 ? '' : 's'}',
                        style: TextStyle(fontSize: 12.5, color: harbor.mut),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: harbor.mut),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small dialog to name a new preset and pick its icon.
Future<(String, String)?> _namePresetDialog(BuildContext context,
    {required String title}) {
  final controller = TextEditingController();
  var icon = '🎒';
  return showDialog<(String, String)>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final harbor = context.harbor;
        return AlertDialog(
          title: Text(title),
          content: Row(
            children: [
              GestureDetector(
                onTap: () async {
                  final picked =
                      await showIconPicker(context, current: icon);
                  if (picked != null) setState(() => icon = picked);
                },
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                      color: harbor.tile, borderRadius: BorderRadius.circular(12)),
                  alignment: Alignment.center,
                  child: Text(icon, style: const TextStyle(fontSize: 24)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  onSubmitted: (value) {
                    if (value.trim().isNotEmpty) {
                      Navigator.of(context).pop((value.trim(), icon));
                    }
                  },
                  decoration: const InputDecoration(
                      isDense: true, hintText: 'Preset name'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () {
                  if (controller.text.trim().isNotEmpty) {
                    Navigator.of(context).pop((controller.text.trim(), icon));
                  }
                },
                child: Text('Create', style: TextStyle(color: harbor.accent))),
          ],
        );
      },
    ),
  );
}
