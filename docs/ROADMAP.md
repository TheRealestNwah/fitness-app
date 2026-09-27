# Roadmap

What exists today: onboarding with a computed plan, Today dashboard, weight tracking with trend and insights, a food diary with a built-in food database, vitals with history, a week meal planner with recipes and a grocery list, reminders, CSV export, light/dark appearance, and CI with unit tests and simulator screenshots.

Planned work is tracked as [GitHub issues](https://github.com/TheRealestNwah/fitness-app/issues); each issue has its own "done when". This page groups them by priority, ordered by how much they help someone in the first weeks of a weight-loss journey, weighed against effort. Open [bugs](https://github.com/TheRealestNwah/fitness-app/issues?q=is%3Aopen+label%3Abug) come before new features.

## Shipped — Tier 1

1. **HealthKit sync (weight, steps, active energy, sleep, heart rate).** Settings toggle imports 90 days of weigh-ins, resting heart rate and sleep (and keeps importing on foreground), writes weigh-ins and diary calories/macros back, shows steps and active energy on Today, and can credit off / half / all of active energy to the budget.
2. **Barcode scanning + a bigger food database.** VisionKit scanner (typed-number fallback where the camera isn't available) with Open Food Facts lookup, cached as custom foods with the barcode, and a create-food path for unknown codes.
3. **Copy yesterday / repeat meal / favourite meals.** Per-meal "copy from yesterday", save-as-favourite from the meal menu, favourite meals at the top of food search with one-tap logging.
4. **Weekly review card.** "Last 7 days" card on Today with average intake vs. budget, weight change vs. plan, days logged, and a rule-based headline and suggestion (`WeeklyReviewCalculator`, unit-tested).
5. **Adaptive calorie target.** `AdaptiveTargetCalculator` estimates maintenance from 28 days of intake and weigh-ins (energy balance, with data-sufficiency and confidence rules); Settings shows it against the formula with a one-tap apply.

## Known rough edges

- [#28](https://github.com/TheRealestNwah/fitness-app/issues/28) Today doesn't refresh at midnight or on foreground
- [#39](https://github.com/TheRealestNwah/fitness-app/issues/39) Macro sliders can total more or less than 100%
- [#40](https://github.com/TheRealestNwah/fitness-app/issues/40) Grocery list concatenates quantities instead of summing
- [#41](https://github.com/TheRealestNwah/fitness-app/issues/41) Reset data needs a proper confirmation and progress flow

## Tier 2 — usability polish

- [#27](https://github.com/TheRealestNwah/fitness-app/issues/27) Home-screen and lock-screen widgets
- [#29](https://github.com/TheRealestNwah/fitness-app/issues/29) Food search: fuzzy matching, recent searches, per-100 g entry
- [#25](https://github.com/TheRealestNwah/fitness-app/issues/25) Rank meals and favourites in food search
- [#17](https://github.com/TheRealestNwah/fitness-app/issues/17) Undo after deleting entries
- [#20](https://github.com/TheRealestNwah/fitness-app/issues/20) Swipe between days in the Food diary
- [#19](https://github.com/TheRealestNwah/fitness-app/issues/19) Empty states with a primary action
- [#24](https://github.com/TheRealestNwah/fitness-app/issues/24) Faster weigh-in entry
- [#23](https://github.com/TheRealestNwah/fitness-app/issues/23) Serving presets and remembered serving size
- [#21](https://github.com/TheRealestNwah/fitness-app/issues/21) Quick actions from the calorie ring
- [#22](https://github.com/TheRealestNwah/fitness-app/issues/22) Customisable Today card order
- [#18](https://github.com/TheRealestNwah/fitness-app/issues/18) Haptic feedback for logging and goals
- [#26](https://github.com/TheRealestNwah/fitness-app/issues/26) First-run feature tips with TipKit
- [#30](https://github.com/TheRealestNwah/fitness-app/issues/30) Progress photos with side-by-side compare
- [#31](https://github.com/TheRealestNwah/fitness-app/issues/31) Body measurements chart and body-fat trend
- [#32](https://github.com/TheRealestNwah/fitness-app/issues/32) Accessibility pass: Dynamic Type, VoiceOver, large-size screenshots
- [#33](https://github.com/TheRealestNwah/fitness-app/issues/33) Localisation and extra units (stones, kJ)

## Tier 3 — larger features

- [#10](https://github.com/TheRealestNwah/fitness-app/issues/10) Goal milestones and plateau detection
- [#11](https://github.com/TheRealestNwah/fitness-app/issues/11) Maintenance mode after reaching goal
- [#13](https://github.com/TheRealestNwah/fitness-app/issues/13) Track fibre, sugar and sodium
- [#34](https://github.com/TheRealestNwah/fitness-app/issues/34) Exercise logging with earn-back calories
- [#36](https://github.com/TheRealestNwah/fitness-app/issues/36) Adaptive reminders
- [#12](https://github.com/TheRealestNwah/fitness-app/issues/12) Flexible weekly calorie budget and diet breaks
- [#9](https://github.com/TheRealestNwah/fitness-app/issues/9) Intermittent fasting timer
- [#14](https://github.com/TheRealestNwah/fitness-app/issues/14) Photo meal logging placeholder
- [#35](https://github.com/TheRealestNwah/fitness-app/issues/35) Recipe scaling, nutrition from ingredients, URL import
- [#15](https://github.com/TheRealestNwah/fitness-app/issues/15) Correlation views in Vitals
- [#38](https://github.com/TheRealestNwah/fitness-app/issues/38) Share weekly summary image and doctor-friendly PDF
- [#37](https://github.com/TheRealestNwah/fitness-app/issues/37) iCloud sync via SwiftData CloudKit
- [#16](https://github.com/TheRealestNwah/fitness-app/issues/16) Apple Watch app / complication
