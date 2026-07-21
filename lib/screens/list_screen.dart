import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../haptics.dart';
import '../models.dart';
import '../sheets/category_sheet.dart';
import '../sheets/new_list_sheet.dart';
import '../sheets/preset_picker.dart';
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

class _CatHeaderRow extends _Row {
  _CatHeaderRow(this.cat) : super('h-${cat.id}');
  final PackCategory cat;
}

class _ItemRow extends _Row {
  _ItemRow(this.cat, this.item, {required this.isLastInCard})
      : super('i-${item.id}');
  final PackCategory cat;
  final Item item;
  final bool isLastInCard;
}

class _AddRow extends _Row {
  _AddRow(this.cat) : super('a-${cat.id}');
  final PackCategory cat;
}

class _PackedHeaderRow extends _Row {
  _PackedHeaderRow(this.count) : super('packed-header');
  final int count;
}

class _PackedLabelRow extends _Row {
  _PackedLabelRow(this.cat) : super('pl-${cat.id}');
  final PackCategory cat;
}

class _PackedItemRow extends _Row {
  _PackedItemRow(this.cat, this.item,
      {required this.isFirst, required this.isLast})
      : super('pi-${item.id}');
  final PackCategory cat;
  final Item item;
  final bool isFirst;
  final bool isLast;
}

