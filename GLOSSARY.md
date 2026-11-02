# Glossary

The words Stride uses for its domain, and what each one means in the code. Use these terms in issues, PRs, test names and comments. Where a term has a common synonym we avoid, it's listed under _Avoid_.

Decisions behind these terms are in [docs/adr/](docs/adr/).

## Energy and targets

**BMR (basal metabolic rate)**
: Calories burned at rest, from the Mifflin-St Jeor formula (`NutritionCalculator.bmr`). Uses the current weight.

**TDEE (total daily energy expenditure)**
: BMR times the activity level's multiplier (`NutritionCalculator.tdee`). Stride's estimate of maintenance before there's enough diary data for the adaptive estimate.

**Activity level**
: The person's everyday movement (`ActivityLevel`), chosen in onboarding. It sets the TDEE multiplier and is separate from logged exercise.

**Maintenance calories**
: Calories that hold weight steady. Either the TDEE, or the **adaptive maintenance estimate**: what four weeks of diary and weigh-ins say maintenance really is (`AdaptiveTargetCalculator`, `MaintenanceEstimate`). The estimate needs 14 logged days and 4 weigh-ins over 14 days, and carries a confidence level.

**Safety floor**
: The lowest daily calorie target Stride will set without medical supervision: 1,200 kcal (female) or 1,500 kcal (male) (`NutritionCalculator.calorieFloor`). Every target, rest-day cut and weekly share is held at or above it.
: _Avoid:_ minimum, limit.

**Pace** (weekly loss)
: The planned loss per week (`UserProfile.weeklyLossKg`). Turned into a daily deficit at 7,700 kcal per kg of fat (`NutritionCalculator.kcalPerKgFat`).

**Daily target** (profile target)
: The calorie target from the profile alone, for a given current weight: the custom target if set; otherwise maintenance calories in maintenance mode or on a diet break; otherwise TDEE minus the pace's deficit, held at the safety floor (`UserProfile.calorieTarget(currentWeightKg:)`). It has none of the day's adjustments (weekly budget, day type, activity credit).
: _Avoid:_ using "target" alone when you mean this; say "daily target" or "day's budget".

**Custom target**
: A calorie target the person typed in (`UserProfile.customCalorieTarget`). Replaces the calculated daily target and turns off weekly budgeting. Cleared when maintenance mode starts.

**Macro split**
: Protein, carbs and fat as percentages of calories (`proteinPercent`, `carbsPercent`, `fatPercent`). **Macro targets** are those percentages turned into grams for a calorie number (`MacroTargets`, `NutritionCalculator.macroGrams`).

**Current weight**
: The latest weigh-in, or the start weight when there are none. Most targets are worked out from it. Today every screen works it out itself (`weights.first?.weightKg ?? profile.startWeightKg`); [ADR 0007](docs/adr/0007-day-nutrition-module.md) moves it into one place.

## The day's budget

