#!/usr/bin/env bash
# Gala Engine recipe: build an unsigned Release device IPA.
set -euo pipefail

: "${GALA_BUILD_DIR:?Gala build directory is required}"
: "${GALA_ARTIFACT_DIR:?Gala artifact directory is required}"

DERIVED_DATA="$GALA_BUILD_DIR/DerivedData"
xcodebuild -quiet \
  -project MBDocumentScanner.xcodeproj -scheme MBDocumentScanner \
  -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO build

APP="$DERIVED_DATA/Build/Products/Release-iphoneos/MBDocumentScanner.app"
test -d "$APP"
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/mbdocumentscanner-gala.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/Payload" "$GALA_ARTIFACT_DIR"
ditto "$APP" "$STAGE/Payload/MBDocumentScanner.app"
IPA="$GALA_ARTIFACT_DIR/MBDocumentScanner.ipa"
(cd "$STAGE" && zip -qry "$IPA" Payload)
shasum -a 256 "$IPA"
