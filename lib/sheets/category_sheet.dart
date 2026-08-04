import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import 'icon_picker.dart';

/// Bottom sheet for creating a category, or renaming one / changing its icon
/// when [edit] is passed. Icons are optional for categories — no default.
///
/// Works against a list ([listId]) or, when [saved] is true, against the
/// library of reusable categories. Both are the same type, so the only thing
/// that changes is which store operations run.
///
/// Returns the created or edited category, or null if the sheet was dismissed.
Future<PackCategory?> showCategorySheet(
  BuildContext context, {
  String? listId,
  bool saved = false,
  PackCategory? edit,
}) {
  return showModalBottomSheet<PackCategory>(
    context: context,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: _CategorySheet(listId: listId, saved: saved, edit: edit),
    ),
  );
}

class _CategorySheet extends StatefulWidget {
  const _CategorySheet({this.listId, this.saved = false, this.edit});

  final String? listId;
  final bool saved;
  final PackCategory? edit;

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.edit?.name ?? '');
  late String? _icon = widget.edit?.icon;

  bool get _canSave => _name.text.trim().isNotEmpty;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickIcon() async {
    final picked = await showIconPicker(context, current: _icon ?? '');
    if (picked != null) setState(() => _icon = picked);
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final store = context.read<AppStore>();
    final PackCategory? result;
    if (widget.saved) {
      if (widget.edit == null) {
        result = store.addSavedCategory(name, _icon);
      } else {
        store.updateSavedCategory(widget.edit!.id,
            name: name, icon: _icon, clearIcon: _icon == null);
        result = widget.edit;
      }
    } else {
      if (widget.edit == null) {
        result = store.addCategory(widget.listId!, name, _icon);
      } else {
        store.updateCategory(widget.listId!, widget.edit!.id,
            name: name, icon: _icon, clearIcon: _icon == null);
        result = widget.edit;
      }
    }
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final harbor = context.harbor;
    final editing = widget.edit != null;

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 5,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: harbor.line,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Row(
              children: [
                SizedBox(
                  width: 72,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Cancel',
                        style: TextStyle(fontSize: 14, color: harbor.accent)),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      editing ? 'Edit Category' : 'New Category',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: harbor.ink,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 72),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _pickIcon,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: harbor.tile,
                    borderRadius: BorderRadius.circular(14),
                    border: _icon == null
                        ? Border.all(color: harbor.line, width: 1.5)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: _icon == null
                      ? Icon(Icons.add_reaction_outlined, size: 20, color: harbor.mut)
                      : Text(_icon!, style: const TextStyle(fontSize: 26)),
                ),
              ),
              if (_icon != null)
                TextButton(
                  onPressed: () => setState(() => _icon = null),
                  child: Text('Remove icon',
                      style: TextStyle(fontSize: 12.5, color: harbor.mut)),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(
              'Icon is optional for categories',
              style: TextStyle(fontSize: 11.5, color: harbor.mut),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _save(),
              style: TextStyle(fontSize: 15, color: harbor.ink),
              decoration: InputDecoration(
                hintText: 'Category name',
                hintStyle: TextStyle(color: harbor.mut),
                filled: true,
                fillColor: harbor.bg,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _canSave ? _save : null,
                style: FilledButton.styleFrom(
                  backgroundColor: harbor.accent,
                  disabledBackgroundColor: harbor.accent.withValues(alpha: 0.35),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white70,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle:
                      const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                child: Text(editing ? 'Save' : 'Create Category'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
