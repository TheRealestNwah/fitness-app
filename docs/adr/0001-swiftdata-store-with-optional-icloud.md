# 0001. On-device SwiftData store, with iCloud sync opt-in

- Status: Accepted
- Date: 2026-11-02 (recorded; the decision predates 1.0)

## Context

Stride holds weight, food and health data, which people consider private. It needs to work offline, with no account, and on iPhone, iPad and Mac. Some people want their iPhone and iPad to share one diary.

## Decision

All data lives in a SwiftData store on the device. There is no Stride server. iCloud sync uses SwiftData's CloudKit integration with the private database (`CloudSync`), is off by default, and is read once at launch because a store's configuration can't change while it's open. If iCloud isn't available, the app falls back to the on-device store and says why. UI tests and demo data always run on-device.

CloudKit sets rules for the model: every property needs a default or is optional, there are no unique constraints, and relationships are optional. Because two devices can each seed the built-in foods, recipes and a profile before they first sync, seed records get stable ids derived from their names and `SyncDeduplicator` folds duplicates back into one. The person's own foods and recipes are never merged.

## Consequences

- New model properties must have a default or be optional, so they work with CloudKit.
- Code can't rely on there being exactly one `UserProfile`; deduplication runs after sync.
- Online food search (USDA, Open Food Facts) is the only network use besides iCloud.
- Signed iCloud builds need the paid developer account (see [PAID-ACCOUNT.md](../PAID-ACCOUNT.md)).
