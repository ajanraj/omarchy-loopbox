#!/usr/bin/env bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
gif_tile="$script_dir/../components/GifTile.qml"

if ! awk '
    /id: label/ { in_label = 1 }
    in_label && /textFormat:[[:space:]]*Text\.PlainText/ { plain_text = 1 }
    in_label && /^    }/ { exit plain_text ? 0 : 1 }
    END { if (!in_label || !plain_text) exit 1 }
' "$gif_tile"; then
    printf 'FAIL: provider-controlled GIF titles must use Text.PlainText\n' >&2
    exit 1
fi

qmllint "$gif_tile"
printf 'PASS: QML provider text security contract\n'
