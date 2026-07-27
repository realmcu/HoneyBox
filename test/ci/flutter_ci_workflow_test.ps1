$ErrorActionPreference = 'Stop'

$workflowPath = Join-Path $PSScriptRoot '..\..\.github\workflows\flutter-ci.yml'
$workflow = Get-Content -LiteralPath $workflowPath -Raw

function Assert-Contains([string]$Pattern, [string]$Message) {
    if ($workflow -notmatch $Pattern) {
        throw $Message
    }
}

function Assert-NotContains([string]$Pattern, [string]$Message) {
    if ($workflow -match $Pattern) {
        throw $Message
    }
}

Assert-Contains '(?m)^\s+tags:\s*\[''v\*''\]' 'CI must run for v* tag pushes.'
Assert-Contains '(?m)^\s+workflow_dispatch:\s*$' 'CI must support manual runs.'
Assert-Contains "startsWith\(github\.ref, 'refs/tags/v'\)" 'Releases must be limited to v* tags.'
Assert-Contains 'flutter build apk --release' 'Tag builds must produce a release APK.'
Assert-Contains 'tag_name:\s*\$\{\{ github\.ref_name \}\}' 'The pushed tag must be used as the release tag.'
Assert-Contains 'prerelease:\s*false' 'Version tags must create normal releases.'
Assert-NotContains 'Generate version tag' 'CI must not generate timestamp tags.'
Assert-NotContains 'date -u' 'CI must not derive release versions from timestamps.'
Assert-NotContains "github\.ref_name == 'master'" 'Master pushes must not publish releases.'

Write-Host 'flutter-ci workflow policy checks passed.'
