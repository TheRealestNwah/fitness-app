# 0004. Diary entries are snapshots of the food

- Status: Accepted
- Date: 2026-11-02 (recorded; the decision predates 1.0)

## Context

Foods get edited, corrected, merged by sync and deleted. If a diary entry pointed at its food, any of those would quietly change past days, and with them weekly budgets, reports and the adaptive maintenance estimate.

## Decision

A `FoodLogEntry` stores its own name, serving and nutrition totals for the amount eaten. Editing or deleting the food later never rewrites history. Saved meal lines (`SavedMealItem`) and meal plan items (`MealPlanEntry`) are snapshots in the same way, with an optional link back to the recipe or food only for convenience.

## Consequences

- Past days are stable, and backups and CSV exports are simple.
- Every way of logging (from a food, a recipe, a saved meal, a batch, a plan, copy, move, drag and drop, suggestions, Siri) has to build the snapshot fully, including micronutrients. When each path builds it by hand, fields get dropped; recipe logging losing micronutrients was one case. The architecture review of 1 Nov 2026 suggests one food-entry module that owns logging, copying, moving and deleting entries, with undo.
- Adding a nutrient means adding it to the entry and to every path that builds one.
