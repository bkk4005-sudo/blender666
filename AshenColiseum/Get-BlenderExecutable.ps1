$ErrorActionPreference = 'Stop'

if ($env:BLENDER_EXECUTABLE) {
    if (-not (Test-Path -LiteralPath $env:BLENDER_EXECUTABLE -PathType Leaf)) {
        throw "BLENDER_EXECUTABLE does not point to a file: $env:BLENDER_EXECUTABLE"
    }
    return (Resolve-Path -LiteralPath $env:BLENDER_EXECUTABLE).Path
}

$command = Get-Command blender.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if ($command) { return $command.Source }

$roots = @(
    (Join-Path $env:ProgramFiles 'Blender Foundation')
    (Join-Path ${env:ProgramFiles(x86)} 'Blender Foundation')
    (Join-Path $env:LOCALAPPDATA 'Programs\Blender Foundation')
    (Join-Path $env:LOCALAPPDATA 'Blender Foundation')
)

$executables = foreach ($root in $roots) {
    if (Test-Path -LiteralPath $root -PathType Container) {
        Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
            ForEach-Object { Join-Path $_.FullName 'blender.exe' } |
            Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }
    }
}

$found = $executables | Sort-Object -Descending | Select-Object -First 1
if ($found) { return $found }

throw 'Blender not found. Install Blender 5.2 LTS or set BLENDER_EXECUTABLE to the full path of blender.exe.'
