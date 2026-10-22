param([string]$GodotPath = 'godot')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
& $GodotPath --path $projectRoot
exit $LASTEXITCODE
