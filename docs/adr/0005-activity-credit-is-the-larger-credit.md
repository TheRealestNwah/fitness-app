# 0005. Activity credit is the larger of Health and exercise, today only

- Status: Accepted
- Date: 2026-11-02 (recorded; the rule predates 1.0, the exercise card was aligned with it in #411)

## Context

People can earn back calories from activity in two ways: a share of Apple Health's active energy, and a share of exercise logged in Stride. Apple Health's active energy already includes any workout recorded by the Watch or another app, so most logged workouts are in both numbers.

## Decision

The activity credit is `max(healthCredit, exerciseCredit)`, never the sum (`ExerciseCatalog.combinedCredit`). Each credit is a percentage the person picks (Health: 0, 50 or 100%; exercise: the earn-back percent). Exercise calories are net of resting burn, (MET − 1) × kg × hours, because the daily target already includes it. Only today gets a credit: past days don't, so the history doesn't move as Health data arrives late, and future days don't, since the activity hasn't happened.

The credit is added after the day-type offset and the safety floor (`DayBudget.make`). Anything that shows the credit, such as the exercise card, shows the credit actually applied, not one of the two inputs.

## Consequences

- Logging a workout that Health already counted doesn't double the credit.
- A small logged workout on a day with lots of other movement adds nothing, which can surprise people. The exercise card explains which credit was used.
- Any screen showing today's budget needs the same Health credit and exercise total, which is part of why [ADR 0007](0007-day-nutrition-module.md) gathers them in one place.
