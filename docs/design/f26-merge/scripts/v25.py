import json, re, os, shutil
SP = '/tmp/claude-0/-home-user-hostelzy/58cdc0a8-c7d4-5e26-828b-40f705b32de2/scratchpad/'
src = open(SP + 'w3.py').read()
exec(src[:src.index('# --- Screen: oRules')])      # helpers; rd() reads the v24 boards (canvas/project = full24)
O = SP + 'full25/project/'
if os.path.exists(SP + 'full25'): shutil.rmtree(SP + 'full25')
shutil.copytree(SP + 'full24', SP + 'full25')
c = json.load(open(O + 'canvas.json')); B = c['boards']
NEW = []    # (name, title, w, h, row)
def put(name, s): open(O + name, 'w').write(s)
def new(name, tt, s, row, w=390, h=844):
    put(name, title(s, tt)); NEW.append((name, tt, w, h, row))
def upd(name, s, tt=None):
    put(name, s)
    if tt: B[name]['title'] = tt

I['phone'] = '<path d="M5 3h4l2 5-2.5 1.5a11 11 0 0 0 6 6L16 13l5 2v4a2 2 0 0 1-2 2A17 17 0 0 1 3 5a2 2 0 0 1 2-2"/>'
I['user'] = '<path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/>'
I['plusU'] = '<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M19 8v6M22 11h-6"/>'
I['camera'] = '<path d="M4 8h3l2-3h6l2 3h3v12H4z"/><circle cx="12" cy="13" r="3.5"/>'
I['image'] = '<path d="M3 5h18v14H3z"/><path d="m3 16 5-5 4 4 3-3 6 6"/><circle cx="16" cy="9" r="1.5"/>'
I['folder'] = '<path d="M3 6h7l2 2h9v12H3z"/>'
I['chevD'] = '<path d="m6 9 6 6 6-6"/>'
I['download'] = '<path d="M12 4v12M6 10l6 6 6-6M4 20h16"/>'
VF = '[data-hz]{--vf:#1f3a5f}[data-hz][data-theme="dark"]{--vf:#33598a}'
def single(tt, pdiv, dark=False):
    s = title(rd('holds.dc.html'), tt)
    s = s.replace('[data-hz] *{box-sizing:border-box}', VF + '[data-hz] *{box-sizing:border-box}', 1)
    i = s.index('<div data-hz'); j = s.rindex('</div>\n</x-dc>') + 6
    s = s[:i] + pdiv + s[j:]
    if dark:
        s = s.replace('{"dark": {"editor": "boolean", "default": false}', '{"dark": {"editor": "boolean", "default": true}').replace('(this.props.dark ?? false)', '(this.props.dark ?? true)')
    return s
def pdiv(s):
    i = s.index('<div data-hz'); j = s.rindex('</div>\n</x-dc>') + 6
    return s[i:j]
def ph(body, nav=None, h=844):
    d = pdiv(phone('x', body, nav))
    return d.replace('height: 844px;', 'height: %dpx;' % h, 1) if h != 844 else d
def add_sheet(board_div, sh):
    k = board_div.rindex('</div>')
    return board_div[:k] + sh + board_div[k:]
def navsel(nav, label):
    nav = plain_nav(nav)
    k = nav.index('</svg>' + label + '</button>'); b = nav.rindex('<button style="', 0, k); e = nav.index('">', b)
    seg_ = nav[b:e]
    if 'background: var(--ac)' in seg_: return nav
    return nav[:b] + seg_.replace('color: var(--mu);', 'color: var(--tx); box-shadow: inset 0 3px 0 var(--ac);') + nav[e:]
NAV_T, NAV_O, NAV_R = NAVS['tenant'], NAVS['owner'], NAVS['resident']
def hdr(k, t, right=''):
    return ('<div style="flex: none; padding: 12px 16px 12px; display: flex; justify-content: space-between; gap: 12px;"><div style="display: grid; gap: 4px;">' + kick(k)
            + '<b style="display: block; font-size: 32px; line-height: 1.02; letter-spacing: -.025em;">' + t + '</b></div>' + right + '</div>')
def chip(t, on=False, h=38):
    st = 'background: var(--tx); color: var(--bg); border: 2px solid var(--tx);' if on else 'border: 1px solid var(--dv); color: var(--tx);'
    return '<button style="flex: none; height: %dpx; padding: 0 12px; font-size: 13px; font-weight: %s; white-space: nowrap; display: flex; gap: 6px; align-items: center; %s">%s</button>' % (h, '800' if on else '600', st, t)
def seg(items, active, fs=13):
    return ('<div style="display: grid; grid-template-columns: repeat(%d, minmax(0, 1fr)); border: 2px solid var(--tx);">' % len(items)
            + ''.join('<button style="padding: 10px 4px; font-size: %dpx; font-weight: 600; text-align: center; %s">%s</button>' % (fs, 'background: var(--tx); color: var(--bg);' if n == active else 'background: transparent; color: var(--tx);', n) for n in items) + '</div>')
def obtn(text, icon, kind='out', h=44, disabled=False, fs=14):
    st = {'out': 'border: 2px solid var(--tx); color: var(--tx);', 'ink': 'background: var(--tx); color: var(--bg); border: 2px solid var(--tx);', 'red': 'background: var(--ac); color: var(--ai); border: 2px solid var(--ac);'}[kind]
    if disabled: st = 'border: 2px solid var(--hl); color: var(--mu); background: var(--sf);'
    return '<button%s style="height: %dpx; padding: 0 12px; display: flex; justify-content: center; align-items: center; gap: 8px; font-size: %dpx; font-weight: 800; %s">%s%s</button>' % (' disabled' if disabled else '', h, fs, st, ico(icon, 18) if icon else '', text)
def lab(t): return '<b style="font-size: 13px;">%s</b>' % t
def fld(l, v, pre='', ph_=''):
    inp = '<input value="%s" placeholder="%s" style="height: 46px; padding: 0 12px; border: 2px solid var(--tx); background: var(--bg); font-size: 15px; width: 100%%; min-width: 0;">' % (v, ph_)
    if pre:
        inp = '<div style="display: grid; grid-template-columns: 44px minmax(0, 1fr); border: 2px solid var(--tx);"><span style="display: flex; align-items: center; justify-content: center; border-right: 2px solid var(--tx); font-weight: 800;">%s</span>%s</div>' % (pre, inp.replace('border: 2px solid var(--tx);', 'border: 0;'))
    return '<label style="display: grid; gap: 6px; min-width: 0;">' + lab(l) + inp + '</label>'
