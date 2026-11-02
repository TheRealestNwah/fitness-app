# 0003. Calculations are pure functions in `Services/`, tested there

- Status: Accepted
- Date: 2026-11-02 (recorded; the decision predates 1.0)

## Context

Most of Stride's value is in its numbers: targets, budgets, trends, forecasts. These need to be right and to stay right, and SwiftUI views and SwiftData queries are hard to unit test. The main development machine also can't run simulators reliably, so CI's unit tests are the first real check.

## Decision

Every derived number is worked out by a pure function in `Services/` that takes plain values and returns plain values, with no SwiftUI or SwiftData: `NutritionCalculator`, `BudgetCalculator`, `DayTargets`, `DayBudget`, `ProgressCalculator`, `AdaptiveTargetCalculator` and the rest. Each service has its own `*Tests.swift` in `FitnessAppTests/`. Views fetch records and display results; they don't calculate.

## Consequences

- The calculations are well tested and rarely the source of bugs.
- The weak spot is the step between the store and the calculator. Each screen gathers its own inputs (current weight, intake by day, exercise, Health credit), and when they gather them differently the same number differs between screens. That has caused #330, #370 and #408. [ADR 0007](0007-day-nutrition-module.md) addresses it by moving the gathering into a tested module too.
- New logic in `Services/` comes with unit tests.
