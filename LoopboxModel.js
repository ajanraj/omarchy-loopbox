"use strict";

var STATE_VERSION = 1;
var MAX_FAVORITES = 50;
var MAX_RECENTS = 20;
var DEFAULT_COLUMNS = 4;

function defaultState() {
  return { version: STATE_VERSION, favorites: [], recents: [] };
}

function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function text(value) {
  return typeof value === "string" ? value.trim() : "";
}

function nonNegativeInteger(value) {
  var numeric = Number(value);
  if (!isFinite(numeric) || numeric < 0) {
    return 0;
  }
  return Math.floor(numeric);
}

function recordKey(record) {
  if (!isObject(record)) {
    return "";
  }
  var provider = text(record.provider);
  var id = text(record.id);
  return provider && id ? provider + "\u0000" + id : "";
}

/**
 * Copy the stable result contract used by the provider. Reconstructing records
 * on load keeps favorites and recents usable when the provider is offline.
 */
function normalizeRecord(record) {
  if (!isObject(record)) {
    return null;
  }

  var provider = text(record.provider);
  var id = text(record.id);
  var originalUrl = text(record.originalUrl);
  if (!provider || !id || !originalUrl) {
    return null;
  }

  var previewUrl = text(record.previewUrl) || originalUrl;
  return {
    provider: provider,
    id: id,
    title: text(record.title),
    pageUrl: text(record.pageUrl),
    shareUrl: text(record.shareUrl) || originalUrl,
    originalUrl: originalUrl,
    previewUrl: previewUrl,
    width: nonNegativeInteger(record.width),
    height: nonNegativeInteger(record.height),
    bytes: nonNegativeInteger(record.bytes),
  };
}

function dedupeRecords(records, max) {
  if (!Array.isArray(records)) {
    return [];
  }

  var output = [];
  var seen = Object.create(null);
  records.forEach(function (record) {
    var normalized = normalizeRecord(record);
    var key = recordKey(normalized);
    if (!key || seen[key]) {
      return;
    }
    seen[key] = true;
    output.push(normalized);
  });
  return output.slice(0, max);
}

function normalizeState(state) {
  if (!isObject(state) || state.version !== STATE_VERSION) {
    return defaultState();
  }
  return {
    version: STATE_VERSION,
    favorites: dedupeRecords(state.favorites, MAX_FAVORITES),
    recents: dedupeRecords(state.recents, MAX_RECENTS),
  };
}

/**
 * Parse persisted JSON defensively. Corrupt data and unsupported versions are
 * treated as an empty current state; the overlay can then rewrite it safely.
 */
function parseState(rawOrObject) {
  var value = rawOrObject;
  if (typeof rawOrObject === "string") {
    if (!rawOrObject.trim()) {
      return defaultState();
    }
    try {
      value = JSON.parse(rawOrObject);
    } catch (error) {
      return defaultState();
    }
  }
  return normalizeState(value);
}

function serializeState(state) {
  return JSON.stringify(normalizeState(state));
}

function listForFavorites(stateOrFavorites) {
  if (Array.isArray(stateOrFavorites)) {
    return stateOrFavorites;
  }
  return isObject(stateOrFavorites) && Array.isArray(stateOrFavorites.favorites)
    ? stateOrFavorites.favorites
    : [];
}

function stateForMutation(stateOrFavorites) {
  if (Array.isArray(stateOrFavorites)) {
    return null;
  }
  return normalizeState(stateOrFavorites);
}

function findRecordIndex(records, target) {
  var key = recordKey(target);
  if (!key) {
    return -1;
  }
  for (var index = 0; index < records.length; index += 1) {
    if (recordKey(records[index]) === key) {
      return index;
    }
  }
  return -1;
}

function isFavorite(stateOrFavorites, maybeResult) {
  var favorites = stateOrFavorites;
  var target = maybeResult;
  // Accept the natural `(state, result)` form and the convenient
  // `(result, favorites)` form for QML delegates.
  if (!Array.isArray(favorites) && isObject(favorites) && Array.isArray(favorites.favorites)) {
    favorites = favorites.favorites;
  } else if (isObject(favorites) && !Array.isArray(favorites) && Array.isArray(maybeResult)) {
    target = stateOrFavorites;
    favorites = maybeResult;
  }
  return findRecordIndex(dedupeRecords(favorites, MAX_FAVORITES), target) !== -1;
}

