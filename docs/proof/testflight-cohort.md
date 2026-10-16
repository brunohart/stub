# The TestFlight cohort

**The question.** Do people who go to the cinema twice a month or more keep every night's ticket in Stub, and do they
still open it once nobody is asking them to?

**Who.** 30 to 50 external testers in Aotearoa New Zealand, each going to the cinema at least twice a month, on an
iPhone 11, iPhone SE (2nd generation) or later.

**How long.** 30 days asked to keep every ticket, then 7 days unasked. About 8 weeks from the first post to the results.

**The build.** One build, the one that passed the exit test (or its fix), through Beta App Review. A TestFlight build
expires after 90 days, which covers the cohort with room to spare.

## Before the first invitation

- [ ] The build has passed the exit test ([exit-test.md](exit-test.md)) and Beta App Review for external testing.
- [ ] The CloudKit schema is deployed to Production (`docs/device.md` §4), or every tester's drawer stays on one phone.
- [ ] An external group in App Store Connect › TestFlight called `Cohort 1`, with the build added and the What to Test
      notes below.
- [ ] The sign-up form, the weekly check-in form and the survey form, outside the app, with the settings in
      [Forms](#forms).
- [ ] A private sheet, outside the repo, with the tabs in [The sheet](#the-sheet).
- [ ] The start date: a Thursday, the day new films open in New Zealand, so the cohort's weeks run with the release
      calendar. Note any school holidays or festival in the 37 days; both change how often people go.
- [ ] The dates for each snapshot and message written in the sheet before day 0 (see [Measuring it](#measuring-it)).

## Who, and where to find them

### Who qualifies

| Criterion | Asked as | Qualifies |
|---|---|---|
| Goes often | Cinema visits in the last three months | 6 or more |
| The phone | Which iPhone | iPhone 11, iPhone SE (2nd generation) or later, on iOS 26 or later |
| Where | Town or city | In New Zealand |
| Willing | The consent line on the form | Ticked |

### The mix, of 50 invited

Invite 50 to end with 30 or more who keep at least one ticket. Fill these before anything else; the rest by date of
sign-up.

| Group | At least | At most | Why |
|---|---|---|---|
| Phones with Apple Intelligence (iPhone 15 Pro or later) | 15 | — | The model's reading, on real tickets |
| Phones without it (iPhone 11 to iPhone 15 Plus, SE 2nd and 3rd generation) | 15 | — | The rules alone, on the oldest phones Stub supports |
| Mostly independents (more paper) | 12 | — | The printed stub and the thermal receipt |
| Mostly chains (more digital) | 12 | — | Wallet passes, PDFs and booking emails |
| Know Bruno personally | — | 5 | Friends are kind. Marked in the sheet and read separately. |
| Work in exhibition, distribution or ticketing | — | 3 | They see tickets differently. Marked, and left out of the headline numbers. |

### Where to find them

Real cinema names never go in a post. Ask the person who runs a group to pass the post on; never message strangers in
bulk, and never scrape a list.

- **Film societies.** Most centres have one. Write to the secretary and ask them to forward the post to members.
- **Letterboxd circles.** New Zealand members who log often: a post from Bruno's own account, and the people who run New
  Zealand lists or clubs asked to share it.
- **Festival volunteers.** The volunteer coordinators of the film festivals, asked to pass it on to last year's
  volunteers.
- **University film clubs** and film and media students' groups.
- **Local community groups**, city subreddits and neighbourhood forums, with the moderators' permission first.
- **The exit test.** A small card with the sign-up link for anyone who asks what Stub is. Never offered as part of the
  test.
- **Not** a cinema's own social accounts, mailing list or foyer, unless the cinema offers.

## The words

### The post

> **Go to the cinema twice a month? Try Stub for 30 days before it is out.**
>
> I make Stub, a small iPhone app for keeping cinema tickets. On the way out you photograph the ticket, or share in the
> e-ticket, tap Keep, and it is filed in a drawer. Each one comes back as a ticket designed for its film's release.
>
> I am looking for about 40 people in New Zealand to use it for a month before it is released: keep every cinema ticket in it
> for 30 days and answer a one-minute question each week. It is free. You need an iPhone 11, an iPhone SE (2nd
> generation) or later.
>
> Stub has no account, no ads and no analytics. What you keep stays on your phone, and in your own iCloud if you choose.
> I never see your tickets.
>
> Sign up in two minutes: [link]
>
> Bruno · designedbybruno.net/stub

### The sign-up form

Above the questions:

> This form is for the Stub test. Your answers go to Bruno, who makes Stub, and are used only to choose testers and send
> the TestFlight invitation and a weekly check-in. They are kept in a private sheet, never shared, and deleted 90 days
> after the test ends. Reply to any email from me to see, correct or delete yours.

1. First name (what to call you).
2. Email, for the TestFlight invitation and the weekly check-in.
3. Town or city.
4. How many times have you been to the cinema in the last three months? (a number)
5. Where do you mostly go? (Chains / Independents / Both about the same)
6. How do your tickets usually come? (Printed or a receipt / On my phone: Wallet, email, PDF or an app / Both)
7. Which iPhone do you use? (Settings › General › About › Model Name, if you are not sure)
8. Do you keep cinema tickets now? (Yes / I used to / No)
9. Do you log the films you see anywhere? (An app or website / A notebook / No)
10. Do you work for a cinema, a film distributor or a ticketing company? (Yes / No)
11. Do you know Bruno personally? (Yes / No)
12. [ ] I'd like to test Stub for 30 days, and I've read what happens to these answers.

### The welcome email

Sent the day the TestFlight invitations go out; Apple's invitation arrives separately, from TestFlight.

> Subject: Stub: you're in
>
> Hi [first name],
>
> Thank you for testing Stub. An invitation from TestFlight is on its way to this address. Install TestFlight from the
> App Store, then accept the invitation to install Stub.
>
> For the next 30 days: keep every cinema ticket in Stub, however it comes. A paper stub, a receipt, a Wallet pass, a
> PDF, a booking email or a screenshot. Walking out is the best time. Old tickets from a drawer at home are welcome too;
> just tell me about them in the check-in.
>
> Everything else is up to you. There is no right way to use it.
>
> Every [weekday] I'll send a one-minute check-in. Your tester code is **[T07]**; the form asks for it instead of your
> name.
>
> If something goes wrong, take a screenshot: TestFlight offers to send it to me with a note. Crop out anything on a
> ticket you'd rather not send.
>
> What you keep stays on your phone, and in your own iCloud if you choose. TestFlight tells me whether Stub crashed and,
> if your phone shares usage data with app developers, how many times it was opened. It never tells me what you kept.
> Sharing is your choice; the test works either way.
>
> Bruno

### What to Test

In the build's What to Test notes, so it is in front of every tester inside TestFlight:

> Thank you for trying Stub.
>
> For 30 days, keep every cinema ticket in Stub: a paper stub, a receipt, a Wallet pass, a PDF, an email or a
> screenshot. Walking out is the best time. Old tickets are welcome too.
>
> The weekly check-in comes by email. If something goes wrong, take a screenshot and TestFlight will offer to send it.
>
> Nothing you keep leaves your phone, except to your own iCloud.

On day 21, edit the notes to add the survey ([pmf-survey.md](pmf-survey.md)):

> If you have kept three stubs or more: the survey, [link]. Five minutes.

## What testers are asked to do

1. Keep every cinema ticket in Stub for 30 days.
2. Answer the check-in each week: one minute.
3. Send a screenshot through TestFlight when something goes wrong.

Nothing else. They are not asked to use the press, make drawers, add the widget or share an edition. Whether they do is
part of what the cohort finds out, through the survey's question on the editions.

## Measuring it

Stub measures nothing. Three things are put side by side in the sheet: TestFlight's counts, the testers' check-ins, and,
in the last week, field reports a tester chooses to send.

### The words used

- **Cohort day 0** is the day the invitations go out. Every message and snapshot is dated by cohort day, so the asked
  month ends for everyone on day 30.
- **Install day** is a tester's own: the first evening snapshot that shows the cohort build installed. Testers installed
  by cohort day 3 are the cohort; anyone later is read as a small group of their own, on their own dates, not dropped.
- **A screening** is one film seen at a cinema with a ticket. A double feature is two.
- **Kept on the night** means kept before the end of the day after the screening.
- **A session** is whatever App Store Connect counts as one. Opening the app from the Control is a session; a glance at
  the widget is not.

### The snapshots

App Store Connect › Stub › TestFlight › `Cohort 1` lists each tester with status, sessions, crashes and feedback. The
counts are running totals; a week's figure is this snapshot minus the last. Copy the table into the sheet's Snapshots
tab by hand (or through the App Store Connect API, if it has been set up; check what periods it reports before relying
on it).

| When | Why |
|---|---|
| Every evening, cohort days 0 to 3 | Each tester's install day |
| The evening of cohort days 7, 14, 21, 28 | The weekly figures |
| The evening of cohort days 30 and 37 | The unasked week, exactly: day 37's count less day 30's |
| Any evening a new build ships | The counts may restart with a build. If they do, carry the old total forward. |

### The measures

| Measure | Definition | Counted over | Source |
|---|---|---|---|
| **Activation** | Kept the ticket of a screening seen after install, within 14 days of install | Testers who installed | Check-ins, weeks 1–2 |
| **D1 · the first night** | The ticket of the first screening after install was kept on the night | Testers who went to at least one screening after install | Check-in question 11 |
| **D7 · the second night** | Kept a second stub, of a new screening within 7 days of the first one kept, on the night | Testers who went to a second screening within those 7 days | Check-in question 12, answered from the dates in their own drawer |
| **D30 · unasked** | Opened Stub at least once in cohort days 31 to 37, the week after the asking ended | Testers who share usage data and installed by cohort day 3 | Snapshots on cohort days 30 and 37 |
| **Keep rate** | Screenings kept on the night ÷ screenings seen, cohort days 0 to 30 | Each tester; reported as the median tester, and pooled | Check-in questions 2, 4 and 5 |
| **Between films** | Weeks with no screening in which Stub was opened | Tester-weeks with no screening, for testers who share | Weekly snapshot delta beside check-in question 2 |
| **Crash-free sessions** | 1 − crashes ÷ sessions | All sessions | Snapshots; the crash logs in Xcode Organizer |

Why these and not the usual "opened on day 1, 7, 30": Stub is used when someone goes to the cinema, and someone who goes
twice a month has no reason to open it on day 1 or day 7. D1 and D7 here are about the nights, so they are counted only
over people who had a night. D30 is the only one about the app itself, and it is read in two halves: testers who went to
the cinema in days 31 to 37, and testers who did not. The first half shows the habit; the second shows the afterglow.

The headline D7 uses the people who went again. The raw figure, counted over every activated tester, is written beside
it, because a low raw figure with a high headline means people did not go, not that Stub failed.

### What this cannot see

- **Sessions only for testers who share usage data.** Those testers may be the keener ones. Write how many share, and
  read D30 and Between films as theirs, not everyone's.
- **The widget.** A glance at The drawer on the home screen is the afterglow working, and it is invisible here. The
  check-in asks about it instead.
- **How often people go.** Every time-based measure moves with the release calendar. That is why D1 and D7 count only
  people who had a night, why the keep rate is a ratio, and why D30 is read in two halves.
- **Asked behaviour.** Testers were asked to keep every ticket. The keep rate is a ceiling for what happens after
  launch, never a forecast of it.
- **Memory.** Check-ins are self-reported. Weekly keeps it fresh; the season sheet's films figure, which the tester can
  read off their own phone, is the cross-check at day 30.
- **Novelty.** The first two weeks flatter everything. D30 is the only measure that has had time to wear off.
- **Few people.** At 30 testers, 70% observed could be anywhere from about 52% to 83%; at 50, from about 56% to 81%
  (Wilson, 95%). The bars below are far apart for that reason, and a result between them is a hold, not a pass.

## The weekly check-in

### The message

Sent on the cohort's weekday, in the evening, on days 7, 14, 21 and 28. Day 30 and day 37 have their own messages,
below, so the asked month ends exactly on day 30.

> Subject: Stub, week [2] of 4: one minute
>
> Hi [first name],
>
> One minute: [form link]. Your tester code is [T07].
>
> If you missed a ticket this week, that is the most useful thing you can tell me. Say why; there is no wrong answer.
>
> Thank you,
> Bruno

### The form

At its top: "'This week' means since your last check-in, or since you installed Stub if this is the first."

1. Your tester code.
2. How many films did you see at a cinema this week? (0 / 1 / 2 / 3 / 4 or more)
3. How many of this week's tickets have you kept in Stub? (a number)
4. Of those, how many did you keep walking out of the cinema? (a number)
5. And how many later that night or the next day? (a number)
6. If you didn't keep one, why? Tick all. (Forgot / No time or no free hand / No signal / It didn't read the ticket /
   Didn't have the ticket / Didn't want to / Something else: ___)
7. How did the tickets come in? Tick all. (Photographed a printed stub / Photographed a receipt / A Wallet pass / A PDF
   / A booking email / A screenshot / Typed it in)
8. On a day you didn't go to the cinema, did you open Stub or look at its widget? (Opened it / Looked at the widget /
   Both / Neither)
9. Did you keep any old tickets this week? (a number)
10. Anything that annoyed, surprised or pleased you? (optional)

Two more, shown until each has been answered once (the form can branch on "Already answered"):

11. Your first film since installing Stub: when did you keep its ticket? (Walking out / Later that night or the next
    day / Later than that / I didn't keep it / Already answered)
12. After the first film whose ticket you kept, did you see another within 7 days, and did you keep that ticket? Your
    drawer has the dates. (Yes, kept it walking out, that night or the next day / Yes, kept it later / Yes, didn't keep
    it / No film within 7 days / Not yet / Already answered)

Kept on the night is questions 4 and 5 together; kept later is question 3 less both. Question 11 is D1; question 12 is
D7, and its "No film within 7 days" answers are the ones left out of D7's headline.

### Day 30: the asking stops

> Subject: Stub: the month is up
>
> Hi [first name],
>
> Thirty days. Thank you. First, the check-in for the last three days: [form link].
>
> Then you can stop keeping every ticket: use Stub or don't, as you would if I had never asked. One last check-in in a
> week, and that's all.
>
> Bruno

### Day 37: the last check-in

The weekly form (its question 2 says whether they had a screening in the unasked week, which splits D30), plus:

13. Since the month ended, did you keep a ticket without being asked? (Yes / I didn't go / I went and didn't keep it)
14. If you are willing: in Stub, open Your card (the round button, top right) and share "How Stub runs on this phone".
    Those are your phone's own reports of how fast Stub ran: launch, hangs, and how long a ticket took to read. Look at
    them before you send them. They contain nothing you kept. (Only if the build has `FieldMetrics`; leave the question
    out if not.)

And the thank-you: the survey link if they haven't had it, and a line saying when their sign-up answers will be deleted.

## Thresholds

Fixed before day 0. Between the two bars is a hold: read the reasons, fix the top one, and run that measure again, by
extending this cohort 14 days or with the next.

| Measure | Keeps the plan | Rethink below | Why this number |
|---|---|---|---|
| Activation | 80% | 60% | Everyone was recruited for two visits a month and asked to keep every ticket; 14 days should hold a screening for nearly all of them. Under 60% means the first keep is failing or forgotten even when asked. Read D1's reasons. |
| D1 · the first night | 70% | 50% | The moment is the product (decision 001). The first time is the hardest: a new app, a habit that does not exist yet, a ticket that might be digital. So the bar sits below the keep rate's. |
| D7 · the second night | 70% | 50% | Counted only over people who went again, so frequency is out of it. The second night is where the habit forms or does not. |
| Keep rate, median tester | 80% | 60% | A ceiling, since testers were asked. If the ceiling is low, unprompted use after launch is lower still. |
| D30 · unasked | 40% | 25% | Someone who goes twice a month has a screening in any 7 days about 4 times in 10 (37% if their visits are random, 47% if evenly spaced). Keeping alone gives about that; opens between films add to it. Under 25% means even people with a film did not reach for it. |
| Between films | Read, not gated | — | The widget is invisible to it, so it undercounts the afterglow. Read beside check-in question 8. |
| Crash-free sessions | 99%, and no crash while keeping | Any crash while keeping | A crash at the exit loses the night, and the ticket may not survive to a second try. Fixed before anything else, with a new build and a line in the results. |

What the result changes is in [the README's reading](README.md#reading-them-together). In short: a low keep rate with a
passed exit test is a reach problem (decision 002); a high keep rate kept late, at home, reopens decision 001.

## The sheet

Private, outside the repo. Tabs:

| Tab | One row per | Columns |
|---|---|---|
| Testers | Tester | Code, first name, email, city, iPhone, Apple Intelligence (y/n), visits in 3 months, chains or independents, paper or digital, keeps tickets now, logs films, works in the trade, knows Bruno, invited, install day, shares usage data (y/n, from whether sessions ever appear) |
| Snapshots | Tester per snapshot | Date, code, build, status, sessions total, crashes total, feedback total |
| Check-ins | Tester per week | Week, code, screenings, kept, kept walking out, kept that night or next day, reasons missed, ways in, opened or glanced between films, old tickets, first film (q11), second film (q12), note |
| Measures | Tester | Activated, D1, D7 (and whether eligible), D30 (and whether they had a screening in days 31–37), keep rate |
| Builds | Build | Number, date, why, testers on it |

On day 127 (90 days after day 37), delete the Testers tab's names and emails and the free-text notes. Keep the codes and
the counts.

## Forms

The same settings for the sign-up, the check-in and the survey:

- No sign-in, and no automatic collection of email addresses.
- Every analytics, tracking pixel or "insights" option the form tool offers turned off.
- Plain links, no tracking parameters added.
- The tester code typed in by the tester, never carried in the link.
- Answers exported to the private sheet, and deleted from the form tool when the cohort's results are written.

## Results

Written to `docs/proof/results/YYYY-MM-DD-cohort.md` from this template. Counts, percentages and n only.

### The cohort

| | n |
|---|---|
| Signed up | |
| Qualified | |
| Invited | |
| Installed by cohort day 3 | |
| Installed later | |
| Share usage data | |
| Activated | |
| Answered every check-in | |
| Known to Bruno (marked) | |
| Work in the trade (marked, out of the headline) | |

### The measures

| Measure | Result | n | 95% range | Bar | Verdict |
|---|---|---|---|---|---|
| Activation | % | | | 80% / 60% | keep / hold / rethink |
| D1 · the first night | % | | | 70% / 50% | |
| D7 · the second night | % | | | 70% / 50% | |
| D7, raw (every activated tester) | % | | | read | |
| Keep rate, median tester | % | | | 80% / 60% | |
| Keep rate, pooled | % | | | read | |
| D30 · unasked | % | | | 40% / 25% | |
| D30, had a screening in days 31–37 | % | | | read | |
| D30, no screening in days 31–37 | % | | | read | |
| Between films | % of tester-weeks | | | read | |
| Crash-free sessions | % | | | 99% | |

### Split by phone and by ticket

| Measure | Apple Intelligence | Rules only | Mostly paper | Mostly digital |
|---|---|---|---|---|
| D1 · the first night | | | | |
| Keep rate, median tester | | | | |
| D30 · unasked | | | | |

### Week by week

| Days | Screenings | Kept walking out | Kept that night or next day | Kept later | Not kept | Old tickets kept | Sessions (sharing testers) | Crashes |
|---|---|---|---|---|---|---|---|---|
| 0–6 | | | | | | | | |
| 7–13 | | | | | | | | |
| 14–20 | | | | | | | | |
| 21–27 | | | | | | | | |
| 28–30 | | | | | | | | |
| 31–37, unasked | | | | | | | | |

### Why tickets were not kept

| Reason | Check-ins ticking it | Testers |
|---|---|---|
| Forgot | | |
| No time or no free hand | | |
| No signal | | |
| It didn't read the ticket | | |
| Didn't have the ticket | | |
| Didn't want to | | |
| Something else (listed) | | |

### How tickets came in

| Way in | Check-ins ticking it | Testers |
|---|---|---|
| Photographed a printed stub | | |
| Photographed a receipt | | |
| Wallet pass | | |
| PDF | | |
| Booking email | | |
| Screenshot | | |
| Typed in | | |

### Notes

- Builds shipped during the cohort, with dates and why.
- Holidays, festivals or big releases inside the 37 days.
- Field reports received: how many, and the median `Keepable` interval they carry, beside the simulator's in
  `docs/evals.md`.
- Feedback screenshots: how many, grouped by what they show.
