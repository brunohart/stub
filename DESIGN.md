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

## Editions

Every stub also comes back as an **edition**: a ticket designed for its film's release. The edition is the image layer, not the app, so the rules above bend for it in exactly these ways and no others.

1. **One edition per release, one copy per stub.** The design is the film's; the seat, the date, the cinema and the viewing number are yours.
2. **The model chooses, the code draws.** Eight movements, twelve palettes, four stocks. The on-device model picks from them; it never picks a colour, a position or a word. The hash picks when the model is absent, and picks the composition always.
3. **Surface is allowed on its type.** An edition is a printed object: ink is pressed into the stock, foil catches the light, the stock has a grain. That is surface, not grit on words; the app's own type stays clean.
4. **One light, and it is the phone's.** Every surface on the card is lit from the same place. Tilt the phone and the light moves; put it down and it stays. Nothing shimmers on its own.
5. **Weight is allowed, the faces are not.** Host Grotesk from Light to ExtraBold, Newsreader, Fragment Mono. No fourth face, even for a Deco title.
6. **Nothing invented.** No taglines, no plot, no stars, no fake barcode. The Aztec code on the back says what the strip says.
7. **You can feel it.** A finger dragged across the card feels the stock (cotton is soft, foil is slick) and clicks once at the perforation.

## The press

The person who kept a stub can pull their own proof of its edition (ADR-016, `docs/briefs/the-press.md`). The rules for editions still hold; these are added.

1. **You choose between drawings. You never move a mark.** Another take of a part, another movement, inks or stock from the genome's lists. No colour picker, no drag, no text, no sticker.
2. **Only what you are holding moves.** A part is turned on its own die; the rest of the poster stands still while it redraws.
3. **Going back is one step.** A proof is a difference laid over the edition, never a replacement; deleting it shows the title's (or the model's) edition exactly.
4. **The front is the film's; the back is yours.** Nothing is added to the front but what the strip already prints. The owner's pencil (a signature, A/P, the takes) goes on the back.
5. **The press room is chrome, not an edition.** Parchment, `Ink`, the three faces, one italic sentence a screen. No dark deck, no glass, no tracked uppercase labels.
6. **Haptics are the stock's.** The wheel's detents, the lever's resistance and the platen are felt at the stock's own sharpness, and punctuate what the hand does.
7. **One light, and nothing moves on its own,** except wet ink drying for a moment after a pull, which is the consequence of an act and ends.

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
