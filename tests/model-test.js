"use strict";

const assert = require("assert");
const fs = require("fs");
const http = require("http");
const path = require("path");
const { spawn } = require("child_process");
const vm = require("vm");

const root = path.resolve(__dirname, "..");

function loadQmlJavaScript(relativePath) {
  const filename = path.join(root, relativePath);
  const source = fs.readFileSync(filename, "utf8");
  const module = { exports: {} };
  const context = {
    console,
    module,
    exports: module.exports,
  };
  vm.runInNewContext(source, context, { filename });
  return module.exports;
}

function result(id, title) {
  return {
    provider: "klipy",
    id: String(id),
    title: title || "GIF " + id,
    pageUrl: "https://klipy.com/gifs/" + id,
    shareUrl: "https://static.klipy.com/original/" + id + ".gif",
    originalUrl: "https://static.klipy.com/original/" + id + ".gif",
    previewUrl: "https://static.klipy.com/nano/" + id + ".gif",
    width: 160,
    height: 90,
    bytes: 1234,
  };
}

const Model = loadQmlJavaScript("LoopboxModel.js");
const Klipy = loadQmlJavaScript("providers/Klipy.js");
const fixture = JSON.parse(
  fs.readFileSync(path.join(root, "tests", "klipy-fixture.json"), "utf8"),
);

function plain(value) {
  return JSON.parse(JSON.stringify(value));
}

// Provider command construction is argv-only and keeps query data out of a shell.
const hostileQuery = "funny cats & dogs; $(touch /tmp/loopbox-should-not-exist)";
const searchArgv = Klipy.searchCommand(hostileQuery, 24);
assert.deepStrictEqual(plain(searchArgv), [
  "curl",
  "--fail",
  "--silent",
  "--show-error",
  "--connect-timeout",
  "3",
  "--max-time",
  "8",
  "--max-filesize",
  "262144",
  "--get",
  "https://gif-search.raycast.com/api/klipy",
  "--data-urlencode",
  "locale=en",
  "--data-urlencode",
  "media_filter=gif,nanogif,tinygif",
  "--data-urlencode",
  "limit=24",
  "--data-urlencode",
  "q=" + hostileQuery,
]);
assert.deepStrictEqual(
  plain(Klipy.searchCommand("", 24)),
  [
    "curl",
    "--fail",
    "--silent",
    "--show-error",
    "--connect-timeout",
    "3",
    "--max-time",
    "8",
    "--max-filesize",
    "262144",
    "--get",
    "https://gif-search.raycast.com/api/klipy",
    "--data-urlencode",
    "locale=en",
    "--data-urlencode",
    "media_filter=gif,nanogif,tinygif",
    "--data-urlencode",
    "limit=24",
  ],
);
assert.deepStrictEqual(
  plain(Klipy.searchCommand("   ", 24).slice(-2)),
  ["--data-urlencode", "limit=24"],
);
assert.deepStrictEqual(
  plain(Klipy.searchCommand("query", 100).slice(-4)),
  ["--data-urlencode", "limit=24", "--data-urlencode", "q=query"],
);
assert.deepStrictEqual(
  plain(Klipy.searchCommand("query", 24, "Mg==").slice(-6)),
  [
    "--data-urlencode", "limit=24",
    "--data-urlencode", "pos=Mg==",
    "--data-urlencode", "q=query",
  ],
);
assert.strictEqual(Klipy.searchCommand("query", 24, "bad cursor").includes("pos=bad cursor"), false);
assert.strictEqual(
  Klipy.searchCommand("x".repeat(200), 24).slice(-1)[0],
  "q=" + "x".repeat(120),
);

