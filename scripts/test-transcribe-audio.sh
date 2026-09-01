#!/usr/bin/env bash
set -euo pipefail

skill_dir="$(cd "$(dirname "$0")/.." && pwd -P)"
helper="$skill_dir/scripts/transcribe-audio"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/anc-transcribe-audio-test.XXXXXX")"
cleanup() {
  rm -rf "$test_dir"
}
trap cleanup EXIT INT TERM

touch "$test_dir/short.wav" "$test_dir/long.wav"

cat >"$test_dir/fake-codex-asr" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
input_name="$(basename "$1")"
marker_dir="${FAKE_ASR_MARKER_DIR:?}"

if [[ "${FAKE_ASR_ALWAYS_FAIL_CHUNK:-}" == "$input_name" ]]; then
  echo "forced failure: $input_name" >&2
  exit 1
fi

if [[ "${FAKE_ASR_FAIL_ONCE_CHUNK:-}" == "$input_name" && ! -e "$marker_dir/$input_name" ]]; then
  touch "$marker_dir/$input_name"
  echo "first attempt failed: $input_name" >&2
  exit 1
fi

printf 'transcript:%s' "$input_name"
for arg in "$@"; do
  if [[ "$arg" == "zh" ]]; then
    printf ':zh'
  fi
done
printf '\n'
EOF
chmod +x "$test_dir/fake-codex-asr"

cat >"$test_dir/ffprobe" <<'EOF'
#!/usr/bin/env bash
case "${*: -1}" in
  *long.wav) printf '1201.0\n' ;;
  *) printf '5.0\n' ;;
esac
EOF
chmod +x "$test_dir/ffprobe"

cat >"$test_dir/ffmpeg" <<'EOF'
#!/usr/bin/env bash
output="${*: -1}"
touch "${output//%04d/0000}" "${output//%04d/0001}" "${output//%04d/0002}"
EOF
chmod +x "$test_dir/ffmpeg"

export PATH="$test_dir:$PATH"
export CODEX_ASR_BIN="$test_dir/fake-codex-asr"
export FAKE_ASR_MARKER_DIR="$test_dir"

short_output="$(bash "$helper" "$test_dir/short.wav" zh 2>/dev/null)"
[[ "$short_output" == "transcript:short.wav:zh" ]]

export FAKE_ASR_FAIL_ONCE_CHUNK="chunk-0001.wav"
markdown_path="$test_dir/outputs/long-transcript.md"
reported_path="$(bash "$helper" "$test_dir/long.wav" zh "$markdown_path" 2>/dev/null)"
[[ "$reported_path" == "$markdown_path" ]]
[[ -f "$markdown_path" ]]
rg -q '^# long — 原文稿$' "$markdown_path"
rg -q '^- Duration: 00:20:01$' "$markdown_path"
expected_order=$'transcript:chunk-0000.wav:zh\n\ntranscript:chunk-0001.wav:zh\n\ntranscript:chunk-0002.wav:zh'
actual_order="$(sed -n '/^## Transcript$/,$p' "$markdown_path" | tail -n +3)"
[[ "$actual_order" == "$expected_order" ]]

if bash "$helper" "$test_dir/long.wav" zh "$markdown_path" >/dev/null 2>&1; then
  echo "expected an existing output path to fail" >&2
  exit 1
fi

unset FAKE_ASR_FAIL_ONCE_CHUNK
export FAKE_ASR_ALWAYS_FAIL_CHUNK="chunk-0001.wav"
failed_path="$test_dir/outputs/failed-transcript.md"
if bash "$helper" "$test_dir/long.wav" zh "$failed_path" >/dev/null 2>&1; then
  echo "expected a failed chunk to fail the whole transcription" >&2
  exit 1
fi
[[ ! -e "$failed_path" ]]

if bash "$helper" "$test_dir/missing.wav" >/dev/null 2>&1; then
  echo "expected a missing file to fail" >&2
  exit 1
fi

printf 'ok\n'
