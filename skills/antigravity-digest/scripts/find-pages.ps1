<#
List the PDF pages whose text layer matches a regex, with a one-line preview. Needs pdftotext
(ships with Git for Windows; elsewhere install poppler).
  find-pages.ps1 -Pdf big.pdf -Pattern 'gemcitabine' -All 'cisplatin','bladder'
-All: more regexes that must also match on the same page. Case-insensitive.
#>
param(
  [Parameter(Mandatory)][string]$Pdf,
  [Parameter(Mandatory)][string]$Pattern,
  [string[]]$All = @(),
  [int]$Max = 40
)
$ErrorActionPreference = 'Stop'
$All = @($All | ForEach-Object { $_ -split ',' })  # powershell -File passes 'a','b' as one string "a,b"
if (-not (Get-Command pdftotext -ErrorAction SilentlyContinue)) { throw 'pdftotext not found (install Git for Windows or poppler).' }

$tmp = [IO.Path]::GetTempFileName()
try {
  pdftotext -layout $Pdf $tmp
  $pages = [IO.File]::ReadAllText($tmp) -split "`f"
} finally {
  Remove-Item $tmp -ErrorAction SilentlyContinue
}
$total = $pages.Count - 1  # pdftotext ends every page with a form feed
if (-not ($pages | Where-Object { $_.Trim().Length -gt 50 })) { throw 'No text layer (scanned PDF?). Send the file whole or OCR it first.' }

$shown = 0
for ($i = 0; $i -lt $total; $i++) {
  $p = $pages[$i]
  if ($p -notmatch $Pattern) { continue }
  if ($All | Where-Object { $p -notmatch $_ }) { continue }
  $first = ($p -split "`n" | ForEach-Object { ($_ -replace '\s{2,}', ' ').Trim() } | Where-Object { $_ } | Select-Object -First 2) -join ' // '
  '{0,5}: {1}' -f ($i + 1), $first.Substring(0, [Math]::Min(150, $first.Length))
  if (++$shown -ge $Max) { "(stopped after $Max matches)"; break }
}
"$total pages searched, $shown shown"
