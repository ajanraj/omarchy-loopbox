# Loopbox

Loopbox is a fast keyboard-first Omarchy GIF picker and reaction GIF search plugin for Hyprland. It works as a lightweight GIF launcher and Wayland GIF clipboard: search GIFs, browse reactions and trending GIFs, then copy the image or URL without leaving the keyboard.

![Loopbox searching for a reaction GIF](preview.png)

## What it does

- Searches reaction GIFs through KLIPY with no API key or setup
- Shows trending GIFs as soon as the overlay opens
- Adds a Loopbox image icon to the Omarchy bar
- Loads scrollable results in 24-item pages, capped at 96 per search
- Copies GIFs as animated PNG clipboard data with Enter for reliable Wayland paste support
- Copies the direct GIF URL with Shift+Enter when an app does not accept image data
- Saves up to 50 favourites and 20 recent selections locally

## Requirements

Loopbox targets current Omarchy 4 releases with the Quickshell-based Omarchy shell. It uses tools included with Omarchy:

- `curl` for GIF search and downloads
- `ffmpeg` for cached GIF-to-APNG conversion before clipboard copy
- `python3`, `jq`, and `hyprctl` for media URL checks, safe local state, and shortcut setup
- Standard `coreutils` and `util-linux` tools for bounded downloads and cache coordination
- `wl-clipboard` through Omarchy's `omarchy-clipboard-paste-file` helper
- Qt image format support for animated GIF previews

Network access is required for search and uncached GIF copies. No API key is required.

## Install

Install and enable Loopbox from its public repository:

```bash
omarchy plugin add https://github.com/ajanraj/omarchy-loopbox.git --enable
```

Omarchy adds the Loopbox image icon to the right side of the bar by default. An interactive install also lets you choose the bar section. Left-click the icon to open Loopbox. If you decline a shortcut, right-click the icon to show setup later.

The first open offers `Super+Ctrl+Shift+L`. Current Omarchy defaults do not use this chord. Press Enter to accept it. Loopbox checks the live Hyprland binding table first, so custom shortcuts count too. If another action uses the default, Loopbox names the conflict and selects a free alternative. Type any letter to test `Super+Ctrl+Shift` with that key, or use Left and Right to browse suggestions, then press Enter. Loopbox never unbinds or replaces an existing action.

Omarchy's plugin installer cannot run plugin code or interactive install hooks. Shortcut choice therefore happens inside Loopbox on first launch, after installation. Press Tab to decline a shortcut and keep opening Loopbox from the bar icon. Loopbox remembers that choice; right-click the bar icon if you change your mind.

After confirmation, Loopbox writes its binding to `~/.config/hypr/loopbox.lua`, adds a small managed loader block to `~/.config/hypr/bindings.lua`, reloads Hyprland, and checks for new configuration errors. A failed reload restores both files.

You can also open Loopbox directly:

```bash
omarchy-shell shell toggle io.github.ajanraj.loopbox '{}'
```

If you update an older overlay-only Loopbox checkout, add its new widget to the existing bar layout once:

```bash
omarchy bar put io.github.ajanraj.loopbox --section right
```

## Use

Open Loopbox and start typing or paste into the already-focused search field. Its blinking cursor makes the active filter explicit; an empty query shows trending GIFs.

| Key | Action |
|---|---|
| Arrow keys | Move through the grid |
| Mouse wheel / touchpad | Scroll through results and load the next page near the end |
| Home / End | Select the first / last result |
| Enter | Copy the selected GIF as animated `image/png` |
| Shift+Enter | Copy the selected GIF URL |
| Ctrl+1 | Show trending GIFs |
| Ctrl+2 | Show favourites |
| Ctrl+Shift+F | Add or remove the selected favourite |
| Ctrl+R | Retry the current search |
| Escape | Clear the query, then close Loopbox |

During shortcut setup, type a letter to choose its `Super+Ctrl+Shift` chord. Left and Right browse suggestions, Enter confirms, Tab declines future prompts, and Escape closes Loopbox.

