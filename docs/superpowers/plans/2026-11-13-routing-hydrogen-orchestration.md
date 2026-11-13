# Routing, Hydrogen and Orchestration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an offload-judgement step, Gemini 4 Hydrogen routing and hybrid orchestration to the `antigravity-delegate` skill, then push to GitHub and update the plugin installed on the owner's machine.

**Architecture:** `SKILL.md` stays the entry point and gains a Route step and permission tiers; detail lives in two reference files. One new PowerShell script keeps an outcome ledger. Every claim about `agy` behaviour that the skill states is first measured in a throwaway repo (benchmark B1, tier tests T4/T5, orchestration dry run T6, swarm spike S1) and recorded.

**Tech Stack:** Markdown skill files; PowerShell 5.1-compatible scripts; Node (`node --test`, `npm test`) for throwaway fixtures; `agy` 1.5.8; git.

**Spec:** `docs/superpowers/specs/2026-11-13-routing-hydrogen-orchestration-design.md`

## Global Constraints
- Plugin version becomes `0.4.0` in `.claude-plugin/plugin.json`.
- No wildcard allow rules; `--settings` rules are exact `command(<full string>)`.
- Always pass `--model`; never `--effort` with a model id that has an effort suffix.
- Worker cap by Gemini five-hour quota: 60% or more = 3, 30-59% = 2, under 30% = 1; quota unreadable = 1.
- Tier 2 only after an explicit yes per project, in an isolated clone (`git clone --no-hardlinks`, then `git remote remove origin`).
- Ledger at `%USERPROFILE%\.agy-delegate\ledger.jsonl`; no code and no prompts stored.
- Swarm lane stays off unless spike S1 passes (correct diff, quota delta about 15% of the five-hour limit or less).
- Main `SKILL.md` about 170 lines or less; no secrets committed.
- PowerShell: 5.1 compatible, no non-ASCII literals in `.ps1` files, never name a local variable like a parameter (names are case-insensitive).
- No merge to `main` or push by workers; the only push is the release in Task 8, which the owner requested.

## Review Focus
- Two workers finish together and both append to the ledger: no lost or interleaved lines (Task 2).
- A ledger line is corrupted or the folder is missing: `-Summary` still works and says what it skipped (Task 2).
- `/usage` prints "quota unavailable" or changes format: the worker cap falls to 1 and the verdict line says why, no crash (Task 5).
- Two tasks list overlapping paths that differ only in case, slashes or directory-versus-file: the planner must treat them as overlapping and sequence them (Task 5).
- A tier-2 worker runs `git push` or `git branch -D main` inside its clone: the real repo is untouched, and fetch-back never overwrites `main` (Task 4).

---

### Task 1: Benchmark B1 and Hydrogen's quota pool
**Files:**
- Create: `skills/antigravity-delegate/references/benchmarks.md`
- Scratch (not committed): fixture repo `bench` in the scratchpad

**Interfaces:**
- Produces: `benchmarks.md` with a table (model, packet, first-pass yes/no, minutes, diff lines, Gemini/Claude-GPT/Argon quota points used) and three decision lines: mechanical default model, substantive-coding default model, Hydrogen's pool. Tasks 3 and 7 copy these decisions.

