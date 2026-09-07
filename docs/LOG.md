# Build log

Newest at the top. One entry per slot. What shipped, what broke, what the reader did.

## 2026-09-07 — Day 1

**Shipped.** The look is drawn by Metal: `paper`, `silkscreen` and `misregister` from `Shaders/Silkscreen.metal` are the default, the Day 0 SwiftUI versions stay behind `LookEngine` (`scripts/run.sh --look swiftui`), and the pair of screenshots is in `docs/screenshots/day-1-look-metal.png` and `day-1-look-swiftui.png`. The reader crops: `StubCrop` finds the ticket's corners and Core Image straightens them, so the card plate is the ticket rather than the table, and the card takes the ticket's own shape. `ModelProbe` asks the model for one token at launch and the import screen's status line reads from that. Parser edge cases: "Row H Seat 12", "12,50 €", ISO currency codes, `dd.MM.yyyy`, dates without a year. Nineteen tests.

**Reader.** Four fixtures, all cropped 2400×1400 → 1963×842 **by rectangles**, all read from the crop (Vision 10–13 lines each), all filed by heuristics at 100%: The Brutalist / H12, Perfect Days / F7, Dune Part Two / D4, Past Lives / K9. Vision's document segmentation returns the same full-width bottom-quarter strip for every fixture at 0.83–0.99 confidence on this simulator; on the Mac the same request finds the ticket exactly. The strip is rejected ("hugs 3 frame edges") and `DetectRectanglesRequest`, which is arithmetic rather than a downloaded model, finds every ticket at 1.0 (ADR-007). The model probe failed in 1 s: `GenerationError -1 ← ModelManagerError 1026 ← UnifiedAssetFramework 5000 "no underlying assets for com.apple.modelcatalog"`. The status line now says "On-device model answered with an error; reading with heuristics" and the reader does not bother the model until a probe succeeds.

**Broke and fixed.** The floor was down when the slot started: three CodeSign failures with "resource fork, Finder information, or similar detritus not allowed". `~/Documents` is an iCloud file-provider domain and the provider stamps every `.app` package under it with `FinderInfo`, faster than a script can strip it and even inside a `.nosync` folder. Derived data now lives in `~/Library/Developer/Xcode/DerivedData/Stub-scripts` (ADR-008). The trailing-euro price regex had `\b` after `€`, which never matches at the end of a line. `Logger` will not interpolate an optional `String`. The first crop test failed honestly: the crop was a 2424×353 strip with no text in it, which is how the segmentation problem was found.

**For Bruno.** The model catalog on this Mac has no assets (`UnifiedAssetFramework 5000`): System Settings → Apple Intelligence & Siri, turn it on, let the download finish, then the probe will pass. The same host problem likely explains segmentation; on a device with the assets it should be the first detector that wins, and the seed log will say `[cropped by segmentation]`.

**Still rough.** The card plates are small at 2.3:1 in a half-width column; Day 2's zoom transition will decide whether that is right or the table needs one wider column for landscape stubs. `misregister` is applied only to `DisplayTitle`; the italic sentence and card titles are single-pass, as designed, but the Metal and SwiftUI plates differ slightly in grain scale (Metal is per-pixel, SwiftUI is a tiled plate). Nothing tests the Metal shaders themselves.

## 2026-09-06 — Day 0

**Shipped.** The whole skeleton: model, reader, two parsers, look, table, import, detail, seed path, fixtures, scripts, playbook, ADRs. Linear project created. Repo pushed.

**Reader.** Vision read 9–10 lines per fixture. Foundation Models reported `.available` and then failed all four calls with `GenerationError -1` wrapping `ModelManagerServices.ModelManagerError 1026`. Heuristics filed all four at 100% confidence: The Brutalist / Embassy Theatre / H12; Perfect Days / Lighthouse Cinema Cuba / F7; Dune Part Two / The Roxy Cinema / D4; Past Lives / Penthouse Cinema / K9.

**Broke and fixed.** Fonts with `[wght]` in the filename did not register from `UIAppFonts` (renamed). The misregistered plate rendered grey because the inner `foregroundStyle` won (now `DisplayTitle` draws both passes explicitly). Two-column table overflowed the screen because `scaledToFill` images had no width constraint (now `Color.clear.overlay`). Metal toolchain catalog fetch failed twice before succeeding.

**For Bruno.** Check System Settings → Apple Intelligence & Siri is on and the model has finished downloading; error 1026 from ModelManager on the simulator is usually the host's model assets. Once the model answers, the seed log will show `by foundation-models`.

**Still rough.** Cards show the table around the stub (crop is Day 1). Import screen says "On-device model ready" when it is not (Day 1). Metal shaders compiled but not active (Day 1).
