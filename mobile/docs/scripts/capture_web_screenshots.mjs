#!/usr/bin/env node
/**
 * Capture web admin UI screenshots for product documentation.
 * Starts the backend if needed, then captures each page via Playwright.
 *
 * Usage: node capture_web_screenshots.mjs [baseUrl]
 */
import { chromium } from "playwright";
import { execSync } from "node:child_process";
import { mkdir } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO = path.resolve(__dirname, "../../../..");
const OUT = path.join(__dirname, "../screenshots/admin");
const BASE = process.argv[2] ?? "http://localhost:3000";

const JOB_ID = "caa39c93-d200-48a7-b64f-ec7995e9c299";
const CAMPAIGN_ID = "4cf9bcf7-9f8a-44ba-9614-4f8bf0ba6264";
const CV_ID = "94c91a18-8f90-4fde-9e7e-7b240f159be7";

const PAGES = [
  { file: "01_dashboard.png", path: "/", ready: "CV Repository overview" },
  { file: "02_library.png", path: "/cvs", ready: "Library" },
  { file: "03_cv_detail.png", path: `/cvs/${CV_ID}`, ready: "Profile" },
  { file: "04_upload.png", path: "/cvs/upload", ready: "Upload" },
  { file: "05_jobs.png", path: "/jobs", ready: "Jobs" },
  { file: "06_job_detail.png", path: `/jobs/${JOB_ID}`, ready: "Ranking progress" },
  { file: "07_campaigns.png", path: "/campaigns", ready: "Campaigns" },
  { file: "08_campaign_detail.png", path: `/campaigns/${CAMPAIGN_ID}`, ready: "Senior Backend Engineer" },
  { file: "09_pipeline.png", path: "/pipeline", ready: "Pipeline" },
  { file: "10_search.png", path: "/search?q=backend", ready: "Search" },
  { file: "11_profile.png", path: "/profile", ready: "Profile" },
];

function ensureBackend() {
  execSync("bash scripts/ensure-backend.sh", { cwd: REPO, stdio: "inherit" });
  execSync("curl -sf http://127.0.0.1:8080/healthz >/dev/null", { stdio: "inherit" });
}

async function capture(page, { file, path: urlPath, ready }) {
  const url = `${BASE}${urlPath}`;
  for (let attempt = 1; attempt <= 3; attempt++) {
    await page.goto(url, { waitUntil: "domcontentloaded", timeout: 60_000 });
    try {
      await page.waitForSelector(`text=${ready}`, { timeout: 20_000 });
    } catch {
      if (attempt === 3) throw new Error(`${file}: timed out waiting for "${ready}"`);
      await page.waitForTimeout(1500);
      continue;
    }
    const failed = await page.locator("text=fetch failed").count();
    if (failed > 0 && attempt < 3) {
      await page.waitForTimeout(1500);
      continue;
    }
    break;
  }
  await page.waitForTimeout(600);
  await page.screenshot({ path: path.join(OUT, file), fullPage: false });
  console.log(`Captured ${file}`);
}

async function main() {
  ensureBackend();
  await mkdir(OUT, { recursive: true });

  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({
    viewport: { width: 1440, height: 900 },
    deviceScaleFactor: 1,
  });

  for (const entry of PAGES) {
    await capture(page, entry);
  }

  await browser.close();
  console.log(`Done — ${OUT}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
