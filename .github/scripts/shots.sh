#!/usr/bin/env bash
set -euo pipefail

device=$1
app_path=$2
out=${3:-shots}

BUNDLE_ID=com.sidharthify.BreatheOSS
GROUP_ID=group.com.sidharthify.BreatheOSS.BreatheWidget
PINNED='["srinagar","kargil_town","jammu_city"]'
PINNED_HEX=$(printf '%s' "$PINNED" | xxd -p | tr -d '\n')

mkdir -p "$out"

pick_device() {
  local pattern udid
  for pattern in "$@"; do
    udid=$(xcrun simctl list devices available -j | jq -r --arg p "$pattern" '[.devices[][] | select(.name | startswith($p))] | last | .udid // empty')
    if [ -n "$udid" ]; then
      echo "$udid"
      return
    fi
  done
}

seed_prefs() {
  local dirs=("$(xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" data)")
  local group_dir
  group_dir=$(xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" "$GROUP_ID" 2>/dev/null || true)
  if [ -n "$group_dir" ]; then
    dirs+=("$group_dir")
  fi
  for dir in "${dirs[@]}"; do
    mkdir -p "$dir/Library/Preferences"
    plist="$dir/Library/Preferences/$GROUP_ID"
    defaults write "$plist" has_onboarded -bool YES
    defaults write "$plist" is_us_aqi -bool YES
    defaults write "$plist" pinned_zones -data "$PINNED_HEX"
  done
}

shoot() {
  local name=$1 tab=$2
  shift 2
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
  rm -f "$MARKER"
  xcrun simctl launch "$UDID" "$BUNDLE_ID" \
    -initialTab "$tab" \
    -has_onboarded YES \
    -pinned_zones "<$PINNED_HEX>" \
    "$@" > /dev/null
  local tries=0
  while [ ! -f "$MARKER" ] && [ "$tries" -lt 120 ]; do
    sleep 0.25
    tries=$((tries + 1))
  done
  if [ ! -f "$MARKER" ]; then
    echo "::warning::$name never signalled ready"
  fi
  xcrun simctl io "$UDID" screenshot "$out/$name.png"
}

appearance() {
  xcrun simctl ui "$UDID" appearance "$1"
}

iphone_set() {
  local mode=$1
  shoot "iphone-home-$mode" 0 -shotZone gandhi-nagar
  shoot "iphone-home-nodes-$mode" 0 -shotZone gandhi-nagar -shotScroll nodes
  shoot "iphone-home-history-$mode" 0 -shotZone gandhi-nagar -shotScroll history
  shoot "iphone-home-hourly-$mode" 0 -shotZone gandhi-nagar -shotScroll history -shotHistory hourly
  shoot "iphone-node-live-$mode" 0 -shotZone gandhi-nagar -shotSheet node
  shoot "iphone-node-offline-$mode" 0 -shotZone ahamshrief -shotSheet offlineNode
  shoot "iphone-extended-history-$mode" 0 -shotZone gandhi-nagar -shotScreen extendedHistory
  shoot "iphone-map-sensors-$mode" 1
  shoot "iphone-map-zone-$mode" 1 -shotZone gandhi-nagar -shotSheet zone
  shoot "iphone-search-$mode" 2
  shoot "iphone-settings-$mode" 3
  shoot "iphone-settings-bottom-$mode" 3 -shotScroll bottom
  shoot "iphone-data-sources-$mode" 3 -shotScreen dataSources
}

case "$device" in
  iphone)
    UDID=$(pick_device "iPhone 18 Pro Max" "iPhone 17 Pro Max" "iPhone")
    ;;
  ipad)
    UDID=$(pick_device "iPad Pro 13" "iPad Air 13" "iPad Pro" "iPad")
    ;;
  *)
    echo "Unknown device $device"
    exit 1
    ;;
esac

if [ -z "$UDID" ]; then
  echo "No simulator found for $device"
  exit 1
fi

xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID"
xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState charged --batteryLevel 100 || true
xcrun simctl install "$UDID" "$app_path"
seed_prefs
MARKER="$(xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" data)/tmp/shot-ready"

case "$device" in
  iphone)
    appearance light
    iphone_set light
    appearance dark
    iphone_set dark
    xcrun simctl ui "$UDID" content_size accessibility-extra-large
    shoot iphone-home-dark-largetext 0 -shotZone gandhi-nagar
    xcrun simctl ui "$UDID" content_size large
    ;;
  ipad)
    appearance light
    shoot ipad-home-light 0 -shotZone gandhi-nagar
    shoot ipad-map-light 1
    shoot ipad-search-light 2
    shoot ipad-settings-light 3
    appearance dark
    shoot ipad-home-dark 0 -shotZone gandhi-nagar
    shoot ipad-search-dark 2
    ;;
esac

xcrun simctl shutdown "$UDID"
