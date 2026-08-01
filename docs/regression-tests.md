## Priority legend

| Tag | Meaning |
|-----|---------|
| **P0** | Core flow. If this breaks, the app is unusable. Always test. |
| **P1** | Important feature. Test on any related change and every full pass. |
| **P2** | Polish / edge case. Test on full passes or when the area changed. |

---

## 0. Smoke Test (P0)

- [ ] **SMK-1** App launches to the Home screen with the four seeded lists visible.
- [ ] **SMK-2** Tapping a list opens it and shows its items.
- [ ] **SMK-3** Checking an item gives a haptic + sound, then the row animates down into **PACKED**.
- [ ] **SMK-4** Unchecking an item (tap it in PACKED) returns it to its section.
- [ ] **SMK-5** The **+** (FAB) on Home creates a new list; it appears at the **top**.
- [ ] **SMK-6** Adding an item inline (tap **Add item**, type, Enter) works.
- [ ] **SMK-7** Swipe a Home card **left** → Delete (with confirm); **right** → Duplicate.
- [ ] **SMK-8** `···` menu → **Uncheck All** resets a list; nothing is deleted.
- [ ] **SMK-9** Change theme in Settings (Light/Dark/System) and it applies immediately.
- [ ] **SMK-10** Force-kill the app and relaunch — all changes from this session persisted.
- [ ] **SMK-11** The launcher shows the app as **"Pack Lite"** under its icon — not
  "pack_lite" or "packlite". Check this on the home screen and in Settings → Apps.
