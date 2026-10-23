---
name: antigravity-delegate
description: Delegate well-specified implementation packets (features, views, models, tests, CSS, refactors, docs) to the Antigravity CLI (agy) running headless in isolated git worktrees, check the user's agy quota first, pick the model, run packets in parallel, then review and commit as Claude. Works in any git project. Use when the user says delegate/hand off to agy, Antigravity, Gemini or Flash, or when a plan has several independent implementation tasks.
---

# antigravity-delegate: Claude architects and reviews, agy implements

Verified on agy 1.4.6, Windows + PowerShell, 2026-10-23. Re-check `agy --version` / `agy --help` after updates. macOS/Linux flags are the same but untested.

## Defaults (edit here, everything below follows them)
- **Workhorse:** `gemini-3.8-flash-high` (high effort on Flash is cheap in practice; change it if your plan differs).
- **Hard-packet model:** `gemini-4-argon-high` (about Opus 5.5 level, small weekly limit). Only when quota allows (table below) and Flash is likely to flounder.
- **Fallbacks:** `claude-sonnet-5-5-high` / `claude-opus-5-5-high` (Claude/GPT pool). `agy models` lists all ids; listed does not mean you have credits.
- **ALWAYS pass `--model`.** Omitting it runs Gemini 4 Argon (Medium) and silently burns the scarcest quota.
- **Parallel packets:** up to 3 at once.

## Be bold: what to delegate
Rule: **if you can write the acceptance test or the exact diff criteria, delegate it.** Claude is the architect and reviewer; every diff is reviewed before it is committed, in a throwaway worktree, so risk is bounded. Delegate by default: new models/views/forms/templates, CRUD, CSS, test suites, refactors with a clear boundary, doc updates, migrations (review them), and even sensitive code (money, auth, audit) **when Claude writes the invariants and acceptance tests into the packet and reviews every line**.
Keep with Claude: architecture and design decisions; ambiguous specs (resolve with the user first); work needing secrets or production access; destructive git operations; merging and pushing; and trivial edits (under ~5 lines are faster done directly).

## Step 0: preflight (cheap, always)
1. `agy --version`. If `-p` ever exits 0 with empty output and no stderr, the CLI is signed out: ask the user to run `agy` once.
2. **Quota.** `agy -p "/usage"` (client command, instant, no model call). Output is tab-separated lines `group  metric  pct  reset-time-UTC`:
   `Gemini Models | Weekly / Five Hour Limit Remaining`, `Claude and GPT models | Weekly / Five Hour ...`, `Gemini 4 Argon | Weekly Limit`.
3. **Pick the model:**

| Situation | Choice |
|---|---|
| Gemini pool weekly >= 10% and five-hour >= 10% | `gemini-3.8-flash-high` for ordinary packets |
| Packet is hard (cross-cutting, subtle invariants, Flash already failed twice) and Argon weekly >= 25% | `gemini-4-argon-high`, one packet at a time |
| Gemini pool low but Claude/GPT pool >= 20% | `claude-sonnet-5-5-high` |
| Everything low | do it in Claude, or tell the user the reset time from `/usage` |

Re-run `/usage` between waves of packets. State the quota and chosen model to the user in one line. Per-packet cost is not reported; measured once: a small Flash-high packet (2 files, 78 s) cost about 1% of the Gemini five-hour limit and 0% of the weekly one. Re-measure for big packets.
4. **Project profile** (read once per project from AGENTS.md / CLAUDE.md / README): test command and interpreter (e.g. a venv python), env files and DB setup, hard invariants / "never" lists, commit conventions. Put the relevant lines in every packet; the worker does not know them.

