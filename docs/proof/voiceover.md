# The VoiceOver session

**The question.** Can someone who uses VoiceOver every day do every common task in Stub with VoiceOver alone?

**The bar.** Apple's VoiceOver evaluation criteria for the Accessibility Nutrition Label: every common task (the app's
primary functionality, first launch, settings, and purchase) can be completed with VoiceOver alone
(https://developer.apple.com/help/app-store-connect/manage-app-accessibility/voiceover-evaluation-criteria). Stub claims
the label only when a daily VoiceOver user has done every task below unaided (decision 005).

**Who.** One person who uses VoiceOver as their main way of using an iPhone. A second if a task fails and is fixed, or
if the first session leaves a doubt.

**How long.** 60 minutes, on their own iPhone, with their own settings, Stub installed from TestFlight.

**The build.** The cohort's build, after Beta App Review: the participant is an external tester.

## Finding a participant

- **Where.** Ask Blind Low Vision NZ whether they can pass an invitation to people who use VoiceOver daily, or ask a
  local blind or low-vision community group or peer network to share it. Never approach anyone directly from a list.
- **Who.** Uses VoiceOver as their main way of using an iPhone, every day, for a year or more. An iPhone 11, iPhone SE
  (2nd generation) or later, on iOS 26 or later. Goes to the cinema sometimes (audio-described sessions count), though
  it is not required.
- **Payment.** NZ$80 for the hour plus travel, or what the organisation recommends if it is more, paid at the start in
  the way they prefer, whether or not the session finishes.
- **Where the session happens.** Their home or a quiet place they choose, so VoiceOver can be heard. Bruno goes to them.

### The invitation

Plain text in the email itself, never an image or a PDF alone.

> Subject: Paid, one hour: test a new iPhone app with VoiceOver
>
> Kia ora,
>
> I make Stub, an iPhone app for keeping cinema tickets. Before it is released I need to know whether everything in it
> works with VoiceOver, and the only way to know is to watch someone who uses VoiceOver every day try it.
>
> One hour, at your home or a place you choose, in [city]. You would use your own iPhone and do about ten everyday
> things in the app: keep a ticket, find one, share one. I pay NZ$80 for the hour, plus travel, whatever happens in it.
>
> You would need an iPhone 11 or later on a recent iOS, and to install Apple's TestFlight app beforehand. I can help with
> that by phone.
>
> Nothing is filmed. With your permission I would record the sound of the session, and delete it within two weeks.
>
> If you'd like to, reply to this email, or call me on [phone].
>
> Bruno · designedbybruno.net/stub

## Before the session

### Bruno's own run, a week before

Every task below, on the cohort's build, with VoiceOver on and Screen Curtain on (three-finger triple-tap), the phone
never looked at. Fill the same results table. Fix what is found before the session: the participant's hour is for what
Bruno cannot find himself.

### TestFlight

- Add their email to an external group, `Accessibility`, with the cohort's build.
- Send the invitation at least three days before, with an offer to help install TestFlight by phone. Installing
  TestFlight is Apple's, not a task.
- Ask them to install Stub but **not open it** until the session: first launch is task 1.

### The tickets

All fictional. Not the repo's fixtures: they carry real film names. Check each invented title against a film database
before printing, and change any that turns out to be real.

| Ticket | Film | Cinema | Date | Screen, seat | Used in |
|---|---|---|---|---|---|
| Printed stub 1 | A Quiet Harbour | The Kingsway Picture House | A Saturday last month, 7.30 pm | Screen 2, F12 | Task 2 |
| Printed stub 2 | Northerly | The Kingsway Picture House | Two months ago, 6.15 pm | Screen 1, C4 | Before task 4 |
| Printed stub 3 | The Glasshouse Year | The Kingsway Picture House | Earlier this month, 8.00 pm | Screen 3, H8 | Before task 4 |
| PDF e-ticket | Winter Orchard | The Kingsway Picture House | Earlier this month, 5.45 pm | Screen 1, D7 | Task 3 |

- Choose the dates so that last month holds one film and this month two; early in a month, move all four back a month
  and change the words of tasks 2 and 4 to match. The cinema's name is spelled the same on all four.
- The printed stubs on card, about 13 by 6 cm, the film in large type; a thermal receipt printer for one of them if one
  is at hand.
- The PDF: one A4 page with the cinema, film, date, time, screen, seat, price in NZ$ and an invented booking reference.
  Emailed to the participant the day before, subject "Your e-ticket for the Stub session".

### The purchase

Task 10 needs the icon drawer's in-app purchase to exist in App Store Connect and the Paid Apps agreement signed
(BEDIP-217). In TestFlight a purchase is not charged. If the purchase is not there yet, task 10 cannot be run, and the
label waits until it has been.

### To bring

- [ ] The three printed stubs, in an envelope; the PDF already in their Mail.
- [ ] An audio recorder (used only with consent), notes sheets, a watch for times.
- [ ] The payment, ready to give at the start.
- [ ] This page, printed or on a laptop, for the "should happen" notes.

## The session

| Minutes | What |
|---|---|
| 0–5 | Welcome, consent, payment. Their setup: iPhone model, iOS version, speech rate, braille display or not, years with VoiceOver. |
| 5–50 | The tasks, in order |
| 50–60 | What was hardest, what they would change first, anything else |

If more than three tasks remain at minute 45, stop and book a second paid half hour rather than rush. The debrief can
shrink; a task cannot be skipped, because the label needs every one.

### Consent

> "Thank you for doing this. I make Stub, an iPhone app for keeping cinema tickets, and I want to find out whether all
> of it works with VoiceOver. I'll ask you to do some things in it, and I'll mostly stay quiet and take notes, because I
> need to hear where it works without me. Anything that goes wrong is the app's fault, never yours.
>
> With your permission I'd like to record the sound: what your phone says and what you say, so I can check exactly what
> VoiceOver announced. Nothing is filmed. The recording stays with me and is deleted within two weeks, once my notes are
> written. If you'd rather I didn't record, that's fine; I'll write notes instead.
>
> The tickets you'll keep are made up for today. At the end you can delete Stub or keep it.
>
> You can stop at any time and skip anything. You're paid for the hour either way. Is that all right?"

A spoken yes, and a separate yes or no to the recording.

### Running each task

- Read the task's words exactly, once; repeat them whenever asked. Nothing about how.
- If they ask how: "What would you try?" Once.
- A second request, three minutes with no progress inside Stub, or "I'd give up": help, and write exactly what help was
  needed. The task is **not unaided**. Carry on, so the later tasks are still seen.
- Help with Apple's own parts (Mail, the system share sheet, the camera permission alert, the App Store purchase sheet)
  is **system help**: the task still counts as unaided if every step inside Stub, and in its Keep in Stub sheet, was
  theirs.
- Any VoiceOver gesture, rotor, action, Magic Tap or braille display is theirs to use. Ask at the start that Screen
  Recognition stays off; if they turn it on to get past something, that task is not unaided, because it is then the
  phone reading the pixels, not Stub describing itself.
- Time each task from the end of its words to its "done when".

## The tasks

### 1 · First launch

> "Open Stub for the first time. Tell me what you think it's for, and what you'd do first."

**Done when** they have said what it is for and found Keep the first stub.

**Should happen.** The empty drawer reads "A blank stub. The drawer is empty.", one sentence about what the drawer is
for, and the button "Keep the first stub". "Your card" is a button at the top. *3 minutes.*

### 2 · Keep a printed stub

Hand them printed stub 1.

> "Here's the ticket from a film you saw last month. Keep it in Stub."

**Done when** Keep it is accepted and the sheet becomes the press.

**Should happen.** Keep the first stub opens the viewfinder; the system asks for the camera once. The viewfinder has
"Cancel", "Torch on", a line of guidance, "Take the photograph", "Photos" and "Type it in". The guidance reads "Lay the
stub flat and fit it inside the marks." and changes to "That is a ticket. Take it while it is still." when the marks
hold the ticket. The line is marked as updating frequently; whether the change is heard without VoiceOver's focus on it
is one of the things to watch. Then the form: text fields Film, Cinema, Screen and Seat, the Screening date picker, and
"Read by …, N percent confident." The sheet's one primary act is **Keep it**, at the bottom; until there is a title it
reads "Keep it, once it has a title" and is dimmed. *6 minutes.*

Watch: whether the date read off the ticket is last month's or today's, and whether they check it.

### 3 · Keep a PDF from Mail

> "I've emailed you an e-ticket. Keep it in Stub, starting from Mail."

**Done when** Keep it is accepted in Stub.

**Should happen.** In Mail, the PDF attachment's share sheet offers Stub (perhaps under More). Stub's sheet reads "Keep
in Stub", with "Cancel" and "Send to Stub", and the line "Nothing leaves the phone. Stub files it when you keep it." After
sending: "It is waiting in Stub. Open Stub to keep it." In Stub, the form opens filled in; Keep it. *6 minutes.*

Watch: whether they know to open Stub afterwards, and whether "It is waiting in Stub" is heard before the sheet closes.

### Before task 4 · two more for the drawer

Hand them printed stubs 2 and 3.

> "Two more for the drawer, please. Keep both."

Not a task; timed anyway. The second and third keeps show whether it gets quicker once learned. *4 minutes.*

### 4 · Find last month's film

> "Find the film you saw last month, and tell me which cinema and which seat."

**Done when** they say The Kingsway Picture House and F12.

**Should happen.** The cabinet's plate reads "Every stub: 4 stubs, 1 cinema, [year]." The year's folder is a heading,
"[year], 4 stubs", with ", open" or ", closed" where it can be closed. "Show the drawer as" chooses tickets or editions. Each card is one button whose
label is the film, the date, the cinema and the seat ("A Quiet Harbour, [date], The Kingsway Picture House, seat F12"),
with the hint "Opens the stub." Within a year the cards are in the order they were put in, not by date, so finding last
month's means hearing the dates. *4 minutes.*

### 5 · The season

> "Open the season. Tell me how many films and how many cinemas are in your drawer, and which month had the most."

**Done when** they say 4 films, 1 cinema, and this month.

**Should happen.** "The season, 4 films" at the bottom, with the hint "The numbers behind the sentence." (the cabinet's
plate opens it too). On the sheet: the season's sentence; the figures, each one element ("films, 4", "cinemas, 1",
"paid, …"); then "Nights by month", one element whose value is read month by month, each month with its count; then
the ruled lines, each label with its fact. *3 minutes.*

