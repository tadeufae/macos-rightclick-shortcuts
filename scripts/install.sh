#!/bin/zsh

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
APP_SUPPORT_DIR="$HOME/Library/Application Support/MacOS Right Click Shortcuts"
SERVICES_DIR="$HOME/Library/Services"
WORKFLOW_TEMPLATE_NAME="Convert to JPG.workflow"
WORKFLOW_NAME="Utilz - Convert to JPG.workflow"
LEGACY_WORKFLOW_NAME="Convert to JPG.workflow"
WORKFLOW_TARGET="$SERVICES_DIR/$WORKFLOW_NAME"
LEGACY_WORKFLOW_TARGET="$SERVICES_DIR/$LEGACY_WORKFLOW_NAME"
HELPER_NAME="convert-image-to-jpg.sh"
LEGACY_HELPER_NAME="convert-heic-to-jpg.sh"
HELPER_TARGET="$APP_SUPPORT_DIR/$HELPER_NAME"
LEGACY_HELPER_TARGET="$APP_SUPPORT_DIR/$LEGACY_HELPER_NAME"
PBS="/System/Library/CoreServices/pbs"

if [[ ! -d "$ROOT_DIR/templates/$WORKFLOW_TEMPLATE_NAME" ]]; then
  echo "Workflow template not found: $ROOT_DIR/templates/$WORKFLOW_TEMPLATE_NAME" >&2
  exit 1
fi

WORKFLOW_TEMPLATE="$ROOT_DIR/templates/$WORKFLOW_TEMPLATE_NAME"

mkdir -p "$APP_SUPPORT_DIR" "$SERVICES_DIR"

rm -f "$LEGACY_HELPER_TARGET"
cp "$ROOT_DIR/scripts/$HELPER_NAME" "$HELPER_TARGET"
chmod +x "$HELPER_TARGET"

rm -rf "$LEGACY_WORKFLOW_TARGET" "$WORKFLOW_TARGET"
cp -R "$WORKFLOW_TEMPLATE" "$WORKFLOW_TARGET"

LC_ALL=C perl -0pi -e "s|__CONVERTER_SCRIPT__|$HELPER_TARGET|g" \
  "$WORKFLOW_TARGET/Contents/Resources/document.wflow"

if [[ -x "$PBS" ]]; then
  "$PBS" -update >/dev/null 2>&1 || true
fi

echo "Installed helper script to: $HELPER_TARGET"
echo "Installed Quick Action to: $WORKFLOW_TARGET"
echo "If Finder does not show it immediately, run: killall Finder"
