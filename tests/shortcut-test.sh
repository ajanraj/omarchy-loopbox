#!/usr/bin/env bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
shortcut_helper="$script_dir/../scripts/shortcut"
test_root=$(mktemp -d)
fake_hyprctl="$test_root/hyprctl"
bindings_file="$test_root/hypr/bindings.lua"
shortcut_file="$test_root/hypr/loopbox.lua"
binds_file="$test_root/binds.json"
reload_log="$test_root/reloads"

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

assert_contains() {
    local needle=$1
    local file=$2
    local message=$3
    grep -F -- "$needle" "$file" >/dev/null || fail "$message"
}

run_failure() {
    local stdout_file=$1
    local stderr_file=$2
    shift 2
    set +e
    "$shortcut_helper" "$@" >"$stdout_file" 2>"$stderr_file"
    RUN_STATUS=$?
    set -e
}

mkdir -p -- "$(dirname -- "$bindings_file")"
printf '%s\n' '-- personal bindings' >"$bindings_file"
printf '%s\n' '[]' >"$binds_file"

cat >"$fake_hyprctl" <<'HYPRCTL'
#!/usr/bin/env bash
set -euo pipefail

case ${1:-} in
    binds)
        [[ ${2:-} == '-j' ]] || exit 64
        cat -- "$FAKE_BINDS_FILE"
        ;;
    reload)
        printf 'reload\n' >>"$FAKE_RELOAD_LOG"
        if [[ ${FAKE_RELOAD_MODE:-ok} == pause ]]; then
            : >"$FAKE_RELOAD_MARKER"
            sleep 0.3
            exit 0
        fi
        [[ ${FAKE_RELOAD_MODE:-ok} == ok ]]
        ;;
    configerrors)
        if [[ ${FAKE_CONFIG_ERROR_MODE:-none} == new-error && -f $LOOPBOX_SHORTCUT_FILE ]]; then
            printf 'loopbox.lua: simulated error\n'
        elif [[ ${FAKE_CONFIG_ERROR_MODE:-none} == existing ]]; then
            printf 'unrelated existing error\n'
        fi
        ;;
    *)
        exit 64
        ;;
esac
HYPRCTL
chmod +x -- "$fake_hyprctl"

export HOME="$test_root/home"
export XDG_STATE_HOME="$test_root/state"
export LOOPBOX_HYPRCTL="$fake_hyprctl"
export LOOPBOX_BINDINGS_FILE="$bindings_file"
export LOOPBOX_SHORTCUT_FILE="$shortcut_file"
export FAKE_BINDS_FILE="$binds_file"
export FAKE_RELOAD_LOG="$reload_log"

free_status=$("$shortcut_helper" status 'SUPER + CTRL + SHIFT + L')
assert_eq true "$(jq -r '.available' <<<"$free_status")" 'unused shortcut must be available'
assert_eq false "$(jq -r '.configured' <<<"$free_status")" 'fresh install must not be configured'

arbitrary_status=$("$shortcut_helper" status 'alt + ctrl + space')
assert_eq 'CTRL + ALT + Space' "$(jq -r '.shortcut' <<<"$arbitrary_status")" 'modifier order and named keys must be canonicalized'
assert_eq true "$(jq -r '.available' <<<"$arbitrary_status")" 'an unused arbitrary chord must be available'

function_status=$("$shortcut_helper" status 'F12')
assert_eq 'F12' "$(jq -r '.shortcut' <<<"$function_status")" 'an unmodified function key must be supported'

keypad_status=$("$shortcut_helper" status 'SUPER + kp_3')
assert_eq 'SUPER + KP_3' "$(jq -r '.shortcut' <<<"$keypad_status")" 'keypad keys must be canonicalized'

printf '%s\n' '[{"submap":"","modmask":12,"key":"Space","description":"Window action"}]' >"$binds_file"
arbitrary_occupied=$("$shortcut_helper" status 'CTRL + ALT + Space')
assert_eq false "$(jq -r '.available' <<<"$arbitrary_occupied")" 'collision checks must use the recorded modifier mask'
assert_eq 'Window action' "$(jq -r '.conflict' <<<"$arbitrary_occupied")" 'arbitrary chord conflicts must name the existing action'

printf '%s\n' '[{"submap":"","modmask":69,"key":"L","description":"Lock notes"}]' >"$binds_file"
occupied_status=$("$shortcut_helper" status 'SUPER + CTRL + SHIFT + L')
assert_eq false "$(jq -r '.available' <<<"$occupied_status")" 'occupied shortcut must not be available'
assert_eq 'Lock notes' "$(jq -r '.conflict' <<<"$occupied_status")" 'status must name the conflicting action'

