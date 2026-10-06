import re, json, os
SP = '/tmp/claude-0/-home-user-hostelzy/58cdc0a8-c7d4-5e26-828b-40f705b32de2/scratchpad/'
src = open(SP + 'w4.py').read()
exec(src[:src.index("wr('w4-building")])
Q = SP + 'f26/project/'
os.makedirs(Q, exist_ok=True)

I['phone'] = '<path d="M5 3h4l2 5-2.5 1.5a11 11 0 0 0 6 6L16 13l5 2v4a2 2 0 0 1-2 2A17 17 0 0 1 3 5a2 2 0 0 1 2-2"/>'
I['search'] = '<circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/>'
I['home'] = '<path d="M15 21v-8H9v8"/><path d="M3 10 12 3l9 7v11H3z"/>'
I['user'] = '<path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/>'
I['bed'] = '<path d="M3 7v13M3 14h18v6M21 14v-3a3 3 0 0 0-3-3h-7v6"/><circle cx="7" cy="11" r="2"/>'
I['heart'] = '<path d="M12 21s-8-5.2-8-11a4.5 4.5 0 0 1 8-2.8A4.5 4.5 0 0 1 20 10c0 5.8-8 11-8 11z"/>'
I['wrench'] = '<path d="M14 7a4 4 0 0 0 5 5l-9 9-3-3 9-9a4 4 0 0 0-2-2z"/>'
I['grid'] = '<path d="M3 3h18v18H3zM3 12h18M12 3v18"/>'
I['plusU'] = '<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M19 8v6M22 11h-6"/>'
I['shield'] = '<path d="M12 3 4 6v6c0 5 3.5 8 8 9 4.5-1 8-4 8-9V6z"/><path d="m9 12 2 2 4-4"/>'
I['chevD'] = '<path d="m6 9 6 6 6-6"/>'
I['sort'] = '<path d="M7 4v16M3 8l4-4 4 4M17 20V4M13 16l4 4 4-4"/>'

VF = '[data-hz]{--vf:#1f3a5f;--or:#e8740c;--oi:#201e1d}[data-hz][data-theme="dark"]{--vf:#33598a;--or:#ff9a3d;--oi:#161514}'
OUT2 = []
def save(name, s):
    open(Q + name, 'w').write(s); OUT2.append(name)

def phone_div(s):
    i = s.index('<div data-hz'); j = s.rindex('</div>\n</x-dc>') + 6
    return s[i:j]
def ph(body, nav=None, h=844):
    d = phone_div(phone('x', body, nav))
    return d.replace('height: 844px;', 'height: %dpx;' % h, 1) if h != 844 else d
def src_phone(f):
    d = phone_div(rd(f))
    if '<sc-if value="{{v0}}"' in d:
        a = d.index('<sc-if value="{{v0}}"'); a2 = d.index('>', a) + 1; b = d.index('</sc-if>', a2)
        c = d.index('<sc-if value="{{v1}}"'); e = d.index('</sc-if>', c) + 8
        d = d[:a] + d[a2:b] + d[b + 8:c] + d[e:]
    if 'Rooms and rates' in d: d = d.replace('<button style="padding: 10px; border: 2px solid var(--tx); display: grid; gap: 8px; text-align: left;">', '<div style="padding: 10px; border: 2px solid var(--tx); display: grid; gap: 8px; text-align: left;">').replace('</div></button>', '</div></div>')
    return d

# ---- wrapper board: columns of phones, each with a label
TAGS = {'before': ('Before · in the app now', 'border: 2px solid #605d5d; color: #605d5d;'),
        'after': ('After · F26 proposal', 'background: #201e1d; color: #f3f2f2; border: 2px solid #201e1d;'),
        'state': (None, 'background: #201e1d; color: #f3f2f2; border: 2px solid #201e1d;')}
def col(kind, caption, phone_html, label=None, h=844):
    t, st = TAGS[kind]
    t = label or t
    return ('<div style="width: 390px; display: grid; gap: 12px; align-content: start;">'
            '<div style="height: 64px; display: grid; gap: 6px; align-content: end; justify-items: start;">'
            '<span style="padding: 4px 8px; font-size: 12px; font-weight: 800; letter-spacing: .08em; text-transform: uppercase; %s">%s</span>'
            '<span style="font-size: 14px; line-height: 1.35; color: #201e1d;">%s</span></div>'
            '<div style="outline: 2px solid #201e1d; width: 390px; height: %dpx;">%s</div></div>') % (st, t, caption, h, phone_html)
def board(name, tt, cols, dark=False, h=844):
    n = len(cols)
    W = n * 390 + (n - 1) * 48 + 64
    H = 32 + 64 + 12 + h + 32
    s = rd('holds.dc.html')
    s = title(s, tt)
    s = s.replace('[data-hz] *{box-sizing:border-box}', VF + '[data-hz] *{box-sizing:border-box}', 1)
    i = s.index('<div data-hz'); j = s.rindex('</div>\n</x-dc>') + 6
    root = ('<div style="width: %dpx; height: %dpx; box-sizing: border-box; padding: 32px; display: flex; gap: 48px; background: #ffffff; color: #201e1d; font-family: Archivo, system-ui, sans-serif;">' % (W, H)) + ''.join(cols) + '</div>'
    s = s[:i] + root + s[j:]
    s = s.replace('"$preview": {"width": 390, "height": 844}', '"$preview": {"width": %d, "height": %d}' % (W, H))
    if dark:
        s = s.replace('{"dark": {"editor": "boolean", "default": false}', '{"dark": {"editor": "boolean", "default": true}').replace('(this.props.dark ?? false)', '(this.props.dark ?? true)')
    assert '"$preview": {"width": %d' % W in s
    save(name, s)
    return (W, H)

def navsel(nav, label):
    """select tab by label in a nav"""
    nav = plain_nav(nav)
    k = nav.index('</svg>' + label + '</button>')
    b = nav.rindex('<button style="', 0, k)
    e = nav.index('">', b)
    seg = nav[b:e]
    if 'background: var(--ac)' in seg:
        return nav
    nav = nav[:b] + seg.replace('color: var(--mu);', 'color: var(--tx); box-shadow: inset 0 3px 0 var(--ac);') + nav[e:]
    return nav
def navdot(nav, label):
    k = nav.index('</svg>' + label + '</button>')
    b = nav.rindex('<svg', 0, k)
    dot = '<span style="position: relative; display: block; width: 20px; height: 20px;">'
    return nav[:b] + dot + nav[b:k + 6] + '<span aria-label="New" style="position: absolute; right: -4px; top: -3px; width: 9px; height: 9px; background: var(--ac); border: 2px solid var(--bg);"></span></span>' + nav[k + 6:]

NAV_T = NAVS['tenant']
NAV_O = NAVS['owner']
def tabbtn(ic, label, on=False, fill=False):
    if fill:
        st = 'color: var(--ai); background: var(--ac);'
    elif on:
        st = 'color: var(--tx); box-shadow: inset 0 3px 0 var(--ac);'
    else:
        st = 'color: var(--mu);'
    return ('<button style="display: flex; flex-direction: column; justify-content: center; align-items: flex-start; gap: 5px; padding: 0 6px; font-size: 11px; white-space: nowrap; font-weight: 600; %s">%s%s</button>') % (st, '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="square" style="flex: none;">' + I[ic] + '</svg>', label)
def nav_res(on='Home'):
    tabs = [('home', 'Home'), ('money', 'Rent'), ('bed', 'My stay'), ('search', 'Find a bed'), ('user', 'Me')]
    return ('<nav style="flex: none; display: grid; grid-template-columns: repeat(5, minmax(0, 1fr)); height: 64px; border-top: 2px solid var(--tx); background: var(--bg);">'
            + ''.join(tabbtn(ic, l, l == on, l == 'Rent' and on != 'Rent' and False) for ic, l in tabs) + '</nav>')

def hdr(k, t, right=''):
    return ('<div style="flex: none; padding: 12px 16px 12px; display: flex; justify-content: space-between; gap: 12px;"><div style="display: grid; gap: 4px;">' + kick(k)
            + '<b style="display: block; font-size: 32px; line-height: 1.02; letter-spacing: -.025em;">' + t + '</b></div>' + right + '</div>')
def avatar(t, red=True):
    return '<b style="width: 44px; height: 44px; flex: none; display: grid; place-items: center; %s">%s</b>' % ('background: var(--ac); color: var(--ai);' if red else 'background: var(--sf); color: var(--tx);', t)
def chip(t, on=False, h=38):
    st = 'background: var(--tx); color: var(--bg); border: 2px solid var(--tx);' if on else 'border: 1px solid var(--dv); color: var(--tx);'
    return '<button style="flex: none; height: %dpx; padding: 0 12px; font-size: 13px; font-weight: %s; white-space: nowrap; display: flex; gap: 6px; align-items: center; %s">%s</button>' % (h, '800' if on else '600', st, t)
def seg(items, active):
    return ('<div style="display: grid; grid-template-columns: repeat(%d, minmax(0, 1fr)); border: 2px solid var(--tx);">' % len(items)
            + ''.join('<button style="padding: 10px 4px; font-size: 13px; font-weight: 600; text-align: center; %s">%s</button>' % ('background: var(--tx); color: var(--bg);' if n == active else 'background: transparent; color: var(--tx);', n) for n in items) + '</div>')
def obtn(text, icon, kind='out', h=44, disabled=False):
    st = {'out': 'border: 2px solid var(--tx); color: var(--tx);', 'ink': 'background: var(--tx); color: var(--bg); border: 2px solid var(--tx);', 'red': 'background: var(--ac); color: var(--ai); border: 2px solid var(--ac);', 'or': 'background: var(--or); color: var(--oi); border: 2px solid var(--or);'}[kind]
    if disabled:
        st = 'border: 2px solid var(--hl); color: var(--mu); background: var(--sf);'
    return '<button%s style="height: %dpx; padding: 0 14px; display: flex; justify-content: center; align-items: center; gap: 8px; font-size: 14px; font-weight: 800; %s">%s%s</button>' % (' disabled' if disabled else '', h, st, ico(icon, 18), text)
def note(t):
    return '<div style="margin: 0 16px; padding: 10px 12px; background: var(--sf); font-size: 13px; line-height: 1.45;">' + t + '</div>'

