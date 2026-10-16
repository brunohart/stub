# Proof outside us

Everything known about Stub so far was measured in the simulator or done by Bruno. Nothing has been tried on a phone, and
nobody else has kept a ticket in it (decision 007). This folder is how that changes: four kits, each run with people
outside the team, each with its result decided before it is run.

A kit is ready to run as written: who to find, what to say, what to time, what to write down, and which result keeps the
plan and which changes it.

## What counts as proof

Something a person outside the team did or said, measured where the privacy promise allows. Stub's App Store label is
"Data Not Collected": no analytics, no server of ours, no account. Nothing about anyone can be measured from inside the
app, so none of these kits asks it to.

| Source | What it gives | What it cannot give | When |
|---|---|---|---|
| **TestFlight, in App Store Connect** | Per tester and build: installed or not, sessions, crashes, screenshot feedback. Apple collects it, not Stub. | What anyone kept. Sessions for testers who do not share usage data. A widget glance. | The cohort |
| **People's own words** | Check-ins, the survey, what someone says at the exit or in a session. | Anything they forgot or would rather not say. | Every kit |
| **Observation, with consent** | Times, paths, errors, the words said while doing it. | More than the few people watched. | The exit test, the VoiceOver session |
| **Field reports shared by hand** | MetricKit's daily reports, kept on the phone; the person shares them from Your card, seeing what they send. Carries the capture's `Keepable` interval on a real phone. | Anything from someone who does not send them. | The cohort's last week, if the build has `FieldMetrics` |
| **App Store Connect App Analytics** | Aggregated installs, sessions and retention from people who opted in to share with developers; nothing below a threshold of 5. | Anything before launch. Anyone who did not opt in. | After launch |
| **Xcode Organizer** | Launch time, hangs and crashes from people who share with developers, by build. | Anything per person. | TestFlight and after |

None of these is Stub collecting data, so the label stays true while every kit runs.

What does not count: Bruno's own drawer, the simulator, a friend saying it is lovely, and any number given without how
many people it came from.

## The four kits

| Kit | The question | Who | How long |
|---|---|---|---|
| [The exit test](exit-test.md) | Can a stranger walking out of a cinema keep their ticket in under ten seconds, unaided? | 5 strangers at one cinema's exit | One or two evenings |
| [The TestFlight cohort](testflight-cohort.md) | Do cinema-goers keep every night's ticket, and do they still open Stub when nobody asks them to? | 30 to 50 people who go twice a month or more | 30 days asked, 7 days unasked |
| [The survey](pmf-survey.md) | Would the people who use it be very disappointed without it? | Cohort testers with 3 or more stubs over 2 weeks or more | Sent from day 21 |
| [The VoiceOver session](voiceover.md) | Can every common task be done with VoiceOver alone? | 1 daily VoiceOver user, 2 if a task fails | 60 minutes |

## The order

The moment comes first because it is the product (decision 001). A month of 40 people's cinema nights is too much to
spend on a moment that does not work.

| Step | What | Waits on | Week |
|---|---|---|---|
| 0 | The account and the phone: the Program License Agreement, signing, `docs/device.md` §3 on Bruno's phone, the CloudKit schema deployed to Production, an internal TestFlight build | BEDIP-217 | 0 |
| 1 | **The exit test.** Two test phones are Bruno's own, so the internal build is enough and no Beta App Review is needed. | Step 0 | 1 |
| 2 | Beta App Review of the same build (or the exit test's fix). Recruit the cohort while it is in review. | Step 1 passing, or its fix | 1–2 |
| 3 | **The cohort** starts: everyone invited on the same day. | Review passed, 30 or more selected | 2 |
| 4 | **The VoiceOver session**, on the cohort's build. The participant installs from TestFlight as an external tester. | Step 3 | 3–4 |
| 5 | **The survey**, to each tester as they become eligible. | Day 21 of the cohort | 5–7 |
| 6 | Read everything together; write the results and the decision that follows. | Day 40 of the cohort | 8 |

If the exit test fails, step 2 waits for the fix and a second exit test with five new people. Nothing else moves first.

## Decision rules

Each kit's own page has the detail and the reasoning. These are fixed now, before any result. Changing a threshold
afterwards is a new dated line in the kit saying what changed and why, never an edit.

| Kit | Keeps the plan | In between | Changes the plan |
|---|---|---|---|
| **Exit test** | 5 of 5 keep their ticket unaided, median under 10 s | — | Any one fails unaided: the step where they failed is the next build's first job, then five new people. Median 10 s or more: the laps say where the time goes; cut there, then five new people. |
| **Cohort** | Every gated measure at or above its bar (activation 80%, first night 70%, second night 70%, keep rate 80%, unasked 40%) | Any measure between its two bars: read the reasons, fix the top one, run that measure again | Any measure below its lower bar (60%, 50%, 50%, 60%, 25%): see the reading below |
| **Survey** | 40% or more very disappointed, 20 or more eligible answers | 25% to 39% | Under 25%: the product as built has no core yet. 40% in one segment only: that segment becomes the first audience. |
| **VoiceOver** | Every common task done unaided: the Accessibility Nutrition Label for VoiceOver can be claimed | — | Any task not done unaided: no claim. The task is fixed and run again with the same or a second participant. |

### Reading them together

- **Exit passes, keep rate low.** The act is quick but not remembered. The fix is reach (decision 002: the Control, the
  widget), not speed.
- **Exit fails, keep rate high.** People keep their tickets anyway, later, at home. The ninety seconds after the film may
  be the wrong moment; decision 001 is reopened, not patched.
- **Keep rate high, survey under 40%.** They keep because they were asked, and would not miss it. The afterglow is not
  yet worth the ten seconds; the work goes where the very disappointed say their benefit is.
- **Survey 40% or more, unasked under 25%.** Loved while asked, dropped when not. Run the survey again at day 60 before
  believing either number.
- **VoiceOver fails a task.** No label claim, whatever the rest says. The failing task is fixed before launch.

## What may be claimed, and with what

| Claim | Needs | Said as |
|---|---|---|
| "Keep a ticket in under ten seconds" | The exit test's median under 10 s, every person unaided | "Five strangers at a cinema exit kept their tickets in a median of N s", N as measured |
| "People keep every night" | Never claimed as such | "Testers kept N% of their cinema nights", with n and that they were asked to |
| A survey number | 20 or more eligible answers | Inside the case study only, with n and how testers were found. Never on the store page. |
| The VoiceOver label | Every common task done unaided, on the build that ships | The label itself, in App Store Connect |
| "Data Not Collected" | Already true; the kits do not change it | The label |

## Rules for every kit

- **No names, faces, emails or tickets in this repo.** Results are counts and times, written to
  `docs/proof/results/YYYY-MM-DD-<kit>.md`. Anything with a person in it lives in a private sheet outside the repo and is
  deleted when the kit's page says so.
- **No real cinema or film names in anything public**, and none in the results either. Where an example is needed, use
  fictional ones: the cinema is The Kingsway Picture House, the film is A Quiet Harbour.
- **Report n, and report the failures.** A result with the failures left out is not a result.
- **Personal data held for a kit is held as the Privacy Act 2020 expects:** only what the kit needs, said why at the
  point it is asked, kept private, shown or corrected on request, deleted when done.
- **Fix the build before the people.** No new build mid-cohort except to fix a crash or a loss of data, and every build
  shipped during a kit is written in its results with the date.
