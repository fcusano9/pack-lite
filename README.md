# Pack Lite

A simple, fast, offline packing-list app for trips and activities. Built to sit
between heavyweight packing apps (which force trip dates and other complexity)
and plain to-do apps (which lack packing-specific features like reusable presets
and a one-tap "uncheck all" to reset a list for the next trip).

No account, no ads, no servers of our own — the app never sends your data
anywhere, and works fully offline.

> **Note on Android backups:** Android's own Auto Backup is left enabled, so the
> app's data is included in your device's Google account backup and comes back
> automatically when you set up a new phone. That's a system feature, not
> something Pack Lite uploads. Deleting all data in Settings clears the backed-up
> copy too.

## Features

- **Packing lists** organized into collapsible categories, with big checkboxes
  and a live progress bar per list.
- **Check-off** with haptics and a sound; packed items sink to a "Packed"
  section and a small celebration fires when everything's packed.
- **Reuse** — duplicate a list, or **uncheck all** to reset it for the next trip.
- **Presets** — reusable sets of items (e.g. Toiletries); pour them into any
  list, save a list or category as a preset, or start a new list from presets.
- **Import / export** all data as a single JSON file for backup or moving phones.
- Light / dark themes (follows system), adjustable vibration strength, and text
  that scales with the system font-size setting.

## Design language

The UI follows a design language called **Harbor**: cool grey-blue neutrals, one
deep cobalt accent for actions and in-progress state, and green reserved for the
"done" state.

## Tech

- **Flutter** (single codebase, Android + iOS).
- Local persistence via `shared_preferences` (the whole model is a small JSON
  document).
- State via `provider` / `ChangeNotifier`.

## Building

```sh
flutter pub get
flutter run                                    # run on a connected device or emulator
flutter build apk --release --split-per-abi    # release APKs
```

### Signing

Release builds are signed with a keystore that is **not** in this repo
(`android/app/packlite-release.jks` and `android/key.properties` are
git-ignored). Keep a secure backup of the keystore — it's required to publish
updates that install over existing installs.
