# GitHub Release Policy Design

## Goal

Keep continuous integration useful on ordinary development commits without
creating a GitHub Release for every push.

## Policy

- Pull requests run formatting, analysis, and tests only.
- Pushes to `master`, `main`, or `develop` run quality checks and produce
  short-lived Android and Windows Actions artifacts.
- Manual workflow runs perform the same checks and builds but never publish a
  Release.
- A pushed `v*` tag, such as `v0.8.6`, runs all checks, builds an Android
  release APK and Windows release package, and publishes one normal GitHub
  Release using that exact tag.
- The workflow never creates timestamp tags.

## Compatibility Note

The in-app updater currently reads Gitee releases. Migrating that endpoint to
GitHub is intentionally separate from this CI policy change because it changes
runtime update behavior and requires dedicated parsing and network tests.

## Verification

`test/ci/flutter_ci_workflow_test.ps1` checks the release boundary, release APK
build, exact tag reuse, and removal of timestamp tag generation. The workflow
is also parsed as YAML and checked with `git diff --check`.
