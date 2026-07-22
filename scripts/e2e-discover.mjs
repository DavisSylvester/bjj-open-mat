import { spawn, spawnSync } from 'node:child_process';
import { writeFileSync } from 'node:fs';
const ADB = process.env.ADB || 'adb';
const DEVICE = process.env.DEVICE || 'emulator-5554';
const SECRET = process.env.AUTH_BYPASS_TOKEN || 'TopFlightApiSecurity2026+';
const PKG = process.env.APP_PKG || 'com.davissylvester.bjjopenmat';
const adb = (...args) => spawnSync(ADB, ['-s', DEVICE, ...args], { maxBuffer: 128 * 1024 * 1024 });

// Mock GPS near 75495 (Van Alstyne, TX) so nearby gyms/open-mats resolve.
adb('emu', 'geo', 'fix', '-96.5486', '33.4292');
// Grant location in a tight loop for the first ~30s (flutter test reinstalls the
// APK, resetting runtime grants — winning the race means no permission dialog).
const grantLoop = setInterval(() => {
  adb('shell', 'pm', 'grant', PKG, 'android.permission.ACCESS_FINE_LOCATION');
  adb('shell', 'pm', 'grant', PKG, 'android.permission.ACCESS_COARSE_LOCATION');
}, 400);
setTimeout(() => clearInterval(grantLoop), 30000);

const rec = spawn(ADB, ['-s', DEVICE, 'shell', 'screenrecord', '--time-limit', '180', '/sdcard/e2e-discover.mp4'], { stdio: 'inherit' });

const drive = spawn('flutter', [
  'test',
  'integration_test/discover_gyms_smoke_test.dart',
  '-d', DEVICE,
  '--dart-define=DEV_BYPASS=true',
  `--dart-define=AUTH_BYPASS_TOKEN=${SECRET}`,
  '--dart-define=API_BASE_URL=http://10.0.2.2:3100',
], { stdio: ['ignore', 'pipe', 'inherit'], shell: process.platform === 'win32' });

const captured = new Set();
let buf = '';
drive.stdout.on('data', (d) => {
  const s = d.toString();
  process.stdout.write(s);
  buf += s;
  const lines = buf.split('\n');
  buf = lines.pop() || '';
  for (const ln of lines) {
    const m = ln.match(/E2ESHOT:([\w.-]+)/);
    if (!m || captured.has(m[1])) continue;
    const name = m[1];
    captured.add(name);
    setTimeout(() => {
      const png = adb('exec-out', 'screencap', '-p');
      if (png.status === 0 && png.stdout?.length) {
        writeFileSync(`build/e2e/${name}.png`, png.stdout);
        console.log(`\ncaptured ${name}.png`);
      } else {
        console.log(`\nWARN: screencap failed for ${name}`);
      }
    }, 1200);
  }
});

const code = await new Promise((res) => drive.on('exit', (c) => res(c ?? 1)));
await new Promise((r) => setTimeout(r, 3000));
try { rec.kill('SIGINT'); } catch {}
adb('shell', 'pkill', '-INT', 'screenrecord');
await new Promise((r) => setTimeout(r, 2000));
adb('pull', '/sdcard/e2e-discover.mp4', 'build/e2e/e2e-discover.mp4');
console.log(`shots captured: ${[...captured].join(', ') || 'none'}`);
process.exit(code);
