# iPadOS and native macOS

Stride supports iOS/iPadOS 17 or later. The `StrideMac` scheme builds a separate native SwiftUI/AppKit app for macOS 14 or later, not Mac Catalyst. Both targets compile the shared `FitnessApp` models, services, and screens.

## Running on a Mac

Open `FitnessApp.xcodeproj` in Xcode 26 or later, select **StrideMac**, then **My Mac**. Set your signing team on StrideMac and register `com.stride.StrideMac` with access to the existing `iCloud.com.stride.FitnessApp` container and `group.com.stride.FitnessApp` app group if you want signed iCloud builds. The Mac target has its own sandbox entitlements, including network access, user-selected files, microphone input, and Reminders.

To install a Mac build with only a personal Apple team, run `scripts/install-mac.sh`. It signs with the team already set on the iOS targets (or one you pass) and leaves out the iCloud, Push and app-group entitlements that personal teams can't sign, so that install keeps its data on the Mac without iCloud sync.

To build an installer package instead, run `scripts/build-mac-installer.sh`. It writes `dist/Stride-<version>.pkg`, which installs the same build into /Applications. The app is signed with a personal development certificate, so the package works on your own Macs only; sharing it needs a paid team with Developer ID signing and notarization.

The Mac scheme starts with a normal persistent store. Add `-demoData` to the scheme's launch arguments only for disposable previews: it replaces the local store contents with demo records. CI passes this argument explicitly for UI tests.

The sidebar stays available as the window resizes. Wider windows show the diary calendar and two-column dashboards; narrower windows use single-column detail screens. Settings opens in the sidebar detail. Command-N opens food logging, Shift-Command-N opens another window, Command-comma opens Settings, and Command-1 through Command-5 switch sections. Recipe windows share the same store.

## Platform differences

- Food, water, weigh-ins, vitals, recipes, meal planning, reports, CSV import/export, notifications, Spotlight, and optional iCloud sync use shared logic.
- Mac photos use the Photos picker or image drag and drop. Barcode lookup accepts typed codes; live camera scanning and camera capture remain on supported iOS devices.
- Apple Health and live workout recording require a supported iPhone/iPad. Health-derived records already imported into Stride can sync through Stride's optional iCloud sync.
- Apple Watch pairing, iOS widgets, Live Activities, and iOS background refresh stay in the existing mobile targets. The native Mac target does not embed those extensions.
- The Mac app lock uses Touch ID or the account password. When enabled, switching away removes protected screens and closes their sheets, including during the grace period; save edits before switching away. Returning within the grace period does not require another authentication.

## Validation

Every code PR runs the existing iPhone lint/build/unit/UI suite, the iPad sidebar and compact-width UI tests, and native macOS build/unit/UI tests. Mac unit tests reuse the shared test suite; the two UIKit image test files run on iOS, with native image compression coverage on macOS.

CI validates unsigned simulator/Mac builds. Signed iCloud sync, permissions on physical devices, Touch ID, and App Store distribution still need checks with a development team on real hardware. No release or tag is created by these workflows.
