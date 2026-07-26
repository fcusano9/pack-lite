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
- `screens/` — home, list_screen, preset_editor, presets_screen, settings_screen.
- `sheets/` — new_list, category, icon_picker, preset_picker (bottom sheets).
- `widgets/` — list_card, celebration. `sound.dart` / `haptics.dart` / `data_io.dart`.
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

## Signing
`android/app/packlite-release.jks` + `android/key.properties` are git-ignored
(passwords live in key.properties). Keep a secure backup — losing the keystore
means no more updates that install over existing installs.

## Gotchas (cost us real time — heed these)
- `compileSdk = 36` is set explicitly in `android/app/build.gradle.kts` (file_picker's
  transitive deps require it). Don't drop it back to the Flutter default.
- `file_picker` must be `^10.x` — 8.x is compiled against an old SDK and fails the build.
- **Android's system "touch sounds" / "touch vibration" settings gate Flutter's
  built-in `HapticFeedback` and `SystemSound`.** So core feedback is driven directly:
  vibration via the `vibration` package (with an in-app strength setting), sound via
  `audioplayers` routed to the media stream. Never rely on HapticFeedback/SystemSound
  for the check-off feel.
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