After Enter succeeds, Loopbox closes and the animation is ready to paste with `Super+V` or the target application's normal paste shortcut. Loopbox converts the original GIF to APNG because Chromium and Omarchy's clipboard history accept `image/png` reliably while preserving animation. If an application rejects animated image clipboard data, use Shift+Enter and paste the direct URL instead.

## Provider and privacy

Loopbox uses KLIPY results through Raycast's GIF Search proxy at `gif-search.raycast.com`. This provides install-to-search behavior without asking users for an API key. The proxy is an external, undocumented dependency with no availability guarantee, so provider failures are reported in the overlay and isolated to one adapter for future replacement.

Search queries are sent to Raycast's proxy and KLIPY. Loopbox accepts preview and original images only from KLIPY's HTTPS media host. Uncached GIFs and previews are downloaded directly from publicly routable addresses without following redirects. Loopbox has no analytics and sends no favourites, recents, clipboard contents, or local files.

GIF results and content are provided by [KLIPY](https://klipy.com/). Their terms and the rights attached to individual media still apply.

## Local data

Loopbox stores only:

- Favourites and recents in `$XDG_STATE_HOME/loopbox/state.json` (default: `~/.local/state/loopbox/state.json`)
- Copied original GIFs and their clipboard-ready APNG files in `$XDG_CACHE_HOME/loopbox/gifs/` (default: `~/.cache/loopbox/gifs/`)
- Hardened local preview GIFs in `$XDG_CACHE_HOME/loopbox/previews/` (default: `~/.cache/loopbox/previews/`)
- The confirmed shortcut in `~/.config/hypr/loopbox.lua`, loaded by a marked block in `~/.config/hypr/bindings.lua`
- A shortcut-declined marker at `$XDG_STATE_HOME/loopbox/shortcut-setup-skipped`

The copy cache is bounded to 20 GIF/APNG pairs and 150 MiB. The preview cache is bounded to 16 GIFs and 120 MiB. Search responses are limited to 24 results per page and 96 retained results per query; they are not persisted.

## Troubleshooting

**Search does not load:** check network access and retry with Ctrl+R. A rate-limit or provider outage is shown without closing the overlay.

**A GIF will not paste:** confirm `ffmpeg` and `wl-copy` are installed, then retry. Use Shift+Enter to copy the direct URL if the target rejects animated PNG clipboard data. Loopbox keeps the overlay open when download, conversion, validation, or clipboard ownership fails.

**The bar icon is missing:** confirm the plugin is enabled with `omarchy-shell shell listPlugins`, then place its widget with `omarchy bar put io.github.ajanraj.loopbox --section right`.

**The shortcut does nothing:** click the bar icon to open Loopbox, then complete shortcut setup. You can also run the direct toggle command above. Check Hyprland configuration errors with:

```bash
hyprctl reload
hyprctl configerrors
```

## Remove

Remove the managed shortcut first, while the plugin helper is still installed:

```bash
~/.config/omarchy/plugins/io.github.ajanraj.loopbox/scripts/shortcut remove
```

Then remove the plugin checkout and disable it:

```bash
omarchy plugin remove io.github.ajanraj.loopbox
```

The shortcut removal command changes only Loopbox's marked loader block and `loopbox.lua`, then reloads and validates Hyprland. Omarchy intentionally leaves application state and cache alone. Delete these directories yourself if you also want to remove favourites, recents, and cached GIFs:

```bash
gio trash "${XDG_STATE_HOME:-$HOME/.local/state}/loopbox"
gio trash "${XDG_CACHE_HOME:-$HOME/.cache}/loopbox"
```

## Development

Run the focused checks from the repository root:

```bash
node tests/model-test.js
python3 tests/media-url-test.py
bash tests/qml-security-test.sh
bash tests/clipboard-test.sh
bash tests/preview-test.sh
bash tests/state-test.sh
bash tests/shortcut-test.sh
omarchy plugin validate .
```

Loopbox runs as unsandboxed QML inside the long-running Omarchy shell. Review plugin source before enabling it, just as you would any other Omarchy plugin.

## License

[MIT](LICENSE)
