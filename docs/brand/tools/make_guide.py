"""Builds docs/brand/guide/brand-guide.html (the one-page brand guide artifact). Brand chat, 2026-10-03."""
import os, re
HERE = os.path.dirname(os.path.abspath(__file__))
BRAND = os.path.abspath(os.path.join(HERE, '..'))
A = os.path.join(BRAND, 'assets')
logo = {'__file__': os.path.join(BRAND, 'make_logo.py')}
exec(compile(open(os.path.join(BRAND, 'make_logo.py')).read().split('# Rebuild only the top-level')[0], 'make_logo.py', 'exec'), logo)

def themed(svg):
    """Fixed logo colours -> theme tokens, so the logo follows the page's light/dark."""
    for c, v in (('#201E1D', '--m-wall'), ('#605D5D', '--m-bed'), ('#EC3013', '--m-you')):
        svg = svg.replace(f'fill="{c}"', f'style="fill:var({v})"')
    return re.sub(r' width="\d+" height="\d+"', '', svg, count=1)

def fixed(svg):
    return re.sub(r' width="\d+" height="\d+"', '', svg, count=1)

lock = themed(open(f'{A}/lockup-light.svg').read())
mk = lambda theme, small, bg=None: fixed(logo['svg'](100, 100, logo['mark'](0, 0, 100, theme, small), bg=bg))
mark_full = themed(mk('light', False))
mark_small = themed(mk('light', True))
on_light = fixed(open(f'{A}/lockup-on-light.svg').read())
on_dark = fixed(open(f'{A}/lockup-on-dark.svg').read())
stat = fixed(open(f'{A}/notification/ic_stat_hostelzy.svg').read()).replace('#FFFFFF', '#F0EEEE')
icon = fixed(open(f'{A}/play-store-icon-512.svg').read())

def dont(transform='', extra='', label=''):
    return f'<figure class="dont"><div class="tile"><div style="{transform}">{extra}</div></div><figcaption>{label}</figcaption></figure>'

red_tile = mk('mono', False, bg='#EC3013')
recolor = mk('light', False).replace('#605D5D', '#1f7a3d').replace('#EC3013', '#2f5bd3')
all_red = mk('light', False).replace('#605D5D', '#EC3013')
donts = ''.join([
    dont('transform:rotate(12deg)', mk('light', False), 'Don’t rotate or tilt the room.'),
    dont('', red_tile, 'Don’t put it on a red tile. Only your bed is red.'),
    dont('', recolor, 'Don’t recolour the beds.'),
    dont('', all_red, 'Don’t make more than one bed red.'),
    dont('border-radius:28%;overflow:hidden;box-shadow:0 8px 18px rgba(0,0,0,.35)', mk('light', False, bg='#FFFFFF'), 'No rounded corners, shadows or glows.'),
    dont('', mk('light', True).replace('<svg', '<svg style="width:100%"'), 'Don’t use the simple room above 64 px.'),
])

html = open(os.path.join(HERE, 'guide_template.html')).read()
for k, v in dict(LOCK=lock, MARK_FULL=mark_full, MARK_SMALL=mark_small, ON_LIGHT=on_light, ON_DARK=on_dark,
                 STAT=stat, ICON=icon, DONTS=donts).items():
    html = html.replace('{{' + k + '}}', v)
open(os.path.join(BRAND, 'guide', 'brand-guide.html'), 'w').write(html)
print('ok', len(html))
