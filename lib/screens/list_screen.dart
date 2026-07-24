import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../haptics.dart';
import '../models.dart';
import '../sheets/category_sheet.dart';
import '../sheets/new_list_sheet.dart';
import '../sheets/preset_picker.dart';
import '../sheets/reorder_categories_sheet.dart';
import '../store.dart';
import '../theme.dart';
import '../sound.dart';
import '../widgets/celebration.dart';
import '../widgets/list_card.dart' show ProgressBar;

/// The Packing List Screen: condensed header C on top, categories as cards,
/// checked items sinking into the Packed section at the bottom.
class ListScreen extends StatefulWidget {
  const ListScreen({super.key, required this.listId});

  final String listId;

  @override
  State<ListScreen> createState() => _ListScreenState();
}

// ---- row model for the single flattened reorderable list ----

sealed class _Row {
  const _Row(this.key);
  final String key;
}

class _CategoryHeaderRow extends _Row {
  _CategoryHeaderRow(this.category) : super('header-${category.id}');
  final PackCategory category;
}

/// An item row. [category] is null for loose items (not in any category).
/// [firstInCard] is true only for the first loose item, which rounds the top
/// of the header-less loose card.
class _ItemRow extends _Row {
  _ItemRow(this.category, this.item, {this.firstInCard = false})
      : super('item-${item.id}');
  final PackCategory? category;
  final Item item;
  final bool firstInCard;
}

/// The inline "Add item" row. [category] is null for the loose add row. [roundTop]
/// is true when it's also the top of its card (a loose section with no items).
class _AddRow extends _Row {
  _AddRow(this.category, {this.roundTop = false}) : super('a-${category?.id ?? 'loose'}');
  final PackCategory? category;
  final bool roundTop;
}

class _PackedHeaderRow extends _Row {
  _PackedHeaderRow(this.count) : super('packed-header');
  final int count;
}

class _PackedLabelRow extends _Row {
  _PackedLabelRow(this.category) : super('pl-${category.id}');
  final PackCategory category;
}

/// A packed (checked) item row. [category] is null for loose packed items.
class _PackedItemRow extends _Row {
  _PackedItemRow(this.category, this.item,
      {required this.isFirst, required this.isLast})
      : super('pi-${item.id}');
  final PackCategory? category;
  final Item item;
  final bool isFirst;
  final bool isLast;
}

class _ListScreenState extends State<ListScreen> {
  final Set<String> _collapsed = {};
  bool _packedCollapsed = false;
  // Inline-add state: [_adding] is whether a row is open; [_addCategoryId] is which
  // bucket it targets (null = the loose section).
  bool _adding = false;
  String? _addCategoryId;
  final TextEditingController _addController = TextEditingController();
  final FocusNode _addFocus = FocusNode();
  final Set<String> _pendingCheck = {};
  bool _wasReady = false;

  @override
  void initState() {
    super.initState();
    final list = context.read<AppStore>().byId(widget.listId);
    _wasReady = list?.isReady ?? false;
  }

  @override
  void dispose() {
    _addController.dispose();
    _addFocus.dispose();
    super.dispose();
  }

  AppStore get _store => context.read<AppStore>();

  // ---- check-off ----

