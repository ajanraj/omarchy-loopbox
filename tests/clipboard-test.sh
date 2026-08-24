#!/usr/bin/env bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
copy_gif="$script_dir/../scripts/copy-gif"
test_root=$(mktemp -d)
cache_home="$test_root/cache"
cache_dir="$cache_home/loopbox/gifs"
fake_bin="$test_root/bin"
helper="$fake_bin/fake-clipboard-helper"
curl_count_file="$test_root/curl-count"
curl_url_log="$test_root/curl-urls"
clipboard_log="$test_root/clipboard-log"
clipboard_capture="$test_root/clipboard-capture.png"
ffmpeg_count_file="$test_root/ffmpeg-count"

cleanup() {
    rm -rf -- "$test_root"
}
trap cleanup EXIT

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

assert_eq() {
    local expected=$1
    local actual=$2
    local message=$3

    [[ "$actual" == "$expected" ]] || fail "$message (expected '$expected', got '$actual')"
}

assert_file_contains() {
    local needle=$1
    local file=$2
    local message=$3

    grep -F -- "$needle" "$file" >/dev/null || fail "$message"
}

assert_file_not_contains() {
    local needle=$1
    local file=$2
    local message=$3

    if grep -F -- "$needle" "$file" >/dev/null; then
        fail "$message"
    fi
}

run_failure() {
    local stdout_file=$1
    local stderr_file=$2
    shift 2

    set +e
    "$copy_gif" "$@" >"$stdout_file" 2>"$stderr_file"
    RUN_STATUS=$?
    set -e
}

mkdir -p -- "$fake_bin" "$cache_dir"

cat >"$helper" <<'HELPER'
#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 3 || "$1" != '--copy-only' || "$2" != 'image/png' ]]; then
    printf 'unexpected clipboard arguments\n' >&2
    exit 64
fi

if [[ -n "${FAKE_LOCK_DIR:-}" ]] && ! flock -n "$FAKE_LOCK_DIR" true; then
    printf 'cache lock was inherited by the clipboard helper\n' >&2
    exit 65
fi

printf '%s|%s|%s\n' "$1" "$2" "$3" >>"$FAKE_CLIPBOARD_LOG"
if [[ "${FAKE_CLIPBOARD_MODE:-ok}" == 'fail' ]]; then
    printf 'simulated clipboard failure\n' >&2
    exit 1
fi
cp -- "$3" "$FAKE_CLIPBOARD_CAPTURE"
HELPER
chmod +x -- "$helper"

cat >"$fake_bin/ffmpeg" <<'FFMPEG'
#!/usr/bin/env bash
set -euo pipefail

output=${!#}
count=0
if [[ -f "$FAKE_FFMPEG_COUNT_FILE" ]]; then
    count=$(<"$FAKE_FFMPEG_COUNT_FILE")
fi
printf '%s\n' "$((count + 1))" >"$FAKE_FFMPEG_COUNT_FILE"

if [[ "${FAKE_FFMPEG_MODE:-ok}" == 'fail' ]]; then
    printf 'simulated conversion failure\n' >&2
    exit 1
fi

printf '\211PNG\r\n\032\n\000\000\000\010acTLfake animated payload\n' >"$output"
FFMPEG
chmod +x -- "$fake_bin/ffmpeg"

cat >"$fake_bin/curl" <<'CURL'
#!/usr/bin/env bash
set -euo pipefail

output=''
url=''
while (($#)); do
    case "$1" in
        --url)
            [[ "$#" -ge 2 ]] || exit 64
            url=$2
            shift 2
            ;;
        --output)
            [[ "$#" -ge 2 ]] || exit 64
            output=$2
            shift 2
            ;;
        --connect-timeout|--max-filesize|--max-time)
            [[ "$#" -ge 2 ]] || exit 64
            shift 2
            ;;
        --fail|--location|--show-error|--silent)
            shift
            ;;
        *)
            printf 'unexpected curl argument: %s\n' "$1" >&2
            exit 64
            ;;
    esac
done

