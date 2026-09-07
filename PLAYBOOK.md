# Stub — seven-day playbook

Epoch: **2026-09-06 = Day 0** (this playbook was written and Day 0 shipped that day). One slot per day at 07:00 Pacific/Auckland, run by `scripts/slot.sh` through the `stub-build` skill. Each slot reads its day here, does the work, proves it in the simulator, commits, pushes, and closes the matching Linear issue.

Every day ends the same way, no exceptions:

1. `scripts/build.sh` succeeds and `scripts/test.sh` is green.
2. `scripts/run.sh --seed --reset --shot docs/screenshots/day-N-<what>.png` produces a screenshot of the real app with real fixtures read by the real pipeline.
3. `docs/LOG.md` gets a dated entry: what shipped, what broke, what the reader did (model or heuristic, and why).
4. Commits are small and Conventional (`feat(look): …`, `fix(reader): …`, `docs: …`). Push to `origin main`.
5. The Linear issue for the day is moved to Done with a comment: commit SHAs, the screenshot path, one honest sentence about what is still rough.

If the previous day left the build broken, fixing that comes before anything below.

---

## Day 0 — Sat 6 Sep — The drawer exists ✅

Shipped: SwiftData model, Vision reader (`RecognizeDocumentsRequest` → `RecognizeTextRequest`), heuristic parser with tests, Foundation Models parser behind an availability check, SwiftUI silkscreen look, Metal shaders compiled in (not yet active), the table, import from Photos, detail view, debug seed path, fixtures, scripts, Linear project, this playbook.

Found: the on-device model reports `.available` in the simulator but every `respond` fails with `ModelManagerServices.ModelManagerError 1026`. Heuristics carried all four fixtures at 100%. See DECISIONS ADR-001 and `docs/LOG.md`.

## Day 1 — Sun 7 Sep — The look goes to Metal, and the reader crops ✅

Shipped: all four bullets. Found: Vision's document segmentation returns the same bottom-quarter strip for every photograph on this simulator; rectangles are the fallback (ADR-007). The build was down at the start of the slot because iCloud tags the `.app` (ADR-008). See `docs/LOG.md`.

- Switch `silkscreened`, `Paper`/`Grain` and the misregistered plate to the Metal shaders in `Shaders/Silkscreen.metal` (`colorEffect` / `layerEffect`). Keep the SwiftUI versions behind a `LookEngine` switch so both can be screenshotted side by side; commit the pair of screenshots to `docs/screenshots/day-1-look-swiftui.png` and `day-1-look-metal.png`. Tune `strength`, `grain`, and plate offset by eye against the taste doc: grit lives in the image, never in type.
- Crop the stub out of the photograph before reading and before showing it: Vision `DetectDocumentSegmentationRequest` → perspective-correct with Core Image (`CIPerspectiveCorrection`). The card plate should be the ticket, not the table it was lying on. Fall back to the full image when no quadrilateral is found.
- Probe the model once at launch with a one-token request and cache the outcome, so the import screen's status line is honest ("On-device model ready" is currently a lie when generation fails). Surface `ModelManagerError` codes in the log with a plain-English guess.
- Tests: crop fallback, parser edge cases (price with comma, date without year, seat like "Row H Seat 12").

## Day 2 — Mon 8 Sep — Interaction craft

- Card → detail with `navigationTransition(.zoom)` and `matchedTransitionSource`. The stub lifts off the table and sits up straight as it grows. (From Day 1: the plates are now the cropped ticket at about 2.3:1 and sit small in a half-width column; judge whether the table wants one wider column for landscape stubs once the zoom exists.)
- Press physics: tilt to 0° and 1.02 scale on touch-down (already there), tune `Motion.stamp` so it overshoots once and settles. Reduce Motion path: no rotation, no overshoot.
- Detail: hold to lift the silkscreen (already there) — add the misregistered plate sliding back into register while held. Haptic on register.
- Empty drawer: the blank stub should breathe once on appear (a single spring, not a loop).
- Record a 10-second clip with `xcrun simctl io <sim> recordVideo docs/screenshots/day-2-press.mov` for the write-up.

## Day 3 — Tue 9 Sep — Foundation Models, properly

- Streaming: `session.streamResponse(to:generating:)` into the import fields so the title lands before the seat. Snapshot API drift is likely; compile and adapt.
- Give the model the heuristic draft as a hint in the prompt and measure whether it helps.
- Eval harness: `fixtures/expected.json` with the truth for each fixture; a test target that runs Vision + heuristic (+ model when available) and writes `docs/evals.md` as a table: field, heuristic hit rate, model hit rate, latency. Evidence over assertion.
- Add four harder fixtures (rotated, low contrast, receipt-style thermal print, a European ticket with `€` and `dd.mm.yyyy`).

## Day 4 — Wed 10 Sep — The season line

- The one italic sentence gets written by the on-device model: `@Generable struct Season { sentence: String }` from a compact summary of the drawer (counts, cinemas, weekdays, months, price total). Rules in the instructions: under 20 words, no exclamation marks, no emoji, numbers spelled out, dry. Fall back to the hand-counted sentence.
- A Season sheet: the numbers in Fragment Mono (films, cinemas, most-visited, busiest month, total paid), the sentence in Newsreader italic, nothing else.
- Cache the sentence per drawer-hash so it is only regenerated when the drawer changes.

## Day 5 — Thu 11 Sep — Reach: intents and a widget

- App Intents: `LogStubIntent` (opens the app straight into import), `FilmsThisYearIntent` (returns the count, speakable). `AppShortcutsProvider` phrases: "Log a stub in Stub", "How many films this year in Stub".
- WidgetKit extension (`StubWidget` target in project.yml): lock-screen and small home-screen widget showing the last stub's title, date and seat on parchment. Shared model container via an App Group.
- Verify in the simulator: `xcrun simctl` can't add widgets, so screenshot the Shortcuts app entries and the widget gallery preview instead.

## Day 6 — Fri 12 Sep — Camera, icon, access

- Device-only path: VisionKit `DataScannerViewController` for live text on a physical stub, gated by `DataScannerViewController.isSupported && isAvailable`; the simulator keeps the Photos path. Wire it so the recognised lines feed the same `StubReader` pipeline.
- App icon generated by script (`scripts/make-icon.swift`): parchment, one orange misregistered stub silhouette, nothing else. Add `Assets.xcassets`.
- Accessibility pass: VoiceOver labels on every card and field, Dynamic Type at XXL without truncating titles, 44pt targets, Reduce Motion honoured everywhere.

## Day 7 — Sat 13 Sep — The write-up

- README rewritten with the Day 0 → Day 7 screenshots, the evals table, the failure that was found on Day 0 and how it resolved.
- `docs/post.md`: a draft post on three things — guided generation with `@Generable`, `RecognizeDocumentsRequest` vs `RecognizeTextRequest` on stubs, and Metal `[[stitchable]]` shaders carrying a visual identity in SwiftUI. Evidence-first, screenshots inline, no hype.
- Device build notes: what Bruno has to do to run it on his phone (signing team in project.yml, Apple Intelligence on).
- Tag `v0.1.0`.

## After Day 7

The launchd agent keeps firing; the skill exits cleanly with "playbook complete" until this file grows. Add Day 8+ entries here to keep going.
