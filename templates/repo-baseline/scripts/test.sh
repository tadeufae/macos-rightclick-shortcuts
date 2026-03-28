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

for script_path in scripts/*.sh .githooks/pre-commit; do
  run_check "Shell syntax: $script_path" zsh -n "$script_path"
done

run_check "README presence" test -s README.md
run_check "LICENSE presence" test -s LICENSE

echo "All tests/checks passed."
