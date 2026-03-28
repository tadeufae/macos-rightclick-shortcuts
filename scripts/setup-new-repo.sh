#!/bin/zsh

set -euo pipefail

readonly SCRIPT_DIR=${0:A:h}
readonly APP_SUPPORT_DIR="$SCRIPT_DIR:h"
readonly BASELINE_DIR="$APP_SUPPORT_DIR/repo-baseline"
readonly POPUP_TITLE="Utilz: Setup New Repo"

is_cli_mode() {
  [[ -t 0 || -t 1 ]]
}

escape_applescript_string() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  print -r -- "$value"
}

show_error() {
  local message="$1"
  if is_cli_mode; then
    print -u2 -- "$message"
  else
    message="$(escape_applescript_string "$message")"
    osascript -e "display dialog \"$message\" buttons {\"OK\"} default button \"OK\" with title \"$POPUP_TITLE\"" >/dev/null 2>&1 || true
  fi
}

show_success() {
  local message="$1"
  if is_cli_mode; then
    print -- "$message"
  else
    message="$(escape_applescript_string "$message")"
    osascript -e "display dialog \"$message\" buttons {\"OK\"} default button \"OK\" with title \"$POPUP_TITLE\"" >/dev/null 2>&1 || true
  fi
}

prompt_repo_name() {
  local default_name="$1"
  local response

  if is_cli_mode; then
    printf 'New repo name [%s]: ' "$default_name" >&2
    IFS= read -r response || return 1
    if [[ -z "$response" ]]; then
      response="$default_name"
    fi
  else
    response="$(osascript <<EOF
text returned of (display dialog "New repo name:" default answer "$default_name" buttons {"Cancel", "Create"} default button "Create" with title "$POPUP_TITLE")
EOF
)" || return 1
  fi

  print -r -- "$response"
}

sanitize_repo_name() {
  local raw_name="$1"
  local sanitized="${raw_name#"${raw_name%%[![:space:]]*}"}"
  sanitized="${sanitized%"${sanitized##*[![:space:]]}"}"
  print -r -- "$sanitized"
}

replace_placeholders() {
  local repo_dir="$1"
  local repo_name="$2"
  local author_name="$3"
  local year="$4"

  perl -0pi -e "s|__REPO_NAME__|$repo_name|g; s|__AUTHOR_NAME__|$author_name|g; s|__YEAR__|$year|g" \
    "$repo_dir/README.md" \
    "$repo_dir/LICENSE"
}

ensure_baseline_present() {
  if [[ ! -d "$BASELINE_DIR" ]]; then
    show_error "Repo baseline templates are missing from App Support."
    exit 1
  fi
}

create_repo_from_baseline() {
  local parent_dir="$1"
  local repo_name="$2"
  local repo_dir="$parent_dir/$repo_name"
  local author_name
  local year

  if [[ ! -d "$parent_dir" ]]; then
    show_error "Selected folder is not available."
    exit 1
  fi

  if [[ -e "$repo_dir" ]]; then
    show_error "A folder named \"$repo_name\" already exists here."
    exit 1
  fi

  mkdir -p "$repo_dir"
  ditto "$BASELINE_DIR" "$repo_dir"

  author_name="$(git config --global user.name 2>/dev/null || true)"
  if [[ -z "$author_name" ]]; then
    author_name="Your Name"
  fi

  year="$(date +%Y)"

  replace_placeholders "$repo_dir" "$repo_name" "$author_name" "$year"

  chmod +x \
    "$repo_dir/.githooks/pre-commit" \
    "$repo_dir/scripts/deploy.sh" \
    "$repo_dir/scripts/install-git-hooks.sh" \
    "$repo_dir/scripts/test.sh"

  git -C "$repo_dir" init -b main >/dev/null
  zsh "$repo_dir/scripts/install-git-hooks.sh" >/dev/null

  show_success "Created \"$repo_name\" in $(basename "$parent_dir")."
}

resolve_target() {
  local parent_dir=""
  local repo_name=""

  case $# in
    0)
      parent_dir="$PWD"
      repo_name="$(prompt_repo_name "new-repo")" || exit 0
      ;;
    1)
      if [[ -d "$1" ]]; then
        parent_dir="$1"
        repo_name="$(prompt_repo_name "new-repo")" || exit 0
      else
        parent_dir="$PWD"
        repo_name="$1"
      fi
      ;;
    *)
      parent_dir="$1"
      repo_name="$2"
      ;;
  esac

  repo_name="$(sanitize_repo_name "$repo_name")"

  if [[ -z "$repo_name" ]]; then
    show_error "Repo name cannot be empty."
    exit 1
  fi

  print -r -- "$parent_dir"
  print -r -- "$repo_name"
}

main() {
  local resolved
  local parent_dir
  local repo_name

  ensure_baseline_present

  resolved=("${(@f)$(resolve_target "$@")}")
  parent_dir="${resolved[1]}"
  repo_name="${resolved[2]}"

  create_repo_from_baseline "$parent_dir" "$repo_name"
}

main "$@"
