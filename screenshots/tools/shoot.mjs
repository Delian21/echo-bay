// Captures every Echo Bay screen in light and dark at phone size.
// Drives headless Chrome over the DevTools protocol — no npm dependencies.
//
//   node screenshots/tools/shoot.mjs app [--attach=9334]
//   node screenshots/tools/shoot.mjs onboarding
//
// Output: screenshots/light/<name>.png and screenshots/dark/<name>.png
//
// Two facts shape this driver:
//   * the app resolves light/dark once, at boot (main.dart's
//     didChangePlatformBrightness does not re-resolve), so a theme swap
//     needs a reload with the media feature already emulated;
//   * a full reload costs ~8-16s while an in-page history navigation
//     costs ~2s, so each theme pass reloads once, then walks every route.
import { spawn } from 'node:child_process';
import { mkdir, rm, writeFile } from 'node:fs/promises';
import path from 'node:path';

const CHROME = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const BASE = 'https://echo-bay.netlify.app';
const W = 390;
const H = 844;
const DSF = 2;
const OUT = path.resolve('screenshots');

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const argv = process.argv.slice(2);
const phase = argv[0] ?? 'app';
const attach = argv.find((a) => a.startsWith('--attach='))?.slice(9) ?? null;
const port = attach ?? (phase === 'onboarding' ? 9445 : 9333);
const profileDir = path.join(OUT, phase === 'onboarding' ? '.profile-onboarding' : '.profile');

// ---------------------------------------------------------------- CDP client

let ws;
let msgId = 0;
const pending = new Map();
const inflight = new Set();

function call(method, params = {}) {
  return new Promise((resolve, reject) => {
    const id = ++msgId;
    pending.set(id, { resolve, reject });
    ws.send(JSON.stringify({ id, method, params }));
  });
}

async function connect(wsUrl) {
  ws = new WebSocket(wsUrl);
  await new Promise((resolve, reject) => {
    ws.addEventListener('open', resolve);
    ws.addEventListener('error', (e) => reject(new Error('ws error ' + e.message)));
  });
  ws.addEventListener('message', (ev) => {
    const msg = JSON.parse(ev.data);
    if (msg.id && pending.has(msg.id)) {
      const { resolve, reject } = pending.get(msg.id);
      pending.delete(msg.id);
      if (msg.error) reject(new Error(msg.error.message));
      else resolve(msg.result);
      return;
    }
    if (msg.method === 'Network.requestWillBeSent') inflight.add(msg.params.requestId);
    if (msg.method === 'Network.loadingFinished' || msg.method === 'Network.loadingFailed') {
      inflight.delete(msg.params.requestId);
    }
  });
}

