# 0008. Backups are one versioned JSON file

- Status: Accepted, amended by [0011](0011-profile-backup-from-the-model.md) for the profile
- Date: 2026-11-02 (recorded; the decision predates 1.0)

## Context

With no server ([ADR 0001](0001-swiftdata-store-with-optional-icloud.md)), people need a way to move to a new phone without iCloud, or keep a copy of their own. The format has to survive model changes and app updates.

## Decision

A backup is one JSON file holding every model, the profile and photos (`BackupFile`, `BackupManager`). It has a format `version`; the app refuses a file from a newer version with a clear message and still reads older ones. Each model has a hand-written Codable record (`ProfileRecord`, `FoodLogRecord`, `WeightRecord`…) that copies fields to and from the model, so the file format doesn't change when the SwiftData model is refactored. New fields in a record are optional so older backups still restore.

## Consequences

- Backups are readable, diffable and independent of SwiftData internals.
- Every new setting on `UserProfile` has to be added to `ProfileRecord` by hand, in both directions. Forgetting is silent: #407 lost meal slots and all training-day settings on restore. #410 added a test that every `UserProfile` property is covered by the backup, which catches this at CI time.
- Adding one setting touched about five places. [ADR 0011](0011-profile-backup-from-the-model.md) replaced the hand-written `ProfileRecord` with a field list on `UserProfile`, and moved the format to version 2.