# ---- week table (one component everywhere)
MENU = [('Mon', 'Idli, sambar', 'Rice, dal, cabbage fry', 'Chapati, dal'),
        ('Tue', 'Poha', 'Rice, rasam, beans fry', 'Egg curry, rice'),
        ('Wed', 'Upma, chutney', 'Veg biryani, raita', 'Chapati, mixed veg'),
        ('Thu', 'Puri, aloo curry', 'Rice, sambar, potato fry', 'Fried rice'),
        ('Fri', 'Dosa, peanut chutney', 'Rice, tomato pappu, curd', 'Chicken curry or paneer'),
        ('Sat', 'Pongal', 'Rice, dal, bhindi fry', 'Chapati, aloo curry'),
        ('Sun', 'Bread omelette', 'Rice, dal, egg curry', 'Veg pulao')]
def wtable(days=None, today='Fri'):
    th = 'padding: 7px 6px; font-size: 10px; font-weight: 800; letter-spacing: .06em; text-transform: uppercase; color: var(--mu); text-align: left; border-bottom: 2px solid var(--tx);'
    td = 'padding: 8px 6px; border-bottom: 1px solid var(--hl); font-size: 12px; line-height: 1.3; vertical-align: top;'
    rows = ''
    for d, b, l, dn in MENU:
        if days and d not in days:
            continue
        hi = ' background: var(--ab);' if d == today else ''
        rows += '<tr style="%s"><td style="%s font-weight: 800;">%s</td><td style="%s">%s</td><td style="%s">%s</td><td style="%s">%s</td></tr>' % (hi.strip(), td, d + (' · today' if d == today else ''), td, b, td, l, td, dn)
    return ('<table style="width: 100%%; border-collapse: collapse; table-layout: fixed;"><thead><tr><th style="%s width: 52px;"></th><th style="%s">Breakfast · 7:30</th><th style="%s">Lunch · 12:30</th><th style="%s">Dinner · 8:00</th></tr></thead><tbody>%s</tbody></table>') % (th, th, th, th, rows)

# ---- hostel page pieces
def topbar_from():
    return ('<div style="flex: none; border-top: 2px solid var(--tx); padding: 12px 16px; display: grid; grid-template-columns: minmax(0, 1fr) auto; gap: 12px; align-items: center; background: var(--bg);"><span style="display: grid;"><b style="font-size: 19px;">From ₹5,800<span style="font-size: 13px; font-weight: 400; color: var(--mu);">/mo</span></b><span style="font-size: 12px; color: var(--mu);">₹8,800 to move in · 9 free</span></span>'
            '<button style="height: 50px; padding: 0 16px; display: flex; gap: 10px; align-items: center; font-weight: 800; font-size: 15px; background: var(--ac); color: var(--ai);">Pick a bed' + ico('arrow') + '</button></div>')
def page_head(k):
    return ('<div style="flex: none; padding: 10px 16px; display: flex; gap: 12px; align-items: center; border-bottom: 2px solid var(--tx);"><button aria-label="Back" style="width: 44px; height: 44px; flex: none; display: grid; place-items: center; border: 1px solid var(--dv);">' + ico('back', 20) + '</button><span style="display: grid;">' + kick(k) + '<b style="font-size: 17px;">Anjani Residency</b></span></div>')
def onfloor_old():
    fl = [('Floor 3', ['RO', 'Iron'], []), ('Floor 2', ['Fridge', 'RO'], ['Washer']), ('Floor 1', ['Fridge', 'RO', 'Washer'], [])]
    r = ''.join('<div style="padding: 10px 16px; border-bottom: 1px solid var(--hl); display: grid; gap: 6px;"><b style="font-size: 15px;">%s</b><span style="display: flex; gap: 6px; flex-wrap: wrap;">%s</span></div>' % (n, ''.join(thing(t) for t in ok) + ''.join(thing(t, True) for t in bad)) for n, ok, bad in fl)
    return ('<div style="padding: 18px 16px 6px; display: flex; justify-content: space-between; align-items: flex-end;">' + kick('On each floor') + '<span style="font-size: 12px; font-weight: 800; color: var(--mu);">Updated by residents · 28 Sep</span></div>'
            '<div style="border-top: 2px solid var(--tx);">' + r + '</div><div style="padding: 8px 16px 0;">' + mut('Shared by everyone on that floor.', 13) + '</div>'
            '<div style="padding: 12px 16px 0;"><a href="#" style="font-size: 14px; font-weight: 800; color: var(--tx); text-decoration: underline; display: inline-flex; gap: 6px; align-items: center;">' + ico('grid', 16) + 'See the whole building ›</a></div>')
def food_old():
    rows = ''.join('<div style="display: grid; grid-template-columns: 92px minmax(0, 1fr); gap: 12px; padding: 10px 16px; border-bottom: 1px solid var(--hl);"><span style="display: grid;"><b style="font-size: 14px;">%s</b><span style="font-size: 11px; color: var(--mu);">%s</span></span><span style="font-size: 14px;">%s</span></div>' % (m, t, d) for m, t, d in [('Breakfast', '7:30 – 9:30', 'Dosa, peanut chutney'), ('Lunch', '12:30 – 2:00', 'Rice, tomato pappu, curd'), ('Dinner', '8:00 – 10:00', 'Chicken curry or paneer')])
    return ('<div style="padding: 20px 16px 6px;">' + kick('Food menu · today, Friday') + '</div><div style="border-top: 2px solid var(--dv);">' + rows
            + '<div style="display: flex; justify-content: space-between; align-items: center; padding: 12px 16px; border-bottom: 1px solid var(--hl);"><b style="font-size: 14px;">Whole week</b>' + ico('chev', 16) + '</div></div>')
def food_new(label='Food menu · this week'):
    return ('<div style="padding: 20px 16px 6px; display: flex; justify-content: space-between; align-items: baseline;">' + kick(label) + '<span style="font-size: 12px; color: var(--mu);">From Srinivas’s menu</span></div><div style="padding: 0 10px;">' + wtable() + '</div>')
def rules_row():
    return '<div style="margin: 16px 16px 0; padding: 14px 12px; display: flex; justify-content: space-between; align-items: center; border-top: 2px solid var(--dv); border-bottom: 2px solid var(--dv);"><b style="font-size: 16px;">House rules</b>' + ico('chev', 18) + '</div>'
def visited_old():
    return ('<div style="padding: 16px; display: grid; gap: 8px;"><div style="padding: 12px; border: 2px solid var(--tx); display: flex; gap: 10px; align-items: flex-start;">' + ico('shield', 20)
            + '<span style="display: grid;"><b style="font-size: 15px;">Visited by Hostelzy · 12 Sep</b><span style="font-size: 12px; color: var(--mu); line-height: 1.35;">Photos taken by our team · beds and prices checked in person</span></span></div>' + avail() + '</div>')
def avail():
    return '<div style="padding: 10px 12px; background: var(--sf); font-size: 13px; line-height: 1.4;"><b>9 free beds</b> · confirmed by the owner today</div>'
def tags_old():
    c = 'padding: 14px 16px; background: var(--bg); font-size: 14px; font-weight: 600;'
    return ('<div style="background: var(--hl); border-top: 2px solid var(--dv); border-bottom: 2px solid var(--dv); display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 1px;">'
            + ''.join('<span style="%s">%s</span>' % (c, t) for t in ['3 meals a day', 'AC rooms', 'Power backup', 'Washing machine']) + '</div>')
def owner_head():
    return ('<div style="padding: 12px; display: flex; gap: 12px; align-items: center;"><b style="width: 44px; height: 44px; flex: none; display: grid; place-items: center; background: var(--sf);">SR</b><span style="display: grid;"><b style="font-size: 15px;">Srinivas, owner</b><span style="font-size: 12px; color: var(--mu);">Usually replies in ~12 min</span></span></div>')
def contact_old():
    return ('<div style="margin: 16px; border: 2px solid var(--tx);">' + owner_head()
            + '<div style="padding: 10px 12px; border-top: 1px solid var(--hl); display: flex; gap: 8px; align-items: center; color: var(--mu);">' + ico('lock', 16) + '<b style="flex-grow: 1; font-size: 15px;">98••• •••10</b><span style="font-size: 12px;">Shows after a hold</span></div>'
            + '<div style="padding: 0 12px 10px; font-size: 13px; line-height: 1.45;"><b>Owner’s number shows after you hold a bed.</b> Talking through Hostelzy keeps your deal and your ₹100 reward.</div>'
            + '<div style="padding: 0 12px 12px;"><button style="width: 100%; min-height: 50px; padding: 6px 14px; display: flex; justify-content: space-between; align-items: center; border: 2px solid var(--tx);"><span style="display: grid;"><b style="font-size: 14px;">Ask on WhatsApp</b><span style="font-size: 11px; font-weight: 600; color: var(--mu);">Saved on Hostelzy with a booking code</span></span>' + ico('msg') + '</button></div></div>')
def contact_locked():
    return ('<div style="margin: 16px; border: 2px solid var(--tx);">' + owner_head()
            + '<div style="padding: 10px 12px; border-top: 1px solid var(--hl); display: flex; gap: 8px; align-items: center;">' + ico('lock', 16) + '<b style="font-size: 14px; line-height: 1.35;">Message and call the owner after you hold a bed</b></div>'
            + '<div style="padding: 0 12px 12px; display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 8px;">' + obtn('WhatsApp', 'msg', disabled=True) + obtn('Call', 'phone', disabled=True) + '</div></div>')
def contact_open():
    return ('<div style="margin: 16px; border: 2px solid var(--tx);">' + owner_head()
            + '<div style="padding: 10px 12px; border-top: 1px solid var(--hl); display: flex; gap: 8px; align-items: center;">' + ico('phone', 16) + '<b style="flex-grow: 1; font-size: 15px;">98480 22310</b>' + tag('You held 204-D', 'ink') + '</div>'
            + '<div style="padding: 0 12px 12px; display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 8px;">' + obtn('WhatsApp', 'msg', 'ink') + obtn('Call', 'phone') + '</div></div>')
def bview(sel=False):
    blk = content[content.index('<div style="border: 2px solid var(--tx); border-top-width: 6px;">'):content.index(legend)]
    if not sel:
        blk = blk.replace(bed('sel', '', 14), bed('free', '', 14))
    lg = legend.replace(bed('sel', '', 12) + 'Your pick', '').replace('<span style="display: flex; gap: 5px; align-items: center;"></span>', '')
    return ('<div style="padding: 18px 16px 0; display: grid; gap: 10px;"><div style="display: flex; justify-content: space-between; align-items: baseline;">' + kick('Whole building · tap a free bed') + '</div>'
            + blk + lg + mut('Shared things sit on each floor; red = not working.', 12) + '</div>')
