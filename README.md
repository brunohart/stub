# Stub

**A private archive of every film you saw in a room with strangers.**

Photograph the ticket stub, or share in the Wallet pass, the PDF or the screenshot the cinema sent. The phone reads it, files it, and gives you two things back: the stub as it was, and an **edition**, a ticket designed for that film's release, printed with your own seat and night, lit by the phone and felt under your finger. Then you can take the edition to the **press** and pull your own proof of it, put it on a real table, and send it turning in the light. Nothing reaches anyone but you: the drawer lives on the phone and, unless you say otherwise, in your own private iCloud.

Native Swift and SwiftUI, Metal, Vision, Foundation Models, Core Haptics, RealityKit, CloudKit. iOS 26, built and proved daily in the iOS 27 simulator.

<p>
<img src="docs/screenshots/2026-10-13-home.png" width="24%" alt="The drawer under its brass label, 2024 to 2026: stubs tipped onto a table, and two stamps at the bottom, The season and Keep a stub">
<img src="docs/screenshots/2026-10-13-detail.png" width="24%" alt="An edition: La Chimera, constructivist, chosen by the on-device model, with The press and Share under it">
<img src="docs/screenshots/2026-10-13-press-marks.png" width="24%" alt="The press: Dune Part Two with registration marks round every part that turns, and the line: tap a part of the poster, then turn the dial">
<img src="docs/screenshots/day-25-separated.png" width="24%" alt="Separations: the card taken apart into five sheets of film">
</p>

<sub>The drawer under its label · an edition · the press, every part that turns marked · the card taken apart into its plates</sub>

---

## Three objects

### The drawer

Stubs are tipped onto a table rather than filed in a grid: two uneven columns, 1.15 to 0.85, overlapping by six points. Every stub keeps the tilt it was given when it was filed, between −1.5° and 1.5° and never level, and sits up straight when touched. The photograph is silkscreened onto parchment, with the orange plate a few points out of register. Hold a stub and the print washes off to show the photograph underneath.

Vision reads the stub on the device. A rule-based parser reads it first, always. The on-device model then reads it with that draft in hand, and is scored against it. Every stub says who read it and how sure it was.

### The edition

Every release gets one design, and every stub of that release prints its own copy: the seat, the date, the cinema, and whether it was the first viewing or the third. The design comes from a closed vocabulary: eight movements, twelve palettes and four stocks. The on-device model chooses between those words; it never chooses a colour, a position or a letter. The release's hash draws everything under them, so there is always an edition, on any phone, before the model answers or if it never does.

<p><img src="docs/editions/specimen-movements-v2.png" width="100%" alt="The eight movements: swiss, constructivist, deco, cutout, riso, letterpress, blueprint, noir"></p>

<sub>All eight movements, drawn in a browser by <a href="docs/editions/edition.js"><code>edition.js</code></a>, which rolls the same dice in the same order as the Swift. It is a design tool and a specimen; the proof is the simulator.</sub>

The card is lit by one light, and it is the phone's. Tilt the phone and the light moves across the ink pressed into the stock, the foil, and the stock's own fibre and sheen: three Metal shaders sharing one light vector. Drag a finger across the card and you feel the stock: cotton drags, foil is slick, and the perforation clicks once. Turn it over and the stub you were handed is on the back, in four photo corners, above an Aztec code that encodes exactly what the strip prints.

### The press

The press gives you the power the model has, and one more. Touch any part of the poster and the rest knocks back to a ghost. Turn the wheel and that part redraws, take after take, while everything else holds still. **You choose between drawings. You never move a mark.**

<p>
<img src="docs/screenshots/day-24-take-13.png" width="32%" alt="The disc at take 13">
<img src="docs/screenshots/day-24-take-13.5.png" width="32%" alt="Halfway between take 13 and take 14: the disc in between">
<img src="docs/screenshots/day-24-take-14.png" width="32%" alt="The disc at take 14">
</p>

