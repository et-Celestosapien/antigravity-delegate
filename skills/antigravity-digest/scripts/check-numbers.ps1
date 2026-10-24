<#
Compare the numbers in a digest (markdown) with the text layer of the source pages.
  check-numbers.ps1 -Pdf big.pdf -First 890 -Last 891 -Digest out.md
Prints numbers in the digest that are not in the source (INVENTED?) and numbers in the source that are
not in the digest (DROPPED?). Page footers and dates show up as harmless noise.
shortcut: set comparison, so it cannot catch a right number in the wrong place, and the text layer of
flowcharts and scrambled tables is unreliable; those still need a human look at the page.
#>
param(
  [Parameter(Mandatory)][string]$Pdf,
  [Parameter(Mandatory)][int]$First,
  [Parameter(Mandatory)][int]$Last,
  [Parameter(Mandatory)][string]$Digest
)
$ErrorActionPreference = 'Stop'
if (-not (Get-Command pdftotext -ErrorAction SilentlyContinue)) { throw 'pdftotext not found (install Git for Windows or poppler).' }

# Flash writes 10^9 as superscript characters; the text layer flattens them to plain digits.
$flat = @{}
0..9 | ForEach-Object { $flat[[char](0x2080 + $_)] = "$_" }
4..9 | ForEach-Object { $flat[[char](0x2070 + $_)] = "$_" }
$flat[[char]0x2070] = '0'; $flat[[char]0xB9] = '1'; $flat[[char]0xB2] = '2'; $flat[[char]0xB3] = '3'

function Get-Numbers([string]$text) {
  foreach ($k in $flat.Keys) { $text = $text.Replace([string]$k, $flat[$k]) }
  [regex]::Matches($text, '\d+(?:[.,]\d+)*') | ForEach-Object { $_.Value.TrimEnd('.', ',') -replace ',(\d{3})', '$1' } | Sort-Object -Unique
}

$tmp = [IO.Path]::GetTempFileName()
try {
  pdftotext -layout -f $First -l $Last $Pdf $tmp
  $source = Get-Numbers ([IO.File]::ReadAllText($tmp))
} finally {
  Remove-Item $tmp -ErrorAction SilentlyContinue
}
if (-not $source) { throw "No numbers in the text layer of pages $First-$Last (scanned PDF?)." }
$mine = Get-Numbers ([IO.File]::ReadAllText((Resolve-Path $Digest)))  # not $digest: same name as the parameter

$invented = @($mine | Where-Object { $source -notcontains $_ })
$dropped = @($source | Where-Object { $mine -notcontains $_ })
"source numbers: $(@($source).Count)   digest numbers: $(@($mine).Count)"
"INVENTED? (in digest, not in source): " + $(if ($invented) { $invented -join ' ' } else { 'none' })
"DROPPED?  (in source, not in digest): " + $(if ($dropped) { $dropped -join ' ' } else { 'none' })
