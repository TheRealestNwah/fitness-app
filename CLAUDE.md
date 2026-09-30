# Stride (fitness-app)

SwiftUI weight-loss companion for iPhone, iPad and Apple Watch. Data lives on-device in SwiftData, with optional CloudKit sync and HealthKit read/write.

## Layout

- `FitnessApp/` – the iOS/iPadOS app
  - `Models/` – SwiftData `@Model` types (food log, weigh-ins, recipes, profile…)
  - `Services/` – logic kept out of views: calculators, importers/exporters, HealthKit, notifications, sync. Most unit tests target these.
  - `Views/` – SwiftUI screens
  - `Intents/` – App Intents / Shortcuts
- `StrideWatch/` – watchOS app
- `StrideWidgets/` – widgets, Live Activity and Control Center controls
- `FitnessAppTests/` – unit tests (one `*Tests.swift` per service)
- `FitnessAppUITests/` – `SmokeTests` (run in CI) plus iPhone/iPad screenshot tests
- `docs/ROADMAP.md` – planned work
- `scripts/` – one-off helpers (app icon generation)

The Xcode project uses synchronized folders, so new `.swift` files are picked up automatically; don't hand-edit `project.pbxproj` just to add a file.

## Building and testing

Development happens on Windows, so there is **no local Swift, Xcode or SwiftLint**. CI on a macOS runner is the only place the app builds, and a run takes about 20 minutes. So before pushing:

- Re-read the diff for compile errors: missing imports, typos in identifiers, wrong argument labels, unhandled optionals.
- Follow `.swiftlint.yml`. CI runs `swiftlint lint --strict`, so any warning fails the build.
- Add or update unit tests in `FitnessAppTests/` for new logic in `Services/`.

CI builds with Xcode 26 (iOS 26 SDK) on the newest iOS simulator, but the deployment target is iOS 17. Wrap iOS 26-only APIs (Foundation Models, HealthKit medications, iPhone workout sessions, glass effects) in `#available(iOS 26, *)` and keep a fallback for older versions.

CI (`.github/workflows/ci.yml`) runs lint, then build, then unit tests, then the UI smoke tests on an iPhone simulator. The required check on `main` is **"Build & test (iOS Simulator)"**. PRs that only touch docs (`docs/**`, `*.md`, `LICENSE`) skip the build and still pass that check.

Screenshots (`.github/workflows/screenshots.yml`) run nightly, on pushes to `claude/**` branches, and on demand (Actions → Screenshots → Run workflow). They publish to the `screenshots` branch.

## Conventions

- Only `main` is branch-protected. Branch names use `feature/`, `fix/`, `chore/` or `docs/`.
- Labels: `bug`, `enhancement`, `documentation`, `accessibility`, `chore`, `ci`, `refactor`.
- The UI is English only. There are no other localisations to keep in sync.
- User-facing PR titles use plain sentences ("Track saturated fat, potassium and cholesterol").
