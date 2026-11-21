# Model data: published benchmarks, cost and effectiveness (2026-11-21)

Desk research only: nothing here was run through `agy`. Sources are Google's launch posts ([Neon](https://blog.google/innovation-and-ai/models-and-research/gemini-models/introducing-gemini-4-neon/), [Neon in Antigravity](https://antigravity.google/blog/gemini-4-neon-in-google-antigravity/), [Hydrogen](https://blog.google/innovation-and-ai/models-and-research/gemini-models/introducing-gemini-4-hydrogen/)) plus third-party write-ups that relay Artificial Analysis (AA), Vals, Arena, Zapier and Cursor results ([kingy.ai](https://kingy.ai/blog/gemini-4-neon/), [explainx.ai](https://explainx.ai/blog/gemini-4-neon-launch-price-benchmarks-vs-carbon-hydrogen-november-2026), [9to5Google](https://9to5google.com/2026/11/18/gemini-4-neon-announcement/), [the-decoder](https://the-decoder.com/googles-gemini-4-hydrogen-outscores-the-bigger-argon-just-four-weeks-after-its-launch/), [nhimg](https://nhimg.org/gemini-4-hydrogen-model-profile), [o-mega](https://o-mega.ai/articles/gemini-4-hydrogen-benchmarks-and-real-cost-for-agents-2026), [workspaceblog](https://www.workspaceblog.in/blog/gemini-4-hydrogen-vs-carbon-vs-argon/)). The benchmark tables on Google's own pages are images and were not readable, so most numbers are second-hand. **I = independent (AA, Vals, Arena, Zapier, Cursor), V = vendor-reported by Google.** Prefer I over V; compare only rows at the same effort level.

## 1. Available in agy (`agy models`, agy 1.5.9, 2026-11-21) and list price
| Model id prefix | Effort ids | Input / output per 1M tokens | Cached in | Context |
|---|---|---|---|---|
| `gemini-4-neon-` (new 2026-11-18) | low, medium, high, xhigh | $3 / $15 | $0.15 | 1M (one source says 512K inside Antigravity) |
| `gemini-4-hydrogen-` | low, medium, high, xhigh | $1.50 / $7.50 | $0.075 | 1M |
| `gemini-4-argon-` | low, medium, high | $2 / $10 until 2026-11-30, then $4 / $20 | $0.10, then $0.20 | 1M |
| `gemini-3.8-flash-` | low, medium, high | $0.75 / $3.75 until 2026-12-31, then $1.50 / $7.50 | not found | not found |
| `gemini-pro-orchestrator-neon` / `-g1-pro` | n/a | Orchestrator presets: Neon plans and Hydrogen executes (the `-g1-pro` one is labelled Argon) | | |

Gemini 4 Carbon (API: $2 / $10 until 2026-11-30, then $4 / $20) is **not** in the `agy models` list: do not route to it. Antigravity subscription quota is not billed per token, so list prices are a proxy for relative cost, not your quota burn; no source states a per-model quota multiplier or pool.

## 2. Effectiveness
| Benchmark (basis) | Neon | Hydrogen | Argon | Reference points |
|---|---|---|---|---|
| AA Intelligence Index, general (I) | 61 xhigh, 60 high, 55 medium, 44 low | 54 xhigh, 51 high, 41 medium, 27 low | 50 high | Carbon 60 high; Opus 5.5 59 max; Sonnet 5.5 55 max; Flash 3.8 31 high |
| AA Coding Agent Index (I) | 58.6, #1 | not found | not found | Opus 5.5 in Claude Code 58 |
| CursorBench 4.1 (I) | 65.4 xhigh, 63.7 high, 57.7 medium, 45.5 low | not found | not found | Opus 5.5 58.1; Carbon high 61.5 |
| Vals Index v2.2 (I) | 70.9% | not found | 69.2% | Sonnet 5.5 70.85%; Opus 5.5 70.1%; Carbon 70.4% |
| Terminal-Bench 4.1 (V) | 65.2% | 57.0% | not found | Opus 5.5 65.8%; Sonnet 5.5 63.9%; Flash 3.8 18.2% |
| SWE-sweep (V) | 12.8% (mini-SWE harness), 39.0% (Antigravity harness) | 13.5% (second-hand only) | 4.3% | harnesses differ, rows are not comparable |
| Arena WebDev (I) | 1,764 (rank 7) | 1,703 high | not found | Opus 5.5 1,818; Carbon high 1,769 |
| Zapier AutomationBench (I) | 56.3%, #1 | not comparable (AA variant) | 51.3% | Opus 5.5 42.5% |

