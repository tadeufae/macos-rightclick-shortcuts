#!/bin/zsh

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)

run_check() {
  local description="$1"
  shift

  echo "==> $description"
  "$@"
  echo "PASS: $description"
  echo
}

cd "$ROOT_DIR"

echo "Running project checks from: $ROOT_DIR"
echo

run_check "Shell syntax: convert-image-to-jpg.sh" zsh -n scripts/convert-image-to-jpg.sh
run_check "Shell syntax: install.sh" zsh -n scripts/install.sh
run_check "Shell syntax: uninstall.sh" zsh -n scripts/uninstall.sh

run_check "Plist validation: workflow Info.plist" \
  plutil -lint templates/Convert\ to\ JPG.workflow/Contents/Info.plist
run_check "Plist validation: workflow document.wflow" \
  plutil -lint templates/Convert\ to\ JPG.workflow/Contents/Resources/document.wflow

run_check "Embedded self-tests: convert-image-to-jpg.sh" \
  zsh scripts/convert-image-to-jpg.sh --self-test

echo "All tests/checks passed."
