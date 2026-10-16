# The corpus

Real tickets, to measure the reader against the world rather than against tickets we drew ourselves (`fixtures/` are all
synthetic). **Nothing in this folder but this README and `labels.example.json` is committed**: real tickets carry names,
booking references and the nights someone went out, and the repo is public. `.gitignore` keeps the rest local.

## Put tickets here

One folder per kind. A file's kind is its folder.

| Folder | What goes in it | How Stub reads it |
|---|---|---|
| `paper/` | a printed stub, photographed (JPEG/HEIC/PNG) | crop → Vision → reader |
| `thermal/` | a thermal receipt-style ticket, photographed; faded ones especially | crop → Vision → reader |
| `pdf/` | an e-ticket PDF as the booking system sent it | the PDF's own text → reader (Vision if image-only) |
| `wallet/` | a `.pkpass` exported from Wallet or the confirmation email | the pass's own fields |
| `screenshot/` | a screenshot of a ticket in a cinema's app or email | Vision → reader |
| `email/` | a booking confirmation email, saved as `.eml` from Mail | the email's own text → reader |

Name files plainly: `event-queen-st-2025-03.jpg`. The names never leave this folder.

## Say what each ticket says

Copy `labels.example.json` to `labels.json` and add one entry per file, written from the ticket, not from what Stub read.
`circuit` is the chain (or `independent`); `condition` is free words for what makes it hard (`faded`, `crumpled`, `glare`,
`two tickets on one PDF`). An empty string means the ticket does not print that field.

## Run it

```
scripts/eval.sh --corpus
```

writes `docs/evals-corpus.md`: per kind, per field, how often the rules and the on-device model got it right, and how
long each took. That report has counts and rates only, never a title, cinema, seat or reference from a real ticket.

## What the corpus needs

At least five of each kind, from at least three circuits and three independents, with thermal and faded paper well
represented, because those are what people actually have in their pockets. The report lists what is short.