def scrollpage(inner):
    return '<div style="flex-grow: 1; overflow: hidden;">' + inner + '</div>'

# ================= [F26 #1 #2] Explore
s = rd('r-explore.dc.html')
a = s.index('<button style="margin: 0 16px; height: 52px;'); b = s.index('<div style="flex-grow: 1; overflow: hidden; border-top: 2px solid var(--dv); padding-top: 14px;">')
search = ('<div style="margin: 0 16px; height: 52px; display: flex; align-items: center; border: 2px solid var(--tx);"><span style="padding: 0 10px 0 14px; color: var(--mu); display: grid;">' + ico('search', 20)
          + '</span><span style="flex-grow: 1; font-size: 15px; color: var(--mu); white-space: nowrap; overflow: hidden;">Area, landmark or hostel</span><button aria-label="Show the map at my location" style="width: 48px; height: 48px; flex: none; display: grid; place-items: center; border-left: 2px solid var(--tx); color: var(--ad);">' + ico('pin', 22) + '</button></div>')
where = '<div style="margin: 10px 16px 0;">' + seg(['Near me', 'Pick a place'], 'Near me') + '</div>'
sortrow = ('<div style="display: flex; gap: 6px; padding: 10px 16px 0; align-items: center; overflow: hidden;"><span style="flex: none; display: flex; gap: 4px; align-items: center; font-size: 12px; font-weight: 800; color: var(--mu); padding-right: 4px;">' + ico('sort', 16) + 'Sort</span>'
           + chip('Price ↑', True, 34) + chip('Distance', False, 34) + chip('Rating', False, 34) + chip('Best deals', False, 34) + '</div>')
filt = s[s.index('<div style="display: flex; gap: 6px; padding: 10px 16px; overflow: hidden;">'):b]
after = s[:a] + search + where + sortrow + filt + s[b:]
after = after.replace('Hyderabad · 18 beds free now', 'Near me · Madhapur · 18 beds free')
after = after.replace('#1 near you', 'Lowest price')
_cs = '<div style="padding: 0 16px 16px; display: grid; gap: 6px;">'
_c1 = after.index(_cs); _c2 = after.index(_cs, _c1 + 10)
_feat = after[_c1:_c2].replace('Lowest price', 'Featured').replace('>Anjani Residency</b>', '>Orchid Grand Men’s PG</b>').replace('Men · Madhapur · 2.1 km from Hitec City · 9 free', 'Men · Madhapur · 1.4 km from Hitec City · 12 free · 96 beds').replace('₹7,600/mo', '₹8,400/mo').replace('₹10,600 to move in', '₹11,400 to move in').replace('Hostelzy price ₹7,400', 'Hostelzy price ₹8,200')
assert 'Orchid' in _feat and 'Featured' in _feat
after = after[:_c1] + _feat + '<div style="padding: 0 16px 8px;">' + kick('Then by price, lowest first') + '</div>' + after[_c1:]
W = {}
W['f26-explore.dc.html'] = board('f26-explore.dc.html', '[F26 #1 #2] Explore: search with map pin, Near me / Pick a place, sort', [
    col('before', 'One Where? bar opens the area picker. No sort.', src_phone('r-explore.dc.html')),
    col('after', '#1 Map pin in the search field. #2 Near me / Pick a place; sort Price ↑ (default) · Distance · Rating · Best deals. One Featured (80+ beds) pinned on top.', phone_div(after))])

# ================= [F26 #3 #4 #5 #6 #7] Hostel page
d = rd('r-detail.dc.html')
nm = '<b style="display: block; font-size: 30px' if '<b style="display: block; font-size: 30px' in d else None
k = d.index('>Anjani Residency</b>')
bstart = d.rindex('<b ', 0, k)
badge = '<span style="flex: none; display: inline-flex; gap: 4px; align-items: center; padding: 4px 8px; background: var(--vf); color: #ffffff; font-size: 11px; font-weight: 800; letter-spacing: .08em;">' + ico('check', 12) + 'VERIFIED</span>'
dnew = d[:bstart] + '<span style="display: flex; gap: 10px; align-items: center; flex-wrap: wrap;">' + d[bstart:k + len('>Anjani Residency</b>')] + badge + '</span><span style="font-size: 13px; color: var(--mu);">Beds and prices checked by Hostelzy · 12 Sep</span>' + d[k + len('>Anjani Residency</b>'):]
vb = dnew.index('Visited by Hostelzy</span>'); vs = dnew.rindex('<span', 0, vb)
dnew = dnew[:vs] + dnew[vb + len('Visited by Hostelzy</span>'):]
seeb = dnew.index('See the whole building'); sa = dnew.rindex('<a ', 0, seeb); sb = dnew.index('</a>', seeb) + 4
dnew = dnew[:sa] + '<a href="#" style="font-size: 14px; font-weight: 800; color: var(--tx); text-decoration: underline;">Whole building, food and owner below ⌄</a>' + dnew[sb:]
old_scroll = ph(page_head('Scrolled down') + scrollpage(onfloor_old() + food_old() + rules_row() + visited_old() + tags_old() + contact_old()) + topbar_from(), None, 1500)
new_scroll = ph(page_head('Scrolled down') + scrollpage(bview() + food_new() + rules_row() + '<div style="padding: 16px 16px 0;">' + avail() + '</div>' + contact_locked()) + topbar_from(), None, 1500)
W['f26-hostel.dc.html'] = board('f26-hostel.dc.html', '[F26 #3 #4 #5 #6 #7] Hostel page: top and scrolled, before → after', [
    col('before', 'Top: “Visited by Hostelzy” in the info line.', src_phone('r-detail.dc.html')),
    col('after', '#5 ✓ VERIFIED (navy) only when the team visited, with one muted line: “Beds and prices checked by Hostelzy · 12 Sep”.', phone_div(dnew)),
    col('before', 'Scrolled: On each floor list, today’s food card, Visited block, 4 tag boxes, Ask on WhatsApp.', old_scroll, h=1500),
    col('after', '#3 Building view inline, shared-thing chips on each floor row. #4 Whole-week food table. #6 Tag boxes gone. #7 Contact locked until a hold.', new_scroll, h=1500)], h=1500)

# dark: hostel page after (top + scrolled)
W['f26-hostelDark.dc.html'] = board('f26-hostelDark.dc.html', '[F26 #3 #4 #5 #6 #7] Hostel page [dark]', [
    col('after', 'Dark · top', phone_div(dnew)),
    col('after', 'Dark · scrolled', new_scroll, h=1500)], dark=True, h=1500)

# ================= [F26 #7] Contact locked → unlocked
lock_ph = ph(page_head('Hostel page · bottom') + scrollpage('<div style="padding: 16px 16px 0;">' + avail() + '</div>' + contact_locked()
             + '<div style="padding: 0 16px;">' + mut('No contact before a hold. “Enquire on WhatsApp” is gone.', 13) + '</div>') + topbar_from())
wa = ('<div style="margin: 0 16px; padding: 12px; border: 2px dashed var(--dv); display: grid; gap: 6px;">' + kick('WhatsApp opens with') + '<span style="font-size: 14px; line-height: 1.45;">“Hi Srinivas, I held bed 204-D at Anjani Residency on Hostelzy. Booking code HZ-4830.”</span></div>')
open_ph = ph(page_head('Hostel page · bottom') + scrollpage('<div style="padding: 16px 16px 0;">' + avail() + '</div>' + contact_open() + wa
             + '<div style="padding: 12px 16px 0;">' + mut('Both lock again if the hold expires or the owner declines.', 13) + '</div>') + topbar_from())
W['f26-contact.dc.html'] = board('f26-contact.dc.html', '[F26 #7] Owner contact: locked before a hold, WhatsApp + Call after', [
    col('state', 'No hold yet: both buttons locked, one line says why.', lock_ph, label='Locked'),
    col('state', 'After a hold: number shows, WhatsApp (with the HZ code) and Call switch on.', open_ph, label='Unlocked')])

# ================= [F26 #8] Pick a bed: all rooms at once
pr = [('Floor 1 · 3 free', [('101', '4 sharing · ₹5,800', ['taken', 'taken', 'free', 'taken']), ('102', '3 sharing AC · ₹8,000', ['taken', 'taken', 'free']), ('105', '2 sharing · ₹8,800', ['free', 'taken'])]),
      ('Floor 2 · 4 free', [('201', '3 sharing AC · ₹8,000', ['taken', 'free', 'taken']), ('202', '2 sharing · ₹8,800', ['free', 'hold']), ('203', '3 sharing AC · ₹8,000', ['taken', 'free', 'taken']), ('204', '4 sharing · ₹5,800', ['taken', 'taken', 'taken', 'sel'])]),
      ('Floor 3 · 1 free', [('301', '3 sharing · ₹6,800', ['taken', 'taken', 'free'])])]
def bedbtn(l, st):
    return '<button aria-label="Bed %s, %s" style="width: 40px; height: 40px; display: grid; place-items: center; font-size: 14px; font-weight: 800; %s">%s</button>' % (l, st, BED[st], l)
def proom(n, sub, beds):
    return ('<div style="display: grid; grid-template-columns: minmax(0, 1fr) auto; gap: 10px; align-items: center; padding: 8px 0; border-bottom: 1px solid var(--hl);"><span style="display: grid;"><b style="font-size: 15px;">Room %s</b><span style="font-size: 12px; color: var(--mu);">%s</span></span><div style="display: flex; gap: 6px;">%s</div></div>') % (n, sub, ''.join(bedbtn('ABCD'[i], b) for i, b in enumerate(beds)))
