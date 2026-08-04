import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../haptics.dart';
import '../models.dart';
import '../sheets/category_sheet.dart';
import '../store.dart';
import '../theme.dart';

/// Edits one saved category. A flat list of items — no checkboxes, no packed
/// section, no nesting, because a saved category *is* the container (#13).
class CategoryEditorScreen extends StatefulWidget {
  const CategoryEditorScreen({super.key, required this.categoryId});

  final String categoryId;

  @override
  State<CategoryEditorScreen> createState() => _CategoryEditorScreenState();
}

class _CategoryEditorScreenState extends State<CategoryEditorScreen> {
  bool _adding = false;
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
      _store.savedCategoryAddItem(widget.categoryId, text);
      Haptics.tap();
    }
    _addController.clear();
    if (keepOpen && text.isNotEmpty) {
      _addFocus.requestFocus();
    } else {
      setState(() => _adding = false);
    }
  }

  void _openAdd() {
    _commitAdd(keepOpen: false);
    setState(() => _adding = true);
    _addController.clear();
  }

  Future<void> _renameItem(Item item) async {
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
      _store.savedCategoryRenameItem(widget.categoryId, item.id, name);
    }
  }

  void _deleteItem(Item item) {
    final bucket =
        _store.savedCategoryById(widget.categoryId)?.items ?? const <Item>[];
    final index = bucket.indexWhere((bucketItem) => bucketItem.id == item.id);
    _store.savedCategoryDeleteItem(widget.categoryId, item.id);
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    final snackBar = messenger.showSnackBar(SnackBar(
      content: const Text('Item deleted'),
      duration: const Duration(seconds: 4),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () =>
            _store.savedCategoryInsertItem(widget.categoryId, index, item),
      ),
    ));
    // SnackBars with an action ignore `duration` in this Flutter version, so
    // close it ourselves (cancelled if it's dismissed sooner).
    final timer = Timer(const Duration(seconds: 4), snackBar.close);
    snackBar.closed.then((_) => timer.cancel());
  }

  void _onReorder(PackCategory category, int oldIndex, int newIndex) {
    if (oldIndex >= category.items.length) return;
    final item = category.items[oldIndex];
    // `onReorderItem` (unlike the deprecated `onReorder`) already accounts for
    // the removed item, so newIndex needs no shift — only a clamp, since the
    // trailing add row is a slot an item can be dropped past.
    final insertAt = newIndex.clamp(0, category.items.length - 1);
    _store.savedCategoryDeleteItem(widget.categoryId, item.id);
    _store.savedCategoryInsertItem(widget.categoryId, insertAt, item);
  }

  @override
  Widget build(BuildContext context) {
    final harbor = context.harbor;
    final store = context.watch<AppStore>();
    final category = store.savedCategoryById(widget.categoryId);
    if (category == null) return const Scaffold(body: SizedBox.shrink());

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
                      onTap: () => showCategorySheet(context,
                          saved: true, edit: category),
                      child: Row(
                        children: [
                          if (category.icon != null) ...[
                            Text(category.icon!,
                                style: const TextStyle(fontSize: 17)),
                            const SizedBox(width: 6),
                          ],
                          Flexible(
                            child: Text(category.name,
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
                    onPressed: _adding ? null : _openAdd,
                    icon:
                        Icon(Icons.add_rounded, size: 24, color: harbor.accent),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: harbor.line),
            Expanded(
              child: (category.items.isEmpty && !_adding)
                  ? _empty(harbor)
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(0, 6, 0, 40),
                      buildDefaultDragHandles: false,
                      // Items, plus the trailing add row.
                      itemCount: category.items.length + 1,
                      onReorderStart: (_) => Haptics.tap(),
                      onReorderItem: (oldIndex, newIndex) =>
                          _onReorder(category, oldIndex, newIndex),
                      itemBuilder: (context, index) =>
                          index == category.items.length
                              ? _addRow(harbor,
                                  roundTop: category.items.isEmpty)
                              : _itemRow(harbor, category.items[index], index),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemRow(Harbor harbor, Item item, int index) {
    final firstInCard = index == 0;
    return Container(
      key: ValueKey('item-${item.id}'),
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
          key: ValueKey('dis-item-${item.id}'),
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
              _renameItem(item);
              return false;
            }
            return true;
          },
          onDismissed: (_) => _deleteItem(item),
          child: Container(
            decoration: firstInCard
                ? null
                : BoxDecoration(
                    border: Border(top: BorderSide(color: harbor.line))),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
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
  }

  Widget _addRow(Harbor harbor, {required bool roundTop}) {
    final radius = roundTop
        ? BorderRadius.circular(12)
        : const BorderRadius.vertical(bottom: Radius.circular(12));
    return Container(
      key: const ValueKey('add-row'),
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _adding ? harbor.accentSoft : harbor.card,
        borderRadius: radius,
      ),
      child: InkWell(
        onTap: _adding ? null : _openAdd,
        borderRadius: radius,
        child: Container(
          // Always pass a decoration — see the matching comment in
          // list_screen.dart. A null -> non-null flip changes the tree depth
          // below Container, disposing the TextField's state and dropping the
          // keyboard as the first item is added (#22).
          decoration: BoxDecoration(
            border: Border(
              top: roundTop ? BorderSide.none : BorderSide(color: harbor.line),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          child: _adding
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
                        child: Icon(Icons.add_rounded,
                            size: 17, color: harbor.mut)),
                    const SizedBox(width: 11),
                    Text('Add item',
                        style: TextStyle(fontSize: 14, color: harbor.mut)),
                  ],
                ),
        ),
      ),
    );
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
            Text('Empty category',
                style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: harbor.ink)),
            const SizedBox(height: 6),
            Text(
                'Add the items you always pack — they come along every time '
                'you use this category.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: harbor.mut, height: 1.5)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _openAdd,
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
