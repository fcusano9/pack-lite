import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../motion.dart';
import '../store.dart';
import '../theme.dart';

/// Sheet listing every saved category. Tapping one returns its id (used when
/// adding a saved category to an existing list). Returns null on cancel.
Future<String?> showCategoryPicker(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    // Pick-one-and-dismiss, so it moves at menu pace rather than form pace.
    sheetAnimationStyle: Motion.menu,
    builder: (context) {
      final harbor = context.harbor;
      final categories = context.read<AppStore>().savedCategories;
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
                color: harbor.line,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Center(
              child: Text('Add Saved Category',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: harbor.ink)),
            ),
            const SizedBox(height: 6),
            if (categories.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                child: Text(
                  'No saved categories yet. Build reusable ones in Settings → '
                  'Categories, or save any category from its long-press menu.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: harbor.mut, height: 1.5),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                  itemCount: categories.length,
                  itemBuilder: (context, index) =>
                      _CategoryRow(category: categories[index]),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.category});

  final PackCategory category;

  @override
  Widget build(BuildContext context) {
    final harbor = context.harbor;
    final itemCount = category.items.length;
    return ListTile(
      onTap: () => Navigator.of(context).pop(category.id),
      leading: categoryGlyph(category, harbor, size: 24),
      title: Text(category.name,
          style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600, color: harbor.ink)),
      subtitle: Text('$itemCount item${itemCount == 1 ? '' : 's'}',
          style: TextStyle(fontSize: 12.5, color: harbor.mut)),
      trailing: Icon(Icons.add_rounded, color: harbor.accent),
    );
  }
}

/// A saved category's emoji, or a neutral stand-in when it has none — icons
/// are optional on categories, but these rows always need something in the
/// leading slot to stay aligned.
Widget categoryGlyph(PackCategory category, Harbor harbor,
    {required double size}) {
  if (category.icon != null) {
    return Text(category.icon!, style: TextStyle(fontSize: size));
  }
  return Icon(Icons.folder_outlined, size: size, color: harbor.mut);
}
