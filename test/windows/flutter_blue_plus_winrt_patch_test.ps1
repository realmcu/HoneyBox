$ErrorActionPreference = 'Stop'

$workspaceRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$patchScript = Join-Path $workspaceRoot 'tool\patch_flutter_blue_plus_winrt.ps1'
$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) "fbp-winrt-patch-$([guid]::NewGuid())"
$windowsDirectory = Join-Path $temporaryRoot 'windows'
$pluginSource = Join-Path $windowsDirectory 'flutter_blue_plus_winrt_plugin.cpp'
$patchedSourcePath = Join-Path $temporaryRoot 'generated\flutter_blue_plus_winrt_plugin.cpp'

try {
    New-Item -ItemType Directory -Path $windowsDirectory | Out-Null
    @'
void FlutterBluePlusWinrtPlugin::HandleMethodCall() {
    if (method == "startScan") { scan_results_cache_.clear(); watcher_.Start(); result->Success(flutter::EncodableValue(true)); return; }
    if (method == "stopScan") { watcher_.Stop(); result->Success(flutter::EncodableValue(true)); return; }
}
'@ | Set-Content -LiteralPath $pluginSource -NoNewline

    & $patchScript -SourcePath $pluginSource -OutputPath $patchedSourcePath

    $originalSource = Get-Content -Raw -LiteralPath $pluginSource
    if ($originalSource -match 'catch \(const winrt::hresult_error& error\)') {
        throw 'The original plugin source was modified.'
    }

    $patchedSource = Get-Content -Raw -LiteralPath $patchedSourcePath
    if ($patchedSource -notmatch 'catch \(const winrt::hresult_error& error\)') {
        throw 'WinRT HRESULT errors are not caught.'
    }
    if ($patchedSource -notmatch 'result->Error\("start_scan_failed"') {
        throw 'startScan failures are not returned through the Flutter channel.'
    }
    if ($patchedSource -notmatch 'result->Error\("stop_scan_failed"') {
        throw 'stopScan failures are not returned through the Flutter channel.'
    }

    & $patchScript -SourcePath $pluginSource -OutputPath $patchedSourcePath

    $secondPassSource = Get-Content -Raw -LiteralPath $patchedSourcePath
    if ($secondPassSource -ne $patchedSource) {
        throw 'Patch is not idempotent.'
    }

    Write-Output 'flutter_blue_plus_winrt patch regression test passed.'
}
finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -Recurse -Force -LiteralPath $temporaryRoot
    }
}
