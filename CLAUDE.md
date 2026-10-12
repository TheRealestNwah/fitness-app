# Stride (fitness-app)

SwiftUI weight-loss companion for iPhone, iPad, Mac and Apple Watch. Data lives on-device in SwiftData, with optional CloudKit sync and HealthKit read/write on supported devices.

## Layout

- `FitnessApp/` – the iOS/iPadOS app
  - `Models/` – SwiftData `@Model` types (food log, weigh-ins, recipes, profile…)
  - `Services/` – logic kept out of views: calculators, importers/exporters, HealthKit, notifications, sync. Most unit tests target these.
  - `Views/` – SwiftUI screens
  - `Intents/` – App Intents / Shortcuts
- `StrideWatch/` – watchOS app
- `StrideMac/` – native macOS entitlements; the `StrideMac` target shares `FitnessApp/` sources
- `StrideMacUITests/` – native Mac navigation, keyboard and onboarding tests
- `StrideWidgets/` – widgets, Live Activity and Control Center controls
- `FitnessAppTests/` – unit tests (one `*Tests.swift` per service)
- `FitnessAppUITests/` – one XCUITest class per area (`SmokeTests`, `SettingsTests`, `LoggingTests`, `PlannerTests`…), all run in CI, plus iPhone/iPad screenshot tests that aren't
- `docs/ROADMAP.md` – planned work
- `scripts/` – one-off helpers (app icon generation)

The Xcode project uses synchronized folders, so new `.swift` files are picked up automatically; don't hand-edit `project.pbxproj` just to add a file.

## Building and testing

Development happens on a MacBook Air with Xcode 27 and SwiftLint installed, but it has only 8 GB of RAM: local builds work, while simulators tend to freeze mid-run. **Treat CI as the source of truth for tests**, and don't burn time fighting a hung local simulator. A CI run takes about 12 minutes. So before pushing:

- Run `swiftlint lint --strict` (CI fails on any warning) and, where practical, a local build.
- Re-read the diff for compile errors: missing imports, typos in identifiers, wrong argument labels, unhandled optionals.
- Follow `.swiftlint.yml`.
- Add or update unit tests in `FitnessAppTests/` for new logic in `Services/`.

CI builds with Xcode 26 (iOS 26 SDK; local Xcode is newer, so check that APIs exist in the iOS 26 SDK) on the newest iOS simulator, but the deployment target is iOS 17. Wrap iOS 26-only APIs (Foundation Models, HealthKit medications, iPhone workout sessions, glass effects) in `#available(iOS 26, *)` and keep a fallback for older versions.

CI (`.github/workflows/ci.yml`) runs lint, then build, then unit tests, then every UI test class except `ScreenshotTests`/`IPadScreenshotTests` on an iPhone simulator, split across three parallel shards by `.github/scripts/ui-test-shard.sh`. New UI test classes are picked up and assigned to a shard without editing the workflow. The required check is a gate job that waits for the unit tests and every shard. UI tests launch with `-demoData` (Sam's profile, six weeks of weigh-ins, a week of food logs, a meal plan for today and tomorrow) or `-resetData` (onboarding). The required check on `main` is **"Build & test (iOS Simulator)"**. PRs that only touch docs (`docs/**`, `*.md`, `LICENSE`) skip the build and still pass that check.

Online food search uses Stride's own USDA FoodData Central key, passed at build time as the `USDA_API_KEY` build setting (e.g. `xcodebuild ... USDA_API_KEY=xxxx`) and read from `USDAAPIKey` in `FitnessApp/Info.plist` (iOS) and `Config/StrideMac-Info.plist` (Mac; CI checks the entry is there). For local and device builds, copy `Config/Local.xcconfig.example` to the gitignored `Config/Local.xcconfig` and put the key there. Never commit the key. Builds without it fall back to USDA's rate-limited `DEMO_KEY`, which is fine for development but not for App Store builds.

Screenshots (`.github/workflows/screenshots.yml`) run nightly, on pushes to `claude/**` branches, and on demand (Actions → Screenshots → Run workflow). They publish to the `screenshots` branch.

CI also runs `IPadSupportTests` on an iPad simulator and the `StrideMac` scheme on macOS. All three platform jobs must pass before merging. See [docs/PLATFORMS.md](docs/PLATFORMS.md) for platform differences and Mac signing setup. macOS deployment is 14; include `macOS 26` in availability checks for new shared APIs. Keep UIKit/AppKit adaptation in the platform helpers and guard mobile-only services with `#if os(iOS)`.

## Conventions

- Only `main` is branch-protected. Branch names use `feature/`, `fix/`, `chore/` or `docs/`.
- Always delete a branch (remote and local) once its PR merges, without asking. Squash merges make merged branches look unmerged to git, so check `gh pr list --head <branch> --state all` when sweeping stale ones. Never delete `main` or `screenshots`.
- Labels: `bug`, `enhancement`, `documentation`, `accessibility`, `chore`, `ci`, `refactor`, `parked` (blocked on something external, e.g. the paid developer account).
- The data model is versioned (`StrideSchemaV1` and `StrideMigrationPlan` in `Services/CloudSync.swift`). Adding an optional property or a new model is a lightweight change; renaming, retyping or removing a property needs a new schema version and a migration stage. If the store can't be opened, the app shows `StoreRecoveryView` rather than crashing.
- The UI is English only. There are no other localisations to keep in sync.
- User-facing PR titles use plain sentences ("Track saturated fat, potassium and cholesterol").
