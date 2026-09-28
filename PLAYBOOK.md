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

## Day 2 — Mon 8 Sep — Interaction craft ✅

Shipped: all five bullets. Found: the table had been ~232pt wide since Day 0 (the stack shrank to the one-line season sentence); fixed, so the plates are ~60% larger and two columns stay (ADR-009). The simulator cannot be tapped from this session's tooling, so `scripts/run.sh --drive` choreographs the presses for the clip. See `docs/LOG.md`.

- Card → detail with `navigationTransition(.zoom)` and `matchedTransitionSource`. The stub lifts off the table and sits up straight as it grows. (From Day 1: the plates are now the cropped ticket at about 2.3:1 and sit small in a half-width column; judge whether the table wants one wider column for landscape stubs once the zoom exists.)
- Press physics: tilt to 0° and 1.02 scale on touch-down (already there), tune `Motion.stamp` so it overshoots once and settles. Reduce Motion path: no rotation, no overshoot.
- Detail: hold to lift the silkscreen (already there) — add the misregistered plate sliding back into register while held. Haptic on register.
- Empty drawer: the blank stub should breathe once on appear (a single spring, not a loop).
- Record a 10-second clip with `xcrun simctl io <sim> recordVideo docs/screenshots/day-2-press.mov` for the write-up.

## Day 3 — Tue 9 Sep — Foundation Models, properly ✅

