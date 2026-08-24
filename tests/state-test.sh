#!/usr/bin/env bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
state_helper="$script_dir/../scripts/state"
test_root=$(mktemp -d)

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
    [[ $actual == "$expected" ]] || fail "$message (expected '$expected', got '$actual')"
}

assert_failure() {
    local message=$1
    shift
    if "$@" >"$test_root/failure.stdout" 2>"$test_root/failure.stderr"; then
        fail "$message"
    fi
}

export HOME="$test_root/home"
export XDG_STATE_HOME="$test_root/state"

state='{"version":1,"favorites":[{"title":"line\\nfeed"}],"recents":[]}'
printf '%s\n' "$state" | "$state_helper" save
assert_eq "$state" "$("$state_helper" load)" 'saved state must round-trip without changing escaped newlines'
assert_eq 700 "$(stat -c %a "$XDG_STATE_HOME/loopbox")" 'state directory must be private'
assert_eq 600 "$(stat -c %a "$XDG_STATE_HOME/loopbox/state.json")" 'state file must be private'

# A pre-hardening regular file remains readable and becomes private without data loss.
chmod 755 "$XDG_STATE_HOME/loopbox"
chmod 644 "$XDG_STATE_HOME/loopbox/state.json"
assert_eq "$state" "$("$state_helper" load)" 'an existing user-owned state file must migrate without data loss'
assert_eq 700 "$(stat -c %a "$XDG_STATE_HOME/loopbox")" 'existing state directory mode must be hardened'
assert_eq 600 "$(stat -c %a "$XDG_STATE_HOME/loopbox/state.json")" 'existing state file mode must be hardened'

target="$test_root/symlink-target"
printf '%s\n' 'do not change' >"$target"
rm -f -- "$XDG_STATE_HOME/loopbox/state.json"
ln -s -- "$target" "$XDG_STATE_HOME/loopbox/state.json"
assert_failure 'load must reject a state symlink' "$state_helper" load
assert_failure 'save must reject a state symlink' bash -c 'printf "%s\n" "{\"version\":1}" | "$1" save' _ "$state_helper"
assert_eq 'do not change' "$(<"$target")" 'a state symlink target must remain unchanged'

rm -f -- "$XDG_STATE_HOME/loopbox/state.json"
hardlink_target="$test_root/hardlink-target"
printf '%s\n' '{"version":1,"favorites":[],"recents":[]}' >"$hardlink_target"
chmod 644 "$hardlink_target"
ln -- "$hardlink_target" "$XDG_STATE_HOME/loopbox/state.json"
assert_failure 'load must reject a hard-linked state file' "$state_helper" load
assert_failure 'save must reject a hard-linked state file' bash -c 'printf "%s\n" "{\"version\":1}" | "$1" save' _ "$state_helper"
assert_eq 644 "$(stat -c %a "$hardlink_target")" 'hard-link rejection must not change the target mode'

rm -f -- "$XDG_STATE_HOME/loopbox/state.json"
rmdir -- "$XDG_STATE_HOME/loopbox"
real_dir="$test_root/real-loopbox"
mkdir -- "$real_dir"
ln -s -- "$real_dir" "$XDG_STATE_HOME/loopbox"
assert_failure 'load must reject a symlinked Loopbox directory' "$state_helper" load
[[ ! -e $real_dir/state.json ]] || fail 'directory symlink target must remain untouched'

rm -f -- "$XDG_STATE_HOME/loopbox"
mkdir -- "$XDG_STATE_HOME/loopbox"
mkdir -- "$XDG_STATE_HOME/loopbox/state.json"
assert_failure 'load must reject a nonregular state path' "$state_helper" load
assert_failure 'save must reject a nonregular state path' bash -c 'printf "%s\n" "{\"version\":1}" | "$1" save' _ "$state_helper"

rmdir -- "$XDG_STATE_HOME/loopbox/state.json"
dd if=/dev/zero of="$XDG_STATE_HOME/loopbox/state.json" bs=1024 count=513 status=none
assert_failure 'load must reject oversized state' "$state_helper" load

rm -f -- "$XDG_STATE_HOME/loopbox/state.json"
assert_failure 'save must reject invalid JSON' bash -c 'printf "%s\n" "not json" | "$1" save' _ "$state_helper"
"$state_helper" shortcut-skip
assert_eq true "$("$state_helper" shortcut-status)" 'shortcut marker must round-trip through the state helper'
assert_eq 600 "$(stat -c %a "$XDG_STATE_HOME/loopbox/shortcut-setup-skipped")" 'shortcut marker must be private'

printf 'PASS: hardened state storage contract\n'
