# 0004. Diary entries are snapshots of the food

- Status: Accepted
- Date: 2026-11-02 (recorded; the decision predates 1.0)

## Context

Foods get edited, corrected, merged by sync and deleted. If a diary entry pointed at its food, any of those would quietly change past days, and with them weekly budgets, reports and the adaptive maintenance estimate.

## Decision

A `FoodLogEntry` stores its own name, serving and nutrition totals for the amount eaten. Editing or deleting the food later never rewrites history. Saved meal lines (`SavedMealItem`) and meal plan items (`MealPlanEntry`) are snapshots in the same way, with an optional link back to the recipe or food only for convenience.

## Consequences

- Past days are stable, and backups and CSV exports are simple.
- Every way of logging (from a food, a recipe, a saved meal, a batch, a plan, copy, move, drag and drop, suggestions, Siri) has to build the snapshot fully, including micronutrients. When each path built it by hand, fields got dropped; recipe logging losing micronutrients was one case. Since the architecture review of 1 Nov 2026, one module, `Diary` (`Services/Diary.swift`), owns logging, copying, moving, changing and deleting entries, with undo, and the snapshots are built by `FoodLogEntry` initialisers next to it. Screens call it instead of inserting entries themselves.
- Nutrients past calories and macros travel together as `OtherNutrients`. Adding a nutrient means adding it to the models and to `OtherNutrients`; the logging paths pick it up from there.
- Recipe ingredients picked from a saved food keep that food's other nutrients. Batches and plan items still snapshot only calories and macros, so their other nutrients come from the linked recipe or food when they're logged, and are zero if it has been deleted.