printf '%s\n' '[{"submap":"","modmask":69,"key":"L","description":"","arg":"custom launcher"}]' >"$binds_file"
unnamed_status=$("$shortcut_helper" status 'SUPER + CTRL + SHIFT + L')
assert_eq 'custom launcher' "$(jq -r '.conflict' <<<"$unnamed_status")" 'empty descriptions must fall back to the binding argument'
run_failure "$test_root/unnamed-install.stdout" "$test_root/unnamed-install.stderr" install 'SUPER + CTRL + SHIFT + L'
(( RUN_STATUS != 0 )) || fail 'install must recheck unnamed collisions'
assert_contains 'custom launcher already uses' "$test_root/unnamed-install.stderr" 'install-time collisions must name the binding argument'

printf '%s\n' '[{"submap":"","modmask":69,"key":"L","description":"Loopbox"}]' >"$binds_file"
unowned_loopbox_status=$("$shortcut_helper" status 'SUPER + CTRL + SHIFT + L')
assert_eq false "$(jq -r '.configured' <<<"$unowned_loopbox_status")" 'an unowned binding named Loopbox must not count as configured'
assert_eq false "$(jq -r '.available' <<<"$unowned_loopbox_status")" 'an unowned binding named Loopbox must still count as a collision'

run_failure "$test_root/invalid-modifier.stdout" "$test_root/invalid-modifier.stderr" status 'SUPER + HYPER + L'
(( RUN_STATUS != 0 )) || fail 'an unknown modifier must be rejected'
assert_contains 'unsupported modifier' "$test_root/invalid-modifier.stderr" 'invalid modifiers must explain the supported set'

run_failure "$test_root/duplicate-modifier.stdout" "$test_root/duplicate-modifier.stderr" status 'CTRL + CTRL + K'
(( RUN_STATUS != 0 )) || fail 'a duplicate modifier must be rejected'
assert_contains 'appears more than once' "$test_root/duplicate-modifier.stderr" 'duplicate modifiers must have a useful error'

run_failure "$test_root/modifier-only.stdout" "$test_root/modifier-only.stderr" status 'SUPER + CTRL'
(( RUN_STATUS != 0 )) || fail 'a modifier-only chord must be rejected'
assert_contains 'non-modifier key' "$test_root/modifier-only.stderr" 'modifier-only chords must explain what is missing'

original_bindings=$(<"$bindings_file")
run_failure "$test_root/injection.stdout" "$test_root/injection.stderr" install 'SUPER + K\"), o.exec("bad") --'
(( RUN_STATUS != 0 )) || fail 'Lua metacharacters must be rejected'
assert_eq "$original_bindings" "$(<"$bindings_file")" 'rejected shortcut text must not modify bindings.lua'
[[ ! -e $shortcut_file ]] || fail 'rejected shortcut text must not create loopbox.lua'

run_failure "$test_root/control.stdout" "$test_root/control.stderr" status $'SUPER +\nCTRL + K'
(( RUN_STATUS != 0 )) || fail 'control characters must be rejected'
assert_contains 'control characters' "$test_root/control.stderr" 'control-character rejection must be explicit'

printf '%s\n' '[{"submap":"","modmask":69,"key":"L","description":"Lock notes"}]' >"$binds_file"
original_bindings=$(<"$bindings_file")
run_failure "$test_root/collision.stdout" "$test_root/collision.stderr" install 'SUPER + CTRL + SHIFT + L'
(( RUN_STATUS != 0 )) || fail 'install must refuse an occupied shortcut'
assert_eq "$original_bindings" "$(<"$bindings_file")" 'collision refusal must preserve bindings.lua'
[[ ! -e $shortcut_file ]] || fail 'collision refusal must not create loopbox.lua'

printf '%s\n' '-- user binding' 'require("hypr.loopbox")' >"$bindings_file"
printf '%s\n' '[]' >"$binds_file"
run_failure "$test_root/user-require.stdout" "$test_root/user-require.stderr" install 'SUPER + CTRL + SHIFT + L'
(( RUN_STATUS != 0 )) || fail 'setup must not claim an unmarked user require line'
assert_contains 'outside Loopbox' "$test_root/user-require.stderr" 'user-owned require conflict must explain recovery'
[[ ! -e $shortcut_file ]] || fail 'user-owned require conflict must not create loopbox.lua'
printf '%s\n' '-- personal bindings' >"$bindings_file"

printf '%s\n' '-- user-owned loopbox module' >"$shortcut_file"
printf '%s\n' '[]' >"$binds_file"
run_failure "$test_root/user-module.stdout" "$test_root/user-module.stderr" install 'SUPER + CTRL + SHIFT + L'
(( RUN_STATUS != 0 )) || fail 'setup must refuse a user-owned loopbox.lua'
assert_eq '-- user-owned loopbox module' "$(<"$shortcut_file")" 'setup must preserve a user-owned loopbox.lua'
assert_contains 'not managed by Loopbox' "$test_root/user-module.stderr" 'user-owned module conflict must explain recovery'
rm -f -- "$shortcut_file"

