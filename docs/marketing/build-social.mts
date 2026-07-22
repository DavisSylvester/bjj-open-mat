/**
 * BJJ Open Mat — social launch assets in multiple aspect ratios.
 *
 *   square  1080x1080  (feed / Instagram)
 *   story   1080x1920  (stories / reels cover)
 *
 * Shares the light theme, real screenshots and Play Store QR of build-poster.mts,
 * but each ratio gets its own composition. Run: bun run build-social.mts
 */
import { createCanvas, loadImage, GlobalFonts, type SKRSContext2D, type Canvas, type Image } from '@napi-rs/canvas';
import QRCode from 'qrcode';
import { writeFileSync } from 'node:fs';
import { join } from 'node:path';

// ---- paths -----------------------------------------------------------------
const FONTS: string = 'C:/Users/davis/.claude/plugins/marketplaces/anthropic-agent-skills/skills/canvas-design/canvas-fonts';
const HERE: string = import.meta.dir;
const SHOTS: string = join(HERE, '..', '..', 'build', 'ios-screenshots');
const PLAY_URL: string = 'https://play.google.com/store/apps/details?id=com.davissylvester.bjjopenmat';

// ---- palette ---------------------------------------------------------------
const INK: string = '#181A2E';
const INDIGO: string = '#5856D6';
const GREEN: string = '#10AF80';
const MUTE: string = '#969AAC';
const BONE_D: string = '#6C7086';
const CARD: string = '#FFFFFF';
const LINE: string = '#DFE2EE';
const BODY: string = '#11121C';

const SS: number = 2;
const Y = (v: number): number => v * SS;

GlobalFonts.registerFromPath(`${FONTS}/BigShoulders-Bold.ttf`, 'BigShoulders');
GlobalFonts.registerFromPath(`${FONTS}/Outfit-Bold.ttf`, 'OutfitBold');
GlobalFonts.registerFromPath(`${FONTS}/Outfit-Regular.ttf`, 'Outfit');
GlobalFonts.registerFromPath(`${FONTS}/DMMono-Regular.ttf`, 'DMMono');

const font = (family: string, size: number): string => `${size * SS}px ${family}`;

// ---- shared primitives -----------------------------------------------------
const textWidth = (ctx: SKRSContext2D, text: string, f: string): number => {
  ctx.font = f;
  return ctx.measureText(text).width;
};

const drawText = (ctx: SKRSContext2D, text: string, x: number, y: number, f: string, color: string): void => {
  ctx.font = f;
  ctx.fillStyle = color;
  ctx.fillText(text, x, y);
};

const centerText = (ctx: SKRSContext2D, cw: number, text: string, y: number, f: string, color: string): void => {
  drawText(ctx, text, Math.round((cw - textWidth(ctx, text, f)) / 2), y, f, color);
};

const roundRectPath = (ctx: SKRSContext2D, x: number, y: number, w: number, h: number, r: number): void => {
  ctx.beginPath();
  ctx.roundRect(x, y, w, h, r);
};

const paintBackground = (ctx: SKRSContext2D, cw: number, ch: number): void => {
  const grad = ctx.createLinearGradient(0, 0, 0, ch);
  grad.addColorStop(0, '#F6F7FC');
  grad.addColorStop(1, '#E7E9F6');
  ctx.fillStyle = grad;
  ctx.fillRect(0, 0, cw, ch);
  const blob = (bx: number, by: number, r: number, rgb: string, a: number): void => {
    const g = ctx.createRadialGradient(bx, by, 0, bx, by, r);
    g.addColorStop(0, `rgba(${rgb},${a})`);
    g.addColorStop(1, `rgba(${rgb},0)`);
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, cw, ch);
  };
  blob(Y(80), Y(20), Y(380), '124,92,246', 0.26);
  blob(cw - Y(20), Y(60), Y(380), '88,86,214', 0.24);
  blob(cw - Y(10), ch - Y(60), Y(400), '124,92,246', 0.2);
};

interface Phone {
  readonly canvas: Canvas;
  readonly w: number;
  readonly h: number;
}

const makePhone = async (path: string, phoneH: number): Promise<Phone> => {
  const img: Image = await loadImage(path);
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
  readonly dy?: number;
  readonly blur?: number;
  readonly alpha?: number;
}

const place = (ctx: SKRSContext2D, phone: Phone, cx: number, cy: number, opts: PlaceOpts = {}): void => {
  const { angle = 0, dy = 22, blur = 40, alpha = 0.42 } = opts;
  ctx.save();
  ctx.translate(cx, cy);
  ctx.rotate((angle * Math.PI) / 180);
  ctx.shadowColor = `rgba(30,28,60,${alpha})`;
  ctx.shadowBlur = blur * SS;
  ctx.shadowOffsetY = dy * SS;
  ctx.drawImage(phone.canvas, -phone.w / 2, -phone.h / 2);
  ctx.restore();
};