// The live provider shape maps nanogif -> preview and gif -> original.
const parsed = Klipy.parseResponse(JSON.stringify(fixture));
assert.strictEqual(parsed.length, 4);
assert.deepStrictEqual(plain(parsed[0]), {
  provider: "klipy",
  id: "6039247074942322",
  title: "Weekend Over? Monday Arrives!",
  pageUrl: "https://klipy.com/gifs/monday-71",
  shareUrl: "https://static.klipy.com/original/monday.gif",
  originalUrl: "https://static.klipy.com/original/monday.gif",
  previewUrl: "https://static.klipy.com/nano/monday.gif",
  width: 498,
  height: 498,
  bytes: 4921058,
});
assert.strictEqual(parsed[1].title, "A useful fallback title");
assert.strictEqual(parsed[1].previewUrl, "https://static.klipy.com/tiny/fallback.gif");
assert.deepStrictEqual(
  { width: parsed[1].width, height: parsed[1].height, bytes: parsed[1].bytes },
  { width: 160, height: 90, bytes: 0 },
);
assert.strictEqual(parsed[2].id, "771");
assert.strictEqual(parsed[2].previewUrl, parsed[2].originalUrl);
assert.strictEqual(parsed[2].pageUrl, "");
const hostileTitle = '<img src="https://attacker.invalid/title.png">Provider title stays text';
assert.strictEqual(parsed[3].title, hostileTitle);
assert.strictEqual(Model.normalizeRecord(parsed[3]).title, hostileTitle);

const parsedPage = Klipy.parsePage(JSON.stringify(Object.assign({}, fixture, { next: "Mg==" })));
assert.strictEqual(parsedPage.results.length, 4);
assert.strictEqual(parsedPage.next, "Mg==");
assert.strictEqual(
  Klipy.parsePage(JSON.stringify(Object.assign({}, fixture, { next: "bad cursor" }))).next,
  "",
);

const safeOriginalUrl = "https://static.klipy.com/original/policy.gif";
const safePreviewUrl = "https://static.klipy.com/nano/policy.gif";
const safeTinyUrl = "https://static.klipy.com/tiny/policy.gif";

function providerRecord(id, urls) {
  const record = {
    id: String(id),
    media_formats: {},
  };
  if (urls.record !== undefined) record.url = urls.record;
  ["gif", "nanogif", "tinygif"].forEach((format) => {
    if (urls[format] !== undefined) {
      record.media_formats[format] = { url: urls[format] };
    }
  });
  return record;
}

const cappedPage = Klipy.parsePage(JSON.stringify({
  next: "Mg==",
  results: Array.from({ length: 30 }, (_, index) => providerRecord("page-" + index, {
    gif: safeOriginalUrl,
    nanogif: safePreviewUrl,
  })),
}));
assert.strictEqual(cappedPage.results.length, 24);
assert.strictEqual(cappedPage.next, "Mg==");

const boundedTitle = Klipy.parseResponse(JSON.stringify({
  results: [Object.assign(providerRecord("bounded-title", { gif: safeOriginalUrl }), {
    title: "A".repeat(200) + "\u202ehidden",
  })],
}))[0].title;
assert.strictEqual(boundedTitle.length, 180);
assert.strictEqual(boundedTitle.includes("\u202e"), false);

const unsafeMediaUrls = [
  "http://static.klipy.com/original/http.gif",
  "https://user:pass@static.klipy.com/original/userinfo.gif",
  "https://static.klipy.com.evil/original/lookalike.gif",
  "https://static.klipy.com:443/original/port.gif",
  "https://static.klipy.com/original/query.gif?x=1",
  "https://static.klipy.com/original/fragment.gif#x",
  " https://static.klipy.com/original/space.gif",
  "https://static.klipy.com/original/control\n.gif",
  "https://static.klipy.com/original/not-image.png",
];
unsafeMediaUrls.forEach((url, index) => {
  const records = Klipy.parseResponse(JSON.stringify({
    results: [
      providerRecord("safe-" + index, {
        gif: safeOriginalUrl,
        nanogif: safePreviewUrl,
        tinygif: safeTinyUrl,
      }),
      providerRecord("unsafe-" + index, { gif: url }),
    ],
  }));
  assert.deepStrictEqual(plain(records.map((record) => record.id)), ["safe-" + index]);
});

const recordUrlFallback = Klipy.parseResponse(JSON.stringify({
  results: [providerRecord("record-url-fallback", {
    record: safeOriginalUrl,
    gif: unsafeMediaUrls[0],
    nanogif: unsafeMediaUrls[4],
    tinygif: safeTinyUrl,
  })],
}))[0];
assert.strictEqual(recordUrlFallback.originalUrl, safeOriginalUrl);
assert.strictEqual(recordUrlFallback.previewUrl, safeTinyUrl);

