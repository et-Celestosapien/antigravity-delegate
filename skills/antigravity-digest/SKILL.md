---
name: antigravity-digest
description: Delegate token-heavy reading of PDFs and documents (guidelines, drug manuals, papers, reports) to the Antigravity CLI (agy) running Gemini Flash, get verbatim structured digests with page citations, verify the numbers against the PDF text layer, then let Claude write the deliverable (slides, summary, report). Has a clinical-guideline mode for oncology-style material (doses, regimens, staging, flowcharts). Use when the user gives a folder of source material to summarise or research for a presentation, or says digest / read these for me / use Gemini for the reading.
---

# antigravity-digest: Gemini reads, Claude verifies and writes

Sibling of `antigravity-delegate` (code). Use that skill's **Step 0** (version, `/usage` quota table, model choice) and **Step 4** (closing quota report) unchanged; this skill only covers reading. Verified on agy 1.4.6, Windows + PowerShell, 2026-10-24.

## What was verified (and what was not)
- `agy` reads a PDF with its `read_file` tool as **page images plus a text layer**. It reproduced an AJCC table whose text layer is scrambled, and a multi-row dose table, exactly. Moderate files go in whole (141 pages / 1.5 MB and 504 pages / 9.8 MB worked).
- A **1,022-page / 90 MB** file overflowed the context; the worker then tried a shell command (denied) and produced nothing. `read_file` has **no page-range option** (only line/byte offsets, about 800 lines / 46 KB per call). So big files must be cut first.
- Handing the worker an extracted **text** slice is not safe for doses: the text layer lost the micro sign (`27 mol/L` for µmol/L), a `≥`, and the column order of a cycles-per-setting table. A **PDF slice** of the same two pages fixed all three.
- `agy` has a built-in web **search** (no raw fetch), but the URLs it returned were wrong or dead in 2 of 3 cases. Claude does all document finding and fetching.
- Not verified: scanned PDFs (no text layer), docx/pptx/xlsx/image inputs, the exact size limit between 504 and 1,022 pages, flowcharts checked by eye (Claude cannot render pages), and quota cost of large image reads (measured 1-5% of the five-hour Gemini limit per run on small tests; re-measure).

## When to delegate, when not
Delegate when sources total more than a few dozen pages, or the user wants digests of many documents. Read directly (do not delegate) when the material is a handful of short pages: the packet costs more than reading. Never delegate the synthesis, the narrative, what to leave out, or final wording.
Confidentiality: everything the worker reads goes to Google. Ask before sending a folder that may hold personal or patient information; never include patient identifiers.

## Step 1: brief
Write down: topic, audience, deliverable, and the section list (for clinical decks: risk factors, histologies, staging, work-up, general management, systemic therapy, radiotherapy). Inventory the folder (file, pages, MB). Work from a working folder such as `<project>\digest\<topic>\`, with one subfolder per packet so parallel packets (max 3) never share files.

## Step 2: locate (Claude, free)
Search the text layer instead of making Flash search:
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File <this skill's dir>\scripts\find-pages.ps1 -Pdf "<file.pdf>" -Pattern "gemcitabine" -All "cisplatin,bladder"
```
It prints matching page numbers with a preview. If it reports no text layer, the file is scanned: send it whole if small, otherwise tell the user.

## Step 3: slice (Claude)
- File up to about 500 pages and 10 MB: send whole, name the section to find.
- Bigger: cut the page range into a small PDF inside the packet folder, one topic per slice, 1-20 pages:
```powershell
qpdf "<file.pdf>" --pages . 890-891 -- "<packet>\slice.pdf"
```
`qpdf` is installed with `winget install --id QPDF.QPDF -e` (ask the user first; it may not be on PATH in an open shell, check `C:\Program Files\qpdf*\bin`). Never send a text extract of a dose or table page in place of the PDF.