const wordmark = (ctx: SKRSContext2D, cw: number, x: number, y: number, size: number): void => {
  const pr = (size * 0.2) * SS;
  const px = x;
  const py = y + (size * 0.14) * SS;
  ctx.strokeStyle = INDIGO;
  ctx.lineWidth = 5 * SS;
  ctx.beginPath();
  ctx.arc(px + pr, py + pr, pr, 0, Math.PI * 2);
  ctx.stroke();
  ctx.fillStyle = INDIGO;
  ctx.beginPath();
  ctx.arc(px + pr, py + pr, pr * 0.34, 0, Math.PI * 2);
  ctx.fill();
  ctx.beginPath();
  ctx.moveTo(px + pr - pr * 0.66, py + 2 * pr - 4 * SS);
  ctx.lineTo(px + pr + pr * 0.66, py + 2 * pr - 4 * SS);
  ctx.lineTo(px + pr, py + 2 * pr + pr * 1.1);
  ctx.closePath();
  ctx.fill();
  drawText(ctx, 'BJJ OPEN MAT', px + 2 * pr + 22 * SS, y, font('BigShoulders', size), INK);
};

const chip = (ctx: SKRSContext2D, x: number, y: number, w: number, h: number, main: string, sub: string, live: boolean, mainSize: number): void => {
  roundRectPath(ctx, x, y, w, h, 20 * SS);
  ctx.fillStyle = CARD;
  ctx.fill();
  ctx.strokeStyle = live ? INDIGO : LINE;
  ctx.lineWidth = 2 * SS;
  ctx.stroke();
  const dot = 9 * SS;
  const dx = x + 24 * SS;
  const dcy = y + h / 2;
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
  drawText(ctx, main, tx, y + (h - mainSize * 1.35 * SS) / 2 - 6 * SS, font('BigShoulders', mainSize), live ? INK : MUTE);
  drawText(ctx, sub, tx + 2 * SS, y + h / 2 + 6 * SS, font('DMMono', 16), live ? GREEN : MUTE);
};

const qrCard = async (ctx: SKRSContext2D, x: number, y: number, w: number, h: number, qsize: number): Promise<void> => {
  const qrBuf = await QRCode.toBuffer(PLAY_URL, {
    errorCorrectionLevel: 'H',
    margin: 2,
    width: qsize,
    color: { dark: '#181A2E', light: '#FFFFFF' },
  });
  const qrImg = await loadImage(qrBuf);
  ctx.save();
  roundRectPath(ctx, x, y, w, h, 26 * SS);
  ctx.shadowColor = 'rgba(40,40,80,0.26)';
  ctx.shadowBlur = 30 * SS;
  ctx.shadowOffsetY = 8 * SS;
  ctx.fillStyle = CARD;
  ctx.fill();
  ctx.restore();
  roundRectPath(ctx, x, y, w, h, 26 * SS);
  ctx.strokeStyle = LINE;
  ctx.lineWidth = 2 * SS;
  ctx.stroke();

  const qx = x + 30 * SS;
  const qy = y + (h - qsize) / 2;
  ctx.drawImage(qrImg, qx, qy, qsize, qsize);
  roundRectPath(ctx, qx - 6 * SS, qy - 6 * SS, qsize + 12 * SS, qsize + 12 * SS, 10 * SS);
  ctx.strokeStyle = LINE;
  ctx.lineWidth = 2 * SS;
  ctx.stroke();

  const txx = qx + qsize + 40 * SS;
  drawText(ctx, 'SCAN  TO', txx, y + h * 0.2, font('BigShoulders', 46), INK);
  drawText(ctx, 'INSTALL', txx, y + h * 0.2 + 42 * SS, font('BigShoulders', 46), INDIGO);
  ctx.strokeStyle = LINE;
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(txx, y + h * 0.2 + 100 * SS);
  ctx.lineTo(x + w - 34 * SS, y + h * 0.2 + 100 * SS);
  ctx.stroke();
  drawText(ctx, 'GOOGLE PLAY  >  FREE', txx, y + h * 0.2 + 116 * SS, font('DMMono', 16), BONE_D);
  drawText(ctx, 'bjjopenmat.app', txx, y + h * 0.2 + 146 * SS, font('DMMono', 22), INK);
};

const bullet = (ctx: SKRSContext2D, x: number, y: number, text: string, size: number): void => {
  const r = 6 * SS;
  ctx.fillStyle = INDIGO;
  ctx.beginPath();
  ctx.arc(x + r, y + size * 0.7 * SS, r, 0, Math.PI * 2);
  ctx.fill();
  drawText(ctx, text, x + 3 * r, y, font('Outfit', size), INK);
};

