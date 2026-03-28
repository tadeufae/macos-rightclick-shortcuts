#!/bin/zsh

set -euo pipefail

typeset -grA SUPPORTED_EXTENSIONS=(
  [png]=1
  [heic]=1
  [heif]=1
  [webp]=1
  [gif]=1
  [bmp]=1
  [tif]=1
  [tiff]=1
)

typeset -grA PASSTHROUGH_EXTENSIONS=(
  [jpg]=1
  [jpeg]=1
)

readonly POPUP_TITLE="Utilz: Convert to JPG"
typeset -g SIPS_BIN="${SIPS_BIN:-sips}"
typeset -g OSASCRIPT_BIN="${OSASCRIPT_BIN:-osascript}"

typeset converted=0
typeset failed=0
typeset eligible=0
typeset passthrough=0
typeset first_failure_reason=""
typeset first_unsupported_reason=""

reset_state() {
  converted=0
  failed=0
  eligible=0
  passthrough=0
  first_failure_reason=""
  first_unsupported_reason=""
}

is_supported_extension() {
  local extension="$1"
  [[ -n "${SUPPORTED_EXTENSIONS[$extension]-}" ]]
}

is_passthrough_extension() {
  local extension="$1"
  [[ -n "${PASSTHROUGH_EXTENSIONS[$extension]-}" ]]
}

show_popup() {
  local message="$1"
  message="${message//\\/\\\\}"
  message="${message//\"/\\\"}"
  "$OSASCRIPT_BIN" -e "display dialog \"$message\" buttons {\"OK\"} default button \"OK\" with title \"$POPUP_TITLE\"" >/dev/null 2>&1 || true
}

normalize_reason() {
  local reason="$1"
  reason="${reason//$'\n'/ }"
  reason="${reason//$'\r'/ }"
  reason="$(print -r -- "$reason" | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//')"
  print -r -- "$reason"
}

unique_output_path() {
  local input_path="$1"
  local directory="${input_path:h}"
  local stem="${input_path:t:r}"
  local candidate="$directory/$stem.jpg"
  local suffix=2

  while [[ -e "$candidate" ]]; do
    candidate="$directory/$stem $suffix.jpg"
    suffix=$((suffix + 1))
  done

  print -r -- "$candidate"
}

remember_unsupported_reason() {
  local reason="$1"

  if [[ -z "$first_unsupported_reason" ]]; then
    first_unsupported_reason="$reason"
  fi
}

remember_failure_reason() {
  local reason="$1"

  if [[ -z "$reason" ]]; then
    return
  fi

  if [[ -z "$first_failure_reason" ]]; then
    first_failure_reason=" because $reason"
  fi
}

convert_file() {
  local input_path="$1"
  local output_path
  local error_file
  local error_text=""

  eligible=$((eligible + 1))
  output_path="$(unique_output_path "$input_path")"
  error_file="$(mktemp)"

  if "$SIPS_BIN" -s format jpeg "$input_path" --out "$output_path" >/dev/null 2>"$error_file"; then
    converted=$((converted + 1))
    rm -f "$error_file"
    return 0
  fi

  failed=$((failed + 1))
  error_text="$(normalize_reason "$(cat "$error_file")")"
  rm -f "$error_file"
  remember_failure_reason "$error_text"
  return 1
}

process_input() {
  local input_path="$1"
  local extension=""

  if [[ ! -f "$input_path" ]]; then
    remember_unsupported_reason "because it is not a regular file"
    return 0
  fi

  extension="${${input_path:e}:l}"

  if is_passthrough_extension "$extension"; then
    passthrough=$((passthrough + 1))
    return 0
  fi

  if ! is_supported_extension "$extension"; then
    if [[ -z "$extension" ]]; then
      remember_unsupported_reason "because it has no file extension"
    else
      remember_unsupported_reason "because .$extension is not currently supported"
    fi
    return 0
  fi

  convert_file "$input_path"
}

finalize_run() {
  local message

  if (( eligible == 0 )); then
    if (( passthrough > 0 )) && [[ -z "$first_unsupported_reason" ]]; then
      return 0
    fi

    message="Oops, I can't convert this file to JPG"
    if [[ -n "$first_unsupported_reason" ]]; then
      message+=" $first_unsupported_reason."
    else
      message+="."
    fi
    show_popup "$message"
    return 0
  fi

  if (( converted == 0 && failed > 0 )); then
    show_popup "Oops, I can't convert this file to JPG${first_failure_reason:-}."
    return 1
  fi

  return 0
}

main() {
  local input_path

  reset_state

  for input_path in "$@"; do
    process_input "$input_path"
  done

  finalize_run
}