def two(a, b): return '<div style="display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 8px;">' + a + b + '</div>'
def switch(label, on, sub=''):
    knob = '<span style="width: 44px; height: 24px; flex: none; border: 2px solid var(--tx); display: flex; justify-content: %s; padding: 2px; background: %s;"><span style="width: 16px; height: 16px; background: var(--%s);"></span></span>' % ('flex-end' if on else 'flex-start', 'var(--tx)' if on else 'transparent', 'bg' if on else 'tx')
    return '<div style="display: flex; justify-content: space-between; align-items: center; gap: 12px; font-size: 15px; font-weight: 600;"><span style="display: grid; gap: 1px;">%s%s</span>%s</div>' % (label, ('<span style="font-size: 12px; font-weight: 400; color: var(--mu);">%s</span>' % sub) if sub else '', knob)
def radio(t, on):
    dot = '<span style="width: 22px; height: 22px; flex: none; border: 2px solid var(--tx); display: grid; place-items: center;">%s</span>' % ('<span style="width: 10px; height: 10px; background: var(--tx);"></span>' if on else '')
    return '<label style="display: flex; gap: 10px; align-items: center; font-size: 15px; font-weight: %s;">%s%s</label>' % ('800' if on else '600', dot, t)
def stripes(h, label, extra=''):
    return '<div style="height: %dpx; position: relative; background: repeating-linear-gradient(135deg, var(--sf) 0 8px, var(--bg) 8px 16px); border: 1px solid var(--hl);">%s<span style="position: absolute; left: 8px; bottom: 8px; font-size: 12px; color: var(--mu);">%s</span></div>' % (h, extra, label)
UNV = '<span style="flex: none; display: inline-flex; align-items: center; padding: 3px 8px; border: 2px solid var(--mu); color: var(--mu); font-size: 11px; font-weight: 800; letter-spacing: .08em;">UNVERIFIED</span>'
GREEN = lambda t: '<span style="justify-self: start; display: inline-flex; gap: 6px; align-items: center; padding: 4px 8px; background: var(--gb); color: var(--gn); font-size: 12px; font-weight: 800;">' + t + '</span>'
def scrollg(inner, pad='12px 16px', gap=10):
    return '<div style="flex-grow: 1; overflow: hidden; border-top: 2px solid var(--tx); padding: %s; display: grid; gap: %dpx; align-content: start;">%s</div>' % (pad, gap, inner)
def bottombar(*btns):
    return '<div style="flex: none; border-top: 2px solid var(--tx); padding: 12px 16px 20px; display: grid; gap: 8px;">' + ''.join(btns) + '</div>'
def backhead(k, t):   # head() from w2: back button + kicker + 30px title
    return head(k, t)

# ======================================================================= F30
LOGO = re.search(r'<svg role="img" aria-label="Hostelzy logo".*?</svg>', rd('login.dc.html'), re.S).group(0).replace('fill="#201E1D"', 'fill="currentColor"')
gbtn = ('<button style="width: 100%; height: 56px; padding: 0 16px; display: flex; gap: 12px; align-items: center; justify-content: center; background: var(--ac); color: var(--ai); font-weight: 800; font-size: 16px;">'
        '<span aria-hidden="true" style="width: 28px; height: 28px; flex: none; display: grid; place-items: center; border: 2px solid var(--ai); font-weight: 800; font-size: 16px;">G</span>Continue with Google</button>')
wall = ('<div style="flex-grow: 1; padding: 8px 20px 28px; display: flex; flex-direction: column; min-height: 0;">'
        '<div><button aria-label="Back" style="width: 44px; height: 44px; flex: none; display: grid; place-items: center; border: 1px solid var(--dv);">' + ico('back', 20) + '</button></div>'
        '<div style="margin-top: 40px; display: grid; gap: 14px; justify-items: start; color: var(--tx);">' + LOGO
        + '<b style="display: block; font-size: 34px; line-height: 1.02; letter-spacing: -.025em;">Sign in to see all 12 hostels</b>'
        '<span style="font-size: 16px; color: var(--mu); line-height: 1.5;">Free. One tap with Google.</span>'
        '<div style="display: grid; gap: 4px; padding: 12px; border: 2px solid var(--tx); width: 100%;">' + kick('Your 3 free hostels') + '<span style="font-size: 15px; line-height: 1.5;">Anjani Residency, Sai Sri Ladies Hostel, Orchid Grand Men’s PG</span></div></div>'
        '<div style="flex-grow: 1;"></div>' + gbtn + '<div style="height: 10px;"></div>' + btn('Not now', 'out', None, 52, 15) + '</div>')
new('f30-wall.dc.html', '[T34] signInWall · Sign in to see all N hostels: 3 free hostels, Continue with Google, Not now · New (F30)', single('x', ph(wall)), 'B')
new('f30-wallDark.dc.html', '[dark] signInWall · Sign in wall (dark) · New (F30)', single('x', ph(wall), True), 'B')
# S8 hint-line variant
ex = rd('r-explore.dc.html')
k = ex.index('Find a bed</b></div>') + len('Find a bed</b></div>')
hint = ('<div style="margin: 0 16px 10px; padding: 8px 10px; background: var(--sf); display: flex; justify-content: space-between; align-items: center; gap: 8px; font-size: 13px;"><span>3 hostels free to open, then sign in (free)</span>'
        '<button aria-label="Dismiss" style="width: 28px; height: 28px; flex: none; display: grid; place-items: center;">' + ico('x', 14) + '</button></div>')
new('f30-exploreHint.dc.html', '[variant of S8] explore · First visit: “3 hostels free to open, then sign in (free)”, once · New (F30)', single('x', pdiv(ex[:k] + hint + ex[k:])), 'B')

# ======================================================================= F28
ENDROW = ('<div style="margin: 4px 16px 16px; padding: 14px; border: 2px solid var(--tx); display: flex; justify-content: space-between; align-items: center; gap: 12px;">'
          '<span style="font-size: 15px; font-weight: 600;">Can’t find your PG?</span><a href="#" style="font-size: 15px; font-weight: 800; color: var(--ad); text-decoration: none;">Add it ›</a></div>')
