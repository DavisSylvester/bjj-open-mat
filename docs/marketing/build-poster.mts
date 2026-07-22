/**
 * BJJ Open Mat — light-theme launch poster with real app screenshots.
 *
 * Renders a 1080x1350 Facebook-portrait PNG with an embedded Play Store QR code.
 * TypeScript port of build_poster.py (kept in sync); this is the canonical stack.
 *
 * Run:  bun run build-poster.mts   (from docs/marketing, after `bun install`)
 */
import { createCanvas, loadImage, GlobalFonts, type SKRSContext2D, type Canvas } from '@napi-rs/canvas';
import QRCode from 'qrcode';
import { writeFileSync } from 'node:fs';
import { join } from 'node:path';

// ---- paths -----------------------------------------------------------------
const FONTS: string = 'C:/Users/davis/.claude/plugins/marketplaces/anthropic-agent-skills/skills/canvas-design/canvas-fonts';
const HERE: string = import.meta.dir;
const SHOTS: string = join(HERE, '..', '..', 'build', 'ios-screenshots');
const OUT: string = join(HERE, 'bjj-open-mat-launch.png');
const PLAY_URL: string = 'https://play.google.com/store/apps/details?id=com.davissylvester.bjjopenmat';

// ---- palette (app light theme: white + indigo/violet) ----------------------
const INK: string = '#181A2E';
const INDIGO: string = '#5856D6';
const GREEN: string = '#10AF80';
const MUTE: string = '#969AAC';
const BONE_D: string = '#6C7086';
const CARD: string = '#FFFFFF';
const LINE: string = '#DFE2EE';
const BODY: string = '#11121C';

const SS: number = 2;
const W: number = 1080;
const H: number = 1350;
const cw: number = W * SS;
const ch: number = H * SS;
const M: number = 70 * SS;
const Y = (v: number): number => v * SS;

// ---- font registration -----------------------------------------------------
GlobalFonts.registerFromPath(`${FONTS}/BigShoulders-Bold.ttf`, 'BigShoulders');
GlobalFonts.registerFromPath(`${FONTS}/Outfit-Bold.ttf`, 'OutfitBold');
GlobalFonts.registerFromPath(`${FONTS}/Outfit-Regular.ttf`, 'Outfit');
GlobalFonts.registerFromPath(`${FONTS}/DMMono-Regular.ttf`, 'DMMono');

const font = (family: string, size: number): string => `${size * SS}px ${family}`;

// ---- canvas ----------------------------------------------------------------
const canvas: Canvas = createCanvas(cw, ch);
const ctx: SKRSContext2D = canvas.getContext('2d');
ctx.textBaseline = 'top';

const textWidth = (ctx2: SKRSContext2D, text: string, f: string): number => {
  ctx2.font = f;
  return ctx2.measureText(text).width;
};

const centerX = (ctx2: SKRSContext2D, text: string, f: string): number =>
  Math.round((cw - textWidth(ctx2, text, f)) / 2);

const drawText = (text: string, x: number, y: number, f: string, color: string): void => {
  ctx.font = f;
  ctx.fillStyle = color;
  ctx.fillText(text, x, y);
};

const roundRectPath = (
  ctx2: SKRSContext2D, x: number, y: number, w: number, h: number, r: number,
): void => {
  ctx2.beginPath();
  ctx2.roundRect(x, y, w, h, r);
};

// ---- background: vertical gradient + soft indigo blobs ---------------------
const grad = ctx.createLinearGradient(0, 0, 0, ch);
grad.addColorStop(0, '#F6F7FC');
grad.addColorStop(1, '#E7E9F6');
ctx.fillStyle = grad;
ctx.fillRect(0, 0, cw, ch);

const blob = (bx: number, by: number, r: number, rgb: string, alpha: number): void => {
  const g = ctx.createRadialGradient(bx, by, 0, bx, by, r);
  g.addColorStop(0, `rgba(${rgb},${alpha})`);
  g.addColorStop(1, `rgba(${rgb},0)`);
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, cw, ch);
};
blob(Y(100), Y(20), Y(360), '124,92,246', 0.28);
blob(cw - Y(40), Y(70), Y(360), '88,86,214', 0.26);
blob(cw - Y(10), ch - Y(70), Y(360), '124,92,246', 0.22);

// ---- phone builder ---------------------------------------------------------
interface Phone {
  readonly canvas: Canvas;
  readonly w: number;
  readonly h: number;
}

