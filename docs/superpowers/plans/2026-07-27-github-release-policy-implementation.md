# GitHub Release Policy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publish GitHub Releases only for explicit `v*` tags while retaining CI artifacts for ordinary pushes.

**Architecture:** Keep the existing workflow jobs and place the release boundary at the event and job-condition level. Branch and manual builds remain disposable Actions artifacts; tag builds use the pushed version tag and a release APK.

**Tech Stack:** GitHub Actions YAML, Flutter CLI, PowerShell policy test

---

### Task 1: Lock The Release Policy

**Files:**
- Create: `test/ci/flutter_ci_workflow_test.ps1`

- [ ] Assert that `v*` tags and manual runs are recognized.
- [ ] Assert that releases use the pushed tag and never generate timestamp tags.
- [ ] Run the test and confirm it fails against the old workflow.

### Task 2: Update The Workflow

**Files:**
- Modify: `.github/workflows/flutter-ci.yml`

- [ ] Add `v*` tag and manual triggers.
- [ ] Keep branch builds as seven-day artifacts.
- [ ] Build Android release APKs only for version tags.
- [ ] Limit the release job to pushed `v*` tags and use `github.ref_name`.
- [ ] Parse the YAML, run the policy test, and check the Git diff.
