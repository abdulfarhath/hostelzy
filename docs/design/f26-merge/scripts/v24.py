import json, re, os
SP = '/tmp/claude-0/-home-user-hostelzy/58cdc0a8-c7d4-5e26-828b-40f705b32de2/scratchpad/'
O = SP + 'full24/project/'
c = json.load(open(O + 'canvas.json')); B = c['boards']
base = json.load(open(SP + 'remote/project/canvas.json'))['boards']
def rd(n): return open(O + n).read()
def wr(n, s): open(O + n, 'w').write(s)
def tit(n, t): B[n]['title'] = t
changed = set()
def sub(n, a, b, count=1, rx=False):
    s = rd(n)
    s2, k = (re.subn(a, b, s) if rx else (s.replace(a, b), s.count(a)))
    assert k >= count, (n, a[:50], k)
    wr(n, s2); changed.add(n)
R24 = ' · Updated (F26 revert)'
# 1 S18 back
pl = rd('w2-pickerList.dc.html')
m = re.search(r'<div style="display: grid; grid-template-columns: repeat\(2, minmax\(0, 1fr\)\);[^"]*"><button[^>]*>Plan</button><button[^>]*>Room</button></div>', pl)
pl = pl.replace(m.group(0), '<div style="padding: 0 16px 8px;"><a href="#" style="font-size: 14px; font-weight: 800; color: var(--ad); text-decoration: none;">‹ Back to the plan</a></div>')
wr('w2-pickerList.dc.html', pl); changed.add('w2-pickerList.dc.html')
o = base['w2-pickerList.dc.html']; B['w2-pickerList.dc.html'].update({'x': o['x'], 'y': o['y']})
tit('w2-pickerList.dc.html', '[S18] picker · List, cheapest first; ‹ Back to the plan' + R24)
# S16: legend + See cheapest beds
leg = ('<div style="flex: none; padding: 8px 16px; display: flex; justify-content: space-between; align-items: center; font-size: 12px; color: var(--mu); border-top: 1px solid var(--hl);"><span>□ Free · ▨ On hold · ■ Taken</span>'
       '<a href="#" style="font-size: 13px; font-weight: 800; color: var(--tx);">See cheapest beds ›</a></div>')
s = rd('picker.dc.html'); k = s.index('<div style="flex: none; border-top: 2px solid var(--tx); padding: 12px 16px; display: grid;')
wr('picker.dc.html', s[:k] + leg + s[k:]); changed.add('picker.dc.html')
tit('picker.dc.html', B['picker.dc.html']['title'].replace(' · Updated (F26)', '') + '; See cheapest beds ›' + R24)
# 4, 5, 12 Explore (every board that draws the new Explore)
for n in os.listdir(O):
    if not n.endswith('.dc.html'): continue
    s = rd(n); s0 = s
    s = s.replace('Madhapur · 12 verified · 84 listed', 'Hyderabad · 18 beds free now · 12 verified · 84 listed')
    s = re.sub(r'<div style="padding: 0 16px 8px;"><span[^>]*>(Then by price, lowest first|₹7,000–9,000 · verified first)</span></div>', '', s)
    s = s.replace('>Lowest price</span>', '>#1 near you</span>')
    s = s.replace('font-weight: 800; white-space: nowrap; display: flex; gap: 6px; align-items: center; border: 2px solid var(--tx); color: var(--tx);">Price ↑<svg', 'font-weight: 800; white-space: nowrap; display: flex; gap: 6px; align-items: center; border: 2px solid var(--tx); color: var(--tx);">Distance<svg')
    if s != s0: wr(n, s); changed.add(n)