## 3. Cost and speed per task (AA, second-hand via kingy.ai and o-mega)
| Model and effort | AA index | $ per task | Minutes per task |
|---|---|---|---|
| Neon xhigh | 61 | 6.44 | 21.5 |
| Neon high | 60 | 3.74 | 14.8 |
| Neon medium | 55 | 1.90 | not found |
| Neon low | 44 | 0.75 | not found |
| Hydrogen xhigh | 54 | 3.16 | 14.8 to 15.3 |
| Hydrogen high | 51 | 1.87 | 8.4 |
| Hydrogen medium | 41 | 0.80 | 3.8 |
| Hydrogen low | 27 | 0.29 | 1.4 |
| Carbon high | 60 | 5.48 (3.88 at promo rates per one source; doubles on 2026-12-01) | 33.8 to 37.1 |
| Gemini 3.8 Flash high | 31 | 7.77 | 14.9 |
| Sonnet 5.5 max | 55 | 10.02 | 33.3 |
| Opus 5.5 max | 59 | 10.04 | 25.2 |

Hydrogen throughput about 169 tokens/s (AA); Google says Hydrogen is 2.5x faster than 3.8 Flash at high.

## 4. What it means for routing (my reading, provisional)
- **Neon-high beats Hydrogen-xhigh at about the same cost and time** (AA 60 vs 54, $3.74 vs $3.16, 14.8 vs 15.3 min), so Neon-high is the first step up from Hydrogen-high, ahead of Hydrogen-xhigh. Neon-xhigh costs about 1.7x Neon-high for 1 AA point; keep it for packets that already failed on Neon-high.
- **Neon-medium matches Hydrogen-high on cost** (AA 55 at $1.90 vs 51 at $1.87). Treat it as a candidate for substantive coding if your Neon quota is not scarcer, but Hydrogen-high has the only measured agy evidence (`benchmarks.md`), so it stays the default until the ledger says otherwise.
- **Argon is dominated on every published number** (AA 50 vs Hydrogen-high 51 and Neon-high 60, at a higher price after 2026-11-30). Its remaining value is that it is a separate weekly pool: use it as a quota escape hatch, not as the quality step-up.
- **Flash 3.8** is a weak model in the data (AA 31, Terminal-Bench 18.2%) and its list price doubles to Hydrogen's on 2027-01-01. Our own B1 runs showed it first-pass on small mechanical packets, and its per-packet quota cost is measured (about 1% of five-hour). Hydrogen-medium ($0.80 per task, AA 41) is the published-data alternative for mechanical work: switch the mechanical default if the ledger shows Flash first-pass under 90% or Hydrogen-medium costs no more quota.
- The Orchestrator claim "about 24% less quota, 19% faster" is Google's figure for **Carbon plans, Hydrogen executes** on Terminal-Bench 4.0. It is not a Neon result and is not measured in agy here. Neon-plans/Hydrogen-executes is described but has no numbers.

## 5. Conflicts and gaps
- Carbon AA index 59 (Google table) vs 60 (AA); Neon "one point above Carbon" is xhigh vs high, they tie at high.
- Google says Neon costs 32% less per task than Carbon; AA data gives about 4% less at November promo prices and about 52% less at December prices; Arena's median cost shows Carbon cheaper ($1.34 vs $2.60). The comparison depends on the price date and the task mix.
- Hydrogen SWE-sweep 13.5% is not in Google's page text; it came from the-decoder and others.
- Opus 5.5 still leads Neon on Terminal-Bench 4.1 (65.8 vs 65.2) and FrontierCode 2.0 (47.3 vs 46.2). Neon's lead over Claude is on the AA and Cursor indexes.
- Not found anywhere: SWE-bench (any variant), LiveCodeBench, Argon coding numbers, and which quota pool Neon or Hydrogen draw from in agy.
- Aggregators disagree on a few details (Argon thinking levels, Antigravity plan tiers); re-read Google's pages before relying on any single figure.

## 6. Refresh without running tests
Re-run `agy models` (free), re-read the three Google posts above, and re-check the dated price changes: Carbon and Argon on 2026-11-30, Flash 3.8 on 2027-01-01. Update this file and the model table in `routing.md` together; the ledger (`scripts/ledger.ps1 -Summary`) overrides these tables once it has 5 or more rows for a model.
