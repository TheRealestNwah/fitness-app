#!/usr/bin/env bash
# Builds the native Mac app and installs it to /Applications, signed with a personal Apple team.
#
# The committed StrideMac entitlements need iCloud, Push and an app group, which personal teams
# can't sign. This builds with a temporary copy that leaves them out (the repo isn't edited), so
# the installed app keeps its data on the Mac and has no iCloud sync.
#
# Usage: scripts/install-mac.sh [TEAM_ID]
#   TEAM_ID defaults to $DEVELOPMENT_TEAM, then to the team set on the iOS targets in the project.
set -euo pipefail

cd "$(dirname "$0")/.."

team="${1:-${DEVELOPMENT_TEAM:-}}"
if [[ -z "$team" ]]; then
    team="$(grep -m1 'DEVELOPMENT_TEAM = ' FitnessApp.xcodeproj/project.pbxproj | sed 's/.*= \([A-Z0-9]*\);.*/\1/' || true)"
fi
if [[ -z "$team" ]]; then
    echo "No signing team found. Pass one: scripts/install-mac.sh TEAM_ID" >&2
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

if pgrep -x Stride >/dev/null; then
    echo "Quitting the running Stride…"
    osascript -e 'tell application "Stride" to quit' >/dev/null 2>&1 || true
    sleep 2
fi

rm -rf /Applications/Stride.app
cp -R "$app" /Applications/Stride.app
echo "Installed /Applications/Stride.app"
