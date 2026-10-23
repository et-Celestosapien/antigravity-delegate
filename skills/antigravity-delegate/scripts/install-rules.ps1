<#
Merge the allow-rule groups from ../rules/allowlist.json into the agy config.
Dry run by default. -Apply writes (backup first). Run it yourself in a terminal to get a y/N prompt instead.
  -List                 show groups and rule counts
  -Groups a,b           only these groups (default: every group except opt-in ones, e.g. "install")
  -Config <path>        default ~/.gemini/config/config.json
#>
param(
  [string[]]$Groups,
  [switch]$Apply,
  [switch]$List,
  [string]$Config = [IO.Path]::Combine($HOME, '.gemini', 'config', 'config.json')
)
$ErrorActionPreference = 'Stop'

$rules = Get-Content ([IO.Path]::Combine($PSScriptRoot, '..', 'rules', 'allowlist.json')) -Raw | ConvertFrom-Json
$names = @($rules.PSObject.Properties.Name | Where-Object { $_ -notlike '_*' })
$optin = @($rules._optin)

if ($List) {
  foreach ($n in $names) { '{0,-20} {1,3} rules{2}' -f $n, @($rules.$n).Count, $(if ($optin -contains $n) { '  (opt-in)' }) }
  return
}
if (-not $Groups) { $Groups = $names | Where-Object { $optin -notcontains $_ } }
$bad = @($Groups | Where-Object { $names -notcontains $_ })
if ($bad) { throw "Unknown group(s): $($bad -join ', '). Use -List." }
if (-not (Test-Path $Config)) { throw "No agy config at $Config. Run 'agy' once to sign in first." }

$cfg = Get-Content $Config -Raw | ConvertFrom-Json
if (-not $cfg.userSettings) { $cfg | Add-Member -NotePropertyName userSettings -NotePropertyValue ([pscustomobject]@{}) }
if (-not $cfg.userSettings.globalPermissionGrants) { $cfg.userSettings | Add-Member -NotePropertyName globalPermissionGrants -NotePropertyValue ([pscustomobject]@{}) }
$grants = $cfg.userSettings.globalPermissionGrants
if ($null -eq $grants.allow) { $grants | Add-Member -NotePropertyName allow -NotePropertyValue @() }
$have = @($grants.allow)

$new = @()
foreach ($n in $Groups) {
  $add = @($rules.$n | Where-Object { ($have -notcontains $_) -and ($new -notcontains $_) })
  '{0,-20} +{1} new of {2}' -f $n, $add.Count, @($rules.$n).Count
  $new += $add
}
"Config: $Config ($($have.Count) existing rules, $($new.Count) to add)"
if (-not $new) { 'Nothing to add.'; return }

if (-not $Apply) {
  if ([Console]::IsInputRedirected) { 'Dry run only. Re-run with -Apply to write (a backup is made first).'; return }
  if ((Read-Host 'Add these rules? [y/N]') -notmatch '^[yY]') { 'Nothing changed.'; return }
}

$bak = "$Config.bak-$(Get-Date -Format yyyyMMddHHmmss)"
Copy-Item $Config $bak
$grants.allow = @($have + $new)
[IO.File]::WriteAllText($Config, (ConvertTo-Json -InputObject $cfg -Depth 20), (New-Object Text.UTF8Encoding $false))

$after = @((Get-Content $Config -Raw | ConvertFrom-Json).userSettings.globalPermissionGrants.allow)
if ($after.Count -ne $have.Count + $new.Count) {
  Copy-Item $bak $Config -Force
  throw 'Verification failed; config restored from backup.'
}
"Added $($new.Count) rules. Backup: $bak"
