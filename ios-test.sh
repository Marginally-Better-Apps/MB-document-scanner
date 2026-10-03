#!/usr/bin/env bash
# Gala Engine gate: run the unit tests on an available iPhone simulator.
set -euo pipefail

DERIVED_DATA="${GALA_BUILD_DIR:-${TMPDIR:-/tmp}/mbdocumentscanner-test}/TestDerivedData"
SIMULATOR_ID="$(xcrun simctl list devices available -j | python3 -c '
import json, sys
devices = json.load(sys.stdin)["devices"]
ids = [d["udid"] for runtime, items in devices.items() if "iOS" in runtime for d in items if d["name"].startswith("iPhone")]
print(ids[0] if ids else "")
')"
test -n "$SIMULATOR_ID" || { echo "No available iPhone simulator" >&2; exit 1; }

xcodebuild -quiet \
  -project MBDocumentScanner.xcodeproj -scheme MBDocumentScanner \
  -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
  -derivedDataPath "$DERIVED_DATA" \
  test