printf '%s\n' '[]' >"$binds_file"
install_result=$("$shortcut_helper" install 'SUPER + CTRL + SHIFT + L')
assert_eq true "$(jq -r '.installed' <<<"$install_result")" 'free shortcut must install'
assert_eq false "$(jq -r '.alreadyConfigured' <<<"$install_result")" 'first install must not report an existing setup'
assert_contains 'o.bind("SUPER + CTRL + SHIFT + L", "Loopbox"' "$shortcut_file" 'managed Lua file must contain the selected shortcut'
assert_contains 'require("hypr.loopbox")' "$bindings_file" 'bindings.lua must load the managed shortcut file'
assert_eq 1 "$(grep -Fc 'require("hypr.loopbox")' "$bindings_file")" 'managed require must appear once'

printf '%s\n' '[{"submap":"","modmask":69,"key":"L","description":"Loopbox"}]' >"$binds_file"
configured_status=$("$shortcut_helper" status 'SUPER + CTRL + SHIFT + J')
assert_eq true "$(jq -r '.configured' <<<"$configured_status")" 'a live Loopbox binding must skip onboarding'
assert_eq 'SUPER + CTRL + SHIFT + L' "$(jq -r '.currentShortcut' <<<"$configured_status")" 'status must report the active managed shortcut'
assert_eq true "$(jq -r '.available' <<<"$configured_status")" 'a free replacement chord must be available while Loopbox is configured'
arbitrary_rebind=$("$shortcut_helper" install 'CTRL + ALT + Space')
assert_eq false "$(jq -r '.alreadyConfigured' <<<"$arbitrary_rebind")" 'a different arbitrary chord must rebind Loopbox'
assert_eq 'CTRL + ALT + Space' "$(jq -r '.shortcut' <<<"$arbitrary_rebind")" 'install must return the canonical chord'
assert_contains 'o.bind("CTRL + ALT + Space", "Loopbox"' "$shortcut_file" 'the managed Lua file must support arbitrary chords'

printf '%s\n' '[{"submap":"","modmask":12,"key":"space","description":"Loopbox"}]' >"$binds_file"
arbitrary_configured=$("$shortcut_helper" status 'SUPER + CTRL + SHIFT + J')
assert_eq 'CTRL + ALT + Space' "$(jq -r '.currentShortcut' <<<"$arbitrary_configured")" 'status must reconstruct arbitrary managed chords'

rebind_result=$("$shortcut_helper" install 'SUPER + CTRL + SHIFT + J')
assert_eq false "$(jq -r '.alreadyConfigured' <<<"$rebind_result")" 'a different free chord must rebind Loopbox'
assert_contains 'o.bind("SUPER + CTRL + SHIFT + J", "Loopbox"' "$shortcut_file" 'rebinding must replace the managed chord'
assert_eq 1 "$(grep -Fc 'require("hypr.loopbox")' "$bindings_file")" 'rebinding must not duplicate the managed require'

printf '%s\n' '[{"submap":"","modmask":69,"key":"J","description":"Loopbox"}]' >"$binds_file"
repeat_result=$("$shortcut_helper" install 'SUPER + CTRL + SHIFT + J')
assert_eq true "$(jq -r '.alreadyConfigured' <<<"$repeat_result")" 'installing the active chord must be idempotent'

printf '%s\n' '[{"submap":"","modmask":69,"key":"J","description":"Loopbox"},{"submap":"","modmask":69,"key":"U","description":"Notes"}]' >"$binds_file"
current_shortcut_contents=$(<"$shortcut_file")
run_failure "$test_root/rebind-collision.stdout" "$test_root/rebind-collision.stderr" install 'SUPER + CTRL + SHIFT + U'
(( RUN_STATUS != 0 )) || fail 'rebinding must refuse an occupied chord'
assert_eq "$current_shortcut_contents" "$(<"$shortcut_file")" 'a rebind collision must preserve the active shortcut'
assert_contains 'Notes already uses' "$test_root/rebind-collision.stderr" 'a rebind collision must name the existing action'

printf '%s\n' '[]' >"$binds_file"
remove_result=$("$shortcut_helper" remove)
assert_eq true "$(jq -r '.removed' <<<"$remove_result")" 'managed shortcut must be removable'
[[ ! -e $shortcut_file ]] || fail 'removal must delete the managed shortcut file'
if grep -F 'LOOPBOX SHORTCUT SETUP' "$bindings_file" >/dev/null; then
    fail 'removal must delete the managed bindings.lua block'
fi
assert_contains '-- personal bindings' "$bindings_file" 'removal must preserve personal bindings'

