# 003 · The kill list

**Date** 2026-10-16 · **Status** two cut; three proposed and waiting for Bruno

Judged against decision 001: does it make keeping tonight faster, or the afterglow worth keeping for? Anything that does
neither, or that costs the moment time, battery or attention, goes.

## Cut

| Feature | Size | Why, in one line |
|---|---|---|
| **The room** ("Put it on the table", ARKit) | `RoomView` 179, `RoomCard` 277, `Room.metal` 34 lines | Its only way in went with the detail's "…" (ADR-035); it is a demo of RealityKit, never tried on a phone, and nobody stands in a foyer wanting AR. |
| **The inline Lock Screen widget** | one family in `StubWidget` | A line of text nobody reads; the Control owns the Lock Screen now (decision 002). |

## Proposed, waiting for Bruno

These are his designs, and each was built deliberately; the evidence says they cost more than they give. Nothing is
removed until he says so.

| Feature | Size | Why, in one line | Evidence |
|---|---|---|---|
| **The model choosing editions on its own** (art direction) | `ArtDirector` 368 lines; up to 12 s per release; model calls while the drawer shows editions | It makes the drawer **less** varied and slower than the hash it replaced. | Deep eval (2026-09-30): the model used 3 of 8 movements, 2 of 12 palettes and 1 of 4 stocks across 24 answers; the hash's floors for the same releases used 6, 6 and 4. **Alternative to cutting:** the hash draws three candidates and the model chooses among those three, so the guardrail stays closed, variety cannot collapse, and the wait is bounded. |
| **The model writing the season sentence** | `SeasonWriter`, a retry, a cache | The hand-counted sentence says the same facts in a millisecond; the sheet's ledger (ADR-034) now carries the facts anyway. | Deep eval: the model's sentence was kept on the first try 1 time in 3 for the full drawer; every refusal was for length, and the retry repeated the refused sentence 2 times in 3. |
| **Separations** (pinch the card into its plates) | `Separation` 140 lines, per-layer projection in `EditionFace` and `PressRoom` | Spectacle that has to be discovered and does not change what is kept. | Bruno's own note (2026-10-13) that the press's moves were undiscoverable until named; the plates-apart gesture is still unnamed. |

## Kept, though they were candidates

- **The press.** It is the afterglow's reason to come back, and the dial now names every move (ADR-031).
- **The 9:16 share and its watermark.** It is the growth loop (decision 006).
- **The icon drawer.** It is the business model's first product (decision 006).
- **Patina and the punch.** Cheap, and they make a kept thing gain rather than decay (ADR-032).

## The evidence

Line counts from the code (2026-10-16); model numbers from `docs/evals-deep.md` (three runs, nine fixtures, 2026-09-30).
