# antigravity-delegate

A [Claude Code](https://claude.com/claude-code) skill that lets Claude act as architect and reviewer while the **Antigravity CLI (`agy`)** does the typing: Claude writes a precise packet, `agy` implements it headless in an isolated git worktree, and Claude reviews the diff, runs the tests and commits.

> Unofficial. Not affiliated with or endorsed by Google or Anthropic. "Antigravity" is Google's product name. Verified on **agy 1.4.6, Windows + PowerShell, 2026-10-23** on a single account; macOS/Linux use the same flags but are untested. Behaviour may change with newer `agy` releases.

## What it does
- **Checks quota first.** `agy -p "/usage"` is instant and costs no model call; the skill shows your weekly / five-hour limits as a table at the start and a start-to-end report when it finishes, and picks a model (default `gemini-3.8-flash-high`, Argon only for hard packets when its weekly quota allows, Claude models as fallback).
- **Always passes `--model`.** Without it `agy` silently uses the scarcest default model.
- **One git worktree per packet**, up to three in parallel with disjoint file lists.
- **Packet template** with explicit allowed/forbidden files, tests first, acceptance commands, project rules copied in.
- **Review gate.** The exit code means nothing; Claude checks stderr, the diff against the allowed-file list, re-runs the tests and reads every line before committing. It never merges or pushes without you.

## Install
```text
/plugin marketplace add et-Celestosapien/antigravity-delegate
/plugin install antigravity-delegate@antigravity-delegate
```
(Plugin layout follows other Claude Code marketplaces; these commands are untested here.) Or copy `skills/antigravity-delegate/` into `~/.claude/skills/`.

Requirements: Claude Code, Antigravity CLI `agy` signed in (run `agy` once), git.

## Command cheat sheet (verified on agy 1.4.6)
| Command | What it does |
|---|---|
| `agy --version` | version |
| `agy models` | list model ids (listing is not the same as having credits) |
| `agy -p "/usage"` | quota: Gemini, Claude/GPT and Argon limits with reset times |
| `agy -p "<prompt>" --mode accept-edits --model <id> --print-timeout 30m --log-file x.log 2>&1` | headless worker; writes only inside the current folder |
| `-c` / `--conversation <id>` | continue the latest / a specific conversation |
| `--effort low\|medium\|high\|xhigh\|max` | reasoning effort (not with a model id that already ends in `-high`) |
| `--add-dir <folder>` | add a folder to the workspace for this run (repeatable) |
| `--output-format text\|json\|stream-json` | print-mode format (json shapes untested) |

Gotchas: call `agy` directly (PowerShell `Start-Process` splits the prompt on spaces); denials go to **stderr** only, so use `2>&1`; exit code 0 does not mean success; omitting `--model` burns your Argon quota; `--mode auto` was unavailable on the tested account.

## Permissions: what actually happens
With `--mode accept-edits`, file writes succeed only inside the working folder and shell commands are **denied unless the whole command line exactly matches an allow rule** in your agy config. Wildcards in rules do not work. `permissions.allow write_file(...)` rules, `--sandbox` and the "dangerously skip permissions" flag are not part of the recommended setup.

### Ready-made allow rules: [`rules/allowlist.json`](skills/antigravity-delegate/rules/allowlist.json)
About 180 exact-match rules in groups: read-only git, directory inspection, Python (venv on Windows/Unix and no venv; `pytest` variants, `ruff`, `mypy`, `black`, `flake8`, Django `manage.py`), Rust (`cargo`), Node (`npm`, `npx`, `pnpm`, `yarn`, `bun`), Go, .NET, JVM (`mvn`, `gradle`), Ruby/PHP/`make`, R. A separate **opt-in `install` group** (`npm install`, `pip install -r requirements.txt`, `cargo fetch`, ...) runs third-party install scripts, so it is never added unless you ask for it.

**Installer:** [`install-rules.ps1`](skills/antigravity-delegate/scripts/install-rules.ps1) merges them into `userSettings.globalPermissionGrants.allow` in your agy config (Windows: `%USERPROFILE%\.gemini\config\config.json`). It is a dry run by default, skips rules you already have, makes a timestamped backup before writing, and verifies the result (restoring the backup if the check fails). The skill runs the dry run on first use, tells you how many rules would be added, and applies only after you say yes in chat.
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File skills\antigravity-delegate\scripts\install-rules.ps1            # list what would change, y/N prompt in a terminal
powershell -NoProfile -ExecutionPolicy Bypass -File skills\antigravity-delegate\scripts\install-rules.ps1 -Apply     # no prompt
powershell -NoProfile -ExecutionPolicy Bypass -File skills\antigravity-delegate\scripts\install-rules.ps1 -Groups install -Apply
```
**The rules are global**: they apply to every `agy` session and the desktop app. Matching is exact (no wildcards), so `pytest tests/x.py` is still denied while `pytest -q` is allowed.

Verified working: venv `pytest`, `cargo check`, `npm test`, `npm run lint`, and `git diff --name-only` (installed by the script, then run by agy). Denied despite a matching rule: bare `node --test` (use `npm test`). The installer was tested on a copy of a real config (idempotent, kept all existing rules and other settings); the newer rules (Go, .NET, JVM, ruff/mypy, extra variants, R/pnpm/yarn) use the same format but have not each been run through `agy`.

### Extra folders and commands, approved by Claude
`agy -p` cannot ask for permission mid-run, so approval happens between runs. If a worker needs something outside its worktree it stops and lists it; Claude decides if it is relevant and either copies the file in, relaunches with `--add-dir <folder>` (verified: lets a write into that folder succeed for that run only), or proposes one more exact command rule to you. Home directory, credentials, `.ssh` and the main checkout's `.git` are never granted.

For venv projects, give each worktree the interpreter with a junction so the relative rule path resolves: `cmd /c mklink /J .venv <main-checkout>\.venv`. When cleaning up, remove it with `cmd /c rmdir .venv` **before** deleting the worktree; never recursively delete a junction.

## Safety notes
- Allowing `pytest`/`cargo`/`npm` runs worker-written code as you, with whatever is in the worktree (e.g. a copied `.env`). That lifts the write confinement; it is acceptable only because every diff is reviewed before it is committed. Use dev databases only and keep production secrets out of worktrees.
- Reads outside the worktree are not restricted by `agy`.
- The skill changes your agy config only through the installer, only after you agree, and always with a backup.
- `--dangerously-skip-permissions` (approve every tool call) is not part of the setup. A worktree does not contain a shell: it shares `.git` with your real repo, can read env files and use the network, and none of that shows up in the diff. It is untested here. If you want a fully autonomous run anyway, ask for it per packet and the skill will warn you first.

## Known unknowns
The installer on macOS/Linux (needs PowerShell 7), `--sandbox` combined with skip-permissions, whether `--input-format stream-json` could carry live approvals, `--mode plan`, the JSON output shape, per-packet quota cost beyond one small measurement (about 1% of the five-hour Gemini limit for a two-file packet), and why bare `node --test` is denied.

## License
MIT, see [LICENSE](LICENSE).
