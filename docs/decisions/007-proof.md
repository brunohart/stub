# 007 · Proof outside us

**Date** 2026-10-16 · **Status** decided

## The decision

Nothing about Stub is claimed in public (on the store page, in the case study, to a cinema) until people outside the
team have shown it. Four kits in `docs/proof` do the showing, each with its result fixed before it is run:

| Kit | What it proves | The bar |
|---|---|---|
| [The exit test](../proof/exit-test.md) | The moment: five strangers keep their own ticket at a cinema exit, timed, with no help | All five unaided, median under 10 s (decision 001) |
| [The TestFlight cohort](../proof/testflight-cohort.md) | The habit: 30 to 50 people who go twice a month keep every ticket for 30 days, then open Stub in the week nobody asks | Activation 80%, first night 70%, second night 70%, keep rate 80%, unasked 40% |
| [The survey](../proof/pmf-survey.md) | The product: would they miss it | 40% or more "very disappointed" |
| [The VoiceOver session](../proof/voiceover.md) | The label: every common task with VoiceOver alone | Every task unaided |

They run in that order. The exit test is first because the moment is the product and the test needs only Bruno's two
phones on an internal build, with no Beta App Review; the cohort runs only on a build that passed it.

Proof comes only from places that leave the privacy promise as it is: TestFlight's own data, which Apple collects;
people's own words, asked outside the app; observation, with consent; and after launch, App Store Connect's aggregated
analytics. Stub itself measures nothing and asks nothing.

Results are counts, written to `docs/proof/results/` and never rewritten. A result that misses a bar changes the plan in
the way its kit says it will, decided now rather than after the number is known.

## The evidence

- **Nobody but Bruno has used Stub.** Every number in the repo is the simulator's: the reader's hit rates and latencies
  (`docs/evals.md`, `docs/evals-deep.md`), the springs, the share. A Release build for a phone compiles with no
  warnings but has never been signed or run on one (`docs/device.md`).
- **It cannot be yet.** BEDIP-217 is open. The first signed archive, on 2026-09-30, was refused by the account, not the
  code: "PLA Update available: You currently don't have access to this membership resource." Until the Program License
  Agreement is accepted every provisioning request is refused, so there is no TestFlight build and no tester, internal
  or external.
- **The moment is still a hypothesis.** Decision 001 says so: under ten seconds, one-handed, in low light, with no
  signal, is a target nobody has timed on a person.
- **The app cannot measure people, by design.** No network calls, no analytics, no account (ADR-005). The privacy
  manifest declares no tracking and no collected data, and the label is "Data Not Collected". Whatever is learned about
  people has to come from outside the app.
- **Apple already collects what a beta needs.** TestFlight takes up to 10,000 external testers after Beta App Review,
  keeps a build for 90 days, and shows each tester's installs, sessions, crashes and screenshot feedback in App Store
  Connect. Sessions are counted only for testers who share usage data; the cohort's kit reads that as a limit, not a
  fault.
- **The bars are public.** Sean Ellis's question and its 40% line, and Superhuman's way of segmenting the answers (First
  Round Review, 2018-11-13). Apple's criteria for the VoiceOver label: every common task, VoiceOver alone.

## What was killed

- **In-app analytics.** Any event log, a vendor's or home-made, sent anywhere. It would end "Data Not Collected", and put
  a network call into an app whose moment assumes there is no signal.
- **A feedback SDK.** An in-app bug reporter, shake to report, session replay. A third party in the privacy manifest for
  what TestFlight's screenshot feedback already does, and the label would go with it.
- **An in-app survey prompt.** A sheet after the third stub asking how you would feel without Stub. It interrupts the
  keepsake while it is being enjoyed, and its answers would need a server to go to. The
  survey is a link in an email and in TestFlight's notes, outside the app.