  void _toggle(PackCategory? category, Item item) {
    if (item.checked) {
      _store.setItemChecked(widget.listId, category?.id, item.id, false);
      return;
    }
    if (_pendingCheck.contains(item.id)) return;
    Haptics.tap();
    SoundEffects.pop();
    setState(() => _pendingCheck.add(item.id));
    // Let the checkmark land for a beat before the row glides to Packed.
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _pendingCheck.remove(item.id));
      _store.setItemChecked(widget.listId, category?.id, item.id, true);
    });
  }

  void _maybeCelebrate(PackingList list) {
    final ready = list.isReady;
    if (ready && !_wasReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Haptics.celebrate();
        SoundEffects.popBig();
        showCelebration(context);
      });
    }
    _wasReady = ready;
  }

  // ---- inline add ----

  void _commitAdd({required bool keepOpen}) {
    if (!_adding) return;
    final text = _addController.text.trim();
    if (text.isNotEmpty) {
      _store.addItem(widget.listId, _addCategoryId, text);
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

  // ---- dialogs & menus ----

  Future<bool> _confirm(String title, String message, String confirmLabel,
      {bool danger = true}) async {
    final harbor = context.harbor;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel,
                style: TextStyle(color: danger ? harbor.danger : harbor.accent)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _addPreset() async {
    final presetId = await showPresetPicker(context);
    if (presetId == null || !mounted) return;
    final before = _store.byId(widget.listId)!.totalItems;
    _store.addPresetToList(widget.listId, presetId);
    final added = _store.byId(widget.listId)!.totalItems - before;
    Haptics.tap();
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(added == 0
            ? 'All preset items were already in this list'
            : 'Added $added item${added == 1 ? '' : 's'} from preset'),
      ));
  }

  Future<void> _saveAsPreset(PackingList list) async {
    _store.saveListAsPreset(widget.listId);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text('Saved "${list.name}" as a preset')));
  }

  Future<void> _uncheckAll(PackingList list) async {
    final packedCount = list.packedItems;
    if (packedCount == 0) return;
    if (await _confirm('Uncheck all ${list.totalItems} items?',
        'Ready to pack for the next trip — nothing is deleted.', 'Uncheck All',
        danger: false)) {
      Haptics.tap();
      _wasReady = false;
      _store.uncheckAll(widget.listId);
    }
  }

  Future<void> _deleteList(PackingList list) async {
    if (await _confirm('Delete "${list.name}"?',
        'This list and all of its items will be deleted.', 'Delete')) {
      _store.deleteList(widget.listId);
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _categoryMenu(PackingList list, PackCategory category) {
    final harbor = context.harbor;
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
                color: harbor.line,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            ListTile(
              leading: Icon(Icons.edit_outlined, size: 20, color: harbor.ink),
              title: Text('Rename & icon',
                  style: TextStyle(fontSize: 14.5, color: harbor.ink)),
              onTap: () {
                Navigator.of(sheetContext).pop();
                showCategorySheet(context, listId: widget.listId, edit: category);
              },
            ),
            if (list.categories.length >= 2)
              ListTile(
                leading:
                    Icon(Icons.swap_vert_rounded, size: 20, color: harbor.ink),
                title: Text('Reorder categories',
                    style: TextStyle(fontSize: 14.5, color: harbor.ink)),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  showReorderCategoriesSheet(context, listId: widget.listId);
                },
              ),
            ListTile(
              leading: Icon(Icons.bookmark_add_outlined, size: 20, color: harbor.ink),
              title: Text('Save as preset',
                  style: TextStyle(fontSize: 14.5, color: harbor.ink)),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _store.saveCategoryAsPreset(widget.listId, category.id);
                ScaffoldMessenger.of(context)
                  ..clearSnackBars()
                  ..showSnackBar(SnackBar(
                      content: Text('Saved "${category.name}" as a preset')));
              },
            ),
            ListTile(
              leading:
                  Icon(Icons.delete_outline_rounded, size: 20, color: harbor.danger),
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
                  _store.deleteCategory(widget.listId, category.id);
                }
              },
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  void _deleteItem(PackCategory? category, Item item) {
    final bucket = category?.items ?? _store.byId(widget.listId)?.items ?? const [];
    final modelIndex = bucket.indexWhere((bucketItem) => bucketItem.id == item.id);
    _store.deleteItem(widget.listId, category?.id, item.id);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: const Text('Item deleted'),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () =>
                _store.insertItem(widget.listId, category?.id, modelIndex, item),
          ),
        ),
      );
  }

  // ---- reorder ----

  List<_Row> _buildRows(PackingList list) {
    final rows = <_Row>[];

    // Loose section at the top. Shown when there are loose items or the list
    // has no categories at all (so a flat list always has its add row).
    final looseUnchecked = list.items.where((item) => !item.checked).toList();
    if (list.items.isNotEmpty || list.categories.isEmpty) {
      for (var index = 0; index < looseUnchecked.length; index++) {
        rows.add(_ItemRow(null, looseUnchecked[index], firstInCard: index == 0));
      }
      rows.add(_AddRow(null, roundTop: looseUnchecked.isEmpty));
    }

    // Categories.
    for (final category in list.categories) {
      rows.add(_CategoryHeaderRow(category));
      if (!_collapsed.contains(category.id)) {
        final unchecked = category.items.where((item) => !item.checked).toList();
        for (final item in unchecked) {
          rows.add(_ItemRow(category, item));
        }
        rows.add(_AddRow(category));
      }
    }

    // Packed section: loose packed first (no label), then labeled categories.
    final packedCount = list.packedItems;
    if (packedCount > 0) {
      rows.add(_PackedHeaderRow(packedCount));
      if (!_packedCollapsed) {
        final loosePacked = list.items.where((item) => item.checked).toList();
        for (var index = 0; index < loosePacked.length; index++) {
          rows.add(_PackedItemRow(null, loosePacked[index],
              isFirst: index == 0, isLast: index == loosePacked.length - 1));
        }
        for (final category in list.categories) {
          final checked = category.items.where((item) => item.checked).toList();
          if (checked.isEmpty) continue;
          rows.add(_PackedLabelRow(category));
          for (var index = 0; index < checked.length; index++) {
            rows.add(_PackedItemRow(category, checked[index],
                isFirst: index == 0, isLast: index == checked.length - 1));
          }
        }
      }
    }
    return rows;
  }

  /// The model index at which to insert the dragged item so it lands at
  /// [uncheckedPos] among the unchecked items of [category] (null = loose bucket).
  int _modelInsertIndex(PackCategory? category, String draggedId, int uncheckedPos) {
    final bucket = category?.items ?? _store.byId(widget.listId)?.items ?? const [];
    final items = bucket.where((item) => item.id != draggedId).toList();
    var seen = 0;
    for (var index = 0; index < items.length; index++) {
      if (!items[index].checked) {
        if (seen == uncheckedPos) return index;
        seen++;
      }
    }
    return items.length;
  }

  void _onReorder(List<_Row> rows, int oldIndex, int newIndex) {
    final dragged = rows[oldIndex];
    if (dragged is! _ItemRow) return;

    final remaining = [...rows]..removeAt(oldIndex);
    // Default target is the loose section (null), since it sits at the top.
    PackCategory? targetCategory;
    var uncheckedPos = 0;
    var inPacked = false;

    for (var index = 0; index < newIndex && index < remaining.length; index++) {
      final row = remaining[index];
      if (row is _CategoryHeaderRow) {
        targetCategory = row.category;
        uncheckedPos = 0;
      } else if (row is _ItemRow) {
        if (row.category?.id == targetCategory?.id) uncheckedPos++;
      } else if (row is _PackedHeaderRow) {
        inPacked = true;
        break;
      }
    }

    if (inPacked) {
      // Dropped into the Packed area: clamp to the end of the current bucket.
      uncheckedPos = 1 << 30;
    }

    final insertAt = _modelInsertIndex(targetCategory, dragged.item.id, uncheckedPos);
    _store.moveItem(widget.listId, dragged.category?.id, dragged.item.id,
        targetCategory?.id, insertAt);
  }

  // ---- build ----

  @override
  Widget build(BuildContext context) {
    final harbor = context.harbor;
    final store = context.watch<AppStore>();
    final list = store.byId(widget.listId);
    if (list == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    _maybeCelebrate(list);
    final rows = _buildRows(list);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              list: list,
              onEdit: () => showNewListSheet(context, edit: list),
              onNewCategory: () =>
                  showCategorySheet(context, listId: widget.listId),
              onAddPreset: _addPreset,
              onUncheckAll: () => _uncheckAll(list),
              onCollapseAll: () => setState(() =>
                  _collapsed.addAll(list.categories.map((category) => category.id))),
              onExpandAll: () => setState(_collapsed.clear),
              onSavePreset: () => _saveAsPreset(list),
              onDelete: () => _deleteList(list),
            ),
            ProgressBar(
              progress: list.progress,
              ready: list.isReady,
              height: 3,
              rounded: false,
            ),
            if (list.isReady) const _AllPackedCard(),
            Expanded(
              child: (list.items.isEmpty &&
                      list.categories.isEmpty &&
                      !_adding)
                  ? _EmptyList(
                      onAddItem: () => _openAdd(null),
                      onNewCategory: () =>
                          showCategorySheet(context, listId: widget.listId),
                    )
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(0, 6, 0, 40),
                      buildDefaultDragHandles: false,
                      itemCount: rows.length,
                      onReorderStart: (_) => Haptics.tap(),
                      proxyDecorator: (child, index, animation) =>
                          Material(
                        type: MaterialType.transparency,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: harbor.card,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.18),
                                blurRadius: 14,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: child,
                        ),
                      ),
                      onReorderItem: (oldIndex, newIndex) =>
                          _onReorder(rows, oldIndex, newIndex),
                      itemBuilder: (context, index) =>
                          _buildRow(context, list, rows, index),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(
      BuildContext context, PackingList list, List<_Row> rows, int index) {
    final harbor = context.harbor;
    final row = rows[index];

    switch (row) {
      case _CategoryHeaderRow(:final category):
        final collapsed = _collapsed.contains(category.id);
        final total = category.items.length;
        final packed = category.items.where((item) => item.checked).length;
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
            onTap: () => setState(() {
              collapsed ? _collapsed.remove(category.id) : _collapsed.add(category.id);
            }),
            onLongPress: () => _categoryMenu(list, category),
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
                          child: Text(
                            category.name.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.7,
                              color: harbor.mut,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '· $packed of $total',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: harbor.mut),
                        ),
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
        final checked = item.checked || _pendingCheck.contains(item.id);
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
              direction: DismissDirection.horizontal,
              background: _renameBg(harbor),
              secondaryBackground: _swipeBg(harbor, Alignment.centerRight),
              confirmDismiss: (direction) async {
                if (direction == DismissDirection.startToEnd) {
                  _renameItem(category, item);
                  return false;
                }
                return true;
              },
              onDismissed: (_) => _deleteItem(category, item),
              child: InkWell(
                onTap: () => _toggle(category, item),
                enableFeedback: false,
                child: Container(
                  decoration: firstInCard
                      ? null
                      : BoxDecoration(
                          border: Border(top: BorderSide(color: harbor.line))),
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
                  child: Row(
                    children: [
                      _Checkbox(checked: checked),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 15, color: harbor.ink),
                        ),
                      ),
                    ],
                  ),
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
              decoration: roundTop
                  ? null
                  : BoxDecoration(
                      border: Border(top: BorderSide(color: harbor.line))),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              child: active
                  ? Row(
                      children: [
                        Opacity(
                            opacity: 0.35,
                            child: _Checkbox(checked: false)),
                        const SizedBox(width: 11),
                        Expanded(
                          child: TextField(
                            controller: _addController,
                            focusNode: _addFocus,
                            autofocus: true,
                            textCapitalization: TextCapitalization.sentences,
                            textInputAction: TextInputAction.done,
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
                          child: Icon(Icons.add_rounded,
                              size: 17, color: harbor.mut),
                        ),
                        const SizedBox(width: 11),
                        Text('Add item',
                            style: TextStyle(fontSize: 14, color: harbor.mut)),
                      ],
                    ),
            ),
          ),
        );

      case _PackedHeaderRow(:final count):
        return Container(
          key: ValueKey(row.key),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 2),
          child: InkWell(
            onTap: () => setState(() => _packedCollapsed = !_packedCollapsed),
            child: Row(
              children: [
                Text(
                  'PACKED · $count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                    color: harbor.mut,
                  ),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: _packedCollapsed ? -0.25 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(Icons.keyboard_arrow_down_rounded,
                      size: 17, color: harbor.mut),
                ),
              ],
            ),
          ),
        );

      case _PackedLabelRow(:final category):
        return Padding(
          key: ValueKey(row.key),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 3),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              category.name.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: harbor.mut.withValues(alpha: 0.75),
              ),
            ),
          ),
        );

      case _PackedItemRow(:final category, :final item, :final isFirst, :final isLast):
        return Container(
          key: ValueKey(row.key),
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: harbor.card,
            borderRadius: BorderRadius.vertical(
              top: isFirst ? const Radius.circular(12) : Radius.zero,
              bottom: isLast ? const Radius.circular(12) : Radius.zero,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Dismissible(
            key: ValueKey('dis-${row.key}'),
            direction: DismissDirection.horizontal,
            background: _renameBg(harbor),
            secondaryBackground: _swipeBg(harbor, Alignment.centerRight),
            confirmDismiss: (direction) async {
              if (direction == DismissDirection.startToEnd) {
                _renameItem(category, item);
                return false;
              }
              return true;
            },
            onDismissed: (_) => _deleteItem(category, item),
            child: InkWell(
              onTap: () => _toggle(category, item),
              enableFeedback: false,
              child: Container(
                decoration: isFirst
                    ? null
                    : BoxDecoration(
                        border: Border(top: BorderSide(color: harbor.line))),
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
                child: Row(
                  children: [
                    _Checkbox(checked: true),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          color: harbor.mut,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: harbor.mut,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
    }
  }

  Widget _renameBg(Harbor harbor) {
    return Container(
      color: harbor.accent,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: const Text(
        'Rename',
        style: TextStyle(
            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
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
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text('Save', style: TextStyle(color: harbor.accent)),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty && name != item.name) {
      _store.renameItem(widget.listId, category?.id, item.id, name);
    }
  }

  Widget _swipeBg(Harbor harbor, Alignment alignment) {
    return Container(
      color: harbor.danger,
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: const Text(
        'Delete',
        style: TextStyle(
            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ---- header (condensed option C) ----

class _Header extends StatelessWidget {
  const _Header({
    required this.list,
    required this.onEdit,
    required this.onNewCategory,
    required this.onAddPreset,
    required this.onUncheckAll,
    required this.onCollapseAll,
    required this.onExpandAll,
    required this.onSavePreset,
    required this.onDelete,
  });

  final PackingList list;
  final VoidCallback onEdit;
  final VoidCallback onNewCategory;
  final VoidCallback onAddPreset;
  final VoidCallback onUncheckAll;
  final VoidCallback onCollapseAll;
  final VoidCallback onExpandAll;
  final VoidCallback onSavePreset;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final harbor = context.harbor;
    final menuStyle = TextStyle(fontSize: 14, color: harbor.ink);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 6, 6),
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
              onTap: onEdit,
              child: Row(
                children: [
                  Text(list.icon, style: const TextStyle(fontSize: 17)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      list.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: harbor.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: harbor.tile,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${list.packedItems}/${list.totalItems}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: harbor.mut,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.add_rounded, size: 24, color: harbor.accent),
            color: harbor.card,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) => switch (value) {
              'category' => onNewCategory(),
              _ => onAddPreset(),
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                  value: 'category',
                  child: Text('New Category', style: menuStyle)),
              PopupMenuItem(
                  value: 'preset', child: Text('Add Preset', style: menuStyle)),
            ],
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_horiz_rounded, size: 22, color: harbor.accent),
            color: harbor.card,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) => switch (value) {
              'uncheck' => onUncheckAll(),
              'collapse' => onCollapseAll(),
              'expand' => onExpandAll(),
              'preset' => onSavePreset(),
              'delete' => onDelete(),
              _ => (),
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                  value: 'uncheck',
                  enabled: list.packedItems > 0,
                  child: Text('Uncheck All', style: menuStyle)),
              PopupMenuItem(
                  value: 'collapse',
                  child: Text('Collapse All', style: menuStyle)),
              PopupMenuItem(
                  value: 'expand',
                  child: Text('Expand All', style: menuStyle)),
              PopupMenuItem(
                  value: 'preset',
                  child: Text('Save as Preset', style: menuStyle)),
              PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete List',
                      style: TextStyle(fontSize: 14, color: harbor.danger))),
            ],
          ),
        ],
      ),
    );
  }
}

