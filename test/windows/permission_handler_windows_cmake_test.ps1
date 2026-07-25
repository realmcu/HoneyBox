$ErrorActionPreference = 'Stop'

$workspaceRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$cmakePath = Join-Path $workspaceRoot 'windows\CMakeLists.txt'
$projectPath = Join-Path $workspaceRoot 'build\windows\x64\plugins\permission_handler_windows\permission_handler_windows_plugin.vcxproj'

$cmake = Get-Content -Raw -LiteralPath $cmakePath
if ($cmake -notmatch 'list\(REMOVE_ITEM PHW_COMPILE_OPTIONS "/await"\)') {
    throw 'The project CMake config does not remove permission_handler_windows legacy /await.'
}

if (Test-Path -LiteralPath $projectPath) {
    $project = Get-Content -Raw -LiteralPath $projectPath
    if ($project -match '(?<!:)/await(?!:)') {
        throw 'permission_handler_windows still enables the deprecated /await compiler option.'
    }
    if ($project -notmatch '<LanguageStandard>stdcpp20</LanguageStandard>') {
        throw 'permission_handler_windows must continue compiling as C++20.'
    }
}

Write-Output 'permission_handler_windows CMake regression test passed.'
