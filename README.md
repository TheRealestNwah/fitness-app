# Stride — iOS weight-loss companion

A SwiftUI app for anyone starting a weight-loss journey. Everything lives on-device (SwiftData), no account required.

## Features

**Today dashboard**
- Calorie ring with calories left/over, protein / carbs / fat bars against personalised targets
- Weight progress bar, projected goal date, days since last weigh-in
- Water tracker with one-tap glasses, daily logging streak, rotating tips
- Quick actions: log food, weigh in, log vitals, add water

**Weight tracking**
- Weigh-ins with notes, editable history, delta between entries
- Chart with 7-day moving average and goal line, 1M / 3M / 6M / All ranges
- Insights: actual weekly rate of loss (least-squares over 4 weeks) vs. plan, BMI, ETA to goal

**Calorie tracking**
- Diary by day and meal (breakfast / lunch / dinner / snacks) with per-meal subtotals
- Built-in database of ~100 common foods with macros; search, recents, favourites
- Custom foods, quick-add calories for meals you can't look up, log recipes as a meal
- Adjustable servings; entries are snapshots so history never changes
- Copy yesterday's meal in one tap, save any meal as a named favourite, and log a favourite meal from the top of search

**Vitals**
- Blood pressure (with category), resting heart rate, body-fat %, waist / hips / chest, sleep, fasting glucose
- Per-vital history charts and change since first reading

**Meal planning**
- Week planner with a meal slot per meal type and per-day calorie totals vs. budget
- Recipe library (16 starter recipes) with ingredients, method, macros; create and edit your own
- Auto-plan: fills empty slots with recipes closest to each meal's share of your budget, avoiding repeats on nearby days
- One-tap "Log" moves a planned meal into the diary; copy a day forward
- Grocery list aggregated from the week's recipes, with check-off

**Personalised plan & settings**
- Onboarding computes BMR (Mifflin-St Jeor), TDEE, calorie target with a safe floor, macro split, and goal date
- Metric or imperial units, light / dark / system appearance, manual calorie override, macro sliders, water goal
- Reminders: morning weigh-in, meal logging, water
- CSV export of weight, food and vitals; full reset

## Project layout

```
FitnessApp.xcodeproj
FitnessApp/
  FitnessApp.swift          App entry, SwiftData container
  Models/                   @Model classes and shared enums
  Services/                 NutritionCalculator, Units, SeedData, NotificationManager, DataExporter
  Views/
    Onboarding/  Dashboard/  Weight/  Food/  Vitals/  MealPlan/  Settings/  Components/
FitnessAppTests/            XCTest coverage for the calculation engine, units, recipes
```

## Requirements

- Xcode 16 or newer (the project uses folder-synchronised groups)
- iOS 17.0+ (SwiftData, Swift Charts, `@Observable`)

Open `FitnessApp.xcodeproj`, pick a simulator, and run. Tests: ⌘U.

## Demo data

Launch with `-demoData` (Scheme → Run → Arguments) to wipe the store and load a sample profile with six weeks of weigh-ins, today's diary, vitals and a meal plan. `-resetData` wipes everything and returns to onboarding. `-appearance dark` (or `light`) forces a colour scheme.

## Continuous integration

`.github/workflows/ci.yml` builds the app and runs the unit tests on an iOS simulator (macOS runner, Xcode 16) for every pull request and push to `main`. The shared `FitnessApp` scheme in `FitnessApp.xcodeproj/xcshareddata` is what the workflow drives.

`.github/workflows/screenshots.yml` runs the `FitnessAppUITests` screenshot suite on a simulator and publishes the PNGs to the `screenshots` branch (and as a workflow artifact).
