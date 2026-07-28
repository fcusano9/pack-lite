# App icon sources

The PNGs in `assets/icon/` are **generated**. Edit the SVGs here, regenerate, then
re-run the launcher-icon tool. Don't hand-edit the PNGs — the next regeneration
will silently overwrite them.

## The design

A rolling suitcase with a checkmark **cut out** of the shell, revealing a green
panel behind it. Harbor palette throughout: cobalt gradient background
(`#3A72F0` → `#1B44AC`), green `#199A6D` for the check, and brushed-metal
hardware (`#DCE6F7` → `#8EA5CD`) for the handle and wheels.

The check is a knockout rather than a drawn mark, so green and cobalt never
touch — see the mask in each SVG.

## Files

| File | Purpose |
|---|---|
| `icon.svg` | Full-bleed master → `icon.png`, used for iOS and the Play listing |
| `icon_background.svg` | Cobalt gradient only → `icon_background.png`, Android adaptive background layer |
| `icon_foreground_white.svg` / `icon_foreground_black.svg` | The same artwork on white and on black — inputs to `unmatte.py` |
| `unmatte.py` | Recovers true transparency from those two renders |

## Why two foreground renders

There is no SVG rasteriser on this machine — no ImageMagick, no librsvg, no
Pillow. The only option is macOS `qlmanage`, which **flattens transparency onto
white**. Feeding that straight in would make the Android adaptive foreground an
opaque white square.

Rendering the same art twice, on white and on black, makes alpha solvable:

```
Cw = C*a + 255*(1-a)      (composite on white)
Cb = C*a                  (composite on black)
  => a = 1 - (Cw - Cb)/255
  => C = Cb / a
```

That is exact, including anti-aliased edges — unlike a chroma-key, which leaves
coloured fringes. `unmatte.py` implements it with a pure-stdlib PNG
decoder/encoder, so there's nothing to install.

## Regenerating

```sh
cd assets/icon/src
qlmanage -t -s 1024 -o . icon.svg icon_background.svg icon_foreground_white.svg icon_foreground_black.svg
python3 unmatte.py icon_foreground_white.svg.png icon_foreground_black.svg.png ../icon_foreground.png
mv icon.svg.png ../icon.png
mv icon_background.svg.png ../icon_background.png
rm -f *.svg.png
cd ../../.. && dart run flutter_launcher_icons
```

## Gotchas

- **Don't pre-scale the foreground artwork.** `flutter_launcher_icons` already
  applies a 16% inset in `ic_launcher.xml`. Scaling the SVG *as well* compounds
  the two and the icon renders about 55% of the visible circle — noticeably
  shrunken. The foreground SVG deliberately uses the same coordinates as the
  master.
- **iOS rejects icons with an alpha channel.** The renderer always emits RGBA,
  so `remove_alpha_ios: true` in `pubspec.yaml` strips it. Verify with
  `sips --getProperty hasAlpha` on the generated 1024 icon.
- The master must stay a **full-bleed square** with no rounded corners — both
  platforms apply their own mask, and baked-in corners show up as corners
  *inside* the mask.
