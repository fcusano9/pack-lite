import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../haptics.dart';
import '../models.dart';
import '../sheets/category_sheet.dart';
import '../store.dart';
import '../theme.dart';

/// Edits a preset. Looks and behaves like the packing list screen, minus
/// checkboxes and the packed section — a preset is a template, not a live
/// checklist. All edits are scoped to the preset via the preset* store ops.
class PresetEditorScreen extends StatefulWidget {
  const PresetEditorScreen({super.key, required this.presetId});

  final String presetId;

  @override
  State<PresetEditorScreen> createState() => _PresetEditorScreenState();
}

sealed class _Row {
  const _Row(this.key);
  final String key;
}

class _HeaderRow extends _Row {
  _HeaderRow(this.cat) : super('h-${cat.id}');
  final PackCategory cat;
}

class _ItemRow extends _Row {
  _ItemRow(this.cat, this.item, {this.firstInCard = false})
      : super('i-${item.id}');
  final PackCategory? cat; // null = loose
  final Item item;
  final bool firstInCard;
}

class _AddRow extends _Row {
  _AddRow(this.cat, {this.roundTop = false}) : super('a-${cat?.id ?? 'loose'}');
  final PackCategory? cat; // null = loose
  final bool roundTop;
}

class _PresetEditorScreenState extends State<PresetEditorScreen> {
  final Set<String> _collapsed = {};
  bool _adding = false;
  String? _addCatId; // null = loose section
  final TextEditingController _addCtrl = TextEditingController();
  final FocusNode _addFocus = FocusNode();

  AppStore get _store => context.read<AppStore>();

  @override
  void dispose() {
    _addCtrl.dispose();
    _addFocus.dispose();
    super.dispose();
  }

  void _commitAdd({required bool keepOpen}) {
    if (!_adding) return;
    final text = _addCtrl.text.trim();
    if (text.isNotEmpty) {
      _store.presetAddItem(widget.presetId, _addCatId, text);
      Haptics.tap();
    }
    _addCtrl.clear();
    if (keepOpen && text.isNotEmpty) {
      _addFocus.requestFocus();
    } else {
      setState(() => _adding = false);
    }
  }

  /// Opens the inline add row for [cat] (null = loose section).
  void _openAdd(PackCategory? cat) {
    _commitAdd(keepOpen: false);
    setState(() {
      _adding = true;
      _addCatId = cat?.id;
    });
    _addCtrl.clear();
  }

