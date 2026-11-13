# Design: smarter delegation (offload judgement, Hydrogen routing, hybrid orchestration)

Date: 2026-11-13. Status: draft for approval. Repo: antigravity-delegate, plugin 0.3.0 -> 0.4.0.

## Intent and why
The owner is a vibe coder (also an oncology resident using the `antigravity-digest` skill). They want to spend **less Claude usage (tokens and limits) and less of their own time**. The skill today delegates only when told to, runs a few workers under tight permissions, and has no way to tell whether a given offload pays off. Four things changed: Google's **Gemini 4 Hydrogen** is available in `agy` (the owner states it matches Sonnet 5.5 at coding; unmeasured), `agy` 1.5.8 added swarms and per-run settings, the owner's account turned out to allow open shell in default mode, and the owner asked for (a) a judgement of whether offloading is worth it and (b) agent orchestration. The owner chose the **hybrid** orchestration approach.

## Goals
1. Before delegating, Claude decides per task: KEEP, DELEGATE, SPLIT or SWARM, with a one-line reason and a rough cost comparison, and improves over time from a ledger of past outcomes.
2. Route work by model: Flash for mechanical work, Hydrogen for substantive coding, scarcer models only when needed, all quota-aware.
3. Orchestrate multi-part goals: Claude-led parallel workers by default, plus a native `agy` swarm lane for big self-contained subtasks if a spike shows swarms work headless.
4. Offer permission tiers so workers can do what a task needs without editing the owner's global config; the default stays safe, and the owner's open-shell account can be used by opt-in with containment.
5. Ship it: push to GitHub and update the plugin installed on the owner's machine.

## Non-goals
- No automatic merge or push; Claude still reviews every diff and the owner decides on merge and push.
- No wildcard allow rules (they do not exist in `agy`).
- No money accounting and no exact token counting; estimates are order-of-magnitude.
- No changes to `agy` or Claude Code; no change to the `antigravity-digest` workflow beyond sharing the model table.

## Anti-goals (a failure even if it technically works)
- Delegating a task that costs Claude more to specify and review than to just do.
- A judgement step so heavy it eats the saving (target: a minute, about ten lines).
- Unreviewed code reaching `main`, or a worker able to reach the owner's real repo history or remote.
- Silently draining Gemini quota, especially Argon (weekly pool was at 12%).

## Facts this rests on
Verified on `agy` 1.5.8, Windows + PowerShell, 2026-11-13 (older items from 1.4.6 are marked):
- Models listed: `gemini-4-hydrogen-{low,medium,high,xhigh}`, `gemini-3.8-flash-{low,medium,high}`, `gemini-4-argon-{low,medium,high}`, `gemini-pro-orchestrator-g1-pro`, `claude-{opus,sonnet}-5-5-*`, `gpt-oss-120b-medium`. `--effort` conflicts with a model id that already has an effort suffix (1.4.6).
- With **no `--mode` flag** (default mode) the owner's account ran a file-creating command and a web request with no allow rule. With `--mode accept-edits` unlisted commands are denied. `--mode auto` is not available on the account.
- `--settings <file or json>` applies per run and never saves. An exact `command(...)` rule works. Wildcard spellings `echo wild*`, `echo:*` and `echo *` were all denied.
- `--add-dir` makes a folder part of the workspace for that run (writes verified on 1.4.6, PDF reads verified).
- `/usage` shows pools: Gemini Models, Claude and GPT, and an Argon weekly row. Hydrogen's pool is unknown: a small test call moved no percentage.
- Changelog: swarms (`/swarm <task>`, 1.5.5 preview, "quota heavy"), workers and subagents get a worktree that includes uncommitted changes, headless `-p` without `--print-timeout` waits for background tasks.