<sub>Take 13, the in-between, take 14. The wheel doesn't cut from one drawing to the next; it draws the space between them, the way an animator draws in-betweens. Only the part you're holding moves. <a href="docs/screenshots/day-24-press.mov">Watch the wheel turn</a>.</sub>

This works because every part of the poster rolls from a die of its own (`Dice.fork`), so a part can be redrawn without moving any other. A test holds all eight movements to that rule, across twenty takes of every part. Pinch the card and it comes apart into the layers it was printed in, so a part buried under another can be reached on its own sheet ([film](docs/screenshots/day-25-separations.mov)).

What the press keeps isn't an image. It's the difference between your card and the title's:

```json
{"pulledAt":"2026-09-27T23:48:29Z","release":"la chimera","takes":{"blueprint/circle":7,"blueprint/radius":3},"version":2}
```

That is 122 bytes, and it prints the same card on every phone. Going back is deleting it. The long version is [`docs/post-press.md`](docs/post-press.md): re-rolling one part of a poster without moving the rest, from `Dice.fork` to the wheel.

### The card keeps its history

A second viewing of a release punches the strip, the way a conductor punches a ticket, in the movement's own die: noir's is a crescent, riso's is two discs out of register, deco's a stepped diamond. The punch goes through both faces and lands clear of every word and of the code on the back. The card also ages from the night it was seen. The stock warms, a spot of foxing comes up every eighteen months or so, and the corners fray. It's the same on every phone and changes only as the calendar does.

Put it on the table and the card sits on a real surface through the camera, at its real size, 64 by 102 millimetres and four tenths thick, cut with its perforation and punches. There, and only there, the light is the room's. Share it and you get the still or three seconds of the card turning while the light crosses the foil.

<p>
<img src="docs/screenshots/day-28-viewings-3.png" width="32%" alt="The Brutalist as a third viewing: two crescent punches through a noir strip">
<img src="docs/screenshots/day-28-age-6-back.png" width="32%" alt="The back of a six-year-old card: warmer stock, four spots of foxing, rubbed corners">
<img src="docs/screenshots/day-29-room.png" width="32%" alt="The second Dune lying on a stand-in table in RealityKit, the holographic disc catching the light">
</p>

