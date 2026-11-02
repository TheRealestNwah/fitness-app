# 0010. One Weight Progress module for Today and the Weight screen

- Status: Accepted
- Date: 2026-11-02

## Context

Today's weight card and the Weight screen both show how someone is doing against their goal: weight lost, weight remaining, a goal date from the plan and one from the actual pace, milestones and a plateau warning. The calculations were pure and tested ([ADR 0003](0003-pure-calculators-in-services.md)), but each screen gathered its own inputs: its own current weight, its own retention filtering, its own food window for the measured maintenance, and, until #413, a different target for the plateau check (Today used the weekly-adjusted base, Weight the plain daily target). Refactor idea 3 in the architecture review of 1 Nov 2026.

## Decision

`WeightProgress` (`Services/WeightProgress.swift`) is the one place that turns weigh-ins, diary lines and retention days into weight-progress numbers. A screen builds it from the records it already has (`WeightProgress(profile:weighIns:food:)`) and reads what it needs: `lostKg`, `remainingKg`, `goalFraction`, `trendKg`, `weeklyChangeKg`, `forecast`, `plannedGoalDate`, `milestones`, `nextMilestone`, `recentMilestone` and `plateau`, plus the readiness of the rate and forecast. Inside it:

- The current weight is the latest weigh-in by date, whatever order the caller sorted them in, through `UserProfile.currentWeightKg(latestWeighIn:)`.
- Retention days are left out of the forecast and plateau, and nothing else.
- The plateau check compares measured maintenance with the plain daily target (`DayNutrition.dailyTarget`), and is off in maintenance mode.

Building one is cheap; each number is worked out when it's read, so a view that reads several binds it to a local first. The calculators underneath (`ProgressCalculator`, `TrendReadiness`, `NutritionCalculator`, `AdaptiveTargetCalculator`, `BudgetCalculator.goalDate`) don't change.

## Consequences

- Today and the Weight screen can't disagree about progress without changing the module.
- The input gathering is unit tested (`WeightProgressTests`), with a fixed date, calendar and retention days.
- A new screen or surface showing progress (a widget, the monthly report) should build a `WeightProgress` rather than calling the calculators itself.
- The rate (`weeklyChangeKg`, negative when losing) and the forecast's `weeklyLossKg` (positive when losing) still have opposite signs; the names say which is which.
