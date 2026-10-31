"""Tạo tài liệu PDF hướng dẫn app Chạm Xanh từ ảnh chụp + vị trí nút (shots.json do integration test xuất ra).

python3 build_pdf.py <thư mục ảnh> <file pdf> <font dir> [icon.png] [nguồn chụp]
"""
import json, math, os, sys, datetime
from PIL import Image, ImageDraw, ImageFont
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.lib.colors import HexColor, white
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas
from reportlab.lib.utils import ImageReader, simpleSplit

SHOTS, OUT, FONTS = sys.argv[1], sys.argv[2], sys.argv[3]
ICON = sys.argv[4] if len(sys.argv) > 4 else None
SOURCE = sys.argv[5] if len(sys.argv) > 5 else 'máy ảo Android'

RED = (220, 38, 38)
EMERALD, EMERALD_D, STONE, WOOD, INK = HexColor('#19582f'), HexColor('#10361e'), HexColor('#eef2ea'), HexColor('#f2c230'), HexColor('#14281b')
MUTED = HexColor('#4f5a49')

pdfmetrics.registerFont(TTFont('Body', f'{FONTS}/BeVietnamPro-Regular.ttf'))
pdfmetrics.registerFont(TTFont('Body-B', f'{FONTS}/BeVietnamPro-Bold.ttf'))
pdfmetrics.registerFont(TTFont('Body-SB', f'{FONTS}/BeVietnamPro-SemiBold.ttf'))
PIL_BOLD = f'{FONTS}/BeVietnamPro-Bold.ttf'

SECTIONS = [
    ('01', 'Bắt đầu'), ('03', 'Hồ sơ vườn'), ('07', 'Ảnh cây và lời nhắc'), ('12', 'Nhắc tưới'),
    ('13', 'Cộng đồng'), ('16', 'Khám phá'), ('18', 'Tin nhắn'), ('21', 'Tài khoản và nâng cấp gói'),
]


def annotate(shot, path_out):
    """Vẽ khung đỏ quanh nút, số thứ tự ở lề và mũi tên đỏ chỉ vào nút."""
    img = Image.open(os.path.join(SHOTS, shot['name'] + '.png')).convert('RGB')
    W, H = img.size
    k = W / shot['w']  # px ảnh / dp
    margin = int(W * 0.30)
    r = int(W * 0.045)
    bottom_marks = [m for m in shot['marks'] if (m['y'] + m['h'] / 2) * k > H * 0.88]
    use_bottom = len(bottom_marks) >= 3
    extra = int(r * 5) if use_bottom else 0
    canvas_img = Image.new('RGB', (W + 2 * margin, H + 40 + extra), (255, 255, 255))
    # khung điện thoại
    d = ImageDraw.Draw(canvas_img)
    d.rounded_rectangle((margin - 18, 2, margin + W + 18, H + 38), radius=int(W * 0.06), fill=(30, 33, 30))
    canvas_img.paste(img, (margin, 20))
    d = ImageDraw.Draw(canvas_img)
    font = ImageFont.truetype(PIL_BOLD, int(r * 1.15))
    lw = max(4, int(W * 0.007))

    marks = []
    for i, m in enumerate(shot['marks']):
        x0, y0 = margin + m['x'] * k, 20 + m['y'] * k
        x1, y1 = x0 + m['w'] * k, y0 + m['h'] * k
        cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
        side = 'L' if cx < margin + W / 2 else 'R'
        if use_bottom and m in bottom_marks:
            side = 'B'
        marks.append({'i': i + 1, 'box': (x0, y0, x1, y1), 'c': (cx, cy), 'side': side})

    # đặt số ở lề, giãn cách để không chồng nhau
    for side in ('L', 'R'):
        group = sorted([m for m in marks if m['side'] == side], key=lambda m: m['c'][1])
        last = -1e9
        for m in group:
            y = max(m['c'][1], last + 2.6 * r)
            y = min(y, H + 20 - r - 4)
            m['label'] = (margin / 2 if side == 'L' else margin + W + margin / 2, y)
            last = y
        # nếu bị đẩy quá đáy, kéo ngược lên
        for j in range(len(group) - 2, -1, -1):
            if group[j + 1]['label'][1] - group[j]['label'][1] < 2.6 * r:
                group[j]['label'] = (group[j]['label'][0], group[j + 1]['label'][1] - 2.6 * r)

    for m in marks:
        if m['side'] == 'B':
            m['label'] = (m['c'][0], H + 40 + extra / 2)

    for m in marks:
        x0, y0, x1, y1 = m['box']
        pad = 6
        d.rounded_rectangle((x0 - pad, y0 - pad, x1 + pad, y1 + pad), radius=14, outline=RED, width=lw)
        lx, ly = m['label']
        # điểm đích: cạnh khung gần số nhất
        if m['side'] == 'B':
            tx, ty, sx, sy = lx, y1 + pad, lx, ly - r
        else:
            tx = x0 - pad if m['side'] == 'L' else x1 + pad
            ty = min(max(ly, y0), y1)
            sx, sy = lx + (r if m['side'] == 'L' else -r), ly
        d.line((sx, sy, tx, ty), fill=RED, width=lw)
        ang = math.atan2(ty - sy, tx - sx)
        ah = r * 0.9
        p1 = (tx - ah * math.cos(ang - 0.45), ty - ah * math.sin(ang - 0.45))
        p2 = (tx - ah * math.cos(ang + 0.45), ty - ah * math.sin(ang + 0.45))
        d.polygon([(tx, ty), p1, p2], fill=RED)
        d.ellipse((lx - r, ly - r, lx + r, ly + r), fill=RED, outline=(255, 255, 255), width=4)
        d.text((lx, ly), str(m['i']), font=font, fill=(255, 255, 255), anchor='mm')
    canvas_img.save(path_out, quality=92)
    return canvas_img.size


