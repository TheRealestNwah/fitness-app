# 0002. Versioned schema, and a recovery screen instead of a crash

- Status: Accepted
- Date: 2026-11-02 (recorded; the decision dates from 1.0)

## Context

A SwiftData store that can't be opened usually ends in a crash on every launch, and the person loses access to everything. Model changes are the usual cause.

## Decision

The model as of 1.0 is frozen as `StrideSchemaV1`, listed in `StrideMigrationPlan` (`Services/CloudSync.swift`).

- Adding an optional property, or one with a default, or a new model, is a lightweight change and needs no new version.
- Renaming, retyping or removing a property needs a `StrideSchemaV2` with copies of the changed models, and a migration stage.

If the store still can't be opened, the app runs on an empty in-memory store and shows `StoreRecoveryView`. It can move the broken store's files aside with a `.broken-<stamp>` suffix, so the next launch starts fresh while the old data stays on the device. Save errors are reported to the person through `SaveFailureCenter`, never swallowed by `try? save()`.

## Consequences

- Prefer adding properties to changing them. Changing one is a migration, so it needs a reason.
- A store from before versioning still opens without the plan.
- Changes to `UserProfile` also touch the backup format ([ADR 0008](0008-versioned-json-backup.md)).
