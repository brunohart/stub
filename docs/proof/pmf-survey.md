# The survey: would they miss it?

**The question.** Would the people who use Stub be very disappointed if they could no longer use it?

**The benchmark.** Sean Ellis's question, with Superhuman's three answers and follow-ups, as Rahul Vohra described them
in First Round Review on 2018-11-13 ("How Superhuman Built an Engine to Find Product/Market Fit",
https://review.firstround.com/how-superhuman-built-an-engine-to-find-product-market-fit/). The line is **40% or more
"very disappointed"**.

**Who.** Cohort testers ([testflight-cohort.md](testflight-cohort.md)) who have kept at least 3 stubs over at least 2
weeks and opened Stub recently.

**What it is not.** A measurement of the market. 30 to 50 recruited cinema-goers can show whether Stub has a core of
people who would miss it, and who they are. At 30 answers, exactly 40% is consistent with a true share anywhere from
about 25% to 58% (Wilson, 95%). The verdict is directional, and the words matter more than the percentage.

## Who gets it, and when

### Eligible

All three, from the tester's own answers at the top of the form:

| | Eligible |
|---|---|
| Stubs kept so far, old ones included | 3 or more |
| First stub kept | 2 or more weeks ago |
| Last opened Stub | This week or last week |

Ellis recommends asking people who have used the product at least twice, and recently; Superhuman left out people who
no longer used it. Three stubs over two weeks is that, for an app used on cinema nights.

Not eligible: the form thanks them and ends. Their answers to the three questions above are kept as a count, nothing
more.

### When

- From cohort day 21, to each tester on the evening the sheet shows them eligible (check-ins: kept plus old tickets, and
  the date of the first).
- Anyone eligible only by day 37 gets it with the last check-in.
- One reminder, 3 days after the first email. No more.
- Closes on cohort day 40. Scored once, after it closes; no peeking at the percentage while it is open.

## How it is sent

Outside the app. Stub never asks: an in-app prompt would interrupt the keepsake, and its answers would need a server
(decision 007).

- A plain form in a form tool (Tally or Google Forms are both fine), with the settings in the cohort's
  [Forms](testflight-cohort.md#forms): no sign-in, no email collection, no analytics or pixels, no tracking parameters
  on the link, the tester code typed in, not carried in the URL.
- Linked from the build's What to Test notes from day 21, and sent by email to each tester as they become eligible.
- Branching after the eligibility questions, so the not-eligible see a thank-you and nothing else. If the tool cannot
  branch, every answer is kept and only the eligible are scored.

### The email

> Subject: Stub: five minutes
>
> Hi [first name],
>
> You have kept enough stubs now for the question I most need answered. Five minutes: [link]. Your tester code is
> [T07].
>
> Answer it as you really feel. "Not disappointed" is as useful to me as anything else.
>
> Bruno

### At the top of the form

> This survey is about Stub, and it is outside the app. Your answers go to Bruno, who makes Stub, and are used only to
> decide what to build next. Your tester code links them to your weekly check-ins; your name and email are not asked.
> Nothing on this page tracks you. Answers are deleted 90 days after the test ends, or sooner if you reply to any email
> from me and ask. You can skip any question.

## The questions

In this order. The main question comes straight after eligibility, so nothing before it leans on the answer. The words
of question 1 and its three answers are Superhuman's, with Stub's name, and are never changed: changing them makes the
40% line meaningless.

**Your tester code** (from your welcome email)

**Eligibility**

- E1. How many stubs have you kept in Stub so far, old ones included? (None / 1 or 2 / 3 to 5 / 6 or more)
- E2. When did you keep your first one? (Less than 2 weeks ago / 2 to 4 weeks ago / More than 4 weeks ago)
- E3. When did you last open Stub? (This week / Last week / Longer ago)

**The question**

1. How would you feel if you could no longer use Stub?
   - Very disappointed
   - Somewhat disappointed
   - Not disappointed

**Superhuman's follow-ups**

2. What type of people do you think would most benefit from Stub?
3. What is the main benefit you receive from Stub?
4. How can I improve Stub for you?

(Superhuman's fourth question says "we". Stub is made by one person, so it says "I". Questions 2 to 4 are free text.)

**Stub's two**

5. Which ways did your tickets come in? Tick every one you used.
   - Photographed a printed stub
   - Photographed a receipt
   - Shared a Wallet pass
   - Shared a PDF e-ticket
   - Shared a booking email
   - Shared a screenshot
   - A cinema's "Add to Stub" link (leave this out unless a cinema near the cohort puts the link on its confirmations)
   - Typed it in
   - Something else: ___
6. Every stub you keep comes back as an edition: a ticket designed for its film's release. What did you do with the
   editions? Tick everything you did.
   - Looked at them in the drawer
   - Tilted the phone to catch the light on one
   - Turned one over to the ticket as I kept it
   - Took one to the press and pulled my own proof
   - Shared one, moving or still
   - Put the drawer's widget on my home screen
   - Made a drawer and filed stubs in it
   - Nothing: I didn't notice them
   - Nothing: I noticed them and didn't care for them

   6b. Tell me about one, if you like. (optional)

Nothing else is asked. The segments come from the sign-up form and the cohort's sheet through the tester code, so
nobody is asked twice.

## Scoring

1. **Keep the eligible answers only.** Write how many answered and how many were not eligible.
2. **The headline.** Very disappointed ÷ eligible answers, with its 95% range. Under 20 eligible answers, no verdict on
   the line: read the words, report the count, and say it was too few.
3. **The segments.** For each, the share very disappointed and n. A segment under 5 is not reported on its own (the
   threshold App Store Connect's own analytics uses); 5 to 9 is read but not acted on; 10 or more can move the plan.

   | Segment | From |
   |---|---|
   | Apple Intelligence phone, or the rules alone | Sign-up |
   | 6 to 8 visits in three months, or 9 or more | Sign-up |
   | Mostly chains, mostly independents, both | Sign-up |
   | Mostly paper, mostly digital, both | Sign-up |
   | Keeps tickets now, used to, never did | Sign-up |
   | Logs films elsewhere, or not | Sign-up |
   | Did something with the editions beyond looking (press, share, widget, a drawer), or not | Question 6 |
   | Keep rate 80% or more, or under | The cohort's measures |
   | The type of person they named | Question 2, coded |

4. **Find the core.** The segment with the highest share very disappointed, n 10 or more. Superhuman's version of this
   is reading question 2's answers from the very disappointed to describe who loves it most, then checking that people
   who match the description score higher. Do both.
5. **Read what they love.** The very disappointed's answers to question 3, coded into themes. Starting codes, to be
   added to, never forced: *the night itself remembered* · *the editions* · *instead of a shoebox, or fading thermal
   paper* · *digital tickets finally kept* · *the season's counts* · *quick to do*. Count each theme.
6. **Read what holds the nearly-there back.** The somewhat disappointed whose question 3 shares the top theme. Their
   question 4 is the list.
7. **Read, don't build for, the not disappointed.** Their answers say what Stub is not. Superhuman set them aside.
8. **Check it against what people did.** The keep rate of the very disappointed beside the others'. If the people who
   say they would miss it do not keep more of their nights, say so: stated love not backed by use is the weakest result
   there is.
9. **Split the next builds.** Superhuman gave half the roadmap to what the very disappointed love and half to what holds
   the nearly-there back. Do the same with the next round of work.

### A worked example, with invented numbers

34 eligible answers, 13 very disappointed: 38%, range about 24% to 55%. A hold overall. Mostly independents and mostly
paper: 9 of 15, 60%, range about 36% to 80%. n is 10 or more and the share is above 40%, so the first audience narrows
to them. Their main benefit, coded: *instead of fading thermal paper* 6, *the editions* 2, *the night itself* 1. Five
somewhat disappointed also named fading paper; four of them asked for the receipt to read without straightening it
first. That is the next build's first half.

## The decision rule

Fixed before the survey opens.

| Result | What it means | What changes |
|---|---|---|
| **40% or more very disappointed**, 20 or more eligible | There is a core. | The plan holds. Launch preparation continues; the next builds follow the split; the store page leads with the top benefit, in Stub's words, not the testers'. |
| **Under 40% overall, 40% or more in one segment of 10 or more** | There is a core, narrower than the plan. | That segment is the first audience: where the next testers are found, what the store page says, what the next builds serve. The rest are not a target yet. |
| **25% to 39%** | Close, not there. | No launch claim. One round of builds on the split, then the survey again: the same testers after 2 more weeks on the new build, or a second cohort. |
| **Under 25%** | The product as built has no core yet. | No new features. Five 30-minute calls (the very disappointed, if any, then the somewhat disappointed) about their cinema nights, not the app. Decision 001 is reopened in a new entry. |

One reading on top of the verdict: if the very disappointed's main benefit is the afterglow (the editions, the season,
the drawer) rather than keeping the night, then the ten seconds at the exit is the cost and the afterglow is the
product. That does not change the bar for the moment; it changes what the store page and the next builds lead with.

## Results

Written to `docs/proof/results/YYYY-MM-DD-survey.md`. Counts and percentages; quotes only if short, unattributed, and
with any cinema or film named in them replaced by [cinema] or [film].

### Answers

| | n |
|---|---|
| Sent | |
| Answered | |
| Eligible | |
| Not eligible: fewer than 3 stubs | |
| Not eligible: first stub under 2 weeks ago | |
| Not eligible: not opened in 2 weeks | |

### The headline

| Answer | n | % of eligible |
|---|---|---|
| Very disappointed | | |
| Somewhat disappointed | | |
| Not disappointed | | |
| **Very disappointed, 95% range** | | % to % |

### By segment

| Segment | n | Very disappointed | % | Acted on (n 10+) |
|---|---|---|---|---|
| Apple Intelligence | | | | |
| Rules alone | | | | |
| 6 to 8 visits in three months | | | | |
| 9 or more | | | | |
| Mostly chains | | | | |
| Mostly independents | | | | |
| Mostly paper | | | | |
| Mostly digital | | | | |
| Keeps tickets now | | | | |
| Used to | | | | |
| Never did | | | | |
| Logs films elsewhere | | | | |
| Doesn't | | | | |
| Did something with the editions | | | | |
| Only looked, or nothing | | | | |
| Keep rate 80% or more | | | | |
| Under 80% | | | | |

### What the very disappointed get from it

| Theme (question 3) | Very disappointed | Somewhat disappointed who share it |
|---|---|---|
| | | |

### What holds the nearly-there back

| Theme (question 4, from the somewhat disappointed who share the top benefit) | n |
|---|---|
| | |

### How tickets came in

| Way in (question 5) | Testers |
|---|---|
| Printed stub | |
| Receipt | |
| Wallet pass | |
| PDF | |
| Booking email | |
| Screenshot | |
| Typed in | |
| Something else (listed) | |

### What they did with the editions

| Question 6 | Testers |
|---|---|
| Looked at them | |
| Tilted one in the light | |
| Turned one over | |
| Pulled a proof at the press | |
| Shared one | |
| Put the widget on the home screen | |
| Made a drawer | |
| Didn't notice them | |
| Noticed, didn't care for them | |

### Stated against done

| | Very disappointed | Somewhat | Not |
|---|---|---|---|
| Keep rate, median | | | |
| D30 · unasked | | | |

### The verdict

One line: the rule's row, the number, n, and what changes.
