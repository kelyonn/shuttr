import puppeteer from "/private/tmp/pup-shot/node_modules/puppeteer-core/lib/esm/puppeteer/puppeteer-core.js";
import path from "path";
import { fileURLToPath } from "url";
import fs from "fs";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const outDir = __dirname;
const html = path.resolve(__dirname, "../camera-directions.html");
const chrome =
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";

// Clear previous PNGs (keep helper files)
for (const name of fs.readdirSync(outDir)) {
  if (name.endsWith(".png")) fs.unlinkSync(path.join(outDir, name));
}

const STATES = [
  {
    file: "01-camera-default.png",
    label: "Camera — Digi '03, cameras closed (default)",
    page: "camera",
    patch: {},
  },
  {
    file: "02-camera-cameras-open.png",
    label: "Camera — cameras picker open",
    page: "camera",
    patch: { cameras: true },
  },
  {
    file: "03-camera-disposable.png",
    label: "Camera — Disposable",
    page: "camera",
    patch: { mode: 1, cameras: false },
  },
  {
    file: "04-camera-instant-locked.png",
    label: "Camera — Instant (preview only)",
    page: "camera",
    patch: { mode: 2, cameras: false },
  },
  {
    file: "05-camera-35-locked.png",
    label: "Camera — Point & Shoot 35 (preview only)",
    page: "camera",
    patch: { mode: 3, cameras: false },
  },
  {
    file: "06-camera-flash-auto.png",
    label: "Camera — flash AUTO",
    page: "camera",
    patch: { mode: 0, flash: 1 },
  },
  {
    file: "07-camera-flash-on.png",
    label: "Camera — flash ON",
    page: "camera",
    patch: { mode: 0, flash: 2 },
  },
  {
    file: "08-camera-front-lens.png",
    label: "Camera — front lens",
    page: "camera",
    patch: { mode: 0, lens: "front", flash: 0 },
  },
  {
    file: "09-camera-front-flash.png",
    label: "Camera — front lens + screen flash ON",
    page: "camera",
    patch: { mode: 0, lens: "front", flash: 1 },
  },
  {
    file: "10-camera-date-stamp.png",
    label: "Camera — date stamp on",
    page: "camera",
    patch: { mode: 0, stamp: true, lens: "rear", flash: 0 },
  },
  {
    file: "11-camera-countdown-3.png",
    label: "Camera — mirror countdown 3",
    page: "camera",
    patch: { mode: 0, counting: 3, mirror: true, stamp: false },
  },
  {
    file: "12-camera-countdown-2.png",
    label: "Camera — mirror countdown 2",
    page: "camera",
    patch: { counting: 2 },
  },
  {
    file: "13-camera-countdown-1.png",
    label: "Camera — mirror countdown 1",
    page: "camera",
    patch: { counting: 1 },
  },
  {
    file: "14-roll.png",
    label: "Roll — with frames",
    page: "gallery",
    patch: { counting: 0 },
  },
  {
    file: "15-roll-empty.png",
    label: "Roll — empty",
    page: "gallery",
    patch: { roll: [] },
  },
  {
    file: "16-settings-all-off.png",
    label: "Settings — all off",
    page: "settings",
    patch: {
      roll: [
        { n: 16, mode: 0, pos: "24% 78%", lens: "rear", stamp: true, mirrorSave: false },
        { n: 17, mode: 1, pos: "78% 36%", lens: "rear", stamp: false, mirrorSave: false },
      ],
      stamp: false,
      mirrorSave: false,
      mirror: false,
    },
  },
  {
    file: "17-settings-all-on.png",
    label: "Settings — all on",
    page: "settings",
    patch: { stamp: true, mirrorSave: true, mirror: true },
  },
  {
    file: "18-review-keep.png",
    label: "Review — RETAKE / KEEP (default seeded shot)",
    page: "review",
    patch: {
      stamp: false,
      mirrorSave: false,
      mirror: false,
      developing: false,
      fromGallery: false,
      gate: false,
      reviewing: {
        n: 18, mode: 0, pos: "62% 38%", lens: "rear", stamp: true, mirrorSave: false,
      },
    },
  },
  {
    file: "19-review-developing.png",
    label: "Review — developing",
    page: "review",
    patch: { developing: true, fromGallery: false },
  },
  {
    file: "20-review-from-roll.png",
    label: "Review — from roll (BACK / DISCARD)",
    page: "review",
    patch: {
      developing: false,
      fromGallery: true,
      gate: false,
      reviewing: {
        n: 16, mode: 0, pos: "24% 78%", lens: "rear", stamp: true, mirrorSave: false,
      },
    },
  },
  {
    file: "21-review-locked-gate.png",
    label: "Review — Instant locked keep gate",
    page: "review",
    patch: {
      developing: false,
      fromGallery: false,
      gate: true,
      mode: 2,
      reviewing: {
        n: 18, mode: 2, pos: "62% 38%", lens: "rear", stamp: false, mirrorSave: false,
      },
    },
  },
  {
    file: "00-board-default.png",
    label: "Full board — all four pages at default state",
    page: null,
    patch: null,
    fullBoard: true,
  },
];

