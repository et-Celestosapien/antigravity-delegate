# Tests for scripts/ledger.ps1. Run:
#   powershell -NoProfile -ExecutionPolicy Bypass -File skills/antigravity-delegate/tests/ledger.tests.ps1
# Prints ALL PASSED, or the names of the failing tests (exit code 1).
$ErrorActionPreference = 'Stop'
$ledgerScript = Join-Path $PSScriptRoot '..\scripts\ledger.ps1'
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('ledger-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $tmp | Out-Null
$failed = @()

function Assert-That($condition, $name) { if (-not $condition) { $script:failed += $name } }

function Invoke-Add {
  param($LedgerPath, $Model, [switch]$FirstPass, $Fix = 0, $Min = 1, $Q5 = 0, $Verdict = 'DELEGATE', $Note = '')
  $ErrorActionPreference = 'Continue'  # stderr from the child must not abort the test run
  $a = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $ledgerScript, '-Add', '-Project', 'proj', '-Task', 't1',
    '-Verdict', $Verdict, '-Score', '3', '-Model', $Model, '-Tier', '0', '-Files', '1', '-Lines', '10',
    '-FixRounds', "$Fix", '-Minutes', "$Min", '-Quota5h', "$Q5", '-QuotaWeek', '0', '-Ledger', $LedgerPath)
  if ($FirstPass) { $a += '-FirstPass' }
  if ($Note) { $a += @('-Note', $Note) }
  & powershell @a 2>&1 | Out-Null
}

function Get-Summary($LedgerPath) {
  $ErrorActionPreference = 'Continue'
  (& powershell -NoProfile -ExecutionPolicy Bypass -File $ledgerScript -Summary -Ledger $LedgerPath 2>&1 | Out-String)
}

# add_creates_folder_and_file
$l1 = Join-Path $tmp 'sub\dir\l.jsonl'
Invoke-Add $l1 'm1' -FirstPass
$ok = Test-Path $l1
Assert-That $ok 'add_creates_folder_and_file (file missing)'
if ($ok) {
  $row = (Get-Content $l1 | Select-Object -First 1) | ConvertFrom-Json
  Assert-That ($row.model -eq 'm1' -and $row.firstPass -eq $true -and $row.tier -eq 0) 'add_creates_folder_and_file (row content)'
}

# summary_two_models
$l2 = Join-Path $tmp 'two.jsonl'
Invoke-Add $l2 'flash' -FirstPass -Fix 0 -Min 3 -Q5 1
Invoke-Add $l2 'flash' -Fix 2 -Min 5 -Q5 3
Invoke-Add $l2 'hydrogen' -FirstPass -Fix 0 -Min 2 -Q5 5
$sum = Get-Summary $l2
Assert-That ($sum -match 'flash tasks=2 firstpass=50% fix=1 min=4 q5h=2') 'summary_two_models (flash line)'
Assert-That ($sum -match 'hydrogen tasks=1 firstpass=100%') 'summary_two_models (hydrogen line)'

# summary_empty_says_no_entries
$sumEmpty = Get-Summary (Join-Path $tmp 'does-not-exist.jsonl')
Assert-That ($sumEmpty -match 'No ledger entries\.') 'summary_empty_says_no_entries'

# corrupted_line_skipped
Add-Content $l2 'not json'
$sumBad = Get-Summary $l2
Assert-That ($sumBad -match 'flash tasks=2' -and $sumBad -match 'skipped 1') 'corrupted_line_skipped'

# parallel_appends
$l3 = Join-Path $tmp 'par.jsonl'
$jobs = 1..5 | ForEach-Object {
  Start-Job -ScriptBlock {
    param($scriptPath, $ledgerPath, $n)
    & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath -Add -Project p -Task "t$n" -Verdict DELEGATE -Score 3 -Model par -Tier 0 -Files 1 -Lines 1 -FixRounds 0 -Minutes 1 -Quota5h 0 -QuotaWeek 0 -Ledger $ledgerPath
  } -ArgumentList $ledgerScript, $l3, $_
}
$jobs | Wait-Job | Out-Null
$jobs | Remove-Job
$parsed = @(Get-Content $l3 -ErrorAction SilentlyContinue | ForEach-Object { try { $_ | ConvertFrom-Json } catch { $null } } | Where-Object { $_ })
Assert-That ($parsed.Count -eq 5) "parallel_appends (expected 5 parseable lines, got $($parsed.Count))"

# bad_verdict_rejected
$l4 = Join-Path $tmp 'bad.jsonl'
Invoke-Add $l4 'm'
Invoke-Add $l4 'm' -Verdict 'MAYBE'
$rowsAfterBad = if (Test-Path $l4) { @(Get-Content $l4).Count } else { 0 }
Assert-That ($rowsAfterBad -eq 1) 'bad_verdict_rejected (expected exactly the 1 valid row)'

# note_truncated_to_200
$l5 = Join-Path $tmp 'note.jsonl'
Invoke-Add $l5 'm' -Note ('x' * 300)
$noteRow = if (Test-Path $l5) { (Get-Content $l5 | Select-Object -First 1) | ConvertFrom-Json } else { $null }
Assert-That ($noteRow -and $noteRow.note.Length -eq 200) 'note_truncated_to_200'

# summary_skips_bad_field_types: a valid-JSON row with a non-numeric, missing or string-boolean field must not abort the summary
$l6 = Join-Path $tmp 'types.jsonl'
Invoke-Add $l6 'good' -FirstPass -Fix 1 -Min 2 -Q5 1
Add-Content $l6 '{"model":"bad","firstPass":true,"fixRounds":"abc","minutes":1,"quota5h":0}'
Add-Content $l6 '{"model":"bad","firstPass":true}'
Add-Content $l6 '{"model":"bad","firstPass":"false","fixRounds":0,"minutes":1,"quota5h":0}'
$sumTypes = Get-Summary $l6
Assert-That ($sumTypes -match 'good tasks=1 firstpass=100%') 'summary_skips_bad_field_types (good row missing from summary)'
Assert-That ($sumTypes -notmatch 'bad tasks') 'summary_skips_bad_field_types (a bad row was counted)'
Assert-That ($sumTypes -match 'skipped 3') 'summary_skips_bad_field_types (expected skipped 3)'

Remove-Item $tmp -Recurse -Force
if ($failed.Count) { "FAILED: " + ($failed -join '; '); exit 1 }
'ALL PASSED'