allrooms = ''.join('<div style="padding: 10px 0 0;"><div style="padding: 4px 0; border-bottom: 2px solid var(--tx);">' + kick(f) + '</div>' + ''.join(proom(*r) for r in rooms) + '</div>' for f, rooms in pr)
fchips = '<div style="display: flex; gap: 6px; padding: 12px 16px 6px; overflow: hidden;">' + ''.join(chip(t, False, 36) for t in ['Floor 1', 'Floor 2', 'Floor 3']) + '<span style="align-self: center; font-size: 12px; color: var(--mu); padding-left: 4px;">jump to</span></div>'
pick = picker('x', 'Plan', fchips + '<div style="flex-grow: 1; overflow: hidden; padding: 0 16px;">' + allrooms + '</div>')
pick = pick.replace(seg3('Plan'), SEG2)
W['f26-pick.dc.html'] = board('f26-pick.dc.html', '[F26 #8] Pick a bed: every room at once, floor chips only jump', [
    col('before', 'One floor at a time: the floor chips switch what shows.', src_phone('picker.dc.html')),
    col('after', 'All rooms in one list, grouped by floor. Floor chips only scroll to that floor.', phone_div(pick))])


# ================= [F26 #3 #8] Women's PG locked, 80+ beds collapsed
def lockover(inner, h, why):
    return ('<div style="position: relative; overflow: hidden;"><div aria-hidden="true" style="filter: blur(5px); opacity: .7; pointer-events: none;">' + inner + '</div>'
            '<div style="position: absolute; inset: 0; display: grid; place-items: center; padding: 16px;"><div style="background: var(--bg); border: 2px solid var(--tx); padding: 16px; display: grid; gap: 8px; justify-items: start; max-width: 300px;">' + ico('lock', 24)
            + '<b style="font-size: 18px;">' + h + '</b>' + mut(why, 13) + '</div></div></div>')
ss = ph(page_head('Scrolled down').replace('Anjani Residency', 'Sai Sri Ladies Hostel') + scrollpage(lockover(bview(), 'Hold a bed to see the floors', 'For residents’ safety, a women’s PG shows its building after a hold.') + food_new().replace('Srinivas’s', 'Lakshmi’s')) + topbar_from().replace('9 free', '6 free'))
big = ('<div style="padding: 18px 16px 0; display: grid; gap: 10px;">' + kick('Whole building')
       + '<button style="width: 100%; padding: 14px 12px; border: 2px solid var(--tx); display: grid; grid-template-columns: minmax(0, 1fr) 16px; gap: 10px; align-items: center;"><span style="display: grid;"><b style="font-size: 16px;">See all 38 rooms ›</b><span style="font-size: 13px; color: var(--mu);">96 beds on 6 floors · 12 free</span></span>' + ico('chev', 16) + '</button>'
       + mut('Big hostels open the building on its own page, so this page stays short.', 12) + '</div>')
og = ph(page_head('Scrolled down').replace('Anjani Residency', 'Orchid Grand Men’s PG') + scrollpage(big + food_new().replace('Srinivas’s', 'Ramesh’s')) + topbar_from().replace('9 free', '12 free'))
pl = picker('x', 'Plan', fchips + '<div style="flex-grow: 1; overflow: hidden; padding: 0 16px;">' + lockover(allrooms, 'Hold a bed to see the floors', 'For residents’ safety. Pick a room in the Room tab to hold a bed.') + '</div>')
pl = pl.replace(seg3('Plan'), SEG2).replace('Anjani Residency', 'Sai Sri Ladies Hostel').replace('Bed 204-D · ₹5,800/mo', 'No bed picked yet').replace('Floor 2 · window side · near the washer', 'Pick a room in the Room tab').replace('Continue<svg', 'Room tab<svg')
W['f26-locked.dc.html'] = board('f26-locked.dc.html', '[F26 #3] Hostel page, 80+ bed hostel: building collapses to See all rooms', [
    col('after', 'Hostel page, 80+ beds: the inline building collapses to “See all N rooms ›”.', og, label='After · 80+ beds')])

# ================= [F26 #9] Holds: steps, red dot, 30-min nudge
def steps(cur, declined=False):
    names = ['Sent', 'Owner reviewing', 'Declined' if declined else 'Kept']
    out = ''
    for i, n in enumerate(names):
        done = i < cur or (i == cur == 2)
        now = i == cur
        mark = ('background: var(--tx); color: var(--bg);' if done else ('background: var(--ac); color: var(--ai);' if now else 'border: 2px solid var(--dv); color: var(--mu);'))
        out += ('<div style="display: grid; grid-template-columns: 24px minmax(0, 1fr); gap: 10px; align-items: center;"><span style="width: 24px; height: 24px; display: grid; place-items: center; font-size: 12px; font-weight: 800; %s">%s</span><b style="font-size: 14px; %s">%s</b></div>') % (mark, ico('check', 14) if done else str(i + 1), '' if (done or now) else 'color: var(--mu);', n + (' · now' if now and i < 2 else ''))
    return '<div style="display: grid; gap: 8px;">' + out + '</div>'
def holdcard(state, body, r1='', r2=''):
    return ('<div style="margin: 12px 16px 0; border: 2px solid var(--tx);"><div style="display: grid; grid-template-columns: minmax(0, 1fr) auto; gap: 12px; align-items: center; padding: 12px; border-bottom: 1px solid var(--hl);"><span style="display: grid; gap: 2px;">' + state
            + '<b style="font-size: 17px; margin-top: 2px;">Bed 204-D</b><span style="font-size: 13px; color: var(--mu);">Anjani Residency · ₹5,800/mo · HZ-4830</span></span><span style="display: grid; justify-items: end;"><b style="font-size: 22px;">' + r1 + '</b><span style="font-size: 12px; color: var(--mu);">' + r2 + '</span></span></div><div style="padding: 12px; display: grid; gap: 12px;">' + body + '</div></div>')
holds_head = '<div style="flex: none; padding: 12px 16px 12px;"><b style="display: block; font-size: 30px; line-height: 1.02; letter-spacing: -.025em;">Holds</b></div>'
nav_hold = navdot(navsel(NAV_T, 'Holds'), 'Holds')
waiting = holdcard(tag('Held', 'red'), steps(1) + '<div style="padding: 10px 12px; background: var(--ab); color: var(--ad); font-size: 14px; font-weight: 800; line-height: 1.4;">Still waiting. Call the owner?</div>'
                   + '<div style="display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 8px;">' + obtn('Call', 'phone', 'ink') + obtn('WhatsApp', 'msg') + '</div>', '24:10', 'left')
kept = holdcard(tag('Kept', 'ink'), steps(2) + mut('Srinivas kept your bed. Visit before the hold ends, or pay to book.', 13)
                + '<div style="display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 8px;">' + obtn('WhatsApp', 'msg', 'ink') + obtn('Call', 'phone') + '</div>', '42:10', 'left')
declined = holdcard(tag('Declined', 'mu'), steps(2, True) + mut('The owner couldn’t keep this bed. Call and WhatsApp are locked again.', 13)
                    + '<div style="display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 8px;">' + obtn('WhatsApp', 'msg', disabled=True) + obtn('Call', 'phone', disabled=True) + '</div>' + btn('Find another bed', 'out', 'arrow', 44, 14), '—', 'ended')
W['f26-holds.dc.html'] = board('f26-holds.dc.html', '[F26 #7 #9 #16] Holds: steps, 30-minute nudge, WhatsApp + Call, red dot', [
    col('before', 'Held with a countdown. No steps, no way to reach the owner.', src_phone('holds.dc.html')),
    col('after', 'Owner reviewing for 30 min → “Still waiting. Call the owner?”. Red dot on the Holds tab until you open it.', ph(holds_head + '<div style="flex-grow: 1; overflow: hidden; border-top: 2px solid var(--tx);">' + waiting + '</div>', nav_hold), label='After · reviewing'),
    col('after', 'Kept: WhatsApp (ready message with HZ-4830) and Call. A push already tells you.', ph(holds_head + '<div style="flex-grow: 1; overflow: hidden; border-top: 2px solid var(--tx);">' + kept + '</div>', nav_hold), label='After · kept'),
    col('after', 'Declined: both lock again.', ph(holds_head + '<div style="flex-grow: 1; overflow: hidden; border-top: 2px solid var(--tx);">' + declined + '</div>', nav_hold), label='After · declined')])

# ================= [F26 #10 #11] Me
s = rd('me.dc.html')
for lbl in ['Saved', 'Holds']:
    k = s.index('<b style="font-size: 16px;">%s</b>' % lbl)
    a = s.rindex('<button style="width: 100%', 0, k); b = s.index('</button>', k) + 9
    s = s[:a] + s[b:]
k = s.index('<b style="font-size: 16px;">Help on WhatsApp</b>'); b = s.index('</button>', k) + 9
logout = '<button style="width: 100%; padding: 16px; border-top: 2px solid var(--dv); border-bottom: 1px solid var(--hl); display: flex; gap: 12px; align-items: center; color: var(--ad); font-size: 16px; font-weight: 800;">' + ico('out', 20) + 'Log out</button>'
s = s[:b] + logout + s[b:]
me_after = s
W['f26-me.dc.html'] = board('f26-me.dc.html', '[F26 #10 #11] Me: no Saved or Holds rows, Log out in red', [
    col('before', 'Saved and Holds repeat the tabs. Log out is inside Settings.', src_phone('me.dc.html')),
    col('after', '#10 Saved and Holds rows gone (they are tabs). #11 Log out in red at the end of the list.', phone_div(s))])

# ================= [F26 #12] Room layout: Edit this layout → try mode
s = rd('f23-Room.dc.html')
k = s.index('Bed 204-B · ₹5,800/mo'); a = s.rindex('<div style="flex: none', 0, k)
s = s[:a] + '<div style="flex: none; padding: 0 16px 10px;">' + obtn('Edit this layout', 'pencil', 'red').replace('style="height: 44px;', 'style="width: 100%; height: 44px;') + '</div>' + s[a:]
room_after = phone_div(s)
e = rd('f19-Edit.dc.html')
e = e.replace('Edit room · ', 'Try a layout · ', 1)
e = re.sub(r'Suggestion · you live in 204 · draft saved on this phone', 'Try mode · only on this phone', e, count=1)
e = e.replace('Only you see this until you send it', 'Move things to see how the room works for you', 1)
e = e.replace('Send to owner', 'Publish', 1)
k = e.rindex('</div>\n</x-dc>')
e = e[:k] + sheet(kick('Publish'), 'Only residents can send a fix', [], [btn('Pick a bed', 'red', 'arrow', 48, 15), btn('Keep trying', 'out', None, 48, 15)], 'Book a bed to join. Your tries stay on this phone.') + e[k:]
try_e = e
W['f26-room.dc.html'] = board('f26-room.dc.html', '[F26 #12] Room layout (tenant): Edit this layout → try mode', [
    col('before', 'Tenants can only look.', src_phone('f23-Room.dc.html')),
    col('after', '“Edit this layout” (red, primary) opens F19 try mode.', room_after),
    col('after', 'Publish in try mode: “Only residents can send a fix. Book a bed to join.”', phone_div(e), label='After · Publish tapped')])