### 6 · File a stub in a drawer they make

> "Make a drawer called Date nights, and put A Quiet Harbour in it."

**Done when** A Quiet Harbour is filed in Date nights.

**Should happen**, by any of three ways:

- Open the stub, "File in a drawer", "New drawer…", the sheet "A new drawer", type the name, "Label the drawer". The
  stub is filed, and the button now reads "Filed in Date nights".
- The card's own menu (held), "File in a drawer", "New drawer…", the same sheet.
- The blank label on the cabinet's shelf, "New drawer", hint "Names a new drawer to file stubs in.", then choosing the
  stubs in it.

*5 minutes.* Watch which way they find, and whether the held menu is reachable at all.

### 7 · Throw one away

> "Throw away Northerly."

**Done when** Northerly is gone from the drawer.

**Should happen.** On its card, VoiceOver's actions (swipe up or down) are "Move earlier in [year]", "Move later in
[year]" and "Throw away". Or open it and choose "Throw this stub away". Either way it is asked once: "Throw it away",
with "The stub and its photograph go from every drawer, here and in your iCloud. Its edition stays with the film."
*3 minutes.*

### 8 · Share an edition

> "Send the edition of The Glasshouse Year, the moving one, to yourself in Messages. Or save it to Photos, if you'd
> rather."

