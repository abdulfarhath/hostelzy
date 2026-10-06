import json, re, os
SP = '/tmp/claude-0/-home-user-hostelzy/58cdc0a8-c7d4-5e26-828b-40f705b32de2/scratchpad/'
exec(open(SP + 'm26.py').read())
D = SP + 'delta26/project/'
r = json.load(open(D + 'canvas.json'))
rb = r['boards']
cbase = rd('f24-cLayoutHelp.dc.html')
add = []
def put2(name, s): open(D + name, 'w').write(s)
# H45 complaint
chips = '<div style="display: flex; gap: 6px; flex-wrap: wrap;">' + ''.join(chip(c, c == 'Water') for c in ['Wi-Fi', 'Water', 'Electricity', 'Cleaning', 'Food', 'Other']) + '</div>'
ta = '<textarea aria-label="What’s wrong" placeholder="What’s wrong? Where, and since when." style="width: 100%; height: 84px; padding: 10px 12px; border: 2px solid var(--tx); background: var(--bg); font: inherit; font-size: 15px; resize: none;">Low pressure in bathroom 2 in the mornings.</textarea>'
h45rows = ['<div style="padding: 14px 16px 0; display: grid; gap: 10px;">' + chips + ta + '</div>']
h45 = ph(stay_body, nav_res('My stay'))
k = h45.rindex('</div>')
h45 = h45[:k] + sheet(kick('Help · Anjani Residency'), 'Something wrong in your room?', h45rows, ['<div style="display: grid; grid-template-columns: 56px minmax(0, 1fr); gap: 8px;"><button aria-label="Add a photo" style="height: 52px; display: grid; place-items: center; border: 2px solid var(--tx);">' + ico('plus', 20) + '</button>' + btn('Send to owner', 'red', 'arrow') + '</div>']) + h45[k:]
put2('f26-h45.dc.html', single('[H45] complaint sheet · Something wrong in your room?: category, text, photo, Send to owner · New (F26)', h45)); add.append('f26-h45.dc.html')
# H46 complaints
def crow(t, st, kind, txt, when):
    return '<div style="padding: 12px 16px; border-bottom: 1px solid var(--hl); display: grid; gap: 4px;"><span style="display: flex; justify-content: space-between; align-items: center;"><b style="font-size: 16px;">%s</b>%s</span><span style="font-size: 14px;">%s</span><span style="font-size: 12px; color: var(--mu);">%s</span></div>' % (t, tag(st, kind), txt, when)
h46rows = [crow('Water', 'Sent', 'red', 'Low pressure in bathroom 2 in the mornings.', 'Just now · Srinivas sees it in the app') + crow('Geyser', 'Being fixed', 'ink', 'No hot water since Monday.', '28 Sep · “Plumber on Tuesday”') + crow('Wi-Fi', 'Fixed', 'mu', 'Drops after 11 pm.', '20 Sep · Router replaced')]
h46 = ph(stay_body, nav_res('My stay'))
k = h46.rindex('</div>')
h46 = h46[:k] + sheet(kick('Help · Anjani Residency'), 'Your complaints', h46rows, [btn('Something wrong in your room?', 'out', 'plus', 48, 15)]) + h46[k:]
put2('f26-h46.dc.html', single('[H46] complaints sheet · Your complaints: Sent / Being fixed / Fixed · New (F26)', h46)); add.append('f26-h46.dc.html')
# H47 claim
def fld(l, v):
    return '<label style="display: grid; gap: 6px; font-size: 13px; font-weight: 800;">%s<input value="%s" style="width: 100%%; min-width: 0; height: 48px; padding: 0 12px; border: 2px solid var(--tx); background: var(--bg); font-size: 15px; font-weight: 400;"></label>' % (l, v)