const browser = await puppeteer.launch({
  executablePath: chrome,
  headless: "new",
  args: ["--hide-scrollbars", "--font-render-hinting=none"],
});

const page = await browser.newPage();
await page.setViewport({ width: 1600, height: 1000, deviceScaleFactor: 2 });
await page.goto("file://" + html, { waitUntil: "networkidle0" });
await page.evaluate(() => document.fonts.ready);
await page.waitForFunction(() => window.__shuttr);
await new Promise((r) => setTimeout(r, 500));

await page.addStyleTag({
  content: `
    html.capture-one body { background: #c9c3b6 !important; margin: 0 !important; }
    html.capture-one .board { padding: 0 !important; }
    html.capture-one .board > .kicker,
    html.capture-one .board > h1,
    html.capture-one .board > .deck { display: none !important; }
    html.capture-one .slots { display: block !important; overflow: visible !important; gap: 0 !important; margin: 0 !important; }
    html.capture-one .slot { display: none !important; width: 390px !important; margin: 0 !important; }
    html.capture-one .slot.is-shot { display: block !important; }
    html.capture-one .slot h2 { display: none !important; }
    html.capture-one .clip { width: 390px !important; height: 844px !important; overflow: hidden !important; }
    html.capture-one .clip .phone { transform: none !important; }
  `,
});

async function resetFresh() {
  await page.evaluate(() => {
    const { board, fresh, paint } = window.__shuttr;
    board._s = fresh();
    paint(board);
  });
}

async function apply(patch) {
  await page.evaluate((p) => {
    const { board, paint } = window.__shuttr;
    Object.assign(board._s, p);
    if (Object.prototype.hasOwnProperty.call(p, "roll")) board._s.roll = p.roll;
    if (Object.prototype.hasOwnProperty.call(p, "reviewing")) board._s.reviewing = p.reviewing;
    paint(board);
  }, patch);
}

async function showPage(pageName) {
  await page.evaluate((name) => {
    document.documentElement.classList.add("capture-one");
    document.querySelectorAll(".slot").forEach((slot) => {
      const phone = slot.querySelector("[data-page]");
      slot.classList.toggle("is-shot", phone && phone.dataset.page === name);
    });
  }, pageName);
}

async function showBoard() {
  await page.evaluate(() => {
    document.documentElement.classList.remove("capture-one");
    document.querySelectorAll(".slot").forEach((slot) => slot.classList.remove("is-shot"));
  });
}

const index = [];

for (const state of STATES) {
  if (state.fullBoard) {
    await resetFresh();
    await showBoard();
    await page.setViewport({ width: 1500, height: 980, deviceScaleFactor: 2 });
    await new Promise((r) => setTimeout(r, 200));
    const out = path.join(outDir, state.file);
    await page.screenshot({ path: out, type: "png", fullPage: true });
    index.push({ file: state.file, label: state.label });
    console.log("wrote", state.file);
    continue;
  }

  await page.setViewport({ width: 430, height: 900, deviceScaleFactor: 2 });
  await resetFresh();
  if (state.patch && Object.keys(state.patch).length) await apply(state.patch);
  await showPage(state.page);
  await new Promise((r) => setTimeout(r, 100));
  const phone = await page.$(`.slot.is-shot .phone`);
  if (!phone) throw new Error("missing phone for " + state.file);
  const out = path.join(outDir, state.file);
  await phone.screenshot({ path: out, type: "png" });
  index.push({ file: state.file, label: state.label });
  console.log("wrote", state.file);
}

fs.writeFileSync(
  path.join(outDir, "INDEX.md"),
  [
    "# Shuttr UI screenshots",
    "",
    "Captured live from `design/camera-directions.html` (current file).",
    "",
    ...index.map((row) => `- ![${row.label}](${row.file}) — **${row.label}**`),
    "",
  ].join("\n"),
);

await browser.close();
console.log("done", index.length);
