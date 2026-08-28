#!/usr/bin/env bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
preview_gif="$script_dir/../scripts/preview-gif"
test_root=$(mktemp -d)
fake_bin="$test_root/bin"
cache_home="$test_root/cache"
curl_count="$test_root/curl-count"
curl_args="$test_root/curl-args"
timeout_args="$test_root/timeout-args"

cleanup() { rm -rf -- "$test_root"; }
trap cleanup EXIT
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
assert_eq() { [[ "$1" == "$2" ]] || fail "$3 (expected '$1', got '$2')"; }
assert_contains() { grep -F -- "$1" "$2" >/dev/null || fail "$3"; }

mkdir -p -- "$fake_bin"

cat >"$fake_bin/python3" <<'PYTHON'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$#" -eq 3 && "$1" == */scripts/media-url && "$2" == resolve ]]; then
    /usr/bin/python3 "$1" validate "$3"
    [[ "${FAKE_RESOLVE_MODE:-ok}" == ok ]] || exit 1
    printf 'static.klipy.com:443:8.8.8.8\n'
    exit 0
fi
exec /usr/bin/python3 "$@"
PYTHON

cat >"$fake_bin/timeout" <<'TIMEOUT'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" >>"$FAKE_TIMEOUT_ARGS"
[[ "$1" == 3s ]] || exit 64
shift
exec "$@"
TIMEOUT

cat >"$fake_bin/curl" <<'CURL'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" >>"$FAKE_CURL_ARGS"
output=''
while (($#)); do
    case "$1" in
        --output) output=$2; shift 2 ;;
        --url|--connect-timeout|--max-filesize|--max-time|--noproxy|--proto|--proto-redir|--resolve|--write-out) shift 2 ;;
        --disable|--fail|--show-error|--silent) shift ;;
        *) exit 64 ;;
    esac
done
count=0
[[ ! -f "$FAKE_CURL_COUNT" ]] || count=$(<"$FAKE_CURL_COUNT")
printf '%s\n' "$((count + 1))" >"$FAKE_CURL_COUNT"
case "${FAKE_CURL_MODE:-gif}" in
    gif) printf 'GIF89a preview payload\n' >"$output"; printf '200' ;;
    redirect) printf 'GIF89a redirect payload\n' >"$output"; printf '302' ;;
    fail) exit 22 ;;
esac
CURL
chmod +x -- "$fake_bin/python3" "$fake_bin/timeout" "$fake_bin/curl"

export PATH="$fake_bin:$PATH"
export XDG_CACHE_HOME="$cache_home"
export FAKE_CURL_COUNT="$curl_count"
export FAKE_CURL_ARGS="$curl_args"
export FAKE_TIMEOUT_ARGS="$timeout_args"

url='https://static.klipy.com/images/preview-one.gif'
path=$("$preview_gif" "$url")
[[ "$path" == "$cache_home/loopbox/previews/"*.gif ]] || fail 'preview helper must return a local cache path'
assert_eq 'GIF89a preview payload' "$(<"$path")" 'preview cache must contain validated GIF bytes'
assert_eq 1 "$(<"$curl_count")" 'first preview load must download once'
assert_eq 3s "$(head -n 1 -- "$timeout_args")" 'preview DNS resolution must be bounded to three seconds'
assert_contains '--resolve' "$curl_args" 'preview download must pin the approved DNS result'
assert_contains '--noproxy' "$curl_args" 'preview download must bypass configured proxies'
assert_contains '*' "$curl_args" 'preview download must bypass every proxy'
assert_contains '=https' "$curl_args" 'preview download must allow HTTPS only'
if grep -F -- '--location' "$curl_args" >/dev/null; then fail 'preview download must not follow redirects'; fi

cached_path=$(FAKE_RESOLVE_MODE=fail FAKE_CURL_MODE=fail "$preview_gif" "$url")
assert_eq "$path" "$cached_path" 'safe cache hits must work without DNS or network'
assert_eq 1 "$(<"$curl_count")" 'safe cache hits must not run curl'
assert_eq 4 "$(wc -l <"$timeout_args")" 'safe cache hits must happen before the DNS timeout command'

if "$preview_gif" 'https://evil.test/preview.gif' >"$test_root/unsafe.out" 2>"$test_root/unsafe.err"; then
    fail 'unsafe preview URLs must fail before cache lookup'
fi
assert_eq 1 "$(<"$curl_count")" 'unsafe preview URLs must not run curl'
assert_contains 'unsafe KLIPY preview URL' "$test_root/unsafe.err" 'unsafe preview failure must explain the accepted URL'

redirect_url='https://static.klipy.com/images/redirect.gif'
if FAKE_CURL_MODE=redirect "$preview_gif" "$redirect_url" >"$test_root/redirect.out" 2>"$test_root/redirect.err"; then
    fail 'redirect responses must not be cached'
fi
assert_contains 'HTTP 302' "$test_root/redirect.err" 'redirect failure must report the rejected status'
assert_eq 1 "$(find "$cache_home/loopbox/previews" -maxdepth 1 -type f -name '*.gif' | wc -l)" 'redirect bodies must not create cache entries'

for index in $(seq -w 1 17); do
    old="$cache_home/loopbox/previews/${index}aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.gif"
    printf 'GIF89a old preview %s\n' "$index" >"$old"
    touch -t "2000010100${index}" "$old"
done
"$preview_gif" "$url" >/dev/null
count=$(find "$cache_home/loopbox/previews" -maxdepth 1 -type f -name '*.gif' | wc -l)
((count <= 16)) || fail 'preview pruning must retain at most 16 files'
if find "$cache_home/loopbox/previews" -maxdepth 1 -type f -name '01*.gif' -print -quit | grep -q .; then
    fail 'preview pruning must remove the oldest file first'
fi

race_scripts="$test_root/race-scripts"
mkdir -p -- "$race_scripts"
cp -- "$script_dir/../scripts/preview-gif" "$script_dir/../scripts/media-url" "$race_scripts/"
cat >"$race_scripts/media-download" <<'RACE_DOWNLOAD'
#!/usr/bin/env bash
set -euo pipefail
printf 'GIF89a concurrent winner\n' >"$2"
exit 1
RACE_DOWNLOAD
chmod +x -- "$race_scripts/preview-gif" "$race_scripts/media-url" "$race_scripts/media-download"
race_path=$(XDG_CACHE_HOME="$test_root/race-cache" "$race_scripts/preview-gif" "$url" 2>"$test_root/race.err")
assert_eq 'GIF89a concurrent winner' "$(<"$race_path")" 'a same-URL winner must satisfy the losing delegate'

cat >"$fake_bin/find" <<'BROKEN_FIND'
#!/usr/bin/env bash
exit 1
BROKEN_FIND
chmod +x -- "$fake_bin/find"
if "$preview_gif" "$url" >"$test_root/find-fail.out" 2>"$test_root/find-fail.err"; then
    fail 'preview cache scan failures must not report success'
fi
assert_contains 'cannot scan the preview cache' "$test_root/find-fail.err" 'preview scan failure must explain recovery'

printf 'PASS: hardened local preview cache contract\n'