[[ -n "$output" ]] || exit 64
printf '%s\n' "$url" >>"$FAKE_CURL_URL_LOG"

count=0
if [[ -f "$FAKE_CURL_COUNT_FILE" ]]; then
    count=$(<"$FAKE_CURL_COUNT_FILE")
fi
printf '%s\n' "$((count + 1))" >"$FAKE_CURL_COUNT_FILE"

case "${FAKE_CURL_MODE:-gif}" in
    gif)
        printf 'GIF89a test payload\n' >"$output"
        ;;
    bad)
        printf 'not a gif\n' >"$output"
        ;;
    oversize)
        printf 'GIF89a' >"$output"
        dd if=/dev/zero bs=1M count=15 >>"$output" 2>/dev/null
        printf 'x' >>"$output"
        ;;
    http-fail)
        printf 'simulated HTTP failure\n' >&2
        exit 22
        ;;
    *)
        printf 'unknown fake curl mode\n' >&2
        exit 64
        ;;
esac
CURL
chmod +x -- "$fake_bin/curl"

export PATH="$fake_bin:$PATH"
export XDG_CACHE_HOME="$cache_home"
export LOOPBOX_CLIPBOARD_HELPER="$helper"
export FAKE_CLIPBOARD_LOG="$clipboard_log"
export FAKE_CLIPBOARD_CAPTURE="$clipboard_capture"
export FAKE_CURL_COUNT_FILE="$curl_count_file"
export FAKE_CURL_URL_LOG="$curl_url_log"
export FAKE_FFMPEG_COUNT_FILE="$ffmpeg_count_file"
export FAKE_LOCK_DIR="$cache_dir"

lock_target="$test_root/lock-target"
printf 'lock target must remain unchanged\n' >"$lock_target"
ln -s -- "$lock_target" "$cache_dir/.copy-gif.lock"

success_stdout="$test_root/success.stdout"
success_stderr="$test_root/success.stderr"
test_url='https://example.invalid/-remote-url'
FAKE_CURL_MODE=gif "$copy_gif" "$test_url" klipy first >"$success_stdout" 2>"$success_stderr"
expected_path="$cache_dir/klipy-first.gif"
expected_clipboard_path="$cache_dir/klipy-first.png"
assert_eq "$expected_path" "$(<"$success_stdout")" 'success must print only the cached path'
cmp -- "$expected_clipboard_path" "$clipboard_capture" >/dev/null || fail 'clipboard helper must receive the converted APNG bytes'
assert_file_contains '--copy-only|image/png|' "$clipboard_log" 'clipboard helper must receive copy-only image/png arguments'
assert_file_contains "$expected_clipboard_path" "$clipboard_log" 'clipboard helper must receive the cached APNG path'
assert_eq "$test_url" "$(<"$curl_url_log")" 'remote URL must be passed as one --url value'
assert_eq 'lock target must remain unchanged' "$(<"$lock_target")" 'lock symlink target must not be truncated or modified'
[[ -L "$cache_dir/.copy-gif.lock" ]] || fail 'lock symlink must not be replaced'

curl_count_after_download=$(<"$curl_count_file")
ffmpeg_count_after_conversion=$(<"$ffmpeg_count_file")
FAKE_CURL_MODE=http-fail "$copy_gif" "$test_url" klipy first >"$test_root/cache-hit.stdout" 2>"$test_root/cache-hit.stderr"
assert_eq "$expected_path" "$(<"$test_root/cache-hit.stdout")" 'cache hit must still copy and print the cached path'
assert_eq "$curl_count_after_download" "$(<"$curl_count_file")" 'cache hit must not download again'
assert_eq "$ffmpeg_count_after_conversion" "$(<"$ffmpeg_count_file")" 'cache hit must not convert the GIF again'

printf 'not a png\n' >"$expected_clipboard_path"
ffmpeg_count_before_apng_repair=$(<"$ffmpeg_count_file")
FAKE_CURL_MODE=http-fail "$copy_gif" "$test_url" klipy first >"$test_root/apng-repair.stdout" 2>"$test_root/apng-repair.stderr"
assert_eq "$((ffmpeg_count_before_apng_repair + 1))" "$(<"$ffmpeg_count_file")" 'invalid APNG cache hit must be converted again'
assert_file_contains 'acTL' "$expected_clipboard_path" 'invalid APNG cache hit must be replaced with an animation'