h47rows = ['<div style="padding: 14px 16px 0; display: grid; gap: 10px;">' + fld('Your name', 'Venkat Rao') + fld('Your phone (WhatsApp)', '+91 98490 11223') + mut('Our team calls you within 2 days to check you run this hostel. Then you can add beds, prices and rooms.', 13) + '</div>']
h47 = ph(upage)
k = h47.rindex('</div>')
h47 = h47[:k] + sheet(kick('Claim Sri Balaji Men’s PG'), 'Are you the owner?', h47rows, [btn('Send to Hostelzy', 'red', 'arrow')]) + h47[k:]
put2('f26-h47.dc.html', single('[H47] claim sheet · Are you the owner? name, phone, Send to Hostelzy · New (F26)', h47)); add.append('f26-h47.dc.html')
# Console C14 / C15
ASIDE_END = 'Hostels</a></aside>'
def navlink(t, on):
    return '<a href="#" style="height: 48px; padding: 0 20px; display: flex; align-items: center; font-size: 15px; font-weight: 600; text-decoration: none; %s">%s</a>' % ('color: var(--tx); background: var(--sf); box-shadow: inset 4px 0 0 var(--ac);' if on else 'color: var(--mu);', t)
def cons(tt, main, sel):
    s = title(cbase, tt)
    s = s.replace('color: var(--tx); background: var(--sf); box-shadow: inset 4px 0 0 var(--ac);">Layout help', 'color: var(--mu);">Layout help')
    s = s.replace(ASIDE_END, 'Hostels</a>' + navlink('Listed', sel == 'Listed') + navlink('Claims', sel == 'Claims') + '</aside>')
    i = s.index('<main'); j = s.index('</main>') + 7
    return s[:i] + main + s[j:]
cth = 'padding: 10px 12px; font-size: 12px; font-weight: 800; letter-spacing: .08em; text-transform: uppercase; color: var(--mu); text-align: left; border-bottom: 2px solid var(--tx);'
ctd = 'padding: 12px; font-size: 14px; border-bottom: 1px solid var(--hl); vertical-align: middle;'
def ctable(heads, rows):
    return '<table style="width: 100%; border-collapse: collapse;"><thead><tr>' + ''.join('<th style="%s">%s</th>' % (cth, h) for h in heads) + '</tr></thead><tbody>' + ''.join('<tr>' + ''.join('<td style="%s">%s</td>' % (ctd, c) for c in row) + '</tr>' for row in rows) + '</tbody></table>'
sbtn = lambda t, kind='out': '<button style="height: 36px; padding: 0 12px; font-size: 13px; font-weight: 800; white-space: nowrap; %s">%s</button>' % ({'out': 'border: 2px solid var(--tx);', 'red': 'background: var(--ac); color: var(--ai);', 'ink': 'background: var(--tx); color: var(--bg);'}[kind], t)
form = ('<div style="display: grid; gap: 12px; align-content: start;"><h2 style="margin: 0; font-size: 24px; font-weight: 800;">List a hostel</h2>' + mut('Shown as UNVERIFIED with an expected rent range. No beds, holds or owner contact until the team visits.', 13)
        + fld('Name', 'Sri Balaji Men’s PG') + fld('Area', 'Madhapur') + '<div style="display: grid; gap: 6px;"><b style="font-size: 13px;">For</b>' + seg(['Men', 'Women', 'Co-living'], 'Men') + '</div>'
        + '<div style="display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 8px;">' + fld('Rent from (₹)', '7,000') + fld('Rent to (₹)', '9,000') + '</div>'
        + '<button style="height: 48px; border: 2px dashed var(--dv); font-weight: 800;">+ Add photos (4 added)</button>' + btn('List it', 'red', 'arrow') + '</div>')
