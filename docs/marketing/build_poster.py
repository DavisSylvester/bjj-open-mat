"""BJJ Open Mat — light-theme launch poster with real app screenshots.
Renders a 1080x1350 Facebook-portrait PNG with an embedded Play Store QR code.

Python reference implementation. A functionally equivalent TypeScript port lives
alongside this file as build-poster.mts (the project's canonical stack).
"""
import segno
from PIL import Image, ImageDraw, ImageFont, ImageFilter

FONTS = "C:/Users/davis/.claude/plugins/marketplaces/anthropic-agent-skills/skills/canvas-design/canvas-fonts"
SHOTS = "C:/projects/davisSylvester/bjj-open-mat/build/ios-screenshots"
OUT = "C:/projects/davisSylvester/bjj-open-mat/docs/marketing/bjj-open-mat-launch.png"
PLAY_URL = "https://play.google.com/store/apps/details?id=com.davissylvester.bjjopenmat"

# ---- palette (app light theme: white + indigo/violet) ----------------------
BG_TOP  = (246, 247, 252)
BG_BOT  = (231, 233, 246)
INK     = (24, 26, 46)       # near-black indigo ink
INDIGO  = (88, 86, 214)      # app accent
VIOLET  = (124, 92, 246)
GREEN   = (16, 175, 128)
MUTE    = (150, 154, 172)
BONE_D  = (108, 112, 134)
CARD    = (255, 255, 255)
LINE    = (223, 226, 238)

SS = 2
W, H = 1080, 1350
cw, ch = W * SS, H * SS

def f(name, size):
    return ImageFont.truetype(f"{FONTS}/{name}", size * SS)

def Y(v):
    return v * SS

# ---- background: vertical gradient + soft indigo blobs ---------------------
base = Image.new("RGB", (cw, ch), BG_TOP)
grad = Image.new("L", (1, ch))
for y in range(ch):
    grad.putpixel((0, y), int(y / ch * 255))
grad = grad.resize((cw, ch))
base = Image.composite(Image.new("RGB", (cw, ch), BG_BOT), base, grad)
base = base.convert("RGBA")

blob = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
bd = ImageDraw.Draw(blob)
bd.ellipse([-Y(160), -Y(200), Y(360), Y(240)], fill=(124, 92, 246, 42))
bd.ellipse([cw - Y(300), -Y(160), cw + Y(220), Y(300)], fill=(88, 86, 214, 40))
bd.ellipse([cw - Y(240), ch - Y(320), cw + Y(260), ch + Y(180)], fill=(124, 92, 246, 34))
blob = blob.filter(ImageFilter.GaussianBlur(Y(90)))
base = Image.alpha_composite(base, blob)

d = ImageDraw.Draw(base)

def cx(text, font):
    b = d.textbbox((0, 0), text, font=font)
    return (cw - (b[2] - b[0])) // 2 - b[0]

def tw(text, font):
    b = d.textbbox((0, 0), text, font=font)
    return b[2] - b[0]

M = 70 * SS

# ---- phone builder ---------------------------------------------------------
def round_corners(im, rad):
    mask = Image.new("L", im.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, im.size[0], im.size[1]], radius=rad, fill=255)
    out = im.convert("RGBA")
    out.putalpha(mask)
    return out

def make_phone(path, phone_h):
    ph = phone_h * SS
    bez = 12 * SS
    sc = Image.open(path).convert("RGB")
    inner_h = ph - 2 * bez
    inner_w = int(sc.width * inner_h / sc.height)
    sc = sc.resize((inner_w, inner_h), Image.LANCZOS)
    sc = round_corners(sc, 30 * SS)
    pw = inner_w + 2 * bez
    frame = Image.new("RGBA", (pw, ph), (0, 0, 0, 0))
    body = Image.new("RGBA", (pw, ph), (17, 18, 28, 255))
    body = round_corners(body, 42 * SS)
    frame = Image.alpha_composite(frame, body)
    frame.alpha_composite(sc, (bez, bez))
    return frame

def place(obj, center_x, center_y, angle=0, shadow=True, dx=0, dy=22, blur=34, s_alpha=115):
    if angle:
        obj = obj.rotate(angle, expand=True, resample=Image.BICUBIC)
    ox = int(center_x - obj.size[0] / 2)
    oy = int(center_y - obj.size[1] / 2)
    if shadow:
        a = obj.split()[3].point(lambda p: int(p * s_alpha / 255))
        sh = Image.new("RGBA", obj.size, (30, 28, 60, 0))
        sh.putalpha(a)
        sh = sh.filter(ImageFilter.GaussianBlur(blur))
        base.alpha_composite(sh, (ox + dx * SS, oy + dy * SS))
    base.alpha_composite(obj, (ox, oy))

# ---- header wordmark -------------------------------------------------------
wm = f("BigShoulders-Bold.ttf", 74)
px, py = M + 6 * SS, Y(86)
pr = 15 * SS
d.ellipse([px, py, px + 2 * pr, py + 2 * pr], outline=INDIGO, width=5 * SS)
d.ellipse([px + pr - 5 * SS, py + pr - 5 * SS, px + pr + 5 * SS, py + pr + 5 * SS], fill=INDIGO)
d.polygon([(px + pr - 10 * SS, py + 2 * pr - 4 * SS), (px + pr + 10 * SS, py + 2 * pr - 4 * SS),
           (px + pr, py + 2 * pr + 18 * SS)], fill=INDIGO)
