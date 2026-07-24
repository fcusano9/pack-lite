import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../haptics.dart';
import '../models.dart';
import '../sheets/new_list_sheet.dart';
import 'settings_screen.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/list_card.dart';
import 'list_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _openList(BuildContext context, PackingList list) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ListScreen(listId: list.id),
      ),
    );
  }

  Future<void> _newList(BuildContext context) async {
    final created = await showNewListSheet(context);
    if (created != null && context.mounted) {
      _openList(context, created);
    }
  }

  @override
  Widget build(BuildContext context) {
    final harbor = context.harbor;
    final store = context.watch<AppStore>();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 4),
              child: Row(
                children: [
                  Text(
                    'Pack Lite',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: harbor.ink,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsScreen())),
                    icon: Icon(Icons.settings_outlined, size: 22, color: harbor.mut),
                  ),
                ],
              ),
            ),
            Expanded(
              child: store.lists.isEmpty
                  ? const _EmptyState()
                  : _CardList(store: store, onOpen: _openList),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _newList(context),
        backgroundColor: harbor.accent,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }
}

class _CardList extends StatelessWidget {
  const _CardList({required this.store, required this.onOpen});

  final AppStore store;
  final void Function(BuildContext, PackingList) onOpen;

  Future<bool> _confirmDelete(BuildContext context, PackingList list) async {
    final harbor = context.harbor;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${list.name}"?'),
        content: const Text('This list and all of its items will be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete', style: TextStyle(color: harbor.danger)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final harbor = context.harbor;
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      buildDefaultDragHandles: false,
      itemCount: store.lists.length,
      onReorderStart: (_) => Haptics.tap(),
      proxyDecorator: (child, index, animation) => AnimatedBuilder(
        animation: animation,
        builder: (context, _) => Transform.scale(
          scale: 1.0 + 0.02 * Curves.easeOut.transform(animation.value),
          child: Material(
            type: MaterialType.transparency,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: child,
            ),
          ),
        ),
      ),
      onReorderItem: (oldIndex, newIndex) {
        if (newIndex != oldIndex) store.reorderLists(oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        final list = store.lists[index];
        return Padding(
          key: ValueKey(list.id),
          padding: const EdgeInsets.only(bottom: 10),
          child: ReorderableDelayedDragStartListener(
            index: index,
            child: Dismissible(
              key: ValueKey('dismiss-${list.id}'),
              direction: DismissDirection.horizontal,
              background: _SwipeBackground(
                alignment: Alignment.centerLeft,
                color: harbor.accent,
                label: 'Duplicate',
                icon: Icons.copy_rounded,
              ),
              secondaryBackground: _SwipeBackground(
                alignment: Alignment.centerRight,
                color: harbor.danger,
                label: 'Delete',
                icon: Icons.delete_outline_rounded,
              ),
              confirmDismiss: (direction) async {
                if (direction == DismissDirection.startToEnd) {
                  // Swipe right duplicates; the card stays in place.
                  store.duplicateList(list.id);
                  Haptics.tap();
                  ScaffoldMessenger.of(context)
                    ..clearSnackBars()
                    ..showSnackBar(SnackBar(
                        content: Text('Duplicated "${list.name}"')));
                  return false;
                }
                // Swipe left deletes.
                return _confirmDelete(context, list);
              },
              onDismissed: (_) => store.deleteList(list.id),
              child: ListCard(list: list, onTap: () => onOpen(context, list)),
            ),
          ),
        );
      },
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.alignment,
    required this.color,
    required this.label,
    required this.icon,
  });

  final Alignment alignment;
  final Color color;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final leadingIcon = alignment == Alignment.centerLeft;
    final content = <Widget>[
      Icon(icon, color: Colors.white, size: 18),
      const SizedBox(width: 6),
      Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    ];
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: leadingIcon ? content : content.reversed.toList(),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final harbor = context.harbor;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🎒', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 14),
          Text(
            'No lists yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: harbor.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap + to create your first packing list',
            style: TextStyle(fontSize: 13.5, color: harbor.mut),
          ),
        ],
      ),
    );
  }
}
