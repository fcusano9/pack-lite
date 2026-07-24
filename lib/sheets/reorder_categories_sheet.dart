import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../haptics.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';

/// Bottom sheet to reorder a list's categories. Opened from a category's
/// long-press menu; drag the handle on a row to move it. Rebuilds live via the
/// store so the order updates as you drag.
Future<void> showReorderCategoriesSheet(BuildContext context,
    {required String listId}) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (context) => Consumer<AppStore>(
      builder: (context, store, _) {
        final harbor = context.harbor;
        final categories =
            store.byId(listId)?.categories ?? const <PackCategory>[];
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 5,
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                decoration: BoxDecoration(
                  color: harbor.line,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                child: Text(
                  'Reorder Categories',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: harbor.ink),
                ),
              ),
              Flexible(
                child: ReorderableListView.builder(
                  shrinkWrap: true,
                  buildDefaultDragHandles: false,
                  padding: const EdgeInsets.only(bottom: 10),
                  itemCount: categories.length,
                  onReorderStart: (_) => Haptics.tap(),
                  onReorderItem: (oldIndex, newIndex) =>
                      store.reorderCategories(listId, oldIndex, newIndex),
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    return ListTile(
                      key: ValueKey(category.id),
                      leading: ReorderableDragStartListener(
                        index: index,
                        child: Icon(Icons.drag_indicator_rounded,
                            color: harbor.mut, size: 24),
                      ),
                      title: Row(
                        children: [
                          if (category.icon != null) ...[
                            Text(category.icon!,
                                style: const TextStyle(fontSize: 15)),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Text(
                              category.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 15, color: harbor.ink),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
