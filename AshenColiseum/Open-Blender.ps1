$ErrorActionPreference = 'Stop'
$blenderExe = Join-Path $env:LOCALAPPDATA 'EclipseSanctum\Blender\blender-5.2.2-windows-x64\blender.exe'
if (-not (Test-Path -LiteralPath $blenderExe)) { throw 'Blender executable not found.' }
$scenePath = Join-Path $PSScriptRoot 'AshenColiseum.blend'
Start-Process -FilePath $blenderExe -ArgumentList @('"' + $scenePath + '"') -WindowStyle Normal