- [ ] **Step 1: Build the fixture** (`package.json` with `"test": "node --test"`, git-initialised). Frozen tests: `test/formatBytes.test.js` (`formatBytes(0)` = `"0 B"`, `1023` = `"1023 B"`, `1024` = `"1.0 KB"`, `1536` = `"1.5 KB"`, `1048576` = `"1.0 MB"`, negative throws `RangeError`); `test/parseDuration.test.js` (`"1h30m15s"` = 5415, `"90s"` = 90, `"2h"` = 7200, `"1h 30m"` = 5400, `"30m1h"` / `""` / `"5x"` throw `Error` with message `invalid duration`); `test/invoice.test.js` plus a messy passing `src/invoice.js` whose `total(items, taxRate)` must keep its existing tests and gain a 10% discount when the pre-tax subtotal is 100 or more, rounded half-up to cents.
- [ ] **Step 2: Verify the baseline.** Run `npm test` in the fixture. Expected: formatBytes and parseDuration tests fail (no implementation), existing invoice tests pass, new discount tests fail.
- [ ] **Step 3: Run seven packets sequentially** (so quota deltas attribute cleanly), each in a fresh worktree from the baseline commit: formatBytes, parseDuration and invoice on `gemini-3.8-flash-high` and `gemini-4-hydrogen-high`, plus parseDuration on `gemini-4-hydrogen-medium`. For each: record `agy -p "/usage"` before and after, wall minutes, then run `npm test` yourself and count diff lines. First pass = frozen tests all pass on the first run.
- [ ] **Step 4: Write `benchmarks.md`** with the table and the decision lines. Rule: Hydrogen becomes the substantive-coding default only if it passes first-pass where Flash did not, or matches Flash on first-pass with no worse minutes or quota; otherwise Flash stays and Hydrogen is reserved for hard tasks. State which `/usage` row moved for Hydrogen (Gemini Models pool, Argon, or neither).
- [ ] **Step 5: Commit** `git add skills/antigravity-delegate/references/benchmarks.md` with message `docs: benchmark Flash vs Hydrogen on three packets`.

### Task 2: Ledger script
**Files:**
- Create: `skills/antigravity-delegate/scripts/ledger.ps1`
- Test: `skills/antigravity-delegate/tests/ledger.tests.ps1`

**Interfaces:**
- Produces: `ledger.ps1 -Add -Project <string> -Task <string> -Verdict <KEEP|DELEGATE|SPLIT|SWARM> -Score <int> -Model <string> -Tier <0|1|2> -Files <int> -Lines <int> [-FirstPass] -FixRounds <int> -Minutes <double> -Quota5h <double> -QuotaWeek <double> [-Note <string>] [-Ledger <path>]` appends one JSON line; `ledger.ps1 -Summary [-Ledger <path>]` prints one line per model: `<model> tasks=<n> firstpass=<pct>% fix=<avg> min=<avg> q5h=<avg>`, or `No ledger entries.`. Default `-Ledger` is `%USERPROFILE%\.agy-delegate\ledger.jsonl`. `-Note` is cut to 200 characters. Tasks 5 and 7 call it.

- [ ] **Step 1: Write failing tests** in `ledger.tests.ps1` (plain assert helper, prints `ALL PASSED` or the failing test name), all against a temp ledger path: `add_creates_folder_and_file`; `summary_two_models` (Flash rows: first-pass yes/fix 0/min 3/q5h 1 and no/fix 2/min 5/q5h 3; one Hydrogen row; expects `tasks=2 firstpass=50% fix=1 min=4 q5h=2` for Flash); `summary_empty_says_no_entries`; `corrupted_line_skipped` (append `not json`; summary still prints and says `skipped 1`); `parallel_appends` (five `Start-Job` adds at once; exactly five parseable lines); `bad_verdict_rejected` (`MAYBE` fails); `note_truncated_to_200`.
- [ ] **Step 2: Run** `powershell -NoProfile -ExecutionPolicy Bypass -File skills/antigravity-delegate/tests/ledger.tests.ps1`. Expected: FAIL (script missing).
- [ ] **Step 3: Implement `ledger.ps1`.** Write each row with one `[IO.File]::AppendAllText` call so parallel appends do not interleave; parse each line in a `try`, count skipped lines.
- [ ] **Step 4: Run the tests.** Expected: `ALL PASSED`.
- [ ] **Step 5: Commit** both files: `feat: add outcome ledger script`.

### Task 3: Routing reference
**Files:**
- Create: `skills/antigravity-delegate/references/routing.md`

**Interfaces:**
- Consumes: Task 1 decision lines; Task 2 `ledger.ps1 -Summary`.
- Produces: the rubric, model table and eight scenarios that `SKILL.md` (Task 7) points to.