class _Checkbox extends StatelessWidget {
  const _Checkbox({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    final harbor = context.harbor;
    final border = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF48546A)
        : const Color(0xFFB6BEC9);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: checked ? harbor.good : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: checked ? harbor.good : border, width: 2),
      ),
      child: checked
          ? const Icon(Icons.check_rounded, size: 17, color: Colors.white)
          : null,
    );
  }
}

/// A persistent "you're done" banner shown at the top of the list once every
/// item is packed. The confetti burst is a one-time celebration; this stays.
class _AllPackedCard extends StatelessWidget {
  const _AllPackedCard();

  @override
  Widget build(BuildContext context) {
    final harbor = context.harbor;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: harbor.good.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: harbor.good.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: harbor.good, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'All packed',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: harbor.good),
                ),
                const SizedBox(height: 2),
                Text(
                  "Everything's checked off — you're ready to go.",
                  style: TextStyle(fontSize: 12.5, color: harbor.good),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyList extends StatelessWidget {
  const _EmptyList({required this.onAddItem, required this.onNewCategory});

  final VoidCallback onAddItem;
  final VoidCallback onNewCategory;

  @override
  Widget build(BuildContext context) {
    final harbor = context.harbor;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 44),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📝', style: TextStyle(fontSize: 42)),
            const SizedBox(height: 14),
            Text(
              'Start your list',
              style: TextStyle(
                  fontSize: 15.5, fontWeight: FontWeight.w700, color: harbor.ink),
            ),
            const SizedBox(height: 6),
            Text(
              'Add items one by one — no setup needed.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: harbor.mut, height: 1.5),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: onAddItem,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add item'),
                  style: FilledButton.styleFrom(
                    backgroundColor: harbor.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11)),
                    textStyle: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: onNewCategory,
                  icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                  label: const Text('New Category'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: harbor.accent,
                    side: BorderSide(color: harbor.line),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11)),
                    textStyle: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
