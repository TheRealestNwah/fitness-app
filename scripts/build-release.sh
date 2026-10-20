#!/usr/bin/env bash
# Builds an installable 1.0 artifact for GitHub without a paid Apple Developer account.
#
#   scripts/build-release.sh ios   -> dist/Stride-<version>.ipa   (unsigned, for re-signing)
#   scripts/build-release.sh mac   -> dist/Stride-<version>.dmg   (ad-hoc signed, not notarized)
#
# The iOS IPA is unsigned: users re-sign it with their own Apple ID (AltStore, Sideloadly).
# The Mac app keeps no iCloud, Push or app-group entitlements, because they can't be signed
# without a paid team. Gatekeeper asks users to approve the app once (see docs/INSTALL.md).
#
# Food search uses the shared DEMO_KEY unless USDA_API_KEY is passed. Release artifacts don't
# include a key (see #401).
set -euo pipefail

cd "$(dirname "$0")/.."

platform="${1:-}"
case "$platform" in
    ios|mac) ;;
    *) echo "Usage: scripts/build-release.sh ios|mac" >&2; exit 2 ;;
esac

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p dist

if [[ "$platform" == "ios" ]]; then
    echo "Building Stride for iPhone and iPad (unsigned)…"
    xcodebuild build -project FitnessApp.xcodeproj -scheme FitnessApp \
        -destination 'generic/platform=iOS' -configuration Release \
        -derivedDataPath "$work/build" \
        CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
        -quiet

    app="$work/build/Build/Products/Release-iphoneos/FitnessApp.app"
    [[ -d "$app" ]] || { echo "Build finished but $app is missing." >&2; exit 1; }

    version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Info.plist")"
    payload="$work/Payload"
    mkdir -p "$payload"
    cp -R "$app" "$payload/"
    ipa="$PWD/dist/Stride-$version.ipa"
    rm -f "$ipa"
    (cd "$work" && zip -qry "$ipa" Payload)
    echo "Built $ipa"
    exit 0
fi

echo "Building Stride for macOS (ad-hoc signed)…"
entitlements="$work/StrideMacRelease.entitlements"
cp StrideMac/StrideMac.entitlements "$entitlements"
for key in com.apple.security.application-groups \
           com.apple.developer.icloud-container-identifiers \
           com.apple.developer.icloud-services \
           com.apple.developer.aps-environment; do
    /usr/libexec/PlistBuddy -c "Delete :$key" "$entitlements" 2>/dev/null || true
done

xcodebuild build -project FitnessApp.xcodeproj -scheme StrideMac -destination 'platform=macOS' \
    -configuration Release -derivedDataPath "$work/build" \
    CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="-" DEVELOPMENT_TEAM="" \
    CODE_SIGN_ENTITLEMENTS="$entitlements" \
    -quiet

app="$work/build/Build/Products/Release/Stride.app"
[[ -d "$app" ]] || { echo "Build finished but $app is missing." >&2; exit 1; }
codesign --verify --deep --strict "$app"

version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")"
dmg="$PWD/dist/Stride-$version.dmg"
rm -f "$dmg"
staging="$work/dmg"
mkdir -p "$staging"
cp -R "$app" "$staging/"
ln -s /Applications "$staging/Applications"
hdiutil create -quiet -volname "Stride $version" -srcfolder "$staging" -format UDZO "$dmg"
echo "Built $dmg"
