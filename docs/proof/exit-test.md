# The exit test

**The question.** Can a stranger walking out of a cinema keep their own ticket in Stub in under ten seconds, with nobody
showing them how?

**The bar** (decision 001). All five keep their ticket unaided, and the median time is under 10 seconds.

**Who.** Five people leaving an evening session, each with tonight's ticket, each an iPhone user who has never seen
Stub.

**Where and how long.** One cinema, with its permission. One evening, two if five do not come in the first.

**Why first.** The moment is the product. The exit test needs only Bruno's own two phones on the internal build, so it
needs no Beta App Review and can run the week the build exists. If it fails, the cohort waits for the fix.

## The cinema

### Choosing it

- An independent, if one will say yes: more paper and thermal tickets, a manager who can be reached, a foyer to stand
  in.
- Evening sessions ending between 8.30 and 10 pm. Not the opening night of a big release: people leave in groups, in a
  hurry.
- One cinema for all five. In everything written afterwards it is "an independent cinema in [city]", never its name.

### Asking first

No test on a cinema's property, or at its door, without a yes. If the answer is no, ask another cinema; never set up on
the footpath outside instead.

The email, to the manager:

> Subject: A two-minute test with your patrons, after an evening session?
>
> Hi [name],
>
> I make Stub, a small iPhone app for keeping cinema tickets: you photograph your ticket on the way out, and it is kept,
> with the night, in a drawer on your phone. It isn't out yet, and before it is I need to see whether a stranger can use
> it, unaided, walking out of a cinema.
>
> I'd like to ask five of your patrons, as they leave an evening session, to try it with their own ticket. Two minutes
> each, timed with a stopwatch.
>
> What it would mean for you:
>
> - Two of us, by the doors or wherever suits you, for one evening. We would stay clear of staff and queues, and leave
>   whenever you ask.
> - Nobody is filmed or photographed. No names are taken. Each ticket's photograph is deleted in front of its owner.
> - Nothing is sold. The only thing handed out is a small thank-you voucher, for your bar if you would like that.
> - Your cinema is never named in anything I publish about the test.
>
> I'd be glad to show you the app first. Would an evening in the next few weeks work, and is there a session you would
> suggest?
>
> Thank you,
> Bruno
> [phone] · designedbybruno.net/stub

On the night, to the duty manager, even with a yes by email:

> "Hi, I'm Bruno. I wrote to [name] about testing a ticket app with a few of your patrons after the [time] session. Is it
> still all right tonight, and where would you like us to stand?"

## The team

- **Bruno, the facilitator.** Approaches, asks consent, hands the phone over, says the words, then says nothing.
- **A timer.** Holds the stopwatch, stands beside the participant where the screen can be seen without leaning in,
  presses the laps, fills the sheet.

Alone is possible, but the laps are lost: time start to stop only, and fill the sheet straight after each person.

## Equipment

- [ ] **Phone A**: an iPhone 15 Pro or later, Apple Intelligence on and its model downloaded. The import sheet's status
      line should not say the model is unavailable.
- [ ] **Phone B**: an iPhone 11 or iPhone SE (2nd generation), the rules alone. The iPhone 11 is the better choice: like
      Phone A it has Face ID and a Lock Screen with two controls at the bottom, so the paths on the two phones match.