listed = ctable(['Hostel', 'Area', 'Rent range', 'Photos', 'Waiting', 'Status', ''], [
    ['<b>Sri Balaji Men’s PG</b>', 'Madhapur', '₹7,000–9,000', '4', '17 want a ping', tag('Listed'), sbtn('Take off')],
    ['<b>Lakshmi Ladies Hostel</b>', 'Kondapur', '₹6,500–8,500', '6', '9', tag('Listed'), sbtn('Take off')],
    ['<b>Orchid Grand Men’s PG</b>', 'Madhapur', '—', '12', '—', tag('Live', 'ink'), ''],
])
main14 = '<main style="min-width: 0; padding: 20px 24px; display: grid; grid-template-columns: 420px minmax(0, 1fr); gap: 24px; align-content: start;">' + form + '<div style="display: grid; gap: 12px; align-content: start;"><h2 style="margin: 0; font-size: 24px; font-weight: 800;">Listed in Madhapur · 72 unverified · 12 live</h2>' + listed + '</div></main>'
put2('f26-c14.dc.html', cons('[C14] console · Listed: list a hostel as UNVERIFIED, photos, List it / Take off, waitlist · New (F26)', main14, 'Listed')); add.append('f26-c14.dc.html')
claims = ctable(['Hostel', 'Says they are', 'Phone', 'Sent', ''], [
    ['<b>Sri Balaji Men’s PG</b><br><span style="font-size: 12px; color: var(--mu);">Madhapur · unverified</span>', 'Venkat Rao', '+91 98490 11223', 'Today, 9:40 am', '<span style="display: flex; gap: 6px; flex-wrap: wrap;">' + sbtn('Call') + sbtn('WhatsApp') + sbtn('Done', 'ink') + sbtn('Not the owner') + '</span>'],
    ['<b>Lakshmi Ladies Hostel</b><br><span style="font-size: 12px; color: var(--mu);">Kondapur · unverified</span>', 'Padma K.', '+91 99080 44551', 'Yesterday', '<span style="display: flex; gap: 6px; flex-wrap: wrap;">' + sbtn('Call') + sbtn('WhatsApp') + sbtn('Done', 'ink') + sbtn('Not the owner') + '</span>'],
])
main15 = '<main style="min-width: 0; padding: 20px 24px; display: grid; gap: 14px; align-content: start;"><h2 style="margin: 0; font-size: 24px; font-weight: 800;">Claims · 2 open</h2>' + mut('Owners who tapped “Claim this hostel”. Call to check, then Done starts onboarding. Not the owner closes it.', 14) + claims + '</main>'
put2('f26-c15.dc.html', cons('[C15] console · Claims: Call / WhatsApp / Done / Not the owner · New (F26)', main15, 'Claims')); add.append('f26-c15.dc.html')
# console nav on the other console boards
navfix = []
for name, b in rb.items():
    t = b.get('title', '')
    if 'archive' in t or not os.path.exists(P + name): continue
    s = open(D + name).read() if os.path.exists(D + name) else rd(name)
    if ASIDE_END in s and '<header' in s:
        s = s.replace(ASIDE_END, 'Hostels</a>' + navlink('Listed', False) + navlink('Claims', False) + '</aside>')
        put2(name, s); navfix.append(name)
        if 'F26 nav' not in t: b['title'] = t + ' · Updated (F26 nav)'
# positions: new row
ny = r['notes']['r26']['y'] + 300
x = max(v['x'] + v['w'] for v in rb.values() if v['y'] == ny) + 80
for name in add:
    if name in rb: continue
    w, h = (1440, 900) if name.startswith('f26-c1') else (390, 844)
    t = re.search(r'<title>(.*?)</title>', open(D + name).read()).group(1)
    rb[name] = {'x': x, 'y': ny, 'w': w, 'h': h, 'title': t}; r['order'].append(name); x += w + 80
r['notes']['r26']['text'] = 'F26 · New boards: S88, S89, H44–H47, T32, T33, C14, C15 + variants'
r['notes']['r26']['maxW'] = x
json.dump(r, open(D + 'canvas.json', 'w'), ensure_ascii=False, indent=1)
cnt = {'main': 0, 'variant': 0, 'dark': 0, 'not': 0, 'arch': 0}
for v in rb.values():
    t = v.get('title', '')
    if 'archive' in t: cnt['arch'] += 1
    elif t.startswith('[variant'): cnt['variant'] += 1
    elif t.startswith('[dark]'): cnt['dark'] += 1
    elif t.startswith('[not counted'): cnt['not'] += 1
    else: cnt['main'] += 1
print(len(rb), cnt, 'navfix', navfix, sorted(os.listdir(D)))
