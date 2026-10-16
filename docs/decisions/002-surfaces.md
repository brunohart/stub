# 002 · The surfaces that reach the moment without opening the app

**Date** 2026-10-16 · **Status** decided

## The decision

Each surface is judged by one question: does it make keeping tonight faster from where the ticket already is?

| Surface | State before | Verdict | Why |
|---|---|---|---|
| **Control: "Keep a stub"** (Lock Screen, Control Centre, Action button) | absent | **Build** | The shortest path in iOS from a locked phone to a camera that is Stub's. One press from the pocket. |
| **App Shortcut "Keep a stub"** (Siri, Spotlight, Action button) | built as "Log a stub" | **Keep, renamed** | Same act, the app's own words ("Keep a stub" is the dock's button). |
| **Share extension** | passes, PDFs, images | **Keep, widen to text** | Digital tickets live in Wallet, Mail and Photos. A booking email's text is the most common ticket of all and it could not be shared in. |
| **Add to Stub link** | built (ADR-021) | **Keep** | The cinema puts it on the confirmation; the ticket arrives already read. The network's supply side (decision 006). |
| **Widget** (Home Screen, small/medium/large) | built: the edition | **Keep** | Not the moment: the afterglow. It brings people back between films, which is what retention is. |
| **Lock Screen widgets** (rectangular, inline) | built: the last film in text | **Keep rectangular, cut inline** | The rectangular one is a quiet "last night"; the inline one is a line of text nobody reads, and the Control now owns the Lock Screen act. |
| **Spotlight** (stubs as indexed entities) | absent | **Build, small** | Retrieval, not capture: "when did I see Anora?" answered from search, and the same entity gives Siri and Shortcuts a query. Cheap once stubs are App Entities. |
| **Live Activity** | absent | **Don't build** | Nothing is ongoing. A film is two hours of the phone being off; a Live Activity is for watching progress. |
| **Notifications** | absent | **Don't build** | A permission prompt and a nudge are the opposite of a keepsake. The cinema's Wallet pass already surfaces at the venue. |
| **"Films this year" intent** | built | **Keep** | Costs nothing; it is the season, asked aloud. |

## The evidence

- The surfaces that exist and their state come from the code (2026-10-16): one widget kind with Turn and Another
  buttons, two App Shortcuts, a share extension that accepts one pass, PDF or image and leaves it in the App Group inbox,
  the Add to Stub universal link, no Control, no Spotlight, no Live Activity.
- Controls (iOS 18) are the system's own place for "one action, from anywhere, including the Lock Screen and the Action
  button"; an App Shortcut alone needs Siri or a Shortcuts setup the person has to know to do.
- The share sheet's activation rule accepted `com.apple.pkpass`, `com.adobe.pdf` and `public.image` only
  (`project.yml`); a confirmation email selected and shared arrives as `public.plain-text`.

## What was killed

- The inline Lock Screen widget.
- A Live Activity for "tonight's film" and an end-of-film notification: both considered, both are the app asking for
  attention in the one place the person wants none.
