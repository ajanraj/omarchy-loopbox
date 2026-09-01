#!/usr/bin/env bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
launcher="$script_dir/../scripts/launcher"
test_root=$(mktemp -d)
export HOME="$test_root/home"
export XDG_DATA_HOME="$test_root/data"
destination="$XDG_DATA_HOME/applications/io.github.ajanraj.loopbox.desktop"

cleanup() {
    rm -rf -- "$test_root"
}
trap cleanup EXIT

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

install_output=$("$launcher" install)
[[ $install_output == 'Loopbox is now available in the Omarchy menu.' ]] || fail 'install must return a bounded confirmation without reflecting a filesystem path'
desktop-file-validate "$destination"
grep -Fx 'Exec=omarchy-shell shell toggle io.github.ajanraj.loopbox' "$destination" >/dev/null || fail 'launcher must use the fixed Loopbox IPC command'
grep -Fx 'GenericName=GIF Search' "$destination" >/dev/null || fail 'launcher must be searchable as GIF Search'
grep -F 'Keywords=gif;' "$destination" >/dev/null || fail 'launcher must be searchable by the gif keyword'
[[ $("$launcher" status | jq -r '.installed') == true ]] || fail 'installed launcher must report its status'
[[ $("$launcher" status | jq 'keys == ["installed"]') == true ]] || fail 'launcher status must not reflect a user-controlled path into QML'

"$launcher" install >/dev/null
"$launcher" remove >/dev/null
[[ ! -e $destination ]] || fail 'remove must delete the managed launcher'

mkdir -p -- "$(dirname -- "$destination")"
printf '%s\n' '[Desktop Entry]' 'Name=Personal Loopbox' >"$destination"
if "$launcher" install >"$test_root/unmanaged.stdout" 2>"$test_root/unmanaged.stderr"; then
    fail 'install must refuse an unmanaged desktop entry'
fi
grep -F 'not managed by Loopbox' "$test_root/unmanaged.stderr" >/dev/null || fail 'unmanaged refusal must explain recovery'

rm -- "$destination"
printf 'do not change\n' >"$test_root/symlink-target"
ln -s -- "$test_root/symlink-target" "$destination"
if "$launcher" install >"$test_root/symlink.stdout" 2>"$test_root/symlink.stderr"; then
    fail 'install must refuse a symlinked desktop entry'
fi
[[ $(<"$test_root/symlink-target") == 'do not change' ]] || fail 'launcher must not alter a symlink target'

printf 'PASS: desktop launcher install contract\n'