s = rd('f26-exploreUnv.dc.html')
CS = '<div style="padding: 0 16px 16px; display: grid; gap: 6px;">'
a = s.index(CS); b = s.index(CS, a + 10); s = s[:a] + s[b:]
k = s.rindex('</div>', 0, s.index('<nav')); s = s[:k] + ENDROW + s[k:]
new('f28-exploreEnd.dc.html', '[variant of S8] explore · End of the list: last listed card, “Can’t find your PG? Add it” · New (F28)', single('x', pdiv(s)), 'A')
s = rd('exploreEmpty.dc.html'); k = s.index('</button>', s.index('Try Hitec City')) + 9
s = s[:k] + '<a href="#" style="font-size: 15px; font-weight: 800; color: var(--ad); text-decoration: none; padding: 6px 0;">Can’t find your PG? Add it ›</a>' + s[k:]
upd('exploreEmpty.dc.html', s, B['exploreEmpty.dc.html']['title'].replace(' · Redesigned', '') + ' · “Can’t find your PG? Add it” · Updated (F28)')
# H1: Verified only switch
s = rd('r-filters.dc.html'); k = s.index('Food included'); e = s.index('</span></span></div>', k) + len('</span></span></div>')
s = s[:e] + switch('Verified only', False) + s[e:]
upd('r-filters.dc.html', s, '[H1] filters sheet · For, Room, Budget (Any), Food included, Verified only · Updated (F28)')
# S79 Me: Add a hostel row (+ Your hostel variant)
me = rd('me.dc.html'); k = me.index('<b style="font-size: 16px;">Stay Rewards</b>'); a = me.rindex('<button style="width: 100%', 0, k); b = me.index('</button>', k) + 9
row = me[a:b]; row = re.sub(r'<svg.*?</svg>', ico('plus'), row, count=1, flags=re.S)
r1 = row.replace('>Stay Rewards<', '>Add a hostel<').replace('>Not a member yet<', '><')
r2 = row.replace('>Stay Rewards<', '>Your hostel<').replace('>Not a member yet<', '>Sri Balaji Men’s PG · Owner asked<')
upd('me.dc.html', me[:a] + r1 + me[a:], B['me.dc.html']['title'].replace(' · Updated (F26)', '') + '; Add a hostel row · Updated (F28)')
new('f28-meYourHostel.dc.html', '[variant of S79] me · “Your hostel · Owner asked” row → S93 · New (F28)', single('x', pdiv(me[:a] + r2 + me[a:])), 'A')
# T20: Add my hostel
s = ph(hdr('Anjani Residency', 'My stay') + scrollg('<span style="font-size: 16px; line-height: 1.45;">Your stay isn’t on Hostelzy yet</span>' + btn('Add my hostel', 'red', 'plus', 50, 15), '20px 16px', 12), navsel(NAV_R, 'My stay'))
upd('w3-stayNotYet.dc.html', single('x', s), '[T20] rStay · Your stay isn’t on Hostelzy yet · Add my hostel · Updated (F28)')
# S22 Rewards variant
s = rd('rewards.dc.html'); k = s.index('>How to earn<'); j = s.rindex('<div', 0, k)
def rrow(amt, t, sub):
    return ('<div style="display: grid; grid-template-columns: 52px minmax(0, 1fr); gap: 12px; align-items: center; padding: 12px 16px; border-bottom: 1px solid var(--hl);"><b style="height: 32px; display: grid; place-items: center; background: var(--gb); color: var(--gn); font-size: 13px;">%s</b><span style="display: grid; gap: 1px;"><b style="font-size: 15px;">%s</b><span style="font-size: 13px; color: var(--mu);">%s</span></span></div>') % (amt, t, sub)
block = ('<div style="padding: 16px 16px 6px;">' + kick('Hostels you added') + '</div><div style="border-top: 2px solid var(--tx);">'
         + rrow('₹200', 'Sri Balaji Men’s PG verified', '₹200 · paid by UPI on the 5th · ravi@okaxis') + rrow('₹20', 'Lakshmi Ladies Hostel listed (partner)', '₹20 · after the team check') + '</div>')
new('f28-rewardsAdded.dc.html', '[variant of S22] rewards · “₹200 · <hostel> verified · paid by UPI on the 5th”, ₹20 partner row · New (F28)', single('x', pdiv(s[:j] + block + s[j:])), 'A')

# S92 Add a hostel
def tile(inner, label):
    return '<div style="height: 72px; border: 2px dashed var(--dv); display: grid; place-items: center; align-content: center; gap: 4px; font-size: 11px; font-weight: 800; color: var(--mu);">%s%s</div>' % (inner, label)
photos = '<div style="display: grid; gap: 6px;">' + lab('Gate photo · 1 to 3') + '<div style="display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 8px;">' + stripes(72, 'gate.jpg') + tile(ico('camera', 20), 'Camera') + tile(ico('image', 20), 'Gallery') + '</div></div>'
pin = '<div style="display: grid; gap: 6px;">' + lab('Pin · drag to fix') + stripes(64, 'Madhapur · from the pin', '<span style="position: absolute; left: 50%; top: 50%; transform: translate(-50%, -70%); color: var(--ad);">' + ico('pin', 26) + '</span>') + '</div>'
def addform(partner=False):
    who = '<div style="display: grid; gap: 8px;">' + radio('I live here', not partner) + radio('I’m a Hostelzy partner', partner) + '</div>'
    rent = two(fld('Rent from · ₹/month', '6,500', '₹'), fld('Rent to', '9,000', '₹')) if partner else two(fld('What do you pay? · ₹/month', '7,000', '₹'), '<div style="display: grid; gap: 6px;">' + lab('Sharing') + '<div style="display: flex; gap: 6px;">' + ''.join(chip(t, t == '3', 46) for t in ['1', '2', '3', '4+']) + '</div></div>')
    extra = fld('Partner code', 'HZ-PART-1') if partner else ''
    body = (backhead('Hyderabad', 'Add a hostel')
            + scrollg(fld('Hostel name', 'Sri Balaji Men’s PG') + photos + pin + '<div style="display: grid; gap: 6px;">' + lab('For') + seg(['Men', 'Women', 'Co-living'], 'Men') + '</div>' + rent
                      + switch('Food included', True) + two(fld('Owner’s name *', 'Venkat Rao'), fld('Owner’s phone *', '98490 11223', '+91')) + who + extra, '10px 16px', 10)
            + bottombar(btn('Add', 'red', 'arrow')))
    return ph(body)
new('f28-addHostel.dc.html', '[S92] addHostel · Add a hostel: name, gate photo, pin, for, what you pay, sharing, food, owner’s name + phone, I live here · New (F28)', single('x', addform()), 'A')
new('f28-addHostelDark.dc.html', '[dark] addHostel · Add a hostel (dark) · New (F28)', single('x', addform(), True), 'A')
new('f28-addHostelPartner.dc.html', '[variant of S92] addHostel · Partner: rent range + partner code · New (F28)', single('x', addform(True)), 'A')

# S93 Your hostel on Hostelzy
def steps5(done, fifth='₹200 paid', muted_from=None, fifth_sub=''):
    names = ['Added', 'Owner asked', 'Owner agreed', 'Verified', fifth]
    out = ''
    for i, n in enumerate(names):
        isdone = i < done; now = i == done and (muted_from is None or i < muted_from)
        mark = 'background: var(--tx); color: var(--bg);' if isdone else ('background: var(--ac); color: var(--ai);' if now else 'border: 2px solid var(--dv); color: var(--mu);')
        sub = ('<span style="font-size: 12px; color: var(--mu);">%s</span>' % fifth_sub) if (i == 4 and fifth_sub) else ''
        out += ('<div style="display: grid; grid-template-columns: 24px minmax(0, 1fr); gap: 10px; align-items: center;"><span style="width: 24px; height: 24px; display: grid; place-items: center; font-size: 12px; font-weight: 800; %s">%s</span><span style="display: grid;"><b style="font-size: 14px; %s">%s</b>%s</span></div>') % (mark, ico('check', 14) if isdone else str(i + 1), '' if (isdone or now) else 'color: var(--mu);', n + (' · next' if now else ''), sub)
    return '<div style="display: grid; gap: 8px;">' + out + '</div>'