async function evalJs(expression) {
  const r = await call('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true });
  if (r.exceptionDetails) throw new Error(r.exceptionDetails.exception?.description ?? r.exceptionDetails.text);
  return r.result.value;
}

async function networkIdle(quiet = 500, timeout = 6000) {
  const start = Date.now();
  let idleSince = Date.now();
  while (Date.now() - start < timeout) {
    if (inflight.size === 0) {
      if (Date.now() - idleSince >= quiet) return;
    } else {
      idleSince = Date.now();
    }
    await sleep(120);
  }
}

// ---------------------------------------------------------------- page actions

/** Turns Flutter's accessibility tree on so screens can be read and tapped. */
async function enableSemantics() {
  await evalJs(`(() => {
    const ph = document.querySelector('flt-semantics-placeholder');
    if (ph) ph.click();
    return true;
  })()`);
}

async function screenText() {
  return evalJs(`(() => {
    const host = document.querySelector('flt-semantics-host');
    const raw = host ? host.textContent : (document.body.innerText || '');
    return (raw || '').replace(/\\s+/g, ' ').trim();
  })()`);
}

async function waitForText(text, timeout = 45000) {
  const start = Date.now();
  while (Date.now() - start < timeout) {
    await enableSemantics();
    const found = await evalJs(`(() => {
      const norm = (s) => (s || '').replace(/\\s+/g, ' ').trim();
      return [...document.querySelectorAll('flt-semantics')]
        .some((n) => norm(n.textContent).includes(${JSON.stringify(text)}));
    })()`);
    if (found) return true;
    await sleep(250);
  }
  throw new Error(`never saw "${text}"`);
}

async function tap(text, { index = 0, exact = false } = {}) {
  const hit = await evalJs(`(() => {
    const norm = (s) => (s || '').replace(/\\s+/g, ' ').trim();
    const want = ${JSON.stringify(text)};
    const matches = (n) => {
      const label = norm(n.textContent);
      return ${exact ? 'label === want' : 'label.includes(want)'};
    };
    const tappable = [...document.querySelectorAll(
      'flt-semantics[flt-tappable], flt-semantics[role="button"], flt-semantics[role="switch"], flt-semantics[role="tab"]'
    )].filter(matches);
    // Fallback: a plain text node inside a gesture area still carries a
    // box, so click the smallest matching one.
    const any = [...document.querySelectorAll('flt-semantics')]
      .filter((n) => matches(n) && n.getBoundingClientRect().width > 0)
      .sort((a, b) => a.textContent.length - b.textContent.length);
    const n = (tappable[${index}] ?? any[${index}]);
    if (!n) return { ok: false, count: tappable.length, any: any.length };
    const r = n.getBoundingClientRect();
    return { ok: true, x: r.x + r.width / 2, y: r.y + r.height / 2 };
  })()`);
  if (!hit.ok) {
    throw new Error(`no node for "${text}" (tappable: ${hit.count}, any: ${hit.any})`);
  }
  await clickAt(hit.x, hit.y);
}

/** Clicks a viewport point — for controls Flutter keeps out of the
 *  accessibility tree (the Hallway's tab bar). */
async function clickAt(x, y) {
  await call('Input.dispatchMouseEvent', { type: 'mouseMoved', x, y });
  for (const type of ['mousePressed', 'mouseReleased']) {
    await call('Input.dispatchMouseEvent', { type, x, y, button: 'left', clickCount: 1 });
    await sleep(60);
  }
}

async function setTheme(theme) {
  await call('Emulation.setEmulatedMedia', {
    features: [{ name: 'prefers-color-scheme', value: theme }],
  });
}

let theme = 'light';

async function capture(name) {
  const { data } = await call('Page.captureScreenshot', {
    format: 'png',
    fromSurface: true,
    captureBeyondViewport: false,
  });
  const file = path.join(OUT, theme, `${name}.png`);
  await writeFile(file, Buffer.from(data, 'base64'));
  const bytes = Buffer.from(data, 'base64').length;
  console.log(`  ${theme}/${name}.png  ${(bytes / 1024).toFixed(0)}kB`);
}

/** Waits for the screen to stop moving, then grabs it. */
async function shoot(name, { settle = 1800 } = {}) {
  await networkIdle(400, 5000);
  await sleep(settle);
  await capture(name);
}

/** Scrolls down and back, which makes Flutter decode images already in view. */
async function nudge() {
  for (const dy of [320, -320]) {
    await call('Input.dispatchMouseEvent', {
      type: 'mouseWheel',
      x: W / 2,
      y: H / 2,
      deltaX: 0,
      deltaY: dy,
    });
    await sleep(450);
  }
  await sleep(1600);
}

/** Scrolls the whole page so every network image starts decoding, then
 *  returns to the top. Post photos only load once they are in view. */
async function warmImages(steps = 6) {
  for (let i = 0; i < steps; i++) {
    await call('Input.dispatchMouseEvent', { type: 'mouseWheel', x: W / 2, y: H / 2, deltaX: 0, deltaY: 600 });
    await sleep(700);
  }
  await networkIdle(700, 12000);
  for (let i = 0; i < steps + 2; i++) {
    await call('Input.dispatchMouseEvent', { type: 'mouseWheel', x: W / 2, y: H / 2, deltaX: 0, deltaY: -600 });
    await sleep(400);
  }
  await networkIdle(700, 8000);
  await sleep(2200);
}

/** In-page route change — no reload, the app shell stays alive. */
async function goInPage(route) {
  await evalJs(`(() => {
    history.pushState({}, '', ${JSON.stringify(route)});
    window.dispatchEvent(new PopStateEvent('popstate', { state: history.state }));
    return location.pathname;
  })()`);
  await sleep(400);
  await enableSemantics();
  await sleep(1400);
}

/** Cold navigation, used once per theme pass (theme is boot-resolved). */
async function reloadWith(expect, { timeout = 45000 } = {}) {
  await call('Page.navigate', { url: `${BASE}/` });
  await sleep(1500);
  await waitForText(expect, timeout);
  await networkIdle(500, 8000);
  await sleep(1200);
}

// ---------------------------------------------------------------- boot

async function openTarget({ fresh = false } = {}) {
  if (attach || !fresh) {
    try {
      const targets = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
      const page = targets.find((t) => t.type === 'page');
      if (page?.webSocketDebuggerUrl) {
        console.log(`attached to an existing browser on ${port}`);
        return { child: null, wsUrl: page.webSocketDebuggerUrl };
      }
    } catch {
      /* nothing listening — launch below */
    }
    if (attach) throw new Error(`nothing listening on ${port}`);
  }

  await rm(profileDir, { recursive: true, force: true });
  await mkdir(profileDir, { recursive: true });
  const child = spawn(
    CHROME,
    [
      '--headless=new',
      '--no-sandbox',
      '--disable-gpu',
      '--hide-scrollbars',
      '--no-first-run',
      '--no-default-browser-check',
      '--disable-background-timer-throttling',
      '--disable-renderer-backgrounding',
      `--remote-debugging-port=${port}`,
      `--user-data-dir=${profileDir.split(path.sep).join('/')}`,
      `--window-size=${W},${H}`,
      'about:blank',
    ],
    { stdio: 'ignore' }
  );
  for (let i = 0; i < 120; i++) {
    try {
      const targets = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
      const page = targets.find((t) => t.type === 'page');
      if (page?.webSocketDebuggerUrl) return { child, wsUrl: page.webSocketDebuggerUrl };
    } catch {
      /* not up yet */
    }
    await sleep(200);
  }
  throw new Error('chrome did not expose a debugging target');
}

// ---------------------------------------------------------------- phases

/** Every signed-in screen: 15 shots, one reload per theme. */
async function appPhase() {
  const today = new Date();
  const day = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(
    today.getDate()
  ).padStart(2, '0')}T00:00:00.000`;

  const routes = [
    ['compose', '/square/compose'],
    ['day', `/square/day/${encodeURIComponent(day)}`],
    ['vault', '/vault'],
    ['conversation', '/vault/conversation/conv-1'],
    ['hallway', '/nexus'],
    ['dorm', '/nexus/group/grp-core'],
    ['landline', '/calls'],
    ['keepsake', '/keepsake'],
    ['notices', '/notifications'],
    ['search', '/search'],
    ['profile', '/profile'],
    ['person', '/person/ada'],
  ];

  for (const t of ['light', 'dark']) {
    theme = t;
    console.log(`\n=== ${t} ===`);
    await setTheme(t);
    await reloadWith('Everyone');

    console.log('square');
    await shoot('square', { settle: 2200 });

    console.log('square-my-window');
    await tap('My Window');
    await shoot('square-my-window', { settle: 1800 });
    await tap('Everyone');
    await sleep(1200);

    for (const [name, route] of routes) {
      console.log(name);
      await goInPage(route);
      await shoot(name, { settle: 1800 });
    }

    console.log('settings');
    await goInPage('/');
    await sleep(1200);
    await tap('Settings');
    await shoot('settings', { settle: 2000 });
  }
}

/** Welcome flow + sign-up, on a wiped profile so it runs from the start. */
async function onboardingPhase() {
  const steps = [
    ['welcome-1-the-square', 2200],
    ['welcome-2-vault-and-hallway', 1400],
    ['welcome-3-nothing-is-forever', 1400],
    ['welcome-4-setup', 1400],
  ];

  for (const t of ['light', 'dark']) {
    theme = t;
    console.log(`\n=== ${t} (fresh profile) ===`);
    const { child, wsUrl } = await openTarget({ fresh: true });
    await connect(wsUrl);
    await call('Page.enable');
    await call('Runtime.enable');
    await call('Network.enable');
    await call('Emulation.setDeviceMetricsOverride', {
      width: W,
      height: H,
      deviceScaleFactor: DSF,
      mobile: true,
    });
    await setTheme(t);

    await call('Page.navigate', { url: `${BASE}/` });
    await sleep(1500);
    await waitForText('Next', 60000);
    await networkIdle(500, 8000);

    for (let i = 0; i < steps.length; i++) {
      const [name, settle] = steps[i];
      console.log(name);
      await shoot(name, { settle });
      if (i < steps.length - 1) {
        await tap('Next');
        await sleep(1400);
      }
    }

    console.log('sign-the-cover');
    await tap('Start writing');
    await waitForText('Sign the cover', 20000);
    await shoot('sign-the-cover', { settle: 1800 });

    try {
      child?.kill();
    } catch {
      /* already gone */
    }
    await sleep(1200);
    if (!attach) ws?.close();
  }
}

/** Re-takes the shots the first pass got wrong: unloaded media, the
 *  Dorm deep link that never selected its tab, and the person page. */
async function fixPhase() {
  const today = new Date();
  const day = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(
    today.getDate()
  ).padStart(2, '0')}T00:00:00.000`;

  for (const t of ['light', 'dark']) {
    theme = t;
    console.log(`\n=== ${t} ===`);
    await setTheme(t);
    await reloadWith('Everyone');

    console.log('square');
    await nudge();
    await shoot('square', { settle: 2600 });

    console.log('square-my-window');
    await tap('My Window');
    await sleep(1200);
    await shoot('square-my-window', { settle: 2600 });
    await tap('Everyone');
    await sleep(1000);

    console.log('compose');
    await goInPage('/square/compose');
    await nudge();
    await shoot('compose', { settle: 2600 });

    console.log('day');
    await goInPage(`/square/day/${encodeURIComponent(day)}`);
    await nudge();
    await sleep(1500);
    await shoot('day', { settle: 2600 });

    console.log('dorm');
    await goInPage('/nexus');
    await sleep(1600);
    // The Hallway's tab bar is invisible to the semantics tree.
    await clickAt(W * 0.75, 88);
    await sleep(1800);
    await tap('Core Devs');
    await shoot('dorm', { settle: 2600 });

    console.log('person');
    await goInPage('/person/bo_tamm');
    await nudge();
    await shoot('person', { settle: 2000 });
  }
}

