# Roadmap

What exists today: onboarding with a computed plan, Today dashboard, weight tracking with trend and insights, a food diary with a built-in food database, vitals with history, a week meal planner with recipes and a grocery list, reminders, CSV export, light/dark appearance, and CI with unit tests and simulator screenshots.

The items below are ordered by how much they help someone in the first weeks of a weight-loss journey, weighed against effort. Each has a short "done when".

## Tier 1 — highest impact, modest effort

1. **HealthKit sync (weight, steps, active energy, sleep, heart rate).**
   Read weigh-ins from a smart scale, steps and active energy from the watch, and write weight and dietary energy back. Done when: a HealthKit toggle in Settings imports the last 90 days, new samples appear without manual entry, and the calorie budget can optionally add a share of active energy.
2. **Barcode scanning + a bigger food database.**
   Camera scan (VisionKit) looking up Open Food Facts, with results cached as custom foods. Done when: scanning a packaged food logs it in two taps, and an offline fallback lets the user type in the label.
3. ~~**Copy yesterday / repeat meal / favourite meals.**~~ Shipped: per-meal "copy from yesterday", save-as-favourite from the meal menu, favourite meals at the top of food search with one-tap logging.
4. **Weekly review card.**
   Every Monday (or on demand): average intake vs. budget, weight change vs. the trend, logging consistency, and one concrete suggestion. Done when: the card appears on Today, and its numbers match the unit-tested calculator.
5. **Adaptive calorie target.**
   Re-estimate maintenance from actual intake and weight change over the last 3–4 weeks and propose a target adjustment. Done when: Settings shows "measured maintenance" next to the formula estimate and offers a one-tap apply.

## Tier 2 — usability polish

6. **Home-screen and lock-screen widgets** (calories left, water, last weigh-in) with an App Intent to add a glass of water.
7. **Today refreshes at midnight** and when the app returns to the foreground; the dashboard's "today" queries are currently built once.
8. **Search improvements**: fuzzy matching, recently searched terms, and a "per 100 g" entry mode for custom foods.
9. **Progress photos** attached to weigh-ins, with a side-by-side compare view.
10. **Body measurements chart** showing waist, hips and chest together, and a body-fat trend against the weight trend.
11. **Accessibility pass**: Dynamic Type check on every screen, VoiceOver labels on the ring and bars, and screenshot tests at the largest accessibility size.
12. **Localisation and units**: string catalog, stones for weight, kJ option for energy.

## Tier 3 — larger features

13. **Exercise logging** with a small activity database and optional HealthKit workouts, feeding an "earn back" toggle for calories.
14. **Recipe scaling and nutrition from ingredients** using the food database, plus importing a recipe from a URL.
15. **Reminders that adapt**: skip the water reminder once the goal is met, nudge when no food is logged by early afternoon.
16. **iCloud sync** via SwiftData's CloudKit container so a phone and iPad share data.
17. **Sharing**: export a weekly summary image and a doctor-friendly PDF of vitals and weight.

## Known rough edges to fix soon

- The macro sliders can total more or less than 100%; they are normalised, but the UI should keep them balanced.
- Grocery list quantities are concatenated strings rather than summed amounts.
- Reset from Settings deletes on a short delay after dismissal; a proper "are you sure" flow with progress would be clearer.