def header(c, title, page):
    w, h = A4
    c.setFillColor(EMERALD)
    c.rect(0, h - 16 * mm, w, 16 * mm, stroke=0, fill=1)
    c.setFillColor(WOOD)
    c.setFont('Body-B', 11)
    c.drawString(15 * mm, h - 10 * mm, 'CHẠM XANH')
    c.setFillColor(white)
    c.setFont('Body', 10)
    c.drawRightString(w - 15 * mm, h - 10 * mm, title)
    c.setFillColor(MUTED)
    c.setFont('Body', 9)
    c.drawCentredString(w / 2, 9 * mm, f'Hướng dẫn sử dụng app Chạm Xanh · trang {page}')


def wrap(c, text, x, y, width, font='Body', size=11, leading=15, color=INK):
    c.setFont(font, size)
    c.setFillColor(color)
    for line in simpleSplit(text, font, size, width):
        c.drawString(x, y, line)
        y -= leading
    return y


def main():
    shots = sorted(json.load(open(os.path.join(SHOTS, 'shots.json'))), key=lambda s: s['name'])
    tmp = os.path.join(SHOTS, '_annotated')
    os.makedirs(tmp, exist_ok=True)
    c = canvas.Canvas(OUT, pagesize=A4)
    c.setTitle('Hướng dẫn sử dụng app Chạm Xanh')
    c.setAuthor('Chạm Xanh')
    w, h = A4

    # ----- Bìa -----
    c.setFillColor(EMERALD_D)
    c.rect(0, 0, w, h, stroke=0, fill=1)
    if ICON and os.path.exists(ICON):
        c.drawImage(ImageReader(ICON), w / 2 - 22 * mm, h - 95 * mm, 44 * mm, 44 * mm, mask='auto')
    c.setFillColor(white)
    c.setFont('Body-B', 30)
    c.drawCentredString(w / 2, h - 115 * mm, 'Hướng dẫn sử dụng')
    c.setFillColor(WOOD)
    c.setFont('Body-B', 38)
    c.drawCentredString(w / 2, h - 132 * mm, 'App Chạm Xanh')
    c.setFillColor(HexColor('#d3e8d6'))
    c.setFont('Body', 13)
    c.drawCentredString(w / 2, h - 145 * mm, 'Android & iOS · Hồ sơ vườn · Nhắc tưới · Cộng đồng · Tin nhắn · Nâng cấp gói')
    y = h - 175 * mm
    for para in [
        f'Ảnh chụp từ app thật chạy trên {SOURCE}, kết nối máy chủ Chạm Xanh với dữ liệu mẫu.',
        'Mũi tên và số màu đỏ chỉ vào từng nút; phần chú thích bên phải giải thích chức năng.',
        f'Ngày tạo: {datetime.date.today().strftime("%d/%m/%Y")}',
    ]:
        c.setFont('Body', 11)
        for line in simpleSplit(para, 'Body', 11, w - 50 * mm):
            c.drawCentredString(w / 2, y, line)
            y -= 16
        y -= 4
    c.showPage()

    # ----- Mục lục -----
    page = 2
    header(c, 'Mục lục', page)
    c.setFillColor(INK)
    c.setFont('Body-B', 22)
    c.drawString(15 * mm, h - 32 * mm, 'Mục lục')
    y = h - 45 * mm
    sec_idx = 0
    for n, s in enumerate(shots):
        prefix = s['name'][:2]
        if sec_idx < len(SECTIONS) and prefix >= SECTIONS[sec_idx][0]:
            y -= 4
            c.setFont('Body-B', 12)
            c.setFillColor(EMERALD)
            c.drawString(15 * mm, y, SECTIONS[sec_idx][1])
            y -= 16
            sec_idx += 1
        c.setFont('Body', 11)
        c.setFillColor(INK)
        c.drawString(22 * mm, y, f'{n + 1}. {s["title"]}')
        c.setFillColor(MUTED)
        c.drawRightString(w - 15 * mm, y, f'trang {n + 3}')
        y -= 15
    c.showPage()

    # ----- Từng màn hình -----
    for n, s in enumerate(shots):
        page += 1
        header(c, s['title'], page)
        out = os.path.join(tmp, s['name'] + '.jpg')
        iw, ih = annotate(s, out)
        c.setFillColor(INK)
        c.setFont('Body-B', 20)
        c.drawString(15 * mm, h - 30 * mm, f'{n + 1}. {s["title"]}')
        y = wrap(c, s['desc'], 15 * mm, h - 38 * mm, w - 30 * mm, size=11, color=MUTED)

        # ảnh bên trái, chú thích bên phải
        top = y - 6 * mm
        max_h = top - 18 * mm
        img_w = w * 0.60
        img_h = img_w * ih / iw
        if img_h > max_h:
            img_h = max_h
            img_w = img_h * iw / ih
        c.drawImage(ImageReader(out), 10 * mm, top - img_h, img_w, img_h)

        lx = 10 * mm + img_w + 4 * mm
        lw = w - lx - 12 * mm
        ly = top - 4 * mm
        c.setFont('Body-B', 12)
        c.setFillColor(EMERALD)
        c.drawString(lx, ly, 'Chức năng')
        ly -= 9 * mm
        for i, m in enumerate(s['marks']):
            c.setFillColor(HexColor('#dc2626'))
            c.circle(lx + 3.6 * mm, ly + 1.3 * mm, 3.6 * mm, stroke=0, fill=1)
            c.setFillColor(white)
            c.setFont('Body-B', 10)
            c.drawCentredString(lx + 3.6 * mm, ly - 0.3 * mm, str(i + 1))
            ly = wrap(c, m['label'], lx + 9.5 * mm, ly, lw - 9.5 * mm, font='Body-SB', size=10.5, leading=13.5) - 6
        c.showPage()

    # Màn hình hệ thống (nếu CI chụp được thanh thông báo)
    shade = os.path.join(SHOTS, 'shade.png')
    if os.path.exists(shade):
        page += 1
        header(c, 'Thông báo nhắc tưới', page)
        c.setFillColor(INK)
        c.setFont('Body-B', 20)
        c.drawString(15 * mm, h - 30 * mm, 'Thông báo nhắc tưới trên Android')
        y = wrap(c, 'Đến giờ, thông báo hiện trên thanh trạng thái và đổ chuông kiểu báo thức. Bấm "Đã tưới" để tắt, '
                    '"Nhắc lại 10 phút" để được nhắc lại sau 10 phút. Ảnh chụp từ máy ảo khi bấm "Thử chuông".',
                 15 * mm, h - 38 * mm, w - 30 * mm, color=MUTED)
        im = Image.open(shade).convert('RGB')
        # Chỉ giữ phần trên (thanh trạng thái + thông báo nhắc tưới), bỏ thông báo hệ thống của máy ảo.
        im = im.crop((0, 0, im.width, int(im.height * 0.40)))
        shade = os.path.join(SHOTS, '_annotated', 'shade_crop.png')
        im.save(shade)
        sw, sh = im.size
        iw2 = w * 0.62
        ih2 = iw2 * sh / sw
        c.drawImage(ImageReader(shade), (w - iw2) / 2, y - 8 * mm - ih2, iw2, ih2)
        c.showPage()
    c.save()
    print(f'Đã tạo {OUT}: {page} trang, {len(shots)} màn hình')


main()
