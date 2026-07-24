param(
    [Parameter(Mandatory = $true)]
    [string]$SourcePath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

$source = Get-Content -Raw -LiteralPath $SourcePath
$startScanOriginal = 'if (method == "startScan") { scan_results_cache_.clear(); watcher_.Start(); result->Success(flutter::EncodableValue(true)); return; }'
$stopScanOriginal = 'if (method == "stopScan") { watcher_.Stop(); result->Success(flutter::EncodableValue(true)); return; }'

$startScanReplacement = @'
if (method == "startScan") {
        scan_results_cache_.clear();
        try {
            watcher_.Start();
            result->Success(flutter::EncodableValue(true));
        } catch (const winrt::hresult_error& error) {
            const auto message = winrt::to_string(error.message());
            Log("startScan failed (HRESULT 0x%08X): %s", static_cast<unsigned int>(error.code().value), message.c_str());
            result->Error("start_scan_failed", message, flutter::EncodableValue(error.code().value));
        } catch (const std::exception& error) {
            Log("startScan failed: %s", error.what());
            result->Error("start_scan_failed", error.what());
        } catch (...) {
            Log("startScan failed with an unknown native exception");
            result->Error("start_scan_failed", "Unknown native Bluetooth scan error");
        }
        return;
    }
'@

$stopScanReplacement = @'
if (method == "stopScan") {
        try {
            watcher_.Stop();
            result->Success(flutter::EncodableValue(true));
        } catch (const winrt::hresult_error& error) {
            const auto message = winrt::to_string(error.message());
            Log("stopScan failed (HRESULT 0x%08X): %s", static_cast<unsigned int>(error.code().value), message.c_str());
            result->Error("stop_scan_failed", message, flutter::EncodableValue(error.code().value));
        } catch (const std::exception& error) {
            Log("stopScan failed: %s", error.what());
            result->Error("stop_scan_failed", error.what());
        } catch (...) {
            Log("stopScan failed with an unknown native exception");
            result->Error("stop_scan_failed", "Unknown native Bluetooth scan error");
        }
        return;
    }
'@

if (-not $source.Contains($startScanOriginal)) {
    throw 'Unsupported flutter_blue_plus_winrt source: startScan handler was not found.'
}
if (-not $source.Contains($stopScanOriginal)) {
    throw 'Unsupported flutter_blue_plus_winrt source: stopScan handler was not found.'
}

$patchedSource = $source.Replace($startScanOriginal, $startScanReplacement.TrimEnd())
$patchedSource = $patchedSource.Replace($stopScanOriginal, $stopScanReplacement.TrimEnd())
$outputDirectory = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
[System.IO.File]::WriteAllText($OutputPath, $patchedSource, [System.Text.UTF8Encoding]::new($false))