mycard = ('<div style="border: 1px solid var(--hl); display: grid; gap: 6px; padding-bottom: 10px;">' + stripes(96, 'photo 1 / 1 · by you')
          + '<div style="padding: 0 10px; display: flex; gap: 8px; align-items: center; flex-wrap: wrap;"><b style="font-size: 16px;">Sri Balaji Men’s PG</b>' + UNV + '</div>'
          + '<span style="padding: 0 10px; font-size: 13px; color: var(--mu);">Men · Madhapur · 3 sharing · food included</span><span style="padding: 0 10px; font-size: 14px;"><b>Around ₹7,000/mo</b> · <span style="color: var(--mu);">expected, not confirmed</span></span></div>')
HONEST = mut('Paid only when the owner agrees and Hostelzy verifies the hostel.', 12)
def myadd(done, action, line='', fifth='₹200 paid', muted_from=None, fifth_sub='', chipt=''):
    body = (backhead('Added by you · 18 Oct', 'Your hostel on Hostelzy')
            + scrollg('<div style="display: grid; gap: 4px;">' + kick('As tenants see it') + mycard + '</div>' + steps5(done, fifth, muted_from, fifth_sub) + (GREEN(chipt) if chipt else '') + (('<div style="padding: 10px 12px; background: var(--sf); font-size: 14px; line-height: 1.45;">%s</div>' % line) if line else ''), '12px 16px', 12)
            + bottombar(*action, HONEST))
    return ph(body, navsel(NAV_T, 'Me'))
main93 = myadd(1, [btn('Send to your owner', 'red', 'msg')])
new('f28-myAdd.dc.html', '[S93] myAdd · Your hostel on Hostelzy: the card, 5 steps, Send to your owner · New (F28)', single('x', main93), 'A')
new('f28-myAddDark.dc.html', '[dark] myAdd · Your hostel on Hostelzy (dark) · New (F28)', single('x', main93, True), 'A')
new('f28-myAddAsked.dc.html', '[variant of S93] myAdd · Owner asked: Ask again after 3 days · New (F28)', single('x', myadd(2, [obtn('Ask again · from 21 Oct', 'msg', 'out', 52, True)], 'Asked 18 Oct')), 'A')
new('f28-myAddAgreed.dc.html', '[variant of S93] myAdd · Owner agreed: your UPI id for the ₹200, Hostelzy verifies next · New (F28)', single('x', myadd(3, [two(fld('Your UPI id for the ₹200', 'ravi@okaxis'), '<div style="display: grid; align-content: end;">' + obtn('Save', None, 'red', 46) + '</div>')], 'Venkat Rao agreed · 20 Oct')), 'A')
new('f28-myAddVerified.dc.html', '[variant of S93] myAdd · Verified: ₹200 by UPI on the 5th · New (F28)', single('x', myadd(4, [], 'Verified 2 Nov · ₹200 to ravi@okaxis on 5 Nov', fifth_sub='by UPI on the 5th')), 'A')
new('f28-myAddPaid.dc.html', '[variant of S93] myAdd · Paid: ₹200 by UPI · New (F28)', single('x', myadd(5, [], '', chipt='₹200 paid by UPI · 5 Nov · ravi@okaxis')), 'A')
new('f28-myAddWaiting.dc.html', '[variant of S93] myAdd · Still waiting (60 days): you can ask again, no payout · New (F28)', single('x', myadd(2, [obtn('Ask again', 'msg', 'out', 52)], '<b>Still waiting.</b> You can ask again.', muted_from=2)), 'A')
new('f28-myAddQueued.dc.html', '[variant of S93] myAdd · Queued: this month’s ₹2,000 cap is reached, ₹200 next month · New (F28)', single('x', myadd(4, [], 'Monthly cap reached · ₹200 queued for 5 Dec', fifth='₹200 queued', fifth_sub='next month')), 'A')

# ======================================================================= F29
# S38 Rent: Call + WhatsApp on the Paid row too
for n in ['oRent.dc.html', 'oRent-dark.dc.html']:
    s = rd(n); a = s.index('<span style="display: flex; gap: 6px;"><button aria-label="Call"'); b = s.index('</button></span>', a) + len('</button></span>')
    pair = s[a:b].replace('aria-label="WhatsApp reminder"', 'aria-label="WhatsApp"')
    s = s.replace('<span style="width: 44px;"></span></div></div>', pair + '</div></div>', 1)
    assert 'width: 44px;"></span>' not in s
    upd(n, s, B[n]['title'].replace('Call + WhatsApp', 'Call + WhatsApp on every row').replace(' · Updated (F26)', '') + ' · Updated (F29)')
# S40 Residents: Call · WhatsApp · Notify on every row; Ask to join
s = rd('residents.dc.html')
rowre = re.compile(r'<div style="display: grid; grid-template-columns: 36px minmax\(0, 1fr\) auto; gap: 12px; align-items: center; padding: 12px 16px; border-bottom: 1px solid var\(--hl\);">.*?</div>', re.S)
def rowfix(m):
    r = m.group(0); noapp = 'Teja Naidu' in r
    btns = obtn('Call', 'phone', 'out', 40, fs=13) + obtn('WhatsApp', 'msg', 'out', 40, fs=13) + obtn('Notify', 'bell', 'out', 40, noapp, 13)
    tail = ('<span style="font-size: 12px; color: var(--mu);">Not on the app yet · <a href="#" style="font-weight: 800; color: var(--ad);">Ask to join ›</a></span>' if noapp else '')
    return r.replace(' border-bottom: 1px solid var(--hl);', '').replace('padding: 12px 16px;', 'padding: 12px 16px 6px;') + '<div style="padding: 0 16px 12px; border-bottom: 1px solid var(--hl); display: grid; gap: 6px;"><div style="display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 6px;">' + btns + '</div>' + tail + '</div>'
