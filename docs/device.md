# Running Stub on a phone

Everything in this repo was proved in the iOS 26 simulator (ADR-003). Four things cannot be proved there, and each needs one thing only Bruno can do. This page is the list.

## 1. Signing: a team in `project.yml`

The simulator build is unsigned and has no `DEVELOPMENT_TEAM`. A device build needs one, and so do the App Group and the App Shortcuts. Add the team to the base settings so both targets get it (ADR-004: edit `project.yml`, never the `.xcodeproj`):

```yaml
settings:
  base:
    SWIFT_VERSION: "6.0"
    SWIFT_STRICT_CONCURRENCY: complete
    IPHONEOS_DEPLOYMENT_TARGET: "26.0"
    CODE_SIGN_STYLE: Automatic
    DEVELOPMENT_TEAM: ABCDE12345        # your ten-character team ID
```

Then:

```bash
xcodegen generate
open Stub.xcodeproj
```

Pick the phone as the run destination and press Run. Xcode's automatic signing registers the two bundle IDs (`com.designedbybruno.stub`, `com.designedbybruno.stub.widget`) and the App Group (`group.com.designedbybruno.stub`) against the team on first build. If the group is refused because the identifier is taken on another team, change it in both `entitlements` blocks in `project.yml` and in `SharedStore.swift` (`SharedStore.group`), then regenerate.

Keep the repo where it is. Derived data goes to `~/Library/Developer/Xcode/DerivedData/Stub-scripts` because `~/Documents` is an iCloud file-provider domain that stamps every `.app` with Finder info and breaks `codesign` (ADR-008). Xcode's own derived data is fine too, since it is outside `~/Documents`.

## 2. Apple Intelligence on the phone

The on-device model needs Apple Intelligence on and its assets downloaded: Settings → Apple Intelligence & Siri. Until then `SystemLanguageModel.default.availability` reports `.unavailable(.appleIntelligenceNotEnabled)` or `.modelNotReady`, the import screen's status line says so in words, and every stub is read by the heuristic parser (ADR-001). The launch probe (`ModelProbe`) asks the model for one word and caches the answer; when it answers, the seed log and every card say `by foundation-models`.

On this Mac the probe only passed on the iOS 26.5 simulator runtime. The 26.2 runtime fails with `ModelManagerError 1026` against a macOS 26.6 host even with Apple Intelligence on. Since 2026-09-26 the scripts run on the iOS 27 runtime (ADR-014), where the probe says the model is still downloading, so the simulator proves the heuristic path and the model rows in `docs/evals.md` are the 26.5 runtime's. A phone on iOS 26 with Apple Intelligence on does not have that problem; if the probe fails there, the status line's reason is the one to read.

## 3. What to test on the phone, in order

Each of these is unproved in the simulator, for the reason given.

1. **The camera path** (Day 6). The import screen shows "Scan the stub with the camera" above the Photos button only when `DataScannerViewController.isSupported && isAvailable`; the simulator has no camera. Hold a real stub in the viewfinder, watch the guidance line count the lines, tap "Read this stub". The lines go through the same parsers as a photograph's (`StubReader.understand`); the frame captured at that moment is the plate. Things to look for: whether the live lines arrive in the printed order (the scanner's ordering is ours, top to bottom then left to right, rows grouped within 12 points), and whether the model reads them as well as it reads Vision's lines. The plate is the whole frame, not the cropped ticket; that is a known rough edge.
2. **The App Shortcuts** (Day 5). Say "How many films this year in Stub" to Siri, or run it from the Shortcuts app. The simulator lists both phrases but cannot run them: `linkd` rejects the unsigned binary ("Unable to get teamId", then "Couldn't find AppShortcutsProvider"). "Log a stub in Stub" should open the app straight onto the import sheet.
3. **The lock-screen widget** (Day 5). Add the Stub widget to the lock screen: the rectangular and inline families are unproved, only the small home-screen widget could be placed in the simulator. It should print the last stub's title, date and seat and update the moment a stub is kept or thrown away (ADR-012: the app tells it; it never polls).
4. **The icon at 60pt** (Day 6). `scripts/make-icon.swift` was judged at 1024. The notches and the perforation may be too fine on a real home screen; the script's `notch` and the dot spacing are the two numbers to move.
5. **The feel** (Day 2). The springs were tuned by arithmetic in the simulator. Press a card, hold the photograph in the detail, feel the haptic land when the plate slides into register. Reduce Motion (Settings → Accessibility → Motion) should remove the tilt and the overshoot everywhere.
6. **Streaming on a device** (Day 3). The simulator's model runs on the CPU fallback (`Cannot create MPS context`); the phone has the Neural Engine. The seed log's "Model streamed: title at … done at …" lines are the number to compare against the simulator's 3–18 s per stub.

## 4. TestFlight

Not ready, and not far. What is missing:

- **An `ExportOptions.plist` and an archive script.** `scripts/build.sh` builds for the simulator only. An `xcodebuild archive` for `generic/platform=iOS` with the team set, then `-exportArchive` with `method: app-store-connect`, is the whole of it.
- **Privacy manifest.** `PrivacyInfo.xcprivacy` declaring no tracking, no required-reason API use beyond `UserDefaults` (the season cache, reason `CA92.1`) and file timestamps. Add it to both targets' sources in `project.yml`.
- **App Store Connect record**: the bundle ID, the App Group capability, a 1024 icon (already in the asset catalog), screenshots (the `docs/screenshots` set is at simulator resolution and will do for a first internal build).
- **Version and build.** `CFBundleShortVersionString` is `0.1.0` in `project.yml` for both targets; `CFBundleVersion` is `1`. Bump the build number per upload.

Nothing in the app needs changing for review: no network, no account, no third-party SDKs, camera and photo-library usage strings are in `project.yml` (ADR-005).
