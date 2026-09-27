#!/bin/bash
# Ad-hoc signs a built Salawaty.app while keeping its entitlements.
#
# `codesign --deep --sign -` drops every entitlement, which leaves the widget unable to
# read the app's data. Instead, sign the widget first, then the app, each with its own
# entitlements. Ad-hoc builds have no Team ID, so the App Group entry is removed; the
# widget reaches the app's data through its shared-preference exception instead.
set -euo pipefail

APP="${1:?usage: adhoc-sign.sh path/to/Salawaty.app}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

strip_group() {
    cp "$1" "$2"
    /usr/libexec/PlistBuddy -c "Delete :com.apple.security.application-groups" "$2" 2>/dev/null || true
}

strip_group "$ROOT/Widgets/SalawatyWidgets.entitlements" "$TMP/widgets.entitlements"
strip_group "$ROOT/Sources/Salawaty.entitlements" "$TMP/app.entitlements"

codesign --force --sign - --entitlements "$TMP/widgets.entitlements" \
    "$APP/Contents/PlugIns/SalawatyWidgets.appex"
codesign --force --sign - --entitlements "$TMP/app.entitlements" "$APP"
codesign --verify --deep --strict "$APP"
