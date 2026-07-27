# Watch Health App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Watch health placeholder with a responsive Flutter dashboard backed by a replaceable mock health repository.

**Architecture:** Immutable health models describe snapshots and period trends. A Riverpod `StateNotifier` coordinates synchronization and period selection through a repository interface. The Flutter page renders provider state and uses custom painters for dependency-free charts.

**Tech Stack:** Flutter, Dart, Riverpod, Material 3, flutter_test

---

### Task 1: Health Data State

**Files:**
- Create: `lib/pages/watch/health/watch_health_data.dart`
- Create: `lib/pages/watch/health/watch_health_provider.dart`
- Create: `test/providers/watch_health_provider_test.dart`

- [ ] Write provider tests for initial, syncing, success, failure, and period states.
- [ ] Run the focused test and verify it fails because the health API is absent.
- [ ] Add immutable models, repository boundary, mock repository, and notifier.
- [ ] Run the focused test and verify it passes.

### Task 2: Health Dashboard

**Files:**
- Modify: `lib/pages/watch/pages/watch_health_page.dart`
- Modify: `lib/app.dart`
- Create: `test/pages/watch/watch_health_page_test.dart`

- [ ] Write widget tests for empty state, route device name, synchronization, and period switching.
- [ ] Run the focused test and verify it fails against the placeholder page.
- [ ] Build the responsive dashboard, summary tiles, custom trend chart, sleep stages, and recent records.
- [ ] Pass route arguments into the page and run focused tests.
- [ ] Run formatting, analysis, the full Flutter test suite, and a Windows release build.
