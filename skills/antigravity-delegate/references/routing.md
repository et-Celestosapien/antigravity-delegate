# Route step: is offloading worth it, and to which model?

Run this before any delegation and whenever the owner gives a multi-part task. It takes a minute and ends in one verdict line. Do not let it grow: if the answer is obvious (a 5-line edit, or a clear 300-line CRUD with tests), say so in one line.

## 1. Score the task
Estimate, then add up:

| Factor | Points |
|---|---|
| Diff size (changed lines) | under 15: **KEEP outright**; 15-39: 0; 40-149: +1; 150 or more, or 4+ mostly mechanical files: +2 |
| Packet-to-diff ratio (lines of spec needed vs lines of code produced) | 25% or less: +1; over 60%: -2; otherwise 0 |
| Ambiguity | 2 (needs a design decision): **KEEP**, settle it with the owner first; 0-1: 0 |
| Checkable (existing tests, or acceptance tests Claude can write first) | yes +1; no -1 |
| Independent (can run in the background while Claude or the owner does other work; this is the owner's-time term) | yes +1 |
| Sensitive (money, auth, security, data loss) | -1, or 0 if Claude writes the acceptance tests |

**Verdict:** 3 or more = DELEGATE. 1 or 2 = DELEGATE only if it runs in parallel or in the background, otherwise KEEP. 0 or less = KEEP. Two or more independent file groups = SPLIT (see `orchestration.md`; score each task). SWARM only when the swarm lane is supported and its conditions hold.
Break-even in words: delegate when (writing the packet + reading the diff + expected rework) is clearly less than writing it directly.

## 2. Pick the model (from benchmark B1, see `benchmarks.md`)
| Work | Model |
|---|---|
| Mechanical: CSS, boilerplate, CRUD, docs, tests from a clear spec | `gemini-3.8-flash-high` |
| Substantive coding: logic, multi-file features, refactors, test-driven work | `gemini-4-hydrogen-high` (`gemini-4-hydrogen-medium` for modest tasks) |
| Hard: cross-cutting, subtle invariants, or Hydrogen-high already failed once | `gemini-4-neon-high` (`gemini-4-neon-xhigh` after one failure; `gemini-4-hydrogen-xhigh` if `agy models` does not list Neon) |
| Gemini pools low, Argon weekly 25% or more | `gemini-4-argon-high`, one packet at a time (a separate pool, not a quality step-up) |
| Gemini pools low, Claude/GPT pool 20% or more | `claude-sonnet-5-5-high` through `agy` |

Neon rows rest on published benchmarks, not agy runs (`models.md`, 2026-11-21): Neon-high scores AA 60 vs Hydrogen-xhigh 54 at about the same cost and time per task, and leads the AA Coding Agent Index. Neon-medium (AA 55, about Hydrogen-high's cost) is a candidate for substantive coding once the ledger has rows for it; until then Hydrogen-high stays the default because it has the measured agy evidence. Carbon is not in `agy models`.

Hydrogen's and Neon's quota pools are unknown (see `benchmarks.md`, `models.md`). Apply the Gemini quota gate (weekly and five-hour both 10% or more) to it, and after Hydrogen runs read every `/usage` row, not only Gemini, so a different pool cannot drain unseen. Always pass `--model`. Evidence is one run per cell on small packets, so treat the table as the starting point and let the ledger correct it.

## 3. Use the ledger
`scripts/ledger.ps1 -Summary` prints one line per model (tasks, first-pass %, average fix rounds, minutes, quota points). With 5 or more rows for a model, read it before scoring. Adjustment rules (provisional, my calls): first-pass under 60% for a model means require a score of 4 or more for it, or step up one model; first-pass 90% or more over 10+ rows means the 1-2 band may DELEGATE even without parallelism. Say when you applied an adjustment.

## 4. The verdict line
`Route: <VERDICT> (<model>, <n> workers). Why: <one reason>. Est: Claude direct ~<x>k tokens vs delegate ~<y>k.`
Rough sizing, order of magnitude only: writing or reading a changed line costs about 12-15 tokens; a packet costs about 10 tokens per spec line plus the context it quotes; expect rework of about 30% of the diff. The verdict follows the score, not the number.

## 5. Eight reference scenarios (check your reading of the rubric against these)
| # | Task | Points | Verdict |
|---|---|---|---|
| 1 | Rename a variable in one file, 8 lines | under 15 lines | KEEP outright |
| 2 | CSS for a new card, 60 lines, clear spec, only a visual check, can run in the background | diff +1, ratio +1, no check -1, independent +1 = 2 | DELEGATE (because background) to Flash |
| 3 | CRUD views, forms and tests for a new model, 6 files, 220 lines, short spec | +2, +1, tests +1, independent +1 = 5 | DELEGATE to Flash |
| 4 | Fix a race in payment retries, 20 lines, sensitive, hard to test | 0, ratio -2, no check -1, sensitive -1 = -4 | KEEP |
| 5 | "Make the dashboard better" | ambiguity 2 | KEEP, ask the owner what better means |
| 6 | Three independent features in separate folders, about 100 lines each, tests available | each: +1, +1, +1, +1 = 4 | SPLIT into 3 tasks, DELEGATE each (Hydrogen-high) |
| 7 | One 400-line self-contained module, tests writable, Gemini five-hour 70%, weekly 55% | +2, +1, +1, +1 = 5 | SWARM only if the owner has said yes to tier 2 for this project (the lane works only at tier 2) and the quota conditions hold; otherwise DELEGATE to Hydrogen-high |
| 8 | Auth-table migration, 80 lines, Claude writes the acceptance tests, touches shared state | diff +1, ratio 0, tests +1, sensitive 0 (tests written), not independent 0 = 2 | DELEGATE only in the background; otherwise KEEP |
