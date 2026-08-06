import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
// Not re-exported by the package's barrel file, but a public path under `lib/`
// (not `src/`), and the one the picker itself uses to resolve its own set.
import 'package:emoji_picker_flutter/locales/default_emoji_set_locale.dart';
import 'package:flutter/material.dart';

import '../icons.dart';
import '../motion.dart';
import '../theme.dart';

/// Picks an icon for a list or category: the whole emoji set (#57), with the
/// packing shortlist from `icons.dart` as its **first tab and default view**.
///
/// The shortlist is injected as [Category.RECENT]. That slot is the right one
/// rather than a hack: with [RecentTabBehavior.NONE] the package never writes
/// to it, and `searchEmoji` deliberately skips it — so the shortlist can repeat
/// emoji that also live in Travel or Activities without doubling up every
/// search result.
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

/// The packing shortlist as a category the picker can render.
///
/// `name` is only ever used to build search keywords, and this category is
/// excluded from search, so the glyph doubles as its own name — which also
/// avoids matching each icon against the package's corpus, where several
/// (🚴 🏃 🏊 🛶) are stored in variant forms that a literal lookup misses.
List<CategoryEmoji> buildIconSet(Locale locale) => [
      CategoryEmoji(
        Category.RECENT,
        [for (final icon in curatedIcons) Emoji(icon, icon)],
      ),
      ...getDefaultEmojiLocale(locale),
    ];

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
            // The current icon travels with the title: the package's cells
            // have no selected state, so this is the only place the sheet can
            // still say what is already set.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: harbor.tile,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  alignment: Alignment.center,
                  child: Text(current, style: const TextStyle(fontSize: 17)),
                ),
                const SizedBox(width: 9),
                Text(
                  'Choose an icon',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: harbor.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
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
      // Prepends the packing shortlist as the first tab; see [buildIconSet].
      emojiSet: buildIconSet,
      categoryViewConfig: CategoryViewConfig(
        // NONE keeps the package's own recents machinery off the RECENT slot,
        // leaving it for the shortlist above.
        recentTabBehavior: RecentTabBehavior.NONE,
        initCategory: Category.RECENT,
        // A suitcase, not the stock clock — this tab is a shortlist, not a
        // history.
        categoryIcons: const CategoryIcons(recentIcon: Icons.luggage),
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

    // The package's own corpus lists some emoji under two categories — 🧳 is in
    // both SMILEYS and OBJECTS — so an unfiltered result set shows the same
    // glyph twice. Nothing to do with the shortlist tab, which `searchEmoji`
    // excludes outright.
    final seen = <String>{};
    final unique = [
      for (final emoji in results)
        if (seen.add(emoji.emoji)) emoji,
    ];

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
            child: unique.isEmpty
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
                        itemCount: unique.length,
                        itemBuilder: (context, index) => buildEmoji(
                          unique[index],
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
