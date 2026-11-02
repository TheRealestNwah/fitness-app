# Architecture decision records

Each file records one decision: the situation, what was decided, and what follows from it. Read the ones that touch an area before changing it. If a change goes against an ADR, say so in the PR and either update the ADR or add a new one that supersedes it.

Domain terms are defined in [GLOSSARY.md](../../GLOSSARY.md).

| # | Decision | Status |
|---|----------|--------|
| [0001](0001-swiftdata-store-with-optional-icloud.md) | On-device SwiftData store, with iCloud sync opt-in | Accepted |
| [0002](0002-versioned-schema-and-store-recovery.md) | Versioned schema, and a recovery screen instead of a crash | Accepted |
| [0003](0003-pure-calculators-in-services.md) | Calculations are pure functions in `Services/`, tested there | Accepted |
| [0004](0004-diary-entries-are-snapshots.md) | Diary entries are snapshots of the food | Accepted |
| [0005](0005-activity-credit-is-the-larger-credit.md) | Activity credit is the larger of Health and exercise, today only | Accepted |
| [0006](0006-widget-snapshot.md) | Widgets, Watch and menu bar read a snapshot, not the store | Accepted |
| [0007](0007-day-nutrition-module.md) | One Day Nutrition module for every screen's day numbers | Accepted, in progress |
| [0008](0008-versioned-json-backup.md) | Backups are one versioned JSON file | Accepted |
| [0009](0009-native-mac-app.md) | A native macOS app, not Mac Catalyst | Accepted |
| [0010](0010-weight-progress-module.md) | One Weight Progress module for Today and the Weight screen | Accepted |

## Writing a new one

Copy the shape below into `NNNN-short-title.md` with the next number, and add it to the table.

```markdown
# NNNN. Title in plain words

- Status: Proposed | Accepted | Superseded by NNNN
- Date: YYYY-MM-DD

## Context
What's true now and why a decision is needed.

## Decision
What we do.

## Consequences
What gets easier, what gets harder, and what to watch for.
```
