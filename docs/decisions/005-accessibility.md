# 005 · Accessibility: every flow, every setting, and an honest label

**Date** 2026-10-16 · **Status** decided; the audit runs in CI and is clean; two labels wait on people (docs/proof/voiceover.md)

## The decision

Every common task — first launch, keeping a ticket (camera, photograph, share, link), finding a stub, the season,
filing, throwing away, sharing, the icon purchase, Your card — works with VoiceOver, at the largest accessibility text
size, with Reduce Motion, and with Increase Contrast. Apple's `performAccessibilityAudit` runs on every screen those tasks
pass through, at the default size and the largest, with Increase Contrast off and on (`StubUITests/AccessibilityTests`,
`scripts/a11y.sh`, the `a11y` job in CI). Stub claims an Accessibility Nutrition Label only when every common task can be
done with that feature, which is Apple's own bar.

## What the audit found, and what changed

The first full audit (2026-10-16) reported issues on all ten screens. In order of who they hurt (ADR-042):

| Found | Who it hurt | Change |
|---|---|---|
| The import form stayed in VoiceOver behind the viewfinder (faded, not removed): "Photograph it" and "Photos" could be reached but not seen | VoiceOver | The form is taken out while the camera is up |
| The press's part chips were inside a status line that ignored its children: VoiceOver could not reach them except through the rotor | VoiceOver | Only the sentence is one element; the chips are buttons, under a heading |
| The press's "kept" line was an empty, unlabelled element when it had nothing to say | VoiceOver | Hidden when it says nothing; it wraps instead of shrinking |
| "Constructivist" broke mid-word on a small phone at the default size | Everyone | The press's three choices change shape where their words do not fit: one row, the movement over the other two, or three rows |
| The press, the plates, the drawer's picker and Your card cut words at the largest sizes | Larger Text | The press scrolls at the accessibility sizes, the card at a height of its own; plates are as tall as their words; the picker stacks; Your card's labels stand over their values |
| The season's year rows were each a separate element, too small to touch | VoiceOver, Voice Control | The calendar is one element, read year by year |
| The press's part chips were 36 points tall to touch (found by the audit on CI) | Motor | Drawn 36 points tall, touched 44 |
| Secondary words in the taste doc's warm grey, #8A8578: 3.2:1 on parchment, 2.9:1 on the plates' card | Low vision; everyone in a dark foyer | **A change to the palette**: words in the same hue at #5A574E (6.2:1), and #48463F (8.5:1) under Increase Contrast. #8A8578 stays for marks that are not words (`Ink.greyMark`). Thin type at 11–13 pt measured below its computed ratio once smoothed, so the grey has margin rather than a bare pass |
| Words in ink at 55–85% opacity did not change under Increase Contrast | Increase Contrast | `Ink.soft(_:)`: the same strength by default, full ink under Increase Contrast; the faintest (55%) raised to 62% |
| The brass plates were a fixed 264 × 80 and shrank their words to fit | Larger Text | The plates grow with the text size (`DrawerLabel.size(for:)`), words wrap instead of shrinking, the engraving is cut darker |
| The gesture legend under a card shrank to one line | Larger Text | Side by side where it fits, one above the other where it does not |
| The season's calendar capped its type | Larger Text | At the accessibility sizes it becomes a ruled list of months at the person's own size; at the others each year is one element read as its months |
| Icon names were cut ("Letterpres") and the locked ones dimmed as disabled | Larger Text; low vision | Four to a row, two at the accessibility sizes; a locked icon opens the purchase instead of doing nothing |
| Words at 9 to 11 points: dates and seats, the plates' lines, the months, icon names | Low vision | No interface words under 12 points (DESIGN.md rule 8) |
| The engraving on the plate's darkest brass measured 2.1:1 at the largest size | Low vision | Cut darker (#1E1406), the darkest brass a step lighter: 5.5:1 at worst |
| The doors at the bottom of the drawer covered a third of it at the largest size | Larger Text | They grow to the first accessibility size, as the system's bars do, and a hold shows their words large (Large Content Viewer) |
| The viewfinder's side controls had a fixed frame | Larger Text | A minimum size that grows |
| The year folders' and the drawer's press springs overshot under Reduce Motion | Reduce Motion | `Motion.press(reduceMotion:)` everywhere a spring presses |

**Printed artwork is not interface text.** An edition is a designed poster and a ticket stub is a photograph. The type
printed on them is part of a picture with significant other visual content, which WCAG's contrast rule exempts. It is
also fixed in size because it is printed. Each card is one accessibility element whose label says what is printed on it
("The Brutalist, Embassy Theatre, 6 September 2026, seat H12, first viewing…"), so its artwork is hidden from VoiceOver
and not read out twice, and named `artwork` for the audit. The words a person needs are always also interface text: the
caption under every card, the detail's title, numbers and ledger.

**Words are set level.** A stub lies at the angle it was filed at; the words under it do not (DESIGN.md rule 3). Type turned
through a degree smears at small sizes, and Apple's audit cannot measure it at all.

## How the audit is judged