printf '%s\n' '-- user-owned loopbox module' >"$shortcut_file"
run_failure "$test_root/remove-user-module.stdout" "$test_root/remove-user-module.stderr" remove
(( RUN_STATUS != 0 )) || fail 'removal must refuse a user-owned loopbox.lua'
assert_eq '-- user-owned loopbox module' "$(<"$shortcut_file")" 'removal must preserve a user-owned loopbox.lua'
rm -f -- "$shortcut_file"

"$shortcut_helper" skip >"$test_root/skip.stdout"
skipped_status=$("$shortcut_helper" status 'SUPER + CTRL + SHIFT + L')
assert_eq true "$(jq -r '.skipped' <<<"$skipped_status")" 'declining setup must suppress future prompts'
forced_status=$("$shortcut_helper" status 'SUPER + CTRL + SHIFT + L' --force)
assert_eq false "$(jq -r '.skipped' <<<"$forced_status")" 'forced setup from the bar must ignore the declined marker'

skip_file="$XDG_STATE_HOME/loopbox/shortcut-setup-skipped"
skip_target="$test_root/shortcut-marker-target"
printf '%s\n' 'do not change' >"$skip_target"
rm -f -- "$skip_file"
ln -s -- "$skip_target" "$skip_file"
run_failure "$test_root/unsafe-marker-status.stdout" "$test_root/unsafe-marker-status.stderr" status 'SUPER + CTRL + SHIFT + L'
(( RUN_STATUS != 0 )) || fail 'status must reject a symlinked declined marker'
assert_contains 'must not be a symlink' "$test_root/unsafe-marker-status.stderr" 'unsafe marker status must explain recovery'
run_failure "$test_root/unsafe-marker-skip.stdout" "$test_root/unsafe-marker-skip.stderr" skip
(( RUN_STATUS != 0 )) || fail 'skip must reject a symlinked declined marker'
assert_eq 'do not change' "$(<"$skip_target")" 'shortcut marker symlink target must remain unchanged'

printf '%s\n' '[]' >"$binds_file"
printf '%s\n' '-- clean config before reload failure' >"$bindings_file"
rm -f -- "$shortcut_file"
FAKE_RELOAD_MODE=fail run_failure "$test_root/reload.stdout" "$test_root/reload.stderr" install 'SUPER + CTRL + SHIFT + J'
(( RUN_STATUS != 0 )) || fail 'reload failure must fail setup'
assert_eq '-- clean config before reload failure' "$(<"$bindings_file")" 'reload failure must restore bindings.lua'
[[ ! -e $shortcut_file ]] || fail 'reload failure must remove the new managed file'
assert_contains 'previous configuration was restored' "$test_root/reload.stderr" 'reload failure must explain rollback'
if find "$(dirname -- "$bindings_file")" -maxdepth 1 -name '.loopbox-*' -print -quit | grep -q .; then
    fail 'failed setup must clean temporary config files'
fi

printf '%s\n' '-- clean config before config error' >"$bindings_file"
FAKE_CONFIG_ERROR_MODE=new-error run_failure "$test_root/config-error.stdout" "$test_root/config-error.stderr" install 'SUPER + CTRL + SHIFT + U'
(( RUN_STATUS != 0 )) || fail 'new Hyprland config error must fail setup'
assert_eq '-- clean config before config error' "$(<"$bindings_file")" 'config error must restore bindings.lua'
[[ ! -e $shortcut_file ]] || fail 'config error must remove the new managed file'
assert_contains 'new configuration error' "$test_root/config-error.stderr" 'config error must explain rollback'

printf '%s\n' '-- clean config before termination' >"$bindings_file"
termination_marker="$test_root/reload-started"
FAKE_RELOAD_MODE=pause FAKE_RELOAD_MARKER="$termination_marker" \
    "$shortcut_helper" install 'SUPER + CTRL + SHIFT + M' \
    >"$test_root/termination.stdout" 2>"$test_root/termination.stderr" &
termination_pid=$!
for _ in $(seq 1 100); do
    [[ -e $termination_marker ]] && break
    sleep 0.01
done
[[ -e $termination_marker ]] || fail 'termination test did not reach Hyprland reload'
kill -TERM "$termination_pid"
set +e
wait "$termination_pid"
termination_status=$?
set -e
assert_eq 130 "$termination_status" 'terminated setup must report signal cancellation'
assert_eq '-- clean config before termination' "$(<"$bindings_file")" 'termination must restore bindings.lua'
[[ ! -e $shortcut_file ]] || fail 'termination must remove the partially installed managed file'
if find "$(dirname -- "$bindings_file")" -maxdepth 1 -name '.loopbox-*' -print -quit | grep -q .; then
    fail 'terminated setup must clean temporary config files'
fi

printf 'PASS: shortcut setup contract\n'
