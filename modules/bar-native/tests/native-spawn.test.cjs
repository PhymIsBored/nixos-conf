"use strict";

const assert = require("node:assert/strict");
const { test } = require("node:test");
const { createAdapter } = require("../native-spawn.cjs");

function fixture() {
  const calls = [];
  const child = { pid: 123 };
  const implementation = Object.fromEntries(
    ["spawn", "execFile"].map((method) => [method, (...args) => {
      calls.push({ method, args });
      return child;
    }]),
  );
  return { adapter: createAdapter("/nix/store/test-runtime", implementation), calls, child };
}

for (const name of ["spring", "spring-headless", "spring-dedicated", "pr-downloader"]) {
  test(`routes ${name} without changing arguments or process options`, () => {
    const { adapter, calls, child } = fixture();
    const binary = `/assets/engine/version with spaces/${name}`;
    const args = ["--write-dir", "/state with spaces", "spring://user:password@host:8200"];
    const options = { cwd: "/engine", stdio: "pipe", detached: true, env: { SPRING_DATADIR: "/assets" } };
    assert.equal(adapter.spawn(binary, args, options), child);
    assert.deepEqual(calls, [{ method: "spawn", args: ["/nix/store/test-runtime", [binary, ...args], options] }]);
    assert.deepEqual(args, ["--write-dir", "/state with spaces", "spring://user:password@host:8200"]);
  });
}

test("execFile preserves its callback, including the omitted-args overload", () => {
  const { adapter, calls } = fixture();
  const callback = () => {};
  adapter.execFile("/engine/pr-downloader", ["--help"], callback);
  adapter.execFile("/engine/pr-downloader", { timeout: 5000 }, callback);
  adapter.execFile("/engine/pr-downloader", callback);
  assert.deepEqual(calls.map(({ args }) => args), [
    ["/nix/store/test-runtime", ["/engine/pr-downloader", "--help"], callback],
    ["/nix/store/test-runtime", ["/engine/pr-downloader"], { timeout: 5000 }, callback],
    ["/nix/store/test-runtime", ["/engine/pr-downloader"], callback],
  ]);
});

test("unrelated commands pass through unchanged", () => {
  const { adapter, calls } = fixture();
  adapter.spawn("/usr/bin/xdg-open", ["https://beyondallreason.info"]);
  adapter.spawn("spring", ["--version"]);
  adapter.execFile("/engine/7za", ["x", "archive.7z"]);
  assert.deepEqual(calls.map(({ args }) => args), [
    ["/usr/bin/xdg-open", ["https://beyondallreason.info"]],
    ["spring", ["--version"]],
    ["/engine/7za", ["x", "archive.7z"]],
  ]);
});