- [ ] **Step 1: Write `routing.md`** with: the score table and verdict rules from spec D1 verbatim (diff size 15 / 40 / 150 breakpoints, ratio 25% / 60%, ambiguity 2 = KEEP, tests +1 / none -1, background +1, sensitive -1 unless Claude writes the tests; 3 or more DELEGATE, 1-2 DELEGATE only in parallel or background, 0 or less KEEP, two or more independent groups SPLIT); the model table from spec D2 with the Task 1 decisions filled in (marked provisional if Task 1 was inconclusive); the ledger rule (at least 5 rows for a model: run `-Summary`, adjust thresholds, say so in the verdict line); the verdict line format `Route: <VERDICT> (<model>, <n> workers). Why: <reason>. Est: Claude direct ~<x> vs delegate ~<y>`.
- [ ] **Step 2: Add the eight scenarios** with factor points and expected verdict: one-file rename, 8 lines = KEEP outright; 60-line CSS card, clear spec, no tests, background = DELEGATE (2); six-file CRUD with tests, 220 lines = DELEGATE (5); 20-line payment race fix, sensitive = KEEP; "make the dashboard better" = KEEP and ask; three independent 100-line features = SPLIT; 400-line self-contained module with 70% five-hour and 55% weekly quota = SWARM if lane supported, else DELEGATE with Hydrogen-xhigh; 80-line auth migration with Claude-written tests = DELEGATE (2) in the background only.
- [ ] **Step 3: Recompute every scenario by hand** from the rubric (separate pass, not copied from the table) and fix any mismatch. Expected: all eight agree.
- [ ] **Step 4: Commit** `docs: add routing rubric and scenarios`.

### Task 4: Permission tiers (tests T4, T5)
**Files:**
- Modify: `skills/antigravity-delegate/SKILL.md` (the "Permission reality" section; Task 7 does the rest)
- Scratch: throwaway repo and clone

**Interfaces:**
- Produces: in `SKILL.md`, the tier 0/1/2 table; the per-run settings recipe `{"permissions":{"allow":["command(<exact string>)"]}}` passed as `--settings <file>` (file outside the repo, deleted afterwards); the `%USERPROFILE%\.agy-delegate\config.json` shape `{"projectTiers": {"<absolute path>": <0|1|2>}}`, default 0, written only after an explicit yes; the tier-2 recipe (clone, remove origin, fetch the branch back under a new name).

- [ ] **Step 1: T4, tier 1.** In a scratch repo run `agy -p` with `--mode accept-edits --settings tier1.json` where the file allows only `command(node --version)`: asking for `node --version` must print a version; asking for `node -e "console.log(1)"` must end with `no output produced ... command permission`. Record both outputs.
- [ ] **Step 2: T5, tier-2 containment** (plain git, no agent): `git clone --no-hardlinks <repo> <clone>` outside the repo, `git remote remove origin` in the clone, commit a change there, then check: `git -C <clone> push origin HEAD` fails, `git -C <clone> branch -D main` leaves the original's `git log` and branches identical, and `git fetch <clone> <branch>:agy/<name>` brings the work back without touching `main`. Expected: all three hold.
- [ ] **Step 3: Write the tier section** in `SKILL.md` from the results, including: tier 2 needs an explicit per-project yes, needs the clone recipe, and if Claude Code's safety classifier refuses to launch a tier-2 worker, stop and tell the owner instead of working around it.
- [ ] **Step 4: Commit** `docs: add worker permission tiers with verified recipes`.

### Task 5: Orchestration reference and dry run (test T6)
**Files:**
- Create: `skills/antigravity-delegate/references/orchestration.md`
- Scratch: fixture repo `orch`

**Interfaces:**
- Consumes: Task 2 `ledger.ps1 -Add`; Task 3 verdict rules.
- Produces: the planner schema (`id, goal, files, dependsOn, tier, model, verdict`), the path-overlap rule, the cap rule, the review and merge procedure.

- [ ] **Step 1: Write `orchestration.md`**: task schema; overlap rule (lower-case, forward slashes, a directory overlaps everything under it; any overlap means sequence or merge); waves with the quota cap (read the Gemini five-hour row of `/usage`; unreadable means cap 1 and say so); per-task review gate (status, diff against the allowed list, Claude re-runs tests, full diff read); merge accepted branches into `agy/<goal>` in dependency order, run the full tests there; two fix rounds then Claude takes over; re-plan when a dependency fails; swarm lane eligibility from spec D4, marked "disabled until S1 passes".
- [ ] **Step 2: Dry run.** Fixture with tasks A (`a.js`), B (`b.js`), C (`c.js`, depends on A and B) and D (also edits `a.js`). Write the plan first: it must put D after A (overlap) and run A and B in wave 1, C and D in wave 2. Run on `gemini-3.8-flash-high`, review each task, merge into `agy/demo`, run `npm test`. Expected: all tests pass, no worker touched files outside its list. State the computed worker cap and simulate unreadable quota (cap 1).
- [ ] **Step 3: Log each task** with `ledger.ps1 -Add` and run `-Summary`. Expected: four rows, sensible averages.
- [ ] **Step 4: Commit** `docs: add orchestration procedure verified by a dry run`.

