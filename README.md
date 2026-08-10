# Pack Lite

A simple, fast, offline packing list for trips and activities. It sits between
heavyweight packing apps, which make you commit to trip dates and other
structure, and plain to-do apps, which have nothing built for packing — no
reusable categories, no one-tap reset for the next trip.

No account, no ads, no tracking, and no servers of our own. Your lists live on
your device and the app works fully offline. The
[Privacy Policy](https://fcusano9.github.io/pack-lite/privacy-policy) covers the
few ways data can leave your phone, all of which you control: your own device
backup, the export file, and the links out to GitHub.

## Features

- **Lists organised into categories** you can collapse, with large checkboxes
  and a live progress bar. Collapsed sections stay collapsed next time.
- **Satisfying check-off** — a haptic tick and a pop, then the item sinks into a
  Packed section. A small celebration fires when a list is finished.
- **Saved categories** — keep reusable blocks like Toiletries, drop one into any
  list, save a category out of a list to use again, or start a new list from
  several at once.
- **Reset for the next trip** — duplicate a list (the copy starts fully
  unpacked) or uncheck everything in place.
- **Export and import** everything as a single JSON file, for a backup or to
  move to a new phone.
- Light and dark themes that follow the system, adjustable vibration strength,
  and text that scales with your system font size.

## Privacy and licence

- [Privacy Policy](https://fcusano9.github.io/pack-lite/privacy-policy)
- [Terms of Service](https://fcusano9.github.io/pack-lite/terms-of-service)
- The source is [MIT licensed](LICENSE). That covers the code — it doesn't grant
  any right to the Pack Lite name or app icon, so please don't publish a build
  under this app's branding.

## Tech

- **Flutter** (single codebase, Android + iOS).
- Local persistence via `shared_preferences` (the whole model is a small JSON
  document).
- State via `provider` / `ChangeNotifier`.

## Building

```sh
flutter pub get
flutter run                                    # a connected device or emulator
flutter build apk --release --split-per-abi    # release APKs
```

## Support

Pack Lite is free, with no ads, no tracking and no in-app purchases — and it
stays that way. Nothing in the app is gated behind paying.

If it's useful to you and you'd like to help it keep going, you can sponsor
development at **[github.com/sponsors/fcusano9](https://github.com/sponsors/fcusano9)**
(also linked under Settings → About).

Sponsoring is entirely optional, and it isn't the only way to help — bug reports
and feature ideas in [Issues](https://github.com/fcusano9/pack-lite/issues) are
just as valuable.
