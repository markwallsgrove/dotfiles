# Guided web walkthrough

A Claude Code skill that walks you through a website in your own Chrome. Claude drives the site (real clicks and typing) and explains each step in a small panel on the page. You set the pace with **Next** / **Previous**, and you can type questions into the panel at any time.

It can also record a walkthrough hands-free, in the background, as a video or GIF: see [Record a video or GIF](#record-a-video-or-gif).

![Demo: Claude shows how to find UK bank holidays on GOV.UK: search, open the list, then answer a question about Scotland](assets/demo.gif)

## What it is for

- Demo a code change or a new feature on a local or staging app.
- Tour a site, or one area of it, step by step.
- Review a change with Claude: issues you raise in the panel are collected as notes.
- Record a demo video or GIF for a README, a PR or a release note, without tying up your screen.

## How it works

![The panel on a step, with the explained element highlighted](assets/screenshot.jpg)

1. Claude plans the story: one step per point, starting with an overview and ending with "Any other questions?".
2. Claude starts `guide-relay.py`, a small local server on `127.0.0.1:47610`, and injects `guide-panel.js` into the page with the Claude in Chrome extension.
3. On each **Next**, Claude moves a visible pointer to the target, clicks or types, highlights the elements it talks about, and shows the explanation in the panel.
4. A message typed into the panel goes to Claude, and the answer appears under the step.
5. On the last step, **Next** becomes **Close**. Claude stops the relay and lists the notes you raised.

The panel sends each click and message to the relay, and the relay prints it as one line on stdout. Claude watches that output with the Monitor tool, so it reacts as soon as you click. Some public sites block calls to `127.0.0.1` with a Content Security Policy. On those sites Claude waits for events inside the page instead (`__guide.waitForEvent`).

## Files

- `SKILL.md`: the instructions Claude follows.
- `guide-panel.js`: the panel. It works on any site; Claude passes in each step's content. The API is at the top of the file.
- `guide-relay.py`: the event relay (Python standard library only).
- `tests/panel.html`: browser tests for the panel (overlap, spinner and autoplay).
- `recorder/`: the background recorder (`record.mjs`), its tests and example plans.

## Use it

Ask Claude something like:

- "Walk me through the changes on this branch in the app."
- "Explain how to use bbc.co.uk/weather."

Requires the Claude in Chrome extension. On sites you don't own, Claude asks before it creates, changes, sends, buys or deletes anything. You type credentials and payment details yourself.

## Record a video or GIF

![Automated recording: each step's actions run, then its text stays up with a countdown before the next step](assets/recording.gif)

Claude can record a walkthrough without you watching. It runs in a hidden (headless) Chrome with no window, so you can keep working, switch desktops, or queue several recordings at once. Each step runs its actions first (pointer, clicks, typing, highlights) while the panel shows a spinner. The step's text then stays up long enough for a slow-to-medium reader (2 s plus 180 words a minute, at least 5 s), with a countdown, before the next step starts. That is long enough to pause the video and read.

Ask Claude something like:

- "Record a video walkthrough of the new settings page."
- "Make a GIF of how to search on docs.python.org for the README."

Claude explores the site live first to find each element, writes a plan (a JSON list of steps), and records it in the background. You get an MP4 (sharp and small), a GIF (plays inline in READMEs and PRs, but larger, with fewer colours), or both.

To run the recorder yourself (needs Google Chrome and ffmpeg):

```sh
cd ~/.claude/skills/guided-web-walkthrough/recorder
npm ci --omit=dev
node record.mjs --format both --out ~/Movies examples/bbc-weather.json examples/python-docs.json
```

- `--format mp4|gif|both` (default `mp4`), `--out <dir>` (default: next to each plan), `--parallel <n>` (default 2).
- Ctrl-C stops the recordings and keeps what was recorded so far.
- The plan format is described in `SKILL.md` under **Recorded walkthrough**; `recorder/examples/` has two plans.
- To turn an existing MP4 into a GIF:

  ```sh
  ffmpeg -i in.mp4 -vf "fps=12,scale=960:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse=dither=bayer:bayer_scale=4" out.gif
  ```

Each recording starts from a fresh browser profile: no logins, and cookie banners appear (plans dismiss them with their reject button). Recording while the screen is locked has not been verified yet.

## Test

The test needs a real browser, because it relies on smooth scrolling:

```sh
python3 -m http.server -d ~/.claude/skills/guided-web-walkthrough 8000
open http://127.0.0.1:8000/tests/panel.html
```

The page shows `RESULT: PASS` or `RESULT: FAIL`, with one line per case.

The recorder has end-to-end tests (real headless Chrome and ffmpeg) and a strict type check:

```sh
cd ~/.claude/skills/guided-web-walkthrough/recorder
npm ci
npm test
npm run check
```
