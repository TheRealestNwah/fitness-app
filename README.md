# Stride — iOS weight-loss companion

A SwiftUI app for anyone starting a weight-loss journey. Everything lives on-device (SwiftData), no account required.

> **Built with AI.** Stride's code, tests and documentation were written by
> Claude, an AI model from Anthropic, directed and tested by the maintainer.
> See [AI disclosure](#ai-disclosure).

## Screenshots

<table>
  <tr>
    <td align="center"><img src="https://raw.githubusercontent.com/TheRealestNwah/fitness-app/screenshots/10-today.png" width="180" alt="Today"><br><sub>Today</sub></td>
    <td align="center"><img src="https://raw.githubusercontent.com/TheRealestNwah/fitness-app/screenshots/12-food-diary.png" width="180" alt="Food diary"><br><sub>Food diary</sub></td>
    <td align="center"><img src="https://raw.githubusercontent.com/TheRealestNwah/fitness-app/screenshots/14-weight.png" width="180" alt="Weight"><br><sub>Weight</sub></td>
    <td align="center"><img src="https://raw.githubusercontent.com/TheRealestNwah/fitness-app/screenshots/16-vitals.png" width="180" alt="Vitals"><br><sub>Vitals</sub></td>
    <td align="center"><img src="https://raw.githubusercontent.com/TheRealestNwah/fitness-app/screenshots/18-meal-planner.png" width="180" alt="Meal plan"><br><sub>Meal plan</sub></td>
    <td align="center"><img src="https://raw.githubusercontent.com/TheRealestNwah/fitness-app/screenshots/30-dark-today.png" width="180" alt="Dark mode"><br><sub>Dark mode</sub></td>
  </tr>
</table>

<sub>Captured from the demo data by the nightly [Screenshots workflow](.github/workflows/screenshots.yml), so they track `main`. More (iPad, accessibility sizes) are on the [`screenshots` branch](https://github.com/TheRealestNwah/fitness-app/tree/screenshots).</sub>

## Features

**Today dashboard**
- Calorie ring with calories left/over, protein / carbs / fat bars against personalised targets
- Weight progress bar, projected goal date, days since last weigh-in
- Weekly review: average intake vs. budget, weight change vs. plan, days logged, and one concrete suggestion
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
- Barcode scanning (camera, or typed number where the camera isn't available) with Open Food Facts lookup; results are cached as custom foods so repeat scans work offline
- Adjustable servings with per-food presets (slice, cup, 100 g…) and the last serving remembered; entries are snapshots so history never changes
- Fuzzy search that tolerates typos, recent searches, and meals and favourites ranked by how often you log them
- Fibre, sugar and sodium alongside macros, with optional daily targets and limits
- Photo meal logging: snap a meal and log an estimate, flagged so you can refine it later
- Swipe between days, undo after deleting an entry
- Copy yesterday's meal in one tap, save any meal as a named favourite, and log a favourite meal from the top of search

**Progress**
- Goal milestones and plateau detection with suggestions
- Progress photos attached to weigh-ins, with side-by-side compare
- Maintenance mode after reaching your goal

**Fasting and exercise**
- Intermittent fasting timer with fasting:eating schedules and a history of completed fasts
- Exercise logging from a built-in catalogue, with optional earn-back calories on the daily budget

**Vitals**
- Blood pressure (with category), resting heart rate, body-fat %, waist / hips / chest, sleep, fasting glucose
- Per-vital history charts and change since first reading
- Correlation views, e.g. sleep against calories eaten, sodium against blood pressure

**Meal planning**
- Week planner with a meal slot per meal type and per-day calorie totals vs. budget
- Recipe library (16 starter recipes) with ingredients, method, macros; create and edit your own
- Auto-plan: fills empty slots with recipes closest to each meal's share of your budget, avoiding repeats on nearby days
- One-tap "Log" moves a planned meal into the diary; copy a day forward
- Grocery list aggregated from the week's recipes, with check-off
- Recipe scaling, nutrition calculated from ingredients, and import from a recipe web page

**Personalised plan & settings**
- Onboarding computes BMR (Mifflin-St Jeor), TDEE, calorie target with a safe floor, macro split, and goal date
- Metric or imperial units, weight in kg / lb / stones, energy in kcal or kJ; light / dark / system appearance; manual calorie override, macro sliders, water goal
- Flexible weekly budget (lighter days bank calories for later) and diet breaks at maintenance
- Customisable Today card order, first-run tips, haptics
- Adaptive target: measured maintenance from four weeks of intake and weigh-ins, shown against the formula with one-tap apply
- Adaptive reminders: morning weigh-in, meal logging and water, skipping anything already logged today
- Apple Health sync: imports weigh-ins, resting heart rate and sleep; writes weigh-ins and logged calories/macros; optional active-energy credit (off / half / all) on the daily budget; steps and active energy on Today
- CSV export of weight, food and vitals; shareable weekly summary image and doctor-friendly PDF report; full reset with confirmation

**Everywhere else**
- Home Screen and Lock Screen widgets: calories left, water, latest weight and streak
- Apple Watch app with one-tap water logging, plus calories-left complications
- Optional iCloud sync across iPhone and iPad (Settings → iCloud)

## Project layout

```
FitnessApp.xcodeproj
FitnessApp/
  FitnessApp.swift          App entry, SwiftData container
  Models/                   @Model classes and shared enums
  Services/                 Pure calculators (nutrition, budget, fasting, progress…), HealthKit, sync, export
  Views/
    Onboarding/  Dashboard/  Weight/  Food/  Vitals/  MealPlan/  Settings/  Components/
FitnessAppTests/            Unit tests, one file per service
FitnessAppUITests/          UI tests, plus the iPhone/iPad screenshot tests
StrideWidgets/              WidgetKit extension (iOS widgets; also built for watchOS complications)
StrideWatch/                watchOS app
```

## Requirements

- Xcode 26 or newer (the project uses folder-synchronised groups; CI builds with Xcode 26)
- iOS 17.0+ (SwiftData, Swift Charts, `@Observable`)

Open `FitnessApp.xcodeproj`, pick a simulator, and run. Tests: ⌘U.

## Running on a device

The simulator needs no setup. On a device, sign the targets with your team and register these capabilities in the developer portal:

- App Group `group.com.stride.FitnessApp`, which the app, widgets and watch share, for the widgets and the watch complication
- iCloud container `iCloud.com.stride.FitnessApp` with CloudKit, for iCloud sync (needs a paid developer account)
- Bundle IDs `com.stride.FitnessApp`, `.Widgets`, `.watchkitapp` and `.watchkitapp.Widgets`
- HealthKit, for Apple Health sync

## Demo data

Launch with `-demoData` (Scheme → Run → Arguments) to wipe the store and load a sample profile with six weeks of weigh-ins, today's diary, vitals and a meal plan. `-resetData` wipes everything and returns to onboarding. `-appearance dark` (or `light`) forces a colour scheme.

## Continuous integration

`.github/workflows/ci.yml` lints the Swift sources with SwiftLint (`swiftlint lint --strict`, configured in `.swiftlint.yml`), builds the app (with its widget and watch targets), then runs the unit tests and the UI tests on an iOS simulator (macOS runner, Xcode 26) for every pull request and push to `main`. Pull requests that only touch docs skip the build. The shared `FitnessApp` scheme in `FitnessApp.xcodeproj/xcshareddata` is what the workflow drives.

`.github/workflows/screenshots.yml` runs nightly (and on demand) on iPhone and iPad simulators and publishes the PNGs to the `screenshots` branch (and as a workflow artifact). The README screenshots come from there.

## AI disclosure

Stride was built with [Claude Code](https://claude.com/claude-code), Anthropic's
AI coding assistant. Claude wrote the code, tests and documentation. The
maintainer ([@TheRealestNwah](https://github.com/TheRealestNwah)) decided what
it should do, tested it, and made the release decisions. Commits written with
Claude carry a `Co-Authored-By: Claude` trailer, so the git history shows which
changes were AI-written.

## Support

Everything on my GitHub is free of charge and open source. If you find it
useful and want to leave a tip or buy me a coffee, you can do that at
[ko-fi.com/morrowheat23](https://ko-fi.com/morrowheat23). It's appreciated,
never expected.

## License

MIT. See [LICENSE](LICENSE).