<sub>A third viewing, punched twice · six years in the drawer · on a table, lit by the room (the simulator's stand-in). <a href="docs/screenshots/day-30-clip.mp4">The moving share</a>.</sub>

---

### Ways in, and ways out

A ticket that never had paper comes in through the share sheet: a **Wallet pass** is read from its own fields (the film, the cinema, the time, the seat, as the pass states them; no camera, no model), a **PDF e-ticket** from its own text, a **screenshot** as a photograph. A booking confirmation can carry an **Add to Stub** link ([the spec](docs/add-to-stub.md)) that opens the import sheet prefilled; nothing is filed until you keep it, and nothing is fetched to open it. The drawer **outlives the phone** in your private iCloud, the press's proofs and your signature with it, and every stub knows its venue and its circuit.

Every share says **shared in Stub**, pressed into the parchment under the card like a paper mill's watermark. The moving share is 9:16, so a Story shows all of it.

<p>
<img src="docs/screenshots/2026-10-13-share-extension.png" width="49%" alt="Sharing a screenshot from Photos into Stub, and the import sheet with every field read">
<img src="docs/screenshots/2026-10-13-pass-and-pdf.png" width="49%" alt="A Wallet pass read from its fields, and a PDF e-ticket read from its own text">
</p>

<p><img src="docs/screenshots/2026-10-13-vertical-clip.png" width="100%" alt="The vertical clip at the start, middle and end of its turn, the Story's reserved bands marked at the top and bottom of the middle frame"></p>

## Tuned by hand

Every number here was set on purpose, and most were tuned by eye and thumb. The ones marked *device* still need a real phone to confirm the feel.

| | Value | Why |
|---|---|---|
| A stub's tilt | −1.5° to 1.5°, never 0, fixed when filed | Nothing on the table sits level |
| Press spring | response 0.34, damping 0.55 | Overshoots about a fifth once, then settles: a stamp pressed too hard |
| Reduce Motion | response 0.26, damping 1 | Critically damped, no overshoot, no tilt |
| The card's lean | up to 11° from the phone's attitude | Smoothed at 0.22 so the light follows the hand, not its tremor |
| The stock under a finger | sharpness 0.15 cotton → 0.85 holographic | Paper feels dull, metal bright *(device)* |
| The wheel | 30° a take, a detent at the stock's sharpness | The wheel feels like the paper it prints on *(device)* |
| A flick | coasts at 0.93 per 16 ms above 0.25°/ms | Then settles on the nearest take with one overshoot |
| Detents | a ratchet when they come faster than one per 28 ms | Single clicks at that speed blur into mush *(device)* |
| A ghosted part | 18% of its ink, drawn toward the stock | Only the part in hand reads |
| Separations | 52° back, −24° turned, 38 pt a sheet | A printer's view of the card's layers |
| The lever | 150 pt of travel, gives at 92%, resistance 0.1 → 0.8 | Committing is physical; there is no Save button *(device)* |
| Wet ink | dries over 2.4 s, then the timeline stops | The one thing that moves on its own, and it ends |
| A proof | about 120 bytes | A few numbers laid over an edition, not a picture of one |
| A punch | 16 pt across, 3 pt clear of any word | Smaller and a cut shape reads as a printed glyph |
| Patina | warmth 0.42 (1 − e^(−years/4.5)), foxing from the first year, one spot every eighteen months, seven at most | Quick at first, then hardly at all; rare |
| The card on a table | 64 × 102.4 × 0.4 mm, maps at 2.5 px a point | A playing card's size; cut in 0.8 s in a Debug build *(device)* |
| The moving share | 3 s at 60 fps, tilt −0.35 → 0.35, HEVC, 1080 × 1920 | The card and its watermark clear of a Story's 250-pixel bands; about 1 MB, drawn in 11.5 s in a Debug build, when a destination asks for it |
| The watermark | "shared in Stub", 15 pt, blind-embossed: a shade of the paper, lit and shaded along its edges by the share's own light | Read by its relief, never ink on the card, always there |
| A stamp | the ink 3 pt out of register with its plate; down in 0.1 s, back with a bounce of 0.45, lifted 2.4 pt and tipped 0.9° | Pressing a button prints a pass; felt at contact and again, softer, at the lift *(device)* |
| The deal | 55 ms a card, from 26 pt up and 4.5° further turned, spring 0.5 / 0.62 | Cards put down on a table one by one, never faded in |
| The drawer label | brass, its sheen 110 pt across a full tilt | The home's name for itself: the years, the stubs, the cinemas |
| The App Store preview | 25 s, 886 × 1920 and 750 × 1334, 30 fps | Filmed from the app and cut, never sped up (`scripts/preview.sh`) |

## How it's built

| | Apple technology | In Stub |
|---|---|---|
| **Read** | Vision `RecognizeDocumentsRequest`, `RecognizeTextRequest` | The printed lines, in reading order |
| **Crop** | `DetectDocumentSegmentationRequest`, `DetectRectanglesRequest`, Core Image | The card is the ticket, not the table it lay on. Two detectors, because one lies in the simulator ([ADR-007](DECISIONS.md#adr-007--two-detectors-for-the-crop-and-a-quadrilateral-that-hugs-the-frame-is-not-a-ticket)) |
| **Understand** | Foundation Models: `@Generable`, streamed snapshots | The model reads with the rules' draft as a hint; the rules are the floor ([ADR-001](DECISIONS.md#adr-001--the-heuristic-parser-is-the-floor-the-model-is-measured-against-it), [ADR-010](DECISIONS.md#adr-010--the-model-reads-with-the-heuristics-draft-in-hand-and-is-scored-in-the-drawers-shapes)) |
| **Say** | Foundation Models | One dry sentence about the drawer: the numbers are counted by hand, only the phrasing is the model's, and the sentence is judged on the way out ([ADR-011](DECISIONS.md#adr-011--the-season-is-counted-by-hand-and-only-phrased-by-the-model)) |
| **Look** | Metal `[[stitchable]]` shaders in SwiftUI | Silkscreen and misregistration on flat parchment, specified at the modifier boundary so Metal is an implementation, not the identity ([ADR-002](DECISIONS.md#adr-002--the-look-is-specified-in-swiftui-first-metal-is-an-implementation-not-the-identity)) |
| **Print** | `@Guide(.anyOf(…))`, Metal, Core Motion, Core Haptics | The model art-directs from a closed vocabulary; the hash draws; one light ([ADR-015](DECISIONS.md#adr-015--every-release-gets-an-edition-the-hash-draws-it-the-model-art-directs-it-from-a-closed-vocabulary)) |
| **Press** | SwiftUI `Canvas`, `projectionEffect`, Core Haptics | Parts, takes, in-betweens, separations; a proof is a diff ([ADR-016](DECISIONS.md#adr-016--the-press-a-proof-is-a-diff-over-the-edition-and-every-part-has-its-own-die)) |
| **Place** | RealityKit, ARKit, a RealityKit surface shader | The card on a real table, lit by the room; holographic film from the real view direction ([ADR-018](DECISIONS.md#adr-018--the-rooms-light-on-a-real-table-the-card-is-lit-by-the-room)) |
| **Share** | `ImageRenderer`, AVFoundation | The still, and three seconds of the card turning in the light, drawn frame by frame through the same shaders |
| **Keep** | SwiftData (versioned), an App Group, a CloudKit private database | On the device and in your own iCloud; no account of ours, no server ([ADR-005](DECISIONS.md#adr-005--private-by-construction), [ADR-012](DECISIONS.md#adr-012--one-drawer-in-an-app-group-the-app-writes-it-the-widget-reads-it-an-intent-runs-inside-the-app), [ADR-024](DECISIONS.md)) |
| **Take in** | A share extension, the Wallet pass format, PDFKit | Passes read from their fields, PDFs from their text, screenshots as photographs; left in an inbox for the app, the drawer's one writer ([ADR-023](DECISIONS.md)) |
| **Reach** | App Intents, universal links, WidgetKit, AVFoundation | "Log a stub in Stub"; Add to Stub links and the Keep a ticket action ([ADR-021](DECISIONS.md)); the drawer's editions on the home screen, dealt and turned in place ([ADR-027](DECISIONS.md)); a viewfinder whose marks lock onto the ticket ([ADR-025](DECISIONS.md)) |
| **Access** | VoiceOver, Dynamic Type, Reduce Motion | Every card says what it knows; one column at the accessibility sizes; a rotor for the parts of a poster; the wheel is one adjustable control ([ADR-013](DECISIONS.md#adr-013--the-table-is-two-columns-until-the-type-gets-large-at-the-accessibility-sizes-it-is-one)) |

---

## Built in the open

One day at a time, each day proved by a screenshot of the real app running in the simulator. The plan is in [`PLAYBOOK.md`](PLAYBOOK.md), the decisions in [`DECISIONS.md`](DECISIONS.md), the rules for the look in [`DESIGN.md`](DESIGN.md), and what actually happened each day, failures included, in [`docs/LOG.md`](docs/LOG.md).

| Day | Shipped | Proof |
|---|---|---|
| 0 | The skeleton: the model, the reader, two parsers, the look, the table, the seed path | <img src="docs/screenshots/day-0-table.png" width="96"> |
| 1 | The look moves to Metal; the reader crops the ticket out of the photograph | <img src="docs/screenshots/day-1-look-metal.png" width="96"> |
| 2 | The zoom transition, press physics, hold to lift the silkscreen | <img src="docs/screenshots/day-2-detail-held.png" width="96"> |
| 3 | The model streams, reads with a hint, and is scored; the eval harness | <img src="docs/screenshots/day-3-evals.png" width="96"> |
| 4 | The season sentence, counted by hand and phrased by the model | <img src="docs/screenshots/day-4-season.png" width="96"> |
| 5 | App Intents, the widget, the drawer in an App Group | <img src="docs/screenshots/day-5-widget.png" width="96"> |
| 6 | The camera path, the icon, the accessibility pass | <img src="docs/screenshots/day-6-type-ax.png" width="96"> |
| 7 | The write-up, [`docs/post.md`](docs/post.md), `v0.1.0` | <img src="docs/screenshots/day-7-table.png" width="96"> |
| 21 | Editions: eight movements, three shaders, the art director, the card in the hand | <img src="docs/screenshots/day-21-edition-turned.png" width="96"> |
| 22 | Day 21 built: 2,600 lines written without a compiler, with one warning between them | <img src="docs/screenshots/day-21-edition.png" width="96"> |
| 23 | Parts, takes and the proof ([the brief](docs/briefs/the-press.md)) | <img src="docs/screenshots/day-23-keeps.png" width="96"> |
| 24 | The press room, the wheel, the in-betweens | <img src="docs/screenshots/day-24-take-14.png" width="96"> |
| 25 | Separations | <img src="docs/screenshots/day-25-separated.png" width="96"> |
| 26 | The fan of movements, the draw-downs that flood the card, the swatch book | <img src="docs/screenshots/day-26-flood.png" width="96"> |
| 27 | The lever and the platen, wet ink, undo, and the back: signed, A/P, the takes in pencil | <img src="docs/screenshots/day-27-signed.png" width="96"> |
| 28 | The punch and patina: a remarque for every viewing after the first; the card ages from the night | <img src="docs/screenshots/day-28-viewings-3.png" width="96"> |
| 29 | The room's light: the card on a real table, lit by the room ([ADR-018](DECISIONS.md#adr-018--the-rooms-light-on-a-real-table-the-card-is-lit-by-the-room)) | <img src="docs/screenshots/day-29-room.png" width="96"> |
| 30 | The moving share, and the write-up, [`docs/post-press.md`](docs/post-press.md) | <img src="docs/screenshots/day-30-clip-frames.png" width="96"> |
| 13 Oct | Add to Stub; Wallet passes, PDFs and screenshots shared in; the drawer in iCloud, venues and circuits; the 9:16 share and its watermark; the home's label, stamps, the press's marks, the icon; the App Store preview | <img src="docs/screenshots/2026-10-13-preview-frames.png" width="96"> |

## Run it

You need Xcode 27 with an iOS 27 simulator (the app still targets iOS 26; [ADR-014](DECISIONS.md#adr-014--the-simulator-is-ios-27-the-app-still-targets-ios-26)) and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`). Turn Apple Intelligence on for the Mac to use the on-device model.

```bash
git clone https://github.com/brunohart/stub && cd stub
scripts/build.sh      # xcodegen, then a simulator build
scripts/test.sh       # the tests on an iPhone 18 Pro; the eval suite asks the model for a few minutes
scripts/eval.sh 3     # the deep eval: every question asked three times, into docs/evals-deep.md (half an hour or so)
scripts/run.sh --seed --reset --wait-for "written|hand-counted" --shot docs/screenshots/now.png
```

The simulator has no camera, no gyroscope and no hands, so `run.sh` stands in for them:

| Flag | Does |
|---|---|
| `--seed --reset` | Runs the eleven synthetic tickets in `fixtures/` (nine photographed stubs, an e-ticket PDF, a screenshot) through the real reader |
| `--edition [--open "Title"]` | Opens a stub so its edition is chosen and printed; `--turned` shows its back |
| `--tilt x,y` | Holds the light where a screenshot wants it |
| `--press --part disc --take 14` | Carries the card into the press and turns a part; `--scrub 13.5` holds an in-between |
| `--separated 0.8` | Pulls the card's layers apart |
| `--proof "disc=14,bars=3"` | Pulls a proof; `--keeps` shows what the press keeps |
| `--bench movement` · `--flood 0.4` | Opens the fan, the draw-downs or the swatch book; holds a flood part-way |
| `--pulled --wet 0.6` · `--signed` | Pulls the proof on the press and holds the ink wet; signs with a fixture signature |
| `--viewings 3` · `--age 6` | Punches the card as a third viewing; ages it six years |
| `--room` | Sets the card on a table (the simulator has no camera, so the table is a stand-in) |
| `--clip out.mp4` | Draws the moving share (9:16, watermarked) and copies it out; `--clip-card` draws the card-sized one |
| `--inbox file` | Puts a `.pkpass`, a PDF or a picture in the share extension's inbox, as a share would |
| `--preview` | Plays the App Store preview's story; `scripts/preview.sh` films it and cuts it to Apple's sizes |
| `--drive [--record out.mov]` | Plays the interactions on a clock, and films them |
| `--type accessibility-extra-large` | Sets Dynamic Type for the run |

On a phone, once the account is set up ([`docs/device.md`](docs/device.md) §1):

```bash
scripts/device.sh     # a signed Release build, installed and launched on the paired iPhone
scripts/archive.sh    # archive and export for TestFlight; --upload sends it to App Store Connect
```

## What the readers score

A test runs every fixture through the real pipeline and writes [`docs/evals.md`](docs/evals.md). The run of 13 October 2026, on the iOS 27 simulator, with eleven fixtures: nine photographed stubs, a PDF e-ticket (read from its own text) and a screenshot of a ticket in an app:

| Field | rules | model, cold | model + the rules' draft |
|---|---|---|---|
| title | 11/11 | 10/11 | 11/11 |
| cinema | 11/11 | 10/11 | 11/11 |
| date | 11/11 | 11/11 | 11/11 |
| screen | 11/11 | 11/11 | 11/11 |
| seat | 11/11 | 11/11 | 11/11 |
| price | 11/11 | 11/11 | 11/11 |

The rules take about a millisecond; the model takes seconds and its latency swings between runs on the same Mac. Given the rules' draft, it matches them on every field. It isn't the same reader twice, so the table is a sample, and the log records the runs that scored differently. A Wallet pass isn't in the table: it is read from its own fields, not by either reader. [`docs/evals-deep.md`](docs/evals-deep.md) asks every question three times: how far one pass can be trusted, how fast the streamed title arrives, how often the season sentence keeps its rules on the first try, and whether the model gives a release the same edition every time.

## Honesty

On Day 0 the on-device model said it was available and then refused every request. The rules filed every fixture anyway, and that is why they are the floor and why every stub records who read it. On Day 1, Vision's document segmentation confidently returned a strip of table for every ticket, and a plain rectangle detector became the second floor. Day 21's editions were written on a machine with no Swift compiler and judged in a browser. They compiled on the first try on Day 22, and the log says what that session did and didn't catch.

What isn't proved yet: the camera, the Siri phrases and the Keep a ticket action, the lock-screen widget, the card on a real table, an Add to Stub link tapped in Mail, a real Wallet pass shared from Wallet, two devices sharing one drawer through iCloud, and everything you feel rather than see (the gyroscope, the haptics, the stamps, the wheel's detents, the foil in moving light) need a signed build on a phone and the account behind it ([`docs/device.md`](docs/device.md)). The three passes in `fixtures/passes` are synthetic, in Apple's format; real ones, redacted, will join them. The model art-directed its first editions in the simulator on Day 28 (The Brutalist as noir, La Chimera as constructivist), but its latency swings from about two seconds to about eighteen between runs on the same Mac, so plenty of editions still fall back to the hash after twelve seconds. Each day's log ends with a "Still rough" paragraph.

## Licence

MIT for the code. The fonts are Host Grotesk, Newsreader and Fragment Mono, under the SIL Open Font License, in `Stub/Resources/Fonts`.
