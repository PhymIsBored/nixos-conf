"use strict";

const childProcess = require("node:child_process");
const path = require("node:path");

const nativeBinaries = new Set([
  "spring",
  "spring-headless",
  "spring-dedicated",
  "pr-downloader",
]);

// Export a private adapter rather than monkey-patching Node globally. The
// package build replaces only the Lobby main bundle's child_process import.
function createAdapter(runtime, implementation = childProcess) {
  function wrap(method) {
    return function (file, ...parameters) {
      if (path.isAbsolute(file) && nativeBinaries.has(path.basename(file))) {
        // spawn and execFile allow args to be omitted. Retain options,
        // callbacks, cwd, stdio and detached without shell quoting or parsing.
        const args = Array.isArray(parameters[0]) ? parameters.shift() : [];
        return implementation[method](runtime, [file, ...args], ...parameters);
      }
      return implementation[method](file, ...parameters);
    };
  }

  return {
    ...implementation,
    spawn: wrap("spawn"),
    execFile: wrap("execFile"),
  };
}

module.exports = createAdapter("@runtime@");
module.exports.createAdapter = createAdapter;