s, n = rowre.subn(rowfix, s); assert n == 4, n
k = s.index('by Sat 3 Oct.</span>') + len('by Sat 3 Oct.</span>')
s = s[:k] + '<span style="display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 8px; margin-top: 8px;">' + obtn('Add resident', 'plus', 'red', 44) + obtn('Ask to join', 'msg', 'red', 44) + '</span>' + s[k:]
upd('residents.dc.html', s, '[S40] oMore · Residents · Call · WhatsApp · Notify on every row; Add resident · Ask to join · Updated (F29)')
RES = pdiv(rd('residents.dc.html'))
# H48 Ask to join
beds = '<div style="display: grid; gap: 6px;">' + lab('Free bed') + '<div style="display: flex; gap: 6px; flex-wrap: wrap;">' + ''.join(chip(b_, b_ == '203-B', 40) for b_ in ['102-C', '201-B', '202-A', '203-B', '301-C']) + '</div></div>'
h48rows = ['<div style="padding: 14px 16px 0; display: grid; gap: 10px;">' + beds + two(fld('Monthly fee', '8,000', '₹'), fld('Advance', '3,000', '₹')) + two(fld('Moves in', 'Today, 18 Oct'), fld('First name (optional)', 'Ravi'))
           + '</div>']
new('f29-askJoin.dc.html', '[H48] askJoin sheet · Ask to join: free bed, fee, advance, moves in, name, Send on WhatsApp · New (F29)', single('x', add_sheet(RES, sheet(kick('Anjani Residency'), 'Ask to join', h48rows, [btn('Send on WhatsApp', 'red', 'msg')]))), 'B')
# S94 Join form (tenant) + done
idsec = ('<div style="display: grid; gap: 8px; padding: 12px; border: 2px solid var(--tx);">' + kick('ID') + '<b style="font-size: 15px; line-height: 1.35;">Take a photo of your Aadhaar (or any government ID)</b>'
         + btn('Send ID on WhatsApp', 'out', 'msg', 48, 15) + '</div>')
jf = (backhead('Bed 203-B · ₹8,000/month · advance ₹3,000', 'Join Anjani Residency')
      + scrollg(fld('Your name', 'Ravi Teja') + fld('Phone · from your account', '90000 00001', '+91') + fld('Moves in', '1 Nov 2026') + idsec, '12px 16px', 10)
      + bottombar(btn('Send to owner', 'red', 'arrow')))
new('f29-joinForm.dc.html', '[S94] joinForm · Join <hostel>: name, phone, moves in, ID (Send ID on WhatsApp), Send to owner · New (F29)', single('x', ph(jf)), 'B')
new('f29-joinFormDark.dc.html', '[dark] joinForm · Join <hostel> (dark) · New (F29)', single('x', ph(jf), True), 'B')
done = (backhead('Bed 203-B · ₹8,000/month', 'Join Anjani Residency')
        + scrollg('<div style="padding: 14px; border: 2px solid var(--tx); display: grid; gap: 4px;"><b style="font-size: 22px;">Sent</b><span style="font-size: 14px; color: var(--mu);">Srinivas will approve · we’ll notify you</span></div>'
                  + '<div style="border-top: 2px solid var(--dv);">' + srow('Name', 'Ravi Teja') + srow('Phone', '+91 90000 00001') + srow('Moves in', '1 Nov 2026') + srow('ID', 'Sent on WhatsApp') + '</div>', '12px 0', 12))
new('f29-joinFormDone.dc.html', '[variant of S94] joinForm · Done: “Sent · <owner> will approve · we’ll notify you” · New (F29)', single('x', ph(done)), 'B')
# S36 Joining tab variant
t = rd('r-today.dc.html')
a = t.index('<div style="margin: 0 16px; display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); border: 2px solid var(--tx);">'); b = t.index('Fixes</span></button></div>', a) + len('Fixes</span></button></div>')
def gtab(n, cnt, on): return '<button style="padding: 8px 2px; display: grid; justify-items: center; gap: 1px; %s"><b style="font-size: 18px; line-height: 1.1;">%s</b><span style="font-size: 11px; font-weight: 600;">%s</span></button>' % ('background: var(--tx); color: var(--bg);' if on else 'color: var(--tx);', cnt, n)
tabs4 = '<div style="margin: 0 16px; display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); border: 2px solid var(--tx);">' + gtab('Holds', 2, False) + gtab('Payments', 1, False) + gtab('Joining', 1, True) + gtab('Fixes', 1, False) + '</div>'
m = t.rindex('<div', 0, t.index('>This month<'))
joincard = ('<div style="border-top: 0;"><div style="padding: 12px 16px; border-bottom: 1px solid var(--hl); display: grid; grid-template-columns: 36px minmax(0, 1fr) 16px; gap: 10px; align-items: center;"><span style="width: 36px; height: 36px; display: grid; place-items: center; background: var(--sf);">' + ico('plusU')
            + '</span><span style="display: grid; gap: 1px;"><b style="font-size: 15px;">Ravi wants to join</b><span style="font-size: 12px; color: var(--mu);">Bed 203-B · moves in 1 Nov · ₹8,000/month · ID on WhatsApp</span></span>' + ico('chev', 16) + '</div></div>')
tj = t[:a] + tabs4 + joincard + t[m:]
new('f29-todayJoining.dc.html', '[variant of S36] oToday · Joining tab (only when non-empty): “Ravi wants to join · bed 203-B · moves in 1 Nov” → H49 · New (F29)', single('x', pdiv(tj)), 'B')
TJ = pdiv(tj)
# H49 Join review
def idrow(kind):
    if kind == 'drive':
        img = ('<div style="position: relative; height: 120px; border: 2px solid var(--tx); background: repeating-linear-gradient(135deg, var(--sf) 0 8px, var(--bg) 8px 16px); padding: 10px; display: grid; align-content: space-between;"><span style="font-size: 10px; font-weight: 800; letter-spacing: .1em;">AADHAAR · RAVI TEJA</span>'
               '<span style="display: flex; gap: 8px; align-items: center; font-size: 18px; font-weight: 800; letter-spacing: .1em;"><span style="width: 150px; height: 22px; background: var(--tx);"></span>1234</span></div>')
        return '<div style="padding: 14px 16px 0; display: grid; gap: 8px;">' + kick('ID · in your Google Drive') + img + '<div style="display: flex; justify-content: space-between; font-size: 13px; font-weight: 800;"><a href="#" style="color: var(--tx);">Open in Drive ›</a><a href="#" style="color: var(--ad);">Delete from my Drive</a></div></div>'
    on = kind == 'tick'
    box = '<span style="width: 26px; height: 26px; flex: none; border: 2px solid var(--tx); display: grid; place-items: center; %s">%s</span>' % ('background: var(--tx); color: var(--bg);' if on else '', ico('check', 16) if on else '')
    return ('<div style="padding: 14px 16px 0;"><label style="display: flex; gap: 12px; align-items: center; padding: 12px; border: 2px solid var(--tx);">' + box + '<span style="display: grid; gap: 1px;"><b style="font-size: 15px;">ID received on WhatsApp' + (' ✓' if on else '') + '</b><span style="font-size: 12px; color: var(--mu);">'
            + ('Ticked 18 Oct' if on else '') + '</span></span></label></div>')
