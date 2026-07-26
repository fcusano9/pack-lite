# Pack Lite — project guide for Claude

Simple, fast, offline packing-list app. Flutter, single codebase (Android + iOS).
No account/ads/cloud; all data local. Product value is simplicity — push back on
feature creep.

## Workflow
- Changes land via pull request, never direct commits to `main` — branch, push,
  open a PR for review.

## Commands
- `flutter pub get` — deps
- `flutter run` — device/emulator; `flutter run -d chrome` — web preview
- `flutter analyze` — must be clean before building
- `flutter build apk --release --split-per-abi` — release APKs (arm64 is the S25 target)

## Architecture (lib/)
- `store.dart` — `AppStore extends ChangeNotifier`, the single source of truth.
  Whole model persisted as ONE JSON doc in shared_preferences on every mutation.
  Keys: `packlite.data`, `packlite.theme`, `packlite.vibration`. Seeds sample
  lists + presets on first launch.
- `models.dart` — `Item`, `PackCategory`, `PackingList`, `Preset` (+ toJson/fromJson).
- `theme.dart` — the **Harbor** design language as a `ThemeExtension` (light + dark).
- `backup_sync.dart` — nudges Android Auto Backup (`BackupManager.dataChanged()` over
  a MethodChannel to `MainActivity.kt`) after destructive changes. See the gotcha below.
- `screens/` — home, list_screen, preset_editor, presets_screen, settings_screen.
- `sheets/` — new_list, category, icon_picker, preset_picker (bottom sheets).
- `widgets/` — list_card, celebration. `sound.dart` / `haptics.dart` / `data_io.dart`.
- `motion.dart` — `Motion.menu`, the shared `AnimationStyle` for menus. Applied via
  `PopupMenuButton.popUpAnimationStyle` and `showModalBottomSheet(sheetAnimationStyle:)`.
  **Menus and pickers use it; forms keep Flutter's defaults** — see the Harbor note below.
- `links.dart` — outbound URLs (repo, GitHub Sponsors) shown in Settings → ABOUT.
  Opened via `url_launcher`; Android needs the `https` VIEW `<intent>` in the manifest's
  `<queries>` or the taps silently do nothing on Android 11+.
- Preset→list merge rule: same-name categories merge; duplicate item names skipped.

## Harbor design language
Cool grey-blue neutrals, ONE cobalt accent (#2251CC light / #5B82F0 dark) for
actions + in-progress, GREEN (#199A6D / #2FB985) reserved for "done". Dense rows
and cards (grown ~25% from the original mockups after on-device testing), modest
font sizes, device-native emoji for icons. List header uses "option C" (count
chip in the title row + thin progress bar).

**Motion:** transient surfaces you tap *through* — popup menus, long-press action
sheets, the icon and preset pickers — use `Motion.menu` (140ms in, 90ms out) instead of
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
  all of `shared_prefs/` (`packlite.data`, `packlite.theme`, `packlite.vibration` — every
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
  no-divider case. Both add rows (`list_screen.dart`, `preset_editor.dart`) do this now.
  The item rows still use the `? null :` form; harmless today since they hold no focus,
  but don't put a `TextField` under one. Guarded by `add_item_keyboard_test.dart`, which
  asserts `tester.testTextInput.isVisible` — the reliable way to test keyboard state.
- Verifying on Flutter **web** (browser pane): `main.dart` calls
  `SemanticsBinding.instance.ensureSemantics()` so `read_page` sees widgets. Coordinate
  clicks are unreliable (2× display scaling), especially top-bar icons — prefer element
  refs or keyboard (space activates InkWells). Force theme via
  `localStorage['flutter.packlite.theme']`. **Editing `main.dart` needs a full dev-server
  restart** (hot reload won't recompile the web entry).

## Testing target
Frank's phone is a Samsung Galaxy S25 Ultra (APK sideload). No Xcode on the Mac yet,
so iOS builds aren't possible. Verify previewable changes in the web preview and
share a screenshot before calling something done.
