# Three things I learned building a ticket-stub app on iOS 26 in seven days

*Draft. Evidence first. Everything below is in the repo: the day-by-day is [`docs/LOG.md`](LOG.md), the numbers are [`docs/evals.md`](evals.md), the decisions are [`DECISIONS.md`](../DECISIONS.md).*

Stub is a private archive of cinema ticket stubs. You photograph the stub, the phone reads it, understands it and files it, and nothing leaves the device. It was built in seven scheduled slots, one a day, 6 to 13 September 2026, each slot doing one day of a playbook written on Day 0 and proving its work with a screenshot from the simulator. Three of Apple's newer APIs carried most of the weight, and each one taught me something I did not know going in.

<p>
<img src="screenshots/day-0-table.png" width="30%" alt="Day 0: four stubs filed by the heuristic parser">
<img src="screenshots/day-4-season.png" width="30%" alt="Day 4: the season sheet, one sentence written by the on-device model">
<img src="screenshots/day-7-table.png" width="30%" alt="Day 7: eight stubs read by the on-device model">
</p>

## 1. Guided generation with `@Generable`: the model is a reader, not a parser

Foundation Models lets you hand the on-device model a Swift struct and ask for an instance of it. Stub's is seven strings:

```swift
@Generable
struct Generated: Sendable {
    @Guide(description: "The film title exactly as printed, in title case, without rating, format (2D, IMAX) or session suffixes.")
    var title: String
    @Guide(description: "The cinema or venue name. Empty string if not printed.")
    var cinema: String
    @Guide(description: "Screening date and time as ISO 8601, e.g. 2026-09-06T19:30:00. Empty string if not printed.")
    var screenedAt: String
    // screen, seat, price, currency …
}
```

The prompt is the lines Vision read off the stub, one per line. The model cannot return anything but this shape, which is the point: no JSON parsing, no retries on malformed output, and a partially generated struct streams back property by property in declaration order, so the title lands in the import screen before the seat.

**What the evidence says.** On Day 0 the model reported `.available` and failed every request with `ModelManagerError 1026`. The heuristic parser, a regular-expression reader built from ticket folklore, filed all four fixtures correctly. That is ADR-001: the heuristic is the floor, the model is measured against it. On Day 3 the model answered for the first time and the two were scored on the same eight synthetic stubs, one of them rotated 12°, one pale ink on grey paper, one a thermal receipt with an address line, one French with `RANG F PLACE 12` and `12,50 €`.

Cold, the model got 2 of 8 prices (it says USD for every `$`), 6 of 8 cinemas ("Queen St" for Event Cinemas Queen St, "Roxxy") and, before I normalised its answers, 0 of 8 dates: it wrote every one in ISO 8601 with a `Z`, twelve or thirteen hours late for a ticket that prints the time on the wall of the cinema. It also lost screens and seats it had read correctly by leaving them as printed: "SCR 2", "SEAT D 4". The first table was scored on strings, and the model looked worse than it was.