## Permission reality (verified; design around it)
Use `--mode accept-edits`. Then:
- File writes succeed **only inside the working folder** (outside is denied). Reads are not confined, so keep secrets out of reach.
- **Shell commands are denied** unless the whole command string exactly matches a rule in `~/.gemini/config/config.json` -> `userSettings.globalPermissionGrants.allow`. Matching is exact: `command(...)` rules with `*` do NOT work (tested `pytest tests/*`), so `pytest tests/x.py` or an extra flag is denied. Ready-made lists are in this plugin's `rules/allowlist.json` (read-only git; Python with a venv on Windows/Unix and without; Rust; Node; R); the user merges the groups they want into their own config. Verified working (2026-10-23): venv pytest, `cargo check`, `npm test`, `npm run lint`. Bare `node --test` is denied despite a matching rule (use `npm test`). R, pnpm and yarn rules are untested. Install/network commands (`npm install`, `cargo add`, `pip install`) are deliberately not on the list.
- `permissions.allow` `write_file(...)` rules in the CLI settings do **not** work. `--sandbox` does not unlock commands. `--mode auto` was unavailable on the tested account (agy warns and falls back); re-check on yours. `--dangerously-skip-permissions` removes all limits: never use it.
- So the loop is: the worker edits files and may run the **allow-listed** whole-suite checks; **Claude always re-runs the tests itself** and sends failures back. For a command not on the list, propose the exact `command(<full command>)` rule to the user and let them add it; never edit that config yourself.
- Venv projects: the rule path is relative to the worktree, so give each worktree the interpreter via a junction: `cmd /c mklink /J .venv <main-checkout>\.venv` (verified). Projects without a venv use the plain `python`/`py`/`pytest`/`cargo`/`npm` rules.
- **Allowing test runs lifts the write confinement:** pytest/cargo/npm execute worker-written code as the user with whatever is in the worktree (e.g. a copied `.env`). Acceptable only because Claude reviews every diff before anything is committed; point workers only at dev databases and never put production secrets in a worktree.

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
Do not: commit, push, install packages, run shell commands, change dependencies, refactor unrelated code, add features.
Report: write .agy-report.md at the worktree root: files changed, assumptions, anything unsure. If blocked, stop and say why there.
```
Sensitive packet? Write the acceptance tests yourself, mark them frozen, and tell the worker to make them pass without editing them.

## Step 2: isolate and launch
Per packet (independent packets must have disjoint file sets; dependent ones go in waves):
```powershell
git worktree add ..\<repo>-<packet> -b <packet> main
# copy env files; give each worktree its own DB/test-DB name if the project uses one
Set-Location ..\<repo>-<packet>
agy -p "Read <packet path> and do it exactly. Do not commit, push, or run shell commands." --mode accept-edits --model gemini-3.8-flash-high --print-timeout 30m --log-file ..\agy-<packet>.log 2>&1
```
- Call `agy` directly, never via Start-Process (it splits the prompt on spaces). `2>&1` is required: denials go to stderr only.
- Run each launch with `run_in_background`; you are notified on exit. Do not poll or sleep. Launch up to 3 packets in one message.
- Follow-up on the same worker: `agy -p "<fix list>" -c ...` (continue latest) or `--conversation <id>` (find it in the log). Max 2 fix rounds, then take over or re-spec.

## Step 3: judge and review (never trust exit code or the worker's DONE)
Exit 0 means nothing (timeouts also return exit 0 with partial output).
1. stderr says `no output produced ... <tool> permission`: a permission was denied. Report which tool/command; never widen permissions on your own.
2. `git -C <worktree> status` and `git diff main`: only the allowed files changed? Anything outside the list is rejected.
3. Run the full test suite yourself in the worktree. Confirm new tests really fail without the change when the packet is about behaviour.
4. Read the whole diff. Check: frozen tests untouched and not weakened, no unrelated edits, project invariants (e.g. no float money, parameterized queries), security-sensitive paths line by line, no secrets or `.agy-report.md` committed.
5. Good: stage explicit paths, commit as Claude with the repo's convention. Bad: fix-up round (Step 2) or revert the worktree.
6. Merge, push and PRs only when the user says so.

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

## Known unknowns
R/pnpm/yarn rules; why bare `node --test` is denied; `--mode plan`; `--output-format json` shape; per-packet quota cost; whether reads outside the worktree can be restricted.
