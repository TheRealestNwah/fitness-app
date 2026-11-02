# 0011. Apple Health sits behind a `HealthStore` adapter

- Status: Accepted
- Date: 2026-11-02

## Context

`HealthKitManager` mixed two jobs: Stride's rules for Apple Health (when sync is on, what to import and how to merge it into the store, the activity credit, retention days, mirroring diary and water entries) and the HealthKit queries themselves. The rules couldn't run without a real `HKHealthStore`, so only the pure helpers in `HealthImportRules` were tested, while the import, the 15-minute throttle and the write guards were not. Refactor idea 6 in the architecture review of 1 Nov 2026.

## Decision

Everything that touches HealthKit goes through the `HealthStore` protocol (`Services/HealthStore.swift`), which speaks in plain values: `HealthQuantity`, `HealthQuantitySample`, `HealthSleepInterval`, `HealthWorkoutSample`, `HealthProfileDetails` and `DietaryHealthRecord`. There are two adapters:

- `HealthKitStore`: the real one. It owns the `HKHealthStore`, the read and write type sets, units, the "asleep" and "no flow" filters, and the per-type sharing check before writes and deletes.
- `FakeHealthStore` (`FitnessAppTests/`): in memory, for tests.

`HealthKitManager` keeps the rules and its observable state. It takes the store, the `UserDefaults` its settings live in, and the clock in its initializer. `HealthKitManager.shared` uses `HealthKitStore`, `.standard` and the real time, so the app behaves as before. The fire-and-forget writes return their `Task` (discardable) so tests can wait for them.

## Consequences

- The manager's rules are unit tested against the fake (`HealthKitManagerTests`): sync off, Health unavailable, today's activity and credit, daily activity, the import and its deduplication, the import throttle, diary and water mirroring, access requests and retention days.
- A new Health read or write adds a method to `HealthStore` and both adapters; the manager never imports HealthKit types beyond the shared identifiers and units in `HealthImportRules`.
- Callers still reach the manager through `HealthKitManager.shared`. Passing it through the SwiftUI environment instead would let UI tests and previews swap it too, but no screen needs that yet.
- `PhoneWorkout` and `MedicationHealthImport` still use HealthKit directly: they are thin wrappers around live workout sessions and the iOS 26 medications API with no rules of their own.
