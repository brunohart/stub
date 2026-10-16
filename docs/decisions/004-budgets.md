# 004 · Performance budgets are the definition of done

**Date** 2026-10-16 · **Status** decided; the simulator lane passes; the device lane waits for a phone (BEDIP-217)

## The decision

Stub is done when every budget below passes **on the oldest iPhone it supports**: iPhone SE (2nd generation) or
iPhone 11, both A13, which run both iOS 26 and iOS 27. They have no Apple Intelligence, so they read tickets with the
rules alone. The model path is budgeted on the iPhone 15 Pro, the oldest phone that has the model. A budget can be
tightened in any commit. Raising one takes a new entry here saying why. It is never lowered quietly.

| Budget (device lane) | Ceiling | Why |
|---|---|---|
| Cold launch to first frame | **400 ms** | WWDC19 *Optimizing App Launch*: the first frame within 400 ms, the length of the launch animation |
| Cold launch to responsive | **500 ms** | The first frame plus Apple's 100 ms for a discrete action (*Improving app responsiveness*) |
| Drawer fling (tickets, editions): hitch time ratio | **< 5 ms/s** | WWDC20 *Eliminate animation hitches with XCTest*: under 5 ms/s is good. This is the stricter of Apple's two published scales; Organizer's current page calls 10 good |
| A stub revealed: hitch time ratio | **< 5 ms/s** | Same |
| The light swept across a card: hitch time ratio | **< 5 ms/s** | Same |
| Shutter to a draft you can keep, rules (SE 2) and model (15 Pro) | **1.5 s** | Decision 001's ten seconds from pocket to kept: about 1.5 s to the viewfinder, 3 s to frame and shoot, at most 1.5 s to read, 3 s to look and keep, 1 s spare. The model never stands between the person and Keep |
| The reader's last word, model path | **10 s** | Keepable plus the reader's 8 s patience plus half a second, by construction (`StubReader.patience`) |
| Keep to saved; Keep to the press on screen | **100 ms** | Apple: 100 ms for a discrete action |
| Keep to the printed card, by the clock | **2.0 s** | The press prints pass by pass in about 1.2 s by design (ADR-015); the rest is the response |
| Tilt-light view: peak memory | **200 MB** | Apple publishes no number. 200 MB is under a seventh of what a 3 GB phone allows one app, so Stub is not the app iOS ends first in the background (WWDC18 *iOS Memory Deep Dive*) |
| Tilt-light view: CPU over a 4.3 s sweep | **1.3 s** (30% of a core) | Apple: about 5 ms of main-thread work per update for continuous interaction; at 60 updates a second that is 30% |
| Tilt-light view: energy | **recorded, not gated** | Apple gives no threshold. The gyroscope runs only while a card or a label is on screen, from one `CMMotionManager`, at 60 Hz. The Power Profiler on the phone is the record |

## How it is measured

- **Signposts** in the app (`Signposts.swift`): `Keepable`, `Understood`, `Kept`, `Pressed` (capture); `Reveal` and `Tilt`
  (animation intervals, for hitches). They ship; they cost nothing when nobody is recording.
