param([string]$GodotPath = 'godot')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot

function Invoke-GodotCheck {
    param([string[]]$GodotArguments)
    # Headless-проверки не зависят от устройства вывода звука Windows.
    $output = & $GodotPath --audio-driver Dummy @GodotArguments 2>&1
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
Invoke-GodotCheck -GodotArguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/territory_grid_test.gd')
Invoke-GodotCheck -GodotArguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/review_regression_test.gd')
Invoke-GodotCheck -GodotArguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/expansion_scenario_test.gd')
Invoke-GodotCheck -GodotArguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/expansion_ui_test.gd')
Invoke-GodotCheck -GodotArguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/fire_scenario_test.gd')
Write-Host 'Все проверки пройдены.'
