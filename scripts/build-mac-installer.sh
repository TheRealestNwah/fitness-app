#!/usr/bin/env bash
# Builds the native Mac app and wraps it in an installer package (dist/Stride-<version>.pkg)
# that installs Stride.app into /Applications.
#
# Like scripts/install-mac.sh, this builds with a temporary entitlements file that leaves out
# iCloud, Push and the app group, because personal Apple teams can't sign them. The app is signed
# with a personal Apple Development certificate, so the package is for your own Macs: other Macs'
# Gatekeeper will refuse it. Shipping to anyone else needs a paid team (Developer ID signing and
# notarization).
#
# Usage: scripts/build-mac-installer.sh [TEAM_ID]
#   TEAM_ID defaults to $DEVELOPMENT_TEAM, then to the team set on the iOS targets in the project.
set -euo pipefail

cd "$(dirname "$0")/.."

team="${1:-${DEVELOPMENT_TEAM:-}}"
if [[ -z "$team" ]]; then
    team="$(grep -m1 'DEVELOPMENT_TEAM = ' FitnessApp.xcodeproj/project.pbxproj | sed 's/.*= \([A-Z0-9]*\);.*/\1/' || true)"
fi
if [[ -z "$team" ]]; then
    echo "No signing team found. Pass one: scripts/build-mac-installer.sh TEAM_ID" >&2
    exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

entitlements="$work/StrideMacLocal.entitlements"
cp StrideMac/StrideMac.entitlements "$entitlements"
for key in com.apple.security.application-groups \
           com.apple.developer.icloud-container-identifiers \
           com.apple.developer.icloud-services \
           com.apple.developer.aps-environment; do
    /usr/libexec/PlistBuddy -c "Delete :$key" "$entitlements" 2>/dev/null || true
done

echo "Building Stride for macOS (team $team)…"
xcodebuild build -project FitnessApp.xcodeproj -scheme StrideMac -destination 'platform=macOS' \
    -configuration Release -derivedDataPath "$work/build" -allowProvisioningUpdates \
    DEVELOPMENT_TEAM="$team" CODE_SIGN_ENTITLEMENTS="$entitlements" -quiet

app="$work/build/Build/Products/Release/Stride.app"
[[ -d "$app" ]] || { echo "Build finished but $app is missing." >&2; exit 1; }
codesign --verify --deep --strict "$app"

version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")"
mkdir -p dist
pkg="dist/Stride-$version.pkg"
pkgbuild --component "$app" --install-location /Applications "$pkg"
echo "Built $pkg"
echo "Open it to install, or: sudo installer -pkg $pkg -target /"