# ================= [F26 #4 #13] Resident Home + new tab bar
h = rd('r-home.dc.html')
a = h.index('<div style="padding: 20px 16px 6px; display: flex; justify-content: space-between; align-items: baseline; gap: 12px;">')
b = h.index('<div style="flex-grow: 1;"></div>', a)
def foodblock(full):
    btnlbl = 'Fewer days' if full else 'Full week'
    return ('<div style="padding: 20px 16px 6px; display: flex; justify-content: space-between; align-items: baseline; gap: 12px;">' + kick('Food this week')
            + '<button style="display: inline-flex; gap: 4px; align-items: center; font-size: 13px; font-weight: 800; color: var(--ad);">' + btnlbl + ico('chevD', 14).replace('<svg', '<svg style="transform: rotate(180deg);"' if full else '<svg', 1).replace('style="flex: none;"', '' if full else 'style="flex: none;"') + '</button></div>'
            + '<div style="padding: 0 10px;">' + wtable(None if full else ['Fri', 'Sat', 'Sun']) + '</div>')
nh = re.sub(r'<nav.*?</nav>', lambda m: nav_res('Home'), h, count=1, flags=re.S)
home_a = nh[:a] + foodblock(False) + nh[b:]
home_b = nh[:a] + foodblock(True) + nh[b:]
W['f26-home.dc.html'] = board('f26-home.dc.html', '[F26 #4 #13] Resident Home: week table, Full week opens in place, new tab bar', [
    col('before', 'Today’s food card; Full week goes to the Food tab. Tabs: Home · Food · Pay rent · Help · Me.', src_phone('r-home.dc.html')),
    col('after', 'Same week table as the hostel page, today first. Tabs: Home · Rent · My stay · Find a bed · Me.', phone_div(home_a)),
    col('after', 'Full week opens the whole table right here. No Food page.', phone_div(home_b), label='After · Full week open')])
W['f26-homeDark.dc.html'] = board('f26-homeDark.dc.html', '[F26 #4 #13] Resident Home [dark]', [
    col('after', 'Dark', phone_div(home_a)), col('after', 'Dark · Full week open', phone_div(home_b))], dark=True)

# ================= [F26 #14] My stay tab (Help inside)
def srow2(ic, t, sub, red=False):
    return ('<button style="width: 100%; display: grid; grid-template-columns: 36px minmax(0, 1fr) 16px; gap: 12px; align-items: center; padding: 12px 16px; border-bottom: 1px solid var(--hl);"><span style="width: 36px; height: 36px; display: grid; place-items: center; background: var(--sf);">' + ico(ic)
            + '</span><span style="display: grid; gap: 1px;"><b style="font-size: 16px;">' + t + '</b><span style="font-size: 13px; color: %s;">' % ('var(--ad)' if red else 'var(--mu)') + sub + '</span></span>' + ico('chev', 16) + '</button>')
stay_body = (hdr('Anjani Residency', 'My stay') + '<div style="flex-grow: 1; overflow: hidden;">'
             + '<div style="margin: 0 16px 12px; padding: 14px; border: 2px solid var(--tx); display: grid; gap: 2px;"><b style="font-size: 20px;">Bed 204-B · Room 204</b><span style="font-size: 14px; color: var(--mu);">Since 14 Mar 2026 · ₹7,600 a month · rent due on the 14th</span></div>'
             + '<div style="padding: 0 16px 6px;">' + kick('Your bed') + '</div><div style="border-top: 2px solid var(--tx);">'
             + srow2('swap', 'Move to another bed', '6 free beds here') + srow2('out', 'Give notice', '30 days · earliest last day 4 Nov') + srow2('money', 'Your refund', '₹2,000 back when you leave') + srow2('star', 'Review your stay', '30-day review is open') + srow2('pencil', 'Fix a room layout', 'Any room in Anjani Residency') + '</div>'
             + '<div style="padding: 16px 16px 6px;">' + kick('Help') + '</div><div style="border-top: 2px solid var(--tx);">'
             + srow2('wrench', 'Something wrong in your room?', 'Wi-Fi, water, electricity, cleaning, food') + srow2('msg', 'Your complaints', '1 being fixed · Geyser', True) + '</div></div>')
W['f26-stay.dc.html'] = board('f26-stay.dc.html', '[F26 #14] My stay tab: bed, notice/move, refund, Help inside', [
    col('before', 'My stay sat inside Me (with a back button).', src_phone('stay.dc.html')),
    col('before', 'Help was its own tab.', src_phone('r-help.dc.html'), label='Before · Help tab'),
    col('after', 'One My stay tab: your bed, move, notice, refund, review, layout fix, then Help. The Help page folds in here.', ph(stay_body, nav_res('My stay')))])

# ================= [F26 #17] Find a bed tab
fb = after
strip = ('<div style="flex: none; padding: 8px 16px; background: var(--tx); color: var(--bg); display: flex; justify-content: space-between; align-items: center; gap: 10px; font-size: 13px;"><span>You’re browsing as a tenant</span><a href="#" style="color: var(--bg); font-weight: 800; text-decoration: underline;">← My stay</a></div>')
k = root_inner(fb)
fb = fb[:k] + strip + fb[k:]
fb = re.sub(r'<nav.*?</nav>', lambda m: nav_res('Find a bed'), fb, count=1, flags=re.S)
W['f26-findbed.dc.html'] = board('f26-findbed.dc.html', '[F26 #15 #17] Find a bed tab (resident): tenant Explore with a strip', [
    col('after', 'Resident’s Find a bed tab = tenant Explore with a strip on top. Nothing about the stay changes. No Holds tab for residents.', phone_div(fb), label='New')])

# ================= [F26 #18] Owner Today grouped
def trow(ic, t, sub, right, rred, btns):
    rc = 'var(--ad)' if rred else 'var(--mu)'
    b = '<div style="display: grid; grid-template-columns: repeat(%d, minmax(0, 1fr)); gap: 8px;">%s</div>' % (len(btns), ''.join(btns)) if btns else ''
    return ('<div style="padding: 12px 16px; border-bottom: 1px solid var(--hl); display: grid; gap: 8px;"><div style="display: grid; grid-template-columns: 36px minmax(0, 1fr) auto; gap: 10px; align-items: center;"><span style="width: 36px; height: 36px; display: grid; place-items: center; background: var(--sf);">%s</span><span style="display: grid; gap: 1px;"><b style="font-size: 15px;">%s</b><span style="font-size: 12px; color: var(--mu);">%s</span></span><b style="font-size: 14px; color: %s;">%s</b></div>%s</div>') % (ico(ic), t, sub, rc, right, b)
def gtabs(active, counts):
    out = ''
    for n, c in counts:
        on = n == active
        st = 'background: var(--tx); color: var(--bg);' if on else 'color: var(--tx);'
        out += '<button style="padding: 8px 2px; display: grid; justify-items: center; gap: 1px; %s"><b style="font-size: 18px; line-height: 1.1;">%s</b><span style="font-size: 11px; font-weight: 600;">%s</span></button>' % (st, c, n)
    return '<div style="margin: 0 16px; display: grid; grid-template-columns: repeat(%d, minmax(0, 1fr)); border: 2px solid var(--tx);">' % len(counts) + out + '</div>'
fair = ('<div style="margin: 0 16px 10px; padding: 10px 12px; background: var(--ab); color: var(--ad); display: grid; grid-template-columns: 20px minmax(0, 1fr) auto; gap: 10px; align-items: center;">' + ico('flag', 20)
        + '<span style="display: grid;"><b style="font-size: 14px;">Fair Play · a tenant says the bed was taken</b><span style="font-size: 12px;">Reply in 47 h · pinned until you answer</span></span>' + ico('chev', 16) + '</div>')
_t = rd('r-today.dc.html'); _a = _t.rindex('<div', 0, _t.index('>This month<')); _b = _t.index('<nav'); month_raw = _t[_a:_t.rindex('</div>', 0, _b)]
today_head = hdr('Anjani Residency · Fri 2 Oct', 'Today', avatar('SR'))
month = ('<div style="padding: 16px 16px 6px; display: flex; justify-content: space-between; align-items: baseline;">' + kick('This month') + '<b style="font-size: 13px;">83% full</b></div>'
         '<div style="display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); border-top: 2px solid var(--dv); border-bottom: 1px solid var(--hl);">'
         + ''.join('<span style="padding: 10px 16px; display: grid;"><b style="font-size: 20px;">%s</b><span style="font-size: 12px; color: var(--mu);">%s</span></span>' % x for x in [('33 / 40', 'beds taken'), ('7', 'free beds'), ('₹15,840', 'rent pending')]) + '</div>'
         '<div role="img" aria-label="83% of beds taken" style="margin: 8px 16px 0; height: 8px; border: 1px solid var(--tx); background: var(--sf);"><div style="width: 83%; height: 100%; background: var(--tx);"></div></div>')
holdrows = (trow('clock', 'Hold on bed 102-C', 'Hostelzy tenant · booking code HZ-4830', '41 min', True, [btn('Confirm', 'red', 'check', 40, 13), btn('Decline', 'out', 'x', 40, 13)])
            + trow('clock', 'Hold on bed 201-B', 'Hostelzy tenant · booking code HZ-4833', '58 min', False, [btn('Confirm', 'red', 'check', 40, 13), btn('Decline', 'out', 'x', 40, 13)]))
grp = (today_head + '<div style="flex-grow: 1; overflow: hidden;">' + fair + '<div style="padding: 0 16px 6px; display: flex; justify-content: space-between; align-items: baseline;">' + kick('Needs you · most urgent first') + '</div>'
       + gtabs('Holds', [('Holds', 2), ('Payments', 1), ('Fixes', 1)]) + '<div style="border-top: 0;">' + holdrows + '</div>' + month_raw + '</div>')
