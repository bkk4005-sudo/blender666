$ErrorActionPreference = 'Stop'
$blenderExe = & (Join-Path $PSScriptRoot 'Get-BlenderExecutable.ps1')
$scenePath = Join-Path $PSScriptRoot 'AshenColiseum.blend'
Start-Process -FilePath $blenderExe -ArgumentList @('"' + $scenePath + '"') -WindowStyle Normal