### Task 6: Swarm spike S1 (test T7)
**Files:**
- Modify: `skills/antigravity-delegate/references/orchestration.md` (swarm lane status)
- Scratch: disposable repo `swarm-s1` in an isolated clone

**Interfaces:**
- Produces: a recorded result and the lane status line `Swarm lane: supported` or `Swarm lane: unsupported (<reason>)`.

- [ ] **Step 1: Prepare** a goal needing three independent files, each with a frozen test, in a clone with a sentinel file outside the workspace; record `/usage`.
- [ ] **Step 2: Run** `agy -p "/swarm <goal>" --mode accept-edits --model gemini-3.8-flash-high --print-timeout 20m --log-file <log> 2>&1` from the clone. Record exit code, stdout, wall time, files changed, sentinel intact or not, and `/usage` after.
- [ ] **Step 3: Judge against the spec:** correct diff (tests pass when Claude runs them) and quota delta about 15% of the five-hour limit or less means supported; anything else means unsupported with the reason.
- [ ] **Step 4: Record** the measurements and the status line in `orchestration.md`; commit `docs: record swarm spike result`.

### Task 7: Skill entry point, docs and version
**Files:**
- Modify: `skills/antigravity-delegate/SKILL.md`, `README.md`, `.claude-plugin/plugin.json`, `skills/antigravity-digest/SKILL.md`

**Interfaces:**
- Consumes: Tasks 1-6 results and files.

- [ ] **Step 1: Edit `SKILL.md`:** update the Defaults model table with the Task 1 decisions (Hydrogen ids, provisional flag if needed); add a short "Step 0b: Route" that applies `references/routing.md` and prints the verdict line before any delegation; add an "Orchestrating several packets" section pointing to `references/orchestration.md` and the tier section from Task 4; add ledger logging to Step 3 and a ledger-summary read to Step 0b; extend the `description` with the trigger phrases "is it worth delegating", "run these in parallel", "Hydrogen". Move detail into the references so the file stays about 170 lines or less.
- [ ] **Step 2: Edit `README.md`** (new capabilities, tiers, ledger, orchestration, swarm lane status), `plugin.json` (`"version": "0.4.0"`, description), and add the shared model note to the digest skill.
- [ ] **Step 3: Verify.** `(Get-Content skills/antigravity-delegate/SKILL.md).Count` is 170 or less; every `references/*.md` path mentioned in `SKILL.md` exists (`Test-Path`); `plugin.json` version is `0.4.0`; a grep for `password|token|api[_-]?key|secret` over the staged diff shows only prose. Expected: all true.
- [ ] **Step 4: Commit** `feat: add offload routing, Hydrogen models and hybrid orchestration`.

### Task 8: Release and install (test T8)
**Files:**
- Modify: none (git and plugin state only)

**Interfaces:**
- Consumes: everything above.

- [ ] **Step 1: Final checks:** run `ledger.tests.ps1` (expected `ALL PASSED`) and `git status` (expected clean).
- [ ] **Step 2: Push** `git push origin main`; confirm `git status -sb` shows no ahead count.
- [ ] **Step 3: Install on this machine:** run `claude plugin marketplace update antigravity-delegate` then `claude plugin update antigravity-delegate@antigravity-delegate`; if `claude` is not on PATH or the command fails, give the owner the equivalent `/plugin` commands instead.
- [ ] **Step 4: Verify** `C:\Users\Celestosapien\.claude\plugins\installed_plugins.json` shows version `0.4.0` and `gitCommitSha` equal to `git rev-parse origin/main`. Report that a new session is needed to load it.
