import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import 'icon_picker.dart';

/// Bottom sheet for creating a category, or renaming one / changing its icon
/// when [edit] is passed. Icons are optional for categories — no default.
///
/// Works against a list ([listId]) or a preset ([presetId]). When
/// [presetMetaId] is set, the sheet edits the preset's own name + icon
/// instead of a category (icon required, defaults to 🎒).
Future<void> showCategorySheet(
  BuildContext context, {
  String? listId,
  String? presetId,
  String? presetMetaId,
  PackCategory? edit,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: _CategorySheet(
        listId: listId,
        presetId: presetId,
        presetMetaId: presetMetaId,
        edit: edit,
      ),
    ),
  );
}

class _CategorySheet extends StatefulWidget {
  const _CategorySheet(
      {this.listId, this.presetId, this.presetMetaId, this.edit});

  final String? listId;
  final String? presetId;
  final String? presetMetaId;
  final PackCategory? edit;

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  bool get _isMeta => widget.presetMetaId != null;

  late final TextEditingController _name =
      TextEditingController(text: widget.edit?.name ?? '');
  // Preset meta requires an icon (default backpack); categories don't.
  late String? _icon = widget.edit?.icon ?? (_isMeta ? '🎒' : null);

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
    if (_isMeta) {
      store.updatePreset(widget.presetMetaId!, name: name, icon: _icon);
    } else if (widget.presetId != null) {
      if (widget.edit == null) {
        store.presetAddCategory(widget.presetId!, name, _icon);
      } else {
        store.presetUpdateCategory(widget.presetId!, widget.edit!.id,
            name: name, icon: _icon, clearIcon: _icon == null);
      }
    } else {
      if (widget.edit == null) {
        store.addCategory(widget.listId!, name, _icon);
      } else {
        store.updateCategory(widget.listId!, widget.edit!.id,
            name: name, icon: _icon, clearIcon: _icon == null);
      }
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final h = context.harbor;
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
              color: h.line,
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
                        style: TextStyle(fontSize: 14, color: h.accent)),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      _isMeta
                          ? 'Edit Preset'
                          : editing
                              ? 'Edit Category'
                              : 'New Category',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: h.ink,
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
                    color: h.tile,
                    borderRadius: BorderRadius.circular(14),
                    border: _icon == null
                        ? Border.all(color: h.line, width: 1.5)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: _icon == null
                      ? Icon(Icons.add_reaction_outlined, size: 20, color: h.mut)
                      : Text(_icon!, style: const TextStyle(fontSize: 26)),
                ),
              ),
              if (_icon != null && !_isMeta)
                TextButton(
                  onPressed: () => setState(() => _icon = null),
                  child: Text('Remove icon',
                      style: TextStyle(fontSize: 12.5, color: h.mut)),
                ),
            ],
          ),
          if (!_isMeta)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(
                'Icon is optional for categories',
                style: TextStyle(fontSize: 11.5, color: h.mut),
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
              style: TextStyle(fontSize: 15, color: h.ink),
              decoration: InputDecoration(
                hintText: _isMeta ? 'Preset name' : 'Category name',
                hintStyle: TextStyle(color: h.mut),
                filled: true,
                fillColor: h.bg,
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
                  backgroundColor: h.accent,
                  disabledBackgroundColor: h.accent.withValues(alpha: 0.35),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white70,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle:
                      const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                child: Text(
                    editing || _isMeta ? 'Save' : 'Create Category'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