/** Composer only: the sheet sits over the feed, so the feed's photos
 *  have to be decoded before the sheet opens. */
async function composePhase() {
  // A freshly launched browser is a fresh install: walk the welcome
  // flow and sign the cover so there is a feed behind the sheet.
  await reloadWith('Next', { timeout: 60000 });
  if ((await screenText()).includes('Skip')) {
    for (let i = 0; i < 3; i++) {
      await tap('Next');
      await sleep(1200);
    }
    await tap('Start writing');
    await waitForText('Sign the cover', 20000);
  }
  if ((await screenText()).includes('Sign the cover')) {
    await tap('Sign the cover', { exact: true });
    await waitForText('Everyone', 15000).catch(() => {})
  }

  for (const t of ['light', 'dark']) {
    theme = t;
    console.log(`\n=== ${t} ===`);
    await setTheme(t);
    await reloadWith('Everyone');
    await warmImages();
    await goInPage('/square/compose');
    await sleep(1800);
    await shoot('compose', { settle: 1500 });
  }
}

/** Photo-heavy screens: wait for still pixels before shooting. */
async function squarePhase() {
  const today = new Date();
  const day = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(
    today.getDate()
  ).padStart(2, '0')}T00:00:00.000`;
  for (const t of ['light', 'dark']) {
    theme = t;
    console.log(`\n=== ${t} ===`);
    await setTheme(t);
    await reloadWith('Everyone');

    console.log('square');
    await warmImages();
    await shoot('square', { settle: 1600 });

    console.log('square-my-window');
    await tap('My Window');
    await sleep(1500);
    await warmImages(3);
    await shoot('square-my-window', { settle: 1600 });

    console.log('day');
    await goInPage(`/square/day/${encodeURIComponent(day)}`);
    await sleep(800);
    await warmImages();
    await shoot('day', { settle: 1600 });
  }
}

async function main() {
  await mkdir(path.join(OUT, 'light'), { recursive: true });
  await mkdir(path.join(OUT, 'dark'), { recursive: true });

  if (phase === 'onboarding') {
    await onboardingPhase();
    console.log('\ndone');
    process.exit(0);
  }

  const { child, wsUrl } = await openTarget();
  await connect(wsUrl);
  await call('Page.enable');
  await call('Runtime.enable');
  await call('Network.enable');
  await call('Emulation.setDeviceMetricsOverride', {
    width: W,
    height: H,
    deviceScaleFactor: DSF,
    mobile: true,
  });

  if (phase === 'compose') await composePhase();
  else if (phase === 'square') await squarePhase();
  else if (phase === 'fix') await fixPhase();
  else await appPhase();
  console.log('\ndone');
  try {
    child?.kill();
  } catch {
    /* already gone */
  }
  process.exit(0);
}

main().catch(async (err) => {
  console.error('FAILED:', err.message);
  try {
    await capture('_error');
  } catch {
    /* nothing to capture */
  }
  process.exit(1);
});
