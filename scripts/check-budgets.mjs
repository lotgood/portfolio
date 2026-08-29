import { gzipSync } from 'node:zlib';
import { readFile, readdir, stat } from 'node:fs/promises';
import { join, relative, resolve } from 'node:path';

const root = resolve('dist');
const entry = join(root, 'index.html');

const limits = {
  initialJsGzip: 40 * 1024,
  initialCssGzip: 32 * 1024,
  totalJsGzip: 110 * 1024,
  htmlRaw: 80 * 1024
};

async function walk(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const files = [];

  for (const item of entries) {
    const path = join(directory, item.name);
    if (item.isDirectory()) files.push(...await walk(path));
    else files.push(path);
  }

  return files;
}

function localAssetPath(url) {
  const clean = url.split('?')[0]?.split('#')[0];
  if (!clean || /^(?:https?:|data:|mailto:|#)/.test(clean)) return undefined;
  return join(root, clean.replace(/^\//, ''));
}

async function gzipSize(path) {
  return gzipSync(await readFile(path)).byteLength;
}

function kib(bytes) {
  return `${(bytes / 1024).toFixed(1)} KiB`;
}

try {
  await stat(entry);
} catch {
  console.error('dist/index.html is missing. Run `pnpm build` first.');
  process.exit(1);
}

const html = await readFile(entry, 'utf8');
const assetUrls = [...html.matchAll(/(?:src|href)="([^"]+\.(?:js|css)(?:\?[^\"]*)?)"/g)]
  .map((match) => match[1])
  .filter(Boolean);

const initialJs = [...new Set(assetUrls.filter((url) => /\.js(?:[?#]|$)/.test(url)).map(localAssetPath).filter(Boolean))];
const initialCss = [...new Set(assetUrls.filter((url) => /\.css(?:[?#]|$)/.test(url)).map(localAssetPath).filter(Boolean))];
const allFiles = await walk(root);
const allJs = allFiles.filter((path) => path.endsWith('.js'));
const allHtml = allFiles.filter((path) => path.endsWith('.html'));

const measurements = {
  initialJsGzip: (await Promise.all(initialJs.map(gzipSize))).reduce((a, b) => a + b, 0),
  initialCssGzip: (await Promise.all(initialCss.map(gzipSize))).reduce((a, b) => a + b, 0),
  totalJsGzip: (await Promise.all(allJs.map(gzipSize))).reduce((a, b) => a + b, 0),
  largestHtmlRaw: Math.max(...await Promise.all(allHtml.map(async (path) => (await stat(path)).size)))
};

console.log('\nProduction budgets');
console.log(`  initial JS gzip : ${kib(measurements.initialJsGzip)} / ${kib(limits.initialJsGzip)}`);
console.log(`  initial CSS gzip: ${kib(measurements.initialCssGzip)} / ${kib(limits.initialCssGzip)}`);
console.log(`  all JS gzip     : ${kib(measurements.totalJsGzip)} / ${kib(limits.totalJsGzip)}`);
console.log(`  largest HTML    : ${kib(measurements.largestHtmlRaw)} / ${kib(limits.htmlRaw)}`);

const failures = [];
if (measurements.initialJsGzip > limits.initialJsGzip) failures.push('initial JavaScript');
if (measurements.initialCssGzip > limits.initialCssGzip) failures.push('initial CSS');
if (measurements.totalJsGzip > limits.totalJsGzip) failures.push('total JavaScript');
if (measurements.largestHtmlRaw > limits.htmlRaw) failures.push('HTML document size');

if (failures.length > 0) {
  console.error(`\nBudget exceeded: ${failures.join(', ')}`);
  console.error('Inspect dist/_astro and remove or split the regression before shipping.');
  process.exit(1);
}

console.log('\nAll budgets passed.');