fallback_home="$test_root/home"
mkdir -p -- "$fallback_home"
fallback_path=$(HOME="$fallback_home" XDG_CACHE_HOME= FAKE_CURL_MODE=gif "$copy_gif" "$test_url" klipy fallback)
assert_eq "$fallback_home/.cache/loopbox/gifs/klipy-fallback.gif" "$fallback_path" 'unset XDG_CACHE_HOME must use the standard HOME/.cache fallback'

FAKE_CURL_MODE=bad run_failure "$test_root/bad.stdout" "$test_root/bad.stderr" "$test_url" klipy bad
(( RUN_STATUS != 0 )) || fail 'invalid GIF magic must fail'
assert_eq '' "$(<"$test_root/bad.stdout")" 'invalid GIF magic must not report success'
assert_file_not_contains 'klipy-bad.gif' "$clipboard_log" 'invalid GIF magic must not reach the clipboard helper'
assert_file_contains 'GIF87a or GIF89a' "$test_root/bad.stderr" 'invalid GIF error must explain the accepted signatures'

count_before_unsafe=$(<"$curl_count_file")
FAKE_CURL_MODE=gif run_failure "$test_root/unsafe-provider.stdout" "$test_root/unsafe-provider.stderr" "$test_url" '../klipy' safe
(( RUN_STATUS != 0 )) || fail 'unsafe provider segment must fail'
assert_eq '' "$(<"$test_root/unsafe-provider.stdout")" 'unsafe provider must not report success'
FAKE_CURL_MODE=gif run_failure "$test_root/unsafe-id.stdout" "$test_root/unsafe-id.stderr" "$test_url" klipy 'bad/id'
(( RUN_STATUS != 0 )) || fail 'unsafe id segment must fail'
assert_eq '' "$(<"$test_root/unsafe-id.stdout")" 'unsafe id must not report success'
assert_eq "$count_before_unsafe" "$(<"$curl_count_file")" 'unsafe path segments must be rejected before downloading'
assert_file_contains 'unsafe provider segment' "$test_root/unsafe-provider.stderr" 'unsafe provider error must explain recovery'

FAKE_CURL_MODE=http-fail run_failure "$test_root/http-fail.stdout" "$test_root/http-fail.stderr" "$test_url" klipy network-failure
(( RUN_STATUS != 0 )) || fail 'HTTP/download failure must fail'
assert_eq '' "$(<"$test_root/http-fail.stdout")" 'HTTP/download failure must not report success'
assert_file_not_contains 'klipy-network-failure.gif' "$clipboard_log" 'HTTP/download failure must not reach the clipboard helper'
assert_file_contains 'download failed' "$test_root/http-fail.stderr" 'HTTP/download error must explain recovery'

FAKE_CURL_MODE=gif FAKE_FFMPEG_MODE=fail run_failure "$test_root/conversion-fail.stdout" "$test_root/conversion-fail.stderr" "$test_url" klipy conversion-failure
(( RUN_STATUS != 0 )) || fail 'APNG conversion failure must fail'
assert_eq '' "$(<"$test_root/conversion-fail.stdout")" 'APNG conversion failure must not report success'
assert_file_not_contains 'klipy-conversion-failure.png' "$clipboard_log" 'failed APNG conversion must not reach the clipboard helper'
assert_file_contains 'conversion failed or timed out' "$test_root/conversion-fail.stderr" 'APNG conversion error must explain recovery'

FAKE_CURL_MODE=oversize run_failure "$test_root/oversize.stdout" "$test_root/oversize.stderr" "$test_url" klipy too-large
(( RUN_STATUS != 0 )) || fail 'oversize download must fail'
assert_eq '' "$(<"$test_root/oversize.stdout")" 'oversize download must not report success'
assert_file_contains '15 MiB' "$test_root/oversize.stderr" 'oversize error must name the size limit'
[[ ! -e "$cache_dir/klipy-too-large.gif" ]] || fail 'oversize download must not be atomically cached'