def h49(kind):
    rows = ['<div style="border-top: 0;">' + srow('Name', 'Ravi Teja') + srow('Phone', '+91 90000 00001') + srow('Moves in', '1 Nov 2026') + srow('Monthly fee', '₹8,000') + srow('Advance', '₹3,000') + '</div>' + idrow(kind)]
    return add_sheet(TJ, sheet(kick('Bed 203-B · moves in 1 Nov'), 'Ravi wants to join', rows, [btn('Approve', 'red', 'check'), two(obtn('Ask again', 'bell', 'out', 48), obtn('Decline', 'x', 'out', 48))]))
new('f29-joinReview.dc.html', '[H49] joinReview sheet · Ravi wants to join: details, ID received on WhatsApp (tick), Approve / Ask again / Decline · New (F29)', single('x', h49('none')), 'B')
new('f29-joinReviewDark.dc.html', '[dark] joinReview · Ravi wants to join (dark) · New (F29)', single('x', h49('none'), True), 'B')
new('f29-joinReviewTick.dc.html', '[variant of H49] joinReview · ID received on WhatsApp ✓ · New (F29)', single('x', h49('tick')), 'B')
new('f29-joinReviewDrive.dc.html', '[variant of H49] joinReview · ID in the owner’s Drive: masked image, Open in Drive, Delete from my Drive · New (F29)', single('x', h49('drive')), 'B')
# H50 Tenant IDs in your Drive (over Manage)
MAN = pdiv(rd('r-manage.dc.html'))
def h50(state):
    lead = '<div style="padding: 14px 16px 0; display: grid; gap: 10px;">'
    if state == 'connected':
        lead += '<div style="padding: 10px 12px; border: 2px solid var(--tx); display: grid; gap: 2px;"><b style="font-size: 15px;">Connected · 12 files</b><span style="font-size: 12px; color: var(--mu);">Hostelzy / Anjani Residency / Tenant IDs</span></div>'
    elif state == 'na':
        lead += '<div style="padding: 10px 12px; background: var(--ab); color: var(--ad); font-size: 15px; font-weight: 800;">Not available yet</div>'
    lead += switch('Full copy needed (police file)', False) + '</div>'
    b_ = btn('Disconnect', 'out', 'x') if state == 'connected' else (obtn('Connect Google Drive', 'folder', 'red', 52, state == 'na', 15))
    return add_sheet(MAN, sheet(kick('Manage · Tenant IDs'), 'Tenant IDs in your Drive', [lead], [b_]))
new('f29-drive.dc.html', '[H50] drive sheet · Tenant IDs in your Drive: Connect Google Drive, Full copy needed switch · New (F29)', single('x', h50('off')), 'B')
new('f29-driveConnected.dc.html', '[variant of H50] drive · Connected · 12 files, Disconnect · New (F29)', single('x', h50('connected')), 'B')
new('f29-driveNA.dc.html', '[variant of H50] drive · Not available yet (Drive scope not approved) · New (F29)', single('x', h50('na')), 'B')

# ======================================================================= Web + console (F28)
WJ = rd('wJ.dc.html')
def webpage(tt, inner, h=900):
    s = title(WJ, tt); a = s.index('<h1'); b = s.index('<footer')
    s = s[:a] + inner + s[b:]
    s = s.replace('height: 900px;', 'height: %dpx;' % h, 1)
    s = s.replace('"$preview": {"width": 390, "height": 900}', '"$preview": {"width": 390, "height": %d}' % h)
    return s
H1W = '<h1 style="font-size: 30px; line-height: 1.15; font-weight: 900; letter-spacing: -.02em; margin: 0 0 6px;">%s</h1>'
PW = '<p style="color: var(--mu); font-size: 14px; margin: 0 0 12px;">%s</p>'
CTA = '<a href="#" style="display: block; text-align: center; text-decoration: none; font-weight: 800; padding: 14px 16px; margin: 10px 0; background: var(--ac); color: #fff; border: 2px solid var(--ac);">%s</a>'
def wf(l, v=''):
    return '<label style="display: grid; gap: 6px; font-size: 13px; font-weight: 800; margin: 0 0 12px;">%s<input value="%s" style="height: 46px; padding: 0 12px; border: 2px solid var(--tx); background: var(--bg); font: inherit; font-size: 16px; width: 100%%; min-width: 0;"></label>' % (l, v)
listform = (H1W % 'List your PG on Hostelzy, free'
            + wf('Hostel name') + wf('Your name') + wf('Phone (WhatsApp)') + wf('Area', '') + two(wf('Rent from · ₹/month'), wf('Rent to'))
            + '<div style="display: grid; gap: 6px; margin: 0 0 12px; font-size: 13px; font-weight: 800;">For' + seg(['Men', 'Women', 'Co-living'], '', 14) + '</div>'
            + '<div style="display: grid; gap: 6px; margin: 0 0 12px; font-size: 13px; font-weight: 800;">Food included' + seg(['Yes', 'No'], '', 14) + '</div>'
            + '<div style="display: grid; gap: 6px; margin: 0 0 4px; font-size: 13px; font-weight: 800;">Photos · 1 to 3<div style="height: 72px; border: 2px dashed var(--dv); display: grid; place-items: center; color: var(--mu); font-size: 14px;">Add photos</div></div>'
            + CTA % 'Send' + PW % 'We’ll call you within 2 days to confirm.')
new('f28-wList.dc.html', '[W9] app/list/ · List your PG on Hostelzy, free: form, “We’ll call you within 2 days to confirm” · New (F28)', webpage('List your PG on Hostelzy', listform, 1240), 'C', 390, 1240)
sent = (H1W % 'Thanks. We’ll call you within 2 days to confirm.' + '<div style="border: 2px solid var(--tx); background: var(--sf); padding: 16px; margin: 18px 0;"><div style="color: var(--mu); font-size: 14px;">Sent</div><div style="font-size: 22px; font-weight: 900;">Sri Balaji Men’s PG · Madhapur</div><p style="color: var(--mu); font-size: 14px; margin: 8px 0 0;">We call +91 98490 11223.</p></div>'
        + '<a href="#" style="display: block; text-align: center; text-decoration: none; font-weight: 800; padding: 14px 16px; margin: 10px 0; background: transparent; color: var(--tx); border: 2px solid var(--tx);">Get the app (Android test build)</a>')