- [ ] **SMK-12** The launcher icon is the **rolling suitcase with a green cut-out check**
  on a cobalt gradient — not the Flutter placeholder (#12). On Android confirm it fills
  its mask properly (no white plate behind it, nothing clipped) under whichever icon
  shape the launcher uses; a shrunken-looking icon means the adaptive foreground got
  double-inset — see the App icon note in `CLAUDE.md`.
- [ ] **SMK-13** **iOS 18 dark and tinted icons** (#47). Switch the phone to dark mode:
  the icon loses its cobalt background and sits on the system's dark backdrop, like
  Apple's own apps. Then Settings → Home Screen & App Library → **Tinted**: the icon
  turns monochrome and takes the chosen colour. Neither should show a cobalt square,
  which is what an unconfigured icon looks like.
- [ ] **SMK-14** **Android themed icon** (#48). With themed icons on (Settings →
  Wallpaper & style → Themed icons, Android 13+), the icon becomes a flat silhouette in
  the wallpaper palette, **with the check still visible as a hole** through the case. If
  the check vanishes, the green panel is being included in the monochrome layer — see
  `assets/icon/src/README.md`.

---

## 1. First launch & seed data (P1)

- [ ] **SEED-1** On a **first-ever launch** — no stored data at all — Home shows four
  sample lists: **Hawaii Vacation, Ski Trip, Camping Weekend, Weekend in NYC**. Seeding
  only happens when no data document exists, so **Delete All Data does not reseed**
  (it writes an empty document; see DATA-7). Reinstalling isn't enough to reach this
  state either — see the Auto Backup gotcha in `CLAUDE.md`.
- [ ] **SEED-2** Settings → List Presets shows three seeded presets: **Toiletries,
  Tech & Chargers, Beach Gear**.
- [ ] **SEED-3** Camping Weekend shows an **All Packed** state (fully checked); the
  others show partial progress.
- [ ] **SEED-4** Seed data is fully editable — a seeded list can be renamed, its items
  checked/deleted, and the list swiped away like any user data.

## 2. Home screen (P0)

- [ ] **HOME-1** Each card shows: icon, list name, a count (`X of Y`), and a thin
  progress bar.
- [ ] **HOME-2** A partially packed list's progress bar is **cobalt** and fills
  proportionally to packed/total.
- [ ] **HOME-3** A fully packed list shows **"All Packed ✓"** in green (bold) and a
  full **green** progress bar — clearly distinct from partial lists.
- [ ] **HOME-4** A brand-new empty list shows **"0 items"** and an empty bar.
- [ ] **HOME-5** Tapping a card opens that list.
- [ ] **HOME-6** Swipe a card **right→** reveals a cobalt **Duplicate** background; on
  release the list is duplicated as **"<name> copy"** inserted directly below the
  original, a snackbar confirms, and the original card stays in place. The new card reads
  **`0 of N`** with an empty bar — see REUSE-4.
- [ ] **HOME-7** Swipe a card **←left** reveals a red **Delete** background and shows a
  **confirmation dialog**; Cancel keeps it, Delete removes it.
- [ ] **HOME-8** Long-press a card, then drag to **reorder**; the new order sticks.
- [ ] **HOME-9** Roughly 6–6.5 cards are visible before scrolling (dense layout).
- [ ] **HOME-10** With no lists, an **empty state** ("No lists yet / Tap + to create
  your first packing list") is shown instead of the card list.
- [ ] **HOME-11** The gear icon (top-right) opens Settings.

## 3. Creating & editing lists (P0)

- [ ] **NEW-1** FAB **+** opens the **New List** sheet with an icon tile, a name field
  (autofocused), and (when presets exist) a **"Start from presets · optional"** chip row.
- [ ] **NEW-2** **Create List** is disabled until the name is non-empty.
- [ ] **NEW-3** Tapping the icon tile opens the emoji picker; the chosen icon shows on
  the tile and later on the card. Default icon is the backpack 🎒.
- [ ] **NEW-4** Creating a list closes the sheet, adds the list to the **top** of Home,
  and **opens it** immediately.
- [ ] **NEW-5** Selecting one or more preset chips seeds the new list with those presets'
  items (merged per the preset rules — see §8).
- [ ] **NEW-6** **Cancel** (or back) creates no list and returns to Home.
- [ ] **NEW-7** On the list screen, tapping the **icon + title** in the header opens the
  **Edit List** sheet (no preset chips when editing); changing name/icon updates the
  header and the Home card.
- [ ] **NEW-8** A list with nothing in it shows the empty state: 📝, the heading
  **"Start your list"**, the subtitle **"Add items one by one, or group them into
  categories."**, and two buttons — **Add item** and **New Category**. The subtitle should
  name both paths and must not read as though setup is required (#17). Both buttons work:
  Add item opens the inline field (see ITEM-2), New Category opens the category sheet.

## 4. Items — add / check / rename / delete (P0)

- [ ] **ITEM-1** Each section has an **Add item** row at its bottom. Tapping it opens an
  inline field (no dialog) — the item appears in that section.
- [ ] **ITEM-2** Pressing **Enter** commits the item and **keeps the add row open**
  (refocused) for fast repeated entry — **the keyboard must stay up**. Check this on an
  **empty** list too: the very first item is the case that used to drop the keyboard
  (issue #22), and every item after it behaved correctly, so testing a list that already
  has items will not catch a regression here.
  *(Guarded by `add_item_keyboard_test.dart`, list and preset editor.)*
- [ ] **ITEM-3** Tapping outside the field commits the current text and closes the row;
  submitting an **empty** field just closes it (no blank item created).
- [ ] **ITEM-4** Tapping an item's checkbox: plays a haptic tick + pop sound, the check
  lands, then after a short beat the row **animates down** into the PACKED section.
- [ ] **ITEM-5** A packed item's text is **greyed and struck through**.
- [ ] **ITEM-6** Tapping a packed item unchecks it and it returns to **its original
  section** (not the top).
- [ ] **ITEM-7** Swipe an item **right→** ("Rename") opens a rename dialog; saving
  updates the name. (Item stays put — not dismissed.)
- [ ] **ITEM-8** Swipe an item **←left** ("Delete") deletes it immediately with **no
  confirmation**, showing an **Undo** snackbar.
- [ ] **ITEM-9** Tapping **Undo** restores the item at its original position; the
  snackbar auto-dismisses after ~4s if untouched.
- [ ] **ITEM-10** Deleting a second item quickly replaces the first snackbar cleanly
  (no stuck/duplicate toasts). *(Guarded by `snackbar_dismiss_test.dart`.)*
- [ ] **ITEM-11** Long-press an item and drag to **reorder** within its section; order sticks.
- [ ] **ITEM-12** Long-press-drag an item into a **different category** (or into the
  loose section, or vice-versa) moves it there.

## 5. Categories (P1)

- [ ] **CAT-1** Header **+** → **New Category** prompts for a name and optional icon;
  the new category appears with its **Add item** row.
- [ ] **CAT-2** Tapping a category header **collapses/expands** it (chevron rotates);
  its `packed of total` count shows in the header.
- [ ] **CAT-3** `···` menu → **Collapse All** / **Expand All** affect every category.
- [ ] **CAT-4** Long-press a category header opens its menu: **Rename & icon**,
  **Reorder categories** (only shown when ≥2 categories), **Save as preset**,
  **Delete category**.
- [ ] **CAT-5** **Rename & icon** updates the header; an icon can be added or cleared.
- [ ] **CAT-6** **Reorder categories** sheet changes category order; it persists.
  *(Logic guarded by `reorder_categories_test.dart`.)*
- [ ] **CAT-7** **Delete category** shows a **confirmation** that names how many items
  will be deleted (or "This category is empty"); confirming removes the category and
  all its items.

## 6. Loose items & the Packed section (P1)

- [ ] **LOOSE-1** A list with **no categories** is a flat checklist — its items sit in a
  header-less section with just an Add item row.
- [ ] **LOOSE-2** Adding the **first category** to a flat list moves its loose items into
  a real category named **Uncategorized**, placed first, in their original order and with
  their packed state intact (#46). Nothing should appear to move or reset.
- [ ] **LOOSE-3** In **PACKED**, packed items from that category are labelled
  **UNCATEGORIZED** like any other. A flat list's packed items stay unlabelled.
- [ ] **LOOSE-4** The **PACKED · N** header collapses/hides all packed items and can be
  expanded again. *(Rendering guarded by `loose_items_test.dart`.)*
- [ ] **LOOSE-5** **Uncategorized is an ordinary category** (#46): long-press offers
  **Rename & icon**, **Reorder categories**, **Save as preset** and **Delete category**,
  and each works. Renaming it away means the name is simply gone — no section reappears.
- [ ] **LOOSE-6** It collapses with **Collapse All**, reorders among the other categories,
  and items drag into and out of it like any other. *(Store behaviour and the menu are
  guarded by `uncategorized_section_test.dart`; dragging is manual-only.)*
- [ ] **LOOSE-7** Its header **stays visible when everything in it is packed** (`· 2 of 2`
  with only the Add item row beneath), like any fully packed category.
- [ ] **LOOSE-8** A list that already held loose items **and** categories before this
  change (an older backup, say) is tidied on **import**: the loose items land in
  Uncategorized rather than disappearing.

## 7. Completion moment (P1)

- [ ] **DONE-1** Checking the **last** unchecked item triggers a brief celebration
  (confetti burst), a **bigger** pop sound, and a stronger haptic.
- [ ] **DONE-2** A persistent **"All packed — Everything's checked off…"** banner shows
  at the top of the list; the progress bar is full and green.
- [ ] **DONE-3** The celebration never blocks input — you can immediately scroll/tap.
- [ ] **DONE-4** Unchecking then re-completing the list triggers the celebration **again**
  (it re-arms after dropping below complete).
- [ ] **ALLPACK-5** The **All packed** banner logic holds for a list that was created
  already-complete. *(Guarded by `all_packed_test.dart`.)*

## 8. Presets (P1)

- [ ] **PRE-1** Header **+** → **Add Preset** opens a picker listing every preset with
  its `categories · items` counts.
- [ ] **PRE-2** Choosing a preset pours its items in and shows a snackbar
  **"Added N items from preset"**.
- [ ] **PRE-3** **Merge rule — loose:** a preset's loose items merge into the list's
  loose items; an item whose name already exists there (case-insensitive) is **skipped**.
- [ ] **PRE-4** **Merge rule — categories:** a preset category whose name matches an
  existing category **merges into it** (duplicate item names skipped); a non-matching
  category is appended as new.
- [ ] **PRE-5** Adding a preset whose items are all already present shows
  **"All preset items were already in this list"** and adds nothing.
- [ ] **PRE-6** Settings → **List Presets** lists presets; the count in the Settings row
  matches.
- [ ] **PRE-7** In List Presets: **+** creates a preset (name + icon) and opens the
  **Preset Editor**; tapping a preset opens it to edit.
- [ ] **PRE-8** The Preset Editor behaves like the list screen **minus checkboxes /
  PACKED** — add/rename/delete items and categories, loose items included.
- [ ] **PRE-9** In List Presets, **swipe** a preset (either direction) → Delete with
  confirm; **long-press** to reorder.
- [ ] **PRE-10** Deleting a preset does **not** change lists already created from it.
- [ ] **PRE-11** **Save as preset** from a list's `···` menu creates a preset copy of the
  whole list (unchecked); snackbar confirms.
- [ ] **PRE-12** **Save as preset** from a category's long-press menu creates a
  single-category preset; snackbar confirms.
- [ ] **PRE-13** Later edits to a list do **not** change a preset previously saved from
  it (and vice-versa) — they're independent copies.

## 9. List reuse (P0)

- [ ] **REUSE-1** `···` menu → **Uncheck All** shows a confirm ("Ready to pack for the
  next trip — nothing is deleted"); confirming resets **every** item to unchecked with
  nothing deleted.
- [ ] **REUSE-2** **Uncheck All** is **disabled** when 0 items are packed.
- [ ] **REUSE-3** Duplicating a list from Home (swipe right) yields an independent copy —
  editing the copy doesn't touch the original.
- [ ] **REUSE-4** The duplicate starts **fully unpacked** (`0 of N`, empty progress bar)
  even when the original was partly or wholly packed — and the **original keeps its own
  progress**. Test with a list that has packed items in **both** a category and the loose
  section. *(Guarded by `duplicate_list_test.dart`.)*

## 10. Settings (P1)

- [ ] **SET-1** **Theme** segmented control (Light / Dark / System) applies immediately
  and the selection persists across relaunch.
- [ ] **SET-2** **Vibration** segmented control (Off / Light / Medium / Strong) — each
  tap gives a haptic + sound at that strength; **Off** gives no vibration.
- [ ] **SET-3** Vibration works **regardless of** the phone's system touch-vibration
  setting (turn the system setting off and confirm check-off still buzzes).
- [ ] **SET-4** Check-off **sound** plays even with the phone's system touch-sounds off
  (routed through the media stream).
- [ ] **SET-5** **Language** row reads "English" and is disabled (non-interactive).
- [ ] **SET-6** The app **version** shows centered at the bottom ("Pack Lite <version>")
  and matches the installed build.
- [ ] **SET-7** **ABOUT → View Source on GitHub** opens the repo in the browser; the row
  shows an **open-in-new** glyph (not a chevron) to signal it leaves the app.
- [ ] **SET-9** **LEGAL → Privacy Policy** and **Terms of Service** each open the right
  page on `fcusano9.github.io/pack-lite`. Both stores require a reachable policy link, so
  a dead one here is a submission problem, not just a broken row.
- [ ] **SET-8** **ABOUT → Sponsor on GitHub** opens the **sponsors** page — confirm the
  URL really is `/sponsors/`, not the repo. **Test on a real device:** Android 11+ hides
  other apps unless declared in the manifest `<queries>`, so a broken build fails by doing
  *nothing* on tap. Returning to the app leaves Settings exactly as it was.
  *(Wiring guarded by `settings_links_test.dart`.)*

## 11. Data — export / import / delete (P1)

- [ ] **DATA-1** **Export Data** opens the system share sheet with a file named
  `pack-lite-backup-YYYY-MM-DD.json`.
- [ ] **DATA-2** **Import Data** → file picker; selecting a valid backup shows a dialog
  with its list/preset counts and **Add** vs **Replace** choices.
- [ ] **DATA-3** **Add** (merge) keeps existing data and adds the imported lists/presets;
  a toast reports the counts imported.
- [ ] **DATA-4** **Replace** swaps all current data for the imported data.
- [ ] **DATA-5** Importing a non-backup / corrupt file is rejected gracefully
  ("That doesn't look like a Pack Lite backup" / "Import failed — file may be corrupt").
- [ ] **DATA-6** **Round-trip:** Export → Delete All Data → Import the file (Replace)
  restores lists and presets intact (names, icons, items, checked states).
- [ ] **DATA-7** **Delete All Data** is a **two-step** confirm: a warning dialog, then a
  **type-DELETE** dialog (the final button is disabled until "DELETE" is typed).
  Completing it clears all lists and presets; Home shows the empty state. The first
  dialog states that the **Google account backup** is cleared too.
- [ ] **DATA-8** **Deleted data stays deleted across a reinstall.** Delete All Data, wait
  a few minutes on Wi-Fi (Android schedules the backup pass; it can't run offline), then
  uninstall and reinstall the APK. **Pass = the deleted lists do not come back.** Home
  will show either the empty state (the emptied snapshot was restored) or the seed lists
  (nothing was restored) — both are fine; the old lists reappearing is the failure. This
  is the regression guard for the Auto Backup restore bug (issue #24); see the Auto
  Backup gotcha in `CLAUDE.md`. If it fails, confirm the backup pass actually ran before
  blaming the app.

## 12. Feedback — haptics & sound (P1)

- [ ] **FB-1** Checking an item gives a crisp haptic tick **and** the pop sound together.
- [ ] **FB-2** Reordering (list, item, category, preset) fires a haptic on drag start.
- [ ] **FB-3** Completing a list gives the stronger "celebrate" haptic + bigger pop.
- [ ] **FB-4** With Vibration = Off, no buzzes occur but sounds still play.

## 13. Theming & visuals (P2)

- [ ] **THEME-1** Light and dark both render legibly across Home, list, presets,
  settings — no unreadable low-contrast text.
- [ ] **THEME-2** **System** mode follows the OS toggle live (flip system dark mode).
- [ ] **THEME-3** Cobalt is used for actions & in-progress; **green only** for done
  states (All Packed card, completed progress bar, checkmarks).
- [ ] **THEME-5** **Menus feel snappy** (issue #18). The `···` and **+** popup menus, the
  long-press category menu (list *and* preset editor), and the **icon** and **preset**
  pickers all open in ~140ms and dismiss faster still — open and close each a few times in
  a row, which is where the old 300ms was noticeable. Nothing should flicker, land
  half-drawn, or drop the first tap.
- [ ] **THEME-6** By contrast the **New List** and **Category** sheets, and the **Reorder
  categories** sheet, keep the slower default motion — this is deliberate (see the Harbor
  motion note in `CLAUDE.md`), not an oversight.
- [ ] **THEME-4** A **first-ever launch** defaults to **System**, not Light (issue #23).
  Reinstalling restores the saved theme from the Google account backup, so this only
  reproduces after wiping the backup dataset — see the Auto Backup gotcha in `CLAUDE.md`.
  Covered automatically by `test/theme_default_test.dart`.

## 14. Accessibility / type scaling (P2)

- [ ] **A11Y-1** Raising the system font scale enlarges text throughout without clipping
  or overlap; rows stay usable.
- [ ] **A11Y-2** Very long list / item / category names truncate with an ellipsis rather
  than breaking the layout.

## 15. Persistence & stability (P0)

- [ ] **PERSIST-1** After a range of edits (add/check/rename/reorder across lists,
  categories, presets, settings), **force-kill** the app and relaunch — every change is
  still there.
- [ ] **PERSIST-2** No crashes or error toasts during a full pass; nothing logged that
  looks like an unhandled exception.

## 16. Edge cases (P2)

- [ ] **EDGE-1** Emoji / non-Latin characters in list, item, and category names save and
  render correctly.
- [ ] **EDGE-2** Whitespace-only names are rejected (create/rename buttons stay disabled
  or trim to empty and do nothing).
- [ ] **EDGE-3** A list with a large number of items (e.g. 100+) scrolls and reorders
  without noticeable lag.
- [ ] **EDGE-4** Rapidly checking several items in a row queues their animations without
  losing any (all end up in PACKED).

## 17. iOS (P2 — not yet run on hardware)

Android is the tested platform; iOS has only ever been compiled. Work through §0's smoke
test first, then these — they cover the places iOS is **deliberately different**, so a
difference here is not automatically a bug. See the iOS section of `CLAUDE.md`.

- [ ] **IOS-1** The app launches and Home renders with the seeded lists (CI already checks
  this much via its simulator screenshot artifact — start here only if that's green).
- [ ] **IOS-2** Check-off **haptics** fire. They'll feel coarser than Android and the
  Settings strength levels less distinct, because iOS falls back to `HapticFeedback.*`
  with no amplitude control. Expected. The Settings note should read **"Strength is
  approximate on iPhone…"**, not the Android wording about bypassing the system setting
  (#38) — that claim is false on iOS.
- [ ] **IOS-3** The check-off **pop is silent when the ringer switch is off**, and audible
  when it's on. This is intentional (`AVAudioSessionCategory.ambient`) and the opposite of
  the Android behaviour, where sound deliberately bypasses system touch-sound settings.
- [ ] **IOS-4** **Export** opens the iOS share sheet showing `pack-lite-backup-<date>.json`
  (#37 — it previously did nothing at all), and **Import** opens the Files document picker;
  a round-trip restores the data with no permission prompt. Worth trying on an **iPad** too
  if one is ever to hand: the share popover needs an anchor rect there, which is what was
  missing.
- [ ] **IOS-5** Settings → ABOUT links open Safari. iOS needs no `<queries>` equivalent for
  `https`, so if these fail the cause is different from the Android case in SET-8.
- [ ] **IOS-6** **Delete All Data** clears everything locally. Note the Google-account
  backup wording in the dialog is Android-specific — iOS has no equivalent push, so
  reinstalling may restore from an iCloud backup regardless (see #24 and `CLAUDE.md`).
- [ ] **IOS-7** The launcher shows **"Pack Lite"**, and the icon is currently the **Flutter
  placeholder** — that's issue #12, not an iOS fault.
- [ ] **IOS-8** Light and dark both follow the system setting, and text scales with the iOS
  Display & Text Size setting without clipping.

