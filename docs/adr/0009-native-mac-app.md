# 0009. A native macOS app, not Mac Catalyst

- Status: Accepted
- Date: 2026-11-02 (recorded; see [PLATFORMS.md](../PLATFORMS.md))

## Context

Stride runs on iPhone and iPad and should feel at home on a Mac: sidebar, menu commands, keyboard shortcuts, right-click menus, a Settings window and a menu bar summary.

## Decision

The `StrideMac` target is a native SwiftUI and AppKit app for macOS 14 or later that compiles the shared `FitnessApp/` models, services and screens. UIKit and AppKit differences stay in the platform helpers (`Views/Components/PlatformSupport.swift` and friends). Mobile-only services (HealthKit, live workouts, the camera, widgets, the Watch, background refresh) are guarded with `#if os(iOS)`. New shared APIs include `macOS 26` in their availability checks.

## Consequences

- One codebase, with Mac behaviour that follows Mac conventions.
- The Mac has no Apple Health, so anything depending on Health data (like the Health credit in [ADR 0005](0005-activity-credit-is-the-larger-credit.md)) has to work with it absent.
- CI builds and tests the Mac scheme as a required platform job, so a shared change can't break the Mac unnoticed.