## Step 4: launch
From the packet folder (writes are allowed only there). Files outside it need `--add-dir <folder>` on that launch; the slice inside the packet folder does not. Always pass `--model` (see `antigravity-delegate`), no `--effort` with a `-high` id, call `agy` directly with `2>&1`, `--log-file`, run in the background, up to 3 at once.
```powershell
agy -p $prompt --mode accept-edits --add-dir "<source folder>" --model gemini-3.8-flash-high --print-timeout 20m --log-file "<packet>\agy.log" 2>&1
```
Prompt template (fill the brackets):
```
Open <slice.pdf or full path>. Read the page images, not just the text layer. Do not run any shell command.
Write digest.md in the current folder and say DONE.
Task: <what to extract, with the section list>.
Rules: copy every number, unit, range, symbol (< > ≥ ≤, micro sign) and table row exactly as printed; never shorten with "..."; give the PDF page for every item; write UNREADABLE or AMBIGUOUS instead of guessing; no outside knowledge; do not merge or reconcile sources.
Finish with how you read the file and any limits you hit.
```
A denial prints `no output produced ... permission`; handle it as in `antigravity-delegate` ("Scope requests"). Parallel launches may log harmless "not logged in" noise.

## Step 5: verify (Claude, never skip)
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File <this skill's dir>\scripts\check-numbers.ps1 -Pdf "<file.pdf>" -First 890 -Last 891 -Digest "<packet>\digest.md"
```
`INVENTED?` numbers are errors until explained; `DROPPED?` numbers mean a row or bullet was left out (this catches silent truncation). Page footers, dates and "raw line" references are harmless noise. The check is set-based: it cannot catch a right number in the wrong row, and it is weak on flowcharts and scrambled tables. For those, and for every dose, regimen and stage that goes on a slide, ask the user to check the one source page by eye, and spot-check 3 other claims yourself. Re-run a failed packet once with the specific mismatch named, then take over.

## Step 6: write the deliverable
Read only the verified digests, not the PDFs. Tag every slide fact with its source file and page, put guideline name, version and date in the footer, and mark clinical content "draft: verify against source before use". Close with the `antigravity-delegate` Step 4 quota report.

## Clinical-guideline mode
Use for NCCN/ASCO/ESMO/ASTRO/ESTRO/NRG material, drug monographs and chemotherapy protocols.
- **Schema, one row per recommendation or regimen:** guideline, version/date, section, page, recommendation text verbatim, NCCN category or evidence level, setting, drug / dose / route / days / cycle length / number of cycles, dose modifications (haematological, renal, hepatic) with thresholds, monitoring, source page.
- **Doses are copied, never summarised or converted.** Units and ranges stay as printed. Staging rows record the edition (e.g. AJCC 8th).
- **Conflicts:** when sources disagree (NCCN vs BC Cancer vs Royal Surrey, ASTRO vs ESTRO vs NRG), list them side by side with source and year. Never pick one or average.
- **Flowcharts:** one page per packet; list every box with every bullet, and each arrow as `box -> box`. A box shortened with "..." is a failure (it happened); `check-numbers` plus the user's glance catch it.
- **Radiotherapy:** capture dose, fractions, target volumes, margins and OAR constraints as separate fields.
- The first two guideline pages of a document give its name and version; record them once per source.

## Finding and fetching documents (Claude, not agy)
Use Claude's own search, PubMed and fetch tools. Downloading any file needs the user's yes in chat with file name, source and size. NCCN PDFs need the user's own login; Claude cannot sign in. ASTRO, ESMO, ASCO, NRG/RTOG contouring atlases and open-access ESTRO papers are usually fetchable; paywalled ones need the user's institutional access. Check every URL before giving it to the user.

## Failure cheatsheet
| Symptom | Cause / action |
|---|---|
| Context overflow, then `RunCommand` denied | file too big; slice it (Step 3) |
| Worker says it cannot read only some pages | `read_file` has no page range; slice |
| `read_file` permission denied | file outside the packet folder; add `--add-dir` for that launch |
| Symbol or unit missing in the digest | worker read a text extract; send the PDF slice |
| Box text ends in "..." | truncation; rerun naming that box, one page per packet |
| `find-pages` says no text layer | scanned PDF; whole file if small, else ask the user |