**Done when** the clip is sent or saved.

**Should happen.** Open the stub, "Share the edition", then "Share it turning in the light", "Share it turning, close
up" or "Share the still". The clip is drawn before the share sheet opens: a wait of a few seconds. The shared clip
carries "Shared in Stub". *5 minutes.*

Watch: whether the wait is announced, or silent enough to seem broken.

### 9 · Your card (settings)

> "Put your name on your card, and set the drawer to show editions instead of tickets."

**Done when** the name is on the card and the drawer shows editions.

**Should happen.** "Your card", hint "Your name, the icon, where the drawer is kept, and what Stub is." The name field,
hint "Types your name on the card.", and "Type it". "Show it as" chooses tickets or editions, the chosen one announced
as selected. "Keep it in my iCloud" is a switch. "Done" closes the card. *3 minutes.*

### 10 · The purchase

> "Buy the icon drawer, and put a different icon on your home screen. In TestFlight it costs nothing."

**Done when** a new icon is on the home screen.

**Should happen.** On Your card, "Open the icon drawer · [price]", then Apple's purchase sheet. The icons read as
"[name] icon", with ", on the home screen" for the chosen one and ", in the icon drawer" while locked. Choosing one
brings the system's own notice that the icon has changed. "Restore" is beside the drawer. *4 minutes.*