const makePhone = async (path: string, phoneH: number): Promise<Phone> => {
  const img = await loadImage(path);
  const ph = phoneH * SS;
  const bez = 12 * SS;
  const innerH = ph - 2 * bez;
  const innerW = Math.round((img.width * innerH) / img.height);
  const pw = innerW + 2 * bez;
  const c = createCanvas(pw, ph);
  const g = c.getContext('2d');
  roundRectPath(g, 0, 0, pw, ph, 42 * SS);
  g.fillStyle = BODY;
  g.fill();
  g.save();
  roundRectPath(g, bez, bez, innerW, innerH, 30 * SS);
  g.clip();
  g.drawImage(img, bez, bez, innerW, innerH);
  g.restore();
  return { canvas: c, w: pw, h: ph };
};

interface PlaceOpts {
  readonly angle?: number;
  readonly dx?: number;
  readonly dy?: number;
  readonly blur?: number;
  readonly alpha?: number;
}

const place = (phone: Phone, centerX2: number, centerY: number, opts: PlaceOpts = {}): void => {
  const { angle = 0, dx = 0, dy = 22, blur = 34, alpha = 0.45 } = opts;
  ctx.save();
  ctx.translate(centerX2, centerY);
  ctx.rotate((angle * Math.PI) / 180);
  ctx.shadowColor = `rgba(30,28,60,${alpha})`;
  ctx.shadowBlur = blur * SS;
  ctx.shadowOffsetX = dx * SS;
  ctx.shadowOffsetY = dy * SS;
  ctx.drawImage(phone.canvas, -phone.w / 2, -phone.h / 2);
  ctx.restore();
};

// ---- header wordmark -------------------------------------------------------
const px = M + 6 * SS;
const py = Y(86);
const pr = 15 * SS;
ctx.strokeStyle = INDIGO;
ctx.lineWidth = 5 * SS;
ctx.beginPath();
ctx.arc(px + pr, py + pr, pr, 0, Math.PI * 2);
ctx.stroke();
ctx.fillStyle = INDIGO;
ctx.beginPath();
ctx.arc(px + pr, py + pr, 5 * SS, 0, Math.PI * 2);
ctx.fill();
ctx.beginPath();
ctx.moveTo(px + pr - 10 * SS, py + 2 * pr - 4 * SS);
ctx.lineTo(px + pr + 10 * SS, py + 2 * pr - 4 * SS);
ctx.lineTo(px + pr, py + 2 * pr + 18 * SS);
ctx.closePath();
ctx.fill();

drawText('BJJ OPEN MAT', px + 2 * pr + 22 * SS, Y(72), font('BigShoulders', 74), INK);
const kick = font('DMMono', 18);
const kt = 'FIND YOUR NEXT ROLL';
drawText(kt, cw - M - textWidth(ctx, kt, kick), Y(104), kick, BONE_D);
ctx.strokeStyle = LINE;
ctx.lineWidth = 1;
ctx.beginPath();
ctx.moveTo(M, Y(150));
ctx.lineTo(cw - M, Y(150));
ctx.stroke();

// ---- phones ----------------------------------------------------------------
const phoneDetail = await makePhone(`${SHOTS}/2-rm-elite-detail.png`, 560);
const phoneFind = await makePhone(`${SHOTS}/1-find-75495.png`, 620);
place(phoneDetail, cw * 0.66, Y(452), { angle: -7, dy: 20, blur: 40, alpha: 0.36 });
place(phoneFind, cw * 0.40, Y(470), { angle: 5, dy: 24, blur: 46, alpha: 0.47 });

// ---- tagline ---------------------------------------------------------------
const tag = font('OutfitBold', 40);
const tsub = font('Outfit', 26);
const ty = Y(824);
const line1 = 'Every open mat near you.';
drawText(line1, centerX(ctx, line1, tag), ty, tag, INK);
const line2 = "Search by location or date  ·  See who's going  ·  RSVP  ·  Log your rolls";
drawText(line2, centerX(ctx, line2, tsub), ty + 54 * SS, tsub, BONE_D);

// ---- availability chips ----------------------------------------------------
const chipF = font('BigShoulders', 40);
const sm = font('DMMono', 17);
const ay = Y(910);
const chipH = 84 * SS;
const gap = 30 * SS;

const chipWidth = (main: string, sub: string): number =>
  Math.max(textWidth(ctx, main, chipF), textWidth(ctx, sub, sm)) + 3 * 15 * SS + 40 * SS;