const originalOnlyFallback = Klipy.parseResponse(JSON.stringify({
  results: [providerRecord("original-only-fallback", {
    gif: safeOriginalUrl,
    nanogif: unsafeMediaUrls[4],
    tinygif: unsafeMediaUrls[5],
  })],
}))[0];
assert.strictEqual(originalOnlyFallback.previewUrl, safeOriginalUrl);

const mixedPolicyRecords = Klipy.parseResponse(JSON.stringify({
  results: [
    providerRecord("safe-original", { gif: safeOriginalUrl }),
    providerRecord("unsafe-original", {
      record: unsafeMediaUrls[2],
      gif: unsafeMediaUrls[0],
    }),
  ],
}));
assert.deepStrictEqual(plain(mixedPolicyRecords.map((record) => record.id)), ["safe-original"]);

const unsafePreviewRecord = Object.assign(result("unsafe-preview"), {
  previewUrl: unsafeMediaUrls[4],
  shareUrl: unsafeMediaUrls[2],
});
const normalizedUnsafePreview = Model.normalizeRecord(unsafePreviewRecord);
assert.strictEqual(normalizedUnsafePreview.previewUrl, normalizedUnsafePreview.originalUrl);
assert.strictEqual(normalizedUnsafePreview.shareUrl, normalizedUnsafePreview.originalUrl);
assert.strictEqual(
  Model.normalizeRecord(Object.assign(result("unsafe-persisted"), {
    originalUrl: unsafeMediaUrls[0],
  })),
  null,
);
assert.strictEqual(
  Model.normalizeRecord(Object.assign(result("other-provider"), { provider: "other" })),
  null,
);

const policyState = Model.parseState(JSON.stringify({
  version: 1,
  favorites: [
    unsafePreviewRecord,
    Object.assign(result("unsafe-persisted"), { originalUrl: unsafeMediaUrls[0] }),
    result("safe-persisted"),
  ],
  recents: [],
}));
assert.deepStrictEqual(plain(policyState.favorites.map((record) => record.id)), [
  "unsafe-preview",
  "safe-persisted",
]);
assert.strictEqual(policyState.favorites[0].previewUrl, policyState.favorites[0].originalUrl);
assert.strictEqual(policyState.favorites[0].shareUrl, policyState.favorites[0].originalUrl);

assert.throws(() => Klipy.parseResponse("not JSON"), /Klipy response is not valid JSON/);
assert.throws(() => Klipy.parseResponse(JSON.stringify({ error: "rate limited" })), /Klipy provider error: rate limited/);
assert.throws(() => Klipy.parseResponse(JSON.stringify({ results: [{}] })), /Klipy response contained no valid results/);
assert.deepStrictEqual(
  plain(Klipy.parseResponse(JSON.stringify({ results: [fixture.results[0]], errors: [] }))).length,
  1,
);
assert.deepStrictEqual(plain(Klipy.parseResponse(JSON.stringify({ results: [] }))), []);

// Navigation stays bounded and drops to the last item in an incomplete target row.
assert.strictEqual(Model.navigate(0, "left", 6, 4), 0);
assert.strictEqual(Model.navigate(0, "up", 6, 4), 0);
assert.strictEqual(Model.navigate(5, "right", 6, 4), 5);
assert.strictEqual(Model.navigate(5, "down", 6, 4), 5);
assert.strictEqual(Model.navigate(2, "down", 6, 4), 5);
assert.strictEqual(Model.navigate(3, "down", 6, 4), 5);
assert.strictEqual(Model.navigate(4, "up", 6, 4), 0);
assert.strictEqual(Model.navigate(5, "up", 6, 4), 1);
assert.strictEqual(Model.navigate(5, "home", 6, 4), 0);
assert.strictEqual(Model.navigate(0, "end", 6, 4), 5);
assert.strictEqual(Model.navigate(0, "ArrowDown", 0, 4), -1);

