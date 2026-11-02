"use strict";

const childProcess = require("node:child_process");
const path = require("node:path");

const nativeBinaries = new Set([
  "spring",
  "spring-headless",
  "spring-dedicated",
  "pr-downloader",
]);

function spawn(file, ...parameters) {
  if (typeof file === "string" && path.isAbsolute(file) && nativeBinaries.has(path.basename(file))) {
    const args = Array.isArray(parameters[0]) ? parameters.shift() : [];
    return childProcess.spawn("@runtime@", [file, ...args], ...parameters);
  }

  return childProcess.spawn(file, ...parameters);
}

module.exports = { spawn };