class _ListScreenState extends State<ListScreen> {
  final Set<String> _collapsed = {};
  bool _packedCollapsed = false;
  String? _addingCatId;
  final TextEditingController _addCtrl = TextEditingController();
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
    _addCtrl.dispose();
    _addFocus.dispose();
    super.dispose();
  }

  AppStore get _store => context.read<AppStore>();

  // ---- check-off ----

  void _toggle(PackCategory cat, Item item) {
    if (item.checked) {
      _store.setItemChecked(widget.listId, cat.id, item.id, false);
      return;
    }
    if (_pendingCheck.contains(item.id)) return;
    Haptics.tap();
    Sfx.pop();
    setState(() => _pendingCheck.add(item.id));
    // Let the checkmark land for a beat before the row glides to Packed.
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _pendingCheck.remove(item.id));
      _store.setItemChecked(widget.listId, cat.id, item.id, true);
    });
  }

  void _maybeCelebrate(PackingList list) {
    final ready = list.isReady;
    if (ready && !_wasReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Haptics.celebrate();
        Sfx.popBig();
        showCelebration(context);
      });
    }
    _wasReady = ready;
  }

  // ---- inline add ----

  void _commitAdd({required bool keepOpen}) {
    final catId = _addingCatId;
    if (catId == null) return;
    final text = _addCtrl.text.trim();
    if (text.isNotEmpty) {
      _store.addItem(widget.listId, catId, text);
      Haptics.tap();
    }
    _addCtrl.clear();
    if (keepOpen && text.isNotEmpty) {
      _addFocus.requestFocus();
    } else {
      setState(() => _addingCatId = null);
    }
  }

  // ---- dialogs & menus ----

  Future<bool> _confirm(String title, String message, String confirmLabel,
      {bool danger = true}) async {
    final h = context.harbor;
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
                style: TextStyle(color: danger ? h.danger : h.accent)),
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
    final n = list.packedItems;
    if (n == 0) return;
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

  void _categoryMenu(PackingList list, PackCategory cat) {
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
                color: h.line,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            ListTile(
              leading: Icon(Icons.edit_outlined, size: 20, color: h.ink),
              title: Text('Rename & icon',
                  style: TextStyle(fontSize: 14.5, color: h.ink)),
              onTap: () {
                Navigator.of(sheetContext).pop();
                showCategorySheet(context, listId: widget.listId, edit: cat);
              },
            ),
            ListTile(
              leading: Icon(Icons.bookmark_add_outlined, size: 20, color: h.ink),
              title: Text('Save as preset',
                  style: TextStyle(fontSize: 14.5, color: h.ink)),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _store.saveCategoryAsPreset(widget.listId, cat.id);
                ScaffoldMessenger.of(context)
                  ..clearSnackBars()
                  ..showSnackBar(SnackBar(
                      content: Text('Saved "${cat.name}" as a preset')));
              },
            ),
            ListTile(
              leading:
                  Icon(Icons.delete_outline_rounded, size: 20, color: h.danger),
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
                  _store.deleteCategory(widget.listId, cat.id);
                }
              },
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  void _deleteItem(PackCategory cat, Item item) {
    final modelIndex = cat.items.indexWhere((i) => i.id == item.id);
    _store.deleteItem(widget.listId, cat.id, item.id);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: const Text('Item deleted'),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () =>
                _store.insertItem(widget.listId, cat.id, modelIndex, item),
          ),
        ),
      );
  }

  // ---- reorder ----

  List<_Row> _buildRows(PackingList list) {
    final rows = <_Row>[];
    for (final cat in list.categories) {
      rows.add(_CatHeaderRow(cat));
      if (!_collapsed.contains(cat.id)) {
        final unchecked = cat.items.where((i) => !i.checked).toList();
        for (var k = 0; k < unchecked.length; k++) {
          rows.add(_ItemRow(cat, unchecked[k], isLastInCard: false));
        }
        rows.add(_AddRow(cat));
      }
    }
    final packedCount = list.packedItems;
    if (packedCount > 0 && !list.hidePacked) {
      rows.add(_PackedHeaderRow(packedCount));
      if (!_packedCollapsed) {
        for (final cat in list.categories) {
          final checked = cat.items.where((i) => i.checked).toList();
          if (checked.isEmpty) continue;
          rows.add(_PackedLabelRow(cat));
          for (var k = 0; k < checked.length; k++) {
            rows.add(_PackedItemRow(cat, checked[k],
                isFirst: k == 0, isLast: k == checked.length - 1));
          }
        }
      }
    }
    return rows;
  }

  int _modelInsertIndex(PackCategory cat, String draggedId, int uncheckedPos) {
    final items = cat.items.where((i) => i.id != draggedId).toList();
    var seen = 0;
    for (var k = 0; k < items.length; k++) {
      if (!items[k].checked) {
        if (seen == uncheckedPos) return k;
        seen++;
      }
    }
    return items.length;
  }

  void _onReorder(List<_Row> rows, int oldIndex, int newIndex) {
    final dragged = rows[oldIndex];
    if (dragged is! _ItemRow) return;

    final remaining = [...rows]..removeAt(oldIndex);
    PackCategory? targetCat;
    var uncheckedPos = 0;
    var inPacked = false;
    PackCategory? lastCat;

    for (var k = 0; k < newIndex && k < remaining.length; k++) {
      final row = remaining[k];
      if (row is _CatHeaderRow) {
        lastCat = row.cat;
        targetCat = row.cat;
        uncheckedPos = 0;
      } else if (row is _ItemRow) {
        if (row.cat.id == targetCat?.id) uncheckedPos++;
      } else if (row is _AddRow) {
        // Dropping past the add row keeps the item at the end of that card.
      } else if (row is _PackedHeaderRow) {
        inPacked = true;
      }
    }

    if (inPacked || targetCat == null) {
      // Dropped above the first category or into the Packed section: clamp
      // to the end of the nearest real category.
      targetCat = inPacked ? (lastCat ?? dragged.cat) : list0(rows);
      if (targetCat == null) return;
      uncheckedPos =
          inPacked ? targetCat.items.where((i) => !i.checked).length : 0;
    }

    final insertAt =
        _modelInsertIndex(targetCat, dragged.item.id, uncheckedPos);
    _store.moveItem(
        widget.listId, dragged.cat.id, dragged.item.id, targetCat.id, insertAt);
  }

  PackCategory? list0(List<_Row> rows) {
    for (final row in rows) {
      if (row is _CatHeaderRow) return row.cat;
    }
    return null;
  }

  // ---- build ----

  @override
  Widget build(BuildContext context) {
    final h = context.harbor;
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
              onTogglePacked: () =>
                  _store.setHidePacked(widget.listId, !list.hidePacked),
              onCollapseAll: () => setState(() =>
                  _collapsed.addAll(list.categories.map((c) => c.id))),
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
            Expanded(
              child: list.categories.isEmpty
                  ? _EmptyList(onAdd: () =>
                      showCategorySheet(context, listId: widget.listId))
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
                            color: h.card,
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
    final h = context.harbor;
    final row = rows[index];

    switch (row) {
      case _CatHeaderRow(:final cat):
        final collapsed = _collapsed.contains(cat.id);
        final total = cat.items.length;
        final packed = cat.items.where((i) => i.checked).length;
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
            onTap: () => setState(() {
              collapsed ? _collapsed.remove(cat.id) : _collapsed.add(cat.id);
            }),
            onLongPress: () => _categoryMenu(list, cat),
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
                          child: Text(
                            cat.name.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.7,
                              color: h.mut,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '· $packed of $total',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: h.mut),
                        ),
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

      case _ItemRow(:final cat, :final item):
        final checked = item.checked || _pendingCheck.contains(item.id);
        return Container(
          key: ValueKey(row.key),
          margin: const EdgeInsets.symmetric(horizontal: 12),
          color: h.card,
          child: ReorderableDelayedDragStartListener(
            index: index,
            child: Dismissible(
              key: ValueKey('dis-${row.key}'),
              direction: DismissDirection.horizontal,
              background: _renameBg(h),
              secondaryBackground: _swipeBg(h, Alignment.centerRight),
              confirmDismiss: (direction) async {
                if (direction == DismissDirection.startToEnd) {
                  _renameItem(cat, item);
                  return false;
                }
                return true;
              },
              onDismissed: (_) => _deleteItem(cat, item),
              child: InkWell(
                onTap: () => _toggle(cat, item),
                enableFeedback: false,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: h.line)),
                  ),
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
                          style: TextStyle(fontSize: 15, color: h.ink),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

      case _AddRow(:final cat):
        final active = _addingCatId == cat.id;
        return Container(
          key: ValueKey(row.key),
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: active ? h.accentSoft : h.card,
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(12)),
          ),
          child: InkWell(
            onTap: active
                ? null
                : () {
                    _commitAdd(keepOpen: false);
                    setState(() => _addingCatId = cat.id);
                    _addCtrl.clear();
                  },
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(12)),
            child: Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: h.line)),
              ),
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
                            controller: _addCtrl,
                            focusNode: _addFocus,
                            autofocus: true,
                            textCapitalization: TextCapitalization.sentences,
                            textInputAction: TextInputAction.done,
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
                          child: Icon(Icons.add_rounded,
                              size: 17, color: h.mut),
                        ),
                        const SizedBox(width: 11),
                        Text('Add item',
                            style: TextStyle(fontSize: 14, color: h.mut)),
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
                    color: h.mut,
                  ),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: _packedCollapsed ? -0.25 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(Icons.keyboard_arrow_down_rounded,
                      size: 17, color: h.mut),
                ),
              ],
            ),
          ),
        );

      case _PackedLabelRow(:final cat):
        return Padding(
          key: ValueKey(row.key),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 3),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              cat.name.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: h.mut.withValues(alpha: 0.75),
              ),
            ),
          ),
        );

      case _PackedItemRow(:final cat, :final item, :final isFirst, :final isLast):
        return Container(
          key: ValueKey(row.key),
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: h.card,
            borderRadius: BorderRadius.vertical(
              top: isFirst ? const Radius.circular(12) : Radius.zero,
              bottom: isLast ? const Radius.circular(12) : Radius.zero,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Dismissible(
            key: ValueKey('dis-${row.key}'),
            direction: DismissDirection.horizontal,
            background: _renameBg(h),
            secondaryBackground: _swipeBg(h, Alignment.centerRight),
            confirmDismiss: (direction) async {
              if (direction == DismissDirection.startToEnd) {
                _renameItem(cat, item);
                return false;
              }
              return true;
            },
            onDismissed: (_) => _deleteItem(cat, item),
            child: InkWell(
              onTap: () => _toggle(cat, item),
              enableFeedback: false,
              child: Container(
                decoration: isFirst
                    ? null
                    : BoxDecoration(
                        border: Border(top: BorderSide(color: h.line))),
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
                          color: h.mut,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: h.mut,
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

  Widget _renameBg(Harbor h) {
    return Container(
      color: h.accent,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: const Text(
        'Rename',
        style: TextStyle(
            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }

  Future<void> _renameItem(PackCategory cat, Item item) async {
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
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(ctrl.text.trim()),
            child: Text('Save', style: TextStyle(color: h.accent)),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty && name != item.name) {
      _store.renameItem(widget.listId, cat.id, item.id, name);
    }
  }

  Widget _swipeBg(Harbor h, Alignment alignment) {
    return Container(
      color: h.danger,
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
    required this.onTogglePacked,
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
  final VoidCallback onTogglePacked;
  final VoidCallback onCollapseAll;
  final VoidCallback onExpandAll;
  final VoidCallback onSavePreset;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final h = context.harbor;
    final menuStyle = TextStyle(fontSize: 14, color: h.ink);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 6, 6),
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
                        color: h.ink,
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
              color: h.tile,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${list.packedItems}/${list.totalItems}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: h.mut,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.add_rounded, size: 24, color: h.accent),
            color: h.card,
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
            icon: Icon(Icons.more_horiz_rounded, size: 22, color: h.accent),
            color: h.card,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) => switch (value) {
              'uncheck' => onUncheckAll(),
              'collapse' => onCollapseAll(),
              'expand' => onExpandAll(),
              'packed' => onTogglePacked(),
              'edit' => onEdit(),
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
                  value: 'packed',
                  child: Text(
                      list.hidePacked ? 'Show Packed Items' : 'Hide Packed Items',
                      style: menuStyle)),
              PopupMenuItem(
                  value: 'edit',
                  child: Text('Edit Name & Icon', style: menuStyle)),
              PopupMenuItem(
                  value: 'preset',
                  child: Text('Save as Preset', style: menuStyle)),
              PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete List',
                      style: TextStyle(fontSize: 14, color: h.danger))),
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
    final h = context.harbor;
    final border = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF48546A)
        : const Color(0xFFB6BEC9);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: checked ? h.good : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: checked ? h.good : border, width: 2),
      ),
      child: checked
          ? const Icon(Icons.check_rounded, size: 17, color: Colors.white)
          : null,
    );
  }
}

class _EmptyList extends StatelessWidget {
  const _EmptyList({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final h = context.harbor;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🧳', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 14),
            Text(
              'Nothing here yet',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: h.ink),
            ),
            const SizedBox(height: 6),
            Text(
              'Add a category, then fill it with items.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: h.mut, height: 1.5),
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: onAdd,
              child: Text('New Category',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: h.accent)),
            ),
          ],
        ),
      ),
    );
  }
}
