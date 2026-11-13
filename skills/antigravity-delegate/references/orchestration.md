# Orchestrating several packets (hybrid)

Claude is the orchestrator. Workers are `agy` processes; every task keeps the review gate from `SKILL.md` Step 3. Run the Route step (`routing.md`) for each task first; only DELEGATE and SPLIT tasks get a worker.

**Swarm lane: unsupported** (spike S1 failed at tier 0 on 2026-11-13; see "Spike S1 result"). Use parallel workers (below) instead.

## 1. Plan before launching anything
Write the task list in the reply (one row per task):

| id | goal | files (allowed) | dependsOn | tier | model | verdict |
|---|---|---|---|---|---|---|
| a | ... | `src/a.js`, `test/a.test.js` | - | 0 | per `routing.md` | DELEGATE |

**Overlap rule.** Normalize every path (lower-case, forward slashes, no leading `./`). A directory overlaps everything under it. Two tasks overlap if any path of one equals, contains or sits under any path of the other. Treat shared generated files (lockfiles, migration numbering, `package.json`, index/barrel files) as overlapping. An overlap means: make the later task depend on the earlier one, or merge them into one task. Never run overlapping tasks in the same wave.

## 2. Waves and the worker cap
A wave is every task whose dependencies are already merged. The cap comes from the Gemini **five-hour** row of `agy -p "/usage"`, re-read before each wave:

| Gemini five-hour left | Workers at once |
|---|---|
| 60% or more | 3 |
| 30% to 59% | 2 |
| under 30% | 1 |
| unreadable (command fails, "quota unavailable", no such row) | 1, and say so in the verdict line |

Also lower the cap by the Gemini **weekly** row, which the digest skill shares: 40% or more changes nothing, 15-39% means at most 2, under 15% means 1. The Argon and Claude/GPT-pool rules in `SKILL.md` (Step 0) still apply per task.

## 3. Isolation per task
Tier 0 and 1: `git worktree add ..\<repo>-<id> -b agy/<goal>-<id> <integration branch>`. Tier 2: an isolated clone as described under permission tiers in `SKILL.md`. One folder per task, never shared.

## 4. Review gate, then merge
When a task finishes: stderr/permission check, `git status` and a diff against the branch the task was cut from (`agy/<goal>`, never `main`, which would show earlier merges) checked against the allowed-file list, Claude runs the tests itself, reads the whole diff. Accepted tasks merge into the integration branch `agy/<goal>` (cut from `main`) with `git merge --no-ff`, in dependency order; then run the full suite on that branch. A merge conflict stops the wave: Claude resolves it or re-plans (it counts as a fix round). Merging into `main` and pushing happen only when the owner says so.

## 5. Failures
Two fix rounds per task, then Claude takes the task over. If a task other tasks depend on fails, do not launch its dependents; re-plan. A denied permission is handled with "Scope requests" in `SKILL.md`, never by widening permissions on your own.

## 6. Record outcomes
After each task, one ledger row (replace the values):
`powershell -NoProfile -ExecutionPolicy Bypass -File <skill dir>\scripts\ledger.ps1 -Add -Project <name> -Task <id> -Verdict DELEGATE -Score <n> -Model <model> -Tier <0|1|2> -Files <n> -Lines <n> [-FirstPass] -FixRounds <n> -Minutes <x> -Quota5h <points used> -QuotaWeek <points used>`
`-FirstPass` means the frozen tests passed on the worker's first result. No code or prompts go in the ledger.

## Verified by a dry run (2026-11-13, agy 1.5.8, Flash-high, tier 0)
Four tiny tasks on a throwaway repo: a and b independent, c depends on both, d edits the same file as a. Plan: d after a (overlap rule), wave 1 = a + b, wave 2 = c + d. Result: every worker stayed inside its one allowed file, each passed its own frozen test on the first try (0.5-0.6 minutes each), merges into `agy/demo` had no conflicts, and the full suite went 2/4 after wave 1 and 4/4 after wave 2. Gemini five-hour quota moved 98% -> 97% for all four tasks together. Tips from the run:
- Tell each worker that other tests in the suite belong to other tasks and may fail, so it does not try to fix them.
- Cut each wave's worktrees from the integration branch (`agy/<goal>`), so later tasks see earlier merges.
- With `/usage` unreadable the cap is 1 worker; the plan above would then run a, b, c, d one at a time in dependency order, with the same review gate.
- These tasks were 5-8 changed lines, below the Route step's KEEP threshold; they were used on purpose to test the mechanics. Real tasks go through `routing.md` first.

## Swarm lane (unsupported for now; kept for later)
`agy` can run a native swarm: a Gemini coordinator that spawns worker agents (`/swarm <task>`, preview, labelled quota heavy). Use it only when all of these hold: the subtask is big and self-contained (roughly 300+ changed lines or 6+ files in one bounded folder); acceptance tests exist or Claude writes them first; Gemini five-hour is 60% or more and weekly 40% or more; the owner accepted a quota-heavy run. Launch from an isolated worktree or clone: `agy -p "/swarm <goal>" --mode accept-edits --model <model> --print-timeout 20m --log-file <log> 2>&1`. A swarm is one task in the plan and never runs alongside other workers. Claude reviews the whole diff with the usual gate, reading the tests first.

## Spike S1 result (2026-11-13, agy 1.5.8): not supported at tier 0
Setup: throwaway repo, goal of three independent modules with frozen tests, run from an isolated clone with no remote and a sentinel file outside it: `agy -p "/swarm <goal>" --mode accept-edits --model gemini-3.8-flash-high --print-timeout 20m`.
Result: the `/swarm` command expanded and ran for about 30 seconds, then the coordinator's first `Bash` tool call was denied in headless mode (`no output produced ... "command" permission`) and the run ended after 0.6 minutes. Exit code 0, no file changed, tests still 0 of 3, sentinel intact, nothing written elsewhere, Gemini quota unchanged (five-hour 97% before and after).
Why the lane stays off: the denied command is not named in the log, so a tier-1 exact rule cannot be prepared in advance, and tier 2 (open shell for a whole swarm of agents) needs the owner's per-project yes and was not tried. If the owner wants to try it later: clone the project as in the tier-2 recipe, run the same command with no `--mode` flag, and check the clone, the sentinel and the quota afterwards; mark the lane supported only if the diff is correct and the quota change is about 15% of the five-hour limit or less.
