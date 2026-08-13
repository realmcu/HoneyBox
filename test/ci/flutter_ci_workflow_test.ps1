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
Assert-Contains '(?ms)^\s+workflow_dispatch:\s*\r?\n\s+inputs:\s*\r?\n\s+release_tag:' `
    'Manual runs must accept a release_tag for repairing an existing release.'
Assert-Contains "startsWith\(github\.ref, 'refs/tags/v'\)" 'Releases must be limited to v* tags.'
Assert-Contains 'github\.event\.inputs\.release_tag' `
    'Release jobs must support the manual release_tag input.'
Assert-Contains 'flutter build apk --release' 'Tag builds must produce a release APK.'
Assert-Contains 'tag_name:\s*\$\{\{ env\.RELEASE_TAG \}\}' `
    'The requested release tag must be used as the GitHub release tag.'
Assert-Contains 'prerelease:\s*false' 'Version tags must create normal releases.'
# APK 不再经 CI 上传到 Gitee（实测公网上行仅 12-14 KB/s，132 MB 传不稳），
# 改为手动上传；CI 只把代码与 tag 推到 Gitee 镜像。
Assert-Contains 'Push tag and code to Gitee' `
    'CI must still push code and tags to the Gitee mirror.'
Assert-NotContains 'Publish Gitee Release' `
    'CI must not upload the APK to Gitee (uploaded by hand instead).'
Assert-NotContains 'attach_files' `
    'CI must not attempt the slow Gitee APK asset upload.'
Assert-Contains 'refs/remotes/origin/master:refs/heads/master' `
    'Repair runs must keep Gitee master aligned with GitHub master.'
Assert-NotContains 'HEAD:refs/heads/master' `
    'Repair runs must not move Gitee master back to the release tag.'
Assert-NotContains 'Generate version tag' 'CI must not generate timestamp tags.'
Assert-NotContains 'date -u' 'CI must not derive release versions from timestamps.'
Assert-NotContains "github\.ref_name == 'master'" 'Master pushes must not publish releases.'

Write-Host 'flutter-ci workflow policy checks passed.'
