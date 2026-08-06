import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';

import '../icons.dart';
import '../motion.dart';
import '../theme.dart';

/// Picks an icon for a list or category.
///
/// Two tiers: the curated packing icons up top for the common case, and the
/// full emoji set below for everything else (#57). The curated row is not
/// redundant — a full picker opens on a category no packing app wants first,
/// and 🧳 ✈️ 🏖️ should never be more than one tap away.
Future<String?> showIconPicker(BuildContext context, {required String current}) {
  return showModalBottomSheet<String>(
    context: context,
    // Tall enough that it needs to be scroll-controlled, unlike the old
    // curated-only grid.
    isScrollControlled: true,
    // Pick-one-and-dismiss, so it moves at menu pace rather than form pace.
    sheetAnimationStyle: Motion.menu,
    builder: (context) => _IconPicker(current: current),
  );
}

class _IconPicker extends StatelessWidget {
  const _IconPicker({required this.current});

  final String current;

  @override
  Widget build(BuildContext context) {
    final harbor = context.harbor;
    return SizedBox(
      // Leaves the list behind partly visible, so the sheet still reads as a
      // sheet rather than a page.
      height: MediaQuery.sizeOf(context).height * 0.72,
      child: SafeArea(
        top: false,
        child: Column(
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
            Text(
              'Choose an icon',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: harbor.ink,
              ),
            ),
            _label(harbor, 'SUGGESTED'),
            // One scrolling row, not a grid: as a block the 36 curated icons
            // took the whole sheet and left the full picker with nothing but
            // its tab bar. The packing-relevant ones lead, so the common pick
            // needs no scrolling at all.
            SizedBox(
              height: 46,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: curatedIcons.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final icon = curatedIcons[index];
                  return InkWell(
                    onTap: () => Navigator.of(context).pop(icon),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 46,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: icon == current ? harbor.accentSoft : null,
                        border: icon == current
                            ? Border.all(color: harbor.accent, width: 1.5)
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(icon, style: const TextStyle(fontSize: 24)),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            Container(height: 1, color: harbor.line),
            _label(harbor, 'ALL EMOJI'),
            Expanded(
              child: EmojiPicker(
                onEmojiSelected: (_, emoji) =>
                    Navigator.of(context).pop(emoji.emoji),
                config: _config(context, harbor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(Harbor harbor, String text) => Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 16, 8),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
              color: harbor.mut,
            ),
          ),
        ),
      );

  /// Harbor colours throughout — the package's defaults are a light grey-blue
  /// that looks broken in dark mode.
  Config _config(BuildContext context, Harbor harbor) {
    final surface = Theme.of(context).bottomSheetTheme.backgroundColor ??
        harbor.card;
    return Config(
      emojiViewConfig: EmojiViewConfig(
        columns: 8,
        emojiSizeMax: 26,
        backgroundColor: surface,
        gridPadding: const EdgeInsets.symmetric(horizontal: 12),
        verticalSpacing: 2,
        horizontalSpacing: 2,
      ),
      categoryViewConfig: CategoryViewConfig(
        // The Suggested grid above already is the shortlist, so a second
        // recents strip would just be a worse copy of it.
        recentTabBehavior: RecentTabBehavior.NONE,
        initCategory: Category.TRAVEL,
        backgroundColor: surface,
        indicatorColor: harbor.accent,
        iconColor: harbor.mut,
        iconColorSelected: harbor.accent,
        dividerColor: harbor.line,
      ),
      bottomActionBarConfig: BottomActionBarConfig(
        // The bar is only here to host Search. Backspace belongs to the
        // package's keyboard use case — there's no text field to erase into.
        showBackspaceButton: false,
        backgroundColor: surface,
        buttonColor: harbor.tile,
        buttonIconColor: harbor.mut,
      ),
      searchViewConfig: SearchViewConfig(
        backgroundColor: surface,
        buttonIconColor: harbor.mut,
        hintText: 'Search emoji',
        inputTextStyle: TextStyle(fontSize: 15, color: harbor.ink),
        hintTextStyle: TextStyle(fontSize: 15, color: harbor.mut),
        // The stock search view is a single horizontal strip of results with
        // the field *below* it — sized for sitting above a keyboard, which
        // leaves most of a sheet empty. Ours fills the space with a grid.
        customSearchView: (config, state, showEmojiView) =>
            _HarborSearchView(config, state, showEmojiView, harbor: harbor),
      ),
    );
  }
}

/// Search results as a grid that fills the sheet, with the field at the top.
///
/// Extends the package's [SearchView], so `results`, `onTextInputChanged` and
/// `buildEmoji` all come from it — only the layout is ours.
class _HarborSearchView extends SearchView {
  const _HarborSearchView(super.config, super.state, super.showEmojiView,
      {required this.harbor});

  final Harbor harbor;

  @override
  SearchViewState<_HarborSearchView> createState() => _HarborSearchViewState();
}

class _HarborSearchViewState extends SearchViewState<_HarborSearchView> {
  @override
  Widget build(BuildContext context) {
    final harbor = widget.harbor;
    final searchConfig = widget.config.searchViewConfig;
    final viewConfig = widget.config.emojiViewConfig;

    return Container(
      color: searchConfig.backgroundColor,
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: widget.showEmojiView,
                color: searchConfig.buttonIconColor,
                icon: const Icon(Icons.arrow_back, size: 20),
              ),
              Expanded(
                child: TextField(
                  onChanged: onTextInputChanged,
                  focusNode: focusNode,
                  style: searchConfig.inputTextStyle,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    hintText: searchConfig.hintText,
                    hintStyle: searchConfig.hintTextStyle,
                  ),
                ),
              ),
            ],
          ),
          Container(height: 1, color: harbor.line),
          Expanded(
            child: results.isEmpty
                ? Center(
                    child: Text('No emoji match that search',
                        style: TextStyle(fontSize: 13, color: harbor.mut)),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth -
                          viewConfig.gridPadding.horizontal;
                      return GridView.builder(
                        padding: viewConfig.gridPadding
                            .add(const EdgeInsets.symmetric(vertical: 8)),
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: viewConfig.columns,
                          mainAxisSpacing: viewConfig.verticalSpacing,
                          crossAxisSpacing: viewConfig.horizontalSpacing,
                        ),
                        itemCount: results.length,
                        itemBuilder: (context, index) => buildEmoji(
                          results[index],
                          viewConfig.getEmojiSize(width),
                          viewConfig.getEmojiBoxSize(width),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
