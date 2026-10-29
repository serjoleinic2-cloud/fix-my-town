param([string]$GodotPath = 'godot')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$script:FailedGodotChecks = [System.Collections.Generic.List[string]]::new()

function Invoke-GodotCheck {
    param([string[]]$GodotArguments)
    Write-Host "Проверка: $($GodotArguments -join ' ')"
    $elapsed = [System.Diagnostics.Stopwatch]::StartNew()
    # Headless-проверки не зависят от устройства вывода звука Windows.
    $output = & $GodotPath --audio-driver Dummy @GodotArguments 2>&1
    $result = $LASTEXITCODE
    $output | ForEach-Object { Write-Host $_ }
    Write-Host ("Время: {0:N1} с" -f $elapsed.Elapsed.TotalSeconds)
    if ($result -ne 0 -or ($output -match 'SCRIPT ERROR:|ERROR:|WARNING:')) {
        $script:FailedGodotChecks.Add(($GodotArguments -join ' '))
        Write-Host "Проверка отмечена как неуспешная (код $result); запускаю следующий набор."
    }
}

Invoke-GodotCheck -GodotArguments @('--headless', '--path', $projectRoot, '--editor', '--import', '--quit')
Invoke-GodotCheck -GodotArguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/scenario_test.gd')
Invoke-GodotCheck -GodotArguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/asset_audio_test.gd')
Invoke-GodotCheck -GodotArguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/responsive_ui_test.gd')
Invoke-GodotCheck -GodotArguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/traffic_test.gd')
Invoke-GodotCheck -GodotArguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/transit_quality_test.gd')
Invoke-GodotCheck -GodotArguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/transit_stop_ui_test.gd')
Invoke-GodotCheck -GodotArguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/map_interaction_test.gd')
Invoke-GodotCheck -GodotArguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/building_levels_test.gd')
Invoke-GodotCheck -GodotArguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/completion_test.gd')
Invoke-GodotCheck -GodotArguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/territory_grid_test.gd')
Invoke-GodotCheck -GodotArguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/review_regression_test.gd')
Invoke-GodotCheck -GodotArguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/expansion_scenario_test.gd')
Invoke-GodotCheck -GodotArguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/expansion_ui_test.gd')
Invoke-GodotCheck -GodotArguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/fire_scenario_test.gd')
Invoke-GodotCheck -GodotArguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/construction_work_test.gd')
Invoke-GodotCheck -GodotArguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/citizen_pool_test.gd')
Invoke-GodotCheck -GodotArguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/empty_city_subsidy_test.gd')
Invoke-GodotCheck -GodotArguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/rewarded_placeholder_test.gd')
Invoke-GodotCheck -GodotArguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/city_hall_scenario_test.gd')
Invoke-GodotCheck -GodotArguments @('--headless', '--path', $projectRoot, '--script', 'res://tests/logistics_network_test.gd')
if ($script:FailedGodotChecks.Count -gt 0) {
    throw "Провалены проверки: $($script:FailedGodotChecks -join ' | ')"
}
Write-Host 'Все проверки пройдены.'
