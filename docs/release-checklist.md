# Store release checklists

Everything needed to publish Pack Lite, split by store. Written for this repo
specifically — the generic steps are here, but so are the gaps that are unique to
how Pack Lite is currently built.

**Store policies change.** Fees and requirements below were accurate when written
(July 2026); re-check anything surprising against the current developer console
rather than trusting this file.

## Keeping this current

Tick items off as they're genuinely finished, with the **date** and a PR or issue
reference so the trail is auditable. Also revise any item whose underlying facts have
changed, not just the boxes.

Two rules that matter more than they look:

- **Never tick something that's only partly done.** Annotate it instead — a half-true
  tick is how a launch checklist quietly stops being trustworthy.
- **A stale checklist is worse than no checklist**, because it still gets believed.

---

## Blocks both stores

These are hard blockers. Neither store will accept a build without them.

- [ ] **REL-1 · Real app icon** (issue #12). Both stores reject the Flutter
      placeholder. Needed at every Android mipmap density, plus a 512×512 PNG for
      the Play listing and a 1024×1024 PNG for App Store Connect. This is the
      single highest-value backlog item — nothing ships without it.
- [ ] **REL-2 · Privacy policy, publicly hosted.** Both stores require a URL even
      when the app collects nothing. GitHub Pages on this repo is free and
      sufficient. It must state plainly that Pack Lite stores everything on the
      device, has no account, no analytics and no ads — and should mention that
      Android's Auto Backup may copy data to the user's own Google account, since
      that is user-visible behaviour even though we never receive it.
- [ ] **REL-3 · Support URL.** The repo's Issues page is acceptable for both.
- [ ] **REL-4 · Decide the public version number.** `pubspec.yaml` is currently
      `1.0.0+5`. The `+N` build number must increase on **every** upload to either
      store, forever — see REL-5.
- [ ] **REL-5 · Automate the build number.** Still unresolved. Every CI build is
      currently `versionCode 2005`, and both stores reject re-used build numbers,
      so today each upload needs a manual bump. Deriving it from
      `github.run_number` was proposed and never decided.
- [ ] **REL-6 · Full regression pass** on real hardware — `docs/regression-tests.md`,
      at minimum every P0.
      *Partial (2026-07-27):* §17 IOS-1, IOS-4 (import only), IOS-5 and IOS-8 pass in the
      iOS simulator. Android hardware pass not yet done, and IOS-2/IOS-3 need a physical
      iPhone. Not tickable until the Android P0 sweep is run.
- [ ] **REL-7 · Screenshots** taken on real devices or simulators, per store sizes
      below. Take them *after* REL-1, or they'll show the placeholder icon.

---

## Google Play

**Cost:** $25 one-time. No renewal.

### Account

- [ ] **GP-1** Create a Google Play developer account ($25) and complete identity
      verification (government ID + address). Verification can take days — start early.
- [ ] **GP-2** Decide **personal vs organisation** account. This matters more than it
      looks: see GP-9.

### Build — the real gap

- [ ] **GP-3** **Play requires an Android App Bundle (`.aab`), not an APK.** This repo
      has never built one — CI produces `--split-per-abi` APKs and nothing anywhere
      runs `flutter build appbundle`. Needs adding:
      ```sh
      flutter build appbundle --release
      ```
      Output: `build/app/outputs/bundle/release/app-release.aab`.
- [ ] **GP-4** Decide on **Play App Signing** (effectively mandatory for new apps).
      Google holds the real signing key; `packlite-release.jks` becomes the *upload*
      key. Consequence worth understanding: the APKs users get from Play are signed by
      Google, so they will **not** install over a sideloaded build signed with our
      keystore, and vice versa. Keep the keystore backed up regardless — losing the
      upload key is recoverable via Google support, but painful.
- [ ] **GP-5** Confirm `targetSdk` meets Play's current minimum. `compileSdk` is
      pinned to 36, but `targetSdk` still tracks `flutter.targetSdkVersion` — verify
      that satisfies the requirement in force at submission.

### Listing

- [ ] **GP-6** Store listing: title, short description (80 chars), full description
      (4000), app category, contact details.
- [ ] **GP-7** Graphics: 512×512 icon, **1024×500 feature graphic**, and at least
      2 phone screenshots (min 320px, max 3840px on the long edge).
- [ ] **GP-8** Complete the **Data safety** form. Pack Lite collects and shares
      nothing, which makes this short — but answer deliberately rather than by
      reflex, and note that Auto Backup is the user's own Google backup, not
      collection by us.
- [ ] Content rating questionnaire (IARC), target audience, ads declaration (none),
      news/COVID declarations (no), government-app declaration (no).

### The slow part

- [ ] **GP-9** **Personal accounts must run a closed test with at least 12 testers,
      opted in continuously for 14 days**, before production access is granted.
      Organisation accounts are exempt. This is usually the longest pole in the whole
      process — line up testers early, and note the clock resets if the count drops.
- [ ] **GP-10** Then apply for production access, roll out (staged rollout is
      available and worth using), and wait for review — typically days for a first
      submission.

---

## iOS App Store

**Cost:** $99/year, recurring. **Apps are removed if it lapses.**

### Toolchain

- [x] **IOS-REL-0 · Local iOS toolchain.** *Done 2026-07-27.* Xcode 26.6, iOS 26.5
      simulator runtime, CocoaPods 1.17.0; `flutter doctor` green. The app builds and
      runs in the simulator, and CI builds it on every PR (#36). Prerequisite for
      IOS-REL-8.

### Account and identity

- [ ] **IOS-REL-1** Enrol in the Apple Developer Program ($99/yr). Individual
      enrolment needs ID; organisation enrolment additionally needs a D-U-N-S number
      and takes considerably longer.
- [ ] **IOS-REL-2** Register the bundle id **`com.packlite.app`** in the developer
      portal. If it's already taken by another account, the id must change — and per
      the App identity note in `CLAUDE.md` that is a decision to make *before*
      release, never after.
- [ ] **IOS-REL-3** Create the App Store Connect record: name, primary language,
      bundle id, SKU. **The app name must be globally unique** — "Pack Lite" may not
      be available, so have a fallback ready.

### Fix first

- [ ] **IOS-REL-4** **Issue #37 — Export Data silently does nothing on iOS.** Export
      is the only route data has off an iOS device (there is no `BackupSync`
      equivalent there), so shipping without it is a poor first impression and a
      plausible review question about a non-functional control.
- [ ] **IOS-REL-5** Issue #38 — the vibration helper text is Android-only copy and is
      factually wrong on iOS.
- [ ] **IOS-REL-6** Work through `docs/regression-tests.md` §17 on a **real iPhone**.
      IOS-2 (haptics) and IOS-3 (ringer switch) cannot be checked in a simulator, and
      no physical device is set up — Frank's iPhone 12 is a work phone where MDM may
      block Developer Mode, making TestFlight (IOS-REL-13) the more likely route.
      *Simulator coverage so far (2026-07-27):* IOS-1, IOS-4 import, IOS-5, IOS-8 pass;
      IOS-4 export fails (#37).

### Build and upload

- [ ] **IOS-REL-7** Set up signing: distribution certificate and App Store
      provisioning profile. Xcode's automatic signing handles this once the account
      is enrolled.
- [ ] **IOS-REL-8** Build an archive:
      ```sh
      flutter build ipa --release
      ```
      Then upload via Xcode Organizer or Transporter.
- [ ] **IOS-REL-9** Complete **App Privacy** ("nutrition labels"). As with GP-8, the
      honest answer throughout is that nothing is collected.
- [ ] **IOS-REL-10** Export compliance. Pack Lite uses no encryption beyond
      OS-standard HTTPS, so the usual answer is the exemption — declare it in
      `Info.plist` via `ITSAppUsesNonExemptEncryption` to stop being asked on every
      upload.

### Listing

- [ ] **IOS-REL-11** Screenshots for **each required display size** (at minimum
      6.7" and 6.5" iPhone; iPad sizes too if the app is offered on iPad — decide
      whether it is, since the layout has never been tested there).
- [ ] **IOS-REL-12** Description, keywords (100 chars), promotional text, support and
      marketing URLs, age rating questionnaire.
- [ ] **IOS-REL-13** TestFlight first — internal testers need no review and it's the
      only sane way to test a release build on a device. Also the answer to
      "how do I install this without a cable".
- [ ] **IOS-REL-14** Submit for **App Review**. Unlike Play, a human reviews it;
      expect a day or two, and expect occasional rejections over metadata rather than
      code.

---

## Suggested order

1. **REL-1 (icon)** — blocks everything, on both stores.
2. **Google Play account + GP-9 closed test** — the 14-day clock is the longest pole,
   and $25 with no renewal is a low-commitment start.
3. **Ship Android.** It's the platform actually tested on hardware.
4. **Fix #37**, then pay Apple's $99 — no point starting an annual renewal clock on a
   build that can't ship.
5. **TestFlight, then App Review.**