- **`StubUITests/PerformanceTests`**, with Apple's metrics: `XCTApplicationLaunchMetric` (first frame, and responsive),
  `XCTOSSignpostMetric` (scrolling and deceleration, and the app's own intervals), `XCTHitchMetric`, `XCTMemoryMetric`,
  `XCTCPUMetric`, `XCTClockMetric`. Each test stages its own drawer (`-stage-drawer 60`, `-stage-rules`, `-stage-tilt`,
  `Stage.swift`), so a run is the same run anywhere.
- **The Performance configuration**: Release's optimiser with the staging hooks compiled in (`PERF`), never shipped, no
  debugger, no coverage. This follows Apple's advice for performance tests.
- **`perf/budgets.json` and `scripts/budgets.py`**: the ceilings, per lane, judged from the result bundle. A run fails
  if a metric is over, **or if a budgeted metric was not measured**. Xcode's own baselines are not used: they live in a
  project file this repo generates, and a reported bug ignores them for `measure(metrics:)` in Xcode 15 to 26.
- **Three lanes.** *device*: the budgets above. *simulator*: regression guards on the Stub Perf SE2 simulator on Bruno's
  Mac. *ci*: guards for GitHub's `xcode-27` image, calibrated from its first full run (2026-10-16), each the larger of
  the mean × 1.3 and the slowest run × 1.15, rounded up to two figures. That machine runs about twice this Mac's times
  (first frame 8.1 s against 4.0 s) and has no Apple Intelligence, so its model path is the rules path. One machine's
  numbers are never another's ceilings. A lane with no ceilings fails rather than passing having judged nothing.
- **The simulator records no hitches.** Neither the scroll metric nor `XCTHitchMetric` reported any on the iOS 27
  simulator (2026-10-16). So hitch budgets are device-only. The simulator lane guards per-frame work with CPU time.
- **Instruments**: Time Profiler on the simulator (`xctrace`, with `-stage-scroll` and `-stage-keep` so a recording
  needs no test runner). Hangs, Animation Hitches, Allocations, the Power Profiler and Metal System Trace need the phone.

## The fixes, in order of what a person feels

All numbers are from the SE 2 simulator on the same Mac, before and after, from `StubUITests` unless noted.

| # | What the person feels | Cause | Fix | Before | After |
|---|---|---|---|---|---|
| 1 | Waiting at the cinema door for Keep | The rules' draft was computed first but never shown. Keep waited for the model's first title | The rules' draft is offered the moment it has a title; the model improves it in place | ~8.9 s (model's streamed title, median 7.45 s, deep eval, plus Vision's 1.4 s) | see 2 |
| 2 | The same, opened straight from the Lock Screen | The model's launch probe loaded the model beside Vision | The probe waits 8 s after launch | Keepable (model path) 4.20 s | **1.50 s** |
| 3 | The same, on a phone without the model | Vision competing with the probe at launch | Same | Keepable (rules) 2.46 s | **1.54 s** |
| 4 | A reader that never finishes | A task group waited for the model's stream to wind down after its deadline | A race that stops waiting at the deadline (`Deadline.race`) | Understood 14.13 s | **9.73 s** |
| 5 | A tap on Keep that lags | The Aztec code for the card's back was made on the main thread as the press appeared, and the session's first CoreImage filter loaded CoreImage's registry | Made off the main thread; CoreImage warmed at launch; one shared context | Pressed 0.31 s (rules), 0.40 s (model) | **0.099 s, 0.071 s** |
| 6 | The same tap | The photograph was JPEG-encoded on the tap | Encoded while the person reads the draft | Kept 0.34 s | **0.03 s** |
| 7 | A slow first frame | Laying out the drawer's rows decoded all sixty photographs on the main thread to learn their shapes | Shapes read from the image header, remembered in Caches | Launch to responsive 5.29 s; app main-thread samples at launch 1,008 | **4.68 s; 594** |
| 8 | A drawer that stutters as it fills | Each card recounted the whole drawer to learn which viewing it was, and made two `DateFormatter`s | Viewings counted once per drawer change; formatters made once | Main-thread time in `Copy.init` 9.9% of the staged scroll | **0.4%** (Time Profiler) |
| 9 | Battery | One `CMMotionManager` per brass label, keepsake and press: up to five at once | One `MotionSource` for the app, stopped when nothing listens | 5 managers | **1** (energy: the phone) |

## Where it stands against the device lane

- **Every simulator guard passes** (2026-10-16, `build/budgets.md`), and again after the accessibility changes the same day.
- **Launch** on the simulator is 4.4 s to first frame, and most of it is the simulator's own dyld: 1.7 s of the 2.4 s of
  main-thread samples at launch. A phone pays a fraction of that. If the SE 2 still misses 400 ms, the trade-offs to
  propose, in order: open the store before attaching iCloud mirroring; prepare the edition shaders after the first frame;
  show the drawer's cards before their photographs are decoded. Lowering the budget is not on the list.
- **Memory** in the tilt-light view is 219 MB on the simulator, over the 200 MB device budget. If the phone agrees, the
  trade-off is to draw the drawer's edition faces from cached bitmaps rather than live shaders when they are not under a
  finger, which also lightens the scroll.
- **Hitches, energy and the model path** are measured only on a phone.

## The device lane

`scripts/perf.sh --device <udid>` runs the same suite on a plugged-in phone. In CI, the `device` job runs it on a
self-hosted runner labelled `stub-device` on Bruno's Mac, with an iPhone SE (2nd generation) or iPhone 11 on iOS 26,
Developer Mode on, paired and unlocked. Set the repository variables `DEVICE_LANE=on` and `DEVICE_UDID`. It waits on two
things only Bruno can do: accept the Program License Agreement (BEDIP-217), and have that phone.

## What was killed

- Xcode's baselines as the store of record (generated file, and the baseline bug).
- Measuring on the newest phone only.
- Hitch numbers from the simulator, which reports none.
- Numbers from a Debug build.
