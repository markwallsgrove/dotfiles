#!/usr/bin/env node
// @ts-check
// Records walkthrough plans to MP4s in the background: headless Chrome (no window, so the
// Mac stays free), the walkthrough panel in autoplay mode, and Chrome's own rendered
// frames piped into ffmpeg (no screen capture). The plan format is in ../README.md.
//
//   node record.mjs [--out <dir>] [--parallel <n>] [--format mp4|gif|both] <plan.json>...
//
// Each plan is saved as <out>/<plan name>.mp4 and/or .gif (default: next to the plan).
// Ctrl-C / SIGTERM stops every recording and keeps what was recorded so far.
import { chromium } from "playwright-core";
import { execFile, spawn } from "node:child_process";
import { mkdir, readFile, rm, stat } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { parseArgs, promisify } from "node:util";

/**
 * @typedef {{ click: string, optional?: boolean }
 *   | { type: string }
 *   | { press: string }
 *   | { waitFor: string }
 *   | { highlight: string, label?: string }
 *   | { scrollTo: string }
 *   | { wait: number }} Action
 * @typedef {{ title: string, html: string, actions?: Action[] }} Step
 * @typedef {{
 *   url: string,
 *   steps: Step[],
 *   viewport?: { width: number, height: number },
 *   readSeconds?: number,
 *   timeoutSeconds?: number,
 * }} Plan
 * @typedef {{ signal?: AbortSignal, log?: (message: string) => void }} RecordOptions
 * @typedef {import("playwright-core").Page} Page
 */

const here = path.dirname(fileURLToPath(import.meta.url));
const panelSource = await readFile(path.join(here, "..", "guide-panel.js"), "utf8");
// Installed on every page load, top frame only. Init scripts run before <html> exists.
const panelInit = `if (window === window.top) document.addEventListener("DOMContentLoaded", () => {\n${panelSource}\n}, { once: true });`;
const FPS = 25;

/**
 * Streams Chrome's rendered frames (CDP screencast) into ffmpeg at a steady frame rate,
 * repeating the last frame while the page is still.
 * @param {Page} page
 * @param {string} file
 * @param {{ width: number, height: number }} size
 * @returns {Promise<() => Promise<void>>} stops the stream and waits for the finished file
 */
async function startVideo(page, file, size) {
  const ffmpeg = spawn("ffmpeg", [
    "-loglevel", "error", "-y", "-f", "image2pipe", "-c:v", "mjpeg", "-framerate", `${FPS}`, "-i", "-",
    "-vf", `scale=${size.width}:${size.height}`, "-c:v", "libx264", "-crf", "18", "-pix_fmt", "yuv420p",
    "-movflags", "+faststart", file,
  ], { stdio: ["pipe", "ignore", "inherit"] });
  const exited = new Promise((resolve) => ffmpeg.once("close", resolve));
  const cdp = await page.context().newCDPSession(page);
  /** @type {Buffer | null} */
  let last = null;
  cdp.on("Page.screencastFrame", ({ data, sessionId }) => {
    last = Buffer.from(data, "base64");
    cdp.send("Page.screencastFrameAck", { sessionId }).catch(() => {});
  });
  await cdp.send("Page.startScreencast", { format: "jpeg", quality: 90, maxWidth: size.width * 2, maxHeight: size.height * 2 });
  const tick = setInterval(() => { if (last) ffmpeg.stdin.write(last); }, 1000 / FPS);
  return async () => {
    clearInterval(tick);
    await cdp.send("Page.stopScreencast").catch(() => {});
    ffmpeg.stdin.end();
    await exited;
  };
}

/**
 * Converts a video to a GIF with a per-video palette, small enough for a README.
 * @param {string} video
 * @param {string} gif
 * @param {{ width?: number, fps?: number }} [options]
 */
export async function toGif(video, gif, { width = 960, fps = 12 } = {}) {
  await promisify(execFile)("ffmpeg", [
    "-loglevel", "error", "-y", "-i", video, "-vf",
    `fps=${fps},scale=${width}:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse=dither=bayer:bayer_scale=4`,
    gif,
  ]);
}

/**
 * @param {Page} page
 * @param {Action} action
 */
async function act(page, action) {
  /** @param {string} selector */
  const visible = async (selector) => {
    const locator = page.locator(selector).first();
    await locator.waitFor({ state: "visible" });
    return locator.elementHandle();
  };
  if ("click" in action) {
    // Optional clicks (e.g. a cookie banner) wait briefly, then skip if nothing shows up.
    const shows = () => page.locator(action.click).first().waitFor({ state: "visible", timeout: 3000 }).then(() => true, () => false);
    if (action.optional && !(await shows())) return;
    const point = await page.evaluate((el) => window.__guide.pointTo(el), await visible(action.click));
    await page.mouse.click(point.x, point.y);
  } else if ("type" in action) {
    await page.keyboard.type(action.type, { delay: 90 });
  } else if ("press" in action) {
    await page.keyboard.press(action.press);
  } else if ("waitFor" in action) {
    await page.locator(action.waitFor).first().waitFor({ state: "visible" });
    await page.waitForFunction(() => Boolean(window.__guide));
  } else if ("highlight" in action) {
    const label = action.label;
    await page.evaluate(([el, text]) => window.__guide.highlight(el, text), /** @type {const} */ ([await visible(action.highlight), label]));
  } else if ("scrollTo" in action) {
    const target = action.scrollTo;
    if (target === "top") await page.evaluate(() => window.scrollTo({ top: 0, behavior: "smooth" }));
    else await page.evaluate((el) => el.scrollIntoView({ block: "center", behavior: "smooth" }), await visible(target));
    await page.waitForTimeout(800);
  } else if ("wait" in action) {
    await page.waitForTimeout(action.wait);
  }
}