d.text((px + 2 * pr + 22 * SS, Y(72)), "BJJ OPEN MAT", font=wm, fill=INK)
kick = f("DMMono-Regular.ttf", 18)
kt = "FIND YOUR NEXT ROLL"
d.text((cw - M - tw(kt, kick), Y(104)), kt, font=kick, fill=BONE_D)
d.line([(M, Y(150)), (cw - M, Y(150))], fill=LINE, width=1)

# ---- phones ----------------------------------------------------------------
phone_find   = make_phone(f"{SHOTS}/1-find-75495.png", 620)
phone_detail = make_phone(f"{SHOTS}/2-rm-elite-detail.png", 560)
place(phone_detail, cw * 0.66, Y(452), angle=-7, dy=20, blur=40, s_alpha=95)
place(phone_find, cw * 0.40, Y(470), angle=5, dy=24, blur=46, s_alpha=120)

# ---- tagline ---------------------------------------------------------------
tag = f("Outfit-Bold.ttf", 40)
tsub = f("Outfit-Regular.ttf", 26)
ty = Y(824)
line1 = "Every open mat near you."
d.text((cx(line1, tag), ty), line1, font=tag, fill=INK)
line2 = "Search by location or date  ·  See who's going  ·  RSVP  ·  Log your rolls"
d.text((cx(line2, tsub), ty + 54 * SS), line2, font=tsub, fill=BONE_D)

# ---- availability chips ----------------------------------------------------
chip_f = f("BigShoulders-Bold.ttf", 40)
sm = f("DMMono-Regular.ttf", 17)
ay = Y(910)
chip_h = 84 * SS
gap = 30 * SS

def chip_w(text_main, text_sub):
    return max(tw(text_main, chip_f), tw(text_sub, sm)) + 3 * 15 * SS + 40 * SS

w1 = chip_w("ANDROID", "AVAILABLE NOW")
w2 = chip_w("APPLE", "COMING SOON")
total = w1 + w2 + gap
x0 = (cw - total) // 2

def draw_chip(x, w, main, subt, live):
    y0 = ay
    d.rounded_rectangle([x, y0, x + w, y0 + chip_h], radius=20 * SS,
                        fill=CARD, outline=(INDIGO if live else LINE), width=2 * SS)
    dot = 9 * SS
    dx = x + 24 * SS
    dcy = y0 + chip_h // 2
    if live:
        d.ellipse([dx, dcy - dot, dx + 2 * dot, dcy + dot], fill=GREEN)
    else:
        d.ellipse([dx, dcy - dot, dx + 2 * dot, dcy + dot], outline=MUTE, width=2 * SS)
    tx = dx + 3 * dot
    d.text((tx, y0 + 12 * SS), main, font=chip_f, fill=(INK if live else MUTE))
    d.text((tx + 2 * SS, y0 + 52 * SS), subt, font=sm, fill=(GREEN if live else MUTE))

draw_chip(x0, w1, "ANDROID", "AVAILABLE NOW", True)
draw_chip(x0 + w1 + gap, w2, "APPLE", "COMING SOON", False)

# ---- QR card ---------------------------------------------------------------
qr = segno.make(PLAY_URL, error="h")
qr.save("C:/projects/davisSylvester/bjj-open-mat/docs/marketing/_qr.png",
        scale=8 * SS, border=2, dark="#181A2E", light="#FFFFFF")
qimg = Image.open("C:/projects/davisSylvester/bjj-open-mat/docs/marketing/_qr.png").convert("RGB")

card_y = Y(1050)
card_h = Y(228)
cx0 = M
cx1 = cw - M
cardshadow = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
ImageDraw.Draw(cardshadow).rounded_rectangle([cx0, card_y + 6 * SS, cx1, card_y + card_h + 6 * SS],
                                             radius=26 * SS, fill=(40, 40, 80, 70))
cardshadow = cardshadow.filter(ImageFilter.GaussianBlur(18 * SS))
base.alpha_composite(cardshadow)
d = ImageDraw.Draw(base)
d.rounded_rectangle([cx0, card_y, cx1, card_y + card_h], radius=26 * SS, fill=CARD, outline=LINE, width=2 * SS)

qsize = 176 * SS
qimg = qimg.resize((qsize, qsize), Image.NEAREST)
qx = cx0 + 30 * SS
qy = card_y + (card_h - qsize) // 2
base.paste(qimg, (qx, qy))
d.rounded_rectangle([qx - 6 * SS, qy - 6 * SS, qx + qsize + 6 * SS, qy + qsize + 6 * SS],
                    radius=10 * SS, outline=LINE, width=2 * SS)

txx = qx + qsize + 42 * SS
scan_f = f("BigShoulders-Bold.ttf", 48)
d.text((txx, card_y + 40 * SS), "SCAN  TO", font=scan_f, fill=INK)
d.text((txx, card_y + 84 * SS), "INSTALL", font=scan_f, fill=INDIGO)
d.line([(txx, card_y + 144 * SS), (cx1 - 34 * SS, card_y + 144 * SS)], fill=LINE, width=1)
d.text((txx, card_y + 160 * SS), "GOOGLE PLAY  >  FREE", font=sm, fill=BONE_D)
d.text((txx, card_y + 190 * SS), "bjjopenmat.app", font=f("DMMono-Regular.ttf", 22), fill=INK)

# ---- footer url ------------------------------------------------------------
url = "play.google.com/store/apps/details?id=com.davissylvester.bjjopenmat"
uf = f("DMMono-Regular.ttf", 15)
d.text((cx(url, uf), Y(1305)), url, font=uf, fill=BONE_D)

# ---- output ----------------------------------------------------------------
final = base.convert("RGB").resize((W, H), Image.LANCZOS)
final.save(OUT, "PNG")
print("saved", OUT)
