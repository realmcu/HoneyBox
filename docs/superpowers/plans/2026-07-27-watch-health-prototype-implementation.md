# Watch Health Prototype Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a standalone interactive HTML prototype for syncing and viewing Watch health data.

**Architecture:** A single dependency-free HTML document contains the responsive page shell, semantic health sections, CSS-rendered charts, sample period datasets, and a small JavaScript state machine. Prototype controls change data availability and sync state without claiming a BLE/L2 protocol contract.

**Tech Stack:** HTML5, CSS, vanilla JavaScript, Playwright CLI

---

### Task 1: Build The Health Dashboard

**Files:**
- Create: `docs/prototypes/watch-health-mockup.html`

- [ ] **Step 1: Add the responsive page structure**

Create a phone preview with app bar, sync status, four metric tiles, trend section, sleep distribution, recent records, and a desktop prototype control panel. Use the existing app colors: `#0072bc` primary and `#2e7d6b` Watch accent.

- [ ] **Step 2: Add explicit data states**

Represent `normal`, `empty`, `syncing`, `error`, and `unsupported` states. Missing values use `--`; unsupported values use `不支持`; stale error data keeps the last sync timestamp visible.

- [ ] **Step 3: Add interactions**

Connect the sync button and prototype controls to `setViewState(name)`. Connect the `day`, `week`, and `month` segmented controls to `renderTrend(period)`. A manual sync enters `syncing` and resolves to `normal` after 1.4 seconds.

- [ ] **Step 4: Perform static validation**

Run:

```powershell
rg -n "今日概览|趋势分析|睡眠详情|最近记录|normal|empty|syncing|error|unsupported" docs/prototypes/watch-health-mockup.html
git diff --check -- docs/prototypes/watch-health-mockup.html
```

Expected: all required sections and states are found; `git diff --check` exits with code 0.

### Task 2: Verify In A Real Browser

**Files:**
- Verify: `docs/prototypes/watch-health-mockup.html`
- Create: `output/playwright/watch-health-desktop.png`
- Create: `output/playwright/watch-health-mobile.png`

- [ ] **Step 1: Open the local HTML in Playwright**

Run the Playwright CLI against the absolute `file:///` URL and take a snapshot. Expected: the page title is “Watch 运动 / 健康原型” and controls are discoverable.

- [ ] **Step 2: Verify desktop layout and interactions**

Use a `1280 x 900` viewport, switch trend periods and state controls, and capture the desktop screenshot. Expected: phone preview and control panel are both visible with no overlap.

- [ ] **Step 3: Verify mobile layout**

Use a `390 x 844` viewport and capture the mobile screenshot. Expected: no horizontal overflow, all metric labels fit, and the page scrolls vertically.

- [ ] **Step 4: Commit the prototype**

```powershell
git add docs/superpowers/plans/2026-07-27-watch-health-prototype-implementation.md docs/prototypes/watch-health-mockup.html
git commit -m "docs: add watch health prototype"
```