# H44 sort: Distance chosen when location is on
s = rd('f26-sort.dc.html')
chk = re.search(r'Price, lowest first(<svg.*?</svg>)', s, re.S).group(1)
s = s.replace('font-weight: 800;">Price, lowest first' + chk, 'font-weight: 600;">Price, lowest first')
s = s.replace('font-weight: 600;">Distance</div>', 'font-weight: 800;">Distance' + chk + '</div>')
assert s.count(chk) == 1
wr('f26-sort.dc.html', s); changed.add('f26-sort.dc.html')
# 2, 3 H1 Filters: main's sheet without the Sort by group, over the new Explore
old = open(SP + 'canvas/project/r-filters.dc.html').read()
SH = '<div style="position: absolute; inset: 0; display: flex; flex-direction: column; background: rgba(20,18,17,.55);">'
sheet_html = old[old.index(SH):old.rindex('</div>\n</x-dc>')]
sheet_html = re.sub(r'<b[^>]*>Sort by</b><div[^>]*>(?:<button[^>]*>[^<]*</button>)+</div>', '', sheet_html)
assert 'Sort by' not in sheet_html and 'Any</button>' in sheet_html
ex = rd('r-explore.dc.html')
k = ex.rindex('</div>\n</x-dc>')
f = rd('r-filters.dc.html')
i = f.index('<div data-hz'); j = f.rindex('</div>\n</x-dc>') + 6
ex_div = ex[ex.index('<div data-hz'):k]
wr('r-filters.dc.html', f[:i] + ex_div + sheet_html + '</div>' + f[j:]); changed.add('r-filters.dc.html')
tit('r-filters.dc.html', '[H1] filters sheet · For, Room, Budget (Any), Food included; sort lives in Price ↑ / Distance' + R24)
# 6 hostel page: ₹100 line under the lock line until a hold
lock = 'Message and call the owner after you hold a bed</b></div>'
for n in os.listdir(O):
    if n.endswith('.dc.html') and lock in rd(n):
        sub(n, lock, lock + '<div style="padding: 0 12px 10px; font-size: 13px; line-height: 1.45; color: var(--mu);">Talking through Hostelzy keeps your deal and your ₹100 reward.</div>')
# 9 Confirm hold
for n in ['r-today.dc.html', 'r-todayDark.dc.html']:
    sub(n, '>Confirm<svg', '>Confirm hold<svg', 2)
    tit(n, B[n]['title'].replace('Holds · Payments · Fixes', 'Holds · Payments · Fixes; Confirm hold'))
# 10 Beds: Rooms and rates
for n in ['beds.dc.html', 'beds-dark.dc.html']:
    sub(n, 'to create or copy one.</span>', 'to create or copy one.</span><a href="#" style="font-size: 14px; font-weight: 800; color: var(--tx); min-height: 44px; display: flex; align-items: center;">Rooms and rates ›</a>')
    tit(n, B[n]['title'] + '; Rooms and rates ›' if 'Rooms and rates' not in B[n]['title'] else B[n]['title'])
# 11 try mode + H13
for n in ['f26-tryMode.dc.html', 'f19-Lock.dc.html']:
    s = rd(n)
    s = s.replace('Try a layout · ', 'Edit room · ').replace('Try mode · only on this phone', 'You don’t live here · leaving discards your try').replace('Move things to see how the room works for you', 'Try mode · play freely, nothing is saved')
    wr(n, s); changed.add(n)
s = rd('f19-Lock.dc.html')
s = s.replace('Book a bed to join. Your tries stay on this phone.', 'Book a bed to join.')
s = re.sub(r'(<button[^>]*>)Pick a bed(<svg)', r'\1Book a bed\2', s, 1)
s = re.sub(r'(<button[^>]*>)Keep trying(</button>)', r'\1See beds\2', s, 1)
assert 'See beds' in s and 'Book a bed<svg' in s
wr('f19-Lock.dc.html', s)
tit('f19-Lock.dc.html', '[H13] fix sheet · Only residents can send a fix · Book a bed to join. · Book a bed / See beds' + R24)
tit('f26-tryMode.dc.html', '[variant of S32] rFix · Try mode: Edit room · Room N, play freely, nothing is saved; Publish → H13' + R24)
# F27 extras (variants): S39 Manage › Meals row, S80 Meals switch (resident)
s = rd('r-manage.dc.html') if os.path.exists(O + 'r-manage.dc.html') else None
json.dump(c, open(O + 'canvas.json', 'w'), ensure_ascii=False, indent=1)
cnt = {'main': 0, 'variant': 0, 'dark': 0, 'not': 0, 'arch': 0}
for v in B.values():
    t = v.get('title', '')
    if 'archive' in t: cnt['arch'] += 1
    elif t.startswith('[variant'): cnt['variant'] += 1
    elif t.startswith('[dark]'): cnt['dark'] += 1
    elif t.startswith('[not counted'): cnt['not'] += 1
    else: cnt['main'] += 1
print(len(B), cnt, sorted(changed))