assert_eq() {
  local actual="$1"
  local expected="$2"
  local description="$3"

  if [[ "$actual" != "$expected" ]]; then
    print -u2 -- "FAIL: $description"
    print -u2 -- "  expected: $expected"
    print -u2 -- "  actual:   $actual"
    exit 1
  fi
}

assert_file_exists() {
  local path="$1"
  local description="$2"

  if [[ ! -f "$path" ]]; then
    print -u2 -- "FAIL: $description"
    print -u2 -- "  missing file: $path"
    exit 1
  fi
}

assert_file_missing() {
  local path="$1"
  local description="$2"

  if [[ -e "$path" ]]; then
    print -u2 -- "FAIL: $description"
    print -u2 -- "  unexpected path: $path"
    exit 1
  fi
}

run_self_tests() {
  local tmp_dir bin_dir popup_log sips_log fixture_dir
  local test_png test_jpg test_svg test_tiff
  local exit_code=0

  tmp_dir="$(mktemp -d)"
  bin_dir="$tmp_dir/bin"
  popup_log="$tmp_dir/popup.log"
  sips_log="$tmp_dir/sips.log"
  fixture_dir="$tmp_dir/fixtures"

  mkdir -p "$bin_dir" "$fixture_dir"
  : >"$popup_log"
  : >"$sips_log"

  cat >"$bin_dir/osascript" <<EOF
#!/bin/zsh
print -r -- "\$*" >> "$popup_log"
EOF
  chmod +x "$bin_dir/osascript"

  cat >"$bin_dir/sips" <<EOF
#!/bin/zsh
print -r -- "\$*" >> "$sips_log"
input=""
output=""
args=( "\$@" )
index=1
while (( index <= \$#args )); do
  if [[ "\${args[index]}" == "--out" ]]; then
    (( index++ ))
    output="\${args[index]}"
  elif [[ "\${args[index]}" != "-s" && "\${args[index]}" != "format" && "\${args[index]}" != "jpeg" ]]; then
    input="\${args[index]}"
  fi
  (( index++ ))
done
if [[ "\$input" == *broken* ]]; then
  print -u2 -- "broken image data"
  exit 13
fi
print -r -- "jpeg output from \$input" > "\$output"
EOF
  chmod +x "$bin_dir/sips"

  test_png="$fixture_dir/sample.png"
  test_jpg="$fixture_dir/already.jpg"
  test_svg="$fixture_dir/vector.svg"
  test_tiff="$fixture_dir/broken.tiff"

  : >"$test_png"
  : >"$test_jpg"
  : >"$test_svg"
  : >"$test_tiff"
  : >"$fixture_dir/sample.jpg"

  PATH="$bin_dir:$PATH" SIPS_BIN="$bin_dir/sips" OSASCRIPT_BIN="$bin_dir/osascript" main "$test_png"
  assert_file_exists "$fixture_dir/sample 2.jpg" "supported images should create a unique JPG output"
  assert_eq "$(wc -l < "$popup_log" | tr -d ' ')" "0" "successful conversions should not show a popup"

  : >"$popup_log"
  PATH="$bin_dir:$PATH" SIPS_BIN="$bin_dir/sips" OSASCRIPT_BIN="$bin_dir/osascript" main "$test_jpg"
  assert_eq "$(wc -l < "$popup_log" | tr -d ' ')" "0" "jpg inputs should be ignored silently"

  : >"$popup_log"
  PATH="$bin_dir:$PATH" SIPS_BIN="$bin_dir/sips" OSASCRIPT_BIN="$bin_dir/osascript" main "$test_svg"
  assert_eq "$(wc -l < "$popup_log" | tr -d ' ')" "1" "unsupported inputs should show one popup"
  assert_eq "$(cat "$popup_log")" "-e display dialog \"Oops, I can't convert this file to JPG because .svg is not currently supported.\" buttons {\"OK\"} default button \"OK\" with title \"Utilz: Convert to JPG\"" "unsupported popup should explain the file type"

  : >"$popup_log"
  set +e
  PATH="$bin_dir:$PATH" SIPS_BIN="$bin_dir/sips" OSASCRIPT_BIN="$bin_dir/osascript" main "$test_tiff"
  exit_code=$?
  set -e
  assert_eq "$exit_code" "1" "supported files that fail conversion should return a failing status"
  assert_eq "$(cat "$popup_log")" "-e display dialog \"Oops, I can't convert this file to JPG because broken image data.\" buttons {\"OK\"} default button \"OK\" with title \"Utilz: Convert to JPG\"" "conversion failures should include the sips reason"
  assert_file_missing "$fixture_dir/broken.jpg" "failed conversions should not leave a JPG behind"

  rm -rf "$tmp_dir"
  print -- "Self-tests passed."
}

if [[ "${1-}" == "--self-test" ]]; then
  run_self_tests
  exit 0
fi

main "$@"
