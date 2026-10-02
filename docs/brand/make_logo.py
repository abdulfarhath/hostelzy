"""Builds the Hostelzy logo assets: B3-a2 "Room with AC" (final, founder 2026-10-02).

Run: python3 docs/brand/make_logo.py   (needs: pip install fonttools cairosvg)
Writes docs/brand/assets/. The mark is drawn on a 100-unit grid. Every piece is solid, so the
floor stays transparent in every file.
"""
import os
import shutil
import cairosvg
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.boundsPen import BoundsPen

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..'))
OUT = os.path.join(HERE, 'assets')
FONT = os.path.join(REPO, 'hostelzy', 'assets', 'fonts', 'Archivo-ExtraBold.ttf')

THEMES = {
    'light': {'w': '#201E1D', 'b': '#605D5D', 'r': '#EC3013'},
    'dark': {'w': '#F0EEEE', 'b': '#9A9696', 'r': '#FF563C'},
    'mono': {'w': '#FFFFFF', 'b': '#FFFFFF', 'r': '#FFFFFF'},
}
WHITE, RED, INK, BG_L, BG_D = '#FFFFFF', '#EC3013', '#201E1D', '#F3F2F2', '#161514'


def shapes(small):
    """B3-a2 as solid pieces only (no cut-outs), so the floor is always transparent."""
    S = []
    R = lambda x, y, w, h, role: S.append(('rect', role, (x, y, w, h)))
    # Walls, with a window opening on top (20-42) and a door gap at the bottom (52-68).
    R(4, 4, 16, 9, 'w'); R(42, 4, 54, 9, 'w')
    R(4, 4, 9, 92, 'w'); R(87, 4, 9, 92, 'w')
    R(4, 87, 48, 9, 'w'); R(68, 87, 28, 9, 'w')
    if small:
        R(20, 4, 22, 3, 'w'); R(20, 10, 22, 3, 'w')
    else:
        R(20, 6, 22, 2.2, 'w'); R(20, 9.8, 22, 2.2, 'w')               # window: double line
    if small:
        R(50, 13, 24, 5, 'w')                                          # AC as a bar
    else:                                                              # AC unit + dotted air
        R(50, 14.5, 24, 1.6, 'w'); R(50, 19.9, 24, 1.6, 'w')
        R(50, 14.5, 1.6, 7, 'w'); R(72.4, 14.5, 1.6, 7, 'w'); R(53, 17.6, 18, 1.2, 'w')
        for x in (55, 62, 69):
            S.append(('dots', 'w', (x, 24, 32, 1.6)))
    if small:
        R(17, 17, 16, 32, 'b')
    else:                                                              # bunk: two layers
        R(17, 17, 16, 2.6, 'b'); R(17, 46.4, 16, 2.6, 'b'); R(17, 17, 2.6, 32, 'b'); R(30.4, 17, 2.6, 32, 'b')
        R(22.2, 22.2, 5.6, 21.6, 'b')
    if small:
        R(17, 66, 28, 14, 'b'); R(67, 34, 16, 32, 'r')
    else:                                                              # grey bed + YOUR bed, pillow gaps
        R(17, 66, 6, 14, 'b'); R(25.6, 66, 19.4, 14, 'b')
        R(67, 34, 16, 6, 'r'); R(67, 42.6, 16, 23.4, 'r')
    if small:
        S.append(('circle', 'w', (48, 47, 4.5)))                      # fan as a dot
    else:
        for k in range(3):                                             # fan: 3 blades + hub
            S.append(('blade', 'w', (48, 46, 8, k * 120)))
        S.append(('circle', 'w', (48, 46, 2.48)))
    return S


