---
name: antigravity-delegate
description: Delegate well-specified implementation packets (features, views, models, tests, CSS, refactors, docs) to the Antigravity CLI (agy) running headless in isolated git worktrees. First judges whether offloading is worth it (a scored Route step), checks the user's agy quota, picks the model (Gemini 3.8 Flash for mechanical work, Gemini 4 Hydrogen for substantive coding), runs independent tasks in parallel waves into an integration branch, logs outcomes, then reviews and commits as Claude. Works in any git project. Use when the user says delegate/hand off to agy, Antigravity, Gemini, Flash or Hydrogen, asks whether it is worth delegating, wants several tasks run in parallel, or when a plan has several independent implementation tasks.
---

# antigravity-delegate: Claude architects and reviews, agy implements

Verified on agy 1.5.8, Windows + PowerShell, 2026-11-13 (items marked 2026-10-23 were verified on 1.4.6). Re-check `agy --version` / `agy --help` after updates. macOS/Linux flags are the same but untested.

## Defaults (edit here, everything below follows them)
- **Mechanical work:** `gemini-3.8-flash-high` (high effort on Flash is cheap in practice; change it if your plan differs).
- **Substantive coding:** `gemini-4-hydrogen-high` (`gemini-4-hydrogen-medium` for modest tasks). Benchmark B1 (`references/benchmarks.md`): same first-pass results as Flash, 2-4x faster on logic and refactor packets, closer to the spec on the refactor. It draws from the Gemini Models pool (inferred). One run per cell, so provisional; the ledger corrects it.
- **Hard packets:** `gemini-4-hydrogen-xhigh`; `gemini-4-argon-high` (about Opus 5.5 level, small weekly limit) only when quota allows (table below).
- **Fallbacks:** `claude-sonnet-5-5-high` / `claude-opus-5-5-high` (Claude/GPT pool). `agy models` lists all ids; listed does not mean you have credits.
- **ALWAYS pass `--model`.** Omitting it runs Gemini 4 Argon (Medium) and silently burns the scarcest quota. Do not add `--effort` to a model id that already ends in `-high`: agy rejects the pair ("conflicts with --effort"). Use `--effort` only with an id that has no effort suffix.
- **Parallel packets:** up to 3 at once, fewer when the Gemini five-hour quota is low (cap table in `references/orchestration.md`).

## Be bold: what to delegate
Rule: **if you can write the acceptance test or the exact diff criteria, delegate it.** Claude is the architect and reviewer; every diff is reviewed before it is committed, in a throwaway worktree, so risk is bounded. Delegate by default: new models/views/forms/templates, CRUD, CSS, test suites, refactors with a clear boundary, doc updates, migrations (review them), and even sensitive code (money, auth, audit) **when Claude writes the invariants and acceptance tests into the packet and reviews every line**.
Keep with Claude: architecture and design decisions; ambiguous specs (resolve with the user first); work needing secrets or production access; destructive git operations; merging and pushing; and trivial edits (under ~5 lines are faster done directly).

## Step 0: preflight (cheap, always)
1. `agy --version`. If `-p` ever exits 0 with empty output and no stderr, the CLI is signed out: ask the user to run `agy` once.
1b. **Command rules (once per machine, cheap to re-check).** Workers can only run shell commands that exactly match an allow rule, so check the user's rules are installed: run the installer as a dry run (it changes nothing):
   `powershell -NoProfile -ExecutionPolicy Bypass -File <this skill's directory>\scripts\install-rules.ps1`
   It prints, per group, how many rules are missing. If it says "Nothing to add", continue. Otherwise tell the user how many rules would be added (to `~/.gemini/config/config.json`, global to every agy session, backup made first) and ask in chat. Only on a clear yes run it again with `-Apply`. The `install` group (npm install, pip install -r, cargo fetch, ...) runs third-party install scripts and needs its own yes: `-Groups install -Apply`. If the user declines, carry on with whatever rules they already have; never edit the config by any other route.