const w1 = chipWidth('ANDROID', 'AVAILABLE NOW');
const w2 = chipWidth('APPLE', 'COMING SOON');
const x0 = Math.round((cw - (w1 + w2 + gap)) / 2);

const drawChip = (x: number, w: number, main: string, sub: string, live: boolean): void => {
  roundRectPath(ctx, x, ay, w, chipH, 20 * SS);
  ctx.fillStyle = CARD;
  ctx.fill();
  ctx.strokeStyle = live ? INDIGO : LINE;
  ctx.lineWidth = 2 * SS;
  ctx.stroke();
  const dot = 9 * SS;
  const dx = x + 24 * SS;
  const dcy = ay + chipH / 2;
  ctx.beginPath();
  ctx.arc(dx + dot, dcy, dot, 0, Math.PI * 2);
  if (live) {
    ctx.fillStyle = GREEN;
    ctx.fill();
  } else {
    ctx.strokeStyle = MUTE;
    ctx.lineWidth = 2 * SS;
    ctx.stroke();
  }
  const tx = dx + 3 * dot;
  drawText(main, tx, ay + 12 * SS, chipF, live ? INK : MUTE);
  drawText(sub, tx + 2 * SS, ay + 52 * SS, sm, live ? GREEN : MUTE);
};

drawChip(x0, w1, 'ANDROID', 'AVAILABLE NOW', true);
drawChip(x0 + w1 + gap, w2, 'APPLE', 'COMING SOON', false);

// ---- QR card ---------------------------------------------------------------
const qsize = 176 * SS;
const qrBuf = await QRCode.toBuffer(PLAY_URL, {
  errorCorrectionLevel: 'H',
  margin: 2,
  width: qsize,
  color: { dark: '#181A2E', light: '#FFFFFF' },
});
const qrImg = await loadImage(qrBuf);

const cardY = Y(1050);
const cardH = Y(228);
const cx0 = M;
const cx1 = cw - M;

ctx.save();
roundRectPath(ctx, cx0, cardY, cx1 - cx0, cardH, 26 * SS);
ctx.shadowColor = 'rgba(40,40,80,0.28)';
ctx.shadowBlur = 30 * SS;
ctx.shadowOffsetY = 8 * SS;
ctx.fillStyle = CARD;
ctx.fill();
ctx.restore();
roundRectPath(ctx, cx0, cardY, cx1 - cx0, cardH, 26 * SS);
ctx.strokeStyle = LINE;
ctx.lineWidth = 2 * SS;
ctx.stroke();

const qx = cx0 + 30 * SS;
const qy = cardY + (cardH - qsize) / 2;
ctx.drawImage(qrImg, qx, qy, qsize, qsize);
roundRectPath(ctx, qx - 6 * SS, qy - 6 * SS, qsize + 12 * SS, qsize + 12 * SS, 10 * SS);
ctx.strokeStyle = LINE;
ctx.lineWidth = 2 * SS;
ctx.stroke();

const txx = qx + qsize + 42 * SS;
const scanF = font('BigShoulders', 48);
drawText('SCAN  TO', txx, cardY + 40 * SS, scanF, INK);
drawText('INSTALL', txx, cardY + 84 * SS, scanF, INDIGO);
ctx.strokeStyle = LINE;
ctx.lineWidth = 1;
ctx.beginPath();
ctx.moveTo(txx, cardY + 144 * SS);
ctx.lineTo(cx1 - 34 * SS, cardY + 144 * SS);
ctx.stroke();
drawText('GOOGLE PLAY  >  FREE', txx, cardY + 160 * SS, sm, BONE_D);
drawText('bjjopenmat.app', txx, cardY + 190 * SS, font('DMMono', 22), INK);

// ---- footer url ------------------------------------------------------------
const url = 'play.google.com/store/apps/details?id=com.davissylvester.bjjopenmat';
const uf = font('DMMono', 15);
drawText(url, centerX(ctx, url, uf), Y(1305), uf, BONE_D);

// ---- downsample + output ---------------------------------------------------
const out: Canvas = createCanvas(W, H);
const octx: SKRSContext2D = out.getContext('2d');
octx.imageSmoothingEnabled = true;
octx.imageSmoothingQuality = 'high';
octx.drawImage(canvas, 0, 0, W, H);
writeFileSync(OUT, out.toBuffer('image/png'));
// eslint-disable-next-line no-console
console.log('saved', OUT);
