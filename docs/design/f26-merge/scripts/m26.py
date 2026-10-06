import json, os, re, shutil
SP = '/tmp/claude-0/-home-user-hostelzy/58cdc0a8-c7d4-5e26-828b-40f705b32de2/scratchpad/'
exec(open(SP + 'f26.py').read())
M = SP + 'main26/project/'
os.makedirs(M, exist_ok=True)
C = json.load(open(SP + 'remote/project/canvas.json'))
B = C['boards']
SENT = []
def put(name, s):
    open(M + name, 'w').write(s)
    if name not in SENT:
        SENT.append(name)

def single(tt, pdiv, dark=False):
    s = rd('holds.dc.html')
    s = title(s, tt)
    s = s.replace('[data-hz] *{box-sizing:border-box}', VF + '[data-hz] *{box-sizing:border-box}', 1)
    i = s.index('<div data-hz'); j = s.rindex('</div>\n</x-dc>') + 6
    s = s[:i] + pdiv + s[j:]
    if dark:
        s = s.replace('{"dark": {"editor": "boolean", "default": false}', '{"dark": {"editor": "boolean", "default": true}').replace('(this.props.dark ?? false)', '(this.props.dark ?? true)')
    return s

archive = []   # (name, title, w, h)
def to_archive_copy(name, why):
    """keep the pre-F26 design as an archive copy"""
    z = 'z26-' + name
    put(z, rd(name))
    archive.append((z, '[archive · not counted] before F26 · ' + why, B[name]['w'], B[name]['h']))

def update(name, tt, pdiv, dark=False):
    old = B[name]['title']
    to_archive_copy(name, old.split('] ', 1)[-1][:90])
    put(name, single(tt, pdiv, dark))
    B[name]['title'] = tt

def retire(name, why):
    t = B[name]['title']
    archive.append((name, '[archive · not counted] retired by F26 · was ' + t.split(' · ')[0] + ' ' + (t.split('] ', 1)[-1].split(' · ')[0]) + ' → ' + why + ' · Removed', B[name]['w'], B[name]['h']))

U = ' · Updated (F26)'
# ---------- Updated main boards (same SCREENS id)
update('r-explore.dc.html', '[S8] explore · Map pin in search; one row Near me · Price ↑ · Filters; Featured on top' + U, phone_div(after2))
update('r-exploreDark.dc.html', '[dark] explore · Explore (dark)' + U, phone_div(after2), True)
update('r-filters.dc.html', '[H1] filters sheet · Men / Women / Co-living / AC / Food / Rent' + U, phone_div(filters_open))
update('r-detail.dc.html', '[S13] detail · ✓ VERIFIED (navy) + “checked” line; no tag boxes' + U, phone_div(dnew))
update('r-detailDark.dc.html', '[dark] detail · Hostel page (dark)' + U, phone_div(dnew), True)
update('f24-detailOwner.dc.html', '[variant of S13] detail · Owner contact locked before a hold' + U, lock_ph)
update('picker.dc.html', '[S16] picker · No tabs: floor chips, every room’s drawn layout, Edit this layout' + U, phone_div(pick2))
update('f23-Room.dc.html', '[S17] detail · Room · Edit this layout → try mode' + U, room_after)
update('f19-Lock.dc.html', '[H13] fix sheet · Only residents can send a fix. Book a bed to join.' + U, phone_div(try_e))
update('holds.dc.html', '[S11] holds · Steps Sent → Owner reviewing → Kept / Declined; “Still waiting. Call the owner?”; red dot' + U, ph(holds_head + '<div style="flex-grow: 1; overflow: hidden; border-top: 2px solid var(--tx);">' + waiting + '</div>', nav_hold))
update('me.dc.html', '[S79] me · No Saved / Holds rows; Log out in red' + U, phone_div(me_after))
update('r-home.dc.html', '[S23] rHome · Week table always open; tabs Home · Rent · My stay · Find a bed · Me' + U, phone_div(home2))
update('r-today.dc.html', '[S36] oToday · Holds · Payments · Fixes with counts; Fair Play pinned' + U, ph(grp, NAV_O))
update('r-todayDark.dc.html', '[dark] oToday · Today (dark)' + U, ph(grp, NAV_O), True)
update('beds.dc.html', '[S37] oBeds · Building view only; tap a bed → bed sheet, a room → its layout' + U, phone_div(beds_after))
update('beds-dark.dc.html', '[dark] oBeds · Beds (dark)' + U, phone_div(beds_after), True)
update('oRent.dc.html', '[S38] oRent · Paid green, Late red, Due plain; Call + WhatsApp' + U, phone_div(rent_after))
update('oRent-dark.dc.html', '[dark] oRent · Rent (dark)' + U, phone_div(rent_after), True)

