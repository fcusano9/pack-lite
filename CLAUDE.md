# Pack Lite — project guide for Claude

Simple, fast, offline packing-list app. Flutter, single codebase (Android + iOS).
No account/ads/cloud; all data local. Product value is simplicity — push back on
feature creep.

## Workflow
- Changes land via pull request, never direct commits to `main` — branch, push,
  open a PR for review.
- **Keep PR descriptions short and to the point.** A few sentences or a short
  bullet list: what changed, and anything the reviewer genuinely has to decide
  on. No multi-paragraph write-ups, no section headings per issue, no restating
  the diff or narrating how it was tested — the diff and the CI run already say
  that. Detail belongs in the commit message and the code comments.

## Commands
- `flutter pub get` — deps
- `flutter run` — device/emulator; `flutter run -d chrome` — web preview
- `flutter analyze` — must be clean before building
- `flutter build apk --release --split-per-abi` — release APKs (arm64 is the S25 target)

## Architecture (lib/)
- `store.dart` — `AppStore extends ChangeNotifier`, the single source of truth.
  Whole model persisted as ONE JSON doc in shared_preferences on every mutation.
  Keys: `packlite.data`, `packlite.theme`, `packlite.vibration`,
  `packlite.collapsed`. Seeds sample lists + saved categories on first launch.
  `packlite.collapsed` is `{listId: [sectionKey, …]}` — which headers the user has
  folded shut (#61), with `AppStore.packedSectionKey` standing in for the Packed
  section, which is rendered rather than being a real `PackCategory`. It's view
  state, so it lives in its own key and stays **out** of the exported document;
  it's pruned against the live lists on load, on import and on list delete. The
  document is `v2`
  (`{v, exportedAt, lists, categories}`); `v1`'s `presets` key is dead and not
  migrated — see Saved categories below.
- `models.dart` — `Item`, `PackCategory`, `PackingList` (+ toJson/fromJson).
- `theme.dart` — the **Harbor** design language as a `ThemeExtension` (light + dark).
- `backup_sync.dart` — nudges Android Auto Backup (`BackupManager.dataChanged()` over
  a MethodChannel to `MainActivity.kt`) after destructive changes. See the gotcha below.
- `screens/` — home, list_screen, category_editor, categories_screen, settings_screen.
- `sheets/` — new_list, category, icon_picker, category_picker (bottom sheets).
  `icon_picker` is the whole emoji set via `emoji_picker_flutter` since #57, with
  `icons.dart`'s packing shortlist injected as the **first tab** and the default view.
  See the icon picker note below.
- `widgets/` — list_card, celebration. `sound.dart` / `haptics.dart` / `data_io.dart`.
- `motion.dart` — `Motion.menu`, the shared `AnimationStyle` for menus. Applied via
  `PopupMenuButton.popUpAnimationStyle` and `showModalBottomSheet(sheetAnimationStyle:)`.
  **Menus and pickers use it; forms keep Flutter's defaults** — see the Harbor note below.
- `links.dart` — outbound URLs (repo, GitHub Sponsors) shown in Settings → ABOUT.
  Opened via `url_launcher`; Android needs the `https` VIEW `<intent>` in the manifest's
  `<queries>` or the taps silently do nothing on Android 11+.
- **Invariant: a list has either no categories, or categories and no loose items.**
  `AppStore._absorbLooseItems` folds loose items into a real category named
  `Uncategorized` the instant a list gains its first one (#46), so that section is an
  ordinary `PackCategory` — renameable, reorderable, deletable — with no special case in
  the UI. It runs on `addCategory`, `addSavedCategoryToList`, and on load/import (older
  documents can hold both). `_buildRows` still renders a header-less loose section when
  `items.isNotEmpty`, purely as a safety net so items can never become invisible if the
  invariant is somehow broken; in normal operation that only fires on a flat list.

## Icon picker
Any emoji is pickable (#57), via `emoji_picker_flutter`. Four things about that
integration are deliberate and easy to undo by accident:

- **The shortlist is a `CategoryEmoji(Category.RECENT, …)` prepended to the set** by
  `buildIconSet`, with `initCategory: Category.RECENT` and the tab icon swapped to a
  suitcase. Repurposing RECENT is not a hack: `RecentTabBehavior.NONE` stops the package
  writing to that slot, and `searchEmoji` deliberately **skips RECENT**, so the shortlist
  can repeat emoji that also live in Travel or Objects without doubling every search hit.
- **`Emoji.name` is the glyph itself** for shortlist entries. `name` only ever feeds
  search keywords, and this category is excluded from search — which sidesteps looking
  each icon up in the package's corpus, where 🚴 🏃 🏊 🛶 are stored in variant forms a
  literal match misses.
- **The stock search view is replaced.** It's a single horizontal strip of results with
  the field *below* it, sized to sit above a keyboard; in a sheet that leaves two thirds
  empty. Ours is a grid with the field on top, extending the package's `SearchView` so
  the search logic stays theirs. It also **dedupes by glyph** — the package's own corpus
  lists 🧳 under both SMILEYS and OBJECTS.
- **Everything is Harbor-coloured**; the defaults are a light grey-blue that reads as a
  pale block in dark mode. Backspace is off (no text field to erase into).

## Saved categories (was: presets)
`AppStore.savedCategories` is a `List<PackCategory>` living outside any list — reusable
blocks like "Toiletries". **There is no separate template type.** #13 deleted `Preset`,
which was a `PackingList` minus checkboxes: ~960 lines maintaining a parallel universe of
the same shape, where every seed preset in practice wrapped a *single* category of the
same name. A whole-trip template is already covered by **Duplicate** (which #27 made start
fully unpacked), so the second concept earned nothing.

Consequences worth knowing:
- Only one container type exists now, so the #46 invariant is universal. Presets could
  hold loose items *and* categories at once — the state #46 declared illegal for lists.
- **Merge rule** (`addSavedCategoryToList`): a list category with the same name
  (case-insensitive) absorbs the items, otherwise the category is appended; item names
  already present are skipped either way. `copyUnchecked()` guarantees a block never
  arrives pre-packed.
- UI copy is just "Categories" (Settings row, screen title). The list `+` menu says
  **"Add Saved Category"** — the one place the adjective is needed, since it sits next to
  "New Category".
- **Saving a category whose name is already in the library adds a second entry** rather
  than merging. Matches the old preset behaviour and is non-destructive, but it does mean
  two same-name blocks can coexist; revisit if it proves annoying.
- **No `v1` migration** — the app has only ever run on Frank's devices, so a stored
  `presets` key is ignored and dropped on the next write. Don't add migration code for it.

## Harbor design language
Cool grey-blue neutrals, ONE cobalt accent (#2251CC light / #5B82F0 dark) for
actions + in-progress, GREEN (#199A6D / #2FB985) reserved for "done". Dense rows
and cards (grown ~25% from the original mockups after on-device testing), modest
font sizes, device-native emoji for icons. List header uses "option C" (count
chip in the title row + thin progress bar).

**Motion:** transient surfaces you tap *through* — popup menus, long-press action
sheets, the icon and saved-category pickers — use `Motion.menu` (140ms in, 90ms out) instead of
Flutter's 300ms popup / 250ms sheet defaults, which read as sluggish on repeat use. Exit
is faster than entry: arriving is information, leaving is just clutter. Surfaces you
*work in* — the new-list and category **forms**, and the reorder sheet — keep the
defaults, because a tall sheet snapping in at 140ms reads as a glitch rather than speed.

## Signing
`android/app/packlite-release.jks` + `android/key.properties` are git-ignored
(passwords live in key.properties). Keep a secure backup — losing the keystore
means no more updates that install over existing installs.

## App identity
`applicationId` and iOS bundle id are both **`com.packlite.app`** — product-branded on
purpose, not a personal name. Treat it as permanent: Google will not let you change an
`applicationId` after a Play Store release (a "change" is a new listing that forfeits
installs, reviews and ratings). Even before release, changing it makes Android treat the
build as an entirely different app — it installs *alongside* the old one rather than over
it, and none of the existing data carries over, so export first.

## iOS
**The local iOS toolchain works** (since 2026-07-27): Xcode 26.6, iOS 26.5 simulator
runtime, CocoaPods 1.17.0, `flutter doctor` green. You can build and run iOS locally:

```
flutter build ios --simulator --debug     # then install/launch via simctl
flutter run -d <simulator-udid>           # attaches the Dart console
```

The first build takes ~2 minutes and resolves plugins via **Swift Package Manager**, not
CocoaPods. The `Build iOS` GitHub Actions workflow still does the same thing on every PR
(release `--no-codesign`, plus a simulator launch and screenshot artifact), so it remains
the check that catches iOS regressions without anyone remembering to look.

**No physical device is set up**, and the simulator tooling cannot drive one. Frank's
iPhone 12 is a **work** phone, so MDM may block Developer Mode and dev-signed installs
entirely — TestFlight is the more likely route there. Free-provisioning certificates
expire after 7 days. That leaves IOS-2 (haptics) and IOS-3 (ringer switch) untestable
for now, since neither has a simulator equivalent.

Already handled, don't "fix" these:
- `ios/Podfile` is absent because it's generated on the first iOS build. Not a bug.
- Bundle id is `com.packlite.app`, matching Android (see App identity).
- All plugins resolve iOS implementations, several via federated packages
  (`audioplayers_darwin`, `path_provider_foundation`, `shared_preferences_foundation`,
  `url_launcher_ios`) — an absent `ios/` directory in the top-level package is expected.
- No `NSxxxUsageDescription` keys are needed: `file_picker` reads JSON through the document
  picker, and nothing touches camera, mic, photos or location.

Deliberate platform asymmetries:
- **Haptics.** Android drives the vibrator directly for amplitude control; iOS falls back
  to `HapticFeedback.*` (see `haptics.dart`), so the Settings strength levels are coarser
  there *and* obey the system haptic setting. The Settings helper text is
  platform-conditional for exactly that reason (#38) — the Android wording is false on
  iOS. Guarded by `settings_platform_copy_test.dart`.
- **Sound obeys the iOS silent switch.** `sound.dart` uses
  `AVAudioSessionCategory.ambient`, so the check-off pop is muted when the ringer switch is
  off — unlike Android, where the whole point was bypassing system touch-sound settings.
  This is intentional: `playback` would override the silent switch, which is against
  platform convention and draws App Review attention.
- **`BackupSync` is Android-only** and no-ops on iOS via the caught `MissingPluginException`.
  iOS has no `BackupManager.dataChanged()` equivalent, so the #24 fix has no iOS analogue.
- The **app icon** is the rolling-suitcase mark (see App icon below), generated for both
  platforms — no longer the Flutter placeholder.

## App icon
Generated by `flutter_launcher_icons` from `assets/icon/`; sources and the full
regeneration recipe are in `assets/icon/src/README.md`. **Edit the SVGs, not the PNGs.**
Regenerate with `dart run flutter_launcher_icons`.

Two traps documented there, both hit during the build: `qlmanage` (the only rasteriser on
this machine) flattens transparency onto white, so the adaptive foreground's alpha is
recovered by rendering on white *and* black and solving for it; and the foreground SVG
must **not** be pre-scaled, because `ic_launcher.xml` already applies a 16% inset and the
two compound.

Six PNGs are generated, all derived from the one SVG: the master, the two Android
adaptive layers, **iOS 18 dark and tinted** (#47), and the **Android 13+ themed**
monochrome layer (#48). The monochrome one strips `class="depth"` and `class="panel"`
elements — Android tints by alpha alone, so leaving the green panel in would fill the
check knockout and lose the mark. Keep those classes on the shapes.

## Releasing
`docs/release-checklist.md` — per-store checklists for Google Play and the App Store.
Note Play needs an `.aab` (`flutter build appbundle`) and nothing in this repo builds
one yet, and that build numbers must increase on every upload while every CI build is
still `versionCode 2005`. Release process stays out of the README by preference.

**Keep it current.** Tick items off as they're genuinely finished, with the date and a
PR or issue reference, and update any item whose facts have changed. A checklist that
lags reality is worse than none, because it still gets trusted. Never tick something
that's only partly done — annotate it instead.

## Gotchas (cost us real time — heed these)
- `compileSdk = 36` is set explicitly in `android/app/build.gradle.kts` (file_picker's
  transitive deps require it). Don't drop it back to the Flutter default.
- `file_picker` must be `^10.x` — 8.x is compiled against an old SDK and fails the build.
- **Android's system "touch sounds" / "touch vibration" settings gate Flutter's
  built-in `HapticFeedback` and `SystemSound`.** So core feedback is driven directly:
  vibration via the `vibration` package (with an in-app strength setting), sound via
  `audioplayers` routed to the media stream. Never rely on HapticFeedback/SystemSound
  for the check-off feel.
- **Android Auto Backup silently restores old data on reinstall, so reinstall-based
  testing lies to you.** `android:allowBackup` isn't declared, so it defaults to `true`:
  all of `shared_prefs/` (`packlite.data`, `packlite.theme`, `packlite.vibration`,
  `packlite.collapsed` — every
  byte the app owns) is uploaded to the user's Google account roughly daily and restored
  when the app is installed again. Two bugs were filed against this before it was
  understood: "fresh install defaults to light theme" (#23, not a theme bug — the restored
  snapshot carried `packlite.theme`) and "deleted lists come back after reinstall" (#24).
  - Backup is deliberately left **on** — it's what gives users phone-to-phone migration
    with no account. `deleteAllData()` calls `BackupSync.dataChanged()` to push the empty
    state promptly, but that's a request the system schedules, not a guarantee.
  - **To test a genuinely fresh install**, wipe the cloud dataset first:
    `adb shell bmgr wipe <transport> com.packlite.app` (find `<transport>`, marked
    `*`, via `adb shell bmgr list transports`). Uninstalling alone is *not* enough.
  - To reset local data only, use Settings → Apps → Pack Lite → Storage → **Clear data**;
    clearing data doesn't trigger a restore, reinstalling does.
- **`Container(decoration: cond ? null : BoxDecoration(...))` silently destroys child
  state.** Container only inserts a `DecoratedBox` when `decoration != null`, so flipping
  that condition changes the tree *depth* below it. Flutter can't match the old elements,
  so their `State` is disposed and rebuilt — and a `TextField` in there loses its keyboard
  connection even though the `FocusNode` (owned by the parent) still reports focus. This
  caused #22: the loose add row's `roundTop` is `looseUnchecked.isEmpty`, which flips
  exactly once — as the first item is added — so "the keyboard closes when you add an item
  to an empty list". Fix is to always pass a decoration and use `BorderSide.none` for the
  no-divider case. Both add rows (`list_screen.dart`, `category_editor.dart`) do this now.
  The item rows still use the `? null :` form; harmless today since they hold no focus,
  but don't put a `TextField` under one. Guarded by `add_item_keyboard_test.dart`, which
  asserts `tester.testTextInput.isVisible` — the reliable way to test keyboard state.
- **`Share.shareXFiles` without `sharePositionOrigin` silently does nothing on iOS.**
  It presents no sheet and, critically, **does not throw** — so a `try/catch` around it
  never fires and Export looks like a dead button (#37). The origin is documented as an
  iPad requirement, which is easy to skip when testing on a phone. `DataIO.export` now
  takes one and returns the `ShareResult`; the caller surfaces a toast on
  `ShareResultStatus.unavailable`, so "the platform declined" can never again be
  indistinguishable from "nothing happened".
- Verifying on Flutter **web** (browser pane): `main.dart` calls
  `SemanticsBinding.instance.ensureSemantics()` so `read_page` sees widgets. Coordinate
  clicks are unreliable (2× display scaling), especially top-bar icons — prefer element
  refs or keyboard (space activates InkWells). Force theme via
  `localStorage['flutter.packlite.theme']`. **Editing `main.dart` needs a full dev-server
  restart** (hot reload won't recompile the web entry).

## Testing target
Frank's phone is a Samsung Galaxy S25 Ultra (APK sideload) — the only hardware anything
has actually been tested on. iOS runs in the **simulator** locally and in CI (see iOS
above), but no physical iPhone is set up. Verify previewable changes and share a
screenshot before calling something done; headless widget tests are the trusted stack,
the web preview is the fallback.