grp_empty = (today_head + '<div style="flex-grow: 1; overflow: hidden;">' + gtabs('Holds', [('Holds', 0), ('Payments', 0), ('Fixes', 0)])
             + '<div style="margin: 12px 16px 0; padding: 20px 16px; border: 2px dashed var(--dv); display: grid; gap: 6px; justify-items: start;">' + ico('check', 24) + '<b style="font-size: 18px;">Nothing needs you now</b>' + mut('New holds, payments and fixes show up here.', 13) + '</div>' + month_raw + '</div>')
W['f26-today.dc.html'] = board('f26-today.dc.html', '[F26 #18] Owner Today: Holds · Payments · Fixes with counts, Fair Play pinned', [
    col('before', 'One long list of cards, every kind mixed.', src_phone('r-today.dc.html')),
    col('after', 'Holds · Payments · Fixes with counts; Enquiries are gone. Most urgent tab opens first; Fair Play pinned on top.', ph(grp, NAV_O)),
    col('after', 'All counts 0: “Nothing needs you now”.', ph(grp_empty, NAV_O), label='After · empty')])
W['f26-todayDark.dc.html'] = board('f26-todayDark.dc.html', '[F26 #18] Owner Today [dark]', [
    col('after', 'Dark', ph(grp, NAV_O)), col('after', 'Dark · empty', ph(grp_empty, NAV_O))], dark=True)

# ================= [F26 #19] Owner Beds: Building only
s = rd('w4-oBedsBuilding.dc.html')
a = s.index('<div style="display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); margin: 0 16px 10px; border: 2px solid var(--tx);">'); b = s.index('</div>', s.index('Building</button>', a)) + 6
s = s[:a] + s[b:]
s = s.replace('Shared things sit on top of each floor. Tap a floor to see if they’re working.', 'Tap a bed for its bed sheet. Tap a room number for its layout. <a href="#" style="font-weight: 800;">Layouts ›</a> to create or copy one.')
assert 'Layouts ›' in s
beds_after = s
W['f26-beds.dc.html'] = board('f26-beds.dc.html', '[F26 #19] Owner Beds: Building view only', [
    col('before', 'Rooms list, floor by floor (Building was a second toggle).', src_phone('beds.dc.html')),
    col('after', 'Building view only. Tap a bed → bed sheet. Tap a room → its layout. Layouts page stays for create/copy.', phone_div(s))])

# ================= [F26 #20] Owner Rent: Call + WhatsApp
s = rd('oRent.dc.html')
bell = re.compile(r'<button aria-label="Remind on WhatsApp" style="width: 44px; height: 44px; display: grid; place-items: center; border: 2px solid var\(--tx\);"><svg.*?</svg></button>', re.S)
two = ('<span style="display: flex; gap: 6px;"><button aria-label="Call" style="width: 44px; height: 44px; display: grid; place-items: center; border: 2px solid var(--tx);">' + ico('phone') + '</button>'
       '<button aria-label="WhatsApp reminder" style="width: 44px; height: 44px; display: grid; place-items: center; background: var(--tx); color: var(--bg);">' + ico('msg') + '</button></span>')
s, n = bell.subn(two, s); assert n == 3, n
s = s.replace('border: 1px solid var(--dv); color: var(--mu);">Paid</span>', 'background: var(--gb); color: var(--gn); border: 1px solid var(--gb);">Paid</span>')
s = s.replace('border: 1px solid var(--tx); color: var(--tx);">Due</span>', 'border: 1px solid var(--dv); color: var(--tx);">Due</span>')
assert 'var(--gb);">Paid' in s
k = s.rindex('<nav')
s = s[:k] + '<div style="flex: none; margin: 0 16px 12px; padding: 12px; border: 2px dashed var(--dv); display: grid; gap: 4px;">' + kick('WhatsApp opens with') + '<span style="font-size: 13px; line-height: 1.45;">“Hi Faiz, October rent ₹7,600 for bed 101-A is 12 days late. Pay in the Hostelzy app or by UPI to anjani@okhdfc.”</span></div>' + s[k:]
rent_after = s
W['f26-rent.dc.html'] = board('f26-rent.dc.html', '[F26 #20] Owner Rent: Paid green, Late red, Due plain; Call + WhatsApp', [
    col('before', 'One bell per row: Remind on WhatsApp.', src_phone('oRent.dc.html')),
    col('after', 'Paid green, Late red, Due plain. Call and WhatsApp on every unpaid row; WhatsApp opens with a ready reminder.', phone_div(s))])

# ================= ROUND 2 (founder, 2026-10-06)
I['filter'] = re.search(r'<svg[^>]*>(.*?)</svg>', filt, re.S).group(1)
# --- Explore: one row
def chip2(inner, on=False):
    st = 'background: var(--tx); color: var(--bg); border: 2px solid var(--tx);' if on else 'border: 2px solid var(--tx); color: var(--tx);'
    return '<button style="flex: none; height: 40px; padding: 0 12px; font-size: 13px; font-weight: 800; white-space: nowrap; display: flex; gap: 6px; align-items: center; %s">%s</button>' % (st, inner)
onerow = ('<div style="display: flex; gap: 6px; padding: 10px 16px; overflow: hidden;">' + chip2(ico('pin', 16) + 'Near me' + ico('check', 14), True)
          + chip2('Price ↑' + ico('chevD', 14)) + chip2(ico('filter', 16) + 'Filters · 2') + '</div>')
after2 = after.replace(where + sortrow + filt, onerow)
assert onerow in after2
after2 = after2.replace('Near me · Madhapur · 18 beds free', 'Madhapur · 12 verified · 84 listed')
def fsec(t, chips):
    return '<div style="padding: 12px 16px 0; display: grid; gap: 8px;">' + kick(t) + '<div style="display: flex; gap: 6px; flex-wrap: wrap;">' + ''.join(chip(c, on) for c, on in chips) + '</div></div>'
fsheet = sheet(kick('2 on'), 'Filters', [fsec('Who', [('Men', True), ('Women', False), ('Co-living', False)]), fsec('Room', [('AC', True), ('Non-AC', False)]), fsec('Food', [('Food included', False), ('No food', False)]), fsec('Rent', [('Under ₹8,000', False), ('Under ₹10,000', False)])],
               [btn('Show 9 hostels', 'red', 'arrow', 48, 15), btn('Clear all', 'out', None, 48, 15)])
k = after2.rindex('</div>\n</x-dc>')
filters_open = after2[:k] + fsheet + after2[k:]
W['f26-explore.dc.html'] = board('f26-explore.dc.html', '[F26 #1 #2] Explore: map pin in search, one row Near me · Price ↑ · Filters', [
    col('before', 'One Where? bar, then a long chip row. No sort.', src_phone('r-explore.dc.html')),
    col('after', 'One row: Near me ✓ (tap again → Pick a place) · Price ↑ ▾ (Distance, Rating, Best deals) · Filters · 2. Featured on top.', phone_div(after2)),
    col('after', 'Men / Women / Co-living / AC / Food live in the Filters sheet.', phone_div(filters_open), label='After · Filters open')])

# --- [F26 #21] UNVERIFIED listings
UNV = '<span style="flex: none; display: inline-flex; align-items: center; padding: 3px 8px; border: 2px solid var(--mu); color: var(--mu); font-size: 11px; font-weight: 800; letter-spacing: .08em;">UNVERIFIED</span>'
VER_S = badge.replace('padding: 4px 8px', 'padding: 3px 7px').replace('font-size: 11px', 'font-size: 10px')
def stripes(h, label):
    return '<div style="height: %dpx; position: relative; background: repeating-linear-gradient(135deg, var(--sf) 0 8px, var(--bg) 8px 16px); border: 1px solid var(--hl);"><span style="position: absolute; left: 8px; bottom: 8px; font-size: 12px; color: var(--mu);">%s</span></div>' % (h, label)
unv_card = ('<div style="padding: 0 16px 16px; display: grid; gap: 6px;">' + stripes(150, 'photo 1 / 4 · by the Hostelzy team')
            + '<div style="display: flex; gap: 8px; align-items: center; flex-wrap: wrap;"><b style="font-size: 17px;">Sri Balaji Men’s PG</b>' + UNV + '</div>'
            + '<span style="font-size: 13px; color: var(--mu);">Men · Madhapur · 1.9 km from Hitec City</span>'
            + '<span style="font-size: 14px;"><b>Around ₹7,000–9,000/mo</b> · <span style="color: var(--mu);">expected, not confirmed</span></span></div>')
_cs = '<div style="padding: 0 16px 16px; display: grid; gap: 6px;">'
c1 = after2.index(_cs); nv = after2.index('<nav'); c2 = after2.rindex('</div>', 0, nv)
cards = re.findall(re.escape(_cs) + r'.*?(?=' + re.escape(_cs) + r'|$)', after2[c1:c2], re.S)
anj = [c for c in cards if '>Anjani Residency</b>' in c][0]
anj = anj.replace('<b style="font-size: 17px;">Anjani Residency</b>', '<span style="display: flex; gap: 8px; align-items: center;"><b style="font-size: 17px;">Anjani Residency</b>' + VER_S + '</span>')
anj = anj.replace('height: 168px;', 'height: 150px;')
list_ph = after2[:c1] + '<div style="padding: 0 16px 8px;">' + kick('₹7,000–9,000 · verified first') + '</div>' + anj + unv_card + after2[c2:]
upage = ('<div style="flex: none; position: relative;">' + stripes(200, 'photo 1 / 4 · by the Hostelzy team') + '<button aria-label="Back" style="position: absolute; left: 16px; top: 12px; width: 44px; height: 44px; display: grid; place-items: center; background: var(--bg); border: 1px solid var(--dv);">' + ico('back', 20) + '</button></div>'
         + '<div style="flex-grow: 1; overflow: hidden; padding: 14px 16px; display: grid; gap: 12px; align-content: start;">'
         + '<div style="display: grid; gap: 4px;">' + kick('Men · Madhapur, Hyderabad') + '<span style="display: flex; gap: 10px; align-items: center; flex-wrap: wrap;"><b style="font-size: 30px; line-height: 1.05; letter-spacing: -.025em;">Sri Balaji Men’s PG</b>' + UNV + '</span>'
         + '<span style="font-size: 13px; color: var(--mu);">Listed by the Hostelzy team · not checked yet</span></div>'
         + '<div style="border-top: 2px solid var(--tx); padding-top: 12px; display: grid; gap: 2px;">' + kick('Rent per month') + '<b style="font-size: 24px;">Around ₹7,000–9,000</b><span style="font-size: 13px; color: var(--mu);">Expected, not confirmed. The owner hasn’t joined Hostelzy yet.</span></div>'
         + '<div style="padding: 12px; background: var(--sf); font-size: 14px; line-height: 1.45;">No free beds, holds or owner contact yet. When our team checks this hostel, you’ll see its beds and can hold one.</div>'
         + '<a href="#" style="font-size: 14px; font-weight: 800; color: var(--tx); text-decoration: underline;">Are you the owner? Claim this hostel ›</a></div>'
         + '<div style="flex: none; border-top: 2px solid var(--tx); padding: 12px 16px 20px; display: grid; gap: 8px;">' + btn('Tell me when verified', 'red', 'bell') + btn('Ask Hostelzy', 'out', 'msg') + '</div>')
