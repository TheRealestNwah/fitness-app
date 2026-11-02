# 0006. Widgets, Watch and menu bar read a snapshot, not the store

- Status: Accepted
- Date: 2026-11-02 (recorded; the decision predates 1.0)

## Context

Widgets and Live Activities run in a separate process with tight memory and time limits, the Watch app is on another device, and the Mac menu bar needs a glanceable summary. Opening the SwiftData store from each of them is slow and risks conflicting writes.

## Decision

After every change, the app writes today's numbers as JSON to the shared App Group (`WidgetSnapshot`, key `todaySnapshot`) and reloads the widget timelines. The widget extension decodes the same JSON (`StrideWidgets/Snapshot.swift`), and the Watch gets it over WatchConnectivity (`WatchSync`). New fields are optional so older snapshots still decode. Writes from outside the app, like a glass of water from a widget or the Watch, go through small queues (`WidgetWaterQueue`, `WatchSync`) that the app turns into records.

Since #411 the snapshot's calorie budget and protein target come from `DayBudget`, the same as Today.

## Consequences

- Extensions stay small and fast, and never touch the store.
- The snapshot is only as right as the code that builds it. It must use the same inputs as Today, and [ADR 0007](0007-day-nutrition-module.md) makes that structural rather than something to remember.
- Anything new shown on a widget needs a snapshot field, written by the app.
