// Timer polyfill for Deno compatibility.
// Deno's setTimeout/setInterval return plain numbers (web-standard),
// but cli.js expects Node.js Timeout objects with .unref()/.ref().

const origSetTimeout = globalThis.setTimeout;
const origSetInterval = globalThis.setInterval;
const origClearTimeout = globalThis.clearTimeout;
const origClearInterval = globalThis.clearInterval;

function wrapTimer(id) {
  return {
    id,
    ref() { return this; },
    unref() { return this; },
    hasRef() { return true; },
    refresh() { return this; },
    [Symbol.toPrimitive]() { return id; },
  };
}

function unwrapTimer(timer) {
  if (timer != null && typeof timer === "object" && "id" in timer) {
    return timer.id;
  }
  return timer;
}

globalThis.setTimeout = function (cb, ms, ...args) {
  return wrapTimer(origSetTimeout(cb, ms, ...args));
};

globalThis.setInterval = function (cb, ms, ...args) {
  return wrapTimer(origSetInterval(cb, ms, ...args));
};

globalThis.clearTimeout = function (timer) {
  origClearTimeout(unwrapTimer(timer));
};

globalThis.clearInterval = function (timer) {
  origClearInterval(unwrapTimer(timer));
};

// Load the actual CLI
await import(new URL("./node_modules/@anthropic-ai/claude-code/cli.js", import.meta.url));