Shipped: all four bullets. Found: the on-device model answered for the first time (the host's assets arrived), so the eval table has three columns. Cold, the model is a worse reader than the regex: it writes UTC for a wall-clock ticket, guesses USD for a `$`, and shortens venues. Given the heuristic's draft as a hint it matches the floor on every field (one run earlier it dropped a title, so the table is a sample). The reader now runs the model with the hint and streams the answer into the import fields (ADR-010). See `docs/LOG.md` and `docs/evals.md`.

- Streaming: `session.streamResponse(to:generating:)` into the import fields so the title lands before the seat. Snapshot API drift is likely; compile and adapt.
- Give the model the heuristic draft as a hint in the prompt and measure whether it helps.
- Eval harness: `fixtures/expected.json` with the truth for each fixture; a test target that runs Vision + heuristic (+ model when available) and writes `docs/evals.md` as a table: field, heuristic hit rate, model hit rate, latency. Evidence over assertion.
- Add four harder fixtures (rotated, low contrast, receipt-style thermal print, a European ticket with `€` and `dd.mm.yyyy`).

## Day 4 — Wed 10 Sep — The season line ✅

Shipped: all three bullets. Found: the model keeps the rules about half the time cold (three of its first four sentences for the seeded drawer ran past twenty words), so the rules are checked in code and a refusal earns one retry with the reason; the hand-counted sentence is the floor (ADR-011). The probe's 12 s window was hit twice and is now 20 s. See `docs/LOG.md`.

- The one italic sentence gets written by the on-device model: `@Generable struct Season { sentence: String }` from a compact summary of the drawer (counts, cinemas, weekdays, months, price total). Rules in the instructions: under 20 words, no exclamation marks, no emoji, numbers spelled out, dry. Fall back to the hand-counted sentence.
- A Season sheet: the numbers in Fragment Mono (films, cinemas, most-visited, busiest month, total paid), the sentence in Newsreader italic, nothing else.
- Cache the sentence per drawer-hash so it is only regenerated when the drawer changes.

## Day 5 — Thu 11 Sep — Reach: intents and a widget ✅

Shipped: all four bullets, the Day 4 carry-over first. Found: the App Group is honoured by the simulator, so the placed widget reads the app's drawer there (the gallery preview renders wider than the real widget and is not a proof); the Shortcuts app lists both phrases but cannot run them on an unsigned simulator build (`linkd` rejects the client without a team ID), so the intents are a device test. See `docs/LOG.md` and ADR-012.

- (From Day 4) Before the widget: when the model's seat has no row and the hint's has, keep the hint's; title-case the model's title and cinema as the heuristic does. Both in `ModelParser.draft` so the eval table sees them. The widget shows the last stub's seat, and "PLACE 12" on a lock screen is the wrong first impression.

- App Intents: `LogStubIntent` (opens the app straight into import), `FilmsThisYearIntent` (returns the count, speakable). `AppShortcutsProvider` phrases: "Log a stub in Stub", "How many films this year in Stub".
- WidgetKit extension (`StubWidget` target in project.yml): lock-screen and small home-screen widget showing the last stub's title, date and seat on parchment. Shared model container via an App Group.
- Verify in the simulator: `xcrun simctl` can't add widgets, so screenshot the Shortcuts app entries and the widget gallery preview instead.

## Day 6 — Fri 12 Sep — Camera, icon, access ✅

Shipped (on 13 Sep; the 12 Sep slot did not fire): all three bullets. The camera path is wired and gated but unproved without a device; the icon is generated; the accessibility pass added ADR-013 (one column at the accessibility sizes). See `docs/LOG.md`.


- Device-only path: VisionKit `DataScannerViewController` for live text on a physical stub, gated by `DataScannerViewController.isSupported && isAvailable`; the simulator keeps the Photos path. Wire it so the recognised lines feed the same `StubReader` pipeline. (From Day 5: a stub filed through the table's `stubs` query reloads the widget from the season task; anything that writes to the store without going through the table must call `Reach.refreshWidgets()` itself, ADR-012.)
- App icon generated by script (`scripts/make-icon.swift`): parchment, one orange misregistered stub silhouette, nothing else. Add `Assets.xcassets`.
- Accessibility pass: VoiceOver labels on every card and field, Dynamic Type at XXL without truncating titles, 44pt targets, Reduce Motion honoured everywhere.

## Day 7 — Sat 13 Sep — The write-up ✅

Shipped: all four bullets. README, `docs/post.md`, `docs/device.md`, tag `v0.1.0`. See `docs/LOG.md`.


- README rewritten with the Day 0 → Day 7 screenshots, the evals table, the failure that was found on Day 0 and how it resolved.
- `docs/post.md`: a draft post on three things — guided generation with `@Generable`, `RecognizeDocumentsRequest` vs `RecognizeTextRequest` on stubs, and Metal `[[stitchable]]` shaders carrying a visual identity in SwiftUI. Evidence-first, screenshots inline, no hype.
- Device build notes: what Bruno has to do to run it on his phone (signing team in project.yml, Apple Intelligence on). (From Day 5: the App Shortcuts only run on a signed build, and the lock-screen widget families are unproved in the simulator; both are on the device list.)
- Tag `v0.1.0`.

## After Day 7

The launchd agent keeps firing; the skill exits cleanly with "playbook complete" until this file grows. Add Day 8+ entries here to keep going.

## Day 21 — Sun 27 Sep — Editions ✅

Every stub comes back as two things: the stub as scanned, and an edition designed for its film's release (ADR-015, DESIGN.md › Editions). Written on a container without a Swift toolchain, so the first Mac slot after this one builds it before anything else (the rule at the top of this file).

- The release key and the genome: a title folded to the name its editions share, hashed, and a seeded generator that picks the floor edition and every composition choice. Tests pin the floor for three titles.
- Eight movements drawn in SwiftUI (swiss, constructivist, deco, cutout, riso, letterpress, blueprint, noir), twelve palettes, four stocks. A perforated strip with the stub's own facts and a punched perforation; an Aztec code on the back.
- Metal: `relief` (the ink pressed into the stock), `foil` (metal and holographic film), `stock` (the paper's surface), all lit from one light.
- The on-device model art-directs each release from the closed vocabulary through `@Guide(.anyOf(…))`, judged on the way out and cached per release. The hash is the floor.
- The keepsake in the detail: the edition in front, tilting with the phone (Core Motion) or a finger, the stock under the finger (Core Haptics), a tap turns it over to the stub as scanned.
- The print run after Keep: plate by plate, the foil last, a haptic per pass.
- Proof, next Mac slot: `scripts/run.sh --seed --reset --edition --tilt 0.35,-0.25 --wait-for "written|hand-counted" --shot docs/screenshots/day-21-edition.png`, and the same with `--turned`.


## The press — Days 22 to 30

`docs/briefs/the-press.md` is the brief: a place where the person who kept a stub pulls their own proof of its edition. You choose between drawings; you never move a mark. Read it after DESIGN, DECISIONS and the Day 21 log. Each day ends with the ritual at the top; new `run.sh` flags go through `DebugDrive` (ADR-009). Nothing from Day 23 on starts until Day 22 is green.

## Day 22 — Mon 28 Sep — Day 21, built ✅

Shipped: both bullets. It compiled first time with one deprecation (`sampling` → `samplingMode`); 71 tests pass. The model is back on the iOS 27 simulator but lost every edition to its patience, most likely to the season sentence asking at the same moment. See `docs/LOG.md`.

- `scripts/build.sh`, fix every compile error in the editions, then `scripts/test.sh` green. Log what the compiler found.
- Day 21's proof shots: `scripts/run.sh --seed --reset --edition --tilt 0.35,-0.25 --wait-for "Edition '" --shot docs/screenshots/day-21-edition.png` (with `STUB_AFTER=4` so the press has run), and the same with `--turned`.

## Day 23 — Tue 29 Sep — Parts, takes and the proof ✅

Shipped (on 28 Sep, straight after Day 22): all five bullets. Frames only where something hangs (swiss, constructivist, deco, blueprint); a proof is 122 bytes; 79 tests. See `docs/LOG.md` and ADR-016.

Data only, no new UI (brief §4).

- Parts and per-part dice in all eight movements: each movement declares its parts (at most one frame; pieces read only their own die and the frame's outputs), every poster `Mark` carries its `Part.ID`, strip marks carry none. `dice(_ part:, take:)` is the one way a part gets its die; take 0 is the part's own die, take n is `fork("take n")`.
- `Genome.version = 2`; `Genome.floor` unchanged. `edition.js` in lockstep, the specimen regenerated, v1 and v2 specimen screenshots committed side by side.
- `Proof`, `ProofCache` (one JSON dictionary in `UserDefaults`, keyed by release), `Director.you`, `Edition.applying(_:)` behind `Editions.edition(for:)`. "What the press keeps" in the detail: the proof's JSON and its size in bytes.
- Tests 1, 2, 4, 5, 6, 7 from the brief (§9). ADR-016 and DESIGN.md › *The press*.
- Flag: `--proof "disc=14,bars=3"`. Proof: the edition shot at take 0, and with the proof.

## Day 24 — Wed 30 Sep — The press room, isolation, the wheel ✅

Shipped (on 28 Sep, straight after Day 23): both bullets. The halftone cross-fades between cached screens; the feel is a device test. See `docs/LOG.md`.

- Hold the keepsake to take it to the press; the room (the bed, the bench, the italic line), ghosting the parts you are not holding, the wheel and its detents, in-betweens (`Composition.between`), the rotor and the adjustable wheel (brief §5.1–5.3).
- Test 3. Flags: `--press`, `--part constructivist/disc`, `--take 14`, `--scrub 13.5`. Proof: shots at 13, 13.5 and 14, and `docs/screenshots/day-24-press.mov`.

## Day 25 — Thu 1 Oct — Separations

- The pinch, per-sheet projection, unprojected hit-testing, the flat Reduce Motion row (brief §5.4). Flag: `--separated 0.8`. Proof: the shot, and a clip of the card coming apart and pressing back together.

## Day 26 — Fri 2 Oct — The fan, draw-downs and the swatch book

- `FanLayout`, the flood shader, hold-to-feel, the fast print run (brief §5.5–5.6). Flags: `--bench movement|inks|stock`, `--flood 0.4`. Proof: one shot per bench, and the flood held at 0.4.

## Day 27 — Sat 3 Oct — The lever, wet ink and the back

- Lever and platen, the `wet` uniform, `UndoManager`, the signature, A/P and takes in pencil, the colophon and the detail's line (brief §5.7–5.9). Flags: `--pulled`, `--wet 0.6`. Proof: the wet shot, and the back signed (a fixture signature drawn by `DebugSeed`).

## Day 28 — Sun 4 Oct — The punch and patina

- Remarques punched through both faces for second and later viewings; patina from `screenedAt` and the seed (brief §6.1–6.2). Tests 8 and 9. Flags: `--viewings 3`, `--age 6`.
- A ninth fixture in `scripts/make-fixtures.swift`, a second Dune Part Two ticket ("DUNE PART TWO IMAX", a later date, another seat), with its truth in `fixtures/expected.json`.

## Day 29 — Mon 5 Oct — The room's light

- ADR-017. The card on a real table through the camera (RealityKit), gated on `ARWorldTrackingConfiguration.isSupported`. The entity builds in the simulator; placing it is a device test (`docs/device.md` §3).

## Day 30 — Tue 6 Oct — The moving share, and the write-up

- Confirm `ImageRenderer` draws the edition's shaders first. A three-second clip of the card turning in the light in the `ShareLink`.
- `README.md` (the press row, the day table), `docs/device.md` §3 (the press in the hand), and a draft `docs/post-press.md` on one subject: re-rolling a part without moving the rest, from `Dice.fork` to the wheel.
