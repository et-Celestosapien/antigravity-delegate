<#
Outcome ledger for delegated tasks: one JSON line per task, so later routing decisions use real numbers.
  ledger.ps1 -Add -Project p -Task t1 -Verdict DELEGATE -Score 3 -Model gemini-3.8-flash-high -Tier 0 `
             -Files 2 -Lines 80 [-FirstPass] -FixRounds 1 -Minutes 4.5 -Quota5h 1 -QuotaWeek 0 [-Note text]
  ledger.ps1 -Summary
Default ledger: ~/.agy-delegate/ledger.jsonl (-Ledger overrides). Stores no code and no prompts; -Note is cut to 200 chars.
shortcut: whole-file read for -Summary, fine up to a few thousand rows; switch to streaming if it grows past that.
#>
[CmdletBinding()]
param(
  [Parameter(ParameterSetName = 'Add', Mandatory)][switch]$Add,
  [Parameter(ParameterSetName = 'Summary', Mandatory)][switch]$Summary,
  [Parameter(ParameterSetName = 'Add', Mandatory)][string]$Project,
  [Parameter(ParameterSetName = 'Add', Mandatory)][string]$Task,
  [Parameter(ParameterSetName = 'Add', Mandatory)][ValidateSet('KEEP', 'DELEGATE', 'SPLIT', 'SWARM')][string]$Verdict,
  [Parameter(ParameterSetName = 'Add', Mandatory)][int]$Score,
  [Parameter(ParameterSetName = 'Add', Mandatory)][string]$Model,
  [Parameter(ParameterSetName = 'Add', Mandatory)][ValidateSet(0, 1, 2)][int]$Tier,
  [Parameter(ParameterSetName = 'Add', Mandatory)][int]$Files,
  [Parameter(ParameterSetName = 'Add', Mandatory)][int]$Lines,
  [Parameter(ParameterSetName = 'Add')][switch]$FirstPass,
  [Parameter(ParameterSetName = 'Add', Mandatory)][int]$FixRounds,
  [Parameter(ParameterSetName = 'Add', Mandatory)][double]$Minutes,
  [Parameter(ParameterSetName = 'Add', Mandatory)][double]$Quota5h,
  [Parameter(ParameterSetName = 'Add', Mandatory)][double]$QuotaWeek,
  [Parameter(ParameterSetName = 'Add')][string]$Note = '',
  [string]$Ledger = [IO.Path]::Combine($HOME, '.agy-delegate', 'ledger.jsonl')
)
$ErrorActionPreference = 'Stop'
$path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Ledger)

# Two workers can finish together; AppendAllText holds the file exclusively for writers, so a
# collision throws IOException and we retry instead of interleaving or losing a line.
function Invoke-WithRetry([scriptblock]$Action) {
  for ($try = 0; ; $try++) {
    try { return (& $Action) }
    catch [System.IO.IOException] {
      if ($try -ge 50) { throw }
      Start-Sleep -Milliseconds (20 + (Get-Random -Maximum 80))
    }
  }
}

if ($Add) {
  $dir = Split-Path $path -Parent
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
  $noteShort = if ($Note.Length -gt 200) { $Note.Substring(0, 200) } else { $Note }
  $row = [ordered]@{
    date = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    project = $Project; task = $Task; verdict = $Verdict; score = $Score; model = $Model; tier = $Tier
    files = $Files; lines = $Lines; firstPass = [bool]$FirstPass; fixRounds = $FixRounds
    minutes = $Minutes; quota5h = $Quota5h; quotaWeek = $QuotaWeek; note = $noteShort
  }
  $text = ($row | ConvertTo-Json -Compress) + "`n"
  Invoke-WithRetry { [IO.File]::AppendAllText($path, $text) } | Out-Null
  return
}

if (-not (Test-Path -LiteralPath $path)) { 'No ledger entries.'; return }
$allLines = Invoke-WithRetry { [IO.File]::ReadAllLines($path) }
$rows = @()
$skipped = 0
foreach ($line in $allLines) {
  if (-not $line.Trim()) { continue }
  try { $r = $line | ConvertFrom-Json } catch { $skipped++; continue }
  if ($null -eq $r.model -or $null -eq $r.firstPass) { $skipped++; continue }
  $rows += $r
}
if (-not $rows) { 'No ledger entries.' }
$inv = [Globalization.CultureInfo]::InvariantCulture
foreach ($group in ($rows | Group-Object model | Sort-Object Name)) {
  $n = $group.Count
  $first = @($group.Group | Where-Object { $_.firstPass }).Count
  $avg = { param($prop) [math]::Round((($group.Group | Measure-Object $prop -Average).Average), 1) }
  [string]::Format($inv, '{0} tasks={1} firstpass={2}% fix={3} min={4} q5h={5}',
    $group.Name, $n, [math]::Round(100 * $first / $n), (& $avg 'fixRounds'), (& $avg 'minutes'), (& $avg 'quota5h'))
}
if ($skipped) { "(skipped $skipped unreadable line$(if ($skipped -ne 1) { 's' }))" }