function toggleFavorite(stateOrFavorites, result) {
  var target = normalizeRecord(result);
  var source = dedupeRecords(listForFavorites(stateOrFavorites), MAX_FAVORITES);
  if (!target) {
    return Array.isArray(stateOrFavorites) ? source : normalizeState(stateOrFavorites);
  }

  var index = findRecordIndex(source, target);
  if (index >= 0) {
    source.splice(index, 1);
  } else {
    source.unshift(target);
    source = source.slice(0, MAX_FAVORITES);
  }

  if (Array.isArray(stateOrFavorites)) {
    return source;
  }
  var state = stateForMutation(stateOrFavorites);
  state.favorites = source;
  return state;
}

function listForRecents(stateOrRecents) {
  if (Array.isArray(stateOrRecents)) {
    return stateOrRecents;
  }
  return isObject(stateOrRecents) && Array.isArray(stateOrRecents.recents)
    ? stateOrRecents.recents
    : [];
}

function addRecent(stateOrRecents, result) {
  var target = normalizeRecord(result);
  var source = dedupeRecords(listForRecents(stateOrRecents), MAX_RECENTS);
  if (target) {
    source = source.filter(function (record) {
      return recordKey(record) !== recordKey(target);
    });
    source.unshift(target);
    source = source.slice(0, MAX_RECENTS);
  }

  if (Array.isArray(stateOrRecents)) {
    return source;
  }
  var state = stateForMutation(stateOrRecents);
  state.recents = source;
  return state;
}

function normalizedDirection(direction) {
  if (typeof direction === "number") {
    // Qt.Key_* values used by QML's Keys handler.
    return {
      16777232: "home",
      16777233: "end",
      16777234: "left",
      16777235: "up",
      16777236: "right",
      16777237: "down",
    }[direction] || "";
  }

  var value = text(direction).toLowerCase();
  if (value.indexOf("arrow") === 0) {
    value = value.slice(5);
  }
  return value;
}

/**
 * Return the next bounded grid index. Vertical movement preserves a column
 * where possible and clamps to the final item when the last row is partial.
 */
function navigate(index, direction, itemCount, columns) {
  var count = Math.max(0, Math.floor(Number(itemCount)) || 0);
  if (count === 0) {
    return -1;
  }

  var columnCount = Math.max(1, Math.floor(Number(columns)) || DEFAULT_COLUMNS);
  var current = Math.floor(Number(index));
  if (!isFinite(current)) {
    current = 0;
  }
  current = Math.max(0, Math.min(count - 1, current));

  var move = normalizedDirection(direction);
  if (move === "home") {
    return 0;
  }
  if (move === "end") {
    return count - 1;
  }
  if (move === "left") {
    return Math.max(0, current - 1);
  }
  if (move === "right") {
    return Math.min(count - 1, current + 1);
  }

  var row = Math.floor(current / columnCount);
  var column = current % columnCount;
  var rowCount = Math.ceil(count / columnCount);
  if (move === "up") {
    if (row === 0) {
      return current;
    }
    return (row - 1) * columnCount + column;
  }
  if (move === "down") {
    if (row >= rowCount - 1) {
      return current;
    }
    return Math.min(count - 1, (row + 1) * columnCount + column);
  }
  return current;
}

// Descriptive aliases make the same pure operation easy to call from QML.
function moveSelection(index, direction, itemCount, columns) {
  return navigate(index, direction, itemCount, columns);
}

function navigationIndex(index, direction, itemCount, columns) {
  return navigate(index, direction, itemCount, columns);
}

var api = {
  STATE_VERSION: STATE_VERSION,
  MAX_FAVORITES: MAX_FAVORITES,
  MAX_RECENTS: MAX_RECENTS,
  defaultState: defaultState,
  normalizeRecord: normalizeRecord,
  normalizeState: normalizeState,
  parseState: parseState,
  serializeState: serializeState,
  isFavorite: isFavorite,
  toggleFavorite: toggleFavorite,
  addRecent: addRecent,
  navigate: navigate,
  moveSelection: moveSelection,
  navigationIndex: navigationIndex,
};

if (typeof module !== "undefined" && module.exports) {
  module.exports = api;
}