I['copy'] = '<path d="M8 8h12v12H8z"/><path d="M4 16V4h12"/>'
# S12: same screen, new role
B['add-whereFull.dc.html']['title'] = '[S12] where · Pick a place (tap Near me ✓ again, or the search bar) · real app screenshot · Updated (F26)'
B['where-dark.dc.html']['title'] = '[dark] where · Pick a place · real app screenshot (dark) · Updated (F26)'
# S32 try mode (non-resident) as a variant
tm = rd('f19-Edit.dc.html')
tm = tm.replace('Edit room · ', 'Try a layout · ', 1)
tm = re.sub(r'Suggestion · you live in 204 · draft saved on this phone', 'Try mode · only on this phone', tm, count=1)
tm = tm.replace('Only you see this until you send it', 'Move things to see how the room works for you', 1)
tm = tm.replace('Send to owner', 'Publish', 1)
tm = tm.replace('<path d="M5 11h14v10H5z"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/>', '<path d="M17 3l4 4L8 20H4v-4z"/>', 1)
# H6: Message <name>
wa_body = ('<div style="padding: 14px 16px 0; display: grid; gap: 6px;">' + kick('Your message') + '<div style="padding: 12px; border: 2px solid var(--tx); font-size: 15px; line-height: 1.45;">Hi Srinivas, the geyser in room 204 isn’t working since Monday. Can someone check it today? · Rahul, bed 204-B</div></div>')
wa_ph = phone_div(home2)
k = wa_ph.rindex('</div>')
wa_ph = wa_ph[:k] + sheet(kick('WhatsApp'), 'Message Srinivas', [wa_body], [btn('Open WhatsApp', 'red', 'msg', 48, 15), btn('Copy', 'out', 'copy', 48, 15)]) + wa_ph[k:]
# ---------- Retired (to the archive row)
retire('food.dc.html', 'week table on Home (S23)')
retire('w2-foodWeek.dc.html', 'week table on Home (S23)')
retire('w3-foodNoMenu.dc.html', 'no Food tab')
retire('new-foodWeek.dc.html', 'week table on the hostel page (S13)')
retire('r-help.dc.html', 'Help inside My stay (S28)')
retire('w2-pickerList.dc.html', 'no cheapest-first list; every room in one scroll (S16)')
update('w4-building.dc.html', '[S87] building · Whole building page: from the hostel page and 80+ bed hostels (no longer a picker tab)' + U, ph(head('Anjani Residency', 'Whole building') + scrollpage(bview()) ))
retire('stay.dc.html', 'S89 My stay tab')
retire('w3-roomSignIn.dc.html', 'layouts open to everyone, guests too')
retire('w2-floorLocked.dc.html', 'no locks: layouts open to everyone')
retire('w3-roomCapped.dc.html', 'no locks: layouts open to everyone')
retire('f24-oEnquiries.dc.html', 'enquiries removed')
retire('enquiry.dc.html', 'enquiries removed')
retire('w4-oBedsBuilding.dc.html', 'S37 is the Building view now')
retire('f14-Visited.dc.html', '✓ VERIFIED badge on S13')
retire('f23-Main.dc.html', 'Building view inline on S13')
retire('new-foodPeek.dc.html', 'week table always open on S13')

# ---------- New boards (ids proposed to Build; counted once Build's SCREENS PR lands)
NEW = []
def new(name, tt, pdiv, dark=False):
    put(name, single(tt, pdiv, dark)); NEW.append((name, tt))