const save = (canvas: Canvas, w: number, h: number, name: string): void => {
  const out = createCanvas(w, h);
  const octx = out.getContext('2d');
  octx.imageSmoothingEnabled = true;
  octx.imageSmoothingQuality = 'high';
  octx.drawImage(canvas, 0, 0, w, h);
  const path = join(HERE, name);
  writeFileSync(path, out.toBuffer('image/png'));
  // eslint-disable-next-line no-console
  console.log('saved', path);
};

// ---- SQUARE 1080x1080 ------------------------------------------------------
const renderSquare = async (): Promise<void> => {
  const W = 1080, H = 1080;
  const cw = W * SS, ch = H * SS, M = 60 * SS;
  const canvas = createCanvas(cw, ch);
  const ctx = canvas.getContext('2d');
  ctx.textBaseline = 'top';
  paintBackground(ctx, cw, ch);

  wordmark(ctx, cw, M, Y(52), 56);
  const kick = font('DMMono', 17);
  drawText(ctx, 'ANDROID · AVAILABLE NOW', cw - M - textWidth(ctx, 'ANDROID · AVAILABLE NOW', kick), Y(76), kick, BONE_D);
  ctx.strokeStyle = LINE;
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(M, Y(126));
  ctx.lineTo(cw - M, Y(126));
  ctx.stroke();

  const phone = await makePhone(`${SHOTS}/1-find-75495.png`, 700);
  place(ctx, phone, cw * 0.27, Y(495), { angle: -4, dy: 22, blur: 46, alpha: 0.44 });

  const rx = Math.round(cw * 0.52);
  drawText(ctx, 'Every open mat', rx, Y(180), font('OutfitBold', 48), INK);
  drawText(ctx, 'near you.', rx, Y(238), font('OutfitBold', 48), INDIGO);

  const bullets = [
    'Search by location, date or distance',
    "See who's going & RSVP",
    'Log every training session',
    'Community-added open mats',
  ];
  bullets.forEach((b, i) => bullet(ctx, rx, Y(330) + i * Y(58), b, 24));

  const cardW = cw - 2 * M;
  await qrCard(ctx, M, Y(820), cardW, Y(200), 150 * SS);

  const url = 'play.google.com/store/apps/details?id=com.davissylvester.bjjopenmat';
  const uf = font('DMMono', 14);
  centerText(ctx, cw, url, Y(1042), uf, BONE_D);

  save(canvas, W, H, 'bjj-open-mat-square.png');
};

// ---- STORY 1080x1920 -------------------------------------------------------
const renderStory = async (): Promise<void> => {
  const W = 1080, H = 1920;
  const cw = W * SS, ch = H * SS, M = 70 * SS;
  const canvas = createCanvas(cw, ch);
  const ctx = canvas.getContext('2d');
  ctx.textBaseline = 'top';
  paintBackground(ctx, cw, ch);

  wordmark(ctx, cw, M, Y(96), 74);
  ctx.strokeStyle = LINE;
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(M, Y(178));
  ctx.lineTo(cw - M, Y(178));
  ctx.stroke();

  centerText(ctx, cw, 'Every open mat near you.', Y(226), font('OutfitBold', 54), INK);
  centerText(ctx, cw, "Search  ·  See who's going  ·  RSVP  ·  Log your rolls", Y(298), font('Outfit', 28), BONE_D);

  const phoneDetail = await makePhone(`${SHOTS}/2-rm-elite-detail.png`, 860);
  const phoneFind = await makePhone(`${SHOTS}/1-find-75495.png`, 950);
  place(ctx, phoneDetail, cw * 0.66, Y(830), { angle: -7, dy: 22, blur: 46, alpha: 0.34 });
  place(ctx, phoneFind, cw * 0.40, Y(860), { angle: 5, dy: 26, blur: 52, alpha: 0.46 });

  // availability chips centered
  const chipH = 92 * SS;
  const cf = font('BigShoulders', 42);
  const sf = font('DMMono', 16);
  const cwid = (m: string, s: string): number => Math.max(textWidth(ctx, m, cf), textWidth(ctx, s, sf)) + 3 * 15 * SS + 44 * SS;
  const w1 = cwid('ANDROID', 'AVAILABLE NOW');
  const w2 = cwid('APPLE', 'COMING SOON');
  const gap = 34 * SS;
  const sx = Math.round((cw - (w1 + w2 + gap)) / 2);
  const cy = Y(1430);
  chip(ctx, sx, cy, w1, chipH, 'ANDROID', 'AVAILABLE NOW', true, 42);
  chip(ctx, sx + w1 + gap, cy, w2, chipH, 'APPLE', 'COMING SOON', false, 42);

  await qrCard(ctx, M, Y(1580), cw - 2 * M, Y(250), 200 * SS);

  const url = 'play.google.com/store/apps/details?id=com.davissylvester.bjjopenmat';
  centerText(ctx, cw, url, Y(1866), font('DMMono', 16), BONE_D);

  save(canvas, W, H, 'bjj-open-mat-story.png');
};

await renderSquare();
await renderStory();