/**
 * Records one plan to `file`: an MP4, or a GIF when it ends in .gif. Resolves with the
 * panel events once the last step closes; rejects if a step fails or the signal aborts
 * (the file keeps what was recorded so far).
 * @param {Plan} plan
 * @param {string} file
 * @param {RecordOptions} [options]
 * @returns {Promise<{ file: string, events: string[] }>}
 */
export async function record(plan, file, { signal, log = () => {} } = {}) {
  signal?.throwIfAborted();
  const size = plan.viewport ?? { width: 1280, height: 800 };
  const gif = path.extname(file).toLowerCase() === ".gif";
  const video = gif ? `${file}.tmp.mp4` : file;
  const browser = await chromium.launch({ channel: "chrome", headless: true });
  const onAbort = () => { browser.close().catch(() => {}); };
  signal?.addEventListener("abort", onAbort, { once: true });
  let stopVideo = async () => {};
  /** @type {string[]} */
  const events = [];
  try {
    const context = await browser.newContext({ viewport: size, deviceScaleFactor: 2 });
    context.setDefaultTimeout((plan.timeoutSeconds ?? 30) * 1000);
    await context.addInitScript(panelInit);
    const page = await context.newPage();
    stopVideo = await startVideo(page, video, size);
    await page.goto(plan.url);
    await page.waitForFunction(() => Boolean(window.__guide));
    await page.evaluate((seconds) => window.__guide.autoplay(seconds), plan.readSeconds ?? true);

    const total = plan.steps.length;
    for (const [i, step] of plan.steps.entries()) {
      log(`step ${i + 1}/${total}: ${step.title}`);
      await page.evaluate(() => { window.__guide.busy(true); window.__guide.clearHighlights(); });
      for (const action of step.actions ?? []) await act(page, action);
      await page.evaluate((shown) => { window.__guide.show(shown); window.__guide.busy(false); },
        { step: i + 1, total, title: step.title, html: step.html });
      const event = await page.evaluate(() => window.__guide.waitForEvent(600000));
      if (!event) throw new Error(`step ${i + 1} never finished`);
      events.push(event.type);
    }
    await page.waitForTimeout(500);
    return { file, events };
  } catch (error) {
    if (signal?.aborted) throw new Error("recording stopped", { cause: error });
    throw error;
  } finally {
    signal?.removeEventListener("abort", onAbort);
    await stopVideo();
    await browser.close().catch(() => {});
    if (gif) {
      if (await stat(video).catch(() => null)) await toGif(video, file);
      await rm(video, { force: true });
    }
  }
}

async function main() {
  const { values, positionals } = parseArgs({
    allowPositionals: true,
    options: {
      out: { type: "string" },
      parallel: { type: "string", default: "2" },
      format: { type: "string", default: "mp4" },
    },
  });
  const format = values.format;
  if (positionals.length === 0 || (format !== "mp4" && format !== "gif" && format !== "both")) {
    console.error("usage: node record.mjs [--out <dir>] [--parallel <n>] [--format mp4|gif|both] <plan.json>...");
    process.exit(2);
  }
  const controller = new AbortController();
  for (const sig of /** @type {const} */ (["SIGINT", "SIGTERM"])) {
    process.once(sig, () => {
      console.error(`${sig}: stopping recordings`);
      controller.abort();
    });
  }

  const queue = [...positionals];
  let failed = 0;
  const worker = async () => {
    for (let planPath = queue.shift(); planPath && !controller.signal.aborted; planPath = queue.shift()) {
      const name = path.basename(planPath, ".json");
      const started = Date.now();
      /** @param {string} message */
      const log = (message) => console.log(`[${name} +${((Date.now() - started) / 1000).toFixed(1)}s] ${message}`);
      try {
        /** @type {Plan} */
        const plan = JSON.parse(await readFile(planPath, "utf8"));
        const dir = values.out ?? path.dirname(planPath);
        await mkdir(dir, { recursive: true });
        const base = path.join(dir, name);
        const { file } = await record(plan, `${base}.${format === "gif" ? "gif" : "mp4"}`, { signal: controller.signal, log });
        log(`saved ${file}`);
        if (format === "both") {
          await toGif(file, `${base}.gif`);
          log(`saved ${base}.gif`);
        }
      } catch (error) {
        failed += 1;
        log(`failed: ${error instanceof Error ? error.message : String(error)}`);
      }
    }
  };
  const parallel = Math.max(1, Number(values.parallel) || 1);
  await Promise.all(Array.from({ length: parallel }, worker));
  process.exitCode = controller.signal.aborted ? 130 : failed ? 1 : 0;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) await main();
