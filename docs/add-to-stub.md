# Add to Stub

A link that hands a cinema ticket to Stub. Put it on a booking confirmation, an e-ticket or a receipt, and the person who booked can keep the ticket in Stub with one tap. Nothing is sent to anyone: the ticket travels inside the link, and Stub opens it on the phone.

```
https://designedbybruno.net/stub/add#title=La%20Chimera&cinema=Academy%20Cinemas&at=2026-10-18T19:30%2B13:00&screen=2&seat=F7
```

## What happens when it is tapped

**Stub is on the phone.** Stub opens on its import sheet with the ticket filled in and a line saying it was handed over in a link. The person keeps it or lets it go; nothing is filed until they say so. Once kept, the stub is in their drawer, it gets its edition, and it says it was read by a link.

**Stub is not on the phone.** The link opens a page on designedbybruno.net that shows the ticket as it was handed over and says where to get Stub. The page reads the fields in the browser and sends them nowhere.

In both cases nothing is fetched to open the ticket, and no server sees it. That is why the fields go after `#`: a fragment never leaves the browser, even when the page has to open.

## The fields

| Field | | What it is | Example |
|---|---|---|---|
| `title` | required | The film, as the ticket names it. | `La Chimera` |
| `cinema` | | The cinema, as the ticket names it. | `Academy Cinemas` |
| `at` | | When the film starts: ISO 8601 with the cinema's offset. A date alone is allowed. | `2026-10-18T19:30+13:00` |
| `screen` | | The screen or auditorium, as printed. | `2` or `IMAX` |
| `seat` | | The seat, as printed. | `F7` |
| `price` | | What was paid for this ticket: digits, a dot for the decimals, no symbol. | `19.50` |
| `currency` | | The ISO 4217 code for `price`. Ignored without a price. | `NZD` |
| `ref` | | Your booking reference. Stub keeps it with what the link said and prints it nowhere. | `AC-55120` |

One ticket a link. A booking of four seats is four links, or one link for the seat of the person the email is for.

**Times.** Give the offset of the cinema's time zone on that night: `+13:00` for Auckland in October, `+12:00` in June. `Z` and `+1300` are read too. A time with no offset is taken as the phone's own time zone, which is right only if the person is at home. A date alone (`2026-10-18`) files the ticket for that day with no time.

**Encoding.** Percent-encode every value (JavaScript's `encodeURIComponent` does it right). A space is `%20`; `+` is read as a space, as forms send it, so a plus in a title is `%2B`, and so is the plus in `at`'s offset.

**The query works too.** `…/stub/add?title=…` is read exactly as the fragment is, but its fields reach the web page's server when Stub is not installed. Prefer `#`. If a link has both, the fragment wins.

## What Stub does with bad input

Each field is read on its own, and a field that cannot be read is left out rather than guessed at. The rest of the ticket still opens.

- A date that is not a date (`2026-02-30`, `tomorrow`, `18/10/2026`) is left out.
- A price with a symbol or a sign (`€12.50`, `-3`) is left out; so is a currency that is not three letters.
- Words are cut at 200 characters; line breaks and control characters become spaces.
- Fields Stub does not know are ignored.
- Without a title the sheet still opens, and the person types the title before they can keep it.

## The button

Email-safe HTML, a table rather than a styled link so it survives Outlook:

```html
<table role="presentation" cellspacing="0" cellpadding="0" border="0">
  <tr>
    <td style="background:#1A1A1A;border-radius:6px;">
      <a href="https://designedbybruno.net/stub/add#title=La%20Chimera&cinema=Academy%20Cinemas&at=2026-10-18T19:30%2B13:00&screen=2&seat=F7&ref=AC-55120"
         style="display:inline-block;padding:13px 20px;font-family:Helvetica,Arial,sans-serif;font-size:16px;color:#F0EDE6;text-decoration:none;">
        Keep in Stub
      </a>
    </td>
  </tr>
</table>
```

Making the link:

```js
const fields = { title: "La Chimera", cinema: "Academy Cinemas", at: "2026-10-18T19:30+13:00", screen: "2", seat: "F7", ref: "AC-55120" };
const link = "https://designedbybruno.net/stub/add#" +
  Object.entries(fields).map(([k, v]) => `${k}=${encodeURIComponent(v)}`).join("&");
```

```python
from urllib.parse import quote
fields = {"title": "La Chimera", "cinema": "Academy Cinemas", "at": "2026-10-18T19:30+13:00", "seat": "F7"}
link = "https://designedbybruno.net/stub/add#" + "&".join(f"{k}={quote(v, safe='')}" for k, v in fields.items())
```

A whole sample confirmation, with the button where a person looks for it, is [`add-to-stub/confirmation.html`](add-to-stub/confirmation.html).

## Shortcuts

Stub's **Keep a ticket** action takes the same fields (film, cinema, screening, screen, seat, price, currency, booking reference) and opens the same sheet. An app that would rather call an intent than open a URL can use it, and so can a person's own shortcut.

## Reserved

- `sig`: a signature over the other fields, so a partner's links can be shown as from that partner. Not read yet; a link with it opens as one without.
- `v`: a version, if the fields ever change. This page is version 1, and a link without `v` is version 1.

## Why it is shaped like this

Stub keeps a private archive of the films a person has seen, on their phone. A cinema or a booking app that wants to offer "keep this in Stub" should not have to send Stub anything, sign up for anything or install an SDK, and the person should not have to trust that a ticket went somewhere and back. So the format is the whole integration: a link the booking system already knows how to write, read on the phone by the app it was meant for. The decision is ADR-021 in [`DECISIONS.md`](../DECISIONS.md).
