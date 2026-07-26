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
- **Reuse** — duplicate a list (the copy starts fully unpacked, ready for the next
  trip), or **uncheck all** to reset one in place.
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

### iOS

Android is the platform actively tested on hardware. The iOS target builds, but is
**not yet verified on a device** — CI compiles it on every pull request (release,
unsigned) and launches it in a simulator to confirm it starts, publishing a screenshot
as a build artifact.

```sh
flutter build ios --release --no-codesign    # compile check, no signing identity needed
flutter build ios --simulator --debug        # runnable in the iOS Simulator
```

Both need a full Xcode install (free from the App Store) plus CocoaPods; the Command
Line Tools alone aren't enough.

### Signing

Release builds are signed with a keystore that is **not** in this repo
(`android/app/packlite-release.jks` and `android/key.properties` are
git-ignored). Keep a secure backup of the keystore — it's required to publish
updates that install over existing installs.

## Support

Pack Lite is free, with no ads, no tracking and no in-app purchases — and it
stays that way. Nothing in the app is gated behind paying.

If it's useful to you and you'd like to help it keep going, you can sponsor
development at **[github.com/sponsors/fcusano9](https://github.com/sponsors/fcusano9)**
(also linked under Settings → About).

Sponsoring is entirely optional, and it isn't the only way to help — bug reports
and feature ideas in [Issues](https://github.com/fcusano9/pack-lite/issues) are
just as valuable.