`performAccessibilityAudit` is a heuristic, and it was wrong in both directions here. On the `-a11y-lab` sample sheet
(`Stub/App/ContrastLab.swift`) it passed a grey at 3.2:1 and called it only "nearly passed", and it failed ink at 14:1 on
Your card. The cause was the group around the text: text and its background under any rotation, even 0°, fail, whatever
the inks. So the test collects every issue and judges each one. Apple's WWDC23 session on audits (10035) shows filtering
in the audit's handler, and Apple's forum advice is to filter only what has been verified. Five kinds are settled by
evidence, and each verdict is printed, so the record says why (`build/a11y-settled.txt`):

| Issue | Settled when | Otherwise |
|---|---|---|
| Any, on `artwork` | It is printed artwork: hidden from VoiceOver, spoken by its card | — |
| Contrast | The element measures 4.5:1 or more on the screen, WCAG's way (the commonest light against the darkest few percent) | Fails |
| Contrast with no element named | Every word on the screen measures 4.5:1 or more. On GitHub's slower machine the audit lost the element it meant on two screens, so every word is measured instead, a superset | Fails, naming each word under 4.5:1 |
| Contrast, under the drawer's doors | The caption has scrolled under the doors' fade, which is meant to fade it | — |
| Dynamic Type | The label is at least 1.4 times as tall at the largest size as at the default; or it is a navigation bar's own button, which shows the Large Content Viewer | Fails |
| Text clipped | Vision reads every letter of the element's words where it is drawn | Fails |
| Text found in the pixels | Every word Vision reads on the screen is an element's, on a picture, behind a half-height sheet, or the system's status bar. A fragment Vision reads over an element, clipped by an edge or softened by the scroll edge, counts as that element's when it begins as the element's words begin (2026-10-17: "Wed.a" over "Wednesdays, three films" on CI) | Fails, naming the words |

Anything else fails the run. A11Y lines in `build/a11y.txt` are the failures; the job in CI fails on one.

**The result, 2026-10-16.** Ten screens, each at the default size and the largest accessibility size, with Increase
Contrast off and on: **0 issues**, on this Mac and in CI (GitHub's `xcode-27` image, 2026-10-16). In the last run Apple's audit raised 218, and each was settled by
its evidence:
- 62 printed artwork;
- 45 contrast flags with no element named, where every word on the screen measured 4.5:1 or more;
- 37 contrast flags measured at 4.5:1 or more on screen (the lowest 5.2:1);
- 32 labels measured growing at the largest size;
- 24 times every word on the screen was accounted for;
- 8 navigation bar buttons;
- 8 clipped texts Vision read whole;
- 2 captions under the doors' fade.

The sample sheet that showed the check's blind spot opens with the launch argument `-a11y-lab`, and Your card's
variants with `-a11y-lab -a11y-lab-card` (Debug and Performance only).

## Reduce Motion: a still for every movement

| Movement | With Reduce Motion |
|---|---|
| The light on a card, the brass labels' sheen (the gyroscope) | Not started: the card is lit as it lies; a finger still moves the light, because the person is moving it |
| The card leaning and turning over | No lean; turning over cross-fades flat |
| Cards dealt onto the table; figures put down on the season | Simply there |
| The press: print run, wet ink, plates parting, the wheel coasting | Printed at once, no gloss, sheets laid flat side by side, the wheel steps without coasting |
| Every press spring | Critically damped, no overshoot |

Checked in the simulator with Reduce Motion set (2026-10-16): the drawer's stubs lie level and are simply there. The light
and the haptics need the phone.

## The Accessibility Nutrition Label

| Label | Claim | Evidence, and what it waits on |
|---|---|---|
| VoiceOver | **After the VoiceOver session** | Every element labelled, named actions for moving, filing and throwing away, a Parts rotor in the press. Claimed only when a daily VoiceOver user completes every task unaided (docs/proof/voiceover.md) |
| Voice Control | **After a Voice Control run** | Every act has a named control as well as a gesture (DESIGN.md rule 10). Bruno runs every task with "Show numbers" on a phone |
| Larger Text | **Yes** | The audit is clean at the largest accessibility size on all ten screens (2026-10-16). The press scrolls there; the drawer's doors stop at the first accessibility size and show the Large Content Viewer, as the system's bars do |
| Dark Interface | **No** | Stub is parchment by design. Not claimed |
| Differentiate Without Color Alone | **Yes, after a Grayscale check** | Orange always comes with words or a symbol (the busiest month's dot sits beside its words; filed is a checkmark) |
| Sufficient Contrast | **Yes** | Clean with Increase Contrast off and on; the lowest text measured on screen is 5.1:1 (2026-10-16) |
| Reduced Motion | **Yes, after a Reduce Motion run on a phone** | The table above |
| Captions, Audio Descriptions | **Not applicable** | Stub plays no video or speech; a shared clip is silent and made by the person |

## What was killed

- The taste doc's warm grey for words (it stays for marks).
- Shrinking text to fit anywhere in the app's own interface.
- Claiming a label from the audit alone: the audit checks what is on screen, not whether a person can finish a task.
- Taking the audit's verdict as the last word: it is a heuristic, wrong in both directions here, so each verdict is
  checked against what is on the screen, and the reason is printed.
- Words at an angle. The stubs keep theirs; the words under them are set level.
- Interface words under 12 points.