printf 'not a gif\n' >"$cache_dir/klipy-invalid-cache.gif"
count_before_invalid_cache=$(<"$curl_count_file")
FAKE_CURL_MODE=gif "$copy_gif" "$test_url" klipy invalid-cache >"$test_root/invalid-cache.stdout" 2>"$test_root/invalid-cache.stderr"
assert_eq "$((count_before_invalid_cache + 1))" "$(<"$curl_count_file")" 'invalid cache hit must download a clean replacement'
assert_eq 'GIF89a test payload' "$(<"$cache_dir/klipy-invalid-cache.gif")" 'invalid cache hit must be replaced atomically'

count_before_bad_url=$(<"$curl_count_file")
FAKE_CURL_MODE=gif run_failure "$test_root/bad-url.stdout" "$test_root/bad-url.stderr" 'file:///tmp/local.gif' klipy local
(( RUN_STATUS != 0 )) || fail 'non-HTTP URL must fail'
assert_eq "$count_before_bad_url" "$(<"$curl_count_file")" 'non-HTTP URL must be rejected before downloading'
assert_file_contains 'http or https' "$test_root/bad-url.stderr" 'non-HTTP URL error must explain recovery'

FAKE_CURL_MODE=gif FAKE_CLIPBOARD_MODE=fail run_failure "$test_root/clipboard-fail.stdout" "$test_root/clipboard-fail.stderr" "$test_url" klipy clipboard-failure
(( RUN_STATUS != 0 )) || fail 'clipboard failure must fail'
assert_eq '' "$(<"$test_root/clipboard-fail.stdout")" 'clipboard failure must not report success'
assert_file_contains 'clipboard copy failed' "$test_root/clipboard-fail.stderr" 'clipboard error must explain recovery'

for index in $(seq -w 1 21); do
    printf 'GIF89a old payload %s\n' "$index" >"$cache_dir/klipy-old-$index.gif"
    printf '\211PNG\r\n\032\n\000\000\000\010acTLold payload %s\n' "$index" >"$cache_dir/klipy-old-$index.png"
    touch -t "2000010100${index}" "$cache_dir/klipy-old-$index.gif"
    touch -t "2000010100${index}" "$cache_dir/klipy-old-$index.png"
done
for index in $(seq -w 1 11); do
    large_file="$cache_dir/klipy-large-$index.gif"
    truncate -s 15728640 "$large_file"
    printf 'GIF89a' | dd of="$large_file" bs=1 conv=notrunc status=none
done
FAKE_CURL_MODE=gif FAKE_CLIPBOARD_MODE=ok "$copy_gif" "$test_url" klipy prune >"$test_root/prune.stdout" 2>"$test_root/prune.stderr"
gif_count=$(find "$cache_dir" -maxdepth 1 -type f -name '*.gif' -print | wc -l)
(( gif_count <= 20 )) || fail 'pruning must keep no more than 20 cached GIFs'
[[ ! -e "$cache_dir/klipy-old-01.gif" ]] || fail 'pruning must remove the oldest cached GIF first'
[[ ! -e "$cache_dir/klipy-old-01.png" ]] || fail 'pruning must remove the matching cached APNG'
[[ -e "$cache_dir/klipy-prune.gif" ]] || fail 'pruning must retain the current target'
large_count=$(find "$cache_dir" -maxdepth 1 -type f -name 'klipy-large-*.gif' -print | wc -l)
(( large_count > 0 )) || fail 'pruning should use the 150 MiB cache budget, not the 15 MiB transfer budget'
total_bytes=$(find "$cache_dir" -maxdepth 1 -type f \( -name '*.gif' -o -name '*.png' \) -printf '%s\n' | awk '{ total += $1 } END { print total + 0 }')
(( total_bytes <= 157286400 )) || fail 'pruning must keep the cache at or below 150 MiB'

printf 'PASS: clipboard helper contract\n'
