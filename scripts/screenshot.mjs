// Captures screenshots of the built home page (run `pnpm build` first).
// Usage: node scripts/screenshot.mjs [output-dir]
import { mkdir } from 'node:fs/promises';
import path from 'node:path';
import { preview } from 'astro';
import { chromium } from 'playwright';

const VIEWPORTS = [
  { name: 'desktop', width: 1280, height: 800 },
  { name: 'mobile', width: 390, height: 844 },
];

const outDir = path.resolve(process.argv[2] ?? 'screenshots');
await mkdir(outDir, { recursive: true });

const server = await preview({ logLevel: 'error' });
const browser = await chromium.launch({
  // Lets a locally installed Chromium be used instead of Playwright's download.
  executablePath: process.env.CHROMIUM_PATH || undefined,
});

try {
  const url = `http://localhost:${server.port}/`;
  for (const { name, width, height } of VIEWPORTS) {
    const context = await browser.newContext({
      viewport: { width, height },
      deviceScaleFactor: 2,
      // Freezes the animated background so captures are stable.
      reducedMotion: 'reduce',
    });
    const page = await context.newPage();
    await page.goto(url, { waitUntil: 'networkidle' });
    // Astro drops the `ssr` attribute from an island once it has hydrated.
    await page.locator('astro-island[ssr]').waitFor({ state: 'detached' });
    const file = path.join(outDir, `${name}.png`);
    await page.screenshot({ path: file });
    console.warn(`Saved ${file}`);
    await context.close();
  }
} finally {
  await browser.close();
  await server.stop();
}
