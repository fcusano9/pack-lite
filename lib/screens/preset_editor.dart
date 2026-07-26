import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../haptics.dart';
import '../models.dart';
import '../motion.dart';
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
  _HeaderRow(this.category) : super('header-${category.id}');
  final PackCategory category;
}

class _ItemRow extends _Row {
  _ItemRow(this.category, this.item, {this.firstInCard = false})
      : super('item-${item.id}');
  final PackCategory? category; // null = loose
  final Item item;
  final bool firstInCard;
}

class _AddRow extends _Row {
  _AddRow(this.category, {this.roundTop = false}) : super('a-${category?.id ?? 'loose'}');
  final PackCategory? category; // null = loose
  final bool roundTop;
}

class _PresetEditorScreenState extends State<PresetEditorScreen> {
  final Set<String> _collapsed = {};
  bool _adding = false;
  String? _addCategoryId; // null = loose section
  final TextEditingController _addController = TextEditingController();
  final FocusNode _addFocus = FocusNode();

  AppStore get _store => context.read<AppStore>();

  @override
  void dispose() {
    _addController.dispose();
    _addFocus.dispose();
    super.dispose();
  }

  void _commitAdd({required bool keepOpen}) {
    if (!_adding) return;
    final text = _addController.text.trim();
    if (text.isNotEmpty) {
      _store.presetAddItem(widget.presetId, _addCategoryId, text);
      Haptics.tap();
    }
    _addController.clear();
    if (keepOpen && text.isNotEmpty) {
      _addFocus.requestFocus();
    } else {
      setState(() => _adding = false);
    }
  }

  /// Opens the inline add row for [category] (null = loose section).
  void _openAdd(PackCategory? category) {
    _commitAdd(keepOpen: false);
    setState(() {
      _adding = true;
      _addCategoryId = category?.id;
    });
    _addController.clear();
  }

