import { spawn, spawnSync } from 'node:child_process';
import { writeFileSync } from 'node:fs';
const ADB = process.env.ADB || 'adb';
const DEVICE = process.env.DEVICE || 'emulator-5554';
const SECRET = process.env.AUTH_BYPASS_TOKEN || 'TopFlightApiSecurity2026+';
const adb = (...args) => spawnSync(ADB, ['-s', DEVICE, ...args], { maxBuffer: 128 * 1024 * 1024 });

// 1) Mock GPS near 75495 (Van Alstyne, TX) — lng lat order.
adb('emu', 'geo', 'fix', '-96.5486', '33.4292');
const PKG = process.env.APP_PKG || 'com.davissylvester.bjjopenmat';
// `flutter test` reinstalls the APK, which RESETS runtime permission grants, so a
// one-time pre-grant is wiped. Instead we grant in a tight loop for the first
// ~30s: once a grant lands before the app's location check, the OS returns
// "granted" immediately and never shows the permission dialog (which would
// otherwise cover the search + detail screenshots).
const grantLoop = setInterval(() => {
  adb('shell', 'pm', 'grant', PKG, 'android.permission.ACCESS_FINE_LOCATION');
  adb('shell', 'pm', 'grant', PKG, 'android.permission.ACCESS_COARSE_LOCATION');
}, 400);
setTimeout(() => clearInterval(grantLoop), 30000);
// 2) Start screen recording (<=180s) — full-motion backup of the whole flow.
const rec = spawn(ADB, ['-s', DEVICE, 'shell', 'screenrecord', '--time-limit', '180', '/sdcard/e2e-location.mp4'], { stdio: 'inherit' });

// 3) Run e2e via `flutter test` (single debug APK — faster than `flutter drive`).
// We PIPE its stdout and watch for the test's "E2ESHOT:<name>" markers. On each,
// wait for the frame/launch to settle, then `adb screencap` -> build/e2e/<name>.png.
// (adb screencap works on the live-rendered app; binding.takeScreenshot returns
// blank/throws under Impeller on this emulator.)
const drive = spawn('flutter', [
  'test',
  'integration_test/location_directions_test.dart',
  '-d', DEVICE,
  '--dart-define=DEV_BYPASS=true',
  `--dart-define=AUTH_BYPASS_TOKEN=${SECRET}`,
  '--dart-define=API_BASE_URL=http://10.0.2.2:3100',
], { stdio: ['ignore', 'pipe', 'inherit'], shell: process.platform === 'win32' });

const captured = new Set();
let buf = '';
drive.stdout.on('data', (d) => {
  const s = d.toString();
  process.stdout.write(s); // keep progress visible
  buf += s;
  const lines = buf.split('\n');
  buf = lines.pop() || '';
  for (const ln of lines) {
    const m = ln.match(/E2ESHOT:([\w.-]+)/);
    if (!m || captured.has(m[1])) continue;
    const name = m[1];
    captured.add(name);
    // 03 needs longer: the external app (Chrome) must reach the foreground.
    const settleMs = name.startsWith('03') ? 3500 : 1200;
    setTimeout(() => {
      const png = adb('exec-out', 'screencap', '-p');
      if (png.status === 0 && png.stdout?.length) {
        writeFileSync(`build/e2e/${name}.png`, png.stdout);
        console.log(`\ncaptured ${name}.png`);
      } else {
        console.log(`\nWARN: screencap failed for ${name}`);
      }
    }, settleMs);
  }
});

const code = await new Promise((res) => drive.on('exit', (c) => res(c ?? 1)));
// Give any in-flight 03 screencap time to complete before teardown.
await new Promise((r) => setTimeout(r, 4500));

// 4) Stop recording + pull the video.
adb('shell', 'pkill', '-INT', 'screenrecord');
try { rec.kill('SIGINT'); } catch {}
await new Promise((r) => setTimeout(r, 2500));
adb('pull', '/sdcard/e2e-location.mp4', 'build/e2e/e2e-location.mp4');
console.log(`shots captured: ${[...captured].join(', ') || 'none'}`);
process.exit(code);