new('f28-wListSent.dc.html', '[variant of W9] app/list/ · Sent: “We’ll call you within 2 days to confirm” · New (F28)', webpage('List your PG: sent', sent, 900), 'C', 390, 900)
# W10 poster A4 (794 × 1123)
qr = ('<div aria-label="QR code to farhath.me/hostelzy/app/list" style="width: 300px; height: 300px; border: 4px solid var(--tx); padding: 18px; display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); grid-template-rows: repeat(3, minmax(0, 1fr)); gap: 10px; background: #fff;">'
      + ''.join('<span style="%s"></span>' % ('border: 10px solid var(--tx); box-shadow: inset 0 0 0 10px #fff, inset 0 0 0 26px var(--tx);' if i in (0, 2, 6) else 'background: repeating-linear-gradient(90deg, var(--tx) 0 8px, transparent 8px 16px), repeating-linear-gradient(0deg, var(--tx) 0 8px, transparent 8px 16px); background-blend-mode: multiply; opacity: .85;') for i in range(9)) + '</div>')
poster_s = title(WJ, 'Poster: Get tenants from Hostelzy. Free listing.')
a = poster_s.index('<div data-hz'); b = poster_s.rindex('</div>\n</x-dc>') + 6
poster = ('<div data-hz="" data-theme="{{theme}}" style="width: 794px; height: 1123px; box-sizing: border-box; padding: 56px; background: #ffffff; color: #201e1d; font-family: Archivo, system-ui, sans-serif; display: flex; flex-direction: column; gap: 28px;">'
          '<div style="display: flex; align-items: center; gap: 12px; padding-bottom: 16px; border-bottom: 3px solid #201e1d;"><span style="width: 22px; height: 22px; background: #ec3013; display: inline-block;"></span><span style="font-weight: 900; font-size: 34px; letter-spacing: -.02em;">Hostelzy</span><span style="flex: 1;"></span><span style="font-size: 18px; color: #605d5d;">PG owners · Hyderabad</span></div>'
          '<b style="font-size: 72px; line-height: 1; letter-spacing: -.03em; color: #ec3013;">Get tenants from Hostelzy. Free listing.</b>'
          '<div style="display: grid; grid-template-columns: 300px minmax(0, 1fr); gap: 36px; align-items: center;">' + qr + '<div style="display: grid; gap: 18px; font-size: 24px; line-height: 1.35;"><b style="font-size: 28px;">Scan to list your PG</b><span>We call you within 2 days to confirm.</span></div></div>'
          '<div style="margin-top: auto; padding-top: 18px; border-top: 3px solid #201e1d; display: flex; justify-content: space-between; align-items: baseline; font-size: 22px;"><b>farhath.me/hostelzy/app/list</b><span style="color: #605d5d;">WhatsApp +91 90597 90014</span></div></div>')
poster_s = poster_s[:a] + poster + poster_s[b:]
poster_s = poster_s.replace('"$preview": {"width": 390, "height": 900}', '"$preview": {"width": 794, "height": 1123}')
new('f28-wPoster.dc.html', '[W10] app/list/poster.html · A4 poster: “Get tenants from Hostelzy. Free listing.”, QR to app/list/ · New (F28)', poster_s, 'C', 794, 1123)
# C14 segments + variants
C14 = rd('f26-c14.dc.html')
def csegs(active):
    return '<div style="display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); border: 2px solid var(--tx); max-width: 560px;">' + ''.join('<button style="padding: 10px 4px; font-size: 14px; font-weight: 600; text-align: center; %s">%s</button>' % ('background: var(--tx); color: var(--bg);' if n == active else '', n) for n in ['Listed', 'To call', 'To refresh', 'Partners']) + '</div>'
k = C14.index('<h2 style="margin: 0; font-size: 24px; font-weight: 800;">Listed in Madhapur')
upd('f26-c14.dc.html', C14[:k] + csegs('Listed') + C14[k:], '[C14] console · Listed: segments Listed · To call · To refresh · Partners; list a hostel, List it / Take off · Updated (F28)')
cth = 'padding: 10px 12px; font-size: 12px; font-weight: 800; letter-spacing: .08em; text-transform: uppercase; color: var(--mu); text-align: left; border-bottom: 2px solid var(--tx);'
ctd = 'padding: 12px; font-size: 14px; border-bottom: 1px solid var(--hl); vertical-align: middle;'
def ctable(heads, rows):
    return '<table style="width: 100%; border-collapse: collapse;"><thead><tr>' + ''.join('<th style="%s">%s</th>' % (cth, h) for h in heads) + '</tr></thead><tbody>' + ''.join('<tr>' + ''.join('<td style="%s">%s</td>' % (ctd, x) for x in row) + '</tr>' for row in rows) + '</tbody></table>'
sbtn = lambda t, kind='out': '<button style="height: 36px; padding: 0 12px; font-size: 13px; font-weight: 800; white-space: nowrap; %s">%s</button>' % ({'out': 'border: 2px solid var(--tx);', 'red': 'background: var(--ac); color: var(--ai);', 'ink': 'background: var(--tx); color: var(--bg);'}[kind], t)
sin = lambda v, w=72: '<input value="%s" style="width: %dpx; height: 34px; padding: 0 8px; border: 2px solid var(--tx); background: var(--bg); font-size: 13px;">' % (v, w)
mseg = lambda items, on: '<span style="display: inline-grid; grid-template-columns: repeat(%d, auto); border: 2px solid var(--tx);">' % len(items) + ''.join('<button style="height: 30px; padding: 0 8px; font-size: 12px; font-weight: 700; white-space: nowrap; %s">%s</button>' % ('background: var(--tx); color: var(--bg);' if n == on else '', n) for n in items) + '</span>'
acts = lambda: '<span style="display: flex; gap: 6px; flex-wrap: wrap;">' + sbtn('List', 'red') + sbtn('Not a PG · Closed') + sbtn('Call later') + '</span>'
def cvar(name, tt, h2, lead, body):
    main = '<main style="min-width: 0; padding: 20px 24px; display: grid; gap: 14px; align-content: start;">' + csegs(name) + '<div style="display: flex; justify-content: space-between; align-items: center; gap: 16px;"><h2 style="margin: 0; font-size: 24px; font-weight: 800;">' + h2 + '</h2>' + lead + '</div>' + body + '</main>'
    s = C14; i = s.index('<main'); j = s.index('</main>') + 7
    s = s[:i] + main + s[j:]; s = title(s, tt)
    new('f28-c14-' + name.replace(' ', '').lower() + '.dc.html', tt, s, 'C', 1440, 900)
script = ('<div style="padding: 14px 16px; border: 2px solid var(--tx); display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 6px 24px; font-size: 14px; line-height: 1.45;">'
          + ''.join('<span><b>%d.</b> %s</span>' % (i + 1, t) for i, t in enumerate(['Who we are: Hostelzy, a free app where Hyderabad tenants find PGs.', 'Your PG is listed free; tenants already see it as unverified.', 'What is the rent range? (from – to)', 'For men, women or co-living?', 'Food included?', 'Want it verified? We visit once, free.'])) + '</div>')
