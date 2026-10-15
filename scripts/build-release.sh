#!/usr/bin/env bash
# Builds a universal (Apple silicon + Intel) Release of Will's Bike Shop and packages it
# for download: dist/WillsBikeShop-<version>.dmg, a .zip, and SHA256SUMS.txt.
#
#   ./scripts/build-release.sh
#
# Signing:
#   - If a "Developer ID Application" certificate is in the keychain, the app and the .dmg
#     are signed with it. If notarization credentials are also stored (see NOTARY_PROFILE),
#     both are notarized by Apple and stapled, so downloads open without any warning.
#     Store credentials once with:
#       xcrun notarytool store-credentials wills-bike-shop --apple-id <you@example.com> --team-id <TEAMID>
#   - Otherwise the app is ad-hoc signed and users need a one-time "Open Anyway".
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="Will's Bike Shop"
NOTARY_PROFILE="${NOTARY_PROFILE:-wills-bike-shop}"
VERSION=$(sed -n 's/.*MARKETING_VERSION = \(.*\);/\1/p' WillsBikeShop.xcodeproj/project.pbxproj | head -1)
BASE="WillsBikeShop-$VERSION"

IDENTITY=$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -1)
TEAM_ID=$(sed -n 's/.*(\([A-Z0-9]\{10\}\))$/\1/p' <<<"$IDENTITY")
NOTARIZE=no
if [[ -n "$IDENTITY" ]] && xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
  NOTARIZE=yes
fi

echo "==> Testing BikeKit"
swift test --package-path BikeKit >/dev/null

SIGN_ARGS=()
if [[ -n "$IDENTITY" ]]; then
  echo "==> Signing with: $IDENTITY (notarize: $NOTARIZE)"
  SIGN_ARGS=(CODE_SIGN_STYLE=Manual "CODE_SIGN_IDENTITY=$IDENTITY" "DEVELOPMENT_TEAM=$TEAM_ID" OTHER_CODE_SIGN_FLAGS=--timestamp)
else
  echo "==> No Developer ID certificate found: ad-hoc signing (users will need \"Open Anyway\")"
fi

echo "==> Building $APP_NAME $VERSION (universal)"
xcodebuild -project WillsBikeShop.xcodeproj -scheme WillsBikeShop -configuration Release \
  -derivedDataPath build ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO ${SIGN_ARGS[@]+"${SIGN_ARGS[@]}"} clean build -quiet

APP="build/Build/Products/Release/$APP_NAME.app"
codesign --verify --deep --strict "$APP"
lipo -info "$APP/Contents/MacOS/$APP_NAME"

rm -rf dist && mkdir dist

if [[ $NOTARIZE == yes ]]; then
  echo "==> Notarizing the app (this takes a few minutes)"
  ditto -c -k --keepParent "$APP" "dist/notarize.zip"
  xcrun notarytool submit "dist/notarize.zip" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP"
  rm "dist/notarize.zip"
fi

echo "==> Packaging"
ditto -c -k --sequesterRsrc --keepParent "$APP" "dist/$BASE.zip"

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/$APP_NAME.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -quiet -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDZO "dist/$BASE.dmg"

if [[ -n "$IDENTITY" ]]; then
  codesign --sign "$IDENTITY" --timestamp "dist/$BASE.dmg"
fi
if [[ $NOTARIZE == yes ]]; then
  echo "==> Notarizing the disk image"
  xcrun notarytool submit "dist/$BASE.dmg" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "dist/$BASE.dmg"
  spctl -a -vv -t install "dist/$BASE.dmg"
fi

(cd dist && shasum -a 256 "$BASE.dmg" "$BASE.zip" > SHA256SUMS.txt)
ls -lh dist
