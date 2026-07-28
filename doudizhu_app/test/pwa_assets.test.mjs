import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');

async function pngSize(relativePath) {
  const bytes = await readFile(join(root, relativePath));
  assert.deepEqual([...bytes.subarray(0, 8)], [137, 80, 78, 71, 13, 10, 26, 10]);
  return { width: bytes.readUInt32BE(16), height: bytes.readUInt32BE(20) };
}

test('manifest uses a relative preview entry and standalone scope', async () => {
  const manifest = JSON.parse(await readFile(join(root, 'manifest.webmanifest'), 'utf8'));
  assert.equal(manifest.name, '斗地主记分');
  assert.equal(manifest.short_name, '斗地主');
  assert.equal(manifest.id, './');
  assert.equal(manifest.start_url, './preview.html');
  assert.equal(manifest.scope, './');
  assert.equal(manifest.display, 'standalone');
  assert.equal(manifest.orientation, 'portrait');
  assert.equal(manifest.theme_color, '#151515');
  assert.equal(manifest.background_color, '#151515');
});

test('manifest declares any and maskable PNG icons at 192 and 512', async () => {
  const manifest = JSON.parse(await readFile(join(root, 'manifest.webmanifest'), 'utf8'));
  const contracts = [
    ['./icons/icon-192.png', '192x192', 'any'],
    ['./icons/icon-512.png', '512x512', 'any'],
    ['./icons/maskable-192.png', '192x192', 'maskable'],
    ['./icons/maskable-512.png', '512x512', 'maskable'],
  ];
  assert.deepEqual(manifest.icons.map(({ src, sizes, purpose }) => [src, sizes, purpose]), contracts);
  for (const [src, sizes] of contracts) {
    const expected = Number(sizes.split('x')[0]);
    assert.deepEqual(await pngSize(src.slice(2)), { width: expected, height: expected });
  }
});

test('manifest icons declare image/png MIME type', async () => {
  const manifest = JSON.parse(await readFile(join(root, 'manifest.webmanifest'), 'utf8'));
  assert.equal(manifest.icons.length, 4);
  for (const icon of manifest.icons) {
    assert.equal(icon.type, 'image/png');
  }
});

test('generator centers the DDZ label with a RectangleF DrawString overload', async () => {
  const source = await readFile(join(root, 'tools/generate_pwa_icons.ps1'), 'utf8');
  assert.ok(
    source.includes('New-Object System.Drawing.RectangleF($labelX, $labelY, $labelW, $labelH)'),
    'expected a RectangleF built from the precomputed label coordinates'
  );
  assert.ok(
    source.includes("DrawString('DDZ', $font, $gold, $labelRect, $format)"),
    'expected the five-argument RectangleF DrawString overload'
  );
});

test('run guide documents iPhone, Android, offline verification, and cache releases', async () => {
  const guide = await readFile(join(root, '运行指南.md'), 'utf8');
  for (const phrase of ['iPhone', 'Safari', '添加到主屏幕', 'Android', 'Chrome', '飞行模式', 'doudizhu-shell-v1']) {
    assert.ok(guide.includes(phrase), `missing guide phrase: ${phrase}`);
  }
});
