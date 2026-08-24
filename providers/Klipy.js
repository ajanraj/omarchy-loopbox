"use strict";

// Raycast's keyless KLIPY proxy is deliberately isolated here so the UI does
// not need to know about its URL or the provider response shape.
var KLIPY_ENDPOINT = "https://gif-search.raycast.com/api/klipy";
var DEFAULT_LIMIT = 8;
var MAX_LIMIT = 8;
var MAX_RESPONSE_BYTES = 256 * 1024;

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
  return typeof query === "string" ? query : String(query);
}

/**
 * Build an argv array for Quickshell's Process. Every user-controlled value
 * stays in its own argv element; no shell parser ever sees the query.
 */
function searchCommand(query, limit) {
  var text = queryText(query);
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

  // Whitespace-only input is the trending request and must not send q.
  if (text.trim().length > 0) {
    argv.push("--data-urlencode", "q=" + text);
  }

  return argv;
}

function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function nonEmptyText(value) {
  if (typeof value !== "string") {
    return "";
  }
  return value.trim();
}

function httpUrl(value) {
  var text = nonEmptyText(value);
  return /^https?:\/\//i.test(text) ? text : "";
}

function idText(value) {
  if (typeof value === "string") {
    return value.trim();
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
  return isObject(media) ? httpUrl(media.url) : "";
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
    return value.trim();
  }
  if (isObject(value)) {
    return nonEmptyText(value.message)
      || nonEmptyText(value.error)
      || nonEmptyText(value.code)
      || nonEmptyText(value.status)
      || "unknown provider error";
  }
  if (Array.isArray(value)) {
    return value.map(errorText).filter(Boolean).join(", ");
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
  var originalUrl = mediaUrl(gif) || httpUrl(record.url);
  if (!originalUrl) {
    return null;
  }

  var previewUrl = mediaUrl(nanogif) || mediaUrl(tinygif) || originalUrl;
  var dimensions = mediaDims(gif) || mediaDims(tinygif) || mediaDims(nanogif);
  var title = nonEmptyText(record.title) || nonEmptyText(record.content_description);

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
function parseResponse(rawText) {
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
  payload.results.forEach(function (record) {
    var normalized = normalizeRecord(record);
    if (normalized) {
      results.push(normalized);
    }
  });

  if (payload.results.length > 0 && results.length === 0) {
    throw new Error("Klipy response contained no valid results");
  }

  return results;
}

var api = {
  searchCommand: searchCommand,
  parseResponse: parseResponse,
};

// CommonJS is used by the Node VM tests. QML imports the top-level functions
// directly and has no `module` global, so this conditional is harmless there.
if (typeof module !== "undefined" && module.exports) {
  module.exports = api;
}
