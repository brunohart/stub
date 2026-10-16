# 008 · The corpus: real tickets, measured by kind

**Date** 2026-10-16 · **Status** decided; the corpus is empty until Bruno adds tickets

## The decision

Stub's reading is measured on **real tickets**, by the kind of ticket a person actually has, on both paths: the rules
alone (all an iPhone 11 or SE has) and the on-device model with the rules' draft as its hint (iPhone 15 Pro and later).
The tickets live in `corpus/` on Bruno's Mac and never in git: they carry names, booking references and the nights
someone went out, and the repo is public. The report, `docs/evals-corpus.md`, is counts and rates only, never a title,
cinema, seat or reference from a real ticket. `scripts/eval.sh --corpus` writes it (`StubTests/CorpusEvalTests.swift`).

Each kind is read the way the app reads it:

| Kind | Folder | Path |
|---|---|---|
| A printed stub, photographed | `paper/` | crop → Vision → rules → model |
| A thermal receipt-style ticket, photographed | `thermal/` | crop → Vision → rules → model |
| A PDF e-ticket | `pdf/` | its own text (Vision on its page if it has none) → rules → model |
| A Wallet pass | `wallet/` | the pass's own fields; the rules fill what it leaves out |
| A screenshot of a ticket in an app or email | `screenshot/` | Vision on the whole picture → rules → model |
| A booking confirmation email | `email/` | its own words (`Email.text`, `Booking.lines`) → rules → model |

## The evidence

- **Everything measured so far is synthetic.** `fixtures/` holds eleven tickets drawn by `scripts/make-fixtures.swift`
  and `make-digital.swift`, plus three made-up passes. On them the rules read 66 of 66 fields, the cold model 65 of 66,
  and the model with the rules' hint 66 of 66 (`docs/evals.md`, 2026-10-16). That proves the pipeline; it says nothing
  about a crumpled thermal receipt under a foyer light.
- **No real ticket has been read.** `corpus/` was created on 2026-10-16 and is empty.

## What is missing, exactly

The report's first table counts each kind against a minimum of five before a rate is quoted. As of 2026-10-16 every
kind is short:

| Kind | Have | Need | Also wanted |
|---|---|---|---|
| paper | 0 | 5 | at least 2 crumpled or folded; 1 under glare |
| thermal | 0 | 5 | at least 2 faded (months in a wallet); 1 with a long receipt tail |
| pdf | 0 | 5 | 1 with two tickets on one PDF; 1 image-only (scanned) |
| wallet | 0 | 5 | passes from at least 2 different booking systems |
| screenshot | 0 | 5 | 1 from a cinema's own app, 1 from an email |
| email | 0 | 5 | 1 HTML-only; 1 forwarded |

Across all kinds: at least three chains and three independents, and at least one ticket from outside New Zealand (the
European fixture is the only one today).

## What was killed

- **Publishing real tickets as fixtures.** Redacting a real pass well enough for a public repo loses what makes it real;
  the synthetic fixtures stay the public, repeatable test, and the corpus stays private.
- **A single accuracy number for the README.** Accuracy is quoted per kind and per path, with how many tickets it came
  from, or not at all.
