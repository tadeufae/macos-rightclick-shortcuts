#!/bin/zsh

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
APP_SUPPORT_DIR="$HOME/Library/Application Support/MacOS Right Click Shortcuts"
SERVICES_DIR="$HOME/Library/Services"
TEMPLATES_DIR="$ROOT_DIR/templates"
PBS="/System/Library/CoreServices/pbs"
USER_BIN_DIR="$HOME/.local/bin"
ZPROFILE_PATH="$HOME/.zprofile"
PATH_MARKER_BEGIN="# >>> utilz path >>>"
PATH_MARKER_END="# <<< utilz path <<<"
CLI_SETUP_TARGET="$APP_SUPPORT_DIR/setup-new-repo.sh"

typeset -a cli_command_names=(
  "setup_new_repo"
  "setup_new_repo.sh"
)

typeset -a workflow_template_names=(
  "Convert to JPG.workflow"
  "Setup New Repo.workflow"
)

typeset -A workflow_installed_names=(
  ["Convert to JPG.workflow"]="Utilz - Convert to JPG.workflow"
  ["Setup New Repo.workflow"]="Utilz - Setup New Repo.workflow"
)

typeset -A workflow_script_placeholders=(
  ["Convert to JPG.workflow"]="__CONVERTER_SCRIPT__"
  ["Setup New Repo.workflow"]="__SETUP_NEW_REPO_SCRIPT__"
)

typeset -A workflow_script_names=(
  ["Convert to JPG.workflow"]="convert-image-to-jpg.sh"
  ["Setup New Repo.workflow"]="setup-new-repo.sh"
)

typeset -a helper_script_names=(
  "convert-image-to-jpg.sh"
  "setup-new-repo.sh"
)

typeset -a legacy_workflow_names=(
  "Convert to JPG.workflow"
)

typeset -a legacy_helper_names=(
  "convert-heic-to-jpg.sh"
)

REPO_BASELINE_SOURCE="$TEMPLATES_DIR/repo-baseline"
REPO_BASELINE_TARGET="$APP_SUPPORT_DIR/repo-baseline"

install_helper_scripts() {
  local helper_name

  for helper_name in "${legacy_helper_names[@]}"; do
    rm -f "$APP_SUPPORT_DIR/$helper_name"
  done

  for helper_name in "${helper_script_names[@]}"; do
    cp "$ROOT_DIR/scripts/$helper_name" "$APP_SUPPORT_DIR/$helper_name"
    chmod +x "$APP_SUPPORT_DIR/$helper_name"
  done
}

install_repo_baseline() {
  rm -rf "$REPO_BASELINE_TARGET"
  ditto "$REPO_BASELINE_SOURCE" "$REPO_BASELINE_TARGET"
  chmod +x \
    "$REPO_BASELINE_TARGET/.githooks/pre-commit" \
    "$REPO_BASELINE_TARGET/scripts/deploy.sh" \
    "$REPO_BASELINE_TARGET/scripts/install-git-hooks.sh" \
    "$REPO_BASELINE_TARGET/scripts/test.sh"
}

install_cli_commands() {
  local command_name

  mkdir -p "$USER_BIN_DIR"

  for command_name in "${cli_command_names[@]}"; do
    cat > "$USER_BIN_DIR/$command_name" <<EOF
#!/bin/zsh
exec "$CLI_SETUP_TARGET" "\$@"
EOF
    chmod +x "$USER_BIN_DIR/$command_name"
  done
}

ensure_path_block() {
  if [[ ! -f "$ZPROFILE_PATH" ]]; then
    touch "$ZPROFILE_PATH"
  fi

  if ! grep -Fq "$PATH_MARKER_BEGIN" "$ZPROFILE_PATH"; then
    cat >> "$ZPROFILE_PATH" <<EOF

$PATH_MARKER_BEGIN
export PATH="\$HOME/.local/bin:\$PATH"
$PATH_MARKER_END
EOF
  fi
}

install_workflow() {
  local template_name="$1"
  local target_name="${workflow_installed_names[$template_name]}"
  local target_path="$SERVICES_DIR/$target_name"
  local script_placeholder="${workflow_script_placeholders[$template_name]}"
  local helper_name="${workflow_script_names[$template_name]}"
  local helper_target="$APP_SUPPORT_DIR/$helper_name"

  rm -rf "$target_path"
  cp -R "$TEMPLATES_DIR/$template_name" "$target_path"

  LC_ALL=C perl -0pi -e "s|$script_placeholder|$helper_target|g" \
    "$target_path/Contents/Resources/document.wflow"
}

main() {
  local template_name
  local legacy_workflow_name

  mkdir -p "$APP_SUPPORT_DIR" "$SERVICES_DIR"

  for template_name in "${workflow_template_names[@]}"; do
    if [[ ! -d "$TEMPLATES_DIR/$template_name" ]]; then
      echo "Workflow template not found: $TEMPLATES_DIR/$template_name" >&2
      exit 1
    fi
  done

  if [[ ! -d "$REPO_BASELINE_SOURCE" ]]; then
    echo "Repo baseline template not found: $REPO_BASELINE_SOURCE" >&2
    exit 1
  fi

  install_helper_scripts
  install_repo_baseline
  install_cli_commands
  ensure_path_block

  for legacy_workflow_name in "${legacy_workflow_names[@]}"; do
    rm -rf "$SERVICES_DIR/$legacy_workflow_name"
  done

  for template_name in "${workflow_template_names[@]}"; do
    install_workflow "$template_name"
  done

  if [[ -x "$PBS" ]]; then
    "$PBS" -update >/dev/null 2>&1 || true
  fi

  echo "Installed helper scripts to: $APP_SUPPORT_DIR"
  echo "Installed repo baseline to: $REPO_BASELINE_TARGET"
  echo "Installed CLI commands to: $USER_BIN_DIR"
  echo "Installed Quick Actions to: $SERVICES_DIR"
  echo "You can run: setup_new_repo my-new-repo"
  echo "If Finder does not show them immediately, run: killall Finder"
}

main "$@"
