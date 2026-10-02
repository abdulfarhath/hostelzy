"""Builds Hostelzy logo assets (concept C, 'H made of beds') into docs/brand/assets."""
import os
import cairosvg
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT = f'{REPO}/docs/brand/assets'
FONT = f'{REPO}/hostelzy/assets/fonts/Archivo-ExtraBold.ttf'

INK, RED, BG = '#201E1D', '#EC3013', '#F3F2F2'
INK_D, RED_D, BG_D = '#F0EEEE', '#FF563C', '#161514'
WHITE = '#FFFFFF'

# Mark on a 100-unit grid: 3x3 cells of 28 with 8 gaps. H = both columns + middle cell.
CELL, GAP = 28, 8
POS = [0, CELL + GAP, 2 * (CELL + GAP)]
COLS = [(0, r) for r in range(3)] + [(2, r) for r in range(3)]
MID = (1, 1)


def mark_rects(x0, y0, size, ink, mid, snap=False):
    """The H. With snap, blocks land on whole pixels (for small PNGs)."""
    out = []
    if snap:
        cell = round(size * CELL / 100)
        gap = max(1, round(size * GAP / 100))
        tot = 3 * cell + 2 * gap
        bx, by = round(x0 + (size - tot) / 2), round(y0 + (size - tot) / 2)
        pos = [0, cell + gap, 2 * (cell + gap)]
        for c, r in COLS + [MID]:
            fill = mid if (c, r) == MID else ink
            out.append(f'<rect x="{bx + pos[c]}" y="{by + pos[r]}" width="{cell}" height="{cell}" fill="{fill}"/>')
        return '\n  '.join(out)
    s = size / 100
    for c, r in COLS + [MID]:
        fill = mid if (c, r) == MID else ink
        out.append(f'<rect x="{x0 + POS[c] * s:.3f}" y="{y0 + POS[r] * s:.3f}" '
                   f'width="{CELL * s:.3f}" height="{CELL * s:.3f}" fill="{fill}"/>')
    return '\n  '.join(out)


def write_px(name, build, native, sizes):
    """build(px, snap) -> svg at px. SVG file at native size; each PNG drawn at its own pixel size."""
    with open(f'{OUT}/{name}.svg', 'w') as f:
        f.write(build(native, False))
    for px, suffix in sizes:
        cairosvg.svg2png(bytestring=build(px, px <= 192).encode(), write_to=f'{OUT}/{name}{suffix}.png',
                         output_width=px, output_height=px)


def svg(w, h, body, bg=None):
    back = f'<rect width="{w}" height="{h}" fill="{bg}"/>\n  ' if bg else ''
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">\n  '
            f'{back}{body}\n</svg>\n')


def write(name, content, png_sizes=()):
    with open(f'{OUT}/{name}.svg', 'w') as f:
        f.write(content)
    for px, suffix in png_sizes:
        cairosvg.svg2png(bytestring=content.encode(), write_to=f'{OUT}/{name}{suffix}.png',
                         output_width=px[0], output_height=px[1])


def wordmark_path(text, x, baseline, size, tracking_em):
    """Outlines `text` in Archivo ExtraBold; returns (svg path d, advance width)."""
    font = TTFont(FONT)
    upm = font['head'].unitsPerEm
    cmap = font.getBestCmap()
    gs = font.getGlyphSet()
    hmtx = font['hmtx']
    kern = {}
    scale = size / upm
    pen = SVGPathPen(gs)
    cx = 0.0
    for ch in text:
        g = cmap[ord(ch)]
        tp = TransformPen(pen, (scale, 0, 0, -scale, x + cx * scale, baseline))
        gs[g].draw(tp)
        cx += hmtx[g][0] + tracking_em * upm
    cx -= tracking_em * upm
    return pen.getCommands(), cx * scale


def h_height(size):
    font = TTFont(FONT)
    upm = font['head'].unitsPerEm
    gs = font.getGlyphSet()
    from fontTools.pens.boundsPen import BoundsPen
    bp = BoundsPen(gs)
    gs[font.getBestCmap()[ord('h')]].draw(bp)
    return bp.bounds[3] / upm * size


os.makedirs(OUT, exist_ok=True)

# 1. Mark alone (square, transparent), light / dark / mono.
for name, ink, mid in [('mark', INK, RED), ('mark-dark', INK_D, RED_D), ('mark-mono', '#000000', '#000000')]:
    write(name, svg(100, 100, mark_rects(0, 0, 100, ink, mid)), [((512, 512), '-512')])

# 2. Play Store icon 512x512: full-bleed red square (Play rounds it), white H, ink bed.
play = svg(512, 512, mark_rects(96, 96, 320, WHITE, INK), bg=RED)
write('play-store-icon-512', play, [((512, 512), '')])

# 3. Android adaptive icon (108dp canvas; 432px = xxxhdpi). Mark 46dp fits the 66dp safe circle.
side = 432 * 46 / 108
off = (432 - side) / 2
write('ic_launcher_foreground', svg(432, 432, mark_rects(off, off, side, WHITE, INK)), [((432, 432), '')])
write('ic_launcher_background', svg(432, 432, '', bg=RED), [((432, 432), '')])
write('ic_launcher_monochrome', svg(432, 432, mark_rects(off, off, side, WHITE, WHITE)), [((432, 432), '')])

# 4. Legacy launcher icons (square red tile), per density.
dens = [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]
write_px('ic_launcher', lambda p, sn: svg(p, p, mark_rects(p * 0.18, p * 0.18, p * 0.64, WHITE, INK, sn), bg=RED),
         192, [(p, f'-{d}') for d, p in dens])

# 5. Notification (status bar) icon: white silhouette, transparent, 24dp with 2dp padding.
write_px('ic_stat_hostelzy', lambda p, sn: svg(p, p, mark_rects(p / 12, p / 12, p * 20 / 24, WHITE, WHITE, sn)),
         24, [(p, f'-{d}') for d, p in [('mdpi', 24), ('hdpi', 36), ('xhdpi', 48), ('xxhdpi', 72), ('xxxhdpi', 96)]])

# 6. Wordmark lockup: mark height = height of 'h'; text = app's own wordmark (lowercase, -0.02em).
SIZE = 120
hh = h_height(SIZE)
pad = 24
gap = hh * 0.32
base = pad + hh
d_probe, adv = wordmark_path('hostelzy', 0, 0, SIZE, -0.02)
w = round(pad + hh + gap + adv + pad)
desc = SIZE * 0.24
h = round(base + desc + pad / 2)
for name, ink, mid, bg in [('lockup', INK, RED, None), ('lockup-dark', INK_D, RED_D, None),
                           ('lockup-on-light', INK, RED, BG), ('lockup-on-dark', INK_D, RED_D, BG_D)]:
    d, _ = wordmark_path('hostelzy', pad + hh + gap, base, SIZE, -0.02)
    body = mark_rects(pad, pad, hh, ink, mid) + f'\n  <path d="{d}" fill="{ink}"/>'
    write(name, svg(w, h, body, bg=bg), [((w * 2, h * 2), '@2x')])

print('lockup', w, h, 'h-height', round(hh, 1))
print(len(os.listdir(OUT)), 'files')