- [ ] Both on the same internal TestFlight build, iOS 26 or later, charged above 80%, Low Power Mode off.
- [ ] A stopwatch with laps: a physical one, or the idle test phone's Clock › Stopwatch.
- [ ] Five recording sheets ([below](#the-recording-sheet)), a clipboard, two pens.
- [ ] The consent words printed on a card, for the participant to read along.
- [ ] Five thank-you vouchers (NZ$10, for the cinema's bar or a café nearby), given whether or not anyone finishes.
- [ ] A few cards with the cohort's sign-up link, for anyone who asks what Stub is. Never offered.
- [ ] A power bank and a cable.
- [ ] Optional: a light meter, so the light where each person stood is a number.

## Setting up the phones

### The night before

1. Install the build from TestFlight on both. Open Stub, press Keep the first stub, allow the camera, Cancel. The camera
   prompt is answered once in a life with Stub, at home; nobody meets it at the exit twice.
2. In Your card, turn **Keep it in my iCloud** off, so nothing a participant keeps can leave the phone. With a stub in
   the drawer (step 8), the season sheet should say "Kept on this phone only". Test phones signed in to an Apple ID
   that holds nothing of Bruno's own are better still.
3. **The Lock Screen.** Put the Keep a stub control in the bottom-left place, in place of the torch; leave the camera
   where it is, so reaching for the system camera stays possible and is seen. The same on both phones, and written in
   the report. If Phone B is an SE and its Lock Screen offers no controls, put Keep a stub in Control Centre instead and
   write that the two phones' paths differ. The Action button on Phone A stays as it came: a stranger would not know it
   had been set.
4. **The home screen.** Stub on the first page, bottom row, not in the dock, among a full page of Apple's own apps. A
   page with Stub alone on it makes finding it free.
5. **The passcode off** for the evening (Settings › Face ID & Passcode, or Touch ID & Passcode on an SE), so a
   stranger can open the phone. Check the import sheet's status line on Phone A still shows the model available with
   it off. If not, keep the passcode on Phone A, and before each handover unlock it with your face and leave the Lock
   Screen showing with the padlock open; write which in the report. Turn the passcodes back on afterwards.
6. Photos empty, and Recently Deleted empty, so anything taken by mistake is plain to see.
7. A Focus on, so no notification lands mid-test. Auto-Lock at 2 minutes.
8. **The floor.** On each phone, keep a fictional printed stub (The Kingsway Picture House, A Quiet Harbour) from a dark,
   locked phone, under light like the foyer's, and throw it away. Write the time. It is how fast someone who knows the
   app is; nobody at the exit will beat it.

### Between people

1. The last person's stub thrown away in front of them (see [After each person](#after-each-person)).
2. The drawer empty: Keep the first stub showing.
3. Photos and Recently Deleted empty.
4. Back to the Lock Screen, side button pressed, screen dark.
5. Phones alternate: people 1, 3 and 5 on Phone A; 2 and 4 on Phone B.

## Who to ask

Adults leaving the session, one at a time or in a pair (one of the pair takes part). Before consent, three questions:

1. "Have you just come out of a film here?"
2. "Have you got your ticket on you, on paper or on your phone?"
3. "Do you use an iPhone?"

And: "Have you used an app called Stub before?" A yes (a cohort tester, a friend) is thanked and not tested.

Stop at five who finish. Someone who stops because they have to go, not because of the app, is written as withdrew and
is not one of the five. Someone who gives up on the app is one of the five, and is a fail.

Expect about one in four to say yes. Five takes one to two hours.

## The approach and consent

The approach:

> "Excuse me, have you just come out of a film? I'm Bruno. I make a small iPhone app for keeping cinema tickets, and I'm
> testing it here tonight with the cinema's permission. It takes two minutes. Have you got your ticket on you?"

Then the eligibility questions. Then consent, read aloud with the card in their hand:

> "Here's what would happen. I'll hand you this phone and ask you to keep your ticket in the app, and my friend will
> time it. We won't film or photograph you, and we won't write your name down; only the time and what happened. The app
> takes a photo of your ticket. It stays on this phone, and I'll delete it in front of you when we're done. You can stop
> at any moment, for any reason. Afterwards there's a voucher to say thanks, whether or not you finish. Is that all
> right?"

A spoken yes, not a nod. Anything less is a thank-you and goodbye.

## The words

Said once, as the phone goes into their hand, locked and dark:

> "This app keeps cinema tickets. Could you keep yours in it? Please do it however you think you would."

Then nothing. Stand beside them, not over their shoulder. No pointing, no nodding at the screen, no "nearly".

The only replies allowed, as often as needed:

| They say | The reply |
|---|---|
| "What do I do?" "Where do I press?" "Should I use the camera?" | "However you think you would." |
| "Is this right?" "Did it work?" | "Do what you'd do if I weren't here." |
| "It's not working." | Nothing. The timer writes it down. |
| "I give up," or the phone is handed back | Stop the clock. |

Anything else said to them about the app, before the clock stops, ends the attempt as not unaided.

If the ticket is on their own phone, they choose how to get it in with the test phone: photographing their own screen,
typing it in, or something else. That is recorded, not steered. Sharing a pass or a PDF from their own phone through the
share sheet is the cohort's to measure; the exit test cannot, because the test phone is not theirs.

## What to time

| Mark | Exactly when |
|---|---|
| **Start** | Their hand holds the phone and the facilitator's hand has let go. The phone is locked and dark. |
| **Lap 1 · ready to read** | The viewfinder is on screen. If they went to Photos or Type it in instead, the first frame of that. |
| **Lap 2 · the photograph** | The shutter's paper flash: the frame holds. None if they typed it in. |
| **Stop** | The first tap on **Keep it** that the app takes: the form gives way to the press. A tap on "Keep it, once it has a title" while it is still faint does not stop the clock. |
| **Limit** | 60 seconds, "I give up", or the phone handed back without the stub kept. Write the time and "not kept". |

Write times to a tenth of a second. A hand on a stopwatch is good to about a quarter, so 9.8 s and 10.1 s are the same
result; the bar is for the median, and five people say whether the path breaks, not what its time is to the decimal.

## What to record

For each person, on their sheet:

| Field | Written as |
|---|---|
| Phone | A (Apple Intelligence) or B (rules alone) |
| Ticket | Printed stub · thermal receipt · digital (Wallet, PDF, email, a cinema's app, screenshot) |
| A digital ticket came in by | Photographing their own screen · typing · other (say what) |
| Light where they stood | Lit foyer · dim foyer · street at night; lux if measured |
| Hands | One or two, most of the time; what the other held, if anything |
| Path | Lock Screen control · Control Centre · home screen, then Keep the first stub · system Camera first · Photos · Type it in · other |
| Lap 1, Lap 2, Stop | Seconds from start |
| Unaided | Yes or no |
| Errors | Each in a few words, with the lap it fell in ("opened the system Camera, back to Stub at 6 s"; "took it before the marks held, blurred, took it again"; "tapped Keep while faint") |
| Stub's torch | Used or not |
| Corrected before Keep | Which fields: film, cinema, date and time, screen, seat |
| Wrong after Keep | Which fields, checked with them against the ticket after the clock stops |
| The model (Phone A) | Did a field change while they were looking? Did they wait for it? |
| Words said | Verbatim and short, during and after. No names. |
| Deleted in front of them | Yes |

## After each person

The clock is stopped; two minutes at most.

1. "How was that?"
2. "Would you do that walking out of here on an ordinary night?"
3. "Was anything not where you expected it?"
4. Show the kept stub and its edition: "This is what you get back." Write what they say: it is the afterglow's first
   impression.
5. Check the fields against their ticket together.
6. Delete it in front of them: open the stub, **Throw this stub away**, **Throw it away**, and show them the empty
   drawer. If they took a photograph with the system Camera, delete it from Photos and from Recently Deleted while they
   watch. "That's gone. Nothing left the phone: this one keeps nothing in iCloud."
7. The voucher. If they ask what Stub is or when it's out, a cohort card.

## The bar, and what a result changes

| Result | What changes |
|---|---|
| **5 of 5 unaided, median under 10 s** | Pass. This build goes to Beta App Review for the cohort. The median, with n, may be quoted (README › What may be claimed). |
| **Anyone not unaided** | Fail. The step where they stopped (the laps and errors say which) is the next build's first job. Then five new people, the same setup. |
| **5 of 5 unaided, median 10 s or more** | Fail. The laps say where the time went: getting into Stub (start to lap 1), framing and taking (lap 1 to lap 2), or the form (lap 2 to stop). Cut there, then five new people. |

Wrong fields do not fail the bar; a person can put them right later, in the afterglow. Every wrong field is a case for
decision 008's corpus, and goes in the results.

The median of five is the third-fastest time.

## The recording sheet

One per person.

| | |
|---|---|
| Person | 1 / 2 / 3 / 4 / 5 |
| Date, session ended | |
| Phone | A / B |
| Ticket | printed / receipt / digital: ___ |
| Digital came in by | own screen photographed / typed / ___ |
| Light | lit foyer / dim foyer / street · lux ___ |
| Hands | one / two · other hand held ___ |
| Path | Lock Screen control / Control Centre / home screen / system Camera first / Photos / Type it in / ___ |
| Lap 1 · ready to read | ___ s |
| Lap 2 · the photograph | ___ s |
| Stop · Keep it taken | ___ s, or not kept at ___ s |
| Unaided | yes / no |
| Errors | |
| Stub's torch | yes / no |
| Corrected before Keep | film / cinema / date / screen / seat / none |
| Wrong after Keep | film / cinema / date / screen / seat / none |
| Model changed a field while they looked (A) | yes / no / — |
| Waited for the model (A) | yes / no / — |
| Words, during | |
| How was that? | |
| On an ordinary night? | |
| Not where expected | |
| On seeing the edition | |
| Deleted in front of them | yes |

## Reporting it

Written to `docs/proof/results/YYYY-MM-DD-exit.md`. Counts and times only: no names, no faces, no cinema's name, no
film's name, nothing from a ticket. A quote that names a film or a cinema has it replaced with [film] or [cinema].

```
The exit test · [date]

Where: an independent cinema in [city], after the [evening] sessions. [one evening / two: dates]
Phones: A, iPhone [model], Apple Intelligence; B, iPhone [model], the rules alone. Build [n].
The Lock Screen: Keep a stub bottom left, camera bottom right. Passcode off on both / Face ID handover on A.
Floor (Bruno, from locked): A [s], B [s].

Approached [n] · agreed [n] · finished [5] · withdrew [n]

Unaided: [n] of 5
Median, start to Keep: [s] (fastest [s], slowest [s])
Phone A: [s], [s], [s] · Phone B: [s], [s]

Where the time went (medians): into Stub [s] · to the photograph [s] · the form [s]
Paths: Lock Screen control [n] · Control Centre [n] · home screen [n] · system Camera first [n] · other [n]
Tickets: printed [n] · receipt [n] · digital [n]
Light: lit [n] · dim [n] · street [n]   One hand: [n] of 5

Errors: [each, counted]
Fields corrected before Keep: [n people], [which]
Fields wrong after Keep: [n people], [which]
The model changed a field while they looked: [n] of [3]; waited for it: [n]

Verdict: pass / fail. [One line: what changes.]
```
