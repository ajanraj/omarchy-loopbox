# Loopbox

Loopbox is a fast keyboard-first Omarchy GIF picker and reaction GIF search plugin for Hyprland. It works as a lightweight GIF launcher and Wayland GIF clipboard: search GIFs, browse reactions and trending GIFs, then copy the image or URL without leaving the keyboard.

![Loopbox searching for a reaction GIF](preview.png)

## What it does

- Searches reaction GIFs through KLIPY with no API key or setup
- Shows trending GIFs as soon as the overlay opens
- Keeps eight animated results fast and keyboard-navigable
- Copies verified GIF data to the Wayland clipboard with Enter
- Copies the direct GIF URL with Shift+Enter when an app does not accept image data
- Saves up to 50 favourites and 20 recent selections locally

## Requirements

Loopbox targets current Omarchy 4 releases with the Quickshell-based Omarchy shell. It uses tools included with Omarchy:

- `curl` for GIF search and downloads
- `wl-clipboard` through Omarchy's `omarchy-clipboard-paste-file` helper
- Qt image format support for animated GIF previews

Network access is required for search and uncached GIF copies. No API key is required.

## Install

Install and enable Loopbox from its public repository:

```bash
omarchy plugin add https://github.com/ajanraj/omarchy-loopbox.git --enable
```

Add an optional shortcut to `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + CTRL + G", "Loopbox", "omarchy-shell shell toggle io.github.ajanraj.loopbox '{}'")
```

Check `omarchy menu keybindings --print` first and choose another combination if `Super+Ctrl+G` is already in use. Hyprland reloads the Lua configuration when it changes.

You can also open Loopbox directly:

```bash
omarchy-shell shell toggle io.github.ajanraj.loopbox '{}'
```

## Use

Open Loopbox and start typing. An empty query shows trending GIFs.

| Key | Action |
|---|---|
| Arrow keys | Move through the grid |
| Home / End | Select the first / last result |
| Enter | Copy the selected GIF as `image/gif` |
| Shift+Enter | Copy the selected GIF URL |
| Ctrl+1 | Show trending GIFs |
| Ctrl+2 | Show favourites |
| Ctrl+Shift+F | Add or remove the selected favourite |
| Ctrl+R | Retry the current search |
| Escape | Clear the query, then close Loopbox |

After Enter succeeds, Loopbox closes and the GIF is ready to paste. Paste support varies by application. If an application flattens or rejects animated image clipboard data, use Shift+Enter and paste the direct URL instead.

## Provider and privacy

Loopbox uses KLIPY results through Raycast's GIF Search proxy at `gif-search.raycast.com`. This provides install-to-search behavior without asking users for an API key. The proxy is an external, undocumented dependency with no availability guarantee, so provider failures are reported in the overlay and isolated to one adapter for future replacement.

Search queries are sent to Raycast's proxy and KLIPY. Preview and original images are fetched from the URLs returned by that service. Loopbox has no analytics and sends no favourites, recents, clipboard contents, or local files.

GIF results and content are provided by [KLIPY](https://klipy.com/). Their terms and the rights attached to individual media still apply.

## Local data

Loopbox stores only:

- Favourites and recents in `$XDG_STATE_HOME/loopbox/state.json` (default: `~/.local/state/loopbox/state.json`)
- Copied original GIFs in `$XDG_CACHE_HOME/loopbox/gifs/` (default: `~/.cache/loopbox/gifs/`)

The original GIF cache is bounded to 20 files and 150 MiB. Search responses and previews are not persisted by Loopbox.

## Troubleshooting

**Search does not load:** check network access and retry with Ctrl+R. A rate-limit or provider outage is shown without closing the overlay.

**A GIF will not paste:** confirm the target accepts `image/gif`, then use Shift+Enter to copy its URL. Loopbox keeps the overlay open when download, validation, or clipboard ownership fails.

**The shortcut does nothing:** confirm the plugin is enabled with `omarchy-shell shell listPlugins`, then run the direct toggle command above. Check Hyprland configuration errors with:

```bash
hyprctl reload
hyprctl configerrors
```

## Remove

Remove the plugin checkout and disable it:

```bash
omarchy plugin remove io.github.ajanraj.loopbox
```

Remove the Loopbox line from `~/.config/hypr/bindings.lua` if you added it. Omarchy intentionally leaves application state and cache alone. Delete these directories yourself if you also want to remove favourites, recents, and cached GIFs:

```bash
gio trash "${XDG_STATE_HOME:-$HOME/.local/state}/loopbox"
gio trash "${XDG_CACHE_HOME:-$HOME/.cache}/loopbox"
```

## Development

Run the focused checks from the repository root:

```bash
node tests/model-test.js
bash tests/clipboard-test.sh
omarchy plugin validate .
```

Loopbox runs as unsandboxed QML inside the long-running Omarchy shell. Review plugin source before enabling it, just as you would any other Omarchy plugin.

## License

[MIT](LICENSE)