### 11 · The press, if time is left

> "Take A Quiet Harbour to the press, stamp it with the date, and keep it."

**Done when** the stamped card is kept.

**Should happen.** On the edition, the actions include "Take it to the press" and "Lift the print". In the press, the
bench reads "Overprint" and "Stamp" as buttons, each with a hint. With the stamps out, the tray reads each stamp by name
and the three inks as "First ink", "Second ink", "The type's ink"; on the card, the actions include "Stamp the card" (and
with the screens out, "Overprint across the card"). "Take it off" lifts the last act. The lever: "The lever", action
"Pull the proof", hint "Pulls the proof and keeps it as the card. Nothing else keeps it."

Whether the press is a common task is decided in decision 005. If it is, it needs a participant's unaided run before the
label is claimed; if not, Bruno's own Screen Curtain run covers it.

## What to observe

For every task:

| | Written as |
|---|---|
| **Completed** | Unaided · unaided with system help · with help (say what) · not completed |
| **Time** | Minutes and seconds, from the end of the words to done |
| **Where focus got lost** | The screen and the moment: focus left behind when a sheet opened, jumped to the top after an action, landed on something hidden |
| **Announced, against expected** | What VoiceOver said, beside what "Should happen" says it should. Every label that was wrong, missing or unclear. |
| **Silent changes** | Anything that changed on screen with nothing said: the reading in progress, the marks holding, the press printing, the clip being drawn |
| **How they moved** | Swipes, touch, the rotor (which), actions, Magic Tap, two-finger scrub, braille |
| **Their words** | Short, verbatim, unattributed |
| **Severity** | Blocker: could not finish without help · serious: finished by a workaround, or lost 2 minutes or more · minor: an odd word, extra swipes |

## The bar for the label

Stub may claim the Accessibility Nutrition Label for VoiceOver only when all of these hold:

1. Tasks 1 to 10 each completed **unaided** (system help allowed) by a daily VoiceOver user.
2. On the build that ships, or one with no change to the screens those tasks touch since.
3. Task 11 too, if decision 005 counts the press as a common task.
4. Bruno's own Screen Curtain run of every task passes on the same build.

Any task not completed unaided: no claim. The task is fixed, then run again by the same participant (if they are
willing, and paid again) or a second one. Every blocker and serious finding is fixed before launch whether or not the
label is claimed. A label claimed without this is a promise to people who cannot check it before they download.

## Results

Written to `docs/proof/results/YYYY-MM-DD-voiceover.md`. No name, no recording, nothing that identifies the participant
beyond what follows.

### The participant

| | |
|---|---|
| iPhone, iOS | |
| Years with VoiceOver | |
| Speech rate | slow / medium / fast |
| Braille display | yes / no |
| Screen Recognition | off throughout / turned on in task ___ |
| Build | |
| Bruno's own run, same build | date, passed / failed tasks |

### The tasks

| # | Task | Completed | Time | Focus lost | Announced against expected | Silent changes | Severity |
|---|---|---|---|---|---|---|---|
| 1 | First launch | | | | | | |
| 2 | Keep a printed stub | | | | | | |
| 3 | Keep a PDF from Mail | | | | | | |
| — | Two more stubs (2nd, 3rd keep times) | — | / | | | | |
| 4 | Find last month's film | | | | | | |
| 5 | The season | | | | | | |
| 6 | File in a new drawer (which way) | | | | | | |
| 7 | Throw one away | | | | | | |
| 8 | Share an edition | | | | | | |
| 9 | Your card | | | | | | |
| 10 | The purchase | | | | | | |
| 11 | The press | | | | | | |

### What they said

- Hardest:
- Change first:
- Anything else:

### Findings

| Finding | Task | Severity | Fix | Fixed in build |
|---|---|---|---|---|
| | | | | |

### The verdict

One line: label claimed or not, and if not, which tasks are left and when they run again.
