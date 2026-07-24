import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import 'icon_picker.dart';

/// Bottom sheet for creating a list, or editing one's name and icon when
/// [edit] is passed. Returns the created/edited list, or null on cancel.
Future<PackingList?> showNewListSheet(BuildContext context, {PackingList? edit}) {
  return showModalBottomSheet<PackingList>(
    context: context,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: _NewListSheet(edit: edit),
    ),
  );
}

class _NewListSheet extends StatefulWidget {
  const _NewListSheet({this.edit});

  final PackingList? edit;

  @override
  State<_NewListSheet> createState() => _NewListSheetState();
}

class _NewListSheetState extends State<_NewListSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.edit?.name ?? '');
  late String _icon = widget.edit?.icon ?? '🎒';

  final Set<String> _selectedPresets = {};

  bool get _canSave => _name.text.trim().isNotEmpty;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickIcon() async {
    final picked = await showIconPicker(context, current: _icon);
    if (picked != null) setState(() => _icon = picked);
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final store = context.read<AppStore>();
    final PackingList result;
    if (widget.edit == null) {
      result = _selectedPresets.isEmpty
          ? store.addList(name, _icon)
          : store.addListFromPresets(
              name, _icon, _selectedPresets.toList());
    } else {
      store.updateList(widget.edit!.id, name: name, icon: _icon);
      result = widget.edit!;
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
                      editing ? 'Edit List' : 'New List',
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
          GestureDetector(
            onTap: _pickIcon,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: harbor.tile,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Text(_icon, style: const TextStyle(fontSize: 30)),
                ),
                Positioned(
                  right: -6,
                  bottom: -6,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: harbor.card,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.edit, size: 12, color: harbor.mut),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _save(),
              style: TextStyle(fontSize: 15, color: harbor.ink),
              decoration: InputDecoration(
                hintText: 'List name',
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
          if (!editing) _presetChips(context),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
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
                child: Text(editing ? 'Save' : 'Create List'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _presetChips(BuildContext context) {
    final harbor = context.harbor;
    final presets = context.read<AppStore>().presets;
    if (presets.isEmpty) return const SizedBox(height: 4);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 16, 0),
          child: Text(
            'START FROM PRESETS · OPTIONAL',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
              color: harbor.mut,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in presets)
                _PresetChip(
                  preset: preset,
                  selected: _selectedPresets.contains(preset.id),
                  onTap: () => setState(() {
                    _selectedPresets.contains(preset.id)
                        ? _selectedPresets.remove(preset.id)
                        : _selectedPresets.add(preset.id);
                  }),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip(
      {required this.preset, required this.selected, required this.onTap});

  final Preset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final harbor = context.harbor;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? harbor.accentSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? harbor.accent : harbor.line,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected)
              Padding(
                padding: const EdgeInsets.only(right: 5),
                child: Icon(Icons.check_rounded, size: 15, color: harbor.accent),
              ),
            Text(
              preset.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? harbor.accent : harbor.mut,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
