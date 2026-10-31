"""Vẽ ảnh minh họa cây (dữ liệu mẫu cho test/tài liệu)."""
import math, random, sys, os
from PIL import Image, ImageDraw, ImageFilter

out = sys.argv[1]
W, H = 1200, 900

def bg(top, bottom):
    im = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(im)
    for y in range(H):
        t = y / H
        d.line([(0, y), (W, y)], fill=tuple(int(top[i] * (1 - t) + bottom[i] * t) for i in range(3)))
    return im

def pot(d, cx, base, w, h, color, rim):
    d.polygon([(cx - w / 2, base - h), (cx + w / 2, base - h), (cx + w * 0.38, base), (cx - w * 0.38, base)], fill=color)
    d.rounded_rectangle((cx - w / 2 - 14, base - h - 26, cx + w / 2 + 14, base - h + 8), radius=10, fill=rim)

def leaf(d, cx, cy, length, width, angle, color, vein=None):
    pts = []
    n = 60
    for i in range(n + 1):
        t = i / n; pts.append(((t - .5) * length, math.sin(math.pi * t) * width / 2))
    for i in range(n, -1, -1):
        t = i / n; pts.append(((t - .5) * length, -math.sin(math.pi * t) * width / 2))
    a = math.radians(angle)
    P = [(cx + x * math.cos(a) - y * math.sin(a), cy + x * math.sin(a) + y * math.cos(a)) for x, y in pts]
    d.polygon(P, fill=color)
    if vein:
        d.line([(cx - length / 2 * math.cos(a), cy - length / 2 * math.sin(a)), (cx + length / 2 * math.cos(a), cy + length / 2 * math.sin(a))], fill=vein, width=4)

def shadow(im, cx, base):
    sh = Image.new("RGBA", im.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).ellipse((cx - 220, base - 25, cx + 220, base + 25), fill=(0, 0, 0, 60))
    im.paste(sh.filter(ImageFilter.GaussianBlur(14)), (0, 0), sh.filter(ImageFilter.GaussianBlur(14)))

def monstera(path):
    im = bg((233, 243, 234), (211, 232, 214)); d = ImageDraw.Draw(im); random.seed(1)
    cx, base = 600, 820
    shadow(im, cx, base)
    for ang, ln in [(-150, 420), (-120, 470), (-90, 500), (-60, 470), (-30, 420), (-105, 380), (-75, 380)]:
        a = math.radians(ang)
        ex, ey = cx + math.cos(a) * ln * .75, base - 260 + math.sin(a) * ln * .75
        d.line([(cx, base - 260), (ex, ey)], fill=(47, 130, 73), width=10)
        leaf(d, ex, ey, 300, 230, ang + 90, (31, 107, 58), (79, 156, 99))
        for k in range(3):  # khe lá monstera
            off = (k - 1) * 70
            d.line([(ex + off * math.cos(a + 1.57), ey + off * math.sin(a + 1.57)), (ex + off * 1.6 * math.cos(a + 1.57), ey + off * 1.6 * math.sin(a + 1.57))], fill=(211, 232, 214), width=10)
    pot(d, cx, base, 320, 250, (196, 112, 70), (214, 132, 88))
    im.save(path, quality=90)

def snake(path):
    im = bg((253, 243, 207), (249, 224, 138)); d = ImageDraw.Draw(im)
    cx, base = 600, 820
    shadow(im, cx, base)
    for i, (dx, h, ang) in enumerate([(-90, 470, -8), (-40, 560, -3), (10, 600, 1), (60, 520, 5), (100, 430, 10), (-130, 380, -14)]):
        x0 = cx + dx; top = base - 230 - h
        w = 70
        d.polygon([(x0 - w / 2, base - 230), (x0 + w / 2, base - 230), (x0 + ang * 6 + 6, top), (x0 + ang * 6 - 6, top + 20)], fill=(31, 107, 58))
        for y in range(int(top + 40), base - 240, 46):
            d.line([(x0 - w / 2 + 10 + (y - top) * 0, y), (x0 + w / 2 - 12, y + 10)], fill=(79, 156, 99), width=6)
        d.line([(x0 - w / 2, base - 230), (x0 + ang * 6 - 6, top + 20)], fill=(242, 194, 48), width=6)
    pot(d, cx, base, 300, 240, (238, 242, 234), (211, 220, 205))
    im.save(path, quality=90)

def succulent(path):
    im = bg((232, 241, 249), (207, 226, 242)); d = ImageDraw.Draw(im)
    cx, base = 600, 800
    shadow(im, cx, base)
    cy = base - 300
    for ring, (n, ln, wd, col) in enumerate([(10, 330, 120, (79, 156, 99)), (9, 260, 105, (124, 185, 138)), (7, 180, 90, (169, 210, 176)), (5, 100, 70, (211, 232, 214))]):
        for k in range(n):
            ang = 360 / n * k + ring * 17
            a = math.radians(ang)
            leaf(d, cx + math.cos(a) * ln / 2.4, cy + math.sin(a) * ln / 4, ln, wd, ang, col)
    pot(d, cx, base, 360, 200, (102, 114, 95), (143, 156, 137))
    im.save(path, quality=90)

def pothos(path):
    im = bg((238, 242, 234), (227, 233, 222)); d = ImageDraw.Draw(im); random.seed(4)
    cx, base = 600, 520
    for side in (-1, 1):
        pts = [(cx + side * 120, base - 200)]
        for k in range(1, 9):
            pts.append((cx + side * (140 + k * 38 + random.randint(-12, 12)), base - 200 + k * 70))
        d.line(pts, fill=(47, 130, 73), width=8)
        for k, (x, y) in enumerate(pts[1:]):
            leaf(d, x + side * 30, y, 120, 95, side * 60 + random.randint(-20, 20), (31, 107, 58) if k % 2 else (242, 194, 48) if k == 3 else (79, 156, 99), (124, 185, 138))
    for k in range(9):
        a = math.radians(-160 + k * 18)
        leaf(d, cx + math.cos(a) * 160, base - 230 + math.sin(a) * 120, 150, 115, math.degrees(a), (31, 107, 58), (79, 156, 99))
    pot(d, cx, base, 340, 220, (16, 54, 30), (25, 88, 47))
    im.save(path, quality=90)

def hero(path):
    im = bg((25, 88, 47), (16, 54, 30)); d = ImageDraw.Draw(im); random.seed(9)
    for k in range(40):
        x, y = random.randint(-100, W), random.randint(-100, H)
        leaf(d, x, y, random.randint(160, 340), random.randint(80, 160), random.randint(0, 360), random.choice([(31, 107, 58), (47, 130, 73), (79, 156, 99), (242, 194, 48)]), None)
    im = im.filter(ImageFilter.GaussianBlur(1.2))
    im.save(path, quality=90)

os.makedirs(out, exist_ok=True)
monstera(f"{out}/monstera.jpg"); snake(f"{out}/luoi-ho.jpg"); succulent(f"{out}/sen-da.jpg"); pothos(f"{out}/trau-ba.jpg"); hero(f"{out}/vuon.jpg")
print("ok")