cvar('To call', '[variant of C14] console · Listed › To call: drafts from Places / OSM / web, call script, List / Not a PG / Call later, Export CSV · New (F28)', 'To call · 38 drafts', sbtn('Export CSV'),
     script + ctable(['Hostel', 'Phone', 'Rent ₹ from – to', 'For', 'Food', ''], [
         ['<b>Sri Venkateswara PG</b><br><span style="font-size: 12px; color: var(--mu);">Madhapur · Places</span>', '<a href="#" style="font-weight: 800; color: var(--tx);">+91 98480 10203</a>', sin('6,500') + ' – ' + sin('8,000'), mseg(['Men', 'Women', 'Co-living'], 'Men'), mseg(['Yes', 'No'], 'Yes'), acts()],
         ['<b>Sai Durga Ladies Hostel</b><br><span style="font-size: 12px; color: var(--mu);">Kondapur · web form</span>', '<a href="#" style="font-weight: 800; color: var(--tx);">+91 99080 55612</a>', sin('7,000') + ' – ' + sin('9,500'), mseg(['Men', 'Women', 'Co-living'], 'Women'), mseg(['Yes', 'No'], 'Yes'), acts()],
         ['<b>Green Nest Hostel</b><br><span style="font-size: 12px; color: var(--mu);">Gachibowli · OpenStreetMap</span>', '<a href="#" style="font-weight: 800; color: var(--tx);">+91 97010 33440</a>', sin('') + ' – ' + sin(''), mseg(['Men', 'Women', 'Co-living'], ''), mseg(['Yes', 'No'], ''), acts()],
     ]) + '<span style="font-size: 12px; color: var(--mu);">Map data © OpenStreetMap contributors</span>')
cvar('To refresh', '[variant of C14] console · Listed › To refresh: listed past 50 days, Rent confirmed today / Closed, Export CSV · New (F28)', 'To refresh · 9 listed past 50 days', sbtn('Export CSV'),
     ctable(['Hostel', 'Area', 'Rent range', 'Confirmed', ''], [
         ['<b>Sri Balaji Men’s PG</b>', 'Madhapur', '₹7,000–9,000', '54 days ago', '<span style="display: flex; gap: 6px;">' + sbtn('Rent confirmed today', 'ink') + sbtn('Closed') + '</span>'],
         ['<b>Lakshmi Ladies Hostel</b>', 'Kondapur', '₹6,500–8,500', '61 days ago · shows “Rent on request”', '<span style="display: flex; gap: 6px;">' + sbtn('Rent confirmed today', 'ink') + sbtn('Closed') + '</span>'],
     ]))
pform = ('<div style="display: grid; grid-template-columns: 420px minmax(0, 1fr); gap: 24px; align-items: start;"><div style="display: grid; gap: 12px;">' + fld('Name', 'Priya Sharma') + fld('Phone', '98765 43210', '+91') + fld('UPI id', 'priya@okicici') + fld('Code (made for them)', 'HZ-PART-2') + btn('Add partner', 'red', 'plus') + '</div>'
         + ctable(['Partner', 'Code', 'Listed', '₹ due', 'Active'], [['<b>Anil Kumar</b><br><span style="font-size: 12px; color: var(--mu);">+91 98490 77001 · anil@okaxis</span>', 'HZ-PART-1', '14 · 11 checked', '₹220 · pay on the 5th', mseg(['On', 'Off'], 'On')]]) + '</div>')
cvar('Partners', '[variant of C14] console · Listed › Partners: add partner (code), list, listed count, ₹ due · New (F28)', 'Partners · 1', '', pform)
# C15 variant
s = rd('f26-c15.dc.html')
s = s.replace('Madhapur · unverified</span>', 'Madhapur · unverified</span><br><span style="font-size: 12px;">added by Ravi (resident) · owner phone matches ✓</span>', 1)
s = s.replace('Kondapur · unverified</span>', 'Kondapur · unverified</span><br><span style="font-size: 12px;">added by Priya (partner) · owner phone matches <b style="color: var(--ad);">✗</b></span>', 1)
new('f28-c15-addedBy.dc.html', '[variant of C15] console · Claims: “added by Ravi (resident) · owner phone matches ✓ / ✗” · New (F28)', title(s, 'Claims: added by'), 'C', 1440, 900)

# ======================================================================= index
# archive rows kept only in git: Old main canvas (z-old-*) and F25 drafts
drop = [k for k, v in B.items() if (k.startswith('z-old-') or k in ('aCases.dc.html', 'aPay.dc.html', 'addTenant.dc.html', 'w4-floorMap.dc.html', 'w4-oFloorPlan.dc.html')) and 'archive' in v.get('title', '')]
os.makedirs(SP + 'dropped25', exist_ok=True)
for k in drop:
    shutil.move(O + k, SP + 'dropped25/' + k); del B[k]; c['order'].remove(k)
for nk in ('arch_old', 'arch_f25'): c['notes'].pop(nk, None)
arch_min_y = min(v['y'] for v in B.values() if 'archive' in v.get('title', ''))
mains = [v for v in B.values() if 'archive' not in v.get('title', '') and v.get('title', '') not in [n[1] for n in NEW]]
y = max(v['y'] + v['h'] for v in mains) + 2700
titles = {'B': 'F30 + F29 (Design 1): sign-in wall, Ask to join, join form, join review, Tenant IDs in your Drive · founder GO 18 Oct', 'A': 'F28 app (Design 1): Add a hostel, Your hostel on Hostelzy, Explore, Me, Rewards', 'C': 'F28 web + console (Design 1): app/list/, poster, Listed segments, Claims'}
for row in 'BAC':
    items = [n for n in NEW if n[4] == row]
    x = 0; hmax = max(n[3] for n in items)
    c['notes']['r25' + row] = {'kind': 'title1', 'maxW': 8000, 'text': titles[row], 'w': 240, 'x': 0, 'y': y - 300}
    for name, tt, w, h, _ in items:
        B[name] = {'x': x, 'y': y, 'w': w, 'h': h, 'title': tt}; c['order'].append(name); x += w + 80
    y += hmax + 420
json.dump(c, open(O + 'canvas.json', 'w'), ensure_ascii=False, indent=1)
cnt = {'main': 0, 'variant': 0, 'dark': 0, 'not': 0, 'arch': 0}
for v in B.values():
    t = v.get('title', '')
    if 'archive' in t: cnt['arch'] += 1
    elif t.startswith('[variant'): cnt['variant'] += 1
    elif t.startswith('[dark]'): cnt['dark'] += 1
    elif t.startswith('[not counted'): cnt['not'] += 1
    else: cnt['main'] += 1
files = len([f for f in os.listdir(O)])
print(len(B), cnt, 'files', files, 'new', len(NEW), 'dropped', len(drop), 'arch_min_y', arch_min_y, 'rows_end', y)