So the model is scored in the drawer's shapes: every snapshot goes through the same `normalisedScreen`, `normalisedSeat` and comma-price functions the heuristic uses, and its dates are read as wall-clock time with any zone designator dropped (ADR-010). Then the heuristic's own draft is put in the prompt as a hint, "keep what the text confirms, correct what it does not, fill what it missed". The hinted model reads 8 of 8 on every field, at the same latency as cold (median 8.6 s against 8.9 s on the simulator's CPU fallback). The hint is free and the correction is real.

| Field | heuristic | model, cold | model + hint |
|---|---|---|---|
| title | 8/8 | 8/8 | 7/8 |
| cinema | 8/8 | 6/8 | 8/8 |
| date | 8/8 | 5/8 | 8/8 |
| screen | 8/8 | 8/8 | 8/8 |
| seat | 8/8 | 7/8 | 8/8 |
| price | 8/8 | 2/8 | 8/8 |

*The Day 6 table. The one hinted miss is "Aftrsun" off the low-contrast fixture, a spelling the model has produced three days running with the correct title in front of it.*

The model is not the same reader twice. Across five daily runs the hinted title has been 8/8 and 7/8, the cold cinema 5/8, 6/8 and 7/8. The table is a sample, not a spec, and any rule loosened on its evidence has to earn it there first. That is a good discipline to be forced into.

The second use of the model is the one sentence at the top of the drawer. Everything in it is counted by hand in a millisecond (films, cinemas, busiest month, busiest weekday, total paid); the model is given only those facts, one per line, and asked through a `@Generable struct Season { var sentence: String }` for one dry sentence under twenty words, numbers spelled out (ADR-011). Whatever it writes is judged on the way out, and refused if it breaks a rule. It breaks them about half the time cold: twenty-three, twenty-four, twenty-eight words, with enthusiasm. One retry with the reason in the prompt gets an accepted sentence most days. Instructions are a hope; a check on the way out is a rule. On Day 6 it kept every rule and wrote "twice a week" for eight films over two years, a claim the brief never made, so the next rule is about frequency claims.

## 2. `RecognizeDocumentsRequest` against `RecognizeTextRequest` on a ticket

iOS 26's `RecognizeDocumentsRequest` is document-aware: it returns a `DocumentObservation` with paragraphs and a transcript in reading order, where `RecognizeTextRequest` returns boxes you sort yourself. On a stub, where the title and the seat are both shouting in capitals, the order is most of the meaning, and the heuristic parser's title rule is, roughly, "the shouted line that is not the venue and not a street address". Stub asks the document request first and falls back to the text request when it finds nothing.

**What the evidence says.** Both read 10 to 14 lines per fixture, in about 1.5 s including the crop, on all eight fixtures. The document request's order has been right every time, and the heuristic has read 8 of 8 titles, cinemas, dates, screens, seats and prices on top of it every day since Day 3. I have not needed the fallback in the simulator, and I have not measured the two against each other on a real photograph; that is the honest gap in this section.

The more interesting Vision story was the crop. Before reading, `StubCrop` finds the ticket's corners so the card on the table is the ticket and not the table it was lying on. Vision's `DetectDocumentSegmentationRequest` was asked first, and on the iOS 26 simulator it returned the same full-width bottom-quarter strip for every fixture at 0.83 to 0.99 confidence, at every input scale, through both the new and the `VN` API. On the Mac the same request found the ticket to the pixel. The classic `DetectRectanglesRequest` is arithmetic rather than a downloaded model, and it found every ticket at 1.0 within a few pixels of the Mac's segmentation. So there are two detectors, and a quadrilateral that touches three edges of the frame is rejected by geometry rather than trusted by confidence (ADR-007). It is the language-model story again: a model that reports itself confident and is not there. Twice in one week is a pattern, and the pattern is "keep a floor that does not depend on an asset".

<p>
<img src="screenshots/day-1-look-metal.png" width="30%" alt="Day 1: cropped stubs, Metal look">
<img src="screenshots/day-3-evals.png" width="30%" alt="Day 3: eight fixtures, the hard ones included">
</p>

## 3. Metal `[[stitchable]]` shaders carrying a visual identity in SwiftUI

Stub's look is a drawer of stubs tipped onto a table: every photograph is silkscreened onto parchment (desaturated a little, a breath more contrast, multiplied against the paper so it shows through, then grain), the wordmark has an orange plate a few points out of register beneath it, and the paper itself has grain. Three shaders, sixty lines of Metal, applied through SwiftUI's `colorEffect` and `layerEffect`:

```metal
[[ stitchable ]] half4 silkscreen(float2 position, half4 color, half4 paper,
                                  float strength, float grain, float seed) {
    half a = max(color.a, half(0.0001));
    half3 rgb = color.rgb / a;                       // un-premultiply
    half l = dot(rgb, half3(0.299h, 0.587h, 0.114h));
    half3 desat = mix(rgb, half3(l), half(0.18 * strength));
    half3 contrasted = (desat - 0.5h) * half(1.0 + 0.08 * strength) + 0.5h;
    half3 printed = contrasted * paper.rgb;
    half3 out = mix(rgb, printed, half(strength));
    out += half3((grain_noise(floor(position), seed) - 0.5) * grain);
    return half4(clamp(out, 0.0h, 1.0h) * color.a, color.a);
}
```

`strength` is animatable. Hold a stub and the print washes off to reveal the photograph on a spring; let go and it prints again. The misregistered plate samples the layer's own alpha shifted by an offset and lays orange under it wherever the ink is not, so any text gets the treatment without a second `Text` view.

**What the evidence says.** The identity was specified in SwiftUI first, on Day 0, as view modifiers implemented with blend modes and a Core Image noise plate, and the Metal versions took over on Day 1 behind a switch (`scripts/run.sh --look swiftui` still renders the other one). That order was forced: Apple's Metal toolchain catalog fetch failed twice on Day 0 before it succeeded, and a visual identity cannot depend on a download (ADR-002). It turned out to be the right order anyway. Because the look lives at the modifier boundary, the callers never knew which engine drew it, the two could be screenshotted side by side on Day 1, and the widget, which cannot use Metal or UIKit, compiles the same tokens and draws its card with plain SwiftUI. The identity is the rules in `DESIGN.md`; the shaders are one way of obeying them.

<p>
<img src="screenshots/day-1-look-swiftui.png" width="30%" alt="Day 1: SwiftUI blend modes">
<img src="screenshots/day-1-look-metal.png" width="30%" alt="Day 1: the Metal shaders">
<img src="screenshots/day-2-detail-held.png" width="30%" alt="Day 2: the silkscreen lifted under a held finger">
</p>

The one rule that mattered most was not a shader at all: grit in the image layer, never in type. The photographs are grained and misregistered; the words are Host Grotesk, Newsreader for one italic sentence, Fragment Mono for the numbers, and none of them tracked out or boxed. The shaders make the rough part rough so the rest can be quiet.

## What is not proved

The camera path (VisionKit `DataScannerViewController` feeding the same parsers), the Siri phrases and the lock-screen widget all need a signed build on a phone; [`docs/device.md`](device.md) is the list. The eval table is eight synthetic tickets in a simulator whose model runs on the CPU. The season sentence has no acceptance-rate measurement, only anecdotes. Every one of those is a line in the log's "Still rough" section for the day it was found, which is the section I would read first if I were you.
