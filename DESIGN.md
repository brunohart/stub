# Design

One intent, then rules. The intent decides how the constraints are used; the constraints come from `~/Developer/designedbybruno/digital-design-taste.md`.

## The intent

**A drawer of ticket stubs tipped onto a table.** Not a list. Not a grid. Objects with spatial relationships. You went to the cinema, you kept the stub, and years later the drawer is the proof of who you were on those nights.

## Rules that follow

1. **Type is constant and quiet.** Host Grotesk for the words, Newsreader italic for exactly one sentence per screen, Fragment Mono for numbers. Nothing tracked-out and boxed. No eyebrows.
2. **All grit lives in the image layer.** The stub photograph is the thing that gets silkscreened, misregistered, grained. The parchment has grain. The type does not.
3. **Nothing sits level.** Each stub has a tilt fixed at creation (between −1.5° and 1.5°, never 0). It sits up straight when touched and lies back down when released.
4. **Two uneven columns**, 1.15 to 0.85, overlapping by six points, the right column starting lower. Photos pinned to a corkboard, not tiles.
5. **The silkscreen lifts under pressure.** Hold a stub and the print washes off to reveal the photograph. Let go and it prints again. Reward for attention.
6. **Physics, not transitions.** One spring family (`Motion`), tuned by feel. Overshoot once, settle. High-frequency actions (opening, closing) do not animate for their own sake.
7. **Honest machinery.** Every stub says who read it (the on-device model, heuristics, or you) and how sure it was. The raw read is one tap away.
8. **Respect the platform.** Reduce Motion removes tilt and overshoot. Dynamic Type is honoured. Touch targets are 44pt. Haptics punctuate, they do not decorate.
9. **When in doubt, remove.** The empty drawer has a blank stub, one sentence, one button.

## Inks

| Token | Hex | Use |
|---|---|---|
| paper | `#F0EDE6` | the table, the substrate, the multiply target |
| cream | `#F5F0E1` | a blank stub |
| ink | `#1A1A1A` | words |
| orange | `#D4622B` | the misregistered plate, the accent, never a fill |
| navy | `#1B2D4F` | the italic sentence, offset shadows |
| rust | `#C4391D` | destructive, only |
| grey | `#8A8578` | secondary words |

## What this is not

Dark-mode SaaS. Glass. Template grids. A card component library. Motion for motion's sake. A tracked uppercase mono label anywhere.
