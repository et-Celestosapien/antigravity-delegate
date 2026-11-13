# Benchmark B1: Flash vs Hydrogen (2026-11-13)

Setup: throwaway Node repo, three packets with frozen tests (`formatBytes`, `parseDuration`, a refactor of `invoice` plus a 10% discount), one fresh worktree per run, `--mode accept-edits`, worker allowed to run exactly `npm test`, `agy` 1.5.8, runs one after another. "First pass" = the packet's own frozen tests all passed on the worker's first result. Quota is the change in whole percentage points of `agy -p "/usage"` per run.

| Model | Packet | First pass | Minutes | Diff lines |
|---|---|---|---|---|
| gemini-3.8-flash-high | formatBytes | yes | 0.6 | 18 |
| gemini-4-hydrogen-high | formatBytes | yes | 0.4 | 24 |
| gemini-3.8-flash-high | parseDuration | yes | 1.8 | 18 |
| gemini-4-hydrogen-high | parseDuration | yes | 0.4 | 23 |
| gemini-4-hydrogen-medium | parseDuration | yes | 0.6 | 35 |
| gemini-3.8-flash-high | invoice refactor | yes | 3.4 | 34 |
| gemini-4-hydrogen-high | invoice refactor | yes | 0.9 | 42 |

No run was denied a permission and no worker edited a file outside its allowed list. Quota moved by 0 points in every single run (1% resolution). Over the six runs after the first, only one row moved: Gemini five-hour 99% -> 98%; Gemini weekly, Claude/GPT and Argon rows did not change.

## Review notes
- `invoice`: Flash rounded the discounted subtotal to cents before adding tax (an intermediate rounding the spec did not ask for; the tests do not catch it). Hydrogen rounded once, at the end, with an explicit half-up rule, which follows the spec more closely.
- Hydrogen wrote 24-33% more lines than Flash on every packet (formatBytes +33%, parseDuration +28%, invoice +24%); `hydrogen-medium` wrote the most on `parseDuration`.

## Decisions
- Mechanical default: `gemini-3.8-flash-high`. Hydrogen did not pass where Flash failed, and was only slightly faster on the mechanical packet.
- Substantive-coding default: `gemini-4-hydrogen-high`. Same first-pass result, about 4x faster on the logic and refactor packets (4.5x and 3.8x, single runs; 1.5x on the mechanical one), closer to the spec on the refactor. Use `hydrogen-medium` only for modest tasks.
- Hydrogen's quota pool: unknown. No single run moved any row; across the six runs after the first, one point left the Gemini five-hour row, but two of those runs were Flash, so it cannot be pinned on Hydrogen. Check every `/usage` row after Hydrogen runs. Per-run cost cannot be told apart from Flash at 1% resolution.

## Limits
One run per cell, tiny packets, success judged by tests plus a read of the refactor. It does not test the owner's claim that Hydrogen matches Sonnet 5.5 at coding, and it says nothing about large or ambiguous tasks. Re-run on a bigger packet before trusting these numbers for big work; the ledger (`scripts/ledger.ps1`) accumulates real evidence from then on.
