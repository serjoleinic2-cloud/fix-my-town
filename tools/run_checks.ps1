param([string]$GodotPath = 'godot')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot

function Invoke-GodotCheck {
    param([string[]]$GodotArguments)
    $output = & $GodotPath @GodotArguments 2>&1
    $result = $LASTEXITCODE
    $output | ForEach-Object { Write-Host $_ }
    if ($result -ne 0 -or ($output -match 'SCRIPT ERROR:|ERROR:|WARNING:')) {
        throw "Проверка Godot завершилась с ошибкой или предупреждением (код $result)."
    }
}

Invoke-GodotCheck -GodotArguments @('--headless', '--path', $projectRoot, '--editor', '--import', '--quit')
Invoke-GodotCheck -GodotArguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/scenario_test.gd')
Invoke-GodotCheck -GodotArguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/asset_audio_test.gd')
Invoke-GodotCheck -GodotArguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/responsive_ui_test.gd')
Invoke-GodotCheck -GodotArguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/traffic_test.gd')
Invoke-GodotCheck -GodotArguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/transit_quality_test.gd')
Invoke-GodotCheck -GodotArguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/building_levels_test.gd')
Invoke-GodotCheck -GodotArguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/completion_test.gd')
Write-Host 'Все проверки пройдены.'
