// Guided web walkthrough panel: a generic, site-agnostic overlay the agent injects into
// any page. The agent sets every step's content; the viewer paces it with
// Next/Previous and can type messages. Nothing about the site lives in this file.
//
// API (window.__guide):
//   connect(relayUrl)          send every viewer event to the local relay too
//   show({ step, total, title, html })   render a step (persisted across reloads)
//   say(html)                  answer the viewer's latest message; the step text stays,
//                              and each question with its answer stacks below it
//   status(text)               small status line
//   busy(isBusy)               disable the controls while the agent acts
//   waitForEvent(timeoutMs)    next viewer event { type: "next"|"prev"|"message"|"close", text?, step }
//                              or null on timeout; resolves the moment it happens
//   highlight(target, label?)  outline an element (selector, element, or visible text);
//                              the panel moves aside if it would cover it
//   clearHighlights()
//   pointTo(target)            glide the visible pointer to an element; returns its
//                              centre { x, y, viewportWidth } in CSS px
//   find(text)                 first visible element whose text or label matches
//
// On the last step Next becomes Close: it removes the panel, forgets its state, and
// sends a "close" event.
// The panel lives in a shadow root, so page styles and text searches never see it.
// It saves its own source in sessionStorage; after a full page load restore it with:
//   (0, eval)(sessionStorage.getItem("__guide_src"))
(function installGuide() {
  try { sessionStorage.setItem("__guide_src", `(${installGuide})()`); } catch { /* storage blocked */ }
  if (window.__guide) return "guide already present";

  const STORE = "__guide_state";
  const read = () => { try { return JSON.parse(sessionStorage.getItem(STORE)) ?? {}; } catch { return {}; } };
  const write = (patch) => {
    const next = { ...read(), ...patch };
    try { sessionStorage.setItem(STORE, JSON.stringify(next)); } catch { /* storage blocked */ }
    return next;
  };

  const host = document.createElement("div");
  host.id = "__guide-host";
  host.style.cssText = "all:initial;position:fixed;inset:0;pointer-events:none;z-index:2147483647";
  const root = host.attachShadow({ mode: "open" });
  root.innerHTML = `
<style>
  :host { --ink:#1f1b2e; --accent:#8b6cf0; --soft:#f4f2fb; --muted:#b9a8ff; --line:#3a3352; }
  .panel { position:fixed; right:16px; bottom:16px; width:390px; max-height:70vh;
    display:flex; flex-direction:column; pointer-events:auto; background:var(--ink); color:var(--soft);
    font:14px/1.5 system-ui,-apple-system,sans-serif; border:2px solid var(--accent); border-radius:14px;
    box-shadow:0 16px 48px rgba(0,0,0,.35); cursor:grab; user-select:none; transition:left .35s ease, top .35s ease; }
  .panel.dragging { cursor:grabbing; transition:none; }
  .grip { position:absolute; right:3px; bottom:3px; width:14px; height:14px; cursor:nwse-resize;
    background:linear-gradient(135deg, transparent 50%, var(--muted) 50%, var(--muted) 60%, transparent 60%,
      transparent 75%, var(--muted) 75%, var(--muted) 85%, transparent 85%); }
  .head { padding:14px 16px 6px; }
  .step { font-size:11px; letter-spacing:.08em; text-transform:uppercase; color:var(--muted); }
  .title { font-weight:700; font-size:17px; margin-top:2px; }
  .scroll { flex:1 1 auto; min-height:0; overflow-y:scroll; padding:4px 10px 10px 16px; cursor:auto; user-select:text;
    scrollbar-width:thin; scrollbar-color:var(--accent) #2a2440; }
  .scroll::-webkit-scrollbar { width:8px; }
  .scroll::-webkit-scrollbar-track { background:#2a2440; border-radius:8px; }
  .scroll::-webkit-scrollbar-thumb { background:var(--accent); border-radius:8px; }
  .scroll p { margin:0 0 9px; }
  .scroll code { background:#2e2845; padding:1px 5px; border-radius:4px; font-size:12.5px; }
  .scroll pre { background:#120f1d; color:#d9d2ff; padding:8px; border-radius:8px; font-size:12px;
    white-space:pre-wrap; word-break:break-all; max-height:240px; overflow:auto; }
  .tag { display:inline-block; background:var(--accent); color:#fff; border-radius:999px; padding:0 8px;
    font-size:12px; font-weight:700; margin-right:4px; }
  .thread:empty { display:none; }
  .thread { border-top:1px dashed var(--line); margin-top:4px; padding-top:10px; }
  .q { margin:0 0 6px auto; max-width:85%; width:fit-content; background:var(--line); border-radius:10px 10px 2px 10px; padding:6px 10px; }
  .a { border-left:3px solid var(--accent); background:#2a2440; border-radius:8px; padding:8px 10px; margin:0 0 10px; }
  .a.pending { color:var(--muted); font-style:italic; }
  .status { padding:0 16px 6px; font-size:12px; color:var(--muted); min-height:18px; }
  .ask { display:flex; gap:6px; padding:8px 16px 0; border-top:1px solid var(--line); }
  textarea { flex:1; resize:none; height:38px; background:#2a2440; color:var(--soft); border:1px solid var(--line);
    border-radius:8px; padding:8px; font:13px system-ui; cursor:text; user-select:text; }
  textarea::placeholder { color:#8f86ad; }
  .nav { display:flex; gap:8px; padding:10px 16px 14px; }
  button { font:600 14px system-ui; padding:10px; border-radius:10px; border:0; cursor:pointer; }
  .nav button { flex:1; }
  .prev { background:var(--line); color:var(--soft); }
  .next { background:var(--accent); color:#fff; }
  .send { background:var(--line); color:var(--soft); padding:0 12px; font-size:13px; }
  button:disabled { opacity:.45; cursor:default; }
  .min { position:absolute; top:8px; right:10px; padding:2px 8px; font-size:12px; background:transparent; color:var(--muted); }
  .panel.collapsed .scroll, .panel.collapsed .status, .panel.collapsed .ask { display:none; }
  .dim { position:fixed; inset:0; background:rgba(31,27,46,.18); pointer-events:none; display:none; }
  .hl { position:fixed; border:3px solid var(--accent); border-radius:8px; background:rgba(139,108,240,.06);
    transition:all .35s ease; pointer-events:none; }
  .hl-label { position:absolute; left:-3px; top:-28px; background:var(--accent); color:#fff;
    font:600 12px system-ui; padding:3px 8px; border-radius:6px; white-space:nowrap; }
  .pointer { position:fixed; width:22px; height:22px; margin:-4px 0 0 -4px; transition:left .7s ease, top .7s ease;
    pointer-events:none; filter:drop-shadow(0 2px 3px rgba(0,0,0,.4)); }
  .pointer.pulse::after { content:""; position:absolute; left:-10px; top:-10px; width:40px; height:40px;
    border-radius:50%; border:3px solid var(--accent); animation:pulse .6s ease-out; }
  @keyframes pulse { from { transform:scale(.3); opacity:1 } to { transform:scale(1.2); opacity:0 } }
</style>
<div class="dim"></div>
<div class="panel">
  <button class="min" title="Collapse">–</button>
  <div class="head"><div class="step"></div><div class="title"></div></div>
  <div class="scroll"><div class="body"></div><div class="thread"></div></div>
  <div class="status"></div>
  <div class="ask"><textarea placeholder="Ask a question or report an issue…"></textarea><button class="send">Send</button></div>
  <div class="nav"><button class="prev">← Previous</button><button class="next">Next →</button></div>
  <div class="grip" title="Resize"></div>
</div>
<svg class="pointer" viewBox="0 0 24 24" style="left:-40px;top:-40px">
  <path d="M3 2l7 19 2.6-7.4L20 11z" fill="#fff" stroke="#1f1b2e" stroke-width="1.6" stroke-linejoin="round"/>
</svg>`;
  document.documentElement.appendChild(host);

  const $ = (sel) => root.querySelector(sel);
  const panel = $(".panel");
  const pointer = $(".pointer");
  const input = $("textarea");
  let busyFlag = false;

  // Viewer events: delivered to an in-page waiter the moment they happen, and to the
  // relay (if connected) so the agent is notified without asking.
  const queue = [];
  const waiters = [];
  function emit(event) {
    const full = { ...event, step: read().step ?? null, at: new Date().toISOString() };
    const relay = read().relay;
    if (relay) {
      fetch(relay, { method: "POST", mode: "no-cors", keepalive: true, body: JSON.stringify(full) }).catch(() => {});
    }
    const waiter = waiters.shift();
    if (waiter) waiter(full); else queue.push(full);
  }
  function navigate(type) {
    if (busyFlag) return;
    $(".status").textContent = type === "next" ? "Next requested…" : "Previous requested…";
    emit({ type });
  }
  function send() {
    const text = input.value.trim();
    if (!text) return;
    input.value = "";
    render(write({ thread: [...(read().thread ?? []), { asked: text, answer: null }] }));
    $(".scroll").scrollTop = $(".scroll").scrollHeight;
    $(".status").textContent = "Message sent…";
    emit({ type: "message", text });
  }
  const isLastStep = () => { const s = read(); return Boolean(s.step && s.total && s.step >= s.total); };
  function close() {
    emit({ type: "close" });
    ["__guide_state", "__guide_src"].forEach((key) => { try { sessionStorage.removeItem(key); } catch { /* storage blocked */ } });
    host.remove();
    delete window.__guide;
  }
  $(".next").onclick = () => (isLastStep() ? close() : navigate("next"));
  $(".prev").onclick = () => navigate("prev");
  $(".send").onclick = send;
  input.addEventListener("keydown", (e) => {
    if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); send(); }
    e.stopPropagation();
  });
  ["keyup", "keypress"].forEach((t) => input.addEventListener(t, (e) => e.stopPropagation()));
  $(".min").onclick = () => panel.classList.toggle("collapsed");

  // Pin the panel by its top-left corner, so dragging and resizing move it predictably.
  function anchorTopLeft() {
    const rect = panel.getBoundingClientRect();
    Object.assign(panel.style, { left: `${rect.left}px`, top: `${rect.top}px`, right: "auto", bottom: "auto" });
    return rect;
  }

  // Resize from the bottom-right grip; the size is remembered across reloads.
  $(".grip").addEventListener("pointerdown", (down) => {
    down.stopPropagation();
    down.preventDefault();
    const rect = anchorTopLeft();
    const move = (e) => {
      const width = Math.min(Math.max(280, rect.width + e.clientX - down.clientX), innerWidth - rect.left - 8);
      const height = Math.min(Math.max(220, rect.height + e.clientY - down.clientY), innerHeight - rect.top - 8);
      Object.assign(panel.style, { width: `${width}px`, height: `${height}px`, maxHeight: "none" });
    };
    const up = () => {
      removeEventListener("pointermove", move);
      removeEventListener("pointerup", up);
      write({
        position: { left: panel.style.left, top: panel.style.top },
        size: { width: panel.style.width, height: panel.style.height },
      });
      fit();
    };
    addEventListener("pointermove", move);
    addEventListener("pointerup", up);
  });

  // Drag from anywhere on the panel except its controls and the text.
  panel.addEventListener("pointerdown", (down) => {
    if (down.target.closest("button, textarea, .scroll, .grip")) return;
    const rect = panel.getBoundingClientRect();
    const dx = down.clientX - rect.left;
    const dy = down.clientY - rect.top;
    panel.classList.add("dragging");
    const move = (e) => {
      const left = Math.min(Math.max(0, e.clientX - dx), innerWidth - rect.width);
      const top = Math.min(Math.max(0, e.clientY - dy), innerHeight - 40);
      Object.assign(panel.style, { left: `${left}px`, top: `${top}px`, right: "auto", bottom: "auto" });
      fit();
    };
    const up = () => {
      panel.classList.remove("dragging");
      removeEventListener("pointermove", move);
      removeEventListener("pointerup", up);
      write({ position: { left: panel.style.left, top: panel.style.top } });
    };
    addEventListener("pointermove", move);
    addEventListener("pointerup", up);
  });

  function render(state) {
    $(".step").textContent = state.step && state.total ? `Step ${state.step} of ${state.total}` : "";
    $(".title").textContent = state.title ?? "";
    $(".body").innerHTML = state.html ?? "";
    const thread = $(".thread");
    thread.replaceChildren();
    for (const entry of state.thread ?? []) {
      const q = document.createElement("div");
      q.className = "q";
      q.textContent = entry.asked;
      const a = document.createElement("div");
      a.className = entry.answer === null ? "a pending" : "a";
      if (entry.answer === null) a.textContent = "Waiting for a reply…";
      else a.innerHTML = entry.answer;
      thread.append(...(entry.asked ? [q, a] : [a]));
    }
    $(".status").textContent = state.status ?? "";
    $(".prev").disabled = busyFlag || !state.step || state.step <= 1;
    const last = Boolean(state.step && state.total && state.step >= state.total);
    $(".next").textContent = last ? "Close" : "Next →";
    $(".next").disabled = busyFlag;
    $(".send").disabled = busyFlag;
    if (state.position) Object.assign(panel.style, { ...state.position, right: "auto", bottom: "auto" });
    if (state.size) Object.assign(panel.style, state.size);
    fit();
  }

  // Keep the panel on screen, controls included: the text area scrolls instead of
  // the panel growing. Until the viewer resizes it, it is also capped at 70% height.
  function fit() {
    const top = panel.style.top ? parseFloat(panel.style.top) : null;
    const room = top === null ? innerHeight - 32 : innerHeight - top - 16;
    const cap = read().size ? room : Math.min(innerHeight * 0.7, room);
    panel.style.maxHeight = `${Math.max(200, cap)}px`;
  }

  const isVisible = (el) => {
    const r = el.getBoundingClientRect();
    return r.width > 0 && r.height > 0 && getComputedStyle(el).visibility !== "hidden";
  };
  function find(text) {
    const want = text.trim().toLowerCase();
    const leaves = [...document.querySelectorAll("body *")].filter(
      (el) => !host.contains(el) && el.children.length === 0 && isVisible(el),
    );
    const leaf = leaves.find((el) => el.textContent.trim().toLowerCase() === want)
      ?? leaves.find((el) => el.textContent.trim().toLowerCase().includes(want))
      ?? [...document.querySelectorAll("[aria-label],[placeholder],[title]")].find((el) => isVisible(el)
        && (el.getAttribute("aria-label") ?? el.getAttribute("placeholder") ?? el.title).toLowerCase().includes(want));
    return leaf?.closest("button,a,label,input,select,textarea,[role=button]") ?? leaf ?? null;
  }
  function resolve(target) {
    if (!target) return null;
    if (target instanceof Element) return target;
    try { const el = document.querySelector(target); if (el) return el; } catch { /* not a selector */ }
    return find(target);
  }

  // Move the panel to the corner that covers none of the given elements, so a
  // highlight or the pointer's target is never hidden behind it.
  const overlaps = (a, b) => a.left < b.right && b.left < a.right && a.top < b.bottom && b.top < a.bottom;
  function moveAside(elements) {
    const targets = elements.map((el) => el.getBoundingClientRect());
    const current = panel.getBoundingClientRect();
    if (!targets.some((t) => overlaps(current, t))) return;
    const { width, height } = current;
    const corners = [
      { left: innerWidth - width - 16, top: innerHeight - height - 16 },
      { left: 16, top: innerHeight - height - 16 },
      { left: innerWidth - width - 16, top: 16 },
      { left: 16, top: 16 },
    ];
    const spot = corners.find((c) => !targets.some((t) => overlaps({ ...c, right: c.left + width, bottom: c.top + height }, t)));
    if (!spot) return;
    Object.assign(panel.style, { left: `${spot.left}px`, top: `${spot.top}px`, right: "auto", bottom: "auto" });
    write({ position: { left: panel.style.left, top: panel.style.top } });
    fit();
  }

  const highlights = [];
  function placeBox(box, el) {
    const r = el.getBoundingClientRect();
    Object.assign(box.style, { left: `${r.left - 6}px`, top: `${r.top - 6}px`, width: `${r.width + 12}px`, height: `${r.height + 12}px` });
  }
  const replace = () => highlights.forEach(({ box, el }) => placeBox(box, el));
  addEventListener("scroll", replace, true);
  addEventListener("resize", () => { replace(); fit(); });

  // Re-check the corner whenever the highlights or the panel move or change size.
  const keepClear = () => {
    if (highlights.length && !panel.classList.contains("dragging")) moveAside(highlights.map((h) => h.el));
  };
  addEventListener("scrollend", keepClear, true);
  new ResizeObserver(keepClear).observe(panel);

  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
  // Resolve once the element has stopped moving, i.e. a smooth scroll has finished.
  async function settle(el, maxMs = 2000) {
    const until = Date.now() + maxMs;
    let last = "";
    let still = 0;
    while (still < 6 && Date.now() < until) {
      await sleep(16);
      const r = el.getBoundingClientRect();
      const now = `${r.left},${r.top}`;
      still = now === last ? still + 1 : 0;
      last = now;
    }
  }

  window.__guide = {
    connect(relayUrl) { write({ relay: relayUrl }); },
    show({ step, total, title, html }) { render(write({ step, total, title, html, thread: [], status: "" })); },
    say(html) {
      const thread = [...(read().thread ?? [])];
      const open = thread.findLastIndex((entry) => entry.answer === null);
      if (open >= 0) thread[open] = { ...thread[open], answer: html };
      else thread.push({ asked: null, answer: html });
      render(write({ thread }));
      $(".scroll").scrollTop = $(".scroll").scrollHeight;
    },
    status(text) { write({ status: text }); $(".status").textContent = text; },
    busy(isBusy) {
      busyFlag = isBusy;
      render(read());
      if (isBusy) $(".status").textContent = "Working…";
    },
    waitForEvent(timeoutMs = 25000) {
      if (queue.length) return Promise.resolve(queue.shift());
      return new Promise((resolveEvent) => {
        const waiter = (event) => { clearTimeout(timer); resolveEvent(event); };
        const timer = setTimeout(() => {
          const i = waiters.indexOf(waiter);
          if (i >= 0) waiters.splice(i, 1);
          resolveEvent(null);
        }, timeoutMs);
        waiters.push(waiter);
      });
    },
    highlight(target, label) {
      const el = resolve(target);
      if (!el) return false;
      el.scrollIntoView({ block: "center", behavior: "smooth" });
      const box = document.createElement("div");
      box.className = "hl";
      if (label) {
        const tag = document.createElement("span");
        tag.className = "hl-label";
        tag.textContent = label;
        box.appendChild(tag);
      }
      root.appendChild(box);
      highlights.push({ box, el });
      $(".dim").style.display = "block";
      placeBox(box, el);
      settle(el).then(() => { placeBox(box, el); keepClear(); });
      return true;
    },
    clearHighlights() {
      highlights.splice(0).forEach(({ box }) => box.remove());
      $(".dim").style.display = "none";
    },
    async pointTo(target) {
      const el = resolve(target);
      if (!el) return null;
      el.scrollIntoView({ block: "center", behavior: "smooth" });
      await settle(el);
      moveAside([el, ...highlights.map((h) => h.el)]);
      const r = el.getBoundingClientRect();
      const x = Math.round(r.left + r.width / 2);
      const y = Math.round(r.top + r.height / 2);
      Object.assign(pointer.style, { left: `${x}px`, top: `${y}px` });
      await sleep(750);
      pointer.classList.remove("pulse");
      void pointer.getBoundingClientRect();
      pointer.classList.add("pulse");
      return { x, y, viewportWidth: innerWidth };
    },
    find,
  };
  render(read());
  return "guide ready";
})();
