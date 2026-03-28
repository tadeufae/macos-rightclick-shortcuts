#!/bin/zsh

set -euo pipefail

APP_SUPPORT_DIR="$HOME/Library/Application Support/MacOS Right Click Shortcuts"
SERVICES_DIR="$HOME/Library/Services"
PBS="/System/Library/CoreServices/pbs"
USER_BIN_DIR="$HOME/.local/bin"
ZPROFILE_PATH="$HOME/.zprofile"
PATH_MARKER_BEGIN="# >>> utilz path >>>"
PATH_MARKER_END="# <<< utilz path <<<"

typeset -a workflow_names=(
  "Utilz - Convert to JPG.workflow"
  "Utilz - Setup New Repo.workflow"
  "Convert to JPG.workflow"
)

typeset -a helper_names=(
  "convert-image-to-jpg.sh"
  "setup-new-repo.sh"
  "convert-heic-to-jpg.sh"
)

typeset -a cli_command_names=(
  "setup_new_repo"
  "setup_new_repo.sh"
)

typeset -a removed_paths=()

main() {
  local workflow_name
  local helper_name
  local cli_command_name

  for helper_name in "${helper_names[@]}"; do
    rm -f "$APP_SUPPORT_DIR/$helper_name"
    removed_paths+=("$APP_SUPPORT_DIR/$helper_name")
  done

  rm -rf "$APP_SUPPORT_DIR/repo-baseline"
  removed_paths+=("$APP_SUPPORT_DIR/repo-baseline")

  for workflow_name in "${workflow_names[@]}"; do
    rm -rf "$SERVICES_DIR/$workflow_name"
    removed_paths+=("$SERVICES_DIR/$workflow_name")
  done

  for cli_command_name in "${cli_command_names[@]}"; do
    rm -f "$USER_BIN_DIR/$cli_command_name"
    removed_paths+=("$USER_BIN_DIR/$cli_command_name")
  done

  if [[ -f "$ZPROFILE_PATH" ]] && grep -Fq "$PATH_MARKER_BEGIN" "$ZPROFILE_PATH"; then
    perl -0pi -e 's/\n?\Q'"$PATH_MARKER_BEGIN"'\E\nexport PATH="\$HOME\/\.local\/bin:\$PATH"\n\Q'"$PATH_MARKER_END"'\E\n?//g' "$ZPROFILE_PATH"
    removed_paths+=("$ZPROFILE_PATH (Utilz PATH block)")
  fi

  rmdir "$APP_SUPPORT_DIR" >/dev/null 2>&1 || true

  if [[ -x "$PBS" ]]; then
    "$PBS" -update >/dev/null 2>&1 || true
  fi

  printf 'Removed: %s\n' "${removed_paths[@]}"
}

main "$@"
