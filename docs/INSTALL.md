# Installing Stride

Stride 1.0 is distributed on GitHub, not the App Store. Download the files from the [Releases page](https://github.com/TheRealestNwah/fitness-app/releases):

| File | For | Needs |
| --- | --- | --- |
| `Stride-<version>.ipa` | iPhone and iPad | iOS / iPadOS 17 or later, a free Apple ID, and a Mac or Windows PC to install from |
| `Stride-<version>.dmg` | Mac | macOS 14 or later |

The builds are made without a paid Apple developer account, so they aren't signed or notarized by Apple. The steps below take a few extra minutes the first time.

## iPhone and iPad

The `.ipa` is unsigned. You sign it with your own Apple ID using a sideloading tool, which installs it on your device. A free Apple ID works.

### Install

1. Install [Sideloadly](https://sideloadly.io) or [AltStore](https://altstore.io) on your Mac or PC and follow its setup guide. Connect your iPhone or iPad with a cable the first time.
2. Open `Stride-<version>.ipa` in the tool and sign in with your Apple ID when asked.
3. **If the tool offers to remove app extensions, accept.** The file includes the widgets and the Apple Watch app, which don't work in this build (see [What's not included](#whats-not-included)). A free Apple ID can only have 3 sideloaded apps active at once, and each extension counts as one, so keeping them can make the install fail.
4. On the device, turn on **Developer Mode**: Settings → Privacy & Security → Developer Mode, then restart when asked. (iOS only shows this option after a sideloaded app has been installed.)
5. If Stride says it's from an untrusted developer, go to Settings → General → VPN & Device Management, tap your Apple ID, and tap **Trust**.

### Every 7 days

Apps signed with a free Apple ID expire after 7 days. After that Stride won't open until it's signed again. Your data isn't lost.

- **AltStore** refreshes automatically when your device and computer are on the same Wi-Fi with AltServer running. You can also tap **Refresh All** in AltStore.
- **Sideloadly:** install the same `.ipa` again with the same Apple ID.

Use the same Apple ID every time. Installing with a different one creates a separate copy of Stride without your data.

### Updating

Install the newer `.ipa` the same way, over the existing app. Your data stays.

## Mac

The Mac app is signed ad hoc and not notarized, so macOS blocks it the first time you open it.

1. Open `Stride-<version>.dmg` and drag **Stride** into **Applications**.
2. Open Stride from Applications. macOS says it can't verify the app. Click **Done** (not Move to Trash).
3. Open System Settings → Privacy & Security, scroll down to **Security**, and click **Open Anyway** next to the message about Stride. Enter your password.
4. Click **Open** in the dialog that follows.

You only need to do this once per version. To update, drag the new version into Applications and replace the old one; your data stays.

## What's not included

These features need a paid Apple developer account to sign, so they aren't in the 1.0 builds. See [PAID-ACCOUNT.md](PAID-ACCOUNT.md) for details.

- iCloud sync (data stays on each device)
- Home Screen and Lock Screen widgets
- Fasting Live Activity and Control Center controls
- The Apple Watch app and complications
- Sharing progress with an accountability partner through iCloud (sending a summary through the share sheet still works)

## Food search

Online food search uses USDA FoodData Central with USDA's shared `DEMO_KEY`, which has a low hourly limit across everyone using it. If searches start failing, get a free personal key at [fdc.nal.usda.gov/api-key-signup](https://fdc.nal.usda.gov/api-key-signup) and add it in Settings → Privacy & security → USDA API key. The built-in food database, barcode scanning (Open Food Facts) and everything else work without it.

## Backing up

Stride keeps your data on the device, and deleting the app deletes it. Before reinstalling, switching Apple IDs or moving to a new device, use Settings → Health & data → **Back up all data** and save the `.stridebackup` file somewhere safe. **Restore from backup** in the same place brings it back.
