param([ValidatePattern('^[A-Za-z0-9_]+$')][string]$Clip = 'Showcase')
$ErrorActionPreference = 'Stop'
$blenderExe = & (Join-Path $PSScriptRoot '..\..\Get-BlenderExecutable.ps1')
$scene = Join-Path $PSScriptRoot 'AshenOath_R15.blend'
$selector = Join-Path $PSScriptRoot 'select_clip.py'
$names = (Get-Content (Join-Path $PSScriptRoot 'animation_manifest.json') -Raw | ConvertFrom-Json).name
if ($Clip -ne 'Showcase' -and $Clip -notin $names) { throw ('Unknown clip. Available: ' + ($names -join ', ')) }
Start-Process -FilePath $blenderExe -ArgumentList @('"' + $scene + '"', '--python', '"' + $selector + '"', '--', $Clip) -WindowStyle Normal
