# Loopbox research dossier

Current as of 24 August 2026. Repository evidence uses Omarchy `quattro` commit [`7e469f9`](https://github.com/basecamp/omarchy/tree/7e469f962d33a2d68edd483d07fd9bc19dfab218), marketplace commit [`d4ce66d`](https://github.com/HANCORE-linux/omarchy-plugin-marketplace/tree/d4ce66d2384a0bf88f6db7097f2adeb62db72c41), and Raycast Extensions commit [`85b3c35`](https://github.com/raycast/extensions/tree/85b3c3527479bea53d28fc79985322812c607854).

## Executive finding

Loopbox is a GO. There is no marketplace collision, the interaction fits Omarchy unusually well, and the live provider spike returned useful `this is fine` results in under one second.

Use Raycast's KLIPY proxy for the competition MVP. Ajan explicitly approved this dependency, and a live request from outside Raycast returned HTTP 200 with the expected GIF, thumbnail, and cursor fields. The endpoint has no documented third-party contract or availability guarantee, so isolate it behind one provider module and describe it in the README. This is an accepted competition tradeoff, not a permanent infrastructure decision. [Raycast KLIPY implementation](https://github.com/raycast/extensions/blob/85b3c3527479bea53d28fc79985322812c607854/extensions/gif-search/src/models/klipy.ts), [KLIPY developer terms](https://klipy.com/developers).

The remaining gate is animated clipboard compatibility. `wl-copy --type image/gif` is the correct raw Wayland operation and matches Omarchy's own clipboard implementation. Chromium, Firefox, Discord, and Slack still need a live paste matrix before submission. Enter should nevertheless have one stable meaning: download and verify the original GIF, copy raw `image/gif` bytes, record the recent, and close only after success. Shift+Enter copies the direct GIF URL when a receiver does not accept raw GIF data. [wl-clipboard manual](https://man.archlinux.org/man/wl-copy.1.en), [`omarchy-clipboard-paste-file`](https://github.com/basecamp/omarchy/blob/7e469f962d33a2d68edd483d07fd9bc19dfab218/bin/omarchy-clipboard-paste-file), [Electron clipboard issue #23156](https://github.com/electron/electron/issues/23156).

## Competition facts

The first competition accepts every plugin submitted before Monday 24 August at 09:00 CEST. The Omarchy Core Team selects a podium, with prizes of $2,500, $1,000, and $500. [Official competition announcement](https://omarchy.org/news/2026/08/the-first-plugin-competition/).

At the time of this research, the machine clock was 24 August 2026 at 01:04 CEST. Just under eight hours remained. The build order therefore has one submission path: clipboard spike, overlay, KLIPY search, eight-tile grid, navigation, copy, favourites, polish, validation, preview, submission. Everything else waits.

Implication for Loopbox: ship one provider, one excellent search grid, one proven default copy action, a clear fallback action, and a short recorded demo. Do not spend competition time on downloads, provider switching, or a settings panel until the core paste test passes.

## Marketplace collision check

### Result

No genuine collision found. Keep the locked name **Loopbox**.

- The current marketplace registry and generated catalog contain no plugin named Loopbox and no GIF search or reaction GIF picker. The only GIF-related listings are `Media Widget`, which plays local photos, GIFs, and videos, and `CPU Catjam`, which uses a dancing GIF as a system widget. [Registry](https://github.com/HANCORE-linux/omarchy-plugin-marketplace/blob/d4ce66d2384a0bf88f6db7097f2adeb62db72c41/registry.json), [catalog](https://github.com/HANCORE-linux/omarchy-plugin-marketplace/blob/d4ce66d2384a0bf88f6db7097f2adeb62db72c41/site/catalog.json).
- Searches across all marketplace issues for `Loopbox`, `GIF`, `Giphy`, `Tenor`, `reaction`, `meme`, `sticker`, `animated image`, and `image search` found no submitted GIF picker. The apparent matches concern preview GIFs, Slack reactions, local media, OCR, or unrelated plugins. [GitHub issue search for Loopbox](https://github.com/HANCORE-linux/omarchy-plugin-marketplace/issues?q=is%3Aissue+Loopbox), [GIF search](https://github.com/HANCORE-linux/omarchy-plugin-marketplace/issues?q=is%3Aissue+GIF), [Giphy search](https://github.com/HANCORE-linux/omarchy-plugin-marketplace/issues?q=is%3Aissue+Giphy), [Tenor search](https://github.com/HANCORE-linux/omarchy-plugin-marketplace/issues?q=is%3Aissue+Tenor), [reaction search](https://github.com/HANCORE-linux/omarchy-plugin-marketplace/issues?q=is%3Aissue+reaction).

This validates marketplace originality, not global product originality. Raycast has a mature GIF Search extension, which is useful validation and prior art.

## Omarchy plugin contract

### Manifest and loading

- A third-party plugin is a Git repository with `manifest.json` at the root. Omarchy installs it under `~/.config/omarchy/plugins/<id>/`. [Official shell documentation](https://github.com/basecamp/omarchy/blob/7e469f962d33a2d68edd483d07fd9bc19dfab218/docs/omarchy-shell.md).
- The manifest uses `schemaVersion: 1`, a unique `id`, `name`, `version`, non-empty `kinds`, and `entryPoints`. Entry points must be relative paths without `..`; third parties cannot use `omarchy.*`. [`shell/services/PluginRegistry.qml`](https://github.com/basecamp/omarchy/blob/7e469f962d33a2d68edd483d07fd9bc19dfab218/shell/services/PluginRegistry.qml#L35-L91), [manual](https://omarchy.org/manual/shell-plugins/).
- Loopbox should be an `overlay` with `entryPoints.overlay = "Loopbox.qml"`. Its root object must expose `open(payloadJson)` and `close()`. Omarchy injects `omarchyPath`, `shell`, `manifest`, and registries when those properties exist. [`docs/omarchy-shell.md`](https://github.com/basecamp/omarchy/blob/7e469f962d33a2d68edd483d07fd9bc19dfab218/docs/omarchy-shell.md), [`shell/shell.qml`](https://github.com/basecamp/omarchy/blob/7e469f962d33a2d68edd483d07fd9bc19dfab218/shell/shell.qml#L430-L651).
- The shell loads overlay entry points asynchronously on summon. `keepLoaded: true` keeps the instance resident even when closed. That makes reopening faster but also retains its models, decoded images, timers, and processes inside the long-running shell. [`shell/shell.qml`](https://github.com/basecamp/omarchy/blob/7e469f962d33a2d68edd483d07fd9bc19dfab218/shell/shell.qml#L581-L651).
- Summon with `omarchy-shell shell toggle <id> '{}'` or `summon`; hide invokes `close()`. [`docs/omarchy-shell.md`](https://github.com/basecamp/omarchy/blob/7e469f962d33a2d68edd483d07fd9bc19dfab218/docs/omarchy-shell.md#ipc).
- Plugins run unsandboxed in `omarchy-shell`. Marketplace validation is compatibility validation, not a security review. [Marketplace submission rules](https://github.com/HANCORE-linux/omarchy-plugin-marketplace/blob/d4ce66d2384a0bf88f6db7097f2adeb62db72c41/SUBMISSION.md).

Recommendation: omit `keepLoaded` for the first implementation unless measured summon latency is visibly bad. The loader already creates the QML asynchronously. A GIF picker has unusually expensive retained state, so unloading on close is the safer default.

### First-party UX references

These are the source-of-truth references Loopbox should follow.

| Concern | Source path | What to reuse |
|---|---|---|
| Searchable keyboard grid | [`shell/plugins/emojis/Emojis.qml`](https://github.com/basecamp/omarchy/blob/7e469f962d33a2d68edd483d07fd9bc19dfab218/shell/plugins/emojis/Emojis.qml) | Fullscreen `PanelWindow`, exclusive keyboard focus, centered `BorderSurface`, raw typing through `Keys.onPressed`, arrow navigation, `GridView.Contain`, Escape clears query before dismissing |
| Image-heavy overlay | [`shell/plugins/image-picker/ImagePicker.qml`](https://github.com/basecamp/omarchy/blob/7e469f962d33a2d68edd483d07fd9bc19dfab218/shell/plugins/image-picker/ImagePicker.qml) | Overlay layer, transparent window, scrim, exclusive focus only when ready, focus after layout settles, stale-request serials, safe shell quoting |
| Clipboard interaction and error states | [`shell/plugins/clipboard/Clipboard.qml`](https://github.com/basecamp/omarchy/blob/7e469f962d33a2d68edd483d07fd9bc19dfab218/shell/plugins/clipboard/Clipboard.qml), [`capture.sh`](https://github.com/basecamp/omarchy/blob/7e469f962d33a2d68edd483d07fd9bc19dfab218/shell/plugins/clipboard/capture.sh) | Escape behavior, selection lifecycle, empty state, history persistence, image MIME awareness |
| Menu surface styling | [`shell/Commons/Color.qml`](https://github.com/basecamp/omarchy/blob/7e469f962d33a2d68edd483d07fd9bc19dfab218/shell/Commons/Color.qml), [`shell/Commons/Style.qml`](https://github.com/basecamp/omarchy/blob/7e469f962d33a2d68edd483d07fd9bc19dfab218/shell/Commons/Style.qml), [`default/themed/shell.toml.tpl`](https://github.com/basecamp/omarchy/blob/7e469f962d33a2d68edd483d07fd9bc19dfab218/default/themed/shell.toml.tpl#L154-L186) | `Color.menu.*`, `Style.spacing.*`, `Style.font.*`, `Border.surfaceSpec("menu", ...)`, theme-derived selection and scrim |
| Overlay compositor rules | [`default/hypr/apps/omarchy-shell.lua`](https://github.com/basecamp/omarchy/blob/7e469f962d33a2d68edd483d07fd9bc19dfab218/default/hypr/apps/omarchy-shell.lua) | First-party keyboard overlays disable compositor layer animation and own their restrained QML transition |
| Plugin lifecycle and IPC | [`shell/shell.qml`](https://github.com/basecamp/omarchy/blob/7e469f962d33a2d68edd483d07fd9bc19dfab218/shell/shell.qml#L430-L651) | Queued summon payloads, injected properties, async loader, open and close contract |

There is no first-party launcher QML entry point in the current `shell/plugins/` tree or its plugin inventory. The repository contains launcher theme tokens and a Hyprland rule, but not the launcher UI source. Do not invent a launcher path. The emojis overlay is the closest reachable first-party reference for Loopbox's interaction model. [`shell/plugins/README.md`](https://github.com/basecamp/omarchy/blob/7e469f962d33a2d68edd483d07fd9bc19dfab218/shell/plugins/README.md), [`default/themed/shell.toml.tpl`](https://github.com/basecamp/omarchy/blob/7e469f962d33a2d68edd483d07fd9bc19dfab218/default/themed/shell.toml.tpl#L154-L186).

### Shortcut

The plugin contract does not declare a global hotkey. `Super+Ctrl+G` is free in the current Omarchy defaults and in Ajan's reachable bindings. Document this opt-in Hyprland binding:

```lua
o.bind("SUPER + CTRL + G", "Loopbox", "omarchy-shell shell toggle io.github.ajanraj.loopbox '{}'")
```

Do not write the user's Hyprland configuration during install. Marketplace submitters must affirm that the plugin does not overwrite user configuration without explicit consent. [Submission checklist](https://github.com/HANCORE-linux/omarchy-plugin-marketplace/blob/d4ce66d2384a0bf88f6db7097f2adeb62db72c41/SUBMISSION.md#L75-L84).

## Raycast product and architecture validation

Raycast GIF Search currently supports GIPHY GIFs, GIPHY Clips, KLIPY, and The Finer Gifs Club, plus separate favorites and recents commands. Its manifest defaults to 20 results and makes "Copy GIF" the Enter action, while exposing link, Markdown, paste, favorite, details, browser, square crop, and download actions. [`package.json`](https://github.com/raycast/extensions/blob/85b3c3527479bea53d28fc79985322812c607854/extensions/gif-search/package.json), [`README.md`](https://github.com/raycast/extensions/blob/85b3c3527479bea53d28fc79985322812c607854/extensions/gif-search/README.md).

Useful architectural lessons:

- One normalized `IGif` model carries stable provider ID, title, page URL, original download URL/name, small and large previews, share URL, dimensions, size, tags, attribution, and optional video. [`src/models/gif.ts`](https://github.com/raycast/extensions/blob/85b3c3527479bea53d28fc79985322812c607854/extensions/gif-search/src/models/gif.ts).
- Provider modules implement the same `search`, `trending`, and ID lookup methods. Selection happens in one dispatcher. [`src/hooks/useSearchAPI.ts`](https://github.com/raycast/extensions/blob/85b3c3527479bea53d28fc79985322812c607854/extensions/gif-search/src/hooks/useSearchAPI.ts).
- An empty query means trending. Search keeps previous data while the next request loads, deduplicates results, and paginates. [`src/search.tsx`](https://github.com/raycast/extensions/blob/85b3c3527479bea53d28fc79985322812c607854/extensions/gif-search/src/search.tsx), [`src/hooks/useSearchAPI.ts`](https://github.com/raycast/extensions/blob/85b3c3527479bea53d28fc79985322812c607854/extensions/gif-search/src/hooks/useSearchAPI.ts).
- Recents are most-recent-first and deduplicated by ID. Favorites and recents store provider-specific IDs, then refetch provider metadata when shown. [`src/lib/localGifs.ts`](https://github.com/raycast/extensions/blob/85b3c3527479bea53d28fc79985322812c607854/extensions/gif-search/src/lib/localGifs.ts), [`src/hooks/useLocalGifs.ts`](https://github.com/raycast/extensions/blob/85b3c3527479bea53d28fc79985322812c607854/extensions/gif-search/src/hooks/useLocalGifs.ts).
- Copy downloads the original to a temporary file, copies a file reference, records the recent, closes the window, and caches only favorite files persistently. [`src/lib/copyFileToClipboard.ts`](https://github.com/raycast/extensions/blob/85b3c3527479bea53d28fc79985322812c607854/extensions/gif-search/src/lib/copyFileToClipboard.ts), [`src/lib/cachedGifs.ts`](https://github.com/raycast/extensions/blob/85b3c3527479bea53d28fc79985322812c607854/extensions/gif-search/src/lib/cachedGifs.ts), [`src/components/GifActions.tsx`](https://github.com/raycast/extensions/blob/85b3c3527479bea53d28fc79985322812c607854/extensions/gif-search/src/components/GifActions.tsx).
- Provider failures become a toast and a full empty-state error only when no results remain. [`src/search.tsx`](https://github.com/raycast/extensions/blob/85b3c3527479bea53d28fc79985322812c607854/extensions/gif-search/src/search.tsx), [`src/lib/fetchProviderJson.ts`](https://github.com/raycast/extensions/blob/85b3c3527479bea53d28fc79985322812c607854/extensions/gif-search/src/lib/fetchProviderJson.ts).

Raycast's keyless behavior comes from its own proxy at `https://gif-search.raycast.com/api/...`. On 24 August, both `/api/giphy` and `/api/klipy` were callable outside Raycast and returned successful search and trending responses. KLIPY search for `this is fine` took 0.63 seconds in one live request, returned the burning-house dog as the second result, and produced a roughly 7 KB response with `nanogif`, `tinygif`, and original GIF renditions. GIPHY took 0.71 seconds and produced a roughly 72 KB response. These are observations, not latency guarantees. The proxy response did not advertise browser CORS headers, so Loopbox should call it through Quickshell `Process` and `curl`, not QML `XMLHttpRequest`. [`giphy.ts`](https://github.com/raycast/extensions/blob/85b3c3527479bea53d28fc79985322812c607854/extensions/gif-search/src/models/giphy.ts), [`klipy.ts`](https://github.com/raycast/extensions/blob/85b3c3527479bea53d28fc79985322812c607854/extensions/gif-search/src/models/klipy.ts).

Ajan approved using these endpoints for Loopbox. That settles the product decision, but it does not create an SLA or grant rights beyond the upstream provider terms. Keep the proxy URL in one module, show KLIPY attribution, fail cleanly, and make a direct KLIPY key or another provider a later replacement rather than spreading proxy assumptions through the UI.

The repository and extension manifest are MIT licensed. Direct code reuse is legal if the MIT copyright and permission notice accompanies substantial copied code. Do not copy the React implementation. Reuse the normalized model and provider seam as design references, then write the QML and Wayland mechanics for Omarchy. [Raycast repository license](https://github.com/raycast/extensions/blob/85b3c3527479bea53d28fc79985322812c607854/LICENSE), [`package.json`](https://github.com/raycast/extensions/blob/85b3c3527479bea53d28fc79985322812c607854/extensions/gif-search/package.json).

## Provider matrix

| Provider | Search and trending | Authentication and free access | Formats and thumbnails | Attribution and licensing | Decision |
|---|---|---|---|---|---|
| GIPHY | `GET https://api.giphy.com/v1/gifs/search`; `GET https://api.giphy.com/v1/gifs/trending`; offset pagination | Direct API key required. Beta keys are free and limited to 100 calls/hour. Raycast's proxy removes key setup for its extension. | Response `images` has GIF, WebP, and MP4 renditions, including tiny previews. | Conspicuous "Powered By GIPHY" attribution is required. API terms govern content use. | Strong future provider. The live proxy worked, but its JSON was ten times larger than KLIPY's for the same eight-result query. [Docs](https://developers.giphy.com/docs/api/), [FAQ](https://developers.giphy.com/faq), [Raycast mapping](https://github.com/raycast/extensions/blob/85b3c3527479bea53d28fc79985322812c607854/extensions/gif-search/src/models/giphy.ts) |
| Tenor | Historical v2 search at `https://tenor.googleapis.com/v2/search`; v2 replaced trending with Featured. | Dead. New clients stopped 13 January 2026 and the API was fully decommissioned 30 June 2026. Requests now fail. Historical default was 1 request/second. | Historical responses included `media_formats` such as GIF, tiny GIF, WebP, and MP4. | Historical content required Tenor attribution. | Exclude from code and README. It is not a fallback in August 2026. [Sunset notice](https://support.google.com/tenor/answer/10455265), [migration docs](https://developers.google.com/tenor/guides/migrate-from-v1), [rate limit docs](https://developers.google.com/tenor/guides/rate-limits-and-caching), [attribution docs](https://developers.google.com/tenor/guides/attribution) |
| KLIPY | Tenor-compatible search and trending feeds with cursor pagination. Raycast requests `gif,nanogif,tinygif`. | Direct test key required, 100 calls/hour. Raycast switched to its proxy on 1 July 2026 and removed personal key setup. | Full GIF, `tinygif`, `nanogif`, WebP, and MP4. The live `nanogif` sample was 160 by 90 and 96 KB. | KLIPY requires branding and publishes API terms. The proxy does not remove those content obligations. | MVP choice. It is fast, compact, broad, and returns the exact demo GIF. [Developer page](https://klipy.com/developers), [Raycast changelog](https://github.com/raycast/extensions/blob/85b3c3527479bea53d28fc79985322812c607854/extensions/gif-search/CHANGELOG.md), [Raycast mapping](https://github.com/raycast/extensions/blob/85b3c3527479bea53d28fc79985322812c607854/extensions/gif-search/src/models/klipy.ts) |
| The Finer Gifs Club | Unauthenticated `GET https://api.thefinergifs.club/search?q=...&size=...&start=...`; no trending implementation in Raycast. | No key in the public Raycast integration. No published limits found. | One original `.gif` URL is used for preview and download; no thumbnail renditions. | No API terms, rate-limit policy, or attribution rules could be verified. The catalog is a niche TV GIF collection, not broad reaction search. | Good optional novelty provider only. Do not make it the default or promise reliability. [Raycast implementation](https://github.com/raycast/extensions/blob/85b3c3527479bea53d28fc79985322812c607854/extensions/gif-search/src/models/finergifs.ts), [service](https://thefinergifs.club/) |

No better documented, keyless, broad GIF API was found. Raycast's proxy makes the competition MVP configuration-free, but service ownership remains the main reliability risk.

### Provider recommendation

Implement only `Klipy.js` in the MVP. Search endpoint: `https://gif-search.raycast.com/api/klipy`; omit `q` for trending; send `locale=en`, `media_filter=gif,nanogif,tinygif`, and `limit=8`; use the returned `next` cursor only after the competition if pagination proves necessary.

The normalized mapping is `nanogif.url` to `previewUrl`, `gif.url` to `originalUrl` and `shareUrl`, `itemurl` to `pageUrl`, plus provider ID, title, dimensions, and byte size. Put "Powered by KLIPY" in the header or footer. Do not add a settings screen, user key flow, provider switcher, GIPHY, or Tenor before submission.

## Wayland clipboard

### What `wl-copy` guarantees

- `wl-copy` reads standard input when no text argument is supplied and supports arbitrary MIME types. `--type` controls the single offered type. [Arch manual lines 23 to 29 and 45 to 46](https://man.archlinux.org/man/wl-copy.1.en).
- The exact raw-data command is:

  ```bash
  wl-copy --type image/gif < /absolute/path/to/result.gif
  ```

  Verify it with `wl-paste --list-types` and a byte-for-byte round trip through `wl-paste --type image/gif`. [Arch manual](https://man.archlinux.org/man/wl-copy.1.en).
- By default, `wl-copy` forks and remains the clipboard owner in the background. Do not use `--foreground`, and do not use `--paste-once`, which breaks clients that make more than one request and is known to break XWayland paste. [Arch manual lines 35 to 38](https://man.archlinux.org/man/wl-copy.1.en).
- `wl-copy` cannot offer several MIME types at once. This prevents one invocation from behaving simultaneously as raw `image/gif`, `text/uri-list`, plain URL text, and a portal file transfer. [Arch manual bug section](https://man.archlinux.org/man/wl-copy.1.en#BUGS).

The GIF must first be downloaded to a safe private path because the clipboard action needs the original bytes, not a remote URL. Use `$XDG_CACHE_HOME/loopbox/files/<provider>-<id>.gif`, validate the HTTP status, cap the download size, reject a non-GIF signature, write to a unique temporary file in that directory, then rename atomically. Avoid predictable shared `/tmp` files.

### Compatibility conclusion

Compatibility is unresolved until tested on a live Omarchy session. The standards and current app evidence support these expectations:

| Target | Raw `image/gif` | `text/uri-list` local file | URL text |
|---|---|---|---|
| Chromium and Firefox web composers | May expose image data, but site behavior decides whether paste becomes an upload; animation preservation is not guaranteed | Receiver support varies and portal-aware apps may need more than `text/uri-list` | Reliable as text; the site may unfurl it |
| Discord desktop/browser | Raw animation preservation unverified | Discord documents drag/drop and file upload, not Wayland URI clipboard paste | Officially documented: pasting a GIF URL displays a preview |
| Slack desktop/browser | Raw animation preservation unverified; Electron's `NativeImage` path historically converts source images to PNG | File-reference paste is receiver and portal dependent | Reliable text, with unfurl depending on workspace/app policy |
| Electron generally | Electron documents image clipboard access through `NativeImage`; its own issue records that GIF data is converted to PNG unless the app reads the raw buffer itself | No general guarantee | Reliable text |

Sources: [Electron issue #23156](https://github.com/electron/electron/issues/23156), [Electron file-pointer issue #9035](https://github.com/electron/electron/issues/9035), [Discord upload docs](https://support.discord.com/hc/en-us/articles/211866427-How-do-I-upload-images-and-GIFs), [`wl-copy` single-MIME limitation](https://man.archlinux.org/man/wl-copy.1.en#BUGS).

### What Enter does

The product decision is fixed:

1. Enter marks the selected tile busy and leaves the overlay open.
2. Loopbox downloads the original rendition to a private temporary file under `$XDG_CACHE_HOME/loopbox/gifs`, with an eight-second timeout and a 15 MB size cap.
3. The helper requires HTTP success, a non-empty body, and a `GIF87a` or `GIF89a` signature, then atomically renames the file to `<provider>-<id>.gif`.
4. Loopbox runs Omarchy's own `omarchy-clipboard-paste-file --copy-only image/gif <path>`. That command uses `wl-copy --type image/gif < "$path"` and lets `wl-copy` remain the background clipboard owner.
5. Only after both commands succeed does Loopbox put the normalized record at the front of recents, show "GIF copied", dismiss, and return focus to the prior application. A failure keeps the overlay open and names the failed stage.
6. Shift+Enter copies `originalUrl` as `text/plain;charset=utf-8`, records the recent, reports "GIF link copied", and dismisses.

Before submission, test these three transport modes in native Wayland Chromium, Firefox, Discord, and Slack:

1. raw bytes: `wl-copy --type image/gif < file.gif`
2. file URI: `printf 'file://%s\r\n' "$absolute_path" | wl-copy --type text/uri-list`
3. URL: `wl-copy --type text/plain "$gif_url"`

Record whether each target produces an animated upload, a static frame, a link/unfurl, literal path text, or nothing. Keep the clipboard owner alive long enough to paste, then confirm the cached file remains available for URI-based paste.

The matrix selects the demo target, not Enter semantics. If one receiver rejects raw `image/gif`, document it and demonstrate another passing receiver. Shift+Enter is the supported fallback. Do not label URL copy as file copy.

## QML and Quickshell performance

Omarchy currently installs `qt6-imageformats`, `quickshell`, and `wl-clipboard` in its base package list, so GIF and WebP decoder availability and clipboard tooling are valid Omarchy dependencies. [`install/omarchy-base.packages`](https://github.com/basecamp/omarchy/blob/7e469f962d33a2d68edd483d07fd9bc19dfab218/install/omarchy-base.packages#L108-L142).

- `AnimatedImage` plays GIFs and other QMovie-supported formats. It defaults to playing. When caching is enabled, Qt caches every animation frame. Qt explicitly recommends `cache: false` for long or large animations. [`AnimatedImage` docs](https://doc.qt.io/qt-6/qml-qtquick-animatedimage.html).
- Set `sourceSize` to the cell's pixel dimensions. Unlike merely setting `width` and `height`, `sourceSize` bounds the decoded pixels retained for every frame. Changing it dynamically can reload the network source. [`AnimatedImage.sourceSize`](https://doc.qt.io/qt-6/qml-qtquick-animatedimage.html#sourceSize-prop).
- Network images already load asynchronously. Qt shares cached images with identical source URLs, but external images should still have a bounded `sourceSize`. [`Image` performance docs](https://doc.qt.io/qt-6/qml-qtquick-image.html#performance).
- `GridView` creates delegates as needed. `reuseItems: true` enables a reuse pool; `GridView.onPooled` is the correct place to pause animations and release resources. State must not live in reused delegates. [`GridView.reuseItems`](https://doc.qt.io/qt-6/qml-qtquick-gridview.html#reuseItems-prop).
- `cacheBuffer` retains extra offscreen delegates and consumes more memory. Keep it at zero or one row for animated results. A buffer cannot fix an expensive delegate. [`GridView.cacheBuffer`](https://doc.qt.io/qt-6/qml-qtquick-gridview.html#cacheBuffer-prop).

Recommended rendering budget:

- Fetch exactly eight results and render a fixed four by two grid. Eight moving tiles deliver the visual effect without turning the shell into a GIF stress test.
- Use KLIPY's `nanogif`, normally around 160 by 90, and never render originals in the grid.
- Keep `AnimatedImage.cache: true` for reliable looping of network animations, but make the budget explicit: eight sources, fixed `sourceSize`, no offscreen page, and unload the whole plugin on close. Qt caches every frame, so measure this choice. If open-shell RSS grows by more than 75 MB or CPU stays above 20% on the test machine, animate the selected tile and its three neighbours only.
- Set `playing` only while the overlay is open and the delegate is not pooled. Pause in `GridView.onPooled`, reset in `onReused`, use `reuseItems: true`, and set `cacheBuffer: 0`.
- Keep `sourceSize` fixed to the rendered cell size. Do not bind it to a selection animation that changes width.
- Download the original only after activation. Keep at most 20 GIF files and 150 MB under `$XDG_CACHE_HOME/loopbox/gifs`; prune oldest files after a successful copy.
- Clear the model and stop network/download processes on close if `keepLoaded` is ever enabled.

### Network calls

Follow the first-party weather panel's bounded process pattern: Quickshell `Process`, argv array, `curl -fsS --max-time`, a `StdioCollector`, request serials, and stale response suppression. It gives explicit timeouts and cancellation and matches reachable Omarchy code. [`shell/plugins/panels/weather/Panel.qml`](https://github.com/basecamp/omarchy/blob/7e469f962d33a2d68edd483d07fd9bc19dfab218/shell/plugins/panels/weather/Panel.qml#L174-L190), [`ImagePicker.qml` request serials](https://github.com/basecamp/omarchy/blob/7e469f962d33a2d68edd483d07fd9bc19dfab218/shell/plugins/image-picker/ImagePicker.qml#L18-L31).

Use a 180 ms debounce. Build a `curl` argv array, never a shell string: `--fail --silent --show-error --max-time 8 --get <endpoint> --data-urlencode q=<query> --data-urlencode locale=en --data-urlencode media_filter=gif,nanogif,tinygif --data-urlencode limit=8`. When the query changes, increment `requestSerial`, send SIGTERM to the prior `Process`, queue the latest request until exit, and accept output only if its serial still matches. Keep old successful results visible behind a small loading indicator. Parse provider JSON in a pure JS module and reject malformed objects at that boundary.

## Recommended technical shape

Use this root manifest without adding speculative fields:

```json
{
  "schemaVersion": 1,
  "id": "io.github.ajanraj.loopbox",
  "name": "Loopbox",
  "version": "1.0.0",
  "author": "Ajan",
  "license": "MIT",
  "description": "Fast keyboard-first GIF picker and GIF search for Omarchy. Search reaction GIFs, trending GIFs, favourites, and copy GIFs or links directly to your Wayland clipboard.",
  "kinds": ["overlay"],
  "entryPoints": { "overlay": "Loopbox.qml" }
}
```

Do not set `keepLoaded`. The shell creates the overlay on summon and destroys its GIF model after close. The process and state flow is:

```text
Super+Ctrl+G
  -> Omarchy shell loads Loopbox.qml
  -> 180 ms query debounce
  -> bounded curl Process calls providers/Klipy.js command
  -> Klipy.js validates and normalizes eight records
  -> root ListModel drives four by two AnimatedImage grid
  -> Enter runs scripts/copy-gif
  -> verified cached file goes through omarchy-clipboard-paste-file
  -> state.json records recent, UI reports success, shell unloads overlay
```

```text
omarchy-loopbox/
├── manifest.json
├── Loopbox.qml                 # overlay, lifecycle, focus, state coordination
├── LoopboxModel.js             # pure result normalization and navigation helpers
├── providers/
│   └── Klipy.js                # proxy command, result contract, response normalization
├── components/
│   ├── GifTile.qml
│   ├── SearchHeader.qml
│   └── StatusBar.qml
├── scripts/
│   └── copy-gif                # bounded download, validation, Omarchy clipboard call, pruning
├── tests/
│   ├── model-test.js
│   ├── klipy-fixture.json
│   └── clipboard-test.sh
├── README.md
├── LICENSE
└── preview.png
```

Result contract:

```js
{
  provider: "klipy",
  id: "stable-provider-id",
  title: "Human-readable title",
  pageUrl: "https://klipy.com/gifs/...",
  shareUrl: "https://static.klipy.com/.../original.gif",
  previewUrl: "https://static.klipy.com/.../nano.gif",
  originalUrl: "https://static.klipy.com/.../original.gif",
  previewWidth: 160,
  previewHeight: 90,
  originalWidth: 498,
  originalHeight: 280,
  originalBytes: 2568057
}
```

Keep persistence tiny. One `$XDG_STATE_HOME/loopbox/state.json` file stores `{version: 1, favorites: [], recents: []}`. Store normalized records so both views render during a provider outage. Cap recents at 20 and favourites at 50, deduplicate by `provider + id`, and write through Quickshell `FileView` with `atomicWrites: true`. A short `mkdir -p` `Process` creates the private state directory before the first load. No config file, API key, database, or migration layer belongs in the MVP.

The root owns three modes: empty query shows trending, any typed query shows search results, and `Ctrl+2` shows favourites. `Ctrl+1` returns to trending. `Ctrl+Shift+F` toggles the selected favourite. Typing from either local view switches to search. Recents need persistence now because successful copy ordering is part of Enter, but a dedicated recents screen can wait.

Cache only copied originals. Do not add a response cache before submission. The proxy and thumbnail CDNs already cache network data, the overlay unloads on close, and a bespoke query cache inside a long-running shell creates more invalidation work than eight results justify.

Errors should name impact and recovery:

- 401/403: "GIF search access was rejected. Retry, or check the Loopbox service note in README."
- 429: "GIF search is rate limited. Wait a minute and retry."
- Timeout/offline: keep old results and show "GIF search timed out. Press Ctrl+R to retry."
- Image failure: show the still image or neutral tile; never collapse the grid.
- Copy failure: keep the overlay open and show the exact failed stage, download, validation, or clipboard.

## MVP cut

### Must have

- Overlay summon and dismiss with immediate keyboard focus
- Debounced search and trending on empty query
- Eight visible animated KLIPY preview tiles, with the selection unmistakable
- Left, right, up, down, Home, End, Page Up, Page Down, Escape, Enter
- Enter copies raw GIF bytes; Shift+Enter copies the direct GIF URL
- Favourites view and toggle, because the locked marketplace description promises favourites
- Recents state updated after a successful copy, capped at 20
- Loading, no results, offline, provider error, image error, and copy error states
- One-line success state before closing
- KLIPY attribution in the search surface
- Performance caps and process cancellation
- README, license, root manifest, root preview, install, shortcut, remove, dependencies

### Should have

- Dedicated recents view
- Pagination after the first eight results
- A still-first loading treatment that starts animation as each tile becomes ready

### Nice to have

- GIPHY provider
- The Finer Gifs Club provider
- Downloads
- Provider switching UI
- Configurable grid size or default action
- Direct auto-paste
- GIPHY Clips, stickers, memes, or audio

## Five-second demo

Preconditions: the target application has passed the raw GIF paste matrix and the chosen `this is fine` result still appears in the first eight KLIPY results. Do not warm the search or original-file cache for the take.

1. Start with Discord or Slack open behind the desktop.
2. Press `Super+Ctrl+G`.
3. Type `this is fine` without clicking.
4. The eight animated results appear. Press Right once to select "This Is Fine Dog Meme in Burning House".
5. Press Enter. The selected tile shows a brief copy state; Loopbox closes when the clipboard owns the verified GIF.
6. Press Omarchy's universal paste shortcut, `Super+V`. The GIF appears in the already-focused composer.

Record one uncut take with the keyboard visible in an input overlay if practical. The final frame should hold on the pasted animation. Do not hide an upload dialog or a failed first paste with editing.

## Ordered implementation milestones

Clipboard compatibility is milestone zero. If it fails, the product's default action and demo script change. Do not defer it to milestone seven simply because clipboard appears seventh in the feature list.

| Stage | Files | Implementation | Focused checks | Likely failure modes |
|---|---|---|---|---|
| 0. Clipboard spike | temporary commands only, no product code | Download one known animated GIF. Exercise raw `image/gif`, `text/uri-list`, and URL modes in Chromium, Firefox, Discord, and Slack. Write down exact behavior. | `wl-paste --list-types`; byte-for-byte raw round trip; visual paste matrix | Static first frame, no paste, literal URI, portal-only receiver, cached file removed too early |
| 1. Plugin skeleton | `manifest.json`, `Loopbox.qml`, `README.md`, `LICENSE` | Valid overlay manifest, transparent fullscreen `PanelWindow`, `open` and `close`, theme imports, no network. | `omarchy plugin validate .`; summon, hide, toggle; `qmllint` | Reserved or mismatched ID, unsafe entry point, missing injected property, overlay never unloads |
| 2. Overlay lifecycle | `Loopbox.qml` | Follow Emojis for exclusive focus, scrim, centered card, Escape, outside click, and post-layout focus. Start without `keepLoaded`. | Repeated shortcut 30 times; Escape during opening; click outside; multi-monitor summon | Focus stolen by previous app, invisible exclusive surface, duplicate opens, stale state on reopen |
| 3. Search UI | `Loopbox.qml`, `components/SearchHeader.qml`, `components/EmptyState.qml`, `LoopboxModel.js` | Raw keyboard input, edit helpers, 200 ms debounce, selection reset, loading/no-results/error slots. | Pure model tests for editing and selection; type rapidly; clear with Escape | Text event mishandling, IME issues, Backspace propagation, stale query label |
| 4. One provider | `providers/Klipy.js`, `Loopbox.qml`, `tests/klipy-fixture.json` | Raycast proxy URL, search/trending commands, locale, media filter, eight-result limit, bounded `curl`, serial cancellation, normalized records, KLIPY attribution. | Fixture normalization; live search and trending with no key; 403, 429, malformed JSON, timeout | Proxy policy or schema changes, stale response wins, missing media rendition, attribution omission |
| 5. Result rendering | `components/GifTile.qml`, `Loopbox.qml` | Four by two `GridView`, fixed `sourceSize`, `nanogif` previews, placeholders, eight-item hard cap. | Mixed aspect-ratio fixture; bad URL; slow network; inspect shell RSS and CPU | Original rendition used by mistake, frame cache too large, layout jump, tile collapse, decode storm |
| 6. Keyboard navigation | `Loopbox.qml`, `LoopboxModel.js` | Explicit four-column math, clamped incomplete last row, Home, End, current-index visibility, pointer movement gate. | Table-driven navigation tests for 0 through 8 results; live keyboard-only pass | Right edge jumps, last row overshoots, grid loses focus, mouse and keyboard cursors disagree |
| 7. Clipboard product path | `scripts/copy-gif`, `Loopbox.qml`, `components/StatusBar.qml`, `tests/clipboard-test.sh` | Enter follows the fixed raw-GIF sequence; Shift+Enter copies URL. Bounded download, signature check, private cache, atomic rename, built-in Omarchy clipboard command, actionable errors. | Shell tests with local HTTP fixture; 404, timeout, oversized body, HTML body, interrupted write; repeat live target matrix | Shell injection through URL or ID, corrupted cache, clipboard owner exits, overlay closes before error, animation flattens in target app |
| 8. Performance | `GifTile.qml`, `Loopbox.qml` | Eight-item cap, fixed decode size, pause pooled animations, `cacheBuffer: 0`, cancel work and unload on close. Start with `cache: true` for reliable loops and apply the measured fallback if thresholds fail. | Compare idle and open CPU/RSS; reopen and search 30 times; shell remains responsive; all tiles keep looping | Frame cache exceeds budget, pooled delegate keeps wrong source, timers survive close, memory grows per query |
| 9. Recents and favourites | `Loopbox.qml`, `$XDG_STATE_HOME/loopbox/state.json` runtime file | One versioned state document, recents max 20, favourites max 50, normalized records, atomic write, dedicated favourites view. | Missing, empty, corrupt, and future-version files; dedupe; caps; favourite survives provider outage | Unbounded state, provider ID collision, corrupt write, missing state directory, remote favourite URL expires |
| 10. Visual polish | component QML files, theme bindings | Selection treatment, clipped rounded previews, still-to-animation reveal, compact key hints, one restrained open transition, reduced visual motion. | Dark/light and several Omarchy themes; 1080p/1440p/4K; screenshot review | Hard-coded colors, weak focus state, text contrast, motion competes with GIFs, cell crop hides content |
| 11. Error states | `Loopbox.qml`, `StatusBar.qml`, provider/copy paths | Complete recovery copy for access rejection, rate limit, offline, timeout, no results, broken preview, corrupt response, and failed copy. | Force every error; ensure overlay remains controllable and retry works | Generic error text, stale spinner, error replaces usable old results, retry launches duplicate process |
| 12. Validation | tests, manifest, all source | Run validator, unit tests, shell tests, `qmllint`, clean install and removal, live end-to-end. | `omarchy plugin validate .`; exact documented commands; final filesystem inspection | Tests need repo-only imports, install differs from working tree, undocumented dependency, state remains after removal |
| 13. README | `README.md` | SEO-aware opening, install, enable, shortcut, use, removal, dependencies, proxy disclosure, privacy, state/cache cleanup, troubleshooting, KLIPY attribution. | Follow steps on a clean user profile; link check; compare every command to manifest ID | Proxy dependency hidden, stale ID, removal leaves state/cache without disclosure, compatibility claims exceed the live matrix |
| 14. Preview and demo | `preview.png`, external demo capture | Root preview shows query, animated-looking grid, focus state, and action hint. Record the uncut five-second flow. | Marketplace preview limits; review at card size; replay demo without narration | Copyright or private chat content, preview too busy, paste relies on hidden edit, provider result changes |
| 15. Submission | no code changes unless validation reports them | Rebase/update repository as owner directs, validate public HEAD, prepare exact issue form, secure owner approval, submit real listing. | Confirm public SHA, manifest ID uniqueness, all checklist claims, automated validation and baseline response | Deadline missed, ID collision at last minute, unchecked ownership claim, new commit invalidates verified snapshot |

Definition of done: a clean install can summon Loopbox, search `this is fine`, navigate without a mouse, perform the accurately labelled default action, and paste an animation or documented animated unfurl into the chosen demo target. The shell's memory and CPU return near baseline after closing.

## Competition assessment

| Dimension | Score | Reason |
|---|---:|---|
| Originality | 8/10 | No marketplace collision and no existing Omarchy GIF picker; mature prior art exists outside Omarchy |
| Usefulness | 8/10 | Reaction GIF search is frequent for chat-heavy users, though not universal |
| Omarchy fit | 9.5/10 | Keyboard-first overlay, Wayland clipboard, Hyprland shortcut, and theme-native UI fit the platform directly |
| Technical feasibility | 8/10 | The live proxy removes setup and returned the needed data; cross-app animated paste remains unproven |
| Visual wow factor | 9/10 | A responsive wall of moving reactions is immediately visible and easy to remember |
| Implementation speed | 8/10 | One provider, eight tiles, and first-party interaction patterns keep the code small; the deadline is unforgiving |
| Demo impact | 9.5/10 | Shortcut, query, one arrow, Enter, paste tells the whole story without explanation |
| Overall competition potential | 8.6/10 | Podium-capable if the raw GIF paste works in the filmed target and the grid stays light inside the shell |

Biggest technical risk: cross-application animated GIF paste on Wayland, followed by dependence on an undocumented Raycast proxy.

Killer differentiator: **The reaction GIF appears in your conversation before your hands leave the keyboard.**

## Publishing and metadata

The current rules require a public GitHub repository, one root plugin manifest, root README with installation and removal instructions, root license, documented external dependencies, and a globally unique ID outside `omarchy.*`. A root preview is optional and may be PNG, JPG, JPEG, WebP, or AVIF, up to 50 MB and 40 megapixels. [Current `SUBMISSION.md`](https://github.com/HANCORE-linux/omarchy-plugin-marketplace/blob/d4ce66d2384a0bf88f6db7097f2adeb62db72c41/SUBMISSION.md), [publishing guide](https://omarchyplugins.com/publish.html).

The publishing guide currently says to run `omarchy plugin validate`; with a repository argument, use the documented command:

```bash
omarchy plugin validate .
```

The guide's command is current as of 20 August 2026. [Publishing guide](https://omarchyplugins.com/publish.html), [official plugin reference](https://github.com/basecamp/omarchy/blob/7e469f962d33a2d68edd483d07fd9bc19dfab218/shell/plugins/README.md).

Allowed category and tag values are exact and case-sensitive. `Productivity` is valid. `media`, `launcher`, and `quickshell` are valid, and a submission may use one to three. `gif` is not in the allowed list, but the form accepts one suggested missing reusable tag. [Submission metadata rules](https://github.com/HANCORE-linux/omarchy-plugin-marketplace/blob/d4ce66d2384a0bf88f6db7097f2adeb62db72c41/SUBMISSION.md#choose-listing-metadata).

Final metadata:

- Name: `Loopbox`
- Manifest ID: `io.github.ajanraj.loopbox`
- Description: `Fast keyboard-first GIF picker and GIF search for Omarchy. Search reaction GIFs, trending GIFs, favourites, and copy GIFs or links directly to your Wayland clipboard.`
- Category: `Productivity`
- Tags: `media`, `launcher`, `quickshell`
- Suggested missing tag: `gif`
- GitHub repository name: `omarchy-loopbox` (`https://github.com/ajanraj/omarchy-loopbox` when created)

README opening recommendation:

> Loopbox is a fast keyboard-first Omarchy GIF picker and reaction GIF search plugin for Hyprland. It works as a lightweight GIF launcher and Wayland GIF clipboard: search GIFs, browse reactions and trending GIFs, then copy the image or URL without leaving the keyboard.

Before submission:

1. Use `io.github.ajanraj.loopbox` everywhere. The complete ID, `Loopbox`, and `omarchy-loopbox` had no registry, submission, or public-repository collision at research time; repeat the marketplace checks immediately before submission.
2. Run `omarchy plugin validate .`.
3. Run focused JS and shell tests, `qmllint` with Omarchy's `qs.*` imports available, and the live summon/search/copy flow.
4. Test a clean install with `omarchy plugin add <public-repository-url> --enable`, the manual shortcut, and `omarchy plugin remove <id>`.
5. Confirm the repository and preview are public, all dependencies and API-key steps are documented, and no credential appears in Git history.
6. Use the official submission form, preserve all six headings and five checklist statements, show the final issue body to the owner, and obtain explicit approval before opening the issue. [Submission form](https://github.com/HANCORE-linux/omarchy-plugin-marketplace/issues/new?template=submit-plugin.yml), [`SUBMISSION.md`](https://github.com/HANCORE-linux/omarchy-plugin-marketplace/blob/d4ce66d2384a0bf88f6db7097f2adeb62db72c41/SUBMISSION.md).

## Confidence and open tests

Confirmed by current primary sources:

- no marketplace or submission collision
- Omarchy overlay contract, load lifecycle, IPC, keyboard/focus patterns, theme APIs, and dependencies
- Raycast provider architecture and MIT license
- external calls to Raycast's GIPHY and KLIPY proxy endpoints, including search, trending, response shape, and one latency sample
- GIPHY and KLIPY key, limit, and attribution requirements
- Tenor shutdown
- `wl-copy` raw MIME behavior, ownership behavior, and single-MIME limitation
- Qt animation caching and view-reuse behavior
- current marketplace metadata and validation command

Not verified without building the spike and using the target applications:

- animated GIF paste behavior in current Chromium, Firefox, Discord, and Slack builds on Omarchy Wayland
- peak shell RSS and CPU with eight simultaneous `AnimatedImage` delegates
- how long Raycast will keep its proxy callable by independent clients

Those are milestone-zero gates, not post-polish QA.

## GO / NO-GO

**GO.** Build Loopbox under its locked name. No marketplace collision exists, the KLIPY proxy makes install-to-search possible, the Omarchy architecture is a direct fit, and the five-second demo is strong enough to justify the clipboard and service risks.

## Competition score /10

| Dimension | Score |
|---|---:|
| Originality | 8/10 |
| Usefulness | 8/10 |
| Omarchy fit | 9.5/10 |
| Technical feasibility | 8/10 |
| Visual wow-factor | 9/10 |
| Implementation speed | 8/10 |
| Demo impact | 9.5/10 |
| Overall competition potential | **8.6/10** |

## Exact MVP to build

Build one unload-on-close Omarchy overlay summoned by `Super+Ctrl+G`. It uses the Raycast KLIPY proxy for no-config search and trending, renders eight `nanogif` previews in a four by two keyboard grid, copies a verified original as raw `image/gif` on Enter, copies its direct URL on Shift+Enter, stores 20 recents and 50 favourites in one atomic state file, exposes trending and favourites views, shows KLIPY attribution, and includes complete loading, empty, provider, preview, and clipboard failure states. No pagination, provider switching, downloads, settings, auto-paste, stickers, clips, or GIPHY before submission.

## Biggest technical risk

Raw `image/gif` paste may flatten or fail in a target Chromium or Electron composer even though the Wayland clipboard contains valid GIF bytes; the live app matrix must choose the demo target before UI work proceeds.

## Killer differentiator

The reaction GIF reaches the conversation before the user's hands leave the keyboard.

## Publishing metadata

- Name: `Loopbox`
- Manifest ID: `io.github.ajanraj.loopbox`
- Description: `Fast keyboard-first GIF picker and GIF search for Omarchy. Search reaction GIFs, trending GIFs, favourites, and copy GIFs or links directly to your Wayland clipboard.`
- Category: `Productivity`
- Tags: `media`, `launcher`, `quickshell`
- Suggested missing tag: `gif`
- GitHub repository name: `omarchy-loopbox`