new('f26-savedHolds.dc.html', '[S88] savedHolds · Saved & Holds (resident in Find a bed): one tab, two segments · New (F26)', ph(sh, nav_rt('Saved & Holds')))
new('f26-unverified.dc.html', '[T32] detail · Unverified listing: rent range, Tell me when verified, Claim · New (F26)', ph(upage))
new('f26-myStay.dc.html', '[S89] myStay · My stay tab: bed, move, notice, refund, review, layout fix, Help · New (F26)', ph(stay_body, nav_res('My stay')))
_sort = ''.join('<div style="display: flex; justify-content: space-between; align-items: center; padding: 14px 16px; border-bottom: 1px solid var(--hl); font-size: 16px; font-weight: %s;">%s%s</div>' % ('800' if on else '600', t, ico('check', 20) if on else '') for t, on in [('Price, lowest first', True), ('Distance', False), ('Rating', False), ('Best deals', False)])
new('f26-sort.dc.html', '[H44] sort sheet · Price ↑ · Distance · Rating · Best deals · New (F26)', after2[after2.index('<div data-hz'):after2.rindex('</div>\n</x-dc>')] + sheet(kick('Sort'), 'Show first', [_sort], []) + '</div>')
new('f26-tryMode.dc.html', '[variant of S32] rFix · Try mode (not a resident): Try a layout, Publish → H13 · New (F26)', phone_div(tm))
update('wa.dc.html', '[H6] wa sheet · Message <name>: message text, Open WhatsApp, Copy (owner ↔ resident, layout fix) · Updated (F26)', wa_ph)
new('f26-todayEmpty.dc.html', '[T33] oToday · Nothing needs you now · New (F26)', ph(grp_empty, NAV_O))
new('f26-exploreRes.dc.html', '[variant of S8] explore · Resident in Find a bed: Explore · Map · Saved & Holds · My stay · Me · New (F26)', phone_div(re.sub(r'<nav.*?</nav>', lambda m: nav_rt('Explore'), after2, count=1, flags=re.S)))
new('f26-exploreUnv.dc.html', '[variant of S8] explore · Verified first in a price band, UNVERIFIED card with a rent range · New (F26)', phone_div(list_ph))
new('f26-detailScroll.dc.html', '[variant of S13] detail · Scrolled: Building view inline, week table, contact locked · New (F26)', ph(page_head('Scrolled down') + scrollpage(bview() + food_new() + rules_row() + '<div style="padding: 16px 16px 0;">' + avail() + '</div>' + contact_locked()) + topbar_from()))
new('f26-detailBig.dc.html', '[variant of S13] detail · 80+ beds: See all 38 rooms › · New (F26)', og)
new('f26-contactOpen.dc.html', '[variant of S13] detail · After a hold: number, WhatsApp (HZ code) + Call · New (F26)', open_ph)
new('f26-holdsKept.dc.html', '[variant of S11] holds · Kept: WhatsApp + Call · New (F26)', ph(holds_head + '<div style="flex-grow: 1; overflow: hidden; border-top: 2px solid var(--tx);">' + kept + '</div>', nav_hold))
new('f26-holdsDeclined.dc.html', '[variant of S11] holds · Declined: contact locks again · New (F26)', ph(holds_head + '<div style="flex-grow: 1; overflow: hidden; border-top: 2px solid var(--tx);">' + declined + '</div>', nav_hold))
new('f26-homeDark.dc.html', '[dark] rHome · Home (dark) · New (F26)', phone_div(home2), True)

# ---------- Resident tab bar on every other resident board
TOUCH = set(SENT) | {n for n, *_ in archive}
oldnav = re.compile(r'<nav[^>]*>(?:(?!</nav>).)*?>Food</button>(?:(?!</nav>).)*?>Help</button>(?:(?!</nav>).)*?</nav>', re.S)
NAVFIX = []
MAPSEL = {'Home': 'Home', 'Food': 'Home', 'Pay rent': 'Rent', 'Help': 'My stay', 'Me': 'Me'}
for name, b in B.items():
    if name in TOUCH or 'archive' in b.get('title', '') or not os.path.exists(P + name):
        continue
    s = rd(name)
    if not oldnav.search(s):
        continue
    def fix(m):
        n = m.group(0)
        sel = re.search(r'box-shadow: inset 0 3px 0 var\(--ac\);"><svg.*?</svg>([^<]+)</button>', n, re.S)
        on = MAPSEL.get(sel.group(1).strip()) if sel else ('Rent' if ('[S26]' in b['title'] or 'rPay' in b['title']) else None)
        return nav_res(on)
    s2 = oldnav.sub(fix, s)
    put(name, s2)
    if '(F26 tab bar)' not in b['title']:
        b['title'] = b['title'] + ' · Updated (F26 tab bar)'
    NAVFIX.append(name)

# ---------- layout: new row + archive row at the bottom
bottom = max(v['y'] + v['h'] for v in B.values())
y_new = bottom + 420
C['notes']['r26'] = {'kind': 'title1', 'maxW': 6000, 'text': 'F26 · New boards (founder review 1 + 2) · S88, T32, T33 + variants', 'w': 240, 'x': 0, 'y': y_new - 300}
x = 0
for name, tt in NEW:
    B[name] = {'x': x, 'y': y_new, 'w': 390, 'h': 844, 'title': tt}
    C['order'].append(name)
    x += 470
y_arch = y_new + 844 + 420
C['notes']['arch_f26'] = {'kind': 'title1', 'maxW': 8000, 'text': 'Archive · F26: boards before the founder review, and boards it retired', 'w': 240, 'x': 0, 'y': y_arch - 300}
x = 0
for name, tt, w, h in archive:
    if name not in B:
        B[name] = {}
        C['order'].append(name)
    B[name].update({'x': x, 'y': y_arch, 'w': w, 'h': h, 'title': tt})
    x += w + 80
json.dump(C, open(M + 'canvas.json', 'w'), ensure_ascii=False, indent=1)

# ---------- counts
cnt = {'main': 0, 'variant': 0, 'dark': 0, 'not': 0, 'arch': 0}
for k, v in B.items():
    t = v.get('title', '')
    if 'archive' in t: cnt['arch'] += 1
    elif t.startswith('[variant'): cnt['variant'] += 1
    elif t.startswith('[dark]'): cnt['dark'] += 1
    elif t.startswith('[not counted'): cnt['not'] += 1
    elif re.match(r'\[[SHTCW]\d+\]', t): cnt['main'] += 1
    else: print('??', k, t[:60])
print(cnt, 'sent', len(SENT), 'navfix', len(NAVFIX), NAVFIX)