  Future<void> _renameItem(PackCategory? category, Item item) async {
    final harbor = context.harbor;
    final controller = TextEditingController(text: item.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename item'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
          decoration: const InputDecoration(isDense: true),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: Text('Save', style: TextStyle(color: harbor.accent))),
        ],
      ),
    );
    if (name != null && name.isNotEmpty && name != item.name) {
      _store.presetRenameItem(widget.presetId, category?.id, item.id, name);
    }
  }

  void _deleteItem(PackCategory? category, Item item) {
    final bucket =
        category?.items ?? _store.presetById(widget.presetId)?.items ?? const [];
    final index = bucket.indexWhere((bucketItem) => bucketItem.id == item.id);
    _store.presetDeleteItem(widget.presetId, category?.id, item.id);
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    final snackBar = messenger.showSnackBar(SnackBar(
      content: const Text('Item deleted'),
      duration: const Duration(seconds: 4),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () =>
            _store.presetInsertItem(widget.presetId, category?.id, index, item),
      ),
    ));
    // SnackBars with an action ignore `duration` in this Flutter version, so
    // close it ourselves (cancelled if it's dismissed sooner).
    final timer = Timer(const Duration(seconds: 4), snackBar.close);
    snackBar.closed.then((_) => timer.cancel());
  }

  Future<bool> _confirm(String title, String message, String label) async {
    final harbor = context.harbor;
    final result = await showDialog<bool>(
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
              child: Text(label, style: TextStyle(color: harbor.danger))),
        ],
      ),
    );
    return result ?? false;
  }

  void _categoryMenu(PackCategory category) {
    final harbor = context.harbor;
    showModalBottomSheet<void>(
      context: context,
      // An action menu, not a form — matches the popup menus' pace.
      sheetAnimationStyle: Motion.menu,
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
                  color: harbor.line, borderRadius: BorderRadius.circular(3)),
            ),
            ListTile(
              leading: Icon(Icons.edit_outlined, size: 20, color: harbor.ink),
              title: Text('Rename & icon',
                  style: TextStyle(fontSize: 14.5, color: harbor.ink)),
              onTap: () {
                Navigator.of(sheetContext).pop();
                showCategorySheet(context,
                    presetId: widget.presetId, edit: category);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded,
                  size: 20, color: harbor.danger),
              title: Text('Delete category',
                  style: TextStyle(fontSize: 14.5, color: harbor.danger)),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                final itemCount = category.items.length;
                if (await _confirm(
                    'Delete "${category.name}"?',
                    itemCount == 0
                        ? 'This category is empty.'
                        : 'Its $itemCount item${itemCount == 1 ? '' : 's'} will be deleted too.',
                    'Delete')) {
                  _store.presetDeleteCategory(widget.presetId, category.id);
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
      for (var index = 0; index < preset.items.length; index++) {
        rows.add(_ItemRow(null, preset.items[index], firstInCard: index == 0));
      }
      rows.add(_AddRow(null, roundTop: preset.items.isEmpty));
    }
    for (final category in preset.categories) {
      rows.add(_HeaderRow(category));
      if (!_collapsed.contains(category.id)) {
        for (final item in category.items) {
          rows.add(_ItemRow(category, item));
        }
        rows.add(_AddRow(category));
      }
    }
    return rows;
  }

  void _onReorder(List<_Row> rows, int oldIndex, int newIndex) {
    final dragged = rows[oldIndex];
    if (dragged is! _ItemRow) return;
    final remaining = [...rows]..removeAt(oldIndex);
    PackCategory? target; // null = loose
    var position = 0;
    for (var index = 0; index < newIndex && index < remaining.length; index++) {
      final row = remaining[index];
      if (row is _HeaderRow) {
        target = row.category;
        position = 0;
      } else if (row is _ItemRow && row.category?.id == target?.id) {
        position++;
      }
    }
    final preset = _store.presetById(widget.presetId);
    final bucket = target?.items ?? preset?.items ?? const [];
    final items = bucket.where((item) => item.id != dragged.item.id).toList();
    final insertAt = position.clamp(0, items.length);
    _store.presetDeleteItem(widget.presetId, dragged.category?.id, dragged.item.id);
    _store.presetInsertItem(
        widget.presetId, target?.id, insertAt, dragged.item.copy());
  }

  @override
  Widget build(BuildContext context) {
    final harbor = context.harbor;
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
                        size: 18, color: harbor.accent),
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
                                    color: harbor.ink)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () =>
                        showCategorySheet(context, presetId: widget.presetId),
                    icon: Icon(Icons.add_rounded, size: 24, color: harbor.accent),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: harbor.line),
            Expanded(
              child: (preset.items.isEmpty &&
                      preset.categories.isEmpty &&
                      !_adding)
                  ? _empty(harbor)
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(0, 6, 0, 40),
                      buildDefaultDragHandles: false,
                      itemCount: rows.length,
                      onReorderStart: (_) => Haptics.tap(),
                      onReorderItem: (oldIndex, newIndex) =>
                          _onReorder(rows, oldIndex, newIndex),
                      itemBuilder: (context, index) =>
                          _buildRow(preset, rows, index),
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
    final harbor = context.harbor;
    final row = rows[index];
    switch (row) {
      case _HeaderRow(:final category):
        final collapsed = _collapsed.contains(category.id);
        return Container(
          key: ValueKey(row.key),
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          decoration: BoxDecoration(
            color: harbor.card,
            borderRadius: collapsed
                ? BorderRadius.circular(12)
                : const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: InkWell(
            onTap: () => setState(() => collapsed
                ? _collapsed.remove(category.id)
                : _collapsed.add(category.id)),
            onLongPress: () => _categoryMenu(category),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(15, 13, 15, 7),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        if (category.icon != null) ...[
                          Text(category.icon!, style: const TextStyle(fontSize: 13)),
                          const SizedBox(width: 5),
                        ],
                        Flexible(
                          child: Text(category.name.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.7,
                                  color: harbor.mut)),
                        ),
                        const SizedBox(width: 6),
                        Text('· ${category.items.length}',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: harbor.mut)),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: collapsed ? -0.25 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(Icons.keyboard_arrow_down_rounded,
                        size: 17, color: harbor.mut),
                  ),
                ],
              ),
            ),
          ),
        );

      case _ItemRow(:final category, :final item, :final firstInCard):
        return Container(
          key: ValueKey(row.key),
          margin: const EdgeInsets.symmetric(horizontal: 12),
          clipBehavior: firstInCard ? Clip.antiAlias : Clip.none,
          decoration: BoxDecoration(
            color: harbor.card,
            borderRadius: firstInCard
                ? const BorderRadius.vertical(top: Radius.circular(12))
                : null,
          ),
          child: ReorderableDelayedDragStartListener(
            index: index,
            child: Dismissible(
              key: ValueKey('dis-${row.key}'),
              background: Container(
                color: harbor.accent,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: const Text('Rename',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ),
              secondaryBackground: Container(
                color: harbor.danger,
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
                  _renameItem(category, item);
                  return false;
                }
                return true;
              },
              onDismissed: (_) => _deleteItem(category, item),
              child: Container(
                decoration: firstInCard
                    ? null
                    : BoxDecoration(
                        border: Border(top: BorderSide(color: harbor.line))),
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.only(left: 8, right: 16),
                      decoration:
                          BoxDecoration(color: harbor.mut, shape: BoxShape.circle),
                    ),
                    Expanded(
                      child: Text(item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 15, color: harbor.ink)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

      case _AddRow(:final category, :final roundTop):
        final active = _adding && _addCategoryId == category?.id;
        final radius = roundTop
            ? BorderRadius.circular(12)
            : const BorderRadius.vertical(bottom: Radius.circular(12));
        return Container(
          key: ValueKey(row.key),
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: active ? harbor.accentSoft : harbor.card,
            borderRadius: radius,
          ),
          child: InkWell(
            onTap: active ? null : () => _openAdd(category),
            borderRadius: radius,
            child: Container(
              // Always pass a decoration — see the matching comment in
              // list_screen.dart. A null -> non-null flip changes the tree
              // depth below Container, disposing the TextField's state and
              // dropping the keyboard as the first item is added (#22).
              decoration: BoxDecoration(
                border: Border(
                  top: roundTop
                      ? BorderSide.none
                      : BorderSide(color: harbor.line),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              child: active
                  ? Row(
                      children: [
                        const SizedBox(width: 29),
                        Expanded(
                          child: TextField(
                            controller: _addController,
                            focusNode: _addFocus,
                            autofocus: true,
                            textCapitalization: TextCapitalization.sentences,
                            onSubmitted: (_) => _commitAdd(keepOpen: true),
                            onTapOutside: (_) => _commitAdd(keepOpen: false),
                            style: TextStyle(fontSize: 15, color: harbor.ink),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'Item name',
                              hintStyle: TextStyle(color: harbor.mut),
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
                                Icon(Icons.add_rounded, size: 17, color: harbor.mut)),
                        const SizedBox(width: 11),
                        Text('Add item',
                            style: TextStyle(fontSize: 14, color: harbor.mut)),
                      ],
                    ),
            ),
          ),
        );
    }
  }

  Widget _empty(Harbor harbor) {
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
                    fontSize: 15.5, fontWeight: FontWeight.w700, color: harbor.ink)),
            const SizedBox(height: 6),
            Text('Add items directly, or use + to add a category.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: harbor.mut, height: 1.5)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _openAdd(null),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add item'),
              style: FilledButton.styleFrom(
                backgroundColor: harbor.accent,
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