  Future<void> _renameItem(PackCategory? cat, Item item) async {
    final h = context.harbor;
    final ctrl = TextEditingController(text: item.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename item'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
          decoration: const InputDecoration(isDense: true),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(ctrl.text.trim()),
              child: Text('Save', style: TextStyle(color: h.accent))),
        ],
      ),
    );
    if (name != null && name.isNotEmpty && name != item.name) {
      _store.presetRenameItem(widget.presetId, cat?.id, item.id, name);
    }
  }

  void _deleteItem(PackCategory? cat, Item item) {
    final bucket =
        cat?.items ?? _store.presetById(widget.presetId)?.items ?? const [];
    final idx = bucket.indexWhere((i) => i.id == item.id);
    _store.presetDeleteItem(widget.presetId, cat?.id, item.id);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: const Text('Item deleted'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () =>
              _store.presetInsertItem(widget.presetId, cat?.id, idx, item),
        ),
      ));
  }

  Future<bool> _confirm(String title, String message, String label) async {
    final h = context.harbor;
    final r = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(label, style: TextStyle(color: h.danger))),
        ],
      ),
    );
    return r ?? false;
  }

  void _categoryMenu(PackCategory cat) {
    final h = context.harbor;
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 5,
              margin: const EdgeInsets.only(top: 8, bottom: 6),
              decoration: BoxDecoration(
                  color: h.line, borderRadius: BorderRadius.circular(3)),
            ),
            ListTile(
              leading: Icon(Icons.edit_outlined, size: 20, color: h.ink),
              title: Text('Rename & icon',
                  style: TextStyle(fontSize: 14.5, color: h.ink)),
              onTap: () {
                Navigator.of(sheetContext).pop();
                showCategorySheet(context,
                    presetId: widget.presetId, edit: cat);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded,
                  size: 20, color: h.danger),
              title: Text('Delete category',
                  style: TextStyle(fontSize: 14.5, color: h.danger)),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                final n = cat.items.length;
                if (await _confirm(
                    'Delete "${cat.name}"?',
                    n == 0
                        ? 'This category is empty.'
                        : 'Its $n item${n == 1 ? '' : 's'} will be deleted too.',
                    'Delete')) {
                  _store.presetDeleteCategory(widget.presetId, cat.id);
                }
              },
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  List<_Row> _buildRows(Preset preset) {
    final rows = <_Row>[];
    // Loose section at top: shown when there are loose items or no categories.
    if (preset.items.isNotEmpty || preset.categories.isEmpty) {
      for (var k = 0; k < preset.items.length; k++) {
        rows.add(_ItemRow(null, preset.items[k], firstInCard: k == 0));
      }
      rows.add(_AddRow(null, roundTop: preset.items.isEmpty));
    }
    for (final cat in preset.categories) {
      rows.add(_HeaderRow(cat));
      if (!_collapsed.contains(cat.id)) {
        for (final item in cat.items) {
          rows.add(_ItemRow(cat, item));
        }
        rows.add(_AddRow(cat));
      }
    }
    return rows;
  }

  void _onReorder(List<_Row> rows, int oldIndex, int newIndex) {
    final dragged = rows[oldIndex];
    if (dragged is! _ItemRow) return;
    final remaining = [...rows]..removeAt(oldIndex);
    PackCategory? target; // null = loose
    var pos = 0;
    for (var k = 0; k < newIndex && k < remaining.length; k++) {
      final row = remaining[k];
      if (row is _HeaderRow) {
        target = row.cat;
        pos = 0;
      } else if (row is _ItemRow && row.cat?.id == target?.id) {
        pos++;
      }
    }
    final preset = _store.presetById(widget.presetId);
    final bucket = target?.items ?? preset?.items ?? const [];
    final items = bucket.where((i) => i.id != dragged.item.id).toList();
    final insertAt = pos.clamp(0, items.length);
    _store.presetDeleteItem(widget.presetId, dragged.cat?.id, dragged.item.id);
    _store.presetInsertItem(
        widget.presetId, target?.id, insertAt, dragged.item.copy());
  }

  @override
  Widget build(BuildContext context) {
    final h = context.harbor;
    final store = context.watch<AppStore>();
    final preset = store.presetById(widget.presetId);
    if (preset == null) return const Scaffold(body: SizedBox.shrink());
    final rows = _buildRows(preset);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 6, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.arrow_back_ios_new_rounded,
                        size: 18, color: h.accent),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _editPresetMeta(preset),
                      child: Row(
                        children: [
                          Text(preset.icon,
                              style: const TextStyle(fontSize: 17)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(preset.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: h.ink)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () =>
                        showCategorySheet(context, presetId: widget.presetId),
                    icon: Icon(Icons.add_rounded, size: 24, color: h.accent),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: h.line),
            Expanded(
              child: (preset.items.isEmpty &&
                      preset.categories.isEmpty &&
                      !_adding)
                  ? _empty(h)
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(0, 6, 0, 40),
                      buildDefaultDragHandles: false,
                      itemCount: rows.length,
                      onReorderStart: (_) => Haptics.tap(),
                      onReorderItem: (o, n) => _onReorder(rows, o, n),
                      itemBuilder: (context, i) => _buildRow(preset, rows, i),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editPresetMeta(Preset preset) async {
    // Reuse category sheet's cousin? Simpler: inline rename dialog + icon.
    await showCategorySheet(context,
        presetMetaId: widget.presetId,
        edit: PackCategory(id: preset.id, name: preset.name, icon: preset.icon));
  }

  Widget _buildRow(Preset preset, List<_Row> rows, int index) {
    final h = context.harbor;
    final row = rows[index];
    switch (row) {
      case _HeaderRow(:final cat):
        final collapsed = _collapsed.contains(cat.id);
        return Container(
          key: ValueKey(row.key),
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          decoration: BoxDecoration(
            color: h.card,
            borderRadius: collapsed
                ? BorderRadius.circular(12)
                : const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: InkWell(
            onTap: () => setState(() => collapsed
                ? _collapsed.remove(cat.id)
                : _collapsed.add(cat.id)),
            onLongPress: () => _categoryMenu(cat),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(15, 13, 15, 7),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        if (cat.icon != null) ...[
                          Text(cat.icon!, style: const TextStyle(fontSize: 13)),
                          const SizedBox(width: 5),
                        ],
                        Flexible(
                          child: Text(cat.name.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.7,
                                  color: h.mut)),
                        ),
                        const SizedBox(width: 6),
                        Text('· ${cat.items.length}',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: h.mut)),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: collapsed ? -0.25 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(Icons.keyboard_arrow_down_rounded,
                        size: 17, color: h.mut),
                  ),
                ],
              ),
            ),
          ),
        );

      case _ItemRow(:final cat, :final item, :final firstInCard):
        return Container(
          key: ValueKey(row.key),
          margin: const EdgeInsets.symmetric(horizontal: 12),
          clipBehavior: firstInCard ? Clip.antiAlias : Clip.none,
          decoration: BoxDecoration(
            color: h.card,
            borderRadius: firstInCard
                ? const BorderRadius.vertical(top: Radius.circular(12))
                : null,
          ),
          child: ReorderableDelayedDragStartListener(
            index: index,
            child: Dismissible(
              key: ValueKey('dis-${row.key}'),
              background: Container(
                color: h.accent,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: const Text('Rename',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ),
              secondaryBackground: Container(
                color: h.danger,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: const Text('Delete',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ),
              confirmDismiss: (direction) async {
                if (direction == DismissDirection.startToEnd) {
                  _renameItem(cat, item);
                  return false;
                }
                return true;
              },
              onDismissed: (_) => _deleteItem(cat, item),
              child: Container(
                decoration: firstInCard
                    ? null
                    : BoxDecoration(
                        border: Border(top: BorderSide(color: h.line))),
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.only(left: 8, right: 16),
                      decoration:
                          BoxDecoration(color: h.mut, shape: BoxShape.circle),
                    ),
                    Expanded(
                      child: Text(item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 15, color: h.ink)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

      case _AddRow(:final cat, :final roundTop):
        final active = _adding && _addCatId == cat?.id;
        final radius = roundTop
            ? BorderRadius.circular(12)
            : const BorderRadius.vertical(bottom: Radius.circular(12));
        return Container(
          key: ValueKey(row.key),
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: active ? h.accentSoft : h.card,
            borderRadius: radius,
          ),
          child: InkWell(
            onTap: active ? null : () => _openAdd(cat),
            borderRadius: radius,
            child: Container(
              decoration: roundTop
                  ? null
                  : BoxDecoration(
                      border: Border(top: BorderSide(color: h.line))),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              child: active
                  ? Row(
                      children: [
                        const SizedBox(width: 29),
                        Expanded(
                          child: TextField(
                            controller: _addCtrl,
                            focusNode: _addFocus,
                            autofocus: true,
                            textCapitalization: TextCapitalization.sentences,
                            onSubmitted: (_) => _commitAdd(keepOpen: true),
                            onTapOutside: (_) => _commitAdd(keepOpen: false),
                            style: TextStyle(fontSize: 15, color: h.ink),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'Item name',
                              hintStyle: TextStyle(color: h.mut),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        SizedBox(
                            width: 24,
                            child:
                                Icon(Icons.add_rounded, size: 17, color: h.mut)),
                        const SizedBox(width: 11),
                        Text('Add item',
                            style: TextStyle(fontSize: 14, color: h.mut)),
                      ],
                    ),
            ),
          ),
        );
    }
  }

  Widget _empty(Harbor h) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 44),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📋', style: TextStyle(fontSize: 42)),
            const SizedBox(height: 14),
            Text('Empty preset',
                style: TextStyle(
                    fontSize: 15.5, fontWeight: FontWeight.w700, color: h.ink)),
            const SizedBox(height: 6),
            Text('Add items directly, or use + to add a category.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: h.mut, height: 1.5)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _openAdd(null),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add item'),
              style: FilledButton.styleFrom(
                backgroundColor: h.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11)),
                textStyle:
                    const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
