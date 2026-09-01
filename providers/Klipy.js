"use strict";

// Raycast's keyless KLIPY proxy is deliberately isolated here so the UI does
// not need to know about its URL or the provider response shape.
var KLIPY_ENDPOINT = "https://gif-search.raycast.com/api/klipy";
var DEFAULT_LIMIT = 24;
var MAX_LIMIT = 24;
var MAX_RESPONSE_BYTES = 256 * 1024;
var MAX_QUERY_LENGTH = 120;
var MAX_CURSOR_LENGTH = 128;
var MAX_ID_LENGTH = 128;
var MAX_TITLE_LENGTH = 180;
var MAX_URL_LENGTH = 2048;
var KLIPY_MEDIA_PREFIX = "https://static.klipy.com/";

function safeLimit(limit) {
  var numeric = Number(limit);
  if (!isFinite(numeric) || numeric < 1) {
    return DEFAULT_LIMIT;
  }
  return Math.min(MAX_LIMIT, Math.floor(numeric));
}

function queryText(query) {
  if (query === null || query === undefined) {
    return "";
  }
  var text = typeof query === "string" ? query : String(query);
  return text.slice(0, MAX_QUERY_LENGTH);
}

function safeCursor(cursor) {
  if (typeof cursor !== "string" || cursor.length < 1 || cursor.length > MAX_CURSOR_LENGTH) {
    return "";
  }
  return /^[A-Za-z0-9_-]+={0,2}$/.test(cursor) ? cursor : "";
}

/**
 * Build an argv array for Quickshell's Process. Every user-controlled value
 * stays in its own argv element; no shell parser ever sees the query.
 */
function searchCommand(query, limit, cursor) {
  var text = queryText(query);
  var position = safeCursor(cursor);
  var argv = [
    "curl",
    "--fail",
    "--silent",
    "--show-error",
    "--connect-timeout",
    "3",
    "--max-time",
    "8",
    "--max-filesize",
    String(MAX_RESPONSE_BYTES),
    "--get",
    KLIPY_ENDPOINT,
    "--data-urlencode",
    "locale=en",
    "--data-urlencode",
    "media_filter=gif,nanogif,tinygif",
    "--data-urlencode",
    "limit=" + safeLimit(limit),
  ];

  if (position) {
    argv.push("--data-urlencode", "pos=" + position);
  }

  // Whitespace-only input is the trending request and must not send q.
  if (text.trim().length > 0) {
    argv.push("--data-urlencode", "q=" + text);
  }

  return argv;
}

function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function nonEmptyText(value, maximum) {
  if (typeof value !== "string") {
    return "";
  }
  var limit = Number(maximum) > 0 ? Math.floor(Number(maximum)) : MAX_TITLE_LENGTH;
  return value
    .slice(0, limit)
    .replace(/[\x00-\x1f\x7f-\x9f\u202a-\u202e\u2066-\u2069]/g, " ")
    .trim();
}

function httpUrl(value) {
  var text = nonEmptyText(value, MAX_URL_LENGTH);
  return /^https?:\/\//i.test(text) ? text : "";
}

/**
 * Keep provider media URLs on the exact static host. This is deliberately
 * string-based because QML's JavaScript runtime does not consistently expose
 * the WHATWG URL parser.
 */
function safeKlipyMediaUrl(value) {
  if (typeof value !== "string" || !value || value.length > MAX_URL_LENGTH) {
    return "";
  }
  if (/[\s\x00-\x1f\x7f-\x9f]/.test(value)) {
    return "";
  }
  if (value.indexOf(KLIPY_MEDIA_PREFIX) !== 0) {
    return "";
  }

  var path = value.slice(KLIPY_MEDIA_PREFIX.length);
  if (!path || path.indexOf("?") !== -1 || path.indexOf("#") !== -1) {
    return "";
  }
  return path.slice(-4) === ".gif" ? value : "";
}

function idText(value) {
  if (typeof value === "string") {
    return nonEmptyText(value, MAX_ID_LENGTH);
  }
  if (typeof value === "number" && isFinite(value)) {
    return String(value);
  }
  return "";
}

function nonNegativeInteger(value) {
  var numeric = Number(value);
  if (!isFinite(numeric) || numeric < 0) {
    return 0;
  }
  return Math.floor(numeric);
}