def namehead(name, b, line):
    return ('<div style="padding: 14px 16px; border-bottom: 1px solid var(--hl); display: grid; gap: 4px;">' + kick('Men · Madhapur') + '<span style="display: flex; gap: 10px; align-items: center; flex-wrap: wrap;"><b style="font-size: 24px; letter-spacing: -.02em;">' + name + '</b>' + b + '</span><span style="font-size: 13px; color: var(--mu);">' + line + '</span></div>')
badges = ph('<div style="padding: 14px 16px 6px;">' + kick('Verified · team visited') + '</div>' + namehead('Anjani Residency', badge, 'Beds and prices checked by Hostelzy · 12 Sep')
            + '<div style="padding: 18px 16px 6px;">' + kick('Unverified · listed, not checked') + '</div>' + namehead('Sri Balaji Men’s PG', UNV, 'Listed by the Hostelzy team · not checked yet'), None, 380)
W['f26-unverified.dc.html'] = board('f26-unverified.dc.html', '[F26 #21] UNVERIFIED listings: Explore card and hostel page', [
    col('after', 'Explore: verified first inside each price band. An unverified card shows an expected rent range.', phone_div(list_ph), label='New · Explore'),
    col('after', 'Unverified hostel page: no beds, holds or owner contact. Tell me when verified (push when live), Ask Hostelzy (WhatsApp), Claim.', ph(upage), label='New · hostel page'),
    col('after', 'Both badges, same spot next to the name: ✓ VERIFIED navy, UNVERIFIED grey outline.', badges, label='Badges', h=380)])

# --- [F26 #8] Pick a bed: no tabs, drawn layouts
def lay(beds, ac=True):
    el = ('<span style="position: absolute; left: 120px; top: -2px; width: 110px; height: 6px; background: var(--tx);"></span><span style="position: absolute; left: 128px; top: 8px; font-size: 9px; font-weight: 800; letter-spacing: .06em;">WINDOW</span>'
          '<span style="position: absolute; right: 20px; bottom: -2px; width: 44px; height: 6px; background: var(--bg); border-left: 2px solid var(--tx); border-right: 2px solid var(--tx);"></span><span style="position: absolute; right: 22px; bottom: 8px; font-size: 9px; font-weight: 800; letter-spacing: .06em;">DOOR</span>'
          '<span style="position: absolute; left: 0; bottom: 0; width: 92px; height: 58px; border-top: 2px solid var(--tx); border-right: 2px solid var(--tx); background: repeating-linear-gradient(135deg, var(--sf) 0 4px, var(--bg) 4px 8px); display: flex; align-items: flex-end; padding: 4px; font-size: 9px; font-weight: 800; letter-spacing: .06em;">WASHROOM</span>'
          '<span style="position: absolute; left: 150px; top: 80px; width: 34px; height: 34px; border: 2px dashed var(--dv); border-radius: 50%; display: grid; place-items: center; font-size: 8px; font-weight: 800;">FAN</span>')
    if ac:
        el += '<span style="position: absolute; right: -2px; top: 26px; width: 8px; height: 46px; background: var(--tx);"></span><span style="position: absolute; right: 12px; top: 40px; font-size: 9px; font-weight: 800; letter-spacing: .06em;">AC</span>'
    pos = [(12, 16), (62, 16), (244, 90), (290, 90)]
    for i, st in enumerate(beds):
        x, y = pos[i]
        el += '<span aria-label="Bed %s, %s" style="position: absolute; left: %dpx; top: %dpx; width: 40px; height: 74px; display: grid; align-content: start; padding: 4px; font-size: 14px; font-weight: 800; %s">%s</span>' % ('ABCD'[i], st, x, y, BED[st], 'ABCD'[i])
    return '<div style="position: relative; height: 180px; border: 2px solid var(--tx); background: var(--bg);">' + el + '</div>'
def roomcard(n, sub, free, beds, ac=True):
    return ('<div style="padding: 10px 0 14px; border-bottom: 1px solid var(--hl); display: grid; gap: 8px;"><div style="display: flex; justify-content: space-between; align-items: baseline; gap: 8px;"><span style="display: grid;"><b style="font-size: 16px;">Room ' + n + '</b><span style="font-size: 12px; color: var(--mu);">' + sub + '</span></span><b style="font-size: 13px;">' + free + '</b></div>'
            + lay(beds, ac) + '<div style="display: flex; justify-content: flex-end;">' + obtn('Edit this layout', 'pencil', 'red', 40) + '</div></div>')
fch = '<div style="display: flex; gap: 6px; padding: 4px 16px 8px; overflow: hidden;">' + chip('Floor 1') + chip('Floor 2', True) + chip('Floor 3') + '</div>'
rooms2 = ('<div style="flex-grow: 1; overflow: hidden; padding: 0 16px; border-top: 2px solid var(--tx);">' + '<div style="padding-top: 10px;">' + kick('Floor 2 · 4 free') + '</div>'
          + roomcard('201', '3 sharing AC · ₹8,000', '1 free', ['taken', 'sel', 'taken'], True) + roomcard('202', '2 sharing · ₹8,800', '1 free', ['free', 'hold'], False) + '</div>')
pick2 = picker('x', 'Plan', fch + rooms2).replace(seg3('Plan'), '')
pick2 = pick2.replace('Bed 204-D · ₹5,800/mo', 'Bed 201-B · ₹8,000/mo').replace('Floor 2 · window side · near the washer', 'Floor 2 · by the window · AC room')
W['f26-pick.dc.html'] = board('f26-pick.dc.html', '[F26 #8] Pick a bed: no tabs, floor chips, every room’s drawn layout', [
    col('before', 'Plan · Room tabs, one floor at a time.', src_phone('picker.dc.html')),
    col('after', 'No tabs. Floor chips filter and jump; every room’s drawn layout in one scroll. Edit this layout in red.', phone_div(pick2))])

# --- [F26 #4 #13] Home: week table always open
def foodblock2():
    return ('<div style="padding: 20px 16px 6px; display: flex; justify-content: space-between; align-items: baseline; gap: 12px;">' + kick('Food this week') + '<span style="font-size: 12px; color: var(--mu);">From Srinivas’s menu</span></div>'
            + '<div style="padding: 0 10px;">' + wtable() + '</div>')
_ha = nh.index('<div style="padding: 20px 16px 6px; display: flex; justify-content: space-between; align-items: baseline; gap: 12px;">'); _hb = nh.index('<div style="flex-grow: 1;"></div>', _ha)
home2 = nh[:_ha] + foodblock2() + nh[_hb:]
W['f26-home.dc.html'] = board('f26-home.dc.html', '[F26 #4 #13] Resident Home: week table always open, new tab bar', [
    col('before', 'Today’s food card; Full week goes to the Food tab. Tabs: Home · Food · Pay rent · Help · Me.', src_phone('r-home.dc.html')),
    col('after', 'The 7-day table, always open, today highlighted. No toggle. Tabs: Home · Rent · My stay · Find a bed · Me.', phone_div(home2))])
W['f26-homeDark.dc.html'] = board('f26-homeDark.dc.html', '[F26 #4 #13] Resident Home [dark]', [col('after', 'Dark', phone_div(home2))], dark=True)

# --- [F26 #17] Find a bed = the full tenant app
k = me_after.index('<button style="width: 100%')
mystay = ('<button style="width: 100%; display: grid; grid-template-columns: 36px minmax(0, 1fr) 16px; gap: 12px; align-items: center; padding: 12px 16px; border-top: 2px solid var(--tx); border-bottom: 2px solid var(--tx); background: var(--ab);"><span style="width: 36px; height: 36px; display: grid; place-items: center; background: var(--bg);">' + ico('bed')
          + '</span><span style="display: grid; gap: 1px;"><b style="font-size: 16px;">My stay</b><span style="font-size: 13px; color: var(--mu);">Back to Anjani Residency · Bed 204-B</span></span>' + ico('chev', 16) + '</button>')
me_t = me_after[:k] + mystay + me_after[k:]
me_t = me_t.replace('Ravi Teja', 'Rahul Varma').replace('>RT<', '>RV<')
fb_ex = after2.replace('Madhapur · 12 verified · 84 listed', 'Madhapur · 12 verified · 84 listed')
def nav_rt(on):
    tabs = [('home', 'Explore'), ('pin', 'Map'), ('heart', 'Saved & Holds'), ('bed', 'My stay'), ('user', 'Me')]
    out = ''
    for ic, l in tabs:
        st = 'color: var(--tx); box-shadow: inset 0 3px 0 var(--ac);' if l == on else 'color: var(--mu);'
        out += ('<button style="display: flex; flex-direction: column; justify-content: center; align-items: flex-start; gap: 4px; padding: 0 6px; font-size: 11px; line-height: 1.1; font-weight: 600; %s"><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="square" style="flex: none;">%s</svg>%s</button>') % (st, I[ic], l)
    return '<nav style="flex: none; display: grid; grid-template-columns: repeat(5, minmax(0, 1fr)); height: 64px; border-top: 2px solid var(--tx); background: var(--bg);">' + out + '</nav>'
fb_ex2 = re.sub(r'<nav.*?</nav>', lambda m: nav_rt('Explore'), fb_ex, count=1, flags=re.S)
sh = (holds_head.replace('>Holds</b>', '>Saved &amp; Holds</b>') + '<div style="margin: 0 16px 12px;">' + seg(['Saved · 2', 'Holds · 1'], 'Holds · 1') + '</div>'
      + '<div style="flex-grow: 1; overflow: hidden; border-top: 2px solid var(--tx);">' + kept.replace('Bed 204-D', 'Bed 302-A').replace('Anjani Residency · ₹5,800/mo · HZ-4830', 'Orchid Grand Men’s PG · ₹8,400/mo · HZ-4851').replace('Srinivas kept your bed.', 'Ramesh kept your bed.') + '</div>')
