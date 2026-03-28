#!/bin/zsh

set -euo pipefail

APP_SUPPORT_DIR="$HOME/Library/Application Support/MacOS Right Click Shortcuts"
SERVICES_DIR="$HOME/Library/Services"
WORKFLOW_NAME="Utilz - Convert to JPG.workflow"
LEGACY_WORKFLOW_NAME="Convert to JPG.workflow"
TARGET_WORKFLOW="$SERVICES_DIR/$WORKFLOW_NAME"
LEGACY_TARGET_WORKFLOW="$SERVICES_DIR/$LEGACY_WORKFLOW_NAME"
HELPER_TARGET="$APP_SUPPORT_DIR/convert-image-to-jpg.sh"
LEGACY_HELPER_TARGET="$APP_SUPPORT_DIR/convert-heic-to-jpg.sh"
PBS="/System/Library/CoreServices/pbs"

rm -f "$HELPER_TARGET" "$LEGACY_HELPER_TARGET"
rm -rf "$TARGET_WORKFLOW" "$LEGACY_TARGET_WORKFLOW" "$APP_SUPPORT_DIR"

if [[ -x "$PBS" ]]; then
  "$PBS" -update >/dev/null 2>&1 || true
fi

echo "Removed: $TARGET_WORKFLOW"
echo "Removed: $LEGACY_TARGET_WORKFLOW"
echo "Removed: $APP_SUPPORT_DIR"