**Day's budget** (calorie budget)
: What the person can eat on a given day after every adjustment: the base, moved for the day type (never below the safety floor), plus the activity credit (`DayBudget.calories`). This is the number Today, the Food diary, the widget, Watch, Mac menu bar and Siri should all show.
: _Avoid:_ goal (that's the goal weight), allowance.

**Base**
: The daily target after weekly budgeting, before the day-type offset and activity credit (`DayBudget.base`). Equal to the daily target unless weekly budgeting is on.

**Calories left** (remaining)
: The day's budget minus calories eaten. Can be negative.

**Weekly budget** (weekly budgeting, banking)
: An option to budget the week as a whole: today's base is what's left of 7 times the daily target, shared over the days left, clamped between the safety floor and 150% of the daily target (`BudgetCalculator.weeklyAdjustedTarget`). Past days with nothing logged count as on target. Off during a diet break, in maintenance mode and with a custom target. The **week balance** is calories banked (positive) or overspent (negative) so far.

**Day type**
: Whether a day is a **training day** or a **rest day** (`DayType`), when training days are turned on (`TrainingPlan`). A day becomes a training day by weekday, by a logged or imported workout (if that option is on), or by a one-day manual override. Nil when training days are off or during a diet break.

**Training bonus / rest-day cut**
: Calories added on a training day (`TrainingPlan.bonusKcal`), and taken off each rest day so a typical week averages to the daily target (`DayTargets.restCutKcal`). Together they are the **day-type offset** (`DayTargets.calorieOffset`). Training days also move a **carb shift** of percentage points from fat to carbs.

**Activity credit** (earn-back)
: Calories added to today's budget for activity. It's the larger of two credits, never their sum, because Apple Health's active energy already includes logged workouts (`ExerciseCatalog.combinedCredit`):
  - **Health credit**: a share (0, 50 or 100%) of today's Apple Health active energy (`HealthSettings.creditPercent`, `HealthKitManager.activeEnergyCredit`).
  - **Exercise credit**: a share of the calories from exercise logged in Stride (`ExerciseSettings.earnBackPercent`, `ExerciseCatalog.earnBack`). Exercise calories are net of the resting burn, (MET − 1) × kg × hours.

  Only today gets an activity credit; past and future days don't.
: _Avoid:_ "exercise calories" for the credit (that's the logged burn before the share is applied).

**Day nutrition** (planned)
: The single answer to "what does this day look like": totals eaten, the day's budget, macro targets, calories left and activity credit, worked out from the store in one place. See [ADR 0007](docs/adr/0007-day-nutrition-module.md).

## Plans and modes

**Maintenance mode**
: Holding weight instead of losing it (`UserProfile.isMaintaining`, set by `maintenanceStartedAt`). The daily target becomes maintenance calories. Offered once the 7-day trend reaches the goal weight.

**Maintenance band**
: How far either side of the maintenance weight still counts as on track (`maintenanceBandKg`, default 1.5 kg). The trend is **in band**, **above** or **below** (`MaintenanceStatus`).

**Diet break**
: A planned stretch eating at maintenance (`dietBreakStart` to `dietBreakEnd`, end day not included). Weekly budgeting and day types pause, and the goal date moves later by the break days still ahead. Reminders can pause too.

**Weight goal**
: What the person wants from Stride, asked in onboarding (`WeightGoal`): lose weight, keep it steady, or just track. Only "lose" needs a goal weight and a pace; the others start in maintenance mode.

## Weight progress

**Weigh-in**
: One weight reading (`WeightEntry`), entered by hand or imported from Apple Health.

**Trend** (7-day trend)
: The mean of the weigh-ins in the 7 days ending on a day (`ProgressCalculator.trend`). Milestones, plateaus and maintenance status use the trend, not a single weigh-in, so one light morning doesn't count.
: _Avoid:_ average weight, moving average (in user-facing text "your average" is fine).

**Weight progress**
: Everything below about where someone is on the way to their goal weight, worked out in one place for Today and the Weight screen (`WeightProgress`): current weight, **lost** (since the start weight; negative after a gain), **remaining** (to the goal; zero once reached), rate, forecast, planned goal date, milestones and plateau. See [ADR 0010](docs/adr/0010-weight-progress-module.md).

**Rate** (rate of loss)
: Weight change per week from a straight-line fit through the last four weeks of weigh-ins (`WeightProgress.weeklyChangeKg`, from `NutritionCalculator.weeklyRate`). Negative means losing. Shown once there are 3 weigh-ins over 7 days.

**Forecast** (goal date)
: When the trend reaches the goal weight at the actual rate (`WeightProgress.forecast`, from `ProgressCalculator.trendForecast`). Its `weeklyLossKg` is positive when losing. Nil without enough data, when weight is flat or rising, or when it's too far off.

**Planned goal date**
: When the goal would be reached at the planned pace from the current weight, moved later by a diet break still ahead (`WeightProgress.plannedGoalDate`). Shown until there's enough data for a forecast.

**Milestone**
: Every 5% of starting weight lost, measured on the trend (`Milestone`).

**Plateau**
: The trend has moved less than a tolerance for a minimum number of days, with regular weigh-ins, while there's still weight to lose (`WeightProgress.plateau`, from `ProgressCalculator.plateau`). Its suggestions compare the measured maintenance with the plain daily target. Never shown in maintenance mode.

**Retention days**
: Days likely to show water retention, from cycle data when cycle-aware weight is on (`CycleCalculator`). Left out of the forecast and plateau checks.

**Trend readiness**
: How close the data is to supporting a trend-based insight ("3 of 5 weigh-ins") (`TrendProgress`).

## Logging

**Food** (food item)
: Something that can be logged, with nutrition per serving (`FoodItem`). Built-in (seeded), the person's own, or from online search (USDA FoodData Central, Open Food Facts).

**Entry** (diary entry, log entry)
: One logged item in the diary (`FoodLogEntry`). A snapshot: values are totals for the logged amount, so editing or deleting the food later never rewrites history.
: _Avoid:_ "log" as a noun for one item; the **diary** is all the entries.

**Diary** (Food diary)
: A day's entries grouped by meal, and the screen that shows them. Every change to entries (logging from a food, recipe, saved meal, batch or plan item, quick add, logging again, copying, moving, changing the amount, deleting) goes through `Diary` (`Services/Diary.swift`), which builds the full snapshot, mirrors it to Apple Health, saves, and offers undo. See [ADR 0004](docs/adr/0004-diary-entries-are-snapshots.md).

**Other nutrients**
: Everything an entry records past calories and the three macros: fibre, sugar, sodium, saturated fat, potassium, cholesterol, alcohol, caffeine, and vitamins and minerals (`OtherNutrients`). Recipe ingredients picked from a saved food carry them too, so logging a recipe keeps them.

**Last amount** (last servings)
: The amount of a food last logged (`FoodItem.lastServings`), the default the next time it's logged anywhere: search, suggestions, drag and drop, the Mac menu bar and the Watch.

**Meal slot** (meal)
: One of the person's meals (`MealSlot`, `MealType`): name, icon, usual time, whether it reminds, and its share of the day's budget. The defaults are Breakfast, Lunch, Dinner and Snacks; the list lives on the profile.

**Saved meal**
: A named group of entries the person eats often, logged again with one tap (`SavedMeal`). Its lines are snapshots too.

**Recipe**
: Ingredients and method that make a number of servings (`Recipe`). Can be scaled and imported from a URL.

**Meal-prep batch**
: A recipe cooked once and eaten over several days (`MealPrepBatch`). Logging a portion counts it down.

**Meal plan**
: Items planned for a day (`MealPlanEntry`), each a single-serving snapshot with an optional link back to its recipe or food. Feeds the grocery list.

**Check-in** (meal check-in)
: How hungry someone was before a meal and how they felt after, one per meal per day (`MealCheckIn`).

**Streak**
: Consecutive days, ending today, with at least one entry (`NutritionCalculator.streak`). With the **grace day** option, one missed day between two logged days doesn't break it. There's also a protein streak.

**Today**
: The dashboard screen (`DashboardView`), not just the date.

## Platform and data

**Store**
: The SwiftData database on the device. Optionally synced with iCloud (CloudKit). See [ADR 0001](docs/adr/0001-swiftdata-store-with-optional-icloud.md).

**Schema version**
: A frozen copy of the data model (`StrideSchemaV1`) listed in `StrideMigrationPlan`. See [ADR 0002](docs/adr/0002-versioned-schema-and-store-recovery.md).

**Seed data** / **stable id**
: The built-in foods and recipes, given ids derived from their names so every device seeds the same ones (`SyncDeduplicator.stableID`).

**Backup**
: The whole app in one versioned JSON file (`BackupFile`), with one hand-written record type per model (`ProfileRecord`, `FoodLogRecord`…). See [ADR 0008](docs/adr/0008-versioned-json-backup.md).

**Widget snapshot**
: Today's numbers written as JSON to the shared App Group after every change (`WidgetSnapshot`). The widgets, Watch app and Mac menu bar read it instead of the store. See [ADR 0006](docs/adr/0006-widget-snapshot.md).

**Demo data**
: Sam's profile, six weeks of weigh-ins, a week of entries and a meal plan, loaded with the `-demoData` launch argument for UI tests and previews (`DemoData`). `-resetData` starts at onboarding.
