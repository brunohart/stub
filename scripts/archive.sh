#!/usr/bin/env bash
# Archive Stub for the App Store and export it for TestFlight.
# Usage: scripts/archive.sh [--upload]
# The archive goes where Xcode's Organizer finds it (Window › Organizer › Archives), so it can also be uploaded from
# there. Without --upload the signed .ipa lands in build/export; with it, straight to App Store Connect, which needs
# the app's record to exist first (docs/device.md §4). The build number is the commit count, so an upload from a
# newer commit is always higher than the last; the version is MARKETING_VERSION in project.yml.
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
DESTINATION=export
while [ $# -gt 0 ]; do case "$1" in
  --upload) DESTINATION=upload;;
  *) echo "unknown argument $1" >&2; exit 2;;
esac; shift; done
[ -z "$(git status --porcelain)" ] || echo "note: the tree has uncommitted changes; the build number is HEAD's" >&2
xcodegen generate --quiet
VERSION=$(sed -n 's/^ *MARKETING_VERSION: "\(.*\)"/\1/p' project.yml)
BUILD=$(git rev-list --count HEAD)
ARCHIVE="$HOME/Library/Developer/Xcode/Archives/$(date +%F)/Stub $VERSION ($BUILD).xcarchive"
DD="${STUB_DERIVED_DATA:-$HOME/Library/Developer/Xcode/DerivedData/Stub-device}"
mkdir -p build
echo "archiving Stub $VERSION ($BUILD)"
# -allowProvisioningUpdates lets automatic signing use the Xcode account: it registers the bundle IDs and the App
# Group on first use and renews an expired development certificate.
xcodebuild -project Stub.xcodeproj -scheme Stub -configuration Release -destination 'generic/platform=iOS' \
     -derivedDataPath "$DD" -archivePath "$ARCHIVE" -allowProvisioningUpdates \
     CURRENT_PROJECT_VERSION="$BUILD" archive 2>&1 \
     | tee build/last-archive.log | grep -E "error:|ARCHIVE (SUCCEEDED|FAILED)" || true
grep -q "ARCHIVE SUCCEEDED" build/last-archive.log || { echo "archive failed; see build/last-archive.log" >&2; exit 1; }
OPTIONS=build/ExportOptions.plist
cp scripts/ExportOptions.plist "$OPTIONS"
/usr/libexec/PlistBuddy -c "Set :destination $DESTINATION" "$OPTIONS"
rm -rf build/export
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportOptionsPlist "$OPTIONS" -exportPath build/export \
     -allowProvisioningUpdates 2>&1 | tee build/last-export.log | grep -E "error:|EXPORT (SUCCEEDED|FAILED)|Upload" || true
grep -q "EXPORT SUCCEEDED" build/last-export.log || { echo "export failed; see build/last-export.log" >&2; exit 1; }
echo "archive: $ARCHIVE"
if [ "$DESTINATION" = upload ]; then echo "uploaded Stub $VERSION ($BUILD) to App Store Connect"
else echo "ipa: build/export/Stub.ipa"; fi
