# 001 · Stub is for one moment: walking out of the cinema

**Date** 2026-10-16 · **Status** decided

## The decision

Stub is built for the ninety seconds after the lights come up: the credits are still rolling or you are already in the
foyer, the ticket is in your pocket or your inbox, and the phone is coming out of your pocket anyway to switch it back on.
Everything Stub does is judged by whether it makes **keeping tonight** take less than ten seconds, one-handed, in a dark
foyer, with someone talking to you, and with no signal.

Everything else (the drawer, the editions, the press, the season) is the **afterglow**: what you get back later for
having kept it. The afterglow is why the moment is worth ten seconds; it is never allowed to cost the moment a second.

## The person

Someone who goes to the cinema two or more times a month, in a city with both chains and independents (the first
audience is Aotearoa New Zealand: Event, Hoyts, Reading, Lighthouse, Rialto, and the independents). They keep things:
the stub goes in a wallet, a phone case, a drawer, a shoebox; or they used to, and the tickets went digital and the
keeping stopped. They probably log films somewhere already. What they do not have is the night itself: which cinema,
which seat, who with, what it cost, that it was the third time.

In the moment they have:

- **One hand.** The other holds a coat, a drink, a door, a person.
- **Low light.** Foyers and streets at night; thermal paper that is already fading.
- **Thirty to ninety seconds of attention**, while walking and talking.
- **Maybe no signal**, in a basement cinema or a car park.
- **Two kinds of ticket:** paper (a printed stub or a thermal receipt) or digital (a Wallet pass, a PDF, a booking email,
  a screenshot from a cinema's app).

## What this decides

1. **The fastest path is from a locked phone to the viewfinder.** Not to the drawer. Keep a stub already opens the
   camera (ADR-025); the lock screen and the Action button must reach it without the home screen (decision 002).
2. **Keeping never waits for the model.** The rules read the ticket in milliseconds; the model may improve the draft
   while the person is looking at it, but the Keep button is live the moment the rules have a title, and a model that is
   slow is let go (budget in decision 004).
3. **Nothing is asked in the moment that can be asked later.** No drawer to choose, no edition to approve, no
   permission prompt but the camera's. Filing, the press and the season wait for the afterglow.
4. **Digital tickets are kept from where they already are.** A pass in Wallet, a PDF or email in Mail, a screenshot in
   Photos: shared into Stub from the share sheet, or arriving through a cinema's own Add to Stub link (ADR-021, 023).
5. **On device, always.** No signal is a feature of the moment, not an edge case. That is also the privacy promise
   (ADR-005, decision 006).

## The evidence

- The capture path already measured in the simulator: crop + Vision median 1.4 s, rules 2 ms, the model 12–15 s median
  and up to 36 s (`docs/evals.md`, 2026-10-16). Waiting for the model in a foyer is not acceptable; the rules are.
- The rules read every field of all eleven synthetic fixtures; the cold model missed one cinema (`docs/evals.md`).
  Whether that holds on real tickets is decision 008's job.
- The hypothesis itself is not yet tested on people. Decision 007's unaided-capture test at a real cinema exit is the
  test: five strangers, timed, no help.

## What was killed

- **"Stub is an archive you browse."** The archive is the reward, not the product. Nothing on the home screen may slow
  down the way to the camera.
- **Logging as a diary.** No ratings, no reviews, no watchlist: other apps do that, and every one of them is a field to
  fill in at the exit.
- **Accounts.** Nothing to sign in to at the exit (ADR-028's Your card is a reader's card, not an account).