// Invalid, missing, and old state versions safely fall back to the empty v1 state.
assert.deepStrictEqual(plain(Model.defaultState()), { version: 1, favorites: [], recents: [] });
assert.deepStrictEqual(plain(Model.parseState(undefined)), plain(Model.defaultState()));
assert.deepStrictEqual(plain(Model.parseState("not JSON")), plain(Model.defaultState()));
assert.deepStrictEqual(plain(Model.parseState(JSON.stringify({ version: 0, favorites: [result("old")] }))), plain(Model.defaultState()));
const persisted = Model.parseState(JSON.stringify({
  version: 1,
  favorites: [result("fav"), result("fav"), { provider: "other", id: "bad" }],
  recents: [result("recent"), { provider: "klipy" }, result("recent")],
}));
assert.strictEqual(persisted.favorites.length, 1);
assert.strictEqual(persisted.recents.length, 1);
assert.strictEqual(persisted.favorites[0].originalUrl, result("fav").originalUrl);
assert.deepStrictEqual(plain(Model.parseState(Model.serializeState(persisted))), plain(persisted));

// Favorites are deduped by provider/id, newest additions are retained, and capped at 50.
let state = Model.defaultState();
const favoriteRecords = Array.from({ length: 51 }, (_, index) => result("fav-" + index));
favoriteRecords.forEach((item) => {
  state = Model.toggleFavorite(state, item);
});
assert.strictEqual(state.favorites.length, 50);
assert.strictEqual(state.favorites[0].id, "fav-50");
assert.strictEqual(state.favorites[49].id, "fav-1");
assert.strictEqual(Model.isFavorite(state, favoriteRecords[50]), true);
state = Model.toggleFavorite(state, favoriteRecords[50]);
assert.strictEqual(Model.isFavorite(state, favoriteRecords[50]), false);
assert.strictEqual(state.favorites.length, 49);

// Recents are most-recent-first, deduped, and capped at 20.
state = Model.defaultState();
const recentRecords = Array.from({ length: 21 }, (_, index) => result("recent-" + index));
recentRecords.forEach((item) => {
  state = Model.addRecent(state, item);
});
assert.strictEqual(state.recents.length, 20);
assert.strictEqual(state.recents[0].id, "recent-20");
assert.strictEqual(state.recents[19].id, "recent-1");
state = Model.addRecent(state, recentRecords[5]);
assert.strictEqual(state.recents[0].id, "recent-5");
assert.strictEqual(state.recents.filter((item) => item.id === "recent-5").length, 1);
const repeatedRecent = Model.addRecent(state, recentRecords[5]);
assert.strictEqual(
  Model.serializeState(repeatedRecent),
  Model.serializeState(state),
  "re-copying the most recent GIF must be a semantic state no-op",
);

async function assertOversizedProviderResponseIsBounded() {
  const maxFilesizeIndex = searchArgv.indexOf("--max-filesize");
  assert.notStrictEqual(maxFilesizeIndex, -1);
  const maxResponseBytes = Number(searchArgv[maxFilesizeIndex + 1]);
  assert.strictEqual(maxResponseBytes, 256 * 1024);

  const server = http.createServer((_request, response) => {
    response.on("error", () => {});
    response.writeHead(200, { "Content-Type": "application/json" });

    const chunk = Buffer.alloc(16 * 1024, "x");
    let remaining = maxResponseBytes * 2;
    const write = () => {
      while (remaining > 0) {
        const bytes = Math.min(remaining, chunk.length);
        remaining -= bytes;
        if (!response.write(chunk.subarray(0, bytes))) {
          response.once("drain", write);
          return;
        }
      }
      response.end();
    };
    write();
  });

  await new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(0, "127.0.0.1", resolve);
  });

  try {
    const address = server.address();
    assert.ok(address && typeof address === "object");
    const command = plain(Klipy.searchCommand("", 8));
    const endpointIndex = command.indexOf("https://gif-search.raycast.com/api/klipy");
    assert.notStrictEqual(endpointIndex, -1);
    command[endpointIndex] = `http://127.0.0.1:${address.port}/oversized`;

    const child = spawn(command[0], command.slice(1));
    let stdoutBytes = 0;
    let stderr = "";
    child.stdout.on("data", (data) => { stdoutBytes += data.length; });
    child.stderr.setEncoding("utf8");
    child.stderr.on("data", (data) => { stderr += data; });

    const exitCode = await new Promise((resolve, reject) => {
      child.once("error", reject);
      child.once("close", resolve);
    });

    assert.strictEqual(exitCode, 63, stderr);
    assert.ok(stdoutBytes <= maxResponseBytes, `${stdoutBytes} bytes exceeded the response cap`);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
}

assertOversizedProviderResponseIsBounded()
  .then(() => console.log("model/provider tests passed"))
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
