#!/usr/bin/env bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
gif_tile="$script_dir/../components/GifTile.qml"
loopbox="$script_dir/../Loopbox.qml"

if ! awk '
    /id: label/ { in_label = 1 }
    in_label && /textFormat:[[:space:]]*Text\.PlainText/ { plain_text = 1 }
    in_label && /^    }/ { exit plain_text ? 0 : 1 }
    END { if (!in_label || !plain_text) exit 1 }
' "$gif_tile"; then
    printf 'FAIL: provider-controlled GIF titles must use Text.PlainText\n' >&2
    exit 1
fi

animated_source=$(awk '
    /AnimatedImage[[:space:]]*\{/ { in_image = 1 }
    in_image && /^[[:space:]]*source:/ { print; exit }
' "$gif_tile")
[[ "$animated_source" == *'tile.localPreviewPath'* ]] || {
    printf 'FAIL: AnimatedImage.source must use only the local preview cache path\n' >&2
    exit 1
}
[[ "$animated_source" != *'previewUrl'* ]] || {
    printf 'FAIL: provider preview URLs must never be assigned to AnimatedImage.source\n' >&2
    exit 1
}

grep -F 'requestSerial === tile.previewSerial' "$gif_tile" >/dev/null || {
    printf 'FAIL: preview completion must be gated by the current request serial\n' >&2
    exit 1
}
grep -F 'expectedUrl === tile.previewUrl' "$gif_tile" >/dev/null || {
    printf 'FAIL: preview completion must be gated by the current delegate URL\n' >&2
    exit 1
}
grep -F 'localPreviewPath = ""' "$gif_tile" >/dev/null || {
    printf 'FAIL: delegate reuse must clear the prior local preview\n' >&2
    exit 1
}
grep -F 'onStarted: launchPending = false' "$gif_tile" >/dev/null || {
    printf 'FAIL: preview launch tracking must observe successful process startup\n' >&2
    exit 1
}
grep -F 'if (!running && launchPending)' "$gif_tile" >/dev/null || {
    printf 'FAIL: a preview helper that fails to start must leave the loading state\n' >&2
    exit 1
}
grep -F 'previewScript: root.previewScript' "$loopbox" >/dev/null || {
    printf 'FAIL: preview delegates must receive the local preview helper\n' >&2
    exit 1
}
if grep -Eq '^[[:space:]]*(provider|resultId):[[:space:]]*model\.' "$loopbox"; then
    printf 'FAIL: ListModel roles must use required-property injection, not an undefined model object\n' >&2
    exit 1
fi
grep -F 'required property string provider' "$gif_tile" >/dev/null || {
    printf 'FAIL: preview delegates must inject the provider ListModel role\n' >&2
    exit 1
}
grep -F 'required property string resultId' "$gif_tile" >/dev/null || {
    printf 'FAIL: preview delegates must inject the resultId ListModel role\n' >&2
    exit 1
}

qmllint "$gif_tile"
printf 'PASS: QML provider text and local preview security contracts\n'
