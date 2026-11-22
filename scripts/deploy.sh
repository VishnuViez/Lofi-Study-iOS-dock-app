#!/bin/zsh
# Builds Lofi Dock and installs + launches it on a paired iPhone over the network.
#
#   scripts/deploy.sh                 # device named "vPhone"
#   DEVICE_NAME="My iPhone" scripts/deploy.sh
#   TEAM_ID=ABCDE12345 scripts/deploy.sh
#
# Needs: Xcode (selected with xcode-select, or at one of the paths below), an
# Apple ID signed in under Xcode > Settings > Accounts, and the phone paired
# with Developer Mode on.
set -euo pipefail

ROOT=${0:A:h:h}
DEVICE_NAME=${DEVICE_NAME:-vPhone}
BUNDLE_ID=com.vishnu.lofidock
DERIVED=$ROOT/build/DerivedData
cd "$ROOT"

# Use the selected Xcode if there is one; otherwise point DEVELOPER_DIR at a
# known install, which avoids needing `sudo xcode-select`.
if ! xcodebuild -version >/dev/null 2>&1; then
  for app in ${XCODE_APP:-} "/Volumes/External/Applications/IDE's"/Xcode*.app(N) /Applications/Xcode*.app(N); do
    [[ -n $app && -d $app/Contents/Developer ]] || continue
    export DEVELOPER_DIR=$app/Contents/Developer
    break
  done
fi
if ! xcodebuild -version >/dev/null 2>&1; then
  echo "No Xcode found. Install it, or set XCODE_APP=/path/to/Xcode.app" >&2
  exit 1
fi
echo "==> $(xcodebuild -version | head -1) at ${DEVELOPER_DIR:-$(xcode-select -p)}"

# Team: explicit, else the one saved in project.yml, else the first team Xcode
# has recorded (Xcode 27 only records teams once one is picked in a project).
if [[ -z ${TEAM_ID:-} ]]; then
  TEAM_ID=$(grep -m1 -oE 'DEVELOPMENT_TEAM: [A-Z0-9]{10}' project.yml | awk '{print $2}' || true)
fi
if [[ -z ${TEAM_ID:-} ]]; then
  TEAM_ID=$(defaults read com.apple.dt.Xcode IDEProvisioningTeamByIdentifier 2>/dev/null \
    | grep -m1 -oE 'teamID = "?[A-Z0-9]{10}' | grep -oE '[A-Z0-9]{10}$' || true)
fi
if [[ -z ${TEAM_ID:-} ]]; then
  echo "No development team found. Sign in under Xcode > Settings > Accounts, or set TEAM_ID." >&2
  exit 1
fi

# Find the phone through CoreDevice (works over Wi-Fi once paired).
JSON=$(mktemp)
trap 'rm -f "$JSON"' EXIT
xcrun devicectl list devices --json-output "$JSON" >/dev/null
read -r DEVICE_ID UDID STATE < <(/usr/bin/python3 - "$JSON" "$DEVICE_NAME" <<'PY'
import json, sys
devices = json.load(open(sys.argv[1]))["result"]["devices"]
for d in devices:
    if d["deviceProperties"]["name"] == sys.argv[2]:
        print(d["identifier"], d["hardwareProperties"]["udid"],
              d["connectionProperties"].get("tunnelState", "unknown"))
        break
PY
) || true
if [[ -z ${DEVICE_ID:-} ]]; then
  echo "No paired device named \"$DEVICE_NAME\". Known devices:" >&2
  xcrun devicectl list devices >&2
  exit 1
fi
echo "==> $DEVICE_NAME ($UDID), tunnel: $STATE, team: $TEAM_ID"

if command -v xcodegen >/dev/null; then
  xcodegen generate --quiet
fi

echo "==> Building"
xcodebuild -project LofiDock.xcodeproj -scheme LofiDock -configuration Release \
  -destination "platform=iOS,id=$UDID" -derivedDataPath "$DERIVED" \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
  DEVELOPMENT_TEAM="$TEAM_ID" build -quiet

APP=$DERIVED/Build/Products/Release-iphoneos/LofiDock.app
echo "==> Installing"
xcrun devicectl device install app --device "$DEVICE_ID" "$APP"
echo "==> Launching"
xcrun devicectl device process launch --device "$DEVICE_ID" --terminate-existing "$BUNDLE_ID"
