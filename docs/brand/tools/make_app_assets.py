"""Builds the notification icon and the splash files for the app (Brand chat, 2026-10-03).

Run from the repo root: python3 docs/brand/tools/make_app_assets.py   (needs: pip install cairosvg)
Writes into docs/brand/assets/notification/ and docs/brand/assets/splash/.
Spec and where each file goes: docs/brand/app-assets.md.
"""
import os
import cairosvg

HERE = os.path.dirname(os.path.abspath(__file__))
BRAND = os.path.abspath(os.path.join(HERE, '..'))
ASSETS = os.path.join(BRAND, 'assets')
DENS = [('mdpi', 1), ('hdpi', 1.5), ('xhdpi', 2), ('xxhdpi', 3), ('xxxhdpi', 4)]

# --- Notification icon: ic_stat_hostelzy -------------------------------------------------
# Drawn on Android's 24dp grid, 2dp padding (live area 2..22). One colour (white), transparent.
# The room's one-colour form: walls with a door gap, other beds as outlines, YOUR bed filled
# (in one colour, "filled" plays the part red plays in the full logo).
STAT = [
    # walls, 2dp thick; door gap at the bottom (12..16)
    (2, 2, 20, 2), (2, 2, 2, 20), (20, 2, 2, 20), (2, 20, 10, 2), (16, 20, 6, 2),
    # bunk (outline, 1dp)
    (6, 6, 5, 1), (6, 13, 5, 1), (6, 6, 1, 8), (10, 6, 1, 8),
    # other bed (outline, 1dp)
    (6, 16, 7, 1), (6, 18, 7, 1), (6, 16, 1, 3), (12, 16, 1, 3),
    # your bed: filled
    (14, 7, 4, 9),
]


def stat_svg(px):
    s = px / 24
    body = ''.join(f'<rect x="{x * s}" y="{y * s}" width="{w * s}" height="{h * s}" fill="#FFFFFF"/>' for x, y, w, h in STAT)
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{px}" height="{px}" viewBox="0 0 {px} {px}">{body}</svg>\n'


def vector_drawable():
    paths = ' '.join(f'M{x},{y}h{w}v{h}h-{w}z' for x, y, w, h in STAT)
    return ('<?xml version="1.0" encoding="utf-8"?>\n'
            '<!-- Hostelzy notification icon (Brand, 2026-10-03). Status bar: one colour, Android tints it. -->\n'
            '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
            '    android:width="24dp" android:height="24dp"\n'
            '    android:viewportWidth="24" android:viewportHeight="24">\n'
            f'  <path android:fillColor="#FFFFFFFF" android:pathData="{paths}"/>\n'
            '</vector>\n')


out = os.path.join(ASSETS, 'notification')
os.makedirs(out, exist_ok=True)
with open(os.path.join(out, 'ic_stat_hostelzy.svg'), 'w') as f:
    f.write(stat_svg(24))
with open(os.path.join(out, 'ic_stat_hostelzy.xml'), 'w') as f:
    f.write(vector_drawable())
for d, k in DENS:
    px = round(24 * k)
    cairosvg.svg2png(bytestring=stat_svg(px).encode(), write_to=os.path.join(out, f'ic_stat_hostelzy-{d}.png'),
                     output_width=px, output_height=px)
# Large preview on a dark bar (for review only)
cairosvg.svg2png(bytestring=f'<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24"><rect width="24" height="24" fill="#24221F"/>{stat_svg(24)[stat_svg(24).index(">") + 1:-7]}</svg>'.encode(),
                 write_to=os.path.join(out, 'preview-on-dark.png'), output_width=192, output_height=192)

# --- Splash: Android 12+ icon (and the same picture for older Android) --------------------
# 288dp canvas, transparent, room inside the 192dp circle Android keeps (room = 128dp).
src = open(os.path.join(BRAND, 'make_logo.py')).read()
logo_src = src.split('if os.path.isdir(OUT):')[0]     # only the drawing functions, don't rebuild assets/
logo = {'__file__': os.path.join(BRAND, 'make_logo.py')}
exec(compile(logo_src, 'make_logo.py', 'exec'), logo)

sp_out = os.path.join(ASSETS, 'splash')
os.makedirs(sp_out, exist_ok=True)
for theme in ('light', 'dark'):
    for d, k in DENS:
        px = round(288 * k)
        m = 128 * k
        body = logo['svg'](px, px, logo['mark']((px - m) / 2, (px - m) / 2, m, theme, False))
        cairosvg.svg2png(bytestring=body.encode(), write_to=os.path.join(sp_out, f'splash_icon-{theme}-{d}.png'),
                         output_width=px, output_height=px)
# Previews: what the phone shows (for review only)
for theme, bg in (('light', '#F3F2F2'), ('dark', '#161514')):
    px, m = 390, 128 * 1.5
    body = logo['svg'](px, 844, logo['mark']((px - m) / 2, (844 - m) / 2, m, theme, False), bg=bg)
    cairosvg.svg2png(bytestring=body.encode(), write_to=os.path.join(sp_out, f'preview-{theme}.png'))
print('ok')
