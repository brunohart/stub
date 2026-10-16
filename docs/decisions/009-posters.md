# 009 · The film's own poster, and what it costs the label

**Date** 2026-10-17 · **Status** built and dormant; the privacy label and TMDB's commercial terms await Bruno

## The decision

Every edition prints its film's official poster, in the movement's own process and inks, inside the movement's own hero
(ADR-049). Bruno asked for it: the card should carry the film itself, so each one holds up as an artefact, while the
point of view (the movements, the hand, the press) stays Stub's. The poster comes from The Movie Database, the source
Bruno chose, because its catalogue covers every release a cinema shows and its terms allow app use under licence.

## The evidence

- **Recognition.** A card that carries the film's own image is that film's at a glance in the drawer and in a shared
  clip, before a word is read. Until now the drawing was the release's own but the picture was nobody's.
- **Not a template.** The same poster comes out as eight different prints across the movements (the specimen is in
  ADR-049's screenshots), and two releases in one movement differ by their poster as well as their seed.
- **Craft, not a filter.** Each movement prints a photograph the way its own press did: halftone, line screen, rings,
  cut paper, hatching, a blind pressing. That is the opinion, and it is the app's.

## What it costs: the label

Decision 006 holds Stub to **Data Not Collected**. Apple counts data as collected when it leaves the phone in a way
that lets the developer *or a third-party partner* keep it longer than the request needs. A poster lookup sends TMDB
the film's title and the year it was seen. TMDB is a third party, and its servers can log the request. Read plainly,
the label then becomes **Data Not Linked to You**, most likely under *Search History*, or *Other Data*. Apple's
optional-disclosure exception does not cover it: the lookup is automatic, not chosen each time.

Until Bruno decides, **the build makes no request**. The token lives only in `Config/Secrets.xcconfig`, which is
gitignored; without it `Posters.available` is false, no title leaves the phone, the Your card choice is hidden, and the
label is untouched.

**The choices, for Bruno:**

1. **Accept the label change** (recommended if the posters ship). *Data Not Linked to You: Search History.* Nothing is
   linked to a person; there is no account and no identifier, and the session is ephemeral. The README's opening line
   and decision 006 then say so.
2. **Off by default.** Each person turns posters on in Your card. The label still changes, because the lookup is not
   chosen each time, but fewer titles leave.
3. **Don't ship posters.** The code stays dormant and the editions print as before.

## What it costs: rights

- **TMDB's terms.** Free use is non-commercial. Stub sells the icon drawer, so it needs **TMDB's commercial licence**
  before release. Their notice is in Your card ("This product uses the TMDB API but is not endorsed or certified by
  TMDB"); their logo is needed beside it, and Bruno has to supply it.
- **The posters themselves.** TMDB does not license the images. They belong to the studios and distributors. Showing a
  film's poster beside the film is common practice (every film app does it). Reworking it into a print, and letting
  people share that print in a clip, goes further. Bruno should take advice before release, or ask TMDB what their
  commercial licence covers.
- **Marketing.** Posters stay out of every marketing asset, as real film and cinema names do. The screenshots use the
  fictional stand-ins `scripts/make-posters.py` draws.

## What was killed

- Shipping the token in the repository, or a build that asks TMDB before the label is decided.
- A proxy server to hide the requests: Stub has no server (decision 006), and a server would collect the same data.
- Pasting the poster on the card: it would turn the edition into a frame for someone else's design.