2. **Quota.** `agy -p "/usage"` (client command, instant, no model call). Output is tab-separated lines `group  metric  pct  reset-time-UTC`:
   `Gemini Models | Weekly / Five Hour Limit Remaining`, `Claude and GPT models | Weekly / Five Hour ...`, `Gemini 4 Argon | Weekly Limit`.
   **Always show it to the user at the start** as a table, and keep the numbers as the START snapshot for the closing report (Step 4):
   `| Pool | Weekly left | Weekly resets | 5-hour left | 5-hour resets |` (Argon has only a weekly row; give reset times in the user's local time if known, else UTC). Warn on any pool under 10%. If `/usage` fails or prints nothing, write "quota unavailable" in the table; never skip the table silently.
3. **Pick the model:**

| Situation | Choice |
|---|---|
| Gemini pool weekly >= 10% and five-hour >= 10% | `gemini-3.8-flash-high` for mechanical packets, `gemini-4-hydrogen-high` for substantive coding |
| Packet is hard (cross-cutting, subtle invariants, Hydrogen-high already failed once) | `gemini-4-hydrogen-xhigh`; `gemini-4-argon-high` only if Argon weekly >= 25%, one packet at a time |
| Gemini pool low but Claude/GPT pool >= 20% | `claude-sonnet-5-5-high` |
| Everything low | do it in Claude, or tell the user the reset time from `/usage` |

Re-run `/usage` between waves of packets and show a one-line update. State the chosen model, and why, next to the start table. Per-packet cost is not reported; measured once: a small Flash-high packet (2 files, 78 s) cost about 1% of the Gemini five-hour limit and 0% of the weekly one. Re-measure for big packets.
4. **Project profile** (read once per project from AGENTS.md / CLAUDE.md / README): test command and interpreter (e.g. a venv python), env files and DB setup, hard invariants / "never" lists, commit conventions. Put the relevant lines in every packet; the worker does not know them.

## Step 0b: Route (is offloading worth it?)
Before delegating anything, and whenever the owner gives a multi-part task, score the task with `references/routing.md` (diff size, packet-to-diff ratio, ambiguity, checkability, independence or background fit, sensitivity) and print one line: `Route: <KEEP|DELEGATE|SPLIT> (<model>, <n> workers). Why: <reason>. Est: Claude direct ~<x>k tokens vs delegate ~<y>k.`
The aim is less Claude usage and less of the owner's time. Under 15 changed lines, or an ambiguous spec, is KEEP: do it directly (or ask). Do not delegate when writing the packet and reading the diff would cost about as much as writing the code. With 5 or more ledger rows for a model, read `scripts/ledger.ps1 -Summary` first and adjust as `routing.md` says. Keep this step to a minute and about ten lines.

## Permission reality (verified; design around it)
The default launch is `--mode accept-edits` (tier 0, see "Worker permission tiers" below). Then:
- File writes succeed **only inside the working folder** (outside is denied). Reads outside it are denied too in headless mode (verified 2026-10-24 on a PDF: "no output produced ... `read_file` permission"); add the folder for that launch with `--add-dir <folder>`. Once a folder is added the worker can read all of it, so keep secrets out of any folder you add.
- **Shell commands are denied** unless the whole command string exactly matches a rule in `~/.gemini/config/config.json` -> `userSettings.globalPermissionGrants.allow`. Matching is exact: `command(...)` rules with `*` do NOT work (tested `pytest tests/*`), so `pytest tests/x.py` or an extra flag is denied, and every useful flag combination needs its own rule. This skill ships a wide list in `rules/allowlist.json` (git read-only, directory inspection, Python venv Windows/Unix and no-venv incl. ruff/mypy/black/flake8/Django, Rust, Node/pnpm/yarn/bun, Go, .NET, JVM, Ruby/PHP/make, R, plus an opt-in `install` group) and `scripts/install-rules.ps1` merges it into the user's config after they agree (Step 0, item 1b). Verified working (2026-10-23): venv pytest, `cargo check`, `npm test`, `npm run lint`, and from the later expansion `git diff --name-only` (installed by the script, then run by agy). The other rules added in the later expansion use the same format but each one is untested until first used; if one is denied, say so rather than assume. Bare `node --test` is denied despite a matching rule (use `npm test`). R, pnpm and yarn rules are untested.
- **Extra directories:** `--add-dir <path>` (repeatable) on a launch makes that folder part of the workspace for that run only. Verified 2026-10-23: with `--mode accept-edits --add-dir <sibling>` a file write into the sibling succeeded (without the flag it is denied) while a shell command was still denied. Use it per launch, never as a standing grant (see "Scope requests").
- `permissions.allow` `write_file(...)` rules in the CLI settings do **not** work. `--sandbox` does not unlock commands. `--mode auto` was unavailable on the tested account (agy warns and falls back); re-check on yours. `--dangerously-skip-permissions` approves every tool call with no limits and the worktree does not contain a shell: it shares `.git` with the main checkout (so `git push`, `git branch -D`, `git reset` reach your real repo), can read env files and use the network, and none of that shows in the diff. Never use it by default. It is untested here (this session's own safety classifier refused to launch it). Only if the user explicitly asks for a fully autonomous run in a given packet, warn them of the above in one sentence, get a clear yes for that packet, and keep Step 3 review unchanged.
- So the loop is: the worker edits files and may run the **allow-listed** whole-suite checks; **Claude always re-runs the tests itself** and sends failures back. For a command not on the list, propose the exact `command(<full command>)` rule to the user; add it only by the same ask-then-yes route as the installer, never silently.
- Venv projects: the rule path is relative to the worktree, so give each worktree the interpreter via a junction: `cmd /c mklink /J .venv <main-checkout>\.venv` (verified). Projects without a venv use the plain `python`/`py`/`pytest`/`cargo`/`npm` rules.
- **Allowing test runs lifts the write confinement:** pytest/cargo/npm execute worker-written code as the user with whatever is in the worktree (e.g. a copied `.env`). Acceptable only because Claude reviews every diff before anything is committed; point workers only at dev databases and never put production secrets in a worktree.

### Worker permission tiers (verified 2026-11-13, agy 1.5.8)
| Tier | Launch | Use when |
|---|---|---|
| 0 (default) | `--mode accept-edits` plus the installed allowlist | everything, unless the packet needs more |
| 1 (scoped) | tier 0 plus `--settings <file>` holding `{"permissions":{"allow":["command(<exact string>)"]}}` for the exact commands the packet needs, plus `--add-dir <folder>` for extra folders | the packet needs one or two commands that are not in the allowlist |
| 2 (trusted) | no `--mode` flag, in an isolated clone | only after the owner says yes for this project |

- **Tier 1** (verified): an exact rule in `--settings` let `node --version` run; the unlisted `node -e ...` was denied. Rules are exact: `*`, `:*` and ` *` wildcards are all denied. Write the file outside the repo, delete it after the run. It adds to the global allowlist for that run only and never edits the user's config.
- **Tier 2** (verified): on the owner's account (Turbo preset), a launch with no `--mode` ran a file-creating command and a web request with no rule at all, and `--mode auto` is unavailable. So the account is open and the worktree is not a sandbox. Containment recipe, checked with plain git: `git clone --no-hardlinks <repo> <clone-outside-the-repo>`, then `git -C <clone> remote remove origin`. Inside that clone `git push`, `git branch -D main` and `git reset` cannot reach the real repo; bring the work back with `git fetch <clone> <branch>:agy/<name>`, never over `main`. This stops accidents, not a worker that deliberately uses the original repo's path. Keep production secrets out of the clone.
- **Where the choice is stored:** `%USERPROFILE%\.agy-delegate\config.json`, `{"projectTiers": {"<absolute project path>": 2}}`; a missing file or entry means tier 0. Ask the owner once per project and write the file only after an explicit yes. "Tier 2 for this run only" is allowed and writes nothing.
- If Claude Code's own safety classifier refuses to launch a tier-2 worker, stop and tell the owner; do not work around it. `--dangerously-skip-permissions` stays unused.
- The Step 3 review is identical at every tier.

## Step 1: write the packet (precision is the whole job)
Save as `<repo>/docs/handoff/<packet>.md` (or any tracked-or-ignored path inside the worktree). Template:
```
# Packet <ID>: <one-line goal>
Context to read first: <files/dirs, plus AGENTS.md/CLAUDE.md>
Project rules (copied): <test cmd, invariants, naming, style, "never" list>
You may create/edit ONLY: <explicit file list>      You must NOT touch: <everything else, tests listed as frozen, migrations unless named>
Behaviour: <exact functions/signatures/URLs/templates/fields, edge cases, error cases>
Tests first: <test file + the cases to write; they must fail before the code exists>
Acceptance: <commands Claude will run and the expected result; invariants that must hold>
Checks you may run (exact strings only, no added flags or paths): <the allow-listed commands for this project, e.g. .venv\Scripts\python.exe -m pytest -q>
Do not: commit, push, install packages, run any other shell command, change dependencies, refactor unrelated code, add features.
Out of scope: if you need a file or folder outside this worktree, or a command not listed above, do NOT attempt it (a denied tool call ends the whole run with no output). Finish what you can and list each need under "Needs" in the report: the exact path or command, and why.
Report: write .agy-report.md at the worktree root: files changed, assumptions, anything unsure, Needs. If blocked, stop and say why there.
```
Sensitive packet? Write the acceptance tests yourself, mark them frozen, and tell the worker to make them pass without editing them.

## Step 2: isolate and launch
Per packet (independent packets must have disjoint file sets; dependent ones go in waves):
```powershell
git worktree add ..\<repo>-<packet> -b <packet> main
# copy env files; give each worktree its own DB/test-DB name if the project uses one
Set-Location ..\<repo>-<packet>
agy -p "Read <packet path> and do it exactly. Do not commit or push. Run only the checks the packet lists, as exact strings." --mode accept-edits --model <model from Step 0b> --print-timeout 30m --log-file ..\agy-<packet>.log 2>&1
```
- Call `agy` directly, never via Start-Process (it splits the prompt on spaces). `2>&1` is required: denials go to stderr only.
- Run each launch with `run_in_background`; you are notified on exit. Do not poll or sleep. Launch up to 3 packets in one message.
- Follow-up on the same worker: `agy -p "<fix list>" -c ...` (continue latest) or `--conversation <id>` (find it in the log). Max 2 fix rounds, then take over or re-spec.

## Step 3: judge and review (never trust exit code or the worker's DONE)
Exit 0 means nothing (timeouts also return exit 0 with partial output).
1. stderr says `no output produced ... <tool> permission`: a permission was denied (the message names the permission type; look in `--log-file` for the exact command or path, not verified). Handle it with "Scope requests" below; never widen permissions on your own.
2. `git -C <worktree> status` and `git diff main`: only the allowed files changed? Anything outside the list is rejected.
3. Run the full test suite yourself in the worktree. Confirm new tests really fail without the change when the packet is about behaviour.
4. Read the whole diff. Check: frozen tests untouched and not weakened, no unrelated edits, project invariants (e.g. no float money, parameterized queries), security-sensitive paths line by line, no secrets or `.agy-report.md` committed.
5. Good: stage explicit paths, commit as Claude with the repo's convention. Bad: fix-up round (Step 2) or revert the worktree.
6. Merge, push and PRs only when the user says so.
7. Log the outcome so later Route steps use real numbers: `powershell -NoProfile -ExecutionPolicy Bypass -File <this skill's directory>\scripts\ledger.ps1 -Add ...` (fields in `references/orchestration.md`, section 6). No code or prompts go in the ledger.

## Orchestrating several packets
When the Route step says SPLIT (two or more independent file groups), follow `references/orchestration.md`: a task plan with an overlap check, waves capped by the Gemini five-hour quota, one worktree per task, the Step 3 review for each task, and merges into an integration branch `agy/<goal>`. A native `agy` swarm is not supported today (spike S1 was denied at tier 0); use parallel workers. Merging to main and pushing stay the owner's call.

## Scope requests: files, folders and commands outside the packet
Headless `-p` cannot ask a question mid-run, so approval happens between runs: the worker stops (denial) or lists its "Needs" in `.agy-report.md`, then Claude decides whether the need is relevant to the packet and answers it in the cheapest safe way:
1. **Read-only need (docs, a sibling module, a schema):** copy the file into the worktree or quote the relevant part in the packet, then continue with `-c`. No permission change. If the material is large (PDFs, a whole docs folder), relaunch with `-c --add-dir <folder>` instead, since reads outside the worktree are denied without it.
2. **Write to an extra folder the packet really needs (shared fixture dir, a second package, a docs folder outside the worktree):** relaunch with `-c --add-dir <narrowest folder>`. Per launch only.
3. **A command not on the allowlist:** if it is a read-only or check-style command, propose the exact `command(<full string>)` rule to the user in chat and add it with their yes (same installer/backup route); if it installs, deletes, pushes or touches the network, keep it with Claude and run it yourself.
Never grant: the home directory or drive roots, `~/.ssh`, `~/.gemini`, `~/.claude`, cloud credentials, env files with real secrets, the main checkout's `.git`, or anything the user did not make part of the task. Ask the user first when relevance is unclear. Count a scope request as one of the two fix rounds.

## Step 4: closing quota report (always the last thing you show)
Run `agy -p "/usage"` again and print, per pool, START -> END and the difference, plus which model ran how many packets:
`| Pool | Weekly start -> end | 5-hour start -> end | Used |` and one line such as "gemini-3.8-flash-high: 3 packets".
Percentages are whole numbers, so a small packet may show 0-1% change; say so rather than implying precision. Show this report even when nothing was delegated or the run was abandoned. If any pool is under 10%, add when it resets.

## Cleanup
First remove a `.venv` junction with `cmd /c rmdir <worktree>\.venv` (NEVER `Remove-Item -Recurse` or a recursive delete on it: that can wipe the real venv). Then `git worktree remove <path> --force` and `git branch -d <packet>` after merge/discard; delete logs. Remove any `.agy-report.md`.

## Failure cheatsheet
| Symptom | Cause / action |
|---|---|
| Empty output, exit 0 | signed out, or a denial: rerun with `2>&1` and read stderr |
| `warning: --mode auto is not available` | account lacks it; use accept-edits |
| Worker edited outside the list | reject; tighten the packet's "ONLY" list |
| Argon quota dropped unexpectedly | a run omitted `--model` |
| Worker claims tests pass | it could not run them; run them yourself |
| Prompt split / garbled | launched through Start-Process or unescaped quotes |
| `--model ... conflicts with --effort` | model id already has an effort suffix; drop `--effort` |
| Write outside worktree denied | add `--add-dir <folder>` for that launch if Claude judges it relevant |
| `install-rules.ps1` blocked by execution policy | call it as `powershell -NoProfile -ExecutionPolicy Bypass -File ...` (per process only) |
| `/swarm` run ends with a `command` permission denial | swarm lane unsupported at tier 0; use parallel workers |

## Known unknowns
R/pnpm/yarn rules and the later-expanded rules (Go, .NET, JVM, Ruby/PHP/make, ruff/mypy/black, extra git/npm/cargo variants); why bare `node --test` is denied; `--mode plan`; `--output-format json` shape; per-packet quota cost; whether plain-text and image reads outside the worktree are also denied (only a PDF is verified); whether `--add-dir` also lifts the shell confinement (no evidence it does); `--sandbox` combined with `--dangerously-skip-permissions`; whether `--input-format stream-json` could carry live approvals; the installer on macOS/Linux (needs PowerShell 7 `pwsh`, untested); a swarm at tier 2; whether Hydrogen matches Sonnet 5.5 (the owner's claim, unmeasured) or holds up on large or ambiguous tasks; Hydrogen's per-run quota (under 1% on small packets).
