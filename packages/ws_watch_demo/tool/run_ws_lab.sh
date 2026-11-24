#!/usr/bin/env bash
set -euo pipefail

plan="${1:-all}"
device="${2:-}"
package_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

case "$plan" in
  all|smoke|settings|binding|notifications|history-data|measurement-sport|multi-device) ;;
  *)
    echo "Unknown plan '$plan'. Expected: all, smoke, settings, binding, notifications, history-data, measurement-sport, or multi-device." >&2
    exit 64
    ;;
esac

flutter_bin="${FLUTTER_BIN:-}"
if [[ -z "$flutter_bin" ]]; then
  flutter_bin="$(command -v flutter || true)"
fi
if [[ -z "$flutter_bin" || ! -x "$flutter_bin" ]]; then
  echo "Flutter was not found. Put it on PATH or set FLUTTER_BIN=/path/to/flutter." >&2
  exit 69
fi

adb_bin="${ADB_BIN:-}"
if [[ -z "$adb_bin" ]]; then
  adb_bin="$(command -v adb || true)"
fi
if [[ -z "$adb_bin" && -x "$HOME/Library/Android/sdk/platform-tools/adb" ]]; then
  adb_bin="$HOME/Library/Android/sdk/platform-tools/adb"
fi
if [[ -z "$adb_bin" || ! -x "$adb_bin" ]]; then
  echo "adb was not found. Put it on PATH or set ADB_BIN=/path/to/adb." >&2
  exit 69
fi

if [[ -z "$device" ]]; then
  devices=()
  while IFS= read -r line; do devices+=("$line"); done < <(
    "$adb_bin" devices | awk 'NR > 1 && $2 == "device" {print $1}'
  )
  if [[ "${#devices[@]}" -ne 1 ]]; then
    echo "Expected exactly one adb device, found ${#devices[@]}. Pass its serial as argument 2." >&2
    "$adb_bin" devices -l >&2
    exit 65
  fi
  device="${devices[0]}"
fi

cd "$package_dir"
exec "$flutter_bin" test integration_test/ws_demo_smoke_test.dart \
  -d "$device" \
  --dart-define="WS_LAB_PLAN=$plan"