function mediaObject(media) {
  return isObject(media) ? media : {};
}

function mediaUrl(media) {
  return isObject(media) ? safeKlipyMediaUrl(media.url) : "";
}

function mediaDims(media) {
  if (!isObject(media) || !Array.isArray(media.dims) || media.dims.length < 2) {
    return null;
  }
  var width = nonNegativeInteger(media.dims[0]);
  var height = nonNegativeInteger(media.dims[1]);
  return width > 0 && height > 0 ? { width: width, height: height } : null;
}

function errorText(value) {
  if (typeof value === "string") {
    return nonEmptyText(value, 240);
  }
  if (isObject(value)) {
    return nonEmptyText(value.message, 240)
      || nonEmptyText(value.error, 240)
      || nonEmptyText(value.code, 80)
      || nonEmptyText(value.status, 80)
      || "unknown provider error";
  }
  if (Array.isArray(value)) {
    return value.slice(0, 8).map(errorText).filter(Boolean).join(", ").slice(0, 240);
  }
  return value === undefined || value === null ? "unknown provider error" : String(value);
}

function normalizeRecord(record) {
  if (!isObject(record)) {
    return null;
  }

  var id = idText(record.id);
  if (!id) {
    return null;
  }

  var media = mediaObject(record.media_formats);
  var gif = mediaObject(media.gif);
  var nanogif = mediaObject(media.nanogif);
  var tinygif = mediaObject(media.tinygif);
  var originalUrl = mediaUrl(gif) || safeKlipyMediaUrl(record.url);
  if (!originalUrl) {
    return null;
  }

  var previewUrl = mediaUrl(nanogif) || mediaUrl(tinygif) || originalUrl;
  var dimensions = mediaDims(gif) || mediaDims(tinygif) || mediaDims(nanogif);
  var title = nonEmptyText(record.title, MAX_TITLE_LENGTH)
    || nonEmptyText(record.content_description, MAX_TITLE_LENGTH);

  return {
    provider: "klipy",
    id: id,
    title: title,
    pageUrl: httpUrl(record.itemurl),
    shareUrl: originalUrl,
    originalUrl: originalUrl,
    previewUrl: previewUrl,
    width: dimensions ? dimensions.width : 0,
    height: dimensions ? dimensions.height : 0,
    bytes: nonNegativeInteger(gif.size),
  };
}

/**
 * Validate and normalize one provider response. Individual bad records are
 * skipped, but a response with no usable records is surfaced to the UI as an
 * actionable provider error rather than looking like an empty search.
 */
function parsePage(rawText) {
  if (typeof rawText !== "string") {
    throw new Error("Klipy response must be JSON text");
  }

  var payload;
  try {
    payload = JSON.parse(rawText);
  } catch (error) {
    throw new Error("Klipy response is not valid JSON: " + error.message);
  }

  if (!isObject(payload)) {
    throw new Error("Klipy response must be a JSON object");
  }

  var providerError = payload.error;
  if (!providerError && Array.isArray(payload.errors)) {
    providerError = payload.errors.length > 0 ? payload.errors : null;
  } else if (!providerError) {
    providerError = payload.errors;
  }
  if (!providerError && payload.message && !Array.isArray(payload.results)) {
    providerError = payload.message;
  }
  if (providerError) {
    throw new Error("Klipy provider error: " + errorText(providerError));
  }

  if (!Array.isArray(payload.results)) {
    throw new Error("Klipy response is missing its results array");
  }

  var results = [];
  payload.results.slice(0, MAX_LIMIT).forEach(function (record) {
    var normalized = normalizeRecord(record);
    if (normalized) {
      results.push(normalized);
    }
  });

  if (payload.results.length > 0 && results.length === 0) {
    throw new Error("Klipy response contained no valid results");
  }

  return {
    results: results,
    next: results.length > 0 ? safeCursor(payload.next) : "",
  };
}

function parseResponse(rawText) {
  return parsePage(rawText).results;
}

var api = {
  searchCommand: searchCommand,
  parsePage: parsePage,
  parseResponse: parseResponse,
};

// CommonJS is used by the Node VM tests. QML imports the top-level functions
// directly and has no `module` global, so this conditional is harmless there.
if (typeof module !== "undefined" && module.exports) {
  module.exports = api;
}
