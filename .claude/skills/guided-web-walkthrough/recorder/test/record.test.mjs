// @ts-check
// End-to-end tests: real headless Chrome and ffmpeg, against a local fixture page.
import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { mkdtemp, readdir, readFile, rm } from "node:fs/promises";
import { createServer } from "node:http";
import { tmpdir } from "node:os";
import path from "node:path";
import { after, before, test } from "node:test";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";
import { record } from "../record.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const fixture = await readFile(path.join(here, "fixture.html"));
const server = createServer((_req, res) => {
  res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
  res.end(fixture);
});
/** @type {string} */
let url;
/** @type {string} */
let dir;

before(async () => {
  await new Promise((resolve) => server.listen(0, "127.0.0.1", () => resolve(undefined)));
  const address = server.address();
  assert.ok(address && typeof address === "object");
  url = `http://127.0.0.1:${address.port}/`;
  dir = await mkdtemp(path.join(tmpdir(), "recorder-test-"));
});

after(async () => {
  server.close();
  await rm(dir, { recursive: true, force: true });
});

/**
 * @param {string} file
 * @returns {Promise<{ width: number, height: number, duration: number }>}
 */
async function probe(file) {
  const { stdout } = await promisify(execFile)("ffprobe", [
    "-v", "error", "-select_streams", "v:0",
    "-show_entries", "stream=width,height:format=duration", "-of", "json", file,
  ]);
  const info = JSON.parse(stdout);
  return { width: info.streams[0].width, height: info.streams[0].height, duration: Number(info.format.duration) };
}

test("records every step, then closes, to a playable MP4", async () => {
  const file = path.join(dir, "steps.mp4");
  const result = await record({
    url,
    readSeconds: 1,
    steps: [
      { title: "Overview", html: "<p>Start.</p>" },
      {
        title: "Click Go",
        html: "<p>I clicked Go.</p>",
        actions: [{ click: "#go" }, { waitFor: "#done" }, { highlight: "#done", label: "Result" }],
      },
    ],
  }, file);
  assert.deepEqual(result.events, ["next", "close"]);
  const video = await probe(file);
  assert.equal(video.width, 1280);
  assert.equal(video.height, 800);
  assert.ok(video.duration >= 2, `duration ${video.duration}s covers two 1 s steps`);
});

test("writes a GIF, and no leftover video, when the file ends in .gif", async () => {
  const file = path.join(dir, "steps.gif");
  await record({ url, readSeconds: 1, steps: [{ title: "Overview", html: "<p>Start.</p>" }] }, file);
  const { stdout } = await promisify(execFile)("ffprobe", [
    "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=codec_name,width", "-of", "json", file,
  ]);
  const stream = JSON.parse(stdout).streams[0];
  assert.equal(stream.codec_name, "gif");
  assert.equal(stream.width, 960);
  assert.deepEqual((await readdir(dir)).filter((name) => name.startsWith("steps.gif")), ["steps.gif"]);
});

test("skips an optional click whose element is missing", async () => {
  const result = await record({
    url,
    readSeconds: 1,
    steps: [{ title: "Banner", html: "<p>No banner here.</p>", actions: [{ click: "#cookie-banner", optional: true }] }],
  }, path.join(dir, "optional.mp4"));
  assert.deepEqual(result.events, ["close"]);
});

test("fails when a required element is missing", async () => {
  await assert.rejects(record({
    url,
    readSeconds: 1,
    timeoutSeconds: 2,
    steps: [{ title: "Missing", html: "<p>Never shown.</p>", actions: [{ click: "#missing" }] }],
  }, path.join(dir, "missing.mp4")));
});

test("stops on abort and still leaves a playable file", async () => {
  const file = path.join(dir, "aborted.mp4");
  const controller = new AbortController();
  setTimeout(() => controller.abort(), 3000);
  await assert.rejects(record({
    url,
    readSeconds: 60,
    steps: [{ title: "Long", html: "<p>Long step.</p>" }],
  }, file, { signal: controller.signal }));
  const video = await probe(file);
  assert.ok(video.duration > 1, `partial recording of ${video.duration}s`);
});