def el(kind, geo, fill, s):
    if kind == 'rect':
        x, y, w, h = geo
        return f'<rect x="{x * s:.3f}" y="{y * s:.3f}" width="{w * s:.3f}" height="{h * s:.3f}" fill="{fill}"/>'
    if kind == 'circle':
        cx, cy, r = geo
        return f'<circle cx="{cx * s:.3f}" cy="{cy * s:.3f}" r="{r * s:.3f}" fill="{fill}"/>'
    if kind == 'blade':
        cx, cy, ln, rot = geo
        bw = ln * 0.42
        return (f'<rect x="{(cx - bw / 2) * s:.3f}" y="{(cy - ln) * s:.3f}" width="{bw * s:.3f}" height="{ln * s:.3f}" '
                f'fill="{fill}" transform="rotate({rot} {cx * s:.3f} {cy * s:.3f})"/>')
    if kind == 'dots':
        x, y0, y1, d = geo
        out, y = [], y0
        while y + d <= y1 + 0.01:
            out.append(f'<rect x="{(x - d / 2) * s:.3f}" y="{y * s:.3f}" width="{d * s:.3f}" height="{d * s:.3f}" fill="{fill}"/>')
            y += 2 * d
        return ''.join(out)


def mark(x0, y0, size, theme, small, mid=None):
    """Mark group at (x0, y0), `size` px square, transparent floor."""
    s = size / 100
    pal = THEMES[theme]
    body = ''.join(el(kind, geo, pal[role], s) for kind, role, geo in shapes(small))
    return f'<g transform="translate({x0:.3f} {y0:.3f})">{body}</g>'


def svg(w, h, body, bg=None):
    back = f'<rect width="{w}" height="{h}" fill="{bg}"/>' if bg else ''
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{back}{body}</svg>\n'


def save(name, build, sizes):
    """build(px) -> svg. Writes name.svg at the first size and a PNG per (px, suffix)."""
    with open(f'{OUT}/{name}.svg', 'w') as f:
        f.write(build(sizes[0][0]))
    for px, suffix in sizes:
        cairosvg.svg2png(bytestring=build(px).encode(), write_to=f'{OUT}/{name}{suffix}.png',
                         output_width=px, output_height=px)


def wordmark(x, baseline, size, tracking=-0.02):
    font = TTFont(FONT)
    upm, cmap, gs, hmtx = font['head'].unitsPerEm, font.getBestCmap(), font.getGlyphSet(), font['hmtx']
    sc, pen, cx = size / upm, SVGPathPen(gs), 0.0
    for ch in 'hostelzy':
        g = cmap[ord(ch)]
        gs[g].draw(TransformPen(pen, (sc, 0, 0, -sc, x + cx * sc, baseline)))
        cx += hmtx[g][0] + tracking * upm
    bp = BoundsPen(gs)
    gs[cmap[ord('h')]].draw(bp)
    return pen.getCommands(), (cx - tracking * upm) * sc, bp.bounds[3] * sc


if os.path.isdir(OUT):
    shutil.rmtree(OUT)
os.makedirs(OUT)
SMALL = 64  # at or below this many px the simple mark is used

# Mark alone: light / dark / one colour (transparent background).
for theme in ('light', 'dark', 'mono'):
    save(f'mark-{theme}', lambda p, t=theme: svg(p, p, mark(0, 0, p, t, p <= SMALL, 'm')),
         [(512, ''), (512, '-512')])
    os.remove(f'{OUT}/mark-{theme}.png')

# Play Store icon: 512x512, full-bleed white square (Play rounds the corners), mark at 76%.
save('play-store-icon-512', lambda p: svg(p, p, mark(p * .12, p * .12, p * .76, 'light', False, 'm'), bg=WHITE),
     [(512, '')])

# Android adaptive icon, 108dp canvas = 432 px at xxxhdpi. Mark 48dp: even its corners stay
# inside the round launcher mask (72dp visible circle), so round icons never cut the room.
side = 432 * 48 / 108
off = (432 - side) / 2
save('ic_launcher_foreground', lambda p: svg(p, p, mark(off * p / 432, off * p / 432, side * p / 432, 'light', False, 'm')),
     [(432, '')])
save('ic_launcher_background', lambda p: svg(p, p, '', bg=WHITE), [(432, '')])
save('ic_launcher_monochrome', lambda p: svg(p, p, mark(off * p / 432, off * p / 432, side * p / 432, 'mono', True, 'm')),
     [(432, '')])

