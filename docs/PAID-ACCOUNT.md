# Features that need a paid Apple developer account

A free personal Apple team can't sign the iCloud, Push or App Group capabilities, so the features below can't be built or tested without a paid developer account. **They are not part of the 1.0 release.** The code stays in the repo and CI still builds it unsigned.

| Feature | Needs | Notes |
| --- | --- | --- |
| iCloud sync (`CloudSync`) | iCloud/CloudKit container `iCloud.com.stride.FitnessApp`, Push | Without it data stays on the device. `scripts/install-mac.sh` builds the Mac app this way. |
| Home Screen and Lock Screen widgets | App Group `group.com.stride.FitnessApp` | Widgets read the shared snapshot from the app group. |
| Fasting Live Activity | App Group | Ships in the widgets extension. |
| Control Center controls (log a glass of water) | App Group | Ships in the widgets extension. |
| Apple Watch app and complications | App Group | Shares data with the phone through the app group. |
| Share progress with an accountability partner (#307) | CloudKit sharing (`CKShare`) | Approved, but parked until a paid account is available. |

Features that work with a personal team and stay in 1.0: Apple Health (HealthKit), on-device AI (Foundation Models), barcode and label scanning, notifications, Siri and Shortcuts, app lock, CSV import and export, and everything else that stores data on the device.

When you add a feature that needs iCloud, Push, an App Group, Associated Domains or similar, add it to this table and say so in its issue.
