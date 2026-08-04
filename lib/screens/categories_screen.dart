import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../haptics.dart';
import '../models.dart';
import '../sheets/category_picker.dart' show categoryGlyph;
import '../sheets/category_sheet.dart';
import '../store.dart';
import '../theme.dart';
import 'category_editor.dart';

/// Manage saved categories: a card list mirroring the home screen. Tap to
/// edit, swipe to delete, long-press to reorder, + to create.
class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  Future<void> _newCategory(BuildContext context) async {
    final created = await showCategorySheet(context, saved: true);
    if (created == null || !context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CategoryEditorScreen(categoryId: created.id)));
  }

  @override
  Widget build(BuildContext context) {
    final harbor = context.harbor;
    final store = context.watch<AppStore>();
    final categories = store.savedCategories;

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
                  Text('Categories',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: harbor.ink)),
                ],
              ),
            ),
            Expanded(
              child: categories.isEmpty
                  ? _empty(harbor)
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                      buildDefaultDragHandles: false,
                      itemCount: categories.length,
                      onReorderStart: (_) => Haptics.tap(),
                      onReorderItem: (oldIndex, newIndex) =>
                          store.reorderSavedCategories(oldIndex, newIndex),
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        return Padding(
                          key: ValueKey(category.id),
                          padding: const EdgeInsets.only(bottom: 10),
                          child: ReorderableDelayedDragStartListener(
                            index: index,
                            child: Dismissible(
                              key: ValueKey('dis-${category.id}'),
                              direction: DismissDirection.horizontal,
                              background: _delBg(harbor, Alignment.centerLeft),
                              secondaryBackground:
                                  _delBg(harbor, Alignment.centerRight),
                              confirmDismiss: (_) =>
                                  _confirmDelete(context, category),
                              onDismissed: (_) =>
                                  store.deleteSavedCategory(category.id),
                              child: _CategoryCard(category: category),
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
        onPressed: () => _newCategory(context),
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

  Future<bool> _confirmDelete(
      BuildContext context, PackCategory category) async {
    final harbor = context.harbor;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${category.name}"?'),
        content: const Text('This saved category will be deleted. Lists that '
            'already use it are not affected.'),
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
              Text('No saved categories yet',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: harbor.ink)),
              const SizedBox(height: 6),
              Text(
                  'Saved categories are reusable sets of items — like your '
                  'usual toiletries. Tap + to build one, or save any category '
                  'from its long-press menu in a list.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: harbor.mut, height: 1.5)),
            ],
          ),
        ),
      );
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category});

  final PackCategory category;

  @override
  Widget build(BuildContext context) {
    final harbor = context.harbor;
    final itemCount = category.items.length;
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
              builder: (_) => CategoryEditorScreen(categoryId: category.id))),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child:
                      Center(child: categoryGlyph(category, harbor, size: 26)),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(category.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w600,
                              color: harbor.ink)),
                      const SizedBox(height: 3),
                      Text('$itemCount item${itemCount == 1 ? '' : 's'}',
                          style: TextStyle(fontSize: 12.5, color: harbor.mut)),
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