Not verified: Hydrogen quality versus Flash (and the owner's Sonnet-5.5 claim), Hydrogen's quota pool, `/swarm` in headless mode, whether an isolated clone really contains a tier-2 worker, whether the ledger improves decisions.

## Approaches considered
**Orchestration** (owner picked 1):
1. *Hybrid*: Claude splits goals into tasks and runs parallel workers; a big self-contained subtask may go to a native swarm, only if a spike passes. Keeps Claude's review gate on everything; saves the most where it is safe.
2. *Claude-led only*: same without swarms. Simplest and most controlled; leaves the swarm's parallelism unused.
3. *Swarm-first*: hand the whole goal to a Gemini swarm and review the final diff. Biggest saving of owner time up front, but heavy Gemini quota, preview software, and one huge diff can cost more Claude tokens to review than were saved.

**Offload judgement** (my call, no objection raised): a plain checklist (easy, but no way to learn) versus a scored estimate plus a small outcome ledger (a little more work, but later decisions use real numbers). Chosen: scored estimate plus ledger.

**Permissions** (my call): keep only the global allowlist (safe, but it is the restriction the owner complained about) versus three tiers. Chosen: tiers.

## Design

### D1. Route step (the offload judgement)
Runs before any delegation and whenever the owner gives a multi-part task. Claude estimates, then states the verdict in one line plus a short table row. Inputs: files touched; changed lines (estimate); packet-to-diff ratio (how many lines the spec needs relative to the code it produces); ambiguity (0 clear, 1 some, 2 needs a design decision); independence (can it run while Claude or the owner does something else); checkability (existing tests or acceptance tests Claude can write); sensitivity (money, auth, security).

Score (weights are provisional, my call):
- Diff size: under 15 lines KEEP outright; 15-39 lines 0; 40-149 lines +1; 150+ lines or 4+ mostly mechanical files +2.
- Packet-to-diff ratio: at most 25% +1; over 60% -2.
- Ambiguity 2: KEEP and resolve with the owner first.
- Checkable by tests +1; no check -1.
- Independent, can run in the background +1 (this is the owner's-time term).
- Sensitive -1, unless Claude writes the acceptance tests (then 0).

Verdict: score 3 or more DELEGATE; 1-2 DELEGATE only if it runs in parallel or in the background; 0 or less KEEP. Two or more independent file groups -> SPLIT (D4). The break-even is: delegate when (packet writing + diff review + expected rework) is clearly less than writing it directly. After at least five ledger rows for a model, Claude reads the ledger summary (D5) and adjusts the thresholds for that model, saying so in the verdict line.

### D2. Model routing (provisional until benchmark B1)
| Work | Model |
|---|---|
| Mechanical: CSS, boilerplate, CRUD, docs, tests from a clear spec | `gemini-3.8-flash-high` |
| Substantive coding: logic, multi-file features, refactors, test-driven work | `gemini-4-hydrogen-high` (medium for modest tasks) |
| Hard: cross-cutting, subtle invariants, Hydrogen-high failed once | `gemini-4-hydrogen-xhigh`; Argon only if its weekly quota is 25% or more |
| Gemini pools low, Claude/GPT pool 20% or more | `claude-sonnet-5-5-high` via `agy` |

Quota gates and the "always pass `--model`" rule stay. Benchmark B1 runs three real packets (mechanical, logic, refactor) on Flash-high and Hydrogen-medium/high and records first-pass acceptance, review issues, minutes and quota delta per pool. If Hydrogen does not beat Flash on mechanical work, Flash stays the mechanical default. The defaults in the shipped skill are marked "provisional" until B1 is recorded.

### D3. Permission tiers
- **Tier 0 (default):** `--mode accept-edits` plus the installed allowlist. As today.
- **Tier 1 (scoped):** tier 0 plus a per-run settings file listing the exact commands a packet needs (`--settings <file>`), plus `--add-dir` for extra folders. The settings file lives outside the repo and is deleted afterwards. No global config change.
- **Tier 2 (trusted):** no `--mode` flag, so the account's open shell, network and writes apply. Only after the owner says yes for that project. Containment (my call): run in an isolated clone (`git clone --no-hardlinks`, then `git remote remove origin`) instead of a worktree, so `git push`, `git branch -D` and `git reset` cannot reach the real repo; Claude fetches the branch back for review. No production secrets in the clone. Claude Code's own safety classifier may refuse to launch such a worker; if so Claude stops and tells the owner and does not work around it.
- The owner's per-project choice is stored in `%USERPROFILE%\.agy-delegate\config.json` (`{"projectTiers": {"<absolute path>": 2}}`, default 0), written only after an explicit yes. `--dangerously-skip-permissions` stays unused.

### D4. Orchestration (hybrid)
**Planner.** For a multi-part goal Claude writes a task list: id, goal, allowed files, depends-on, tier, model, route verdict. File sets must be disjoint; overlaps are sequenced or merged into one task.

**Waves.** Up to a quota-based cap of parallel workers: Gemini five-hour 60% or more allows 3, 30-59% allows 2, under 30% allows 1. One worktree (tier 0/1) or clone (tier 2) per task. Claude reviews each finished task with the existing gate (status, diff against the allowed list, tests re-run by Claude, full diff read), merges accepted branches into an integration branch `agy/<goal>` in dependency order, then runs the full tests on it. Two fix rounds per task, then Claude takes over; Claude re-plans if a dependency fails. Merge to `main` and push remain the owner's call.

**Swarm lane (off until spike S1 passes).** Eligible when the subtask is big and self-contained (roughly 300+ changed lines or 6+ files in a bounded folder), acceptance tests exist or Claude can write them, Gemini five-hour is 60% or more and weekly 40% or more, and the owner accepted a quota-heavy run. Launch `agy -p "/swarm <goal>"` with `--print-timeout` and `--log-file` inside an isolated worktree or clone; Claude then reviews the whole diff with the usual gate, reading tests first. A swarm counts as one task and never runs alongside other workers.

**Spike S1.** On a disposable repo with a goal needing three independent files: does `/swarm` start and finish headless, what reaches stdout, which files change, quota delta, wall time, any write outside the workspace. Pass: correct diff and a quota delta of about 15% of the five-hour limit or less. Otherwise the lane ships documented as unsupported.

The `gemini-pro-orchestrator-g1-pro` model is not used: Claude is the orchestrator.

### D5. Ledger
`%USERPROFILE%\.agy-delegate\ledger.jsonl`, one line per delegated task: date, project (path only), task id, verdict and score, model, tier, changed files and lines, first-pass accepted (yes/no), fix rounds, minutes, Gemini five-hour and weekly percentage points used, note. No code and no prompts are stored. `scripts/ledger.ps1` has `-Add` and `-Summary` (per model: tasks, first-pass rate, average fix rounds, average minutes, average quota per task).

### D6. Files
- `skills/antigravity-delegate/SKILL.md`: new Route step, updated model table and permission tiers, pointers to the references, description updated with new trigger phrases ("is it worth delegating", "run these in parallel"). Detail moves into:
- `skills/antigravity-delegate/references/routing.md` (score, model table, ledger use, eight canned scenarios with expected verdicts) and `references/orchestration.md` (planner, waves, swarm lane, spike S1 result).
- `skills/antigravity-delegate/scripts/ledger.ps1`.
- `README.md`, `plugin.json` (0.4.0). `antigravity-digest` only gets the shared model note.

### D7. Release and install
Run the tests below, commit, push `main`, then update the owner's installed plugin from the marketplace (the owner's machine currently has 0.2.0 at commit `72baeb0`): `claude plugin marketplace update` and `claude plugin update` if the CLI is available, otherwise tell the owner the `/plugin` steps. Verify `installed_plugins.json` shows the new version and commit. A new session is needed to load it. No other plugin is touched.

## Tests and acceptance
T1 benchmark B1. T2 the eight canned routing scenarios give the expected verdicts when Claude applies the rubric. T3 ledger add and summary round-trip on a temp file. T4 tier 1: an exact rule in `--settings` runs, an unlisted command is denied. T5 tier 2 containment: in a clone with the remote removed, `git push` fails and the real repo is unchanged. T6 orchestration dry run: three tiny independent packets in two waves on a throwaway repo, merged and tested. T7 swarm spike S1. T8 install check: installed version and commit equal the pushed ones.

Success: every test passes or its feature is documented as unsupported; main `SKILL.md` stays readable (about 170 lines or less); no secrets committed.

## Calls I made (please check)
Scoring weights and thresholds; model table defaults; quota-based worker cap; ledger location and fields; clone isolation for tier 2; per-project tier stored in the owner's home folder; not using the Orchestrator model; swarm lane off until a spike passes; the 0.4.0 version number.

## Left to the builder
Exact wording of the verdict line, script flag names, how the references are laid out, and tuning thresholds after B1.
