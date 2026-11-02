# 0007. One Day Nutrition module for every screen's day numbers

- Status: Accepted (implemented in #413)
- Date: 2026-11-02

## Context

The calculations are pure and tested ([ADR 0003](0003-pure-calculators-in-services.md)), but every screen gathers its own inputs before calling them, and they gather them differently. The architecture review of 1 Nov 2026 found:

- `DayBudget.make` takes nine inputs that each caller builds: profile, current weight, date, today, intake by day, exercise calories, whether there was a workout, the Health credit and the earn-back percent.
- `currentKg = latest weight ?? startWeight` is copied into about a dozen places, some reading `weights.first` and some `weights.last` depending on sort order.
- Three bugs were this one problem: #330, #370 and #408 (the widget, Watch, menu bar and Siri showed a different "calories left" from Today).
- After #411, Today, the Food diary, the widget snapshot, Siri and reminders use `DayBudget`. The meal plan, monthly report, partner share, Settings, Weight's plateau check and onboarding still use the plain daily target, with no weekly budget, day type or activity credit.

## Decision

Grow `DayBudget` into a single Day Nutrition module with a small interface, along the lines of `DayNutrition.for(day, in: context)`. Given a day and the store, it fetches what it needs and returns the day's nutrition: totals eaten (calories, macros, other nutrients), the day's budget and its parts (base, day type, activity credit), macro targets and calories left. The current weight is worked out inside it, once.

Every screen and surface that shows a day's numbers uses it: Today, the Food diary, the widget snapshot (and so the Watch and Mac menu bar), Siri and Shortcuts, reminders, the meal plan and the reports. The pure calculators stay as they are underneath; the module is the one place that turns the store into their inputs.

Inputs that don't live in the store, today's Health active energy and the credit percentages, come in through one small seam so tests can pass fixed values without HealthKit.

## Consequences

- One number per day, everywhere. A screen can't be "a bit different" without changing the module.
- The module's tests cover the input gathering that is untested today, using an in-memory store.
- Screens get simpler; most of their derived properties go away.
- Screens that show the plain daily target on purpose (for example Settings explaining how the target is worked out) need to say so, and use the module's base or daily target rather than reaching round it.
- It mostly removes the need for a separate shared day-fetch helper (idea 5 in the review), and makes a swappable HealthKit layer (idea 6) smaller if it's ever needed.
- The exact API is settled in the implementing PR; update this ADR if it ends up different.

## As built (#413)

`FitnessApp/Services/DayNutrition.swift`:

- `DayNutrition.make(profile:day:food:exercise:latestWeightKg:healthCredit:earnBackPercent:now:calendar:)` is the pure core. It takes plain values (`DayNutrition.Food`, `DayNutrition.Workout`) and is what the tests use, so they need no store or in-memory container.
- A `@MainActor` overload takes `FoodLogEntry` and `ExerciseEntry`, for views that already have them from `@Query`. It's the one seam that reads today's Health credit (`HealthKitManager.shared.activeEnergyCredit`) and the earn-back percent.
- `DayNutrition.for(day, in: context, profile:)` fetches the day's records (from the start of its week, for weekly budgeting) and the latest weigh-in itself.
- The result has `eaten`, `budget` (the `DayBudget`), `target` (the day's budget), `macros`, `base`, `activeCredit`, `dayType` and `remaining`. Other nutrients are not totalled yet.
- `DayNutrition.dailyTarget` and `dailyMacros` give the plain daily target. Summaries over many days use them (weekly review, monthly report, partner share, Settings export, both plateau checks, the protein streak, onboarding), because weekly budgeting, day type and activity are per-day adjustments that average out over a week.
- `UserProfile.currentWeightKg(latestWeighIn:)` is the one place the current weight falls back to the starting weight.

Settings still shows the daily target from `profile.calorieTarget`, on purpose, since it explains how that number is worked out.
