# App icon sources

Everything is derived from **one file**: `icon.svg`. Edit that, then run the two
commands below. Don't hand-edit the PNGs in `assets/icon/` or anything under
`android/.../res/` or `ios/Runner/Assets.xcassets/` — all of it is generated and
will be overwritten.

```sh
python3 assets/icon/src/build_icons.py
dart run flutter_launcher_icons
```

The first command rebuilds the three input PNGs from the SVG; the second fans
those out into every Android density and iOS size.

## The design

A rolling suitcase with a checkmark **cut out** of the shell, revealing a green
panel behind it. Harbor palette throughout: cobalt gradient background
(`#3A72F0` → `#1B44AC`), green `#199A6D` for the check, and brushed-metal
hardware (`#DCE6F7` → `#8EA5CD`) for the handle and wheels. The check is a
knockout rather than a drawn mark, so green and cobalt never touch.

## Files

| File | Purpose |
|---|---|
| `icon.svg` | **The only place artwork lives.** Keep the ids `backdrop` and `art` — the build script looks them up by name |
| `build_icons.py` | Emits the render variants, rasterises them, recovers alpha, writes the three PNGs |
| `README.md` | This file |

`build_icons.py` produces four renders from the one SVG: the master (backdrop +
art), the adaptive background (backdrop alone), and the art composited on white
and on black.

## Why the foreground is rendered twice

There is no SVG rasteriser on this machine — no ImageMagick, no librsvg, no
Pillow. The only option is macOS `qlmanage`, which **flattens transparency onto
white**. Used naively, the Android adaptive foreground would be an opaque white
square.

Rendering the same art on white and on black makes alpha exactly solvable:

```
Cw = C*a + 255*(1-a)      Cb = C*a
  =>  a = 1 - (Cw - Cb)/255        C = Cb / a
```

Exact, including anti-aliased edges — a chroma-key would leave coloured fringes.
Implemented with a pure-stdlib PNG decoder/encoder, so there is nothing to
install. Being macOS-only is the trade: `build_icons.py` exits early if
`qlmanage` is missing.

## Gotchas

- **Never scale the art for the adaptive foreground.** `flutter_launcher_icons`
  already applies a 16% inset in `ic_launcher.xml`. Scaling the SVG as well
  compounds the two and the icon renders at roughly 55% of the visible circle —
  noticeably shrunken. This bit once already.
- **iOS rejects icons with an alpha channel.** The renderer always emits RGBA, so
  `remove_alpha_ios: true` in `pubspec.yaml` strips it. Check with
  `sips --getProperty hasAlpha` on the generated 1024 icon.
- **The master must stay a full-bleed square** with no rounded corners — both
  platforms apply their own mask, and baked-in corners appear as corners *inside*
  the mask.
- **Play needs a 512×512 listing icon uploaded separately.** It isn't part of the
  app bundle; downscale `assets/icon/icon.png` when you get there.
