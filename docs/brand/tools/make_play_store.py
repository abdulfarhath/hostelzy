"""Play Store listing images (Brand chat, 2026-10-03).

Run from the repo root: python3 docs/brand/tools/make_play_store.py   (needs: pip install pillow cairosvg fonttools)
Inputs: real app screens in docs/brand/assets/play-store/raw/ (made by capture_screens_test.dart).
Writes: feature-graphic-1024x500.png and screenshot-1..8 (1080x1920) in docs/brand/assets/play-store/.
Copy and captions: docs/brand/play-store.md.
"""
import io
import os
import cairosvg
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
BRAND = os.path.abspath(os.path.join(HERE, '..'))
REPO = os.path.abspath(os.path.join(BRAND, '..', '..'))
OUT = os.path.join(BRAND, 'assets', 'play-store')
RAW = os.path.join(OUT, 'raw')
FONTS = os.path.join(REPO, 'hostelzy', 'assets', 'fonts')
BG, INK, MU, RED = '#F3F2F2', '#201E1D', '#605D5D', '#EC3013'

logo = {'__file__': os.path.join(BRAND, 'make_logo.py')}
exec(compile(open(os.path.join(BRAND, 'make_logo.py')).read().split('# Rebuild only the top-level')[0], 'make_logo.py', 'exec'), logo)


def font(weight, size):
    return ImageFont.truetype(os.path.join(FONTS, f'Archivo-{weight}.ttf'), size)


def svg_img(svg, w, h):
    return Image.open(io.BytesIO(cairosvg.svg2png(bytestring=svg.encode(), output_width=w, output_height=h))).convert('RGBA')


def text(d, xy, s, f, fill, ls=-0.02):
    """Draw text with letter-spacing (em), like the app's tight headlines."""
    x, y = xy
    for ch in s:
        d.text((x, y), ch, font=f, fill=fill)
        x += f.getlength(ch) + ls * f.size
    return x


# The 8 screenshots: (raw screen, line 1, line 2). Plain words, only things the app does today.
SHOTS = [
    ('explore', 'Find a PG bed', 'near your office or college'),
    ('picker', 'See every room.', 'Pick your own bed.'),
    ('compare', 'Fan, AC, window?', 'Compare two beds first.'),
    ('detail', 'Clear rent, before', 'you go: AC and non-AC'),
    ('reviews', 'Reviews from people', 'who really stayed'),
    ('rHome', 'Living there? Rent,', 'food and complaints'),
    ('reminders', 'Reminders for water,', 'meals and rent'),
    ('oToday', 'Owners: holds, rent and', 'enquiries in one place'),
]

W, H = 1080, 1920
for i, (raw, l1, l2) in enumerate(SHOTS, 1):
    im = Image.new('RGB', (W, H), BG)
    d = ImageDraw.Draw(im)
    # Caption: red square = "your bed" (the logo's red block), then two lines of ExtraBold ink.
    d.rectangle([80, 120, 80 + 28, 120 + 56], fill=RED)
    f = font('ExtraBold', 76)
    text(d, (136, 96), l1, f, INK)
    text(d, (136, 186), l2, f, MU)
    # Real app screen, 2px-style ink rule (6px at this scale), square corners, bleeds off the bottom.
    sw = 840
    scr = Image.open(os.path.join(RAW, f'{raw}.png')).convert('RGB')
    scr = scr.resize((sw, round(scr.height * sw / scr.width)), Image.LANCZOS)
    x0, y0 = (W - sw) // 2, 360
    d.rectangle([x0 - 6, y0 - 6, x0 + sw + 5, H + 10], fill=INK)
    im.paste(scr, (x0, y0))
    im.save(os.path.join(OUT, f'screenshot-{i}-{raw}.png'), optimize=True)

# Feature graphic 1024x500: lockup + promise on the left, the full room big on the right.
fg = Image.new('RGB', (1024, 500), BG)
d = ImageDraw.Draw(fg)
lock = open(os.path.join(BRAND, 'assets', 'lockup-light.svg')).read()
import re
lw, lh = map(float, re.search(r'width="([\d.]+)" height="([\d.]+)"', lock).groups())
lk = svg_img(lock, 430, round(430 * lh / lw))
fg.paste(lk, (52, 92), lk)
text(d, (72, 250), 'See the room.', font('ExtraBold', 58), INK)
text(d, (72, 318), 'Pick your bed.', font('ExtraBold', 58), RED)
text(d, (74, 410), 'PGs and hostels in Hyderabad', font('Medium', 26), MU, ls=0)
room = svg_img(logo['svg'](420, 420, logo['mark'](0, 0, 420, 'light', False)), 420, 420)
fg.paste(room, (560, 40), room)
fg.save(os.path.join(OUT, 'feature-graphic-1024x500.png'), optimize=True)
print('ok')