# Same adaptive layers per density (108dp each), ready for mipmap-*/.
for d, p in [('mdpi', 108), ('hdpi', 162), ('xhdpi', 216), ('xxhdpi', 324), ('xxxhdpi', 432)]:
    for layer, theme, small in [('foreground', 'light', False), ('monochrome', 'mono', True)]:
        body = svg(p, p, mark(off * p / 432, off * p / 432, side * p / 432, theme, small))
        cairosvg.svg2png(bytestring=body.encode(), write_to=f'{OUT}/ic_launcher_{layer}-{d}.png',
                         output_width=p, output_height=p)

# Web build (hostelzy/web): favicon, PWA icons, maskable icons (mark inside the 80% safe circle).
web = lambda p, k: svg(p, p, mark(p * (1 - k) / 2, p * (1 - k) / 2, p * k, 'light', p * k <= SMALL), bg=WHITE)
for name, p, k in [('web-favicon', 32, .9), ('web-Icon-192', 192, .8), ('web-Icon-512', 512, .8),
                   ('web-Icon-maskable-192', 192, .56), ('web-Icon-maskable-512', 512, .56)]:
    cairosvg.svg2png(bytestring=web(p, k).encode(), write_to=f'{OUT}/{name}.png', output_width=p, output_height=p)

# Splash. Android 12+ splash icon: 1152 px canvas (= 288dp at 4x), transparent; the system crops
# it to a circle of 2/3 the width, so the room (corners included) stays inside that circle.
for theme in ('light', 'dark'):
    sp = 1152
    m = round(sp * (2 / 3) / 1.414 * 0.96)
    body = svg(sp, sp, mark((sp - m) / 2, (sp - m) / 2, m, theme, False))
    cairosvg.svg2png(bytestring=body.encode(), write_to=f'{OUT}/splash-icon-{theme}.png', output_width=sp, output_height=sp)

# Legacy square launcher icons (Android 7 and older).
dens = [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]
save('ic_launcher', lambda p: svg(p, p, mark(p * .1, p * .1, p * .8, 'light', p * .8 <= SMALL, 'm'), bg=WHITE),
     [(192, '')] + [(p, f'-{d}') for d, p in dens])
os.remove(f'{OUT}/ic_launcher.png')

# Notification icon: one colour, transparent, 24dp with 1dp padding, simple mark.
note = [('mdpi', 24), ('hdpi', 36), ('xhdpi', 48), ('xxhdpi', 72), ('xxxhdpi', 96)]
save('ic_stat_hostelzy', lambda p: svg(p, p, mark(p / 24, p / 24, p * 22 / 24, 'mono', True, 'm')),
     [(24, '')] + [(p, f'-{d}') for d, p in note])
os.remove(f'{OUT}/ic_stat_hostelzy.png')

# Lockup: mark + "hostelzy" (Archivo ExtraBold, lowercase, -0.02em, like the app header).
SIZE, PAD = 120, 24
_, adv, hh = wordmark(0, 0, SIZE)
msz = round(hh * 1.18)
gap = round(hh * 0.30)
base = PAD + msz
W = round(PAD + msz + gap + adv + PAD)
H = round(base + SIZE * 0.24 + PAD / 2)
for name, theme, ink, bg in [('lockup-light', 'light', INK, None), ('lockup-dark', 'dark', '#F0EEEE', None),
                             ('lockup-on-light', 'light', INK, BG_L), ('lockup-on-dark', 'dark', '#F0EEEE', BG_D)]:
    d, _, _ = wordmark(PAD + msz + gap, base, SIZE)
    body = mark(PAD, PAD, msz, theme, False, 'm') + f'<path d="{d}" fill="{ink}"/>'
    content = svg(W, H, body, bg=bg)
    with open(f'{OUT}/{name}.svg', 'w') as f:
        f.write(content)
    cairosvg.svg2png(bytestring=content.encode(), write_to=f'{OUT}/{name}@2x.png', output_width=W * 2, output_height=H * 2)

print(len(os.listdir(OUT)), 'files in', OUT)
