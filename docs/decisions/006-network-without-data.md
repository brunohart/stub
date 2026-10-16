# 006 · Network effects without collecting data

**Date** 2026-10-16 · **Status** decided; free or paid is Bruno's call

## The constraint

Stub's App Store privacy label stays **Data Not Collected**. Apple's definition: data is *collected* when it is sent off
the phone in a way that lets the developer (or anyone working with them) keep it longer than the request needs. Stub has
no server, no analytics, no account. So every loop below runs on things people choose to do themselves, on Apple's own
aggregated reports, and on the cinema's own tools. Nothing comes back to Stub about anyone.

## 1. The growth loop: the share

**The loop.** Keep a stub → its edition, designed for the film's release → share it to a Story, a 9:16 clip of the card
turning in the light → a friend sees it, with the cinema and the film on the card and "shared in Stub" blind-embossed
under it → finds Stub → keeps their own.

**Non-intrusive by construction.** No prompt asks anyone to share, no reward for sharing, no referral code. Share sits
where a phone keeps it (ADR-030) and the only mark on a share is the embossing (ADR-022). The loop works because the
artefact is worth posting, or it does not work.

**Measuring k without tracking.** k = *i* × *c*: shares per keeper per month, times installs per share.

| Term | Where it comes from | What it is not |
|---|---|---|
| Installs from shares | The share's link now says which share it was (`designedbybruno.net/stub?via=clip`, `card`, `still`). The site passes `via` to the App Store as a campaign token (`ct=share-clip`, …). App Store Connect counts first-time downloads by campaign, aggregated, from people who opted in, at 5 or more. | Anyone who saw a clip and searched for Stub instead of tapping (they count as App Store Search): measured k is a **floor** |
| Keepers | App Store Connect's active devices (opted-in sample); in the TestFlight cohort, sessions per tester | Anyone who did not opt in to share with developers |
| *i*, shares per keeper | The cohort's weekly check-in ("did you share an edition this week?") and the survey | A count from inside the app: there is none |

k for a keepsake app will be well under 1, and that is fine: the point is that every install that came from a share cost
nothing. **The bar to test:** at least 0.1 attributed installs per active keeper per month from shares, measured over
the first three months after launch.

**Built now.** The `via` parameter on every share's link (`ShareLinkText.link(via:)`). **Waits on BEDIP-217:** the App
Store record, its provider token, and the site's redirect from `?via=` to the campaign link (designedbybruno.net).

## 2. The cross-side effect: Add to Stub

**What the cinema puts on its confirmation.** The open link (ADR-021, `docs/add-to-stub.md`): one button, the ticket's
fields in the URL's fragment so they never reach a server, opening Stub's import sheet prefilled. Free to adopt, no SDK,
no account, a JavaScript and a Python builder in the spec.

**What the cinema gets back, without data.**

1. **Its name in its audience's pockets and Stories.** Every edition prints the cinema on its strip; every shared clip
   carries it. Placement it cannot buy, earned by its own audience.
2. **Tickets kept exactly right.** A ticket that arrives by link is kept at full confidence with no camera and no
   reading, so a cinema's keepsakes never carry a misread title.
3. **Its own measure, with its own tools.** The button sits in the cinema's email, so its email platform counts the
   taps. Stub reports nothing back and needs nothing.
4. **(Next, the paid side.) A house style.** A cinema can have its own palette and type on the editions printed from its
   tickets, drawn from Stub's closed vocabulary so it never breaks the design, carried by the link's reserved `sig`
   parameter so it cannot be forged.

**The effect.** More cinemas with the button → more tickets arrive perfect and branded → more people keep and share →
more taps in each cinema's own email reports → more cinemas add the button.

## 3. The data network effect: formats, never contents

**What is shared.** A ticket's **shape**: which labels a cinema's ticket prints and in what order ("SCREEN {screen}
SEAT {seat}", "ADULT {money}"), never the values. When the reader got a ticket wrong and the person corrected it, the
press offers one quiet line: *"Stub misread this cinema's ticket. Send its shape, never what it says, so the next one
reads right."* It opens Mail with the shape written out (`TicketFormat`): every value the person kept replaced by its
field, every date, time, price and figure by its shape, and **every other word blanked unless it is one of ~100 words
tickets print as labels**, so a name or a booking reference cannot leave even if a ticket prints one. The person sees all
of it and sends it, or does not. Infrequent, optional, sent by hand each time, visible in full: Apple's optional-
disclosure case, so the label does not change.

**What comes back.** Bruno turns the shapes into rules for the parser and ships them in the next update, so that
cinema's tickets read right for everyone. More keepers → more cinemas' shapes → better reads for every keeper, on every
phone, including the oldest, which have no on-device model.

**DPLA §3.2(h)(2).** The Apple Developer Program License Agreement forbids using output generated from an Apple model to
train, fine-tune or improve another AI model. The format network is clear of it by construction:

- A shape is built from the ticket's own text (Vision's reading) and the person's own corrected fields, never from the
  Foundation Models answer (`TicketFormat.of(_:kept:)` takes the reading and the kept draft, nothing from the model).
- Shapes become hand-written rules for a deterministic parser. No model is trained, fine-tuned or improved.
- Apple's model is not improved by them either.

**Waits on Bruno:** the address the shapes are sent to (`formats@designedbybruno.net`, a constant in `ShapeOffer`) has to
exist before the first TestFlight build.

## 4. The atomic network

**One independent cinema with a members' programme, and its regulars.** Not a chain: a chain's audience is diffuse and its
tickets come from one national system. An independent's audience is a community that overlaps in real life and in each
other's feeds.

A worked example, with a fictional cinema: *The Kingsway Picture House*, one screen, about 2,000 members, about 300 who
come twice a month. The loop sustains itself when:

- **Supply:** the Kingsway's confirmations carry Add to Stub, and its paper ticket's shape is in the parser, so every
  ticket is kept right whichever way it arrives.
- **Demand:** about 50 members keep their stubs. At two films a month and one share in five, that is about 20 clips a
  month into a few hundred overlapping local feeds: a member who knows another member sees a Kingsway clip most weeks.
- **The turn:** a friend who goes to the Kingsway sees the clip, keeps their next ticket, and their clips reach the next
  ring.

Below about 50 keepers the clips are too rare to be seen; above it each new keeper raises the odds for everyone they
know. The go-to-market is one such cinema at a time, starting in Wellington or Auckland.

## 5. The business model

Stub never sells data, never shows an ad, and never charges for the moment: keeping a ticket, the drawer, the edition,
the press and the season are the product, and a paywall at the cinema door would break both the moment and the network,
which needs installs. It earns from craft and from cinemas. **People** pay once for craft they choose: the icon drawer
(built, US$4.99, ADR-028), and later editions packs (more movements, more stocks); no subscription, nothing renting the
keepsake back to its owner. **Cinemas** pay a yearly fee for a house style on the editions printed from their tickets and
a verified, signed Add to Stub link, in return for attention and a better moment after the purchase, never for data
about their audience. **Free or paid to download is Bruno's decision.** The recommendation is a free download with
one-time purchases, because the network effects above all start from installs.

## What was killed

- An ad-supported or data-funded model.
- Any analytics or attribution SDK, and referral codes or rewards for sharing (each is tracking).
- A server for formats: the shapes come back in app updates, so Stub stays a phone-only app.
- Selling audience insight to cinemas.
- Contacts upload, a friend graph, or a feed inside Stub: the network lives in people's own Stories and inboxes.

**Later.** [009](009-posters.md) asks for the first exception: the film's title to TMDB for its poster. It is built and
dormant, and the label stays Data Not Collected until Bruno decides.