W['f26-findbed.dc.html'] = board('f26-findbed.dc.html', '[F26 #17] Find a bed: tenant app for residents, Saved & Holds + My stay tabs', [
    col('after', 'Resident taps Find a bed in their tab bar.', phone_div(home2), label='1 · Resident'),
    col('after', 'Tenant app, resident version: Explore · Map · Saved &amp; Holds · My stay · Me. My stay returns to the resident app.', phone_div(fb_ex2), label='2 · Find a bed'),
    col('after', 'Saved &amp; Holds is one tab with two segments. A resident can hold a bed elsewhere.', ph(sh, nav_rt('Saved & Holds')), label='3 · Saved &amp; Holds')])

# ================= Tab bars
def navblock(lbl, nav, sub):
    return '<div style="padding: 18px 0 0; display: grid; gap: 6px;"><div style="padding: 0 16px; display: grid; gap: 2px;">' + kick(lbl) + '<span style="font-size: 13px; line-height: 1.4;">' + sub + '</span></div>' + nav.replace('flex: none; display: grid;', 'flex: none; display: grid; border-bottom: 2px solid var(--tx);', 1) + '</div>'
nav_res_old = re.search(r'<nav.*?</nav>', rd('r-home.dc.html'), re.S).group(0)
tb = (hdr('F26 · after the change', 'Tab bars') + '<div style="flex-grow: 1; overflow: hidden;">'
      + navblock('Tenant · unchanged', navdot(plain_nav(NAV_T), 'Holds'), 'Explore · Map · Saved · Holds · Me. Red dot on Holds when a hold result comes in (#9, #16).')
      + navblock('Resident · before', nav_res_old, 'Home · Food · Pay rent · Help · Me')
      + navblock('Resident · after', nav_res('Home'), 'Home · Rent · My stay · Find a bed · Me. No Food tab (#13), Help inside My stay (#14). Find a bed opens the tenant app with its own bar (below).')
      + navblock('Resident inside Find a bed', nav_rt('Explore'), 'Explore · Map · Saved &amp; Holds (one tab, two segments) · My stay (back to the resident app) · Me (#17).')
      + navblock('Owner · unchanged', NAV_O, 'Today · Beds · Add tenant · Rent · Manage')
      + '</div>')
W['f26-tabs.dc.html'] = board('f26-tabs.dc.html', '[F26 #13 #14 #16 #17] Tab bars: tenant, resident, owner', [col('after', 'The three tab bars. Only the resident one changes.', ph(tb), label='Tab bars')])
print(W)

# ================= Cover (Main.dc.html): the 20 changes → boards
CH = [(1, 'Search: map pin inside the field; one row Near me · Price ↑ · Filters', 'Explore'), (2, 'Near me ↔ Pick a place; sort dropdown; Men/Women/AC/Food inside Filters; Featured on top', 'Explore'),
      (3, 'Building view inline, open to everyone (80+ beds: See all N rooms)', 'Hostel page · 80+ beds'), (4, 'Week table always open, today highlighted, no toggle', 'Hostel page · Resident Home'),
      (5, '✓ VERIFIED (navy) only after a team visit + “checked” line', 'Hostel page'), (6, 'Tag boxes removed (none on Explore cards today)', 'Hostel page'),
      (7, 'Contact locked until a hold, then WhatsApp + Call; Enquiries gone', 'Contact · Hostel page · Holds · Owner Today'), (8, 'Pick a bed: no tabs, floor chips, every room’s drawn layout, Edit this layout', 'Pick a bed'),
      (9, 'Holds: steps, red dot, “Still waiting. Call the owner?”', 'Holds'), (10, 'Me: no Saved or Holds rows', 'Me'), (11, 'Me: Log out in red', 'Me'),
      (12, 'Room layout: Edit this layout → try mode (“Only residents can send a fix”)', 'Room layout'), (13, 'Resident: no Food tab, week table on Home', 'Resident Home · Tab bars'),
      (14, 'Resident: My stay tab, Help inside', 'My stay · Tab bars'), (15, 'Resident tab bar has no Holds (holds live in the tenant app, #17)', 'Tab bars'),
      (16, 'Hold result push (exists) + red dot', 'Holds · Tab bars'), (17, 'Find a bed opens the tenant app: Saved & Holds tab, My stay tab back', 'Find a bed · Tab bars'),
      (18, 'Owner Today: Holds · Payments · Fixes, Fair Play pinned', 'Owner Today'), (19, 'Owner Beds: Building view only', 'Owner Beds'), (20, 'Owner Rent: Paid green, Late red, Due plain; Call + WhatsApp', 'Owner Rent'), (21, 'UNVERIFIED listings: grey badge, rent range, Tell me when verified', 'Unverified')]
rows = ''.join('<tr><td style="padding: 9px 12px; border-bottom: 1px solid rgba(32,30,29,.16); font-weight: 800; width: 56px;">#%d</td><td style="padding: 9px 12px; border-bottom: 1px solid rgba(32,30,29,.16);">%s</td><td style="padding: 9px 12px; border-bottom: 1px solid rgba(32,30,29,.16); color: #605d5d;">%s</td></tr>' % c for c in CH)
cover = rd('holds.dc.html')
cover = title(cover, 'F26 proposal: the 21 changes')
i = cover.index('<div data-hz'); j = cover.rindex('</div>\n</x-dc>') + 6
cover = cover[:i] + ('<div style="width: 1280px; height: 1240px; box-sizing: border-box; padding: 56px 64px; background: #ffffff; color: #201e1d; font-family: Archivo, system-ui, sans-serif; display: grid; gap: 20px; align-content: start;">'
    '<span style="font-size: 13px; font-weight: 800; letter-spacing: .1em; text-transform: uppercase; color: #ae1800;">Proposal · not in the app yet</span>'
    '<b style="font-size: 64px; line-height: 1; letter-spacing: -.03em;">F26 · Founder review 1 + 2</b>'
    '<span style="font-size: 18px; line-height: 1.45; max-width: 900px;">21 changes from the founder’s prototype review. Each board shows the screen <b>before</b> (in the app now) next to the <b>after</b>. Dark boards for Owner Today, Resident Home and the Hostel page. The main canvas changes only after the founder approves.</span>'
    '<div style="display: flex; gap: 12px; align-items: center; font-size: 14px;"><span style="padding: 4px 8px; font-size: 12px; font-weight: 800; letter-spacing: .08em; text-transform: uppercase; border: 2px solid #605d5d; color: #605d5d;">Before · in the app now</span><span style="padding: 4px 8px; font-size: 12px; font-weight: 800; letter-spacing: .08em; text-transform: uppercase; background: #201e1d; color: #f3f2f2; border: 2px solid #201e1d;">After · F26 proposal</span><span style="display: inline-flex; gap: 4px; align-items: center; padding: 4px 8px; background: #1f3a5f; color: #ffffff; font-size: 11px; font-weight: 800; letter-spacing: .08em;">' + ico('check', 12) + 'VERIFIED</span><span>badge colour: navy #1f3a5f</span></div>'
    '<table style="width: 100%; border-collapse: collapse; font-size: 15px; border-top: 2px solid #201e1d;"><thead><tr><th style="text-align: left; padding: 9px 12px; font-size: 12px; letter-spacing: .08em; text-transform: uppercase; color: #605d5d; border-bottom: 2px solid #201e1d;">#</th><th style="text-align: left; padding: 9px 12px; font-size: 12px; letter-spacing: .08em; text-transform: uppercase; color: #605d5d; border-bottom: 2px solid #201e1d;">Change</th><th style="text-align: left; padding: 9px 12px; font-size: 12px; letter-spacing: .08em; text-transform: uppercase; color: #605d5d; border-bottom: 2px solid #201e1d;">Board</th></tr></thead><tbody>' + rows + '</tbody></table>'
    '</div>') + cover[j:]
cover = cover.replace('"$preview": {"width": 390, "height": 844}', '"$preview": {"width": 1280, "height": 1240}')
save('Main.dc.html', cover)
W['Main.dc.html'] = (1280, 1240)

# ================= canvas.json
LAYOUT = [('Tenant', ['f26-explore.dc.html', 'f26-unverified.dc.html', 'f26-hostel.dc.html', 'f26-hostelDark.dc.html', 'f26-contact.dc.html']),
          ('Tenant, continued', ['f26-pick.dc.html', 'f26-locked.dc.html', 'f26-holds.dc.html', 'f26-me.dc.html', 'f26-room.dc.html']),
          ('Resident', ['f26-tabs.dc.html', 'f26-home.dc.html', 'f26-homeDark.dc.html', 'f26-stay.dc.html', 'f26-findbed.dc.html']),
          ('Owner', ['f26-today.dc.html', 'f26-todayDark.dc.html', 'f26-beds.dc.html', 'f26-rent.dc.html'])]
def btitle(f):
    return re.search(r'<title>(.*?)</title>', open(Q + f).read()).group(1)
boards = {'Main.dc.html': {'x': 0, 'y': 0, 'w': 1280, 'h': 1240, 'title': 'F26 proposal · the 21 changes'}}
order = ['Main.dc.html']
notes = {}
y = 1240 + 420
for n, (name, fs) in enumerate(LAYOUT):
    x = 0
    hmax = 0
    for f in fs:
        w, hh = W[f]
        t = btitle(f)
        if f.endswith('Dark.dc.html') and '[dark]' not in t:
            t += ' [dark]'
        boards[f] = {'x': x, 'y': y, 'w': w, 'h': hh, 'title': t}
        order.append(f)
        x += w + 80
        hmax = max(hmax, hh)
    notes['row%d' % n] = {'x': 0, 'y': y - 300, 'text': name, 'kind': 'title1', 'maxW': x - 80}
    y += hmax + 420
cj = {'v': 3, 'createdOnFiles': {'v': 1, 'at': '2026-10-05T19:40:00Z'}, 'title': 'Hostelzy · F26 proposal', 'launch': {'view': 'canvas'}, 'pages': [], 'boards': boards, 'order': order, 'notes': notes, 'designSystems': []}
json.dump(cj, open(Q + 'canvas.json', 'w'), ensure_ascii=False, indent=1)
print(len(boards), [b['title'] for b in boards.values()])
