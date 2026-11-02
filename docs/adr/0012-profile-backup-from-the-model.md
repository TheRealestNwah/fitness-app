# 0012. The profile's backup format comes from UserProfile

- Status: Accepted
- Date: 2026-11-02
- Amends: [0008](0008-versioned-json-backup.md)

## Context

[ADR 0008](0008-versioned-json-backup.md) gave every model a hand-written backup record. For `UserProfile` that meant `ProfileRecord` repeated all fifty settings three times: as properties, in `init(_:)` and in `apply(to:)`. Adding a setting touched about five places, and forgetting one was silent: #407 lost meal slots and every training-day setting on restore.

Two more problems sat in the format itself:

- Synthesised `Codable` leaves a nil setting out of the file. So a missing key could mean "nil" or "this backup is older than the setting", and the record couldn't tell them apart. #410 worked around it per field (`mealSlotsJSON` and the training-day settings were optional in the record and left alone when missing).
- Deriving the record automatically isn't possible with public API. SwiftData's `@Model` hides stored values from `Mirror`, and the key paths in `schemaMetadata` aren't public.

## Decision

`UserProfile.backupFields` lists each setting once, as a backup key and a key path (`.value("name", \.name)`, `.optional("customCalorieTarget", \.customCalorieTarget)`). `ProfileRecord` is built from that list in both directions: it reads, writes, encodes and decodes every field through it. The list sits next to the stored properties in `UserProfile.swift`.

The backup format is now version 2:

- Every setting is written, and a nil one is written as `null`.
- On restore, a key that's present (even `null`) sets the profile's value. A missing key means the backup predates the setting, and the profile keeps its value.
- `BackupManager.decode` brings a version 1 file up to version 2 (`ProfileRecord.upgrade(fromVersion:)`): a missing optional key becomes `null`, because version 1 left nil settings out. The one exception is `dayTypeOverrideDay` in files made before #410, which have no `dayTypeOverrideIsTraining` either; it's left alone, as before.

Keys are the property names version 1 used, so a version 2 file reads the same apart from the `null`s and the version number.

The SwiftData schema doesn't change: `UserProfile`'s stored properties are untouched.

## Consequences

- Adding a setting touches two places: the property and one line in `backupFields`. `BackupManagerTests` fails if a stored property is missing from the list, if the list names one that doesn't exist, or if an optional property uses `.value` (or the reverse).
- Backup keys are part of the file format. Renaming a property is already a schema migration ([ADR 0002](0002-versioned-schema-and-store-recovery.md)); it also needs a plan for the old key in backups.
- Older apps (format 1) refuse version 2 files with the "made by a newer version of Stride" message. Version 1 files still restore.
- The other models keep hand-written records. Their fields change rarely, and their records are covered by the round-trip test. If one starts drifting, give it the same treatment.
