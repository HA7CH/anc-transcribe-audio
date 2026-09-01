#!/usr/bin/env bash
set -euo pipefail

skill_dir="$(cd "$(dirname "$0")/.." && pwd -P)"
helper="$skill_dir/scripts/transcribe-audio"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/transcribe-audio-test.XXXXXX")"
cleanup() {
  rm -rf "$test_dir"
}
trap cleanup EXIT INT TERM

touch "$test_dir/short.wav" "$test_dir/long.wav"

cat >"$test_dir/fake-codex-asr" <<'EOF'
#!/usr/bin/env bash
printf 'transcript:%s' "$(basename "$1")"
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

short_output="$(bash "$helper" "$test_dir/short.wav" zh)"
[[ "$short_output" == "transcript:short.wav:zh" ]]

long_output="$(bash "$helper" "$test_dir/long.wav")"
[[ "$long_output" == $'transcript:chunk-0000.wav\n\ntranscript:chunk-0001.wav\n\ntranscript:chunk-0002.wav' ]]

if bash "$helper" "$test_dir/missing.wav" >/dev/null 2>&1; then
  echo "expected a missing file to fail" >&2
  exit 1
fi

printf 'ok\n'
