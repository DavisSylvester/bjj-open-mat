import { spawn, spawnSync } from 'node:child_process';
const ADB = process.env.ADB || 'adb';
const DEVICE = process.env.DEVICE || 'emulator-5554';
const SECRET = process.env.AUTH_BYPASS_TOKEN || 'TopFlightApiSecurity2026+';
// 1) Mock GPS near 75495 (Van Alstyne, TX) — lng lat order.
spawnSync(ADB, ['-s', DEVICE, 'emu', 'geo', 'fix', '-96.5486', '33.4292'], { stdio: 'inherit' });
// 2) Start screen recording (<=180s).
const rec = spawn(ADB, ['-s', DEVICE, 'shell', 'screenrecord', '--time-limit', '180', '/sdcard/e2e.mp4'], { stdio: 'inherit' });
// 3) Run e2e via flutter drive (writes screenshots to build/e2e via the driver).
const drive = spawnSync('flutter', [
  'drive',
  '--driver=test_driver/integration_test.dart',
  '--target=integration_test/search_filter_test.dart',
  '-d', DEVICE,
  '--dart-define=DEV_BYPASS=true',
  `--dart-define=AUTH_BYPASS_TOKEN=${SECRET}`,
  '--dart-define=API_BASE_URL=http://10.0.2.2:3100',
], { stdio: 'inherit', shell: process.platform === 'win32' });
// 4) Stop recording + pull the video.
spawnSync(ADB, ['-s', DEVICE, 'shell', 'pkill', '-INT', 'screenrecord'], { stdio: 'inherit' });
try { rec.kill('SIGINT'); } catch {}
await new Promise((r) => setTimeout(r, 2500));
spawnSync(ADB, ['-s', DEVICE, 'pull', '/sdcard/e2e.mp4', 'build/e2e/e2e.mp4'], { stdio: 'inherit' });
process.exit(drive.status ?? 1);
