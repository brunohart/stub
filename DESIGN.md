# Design

One intent, then rules. The intent decides how the constraints are used; the constraints come from `~/Developer/designedbybruno/digital-design-taste.md`.

## The intent

**A drawer of ticket stubs tipped onto a table.** Not a list. Not a grid. Objects with spatial relationships. You went to the cinema, you kept the stub, and years later the drawer is the proof of who you were on those nights.

## Rules that follow

1. **Type is constant and quiet.** Host Grotesk for the words, Fragment Mono for numbers. Newsreader italic is the drawer's voice and nothing else: the season's sentence, on its sheet, and what an edition prints. It is never an instruction, a status or a way somewhere, and it is not on the home screen (ADR-022). Nothing tracked-out and boxed. No eyebrows.
2. **All grit lives in the image layer, and none of it is noise.** The stub photograph is the thing that gets silkscreened and misregistered. The parchment is a flat warm colour; nothing is grained, because noise laid over an app reads as fake (ADR-017). The type is clean.
3. **Nothing sits level.** Each stub has a tilt fixed at creation (between −1.5° and 1.5°, never 0). It sits up straight when touched and lies back down when released.
4. **Filed by year, then by hand.** Two columns of mounts behind year folders, newest year first; within a year, the order the person put the stubs in. Each row's mount is as tall as its tallest ticket and every ticket stands on the same line, so a drawer of a hundred reads as calmly as one of ten. A folder closes on its year with a tap on its tab (ADR-026). (Until 2026-10-15: two uneven columns, a pinboard.)
5. **The silkscreen lifts under pressure.** Hold a stub and the print washes off to reveal the photograph. Let go and it prints again. Reward for attention.
6. **Physics, not transitions.** One spring family (`Motion`), tuned by feel. Overshoot once, settle. High-frequency actions (opening, closing) do not animate for their own sake.
7. **Honest machinery.** Every stub says who read it (the on-device model, heuristics, or you) and how sure it was. The raw read is one tap away.
8. **Respect the platform.** Reduce Motion removes tilt and overshoot. Dynamic Type is honoured. Touch targets are 44pt. Haptics punctuate, they do not decorate.
9. **When in doubt, remove.** The empty drawer has a blank stub, one sentence, one button.
10. **Every way somewhere is named.** The drawer's two doors (the season, Keep a stub) sit at the bottom where a thumb is; Your card sits in the top corner above the labels. A card's acts are its own gestures, said under it every time ("Tap to turn over · Hold for the press"), and holding draws an orange line round its edge until it lifts for the press, so the hold is seen to work; Share is in the top right where a phone keeps it, and the same acts are in the menu beside it for anyone who would rather choose. In the press, the marks show every part that turns and the line says to tap one and turn the dial; whether the card is kept is always said over the bed, and the lever says Pull to keep (ADR-030).
11. **Buttons are clean and quiet.** Capsules in the drawer's inks: ink for a screen's one primary act, cream with a hairline edge for the rest, words alone for what should not be shouted (Cancel, Throw this stub away). Pressed, a button goes into the page, a touch smaller with its shadow drawn in, with one soft tap at contact; let go, it comes back on a spring with one small overshoot. A choice between two or three things is one control with a sliding ink thumb. No out-of-register plate, no glass, no system capsules on the parchment; the misregistration belongs to what is printed, not to what is pressed (ADR-029).
12. **Things are put down, not faded in.** The cards are dealt onto the table the first time the drawer opens, newest first, each falling from a little above and a few degrees further turned, skidding a fraction past its tilt and settling. A kept stub is dropped onto the table the same way. The season's figures are put down one after another. Under Reduce Motion they are simply there. The launch screen is the parchment, so nothing ever fades in from white.
13. **The home is the cabinet, and every drawer is labelled.** A brass label holder with a typed card in it: the years, the stubs, the cinemas, or the name the person gave the drawer. Not the app's name. Brass is a material, so it answers the light. The labels sit on one shelf; the one in the middle is the drawer open (ADR-026).
14. **Every share is signed by the paper.** "shared in Stub" and a small ticket, blind-embossed under the card on every clip and still, lit by the share's own light. Never on the card, never optional.
15. **The act comes first.** Keep a stub opens the camera; the form is the second layer. Holding a stub moves it; the menu and the list do the same for anyone who would rather tap (ADR-025, ADR-026).
16. **Nothing is lost in one tap.** Throwing a stub away and taking a drawer out are asked once; a stub taken out of a drawer is still in the drawer of every stub.

## Editions

Every stub also comes back as an **edition**: a ticket designed for its film's release. The edition is the image layer, not the app, so the rules above bend for it in exactly these ways and no others.

1. **One edition per release, one copy per stub.** The design is the film's; the seat, the date, the cinema and the viewing number are yours.
2. **The model chooses, the code draws.** Eight movements, twelve palettes, four stocks. The on-device model picks from them; it never picks a colour, a position or a word. The hash picks when the model is absent, and picks the composition always.
3. **Surface is allowed on its type.** An edition is a printed object: ink is pressed into the stock, foil catches the light, cotton has a soft fibre and coated card a sheen. That is surface, not grit on words; the app's own type stays clean.
4. **One light, and it is the phone's.** Every surface on the card is lit from the same place. Tilt the phone and the light moves; put it down and it stays. Nothing shimmers on its own. On a real table the light is the room's, and only there (ADR-018).
5. **Weight is allowed, the faces are not.** Host Grotesk from Light to ExtraBold, Newsreader, Fragment Mono. No fourth face, even for a Deco title.
6. **Nothing invented.** No taglines, no plot, no stars, no fake barcode. The Aztec code on the back says what the strip says.
7. **You can feel it.** A finger dragged across the card feels the stock (cotton is soft, foil is slick) and clicks once at the perforation.
8. **The card keeps its history, and says it.** A second viewing of a release punches the strip, the way a conductor punches a ticket: a remarque in the movement's own die, cut through both faces, the card's shadow falling into the hole. The card ages from the night it was seen (the paper warming from its edges in, a few small clusters of foxing after a couple of years) and from being held (corners rubbed, a burnish where a thumb goes, seen only as the light moves). All of it is the copy's, never the design's; a card seen tonight and never held has none of it; and the detail says in one line what each mark means (ADR-032).

## The press

The person who kept a stub can pull their own proof of its edition (ADR-016, `docs/briefs/the-press.md`). The rules for editions still hold; these are added.

1. **You choose between drawings. You never move a mark.** A named move of a part on the dial (larger, smaller, turned, echo, outline, mirrored, swapped, redrawn), another movement, inks or stock from the genome's lists. No colour picker, no drag, no text, no sticker. The parts are named under the card, so what can be changed is never a guess (ADR-031).
2. **Only what you are holding moves.** A part is turned on its own die; the rest of the poster stands still while it redraws.
3. **Going back is one step.** A proof is a difference laid over the edition, never a replacement; deleting it shows the title's (or the model's) edition exactly.
4. **The front is the film's; the back is yours.** Nothing is added to the front but what the strip already prints. The owner's pencil (a signature, A/P, the takes) goes on the back.
5. **The press room is chrome, not an edition.** Parchment, `Ink`, the three faces. Registration marks show every part that turns. The line between the card and the bench says what is in hand and its take (the number in the mono), or what to do next, in words, not the italic. The bench's choices are stamps, the open one inked; the fan stays in the hand until it is closed. No dark deck, no glass, no tracked uppercase labels.
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
