# F28 boards for the main canvas (Design 2, 2026-10-18).
# Reads the v24 main-canvas boards, writes docs/design/v25/project/*.dc.html + parts/f28.json.
import re, os, json, random
HERE = os.path.dirname(os.path.abspath(__file__))
P = os.path.join(HERE, '..', '..', 'main-canvas', 'project') + '/'
O = os.path.join(HERE, '..', 'project') + '/'
PARTS = os.path.join(HERE, '..', 'parts') + '/'
os.makedirs(O, exist_ok=True); os.makedirs(PARTS, exist_ok=True)
CANVAS = json.load(open(P + 'canvas.json'))

def rd(f): return open(P + f).read()
def rep(s, old, new, n=1):
    c = s.count(old)
    assert c == n, (old[:80], c)
    return s.replace(old, new)
def title(s, t): return re.sub(r'<title>.*?</title>', '<title>' + t + '</title>', s, count=1)

BOARDS = {}   # file -> dict(x, y, w, h, title)
ORDER = []
def wr(name, s, t, w, h, pos=None):
    s = title(s, t)
    open(O + name, 'w').write(s)
    BOARDS[name] = {'w': w, 'h': h, 'title': t, **({'x': pos[0], 'y': pos[1]} if pos else {})}
    ORDER.append(name)

# ---------- shared pieces
I = {
 'arrow': '<path d="M5 12h14"/><path d="m12 5 7 7-7 7"/>',
 'check': '<path d="M20 6 9 17l-5-5"/>',
 'x': '<path d="M18 6 6 18M6 6l12 12"/>',
 'msg': '<path d="M21 12a8 8 0 0 1-11.6 7.1L4 20l1.1-4.6A8 8 0 1 1 21 12z"/>',
 'plus': '<path d="M12 5v14M5 12h14"/>',
 'clock': '<circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/>',
 'pin': '<path d="M20 10c0 5-5.5 10.2-7.4 11.8a1 1 0 0 1-1.2 0C9.5 20.2 4 15 4 10a8 8 0 0 1 16 0"/><circle cx="12" cy="10" r="3"/>',
 'chev': '<path d="m9 18 6-6-6-6"/>',
 'back': '<path d="m15 18-6-6 6-6"/>',
 'money': '<path d="M3 7h18v12H3z"/><path d="M16 13h2"/><path d="M5 7l11-3v3"/>',
 'camera': '<path d="M4 8h3l2-3h6l2 3h3v11H4z"/><circle cx="12" cy="13" r="3.5"/>',
 'home': '<path d="M15 21v-8H9v8"/><path d="M3 10 12 3l9 7v11H3z"/>',
 'reload': '<path d="M21 12a9 9 0 1 1-3-6.7L21 8M21 3v5h-5"/>',
 'out': '<path d="M15 3h6v18h-6M10 17l5-5-5-5M15 12H3"/>',
 'phone': '<path d="M5 3h4l2 5-2.5 1.5a11 11 0 0 0 6 6L16 13l5 2v4a2 2 0 0 1-2 2A16 16 0 0 1 3 5a2 2 0 0 1 2-2"/>',
 'gift': '<path d="M4 11h16v10H4zM2 7h20v4H2zM12 7v14"/><path d="M12 7C10 3 6 3 6 6s6 1 6 1 6 2 6-1-4-3-6 1"/>',
 'star': '<path d="m12 3 2.8 5.7 6.2.9-4.5 4.4 1 6.2L12 17.3 6.5 20.2l1-6.2L3 9.6l6.2-.9z"/>',
 'dl': '<path d="M12 3v12M6 9l6 6 6-6M4 21h16"/>',
 'map': '<path d="M9 4 3 6v14l6-2 6 2 6-2V4l-6 2z"/><path d="M9 4v14M15 6v14"/>',
}
def ico(k, sz=18): return '<svg width="%d" height="%d" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="square" style="flex: none;">%s</svg>' % (sz, sz, I[k])
def btn(text, kind='red', icon='arrow', h=52, fs=15, extra=''):
    st = {'red': 'background: var(--ac); color: var(--ai);', 'ink': 'background: var(--tx); color: var(--bg);', 'out': 'border: 2px solid var(--tx); color: var(--tx);', 'mu': 'border: 2px solid var(--dv); color: var(--mu);'}[kind]
    return '<button style="width: 100%%; height: %dpx; padding: 0 16px; display: flex; justify-content: space-between; align-items: center; gap: 10px; font-weight: 800; font-size: %dpx; text-decoration: none; %s%s">%s%s</button>' % (h, fs, st, extra, text, ico(icon) if icon else '')
def kick(t, extra=''): return '<span style="font-size: 11px; font-weight: 600; letter-spacing: .1em; text-transform: uppercase; line-height: 1.3; color: var(--mu);%s">%s</span>' % (extra, t)
def tag(t, kind='mu'):
    st = {'mu': 'border: 1px solid var(--dv); color: var(--mu);', 'red': 'background: var(--ab); color: var(--ad); border: 1px solid var(--ab);', 'ink': 'background: var(--tx); color: var(--bg); border: 1px solid var(--tx);', 'gn': 'background: var(--gb); color: var(--gn); border: 1px solid var(--gb);'}[kind]
    return '<span style="flex: none; padding: 3px 7px; font-size: 11px; font-weight: 800; letter-spacing: .05em; text-transform: uppercase; white-space: nowrap; %s">%s</span>' % (st, t)
UNV = '<span style="flex: none; display: inline-flex; align-items: center; padding: 3px 8px; border: 2px solid var(--mu); color: var(--mu); font-size: 11px; font-weight: 800; letter-spacing: .08em;">UNVERIFIED</span>'
VER = '<span style="flex: none; display: inline-flex; gap: 4px; align-items: center; padding: 3px 7px; background: var(--vf); color: #ffffff; font-size: 10px; font-weight: 800; letter-spacing: .08em;">' + ico('check', 12) + 'VERIFIED</span>'
def mu(t, fs=13, extra=''): return '<span style="font-size: %dpx; color: var(--mu); line-height: 1.45;%s">%s</span>' % (fs, extra, t)
def label(t): return '<b style="font-size: 13px;">%s</b>' % t
def inp(v, ph='', h=48, extra=''):
    return '<input value="%s" placeholder="%s" style="width: 100%%; min-width: 0; height: %dpx; padding: 0 12px; border: 2px solid var(--tx); background: var(--bg); font-size: 15px; font-weight: 400;%s">' % (v, ph, h, extra)
def field(l, v, ph='', h=48, hint=''):
    return '<label style="display: grid; gap: 6px; font-size: 13px; font-weight: 800;">%s%s%s</label>' % (l, inp(v, ph, h), ('<span style="font-size: 12px; font-weight: 400; color: var(--mu);">%s</span>' % hint) if hint else '')
def seg(opts, on, h=40, fs=13):
    out = '<div style="display: grid; grid-template-columns: repeat(%d, minmax(0, 1fr)); border: 2px solid var(--tx);">' % len(opts)
    for o in opts:
        st = 'background: var(--tx); color: var(--bg);' if o == on else 'background: transparent; color: var(--tx);'
        out += '<button style="height: %dpx; padding: 0 4px; font-size: %dpx; font-weight: 600; text-align: center; %s">%s</button>' % (h - 4, fs, st, o)
    return out + '</div>'
def chips(opts, on):
    out = '<div style="display: flex; flex-wrap: wrap; gap: 6px;">'
    for o in opts:
        st = 'border: 1px solid var(--tx); background: var(--tx); color: var(--bg);' if o in on else 'border: 1px solid var(--dv); background: transparent; color: var(--tx);'
        out += '<button style="height: 36px; padding: 0 12px; font-size: 13px; font-weight: 600; %s">%s</button>' % (st, o)
    return out + '</div>'
def switch(on):
    return ('<span style="width: 44px; height: 24px; flex: none; border: 2px solid var(--tx); display: flex; justify-content: %s; padding: 2px; background: %s;"><span style="width: 16px; height: 16px; background: %s;"></span></span>'
            % ('flex-end' if on else 'flex-start', 'var(--tx)' if on else 'transparent', 'var(--bg)' if on else 'var(--tx)'))
def switch_row(t, on, sub=''):
    s = ('<div style="display: flex; justify-content: space-between; align-items: center; gap: 12px; font-size: 15px; font-weight: 600;"><span style="display: grid; gap: 1px;">%s%s</span>%s</div>'
         % (t, ('<span style="font-size: 12px; font-weight: 400; color: var(--mu);">%s</span>' % sub) if sub else '', switch(on)))
    return s
PHOTO = 'background: repeating-linear-gradient(135deg, var(--sf) 0 8px, var(--bg) 8px 16px); border: 1px solid var(--hl);'

HEAD_LIGHT = rd('f26-unverified.dc.html')
HEAD_LIGHT = HEAD_LIGHT[:HEAD_LIGHT.index('<div data-hz=""')]
TAIL = '''
</x-dc>
<script type="text/x-dc" data-dc-script data-props='{"dark": {"editor": "boolean", "default": %s}, "$preview": {"width": %d, "height": %d}}'>
class Component extends DCLogic {
  renderVals() {
    const out = { theme: (this.props.dark ?? false) ? 'dark' : 'light' };
    return out;
  }
}
</script>
</body>
</html>
'''
def page(body, w=390, h=844, dark=False):
    theme = 'dark' if dark else '{{theme}}'
    return (HEAD_LIGHT + '<div data-hz="" data-theme="%s" style="width: %dpx; height: %dpx; position: relative; background: var(--bg); color: var(--tx); font-family: Archivo, system-ui, sans-serif; display: flex; flex-direction: column; overflow: hidden;">' % (theme, w, h)
            + body + '</div>' + TAIL % ('true' if dark else 'false', w, h))

# nav bars copied from the main boards
_me = rd('me.dc.html'); TENANT_NAV_ME = _me[_me.index('<nav'):_me.index('</nav>') + 6]
_ex = rd('r-explore.dc.html'); TENANT_NAV_EXPLORE = _ex[_ex.index('<nav'):_ex.index('</nav>') + 6]
_st = rd('w3-stayNotYet.dc.html'); RES_NAV = _st[_st.index('<nav'):_st.index('</nav>') + 6]
RES_NAV_ME = RES_NAV.replace('color: var(--mu);">' + ico('phone', 20) if False else 'XX', 'XX')  # placeholder, replaced below
# make "Me" active on the resident nav
RES_NAV_ME = RES_NAV[:RES_NAV.rindex('<button')] + RES_NAV[RES_NAV.rindex('<button'):].replace('color: var(--mu);', 'color: var(--tx); box-shadow: inset 0 3px 0 var(--ac);', 1)

def header(kicker, h1, back=True):
    b = '<button aria-label="Back" style="width: 44px; height: 44px; flex: none; display: grid; place-items: center; border: 1px solid var(--dv);">' + ico('back', 20) + '</button>' if back else ''
    return ('<div style="flex: none; padding: 12px 16px 12px; display: flex; gap: 12px; align-items: flex-start;">%s<div style="flex-grow: 1; display: grid; gap: 2px;">%s<b style="display: block; font-size: 30px; line-height: 1.02; letter-spacing: -.025em;">%s</b></div></div>'
            % (b, kick(kicker) if kicker else '', h1))

# ================= S92 addHostel
def photo_row(n_done=1):
    out = '<div style="display: flex; gap: 8px;">'
    for i in range(3):
        if i < n_done:
            out += '<span style="width: 60px; height: 60px; position: relative; %s"><span style="position: absolute; left: 4px; bottom: 3px; font-size: 10px; color: var(--mu);">gate</span></span>' % PHOTO
        else:
            out += '<button aria-label="Add a photo" style="width: 60px; height: 60px; display: grid; place-items: center; border: 2px dashed var(--dv); color: var(--tx);">' + ico('camera', 20) + '</button>'
    return out + '<span style="align-self: center; font-size: 12px; color: var(--mu);">%d of 3</span></div>' % n_done
def pin_block(area='Madhapur'):
    return ('<div style="height: 72px; position: relative; background: repeating-linear-gradient(0deg, var(--sf) 0 1px, transparent 1px 24px), repeating-linear-gradient(90deg, var(--sf) 0 1px, var(--bg) 1px 24px); border: 2px solid var(--tx);">'
            '<span style="position: absolute; left: 50%; top: 50%; transform: translate(-50%, -100%); color: var(--ad);">' + ico('pin', 30) + '</span>'
            '<span style="position: absolute; left: 8px; top: 6px; font-size: 12px; font-weight: 800;">' + area + '</span>'
            '<button style="position: absolute; right: 6px; bottom: 6px; height: 30px; padding: 0 10px; display: flex; gap: 6px; align-items: center; background: var(--bg); border: 1px solid var(--dv); font-size: 12px; font-weight: 800;">' + ico('pin', 14) + 'Use my location</button></div>')

def add_hostel(partner=False, dark=False):
    who = seg(['I live here', 'I’m a Hostelzy partner'], 'I’m a Hostelzy partner' if partner else 'I live here', 44)
    if partner:
        rent = ('<div style="display: grid; gap: 6px;">' + label('Rent per month') + '<div style="display: grid; grid-template-columns: 1fr 1fr; gap: 8px;">' + inp('₹6,500', 'From', 44) + inp('₹8,500', 'To', 44) + '</div></div>')
        code = inp('HZ-PART-1', 'Partner code', 44)
        kicker = 'Partner · ₹20 per hostel'
    else:
        rent = ('<div style="display: grid; gap: 6px;">' + label('What do you pay?') + '<div style="display: flex; align-items: center; gap: 8px;">' + inp('₹7,500', '₹ per month', 44, ' max-width: 150px;') + mu('a month', 13) + '</div></div>')
        code = ''
        kicker = '₹200 when verified'
    body = (header(kicker, 'Add a hostel')
        + '<div style="flex-grow: 1; overflow: hidden; border-top: 2px solid var(--tx); padding: 8px 16px; display: grid; gap: 7px; align-content: start;">'
        + '<div style="display: grid; gap: 6px;">' + label('Who are you?') + ('<div style="display: grid; grid-template-columns: minmax(0, 1fr) 112px; gap: 8px;">' + who + code + '</div>' if code else who) + '</div>'
        + field('Hostel name', 'Sri Balaji Men’s PG', 'Name on the gate', 44)
        + '<div style="display: grid; gap: 6px;">' + label('Gate photo') + photo_row() + '</div>'
        + '<div style="display: grid; gap: 6px;">' + label('Pin') + pin_block() + '</div>'
        + '<div style="display: grid; grid-template-columns: 1fr; gap: 6px;">' + label('For') + seg(['Men', 'Women', 'Co-living'], 'Men', 38) + '</div>'
        + rent
        + '<div style="display: grid; grid-template-columns: 1fr auto; gap: 12px; align-items: end;"><div style="display: grid; gap: 6px;">' + label('Sharing') + seg(['1', '2', '3', '4+'], '2', 38) + '</div><div style="display: grid; gap: 6px; padding-bottom: 6px;">' + label('Food included') + switch(True) + '</div></div>'
        + '<div style="display: grid; grid-template-columns: 1fr 1fr; gap: 8px;">' + field('Owner’s name · required', 'Venkat Rao', '', 44) + field('Owner’s phone · required', '+91 98490 11223', '', 44) + '</div>'
        + '</div>'
        + '<div style="flex: none; border-top: 2px solid var(--tx); padding: 10px 16px 16px; display: grid; gap: 6px;">'
        + btn('Add this hostel', 'red', 'arrow', 52)
        + '</div>')
    return page(body, dark=dark)

Y0 = max(b['y'] for b in CANVAS['boards'].values()) + 1200     # one new row below everything
GAP = 80; VGAP = 120
X = 0
def slot(w):
    global X
    x = X; X += w + GAP; return x

# S92: main (+dark, partner as variants)
x = slot(390)
wr('f28-addHostel.dc.html', add_hostel(), '[S92] addHostel · Add a hostel: name, gate photo, pin, for, what you pay, sharing, food, owner’s name + phone (required), I live here · New (F28)', 390, 844, (x, Y0))
wr('f28-addHostel-dark.dc.html', add_hostel(dark=True), '[dark] addHostel · Add a hostel (dark) · New (F28)', 390, 844, (x, Y0 + 844 + VGAP))
x2 = slot(390)
wr('f28-addHostelPartner.dc.html', add_hostel(partner=True), '[variant of S92] addHostel · Partner: partner code typed once (remembered on the phone), rent as a range, ₹20 after the team check · New (F28)', 390, 844, (x2, Y0 + 844 + VGAP))
X = x2  # partner variant sits under the next slot; keep S93 right after it
X = x2 + 390 + GAP

# ================= S93 myAdd
STEPS = ['Added', 'Owner asked', 'Owner agreed', 'Verified', '₹200 paid']
def steps(done, subs, current=None, stopped=False):
    out = '<div style="border-top: 2px solid var(--tx);">'
    for i, name in enumerate(STEPS):
        n = i + 1
        if n <= done:
            dot = '<b style="width: 28px; height: 28px; display: grid; place-items: center; background: var(--tx); color: var(--bg);">' + ico('check', 14) + '</b>'
            tcol = 'var(--tx)'
        elif n == done + 1 and not stopped:
            dot = '<b style="width: 28px; height: 28px; display: grid; place-items: center; border: 2px solid var(--ac); color: var(--ad); font-size: 13px;">%d</b>' % n
            tcol = 'var(--tx)'
        else:
            dot = '<b style="width: 28px; height: 28px; display: grid; place-items: center; border: 1px solid var(--dv); color: var(--mu); font-size: 13px;">%d</b>' % n
            tcol = 'var(--mu)'
        sub = subs.get(n, '')
        out += ('<div style="display: grid; grid-template-columns: 28px minmax(0, 1fr); gap: 12px; align-items: center; padding: 9px 0; border-bottom: 1px solid var(--hl);">%s<span style="display: grid; gap: 1px;"><b style="font-size: 15px; color: %s;">%s</b>%s</span></div>'
                % (dot, tcol, name, ('<span style="font-size: 12px; color: var(--mu);">%s</span>' % sub) if sub else ''))
    return out + '</div>'
def my_card(verified=False):
    return ('<div style="border: 2px solid var(--tx); padding: 10px; display: grid; gap: 4px;">'
            '<div style="height: 84px; position: relative; %s"><span style="position: absolute; left: 8px; bottom: 6px; font-size: 11px; color: var(--mu);">photo 1 / 1 · by you</span></div>'
            '<div style="display: flex; gap: 8px; align-items: center; flex-wrap: wrap;"><b style="font-size: 16px;">Sri Balaji Men’s PG</b>%s</div>'
            '%s</div>') % (PHOTO, VER if verified else UNV,
                            mu('Men · Madhapur · ₹7,500/mo · 2 sharing · food included', 13) if not verified else mu('Men · Madhapur · 9 free · from ₹7,500/mo', 13))
def my_add(state='added', dark=False):
    # state: added | asked | agreed | verified | paid | waiting | queued   (F31 Rule A: labels + ticks, values/states only)
    honest = 'Paid when the owner agrees and Hostelzy verifies'
    kicker = 'Added by you · 18 Oct'
    verified_card = state in ('verified', 'paid', 'queued')
    status = ''
    if state == 'added':
        st = steps(1, {1: '18 Oct, 4:12 pm'})
        cta = btn('Send to your owner', 'red', 'msg')
    elif state == 'asked':
        st = steps(2, {1: '18 Oct', 2: 'Sent 18 Oct · no reply yet'})
        cta = btn('Ask again', 'red', 'msg')
    elif state == 'agreed':
        st = steps(3, {1: '18 Oct', 2: '18 Oct', 3: 'Venkat Rao · 22 Oct', 4: 'Visit by 29 Oct'})
        cta = ('<div style="display: grid; gap: 6px;">' + label('UPI ID for the ₹200') + '<div style="display: grid; grid-template-columns: 1fr auto; gap: 8px;">' + inp('ravi.teja@upi', 'UPI ID') + '<button style="height: 48px; padding: 0 16px; font-weight: 800; font-size: 15px; background: var(--tx); color: var(--bg);">Save</button></div></div>')
    elif state == 'verified':
        st = steps(4, {1: '18 Oct', 2: '18 Oct', 3: '22 Oct', 4: '27 Oct', 5: '₹200 to ravi.teja@upi · 5 Nov'})
        cta = btn('See the hostel', 'out', 'arrow')
    elif state == 'paid':
        st = steps(5, {1: '18 Oct', 2: '18 Oct', 3: '22 Oct', 4: '27 Oct', 5: '<span style="color: var(--gn); font-weight: 800;">₹200 · 5 Nov · ravi.teja@upi</span>'})
        cta = btn('See Stay Rewards', 'out', 'gift')
    elif state == 'waiting':
        kicker = 'Added by you · 18 Oct · 60 days'
        st = steps(2, {1: '18 Oct', 2: 'Sent 18 Oct, 21 Oct, 2 Nov · no reply'}, stopped=True)
        cta = btn('Ask again', 'out', 'msg'); status = 'Still waiting'
    elif state == 'queued':
        st = steps(4, {1: '18 Oct', 2: '18 Oct', 3: '22 Oct', 4: '27 Oct', 5: 'Queued · ₹2,000 monthly cap reached · 5 Dec'})
        cta = btn('See the hostel', 'out', 'arrow')
    body = (header(kicker, 'Your hostel on Hostelzy')
        + '<div style="flex-grow: 1; overflow: hidden; border-top: 2px solid var(--tx); padding: 12px 16px; display: grid; gap: 10px; align-content: start;">'
        + my_card(verified_card)
        + kick('As tenants see it' if not verified_card else 'Live')
        + st
        + (('<b style="font-size: 15px;">%s</b>' % status) if status else '')
        + '</div>'
        + '<div style="flex: none; border-top: 2px solid var(--tx); padding: 10px 16px 14px; display: grid; gap: 8px;">'
        + cta
        + (mu(honest, 12, ' font-weight: 600; color: var(--tx);') if state in ('added', 'asked', 'waiting', 'agreed') else '')
        + '</div>')
    return page(body, dark=dark)

x = slot(390)
wr('f28-myAdd.dc.html', my_add('added'), '[S93] myAdd · Your hostel on Hostelzy: the card as tenants see it, 5 steps (Added ✓), Send to your owner (WhatsApp), one honest line (F31 Rule A) · New (F28)', 390, 844, (x, Y0))
wr('f28-myAdd-dark.dc.html', my_add('added', dark=True), '[dark] myAdd · Your hostel on Hostelzy (dark) · New (F28)', 390, 844, (x, Y0 + 844 + VGAP))
variants = [('asked', 'f28-myAddAsked.dc.html', '[variant of S93] myAdd · Owner asked: sent, no reply, Ask again (after 3 days) · New (F28)'),
            ('agreed', 'f28-myAddAgreed.dc.html', '[variant of S93] myAdd · Owner agreed: visit date, UPI ID asked once · New (F28)'),
            ('verified', 'f28-myAddVerified.dc.html', '[variant of S93] myAdd · Verified: card goes VERIFIED, ₹200 due on the 5th · New (F28)'),
            ('paid', 'f28-myAddPaid.dc.html', '[variant of S93] myAdd · ₹200 paid by UPI · New (F28)'),
            ('waiting', 'f28-myAddWaiting.dc.html', '[variant of S93] myAdd · Still waiting (60 days): steps stop at Owner asked, Ask again · New (F28)'),
            ('queued', 'f28-myAddQueued.dc.html', '[variant of S93] myAdd · Queued: monthly ₹2,000 cap reached, pays next month · New (F28)')]
for st, f, t in variants:
    xv = slot(390)
    wr(f, my_add(st), t, 390, 844, (xv, Y0 + 844 + VGAP))

# ================= W8 app/list/ (web page, 390 wide like wR)
_wr = rd('wR.dc.html')
WEB_HEAD = _wr[_wr.index('<header'):_wr.index('</header>') + 9]
WEB_FOOT = _wr[_wr.index('<footer'):_wr.index('</footer>') + 9]
def webpage(inner, h):
    return page('<main style="padding: 24px 16px 40px; font-size: 16px; line-height: 1.55; overflow: hidden;">' + WEB_HEAD + inner + WEB_FOOT + '</main>', 390, h)
def wbtn(t, red=True):
    st = 'background: var(--ac); color: #fff; border: 2px solid var(--ac);' if red else 'background: transparent; color: var(--tx); border: 2px solid var(--tx);'
    return '<a href="#" style="display: block; text-align: center; text-decoration: none; font-weight: 800; padding: 14px 16px; margin: 10px 0; %s">%s</a>' % (st, t)
form = ('<h1 style="font-size: 30px; line-height: 1.15; font-weight: 900; letter-spacing: -.02em; margin: 0 0 6px;">List your PG on Hostelzy, free</h1>'
        '<p style="margin: 0 0 16px; font-size: 17px; line-height: 1.45;">Free · Hyderabad</p>'
        '<div style="display: grid; gap: 12px;">'
        + field('Hostel name', 'Sri Balaji Men’s PG', 'Name on the gate')
        + field('Your name', 'Venkat Rao')
        + field('Phone (WhatsApp)', '+91 98490 11223')
        + field('Area', 'Madhapur', 'Area or landmark')
        + '<div style="display: grid; gap: 6px;">' + label('Rent per month') + '<div style="display: grid; grid-template-columns: 1fr 1fr; gap: 8px;">' + inp('₹7,000', 'From') + inp('₹9,000', 'To') + '</div></div>'
        + '<div style="display: grid; gap: 6px;">' + label('For') + seg(['Men', 'Women', 'Co-living'], 'Men', 44) + '</div>'
        + switch_row('Food included', True)
        + '<div style="display: grid; gap: 6px;">' + label('Photos') + photo_row(0) + '</div>'
        + '</div>'
        + wbtn('Send to Hostelzy')
        + '<p style="color: var(--mu); font-size: 14px; margin: 0 0 12px; line-height: 1.5;">We’ll call you within 2 days to confirm.</p>'
        + '<p style="color: var(--mu); font-size: 13px; margin: 0;">By sending you agree to the <a href="#" style="color: var(--mu); font-weight: 700;">terms</a>.</p>')
x = slot(390)
wr('f28-wList.dc.html', webpage(form, 1300), '[W8] app/list/ · List your PG on Hostelzy, free: name, your name, phone, area, rent from–to, for, food, photos → Send to Hostelzy; “We’ll call you within 2 days” · New (F28)', 390, 1300, (x, Y0))
sent = ('<h1 style="font-size: 30px; line-height: 1.15; font-weight: 900; letter-spacing: -.02em; margin: 0 0 6px;">Thanks, Venkat</h1>'
        '<p style="margin: 0 0 16px; font-size: 17px; line-height: 1.45;">We’ll call you on +91 98490 11223 within 2 days to confirm Sri Balaji Men’s PG.</p>'
        '<div style="border-top: 2px solid var(--tx);">'
        + ''.join('<div style="display: grid; grid-template-columns: 28px minmax(0, 1fr); gap: 12px; align-items: center; padding: 12px 0; border-bottom: 1px solid var(--hl);"><b style="width: 28px; height: 28px; display: grid; place-items: center; %s font-size: 13px;">%s</b><span style="display: grid; gap: 1px;"><b style="font-size: 15px;">%s</b><span style="font-size: 13px; color: var(--mu);">%s</span></span></div>'
                  % (('background: var(--tx); color: var(--bg);' if i == 0 else 'border: 1px solid var(--dv); color: var(--mu);'), (ico('check', 14) if i == 0 else str(i + 1)), a, b)
                  for i, (a, b) in enumerate([('Request sent', 'Today, 4:12 pm'), ('We call you', 'Within 2 days'), ('Your PG is on the app', 'After the call')]))
        + '</div>'
        + wbtn('Get the app (Android test build)', False)
        + '<p style="color: var(--mu); font-size: 14px; margin: 0 0 12px; line-height: 1.5;">Nothing is live yet.</p>')
wr('f28-wListSent.dc.html', webpage(sent, 900), '[variant of W8] app/list/ · Sent: “We’ll call you within 2 days to confirm”, 3 steps, no “Listed!” · New (F28)', 390, 900, (x, Y0 + 1300 + VGAP))

# ================= W9 poster (A4 794×1123)
def qr(n=25, px=300, seed=28):
    random.seed(seed)
    cells = []
    def finder(r, c):
        return (r < 7 and c < 7) or (r < 7 and c >= n - 7) or (r >= n - 7 and c < 7)
    def finder_on(r, c):
        for (r0, c0) in [(0, 0), (0, n - 7), (n - 7, 0)]:
            if r0 <= r < r0 + 7 and c0 <= c < c0 + 7:
                rr, cc = r - r0, c - c0
                if rr in (0, 6) or cc in (0, 6): return True
                if 2 <= rr <= 4 and 2 <= cc <= 4: return True
                return False
        return False
    for r in range(n):
        for c in range(n):
            if finder(r, c): on = finder_on(r, c)
            elif (r == 7 and c < 8) or (c == 7 and r < 8) or (r == 7 and c >= n - 8) or (c == n - 8 and r < 8) or (r >= n - 8 and c == 7) or (r == n - 8 and c < 8): on = False
            elif r == 6 or c == 6: on = (r + c) % 2 == 0
            else: on = random.random() < 0.45
            cells.append('<span style="background: %s;"></span>' % ('#201e1d' if on else 'transparent'))
    return '<div aria-label="QR code" style="width: %dpx; height: %dpx; display: grid; grid-template-columns: repeat(%d, minmax(0, 1fr));">%s</div>' % (px, px, n, ''.join(cells))
poster = ('<div style="flex-grow: 1; padding: 56px 64px 44px; display: flex; flex-direction: column; gap: 26px;">'
          '<div style="display: flex; justify-content: space-between; align-items: center;"><span style="display: flex; align-items: center; gap: 10px;"><span style="width: 18px; height: 18px; background: var(--ac); display: inline-block;"></span><span style="font-weight: 800; font-size: 32px; letter-spacing: -.02em;">Hostelzy</span></span><span style="font-size: 18px; font-weight: 600; color: var(--mu);">For PG and hostel owners · Hyderabad</span></div>'
          '<div style="border-top: 4px solid var(--tx); padding-top: 26px; font-weight: 800; font-size: 76px; line-height: .98; letter-spacing: -.035em; color: var(--ac);">Get tenants<br>from Hostelzy.<br>Free listing.</div>'
          '<div style="display: grid; grid-template-columns: auto minmax(0, 1fr); gap: 40px; align-items: center;">'
          '<div style="padding: 12px; background: #ffffff; border: 2px solid var(--tx); flex: none;">' + qr() + '</div>'
          '<div style="display: grid; gap: 18px;">'
          + ''.join('<div style="display: grid; grid-template-columns: 44px minmax(0, 1fr); gap: 16px; align-items: start;"><b style="width: 44px; height: 44px; display: grid; place-items: center; background: var(--tx); color: var(--bg); font-size: 22px;">%d</b><span style="display: grid; gap: 2px;"><b style="font-size: 26px; line-height: 1.1;">%s</b><span style="font-size: 17px; color: var(--mu); line-height: 1.35;">%s</span></span></div>' % (i + 1, a, b)
                    for i, (a, b) in enumerate([('Scan the code', 'Or open farhath.me/hostelzy/app/list/'), ('Fill in your PG', 'Name, area, rent, men or women. 2 minutes.'), ('We call you within 2 days', 'Then your PG shows to tenants looking nearby.')]))
          + '</div></div>'
          '<div style="display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 0; border: 2px solid var(--tx); margin-top: 8px;">'
          + ''.join('<div style="padding: 18px 20px; display: grid; gap: 4px;%s"><b style="font-size: 22px; line-height: 1.1;">%s</b><span style="font-size: 15px; color: var(--mu); line-height: 1.35;">%s</span></div>' % (' border-left: 2px solid var(--tx);' if i else '', a, b)
                    for i, (a, b) in enumerate([('Free, always', 'No listing fee, no commission, no brokers.'), ('Tenants nearby', 'People searching your area see your PG with its rent range.'), ('Verified badge', 'One visit from our team. Then tenants can hold a bed.')]))
          + '</div>'
          '<div style="margin-top: auto; border-top: 2px solid var(--tx); padding-top: 18px; display: flex; justify-content: space-between; align-items: center; gap: 24px;"><span style="font-size: 22px; font-weight: 800;">No fees. No commission. No brokers.</span><span style="font-size: 16px; color: var(--mu);">Questions? WhatsApp Hostelzy · farhath.me/hostelzy/app/</span></div>'
          '</div>')
x = slot(794)
wr('f28-wPoster.dc.html', page(poster, 794, 1123), '[W9] app/list/poster.html · Printable A4 poster: “Get tenants from Hostelzy. Free listing.”, QR to app/list/, 3 steps · New (F28)', 794, 1123, (x, Y0))

# ================= H1 filters: Verified only switch (updated in place)
s = rd('r-filters.dc.html')
old = '<div style="display: flex; justify-content: space-between; align-items: center; font-size: 15px; font-weight: 600;">Food included<span style="width: 44px; height: 24px; flex: none; border: 2px solid var(--tx); display: flex; justify-content: flex-start; padding: 2px; background: transparent;"><span style="width: 16px; height: 16px; background: var(--tx);"></span></span></div>'
assert s.count(old) == 1, 'food row'
s = s.replace(old, old + switch_row('Verified only', False))
wr('r-filters.dc.html', s, '[H1] filters sheet · For, Room, Budget (Any), Food included, Verified only (off) · Updated (F28)', 390, 844, (CANVAS['boards']['r-filters.dc.html']['x'], CANVAS['boards']['r-filters.dc.html']['y']))

# ================= S8 explore variant: first-visit hint, verified then listed, end row
s = rd('f26-exploreUnv.dc.html')
a = '<div style="flex-grow: 1; overflow: hidden; border-top: 2px solid var(--dv); padding-top: 14px;">'
hint = ('<div style="margin: 0 16px 12px; padding: 8px 12px; background: var(--sf); display: grid; grid-template-columns: minmax(0, 1fr) 20px; gap: 10px; align-items: center; font-size: 13px; line-height: 1.4;">'
        '<span><b>Verified first</b> · then listed</span>'
        '<button aria-label="Hide this hint" style="width: 20px; height: 20px; display: grid; place-items: center; color: var(--mu);">' + ico('x', 14) + '</button></div>')
s = rep(s, a, a.replace('padding-top: 14px', 'padding-top: 12px') + hint)
s = s.replace('height: 150px; position: relative;', 'height: 104px; position: relative;', 2)
s = rep(s, 'Hyderabad · 18 beds free now · 12 verified · 84 listed', 'Madhapur · 18 beds free now · 12 verified · 84 listed')
endrow = ('<button style="margin: 0 16px; width: calc(100% - 32px); padding: 12px 14px; border: 2px solid var(--tx); display: flex; justify-content: space-between; align-items: center; gap: 10px;">'
          '<span style="display: grid; gap: 1px;"><b style="font-size: 15px;">Can’t find your PG? <span style="color: var(--ad);">Add it</span></b>' + mu('₹200 when verified', 12) + '</span>' + ico('plus', 18) + '</button>')
i = s.rindex('</div>', 0, s.index('<nav'))
s = s[:i] + endrow + s[i:]
x = slot(390)
wr('f28-explore.dc.html', s, '[variant of S8] explore · First-visit line “Verified first · then listed”, verified cards then listed ones, end row “Can’t find your PG? Add it” · New (F28)', 390, 844, (x, Y0))

# ================= S79 me: Add a hostel row (updated in place)
s = rd('me.dc.html')
k = '<b style="font-size: 16px;">Reminders</b>'
i = s.rindex('<button style="width: 100%; display: grid; grid-template-columns: 36px', 0, s.index(k))
row = ('<button style="width: 100%; display: grid; grid-template-columns: 36px minmax(0, 1fr) 16px; gap: 12px; align-items: center; padding: 12px 16px; border-bottom: 1px solid var(--hl);">'
       '<span style="width: 36px; height: 36px; display: grid; place-items: center; background: var(--sf);">' + ico('plus') + '</span>'
       '<span style="display: grid; gap: 1px;"><b style="font-size: 16px;">Add a hostel</b><span style="font-size: 13px; color: var(--mu);">₹200 when verified</span></span>' + ico('chev', 16) + '</button>')
s = s[:i] + row + s[i:]
wr('me.dc.html', s, '[S79] me · Add a hostel row (becomes “Your hostel” → S93 once one exists); no Saved / Holds rows; Log out in red · Updated (F28)', 390, 844, (CANVAS['boards']['me.dc.html']['x'], CANVAS['boards']['me.dc.html']['y']))

# ================= T20 rStay not yet: Add my hostel button (updated in place)
s = rd('w3-stayNotYet.dc.html')
old = '<span style="font-size: 14px; color: var(--mu); line-height: 1.45;">Your stay isn’t on Hostelzy yet. Once Srinivas adds you, it shows here.</span></div>'
s = rep(s, old, '<b style="font-size: 16px;">Not on Hostelzy yet</b><div style="margin-top: 12px;">' + btn('Add my hostel', 'red', 'plus', 48, 14) + '</div></div>')
wr('w3-stayNotYet.dc.html', s, '[T20] rStay · “Not on Hostelzy yet” + Add my hostel (F31 Rule A: ≤ 6 words + one button) · Updated (F28)', 390, 844, (CANVAS['boards']['w3-stayNotYet.dc.html']['x'], CANVAS['boards']['w3-stayNotYet.dc.html']['y']))

# ================= S22 rewards variant: ₹200 / ₹20 rows
s = rd('rewards.dc.html')
old_card = s[s.index('<div style="margin: 0 16px; padding: 16px; background: var(--tx); color: var(--bg); display: grid; gap: 4px;">'):]
old_card = old_card[:old_card.index('</div>') + 6]
new_card = ('<div style="margin: 0 16px; padding: 16px; background: var(--tx); color: var(--bg); display: grid; gap: 4px;">' + kick('Member', ' color: var(--bg); opacity: .8;').replace('color: var(--mu);', '') +
            '<b style="font-size: 44px; line-height: 1;">₹100</b><span style="font-size: 14px;">off your next Hostelzy stay · 2-hour holds</span></div>')
s = s.replace(old_card, new_card)
a = s.index('<div style="padding: 20px 16px 6px; display: flex; justify-content: space-between; align-items: baseline; gap: 12px;">')
b = s.index('<div style="padding: 12px 16px;">', a)
def rrow(ic, t, sub, amt, done=True):
    dot = '<b style="width: 32px; height: 32px; display: grid; place-items: center; background: var(--tx); color: var(--bg);">' + ico(ic, 16) + '</b>' if done else '<b style="width: 32px; height: 32px; display: grid; place-items: center; background: var(--sf); color: var(--tx);">' + ico(ic, 16) + '</b>'
    return ('<div style="display: grid; grid-template-columns: 32px minmax(0, 1fr) auto; gap: 12px; align-items: center; padding: 12px 16px; border-bottom: 1px solid var(--hl);">%s<span style="display: grid; gap: 1px;"><b style="font-size: 15px;">%s</b><span style="font-size: 13px; color: var(--mu);">%s</span></span><b style="font-size: 16px; color: var(--gn);">%s</b></div>' % (dot, t, sub, amt))
earned = ('<div style="padding: 20px 16px 6px; display: flex; justify-content: space-between; align-items: baseline; gap: 12px;">' + kick('Hostels you added') + '<span style="font-size: 12px; font-weight: 800; color: var(--mu);">Paid by UPI on the 5th</span></div>'
          '<div style="border-top: 2px solid var(--tx);">'
          + rrow('home', 'Sri Balaji Men’s PG verified', 'Paid 5 Nov · ravi.teja@upi', '₹200')
          + rrow('home', 'Lakshmi Ladies Hostel listed', 'Partner HZ-PART-1 · checked 20 Oct · pays 5 Nov', '₹20', False)
          + '</div>'
          '<div style="padding: 20px 16px 6px;">' + kick('How to earn') + '</div>'
          '<div style="border-top: 2px solid var(--tx);">'
          + rrow('check', 'Move in through Hostelzy', '₹100 credit · done 14 Mar', '').replace('<b style="font-size: 16px; color: var(--gn);"></b>', '')
          + rrow('plus', 'Add a hostel', '₹200 when verified · one at a time', '', False).replace('<b style="font-size: 16px; color: var(--gn);"></b>', '')
          + '</div>')
s = s[:a] + earned + s[b:]
i = s.index('<div style="padding: 12px 16px;">'); j = s.index('</div>', i) + 6
s = s[:i] + '<div style="padding: 12px 16px;">' + btn('Add a hostel', 'out', 'plus') + '</div>' + s[j:]
x = slot(390)
wr('f28-rewards.dc.html', s, '[variant of S22] rewards · Hostels you added: ₹200 hostel verified (paid by UPI on the 5th), ₹20 partner listing · New (F28)', 390, 844, (x, Y0))

# ================= C14 segments
c14 = rd('f26-c14.dc.html')
def segrow(on, counts=('72', '48', '9', '3')):
    names = ['Listed', 'To call', 'To refresh', 'Partners']
    out = '<div style="display: flex; justify-content: space-between; align-items: center; gap: 12px;"><div style="display: flex; border: 2px solid var(--tx);">'
    for n, c in zip(names, counts):
        st = 'background: var(--tx); color: var(--bg);' if n == on else 'background: transparent; color: var(--tx);'
        out += '<button style="height: 40px; padding: 0 16px; font-size: 14px; font-weight: 800; white-space: nowrap; display: flex; gap: 8px; align-items: center; %s">%s<span style="font-size: 12px; font-weight: 600; opacity: .75;">%s</span></button>' % (st, n, c)
    out += '</div><button style="height: 40px; padding: 0 14px; display: flex; gap: 8px; align-items: center; font-weight: 800; font-size: 13px; border: 2px solid var(--tx);">' + ico('dl', 16) + 'Export CSV</button></div>'
    return out
MAIN_START = c14.index('<main')
MAIN_END = c14.index('</main>') + 7
def console(main_inner):
    return c14[:MAIN_START] + '<main style="min-width: 0; padding: 20px 24px; display: grid; gap: 16px; align-content: start;">' + main_inner + '</main>' + c14[MAIN_END:]
TH = '<th style="padding: 10px 12px; font-size: 12px; font-weight: 800; letter-spacing: .08em; text-transform: uppercase; color: var(--mu); text-align: left; border-bottom: 2px solid var(--tx);">%s</th>'
TD = '<td style="padding: 12px; font-size: 14px; border-bottom: 1px solid var(--hl); vertical-align: middle;">%s</td>'
def table(heads, rows, hl_row=None):
    out = '<table style="width: 100%; border-collapse: collapse;"><thead><tr>' + ''.join(TH % h for h in heads) + '</tr></thead><tbody>'
    for i, r in enumerate(rows):
        tr = '<tr style="background: var(--sf);">' if i == hl_row else '<tr>'
        out += tr + ''.join(TD % c for c in r) + '</tr>'
    return out + '</tbody></table>'
def cbtn(t, kind='out'):
    st = {'out': 'border: 2px solid var(--tx);', 'ink': 'background: var(--tx); color: var(--bg);', 'red': 'background: var(--ac); color: var(--ai);', 'mu': 'border: 1px solid var(--dv); color: var(--mu);'}[kind]
    return '<button style="height: 36px; padding: 0 12px; font-size: 13px; font-weight: 800; white-space: nowrap; %s">%s</button>' % (st, t)
def cbtns(*b): return '<span style="display: flex; gap: 6px; flex-wrap: wrap;">' + ''.join(b) + '</span>'
H2 = '<h2 style="margin: 0; font-size: 24px; font-weight: 800;">%s</h2>'

# C14 main: in place, add the segment row (Listed) + Export CSV
s = c14
old_h2 = H2 % 'Listed in Madhapur · 72 unverified · 12 live'
assert s.count(old_h2) == 1
main_old = s[s.index('<main'):s.index('</main>') + 7]
main_new = ('<main style="min-width: 0; padding: 20px 24px; display: grid; gap: 16px; align-content: start;">' + segrow('Listed')
            + '<div style="display: grid; grid-template-columns: 420px minmax(0, 1fr); gap: 24px; align-content: start;">'
            + main_old[main_old.index('<div style="display: grid; gap: 12px; align-content: start;">'):-7] + '</div></main>')
s = s.replace(main_old, main_new)
s = rep(s, old_h2, H2 % 'Listed · 72 unverified · 12 live')
s = rep(s, '<span style="font-size: 13px; color: var(--mu); line-height: 1.45;">Shown as UNVERIFIED with an expected rent range. No beds, holds or owner contact until the team visits.</span>', '')
s = s.replace(TD % '4', TD % '4', 1)
# source column: add to the table head + rows
s = rep(s, TH % 'Photos', TH % 'Source' + TH % 'Photos')
s = rep(s, TD % 'Madhapur' + TD % '₹7,000–9,000', TD % 'Madhapur' + TD % '₹7,000–9,000<br><span style="font-size: 12px; color: var(--mu);">confirmed 18 Oct</span>')
s = rep(s, TD % '₹7,000–9,000<br><span style="font-size: 12px; color: var(--mu);">confirmed 18 Oct</span>' + TD % '4', TD % '₹7,000–9,000<br><span style="font-size: 12px; color: var(--mu);">confirmed 18 Oct</span>' + TD % 'resident · Ravi T.' + TD % '4')
s = rep(s, TD % '₹6,500–8,500' + TD % '6', TD % '₹6,500–8,500<br><span style="font-size: 12px; color: var(--mu);">confirmed 20 Oct</span>' + TD % 'partner · HZ-PART-1' + TD % '6')
s = rep(s, TD % '—' + TD % '12', TD % '—' + TD % 'team' + TD % '12')
wr('f26-c14.dc.html', s, '[C14] console · Listed: segments Listed · To call · To refresh · Partners, Export CSV; list a hostel as UNVERIFIED, source column, List it / Take off · Updated (F28)', 1440, 900, (CANVAS['boards']['f26-c14.dc.html']['x'], CANVAS['boards']['f26-c14.dc.html']['y']))

# C14 To call
script_lines = ['Hi, I’m <b>Farhath from Hostelzy</b>, a free app where tenants find PGs in Hyderabad.',
                'We’d like to list <b>Sri Venkateswara PG</b> for free. No fees, no commission.',
                'What’s the rent range? <i>(from – to, per month)</i>',
                'Is it for men, women or both?',
                'Is food included?',
                'Want to be <b>verified</b>? Our team visits once; then tenants can hold beds.']
tocall = (segrow('To call')
    + '<div style="display: grid; grid-template-columns: 460px minmax(0, 1fr); gap: 24px; align-content: start;">'
    '<div style="display: grid; gap: 12px; align-content: start;">'
    + H2 % 'Sri Venkateswara PG'
    + '<span style="display: flex; gap: 8px; align-items: center; flex-wrap: wrap;">' + tag('Draft', 'mu') + tag('Places', 'mu') + mu('Madhapur · seen 12 Oct · 3 photos', 13) + '</span>'
    + '<a href="#" style="display: flex; gap: 8px; align-items: center; font-size: 18px; font-weight: 800; color: var(--tx); text-decoration: none;">' + ico('phone', 18) + '+91 98660 23410</a>'
    + '<div style="border: 2px solid var(--tx); padding: 12px; display: grid; gap: 8px;">' + kick('Call script')
    + ''.join('<div style="display: grid; grid-template-columns: 22px minmax(0, 1fr); gap: 8px; font-size: 14px; line-height: 1.4;"><b style="color: var(--mu);">%d</b><span>%s</span></div>' % (i + 1, l) for i, l in enumerate(script_lines))
    + '</div>'
    + '<div style="display: grid; grid-template-columns: 1fr 1fr; gap: 8px;">' + field('Rent from (₹)', '7,000') + field('Rent to (₹)', '9,000') + '</div>'
    + '<div style="display: grid; grid-template-columns: 1fr auto; gap: 12px; align-items: end;"><div style="display: grid; gap: 6px;">' + label('For') + seg(['Men', 'Women', 'Co-living'], 'Men', 44) + '</div><div style="display: grid; gap: 6px; padding-bottom: 10px;">' + label('Food') + switch(True) + '</div></div>'
    + '<div style="display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 8px;">' + btn('List', 'red', 'check', 48, 14) + btn('Not a PG / Closed', 'out', 'x', 48, 14) + btn('Call later', 'mu', 'clock', 48, 14) + '</div>'
    + '</div>'
    '<div style="display: grid; gap: 12px; align-content: start;">'
    + H2 % 'To call · 48 drafts'
    + table(['Hostel', 'Area', 'Source', 'Phone', 'Seen', ''], [
        ['<b>Sri Venkateswara PG</b>', 'Madhapur', 'Places', '+91 98660 23410', '12 Oct', cbtns(cbtn('Open', 'ink'))],
        ['<b>Kavya Ladies Hostel</b>', 'Kondapur', 'Web form', '+91 99590 77812', 'Today', cbtns(cbtn('Open'))],
        ['<b>Sai Ram Boys Hostel</b>', 'Gachibowli', 'OSM', '—', '11 Oct', cbtns(cbtn('Open'))],
        ['<b>Royal Comforts PG</b>', 'Hitec City', 'Places', '+91 90520 11240', '12 Oct · call later', cbtns(cbtn('Open'))],
        ['<b>Padma Nilayam</b>', 'Ameerpet', 'Places', '+91 98480 60011', '9 Oct', cbtns(cbtn('Open'))],
      ], 0)
    + mu('Map data © OpenStreetMap contributors', 12)
    + '</div></div>')
x = slot(1440)
wr('f28-c14ToCall.dc.html', console(tocall), '[variant of C14] console · Listed › To call: drafts from Places / OSM / web, phone, 6-line call script, rent + for + food, List / Not a PG / Call later, Export CSV · New (F28)', 1440, 900, (x, Y0))

# C14 To refresh
torefresh = (segrow('To refresh')
    + '<div style="display: grid; gap: 12px; align-content: start;">'
    + H2 % 'To refresh · 9 listed hostels past 50 days'
    + table(['Hostel', 'Area', 'Rent range', 'Confirmed', 'Shows as', ''], [
        ['<b>Sri Balaji Men’s PG</b>', 'Madhapur', '₹7,000–9,000', '52 days ago · resident', '₹7,000–9,000 · 8 days left', cbtns(cbtn('Rent confirmed today', 'ink'), cbtn('Closed'))],
        ['<b>Lakshmi Ladies Hostel</b>', 'Kondapur', '₹6,500–8,500', '58 days ago · team call', '₹6,500–8,500 · 2 days left', cbtns(cbtn('Rent confirmed today', 'ink'), cbtn('Closed'))],
        ['<b>Green Park PG</b>', 'Gachibowli', '₹8,000–10,000', '64 days ago · team call', '<span style="color: var(--mu);">Rent on request</span>', cbtns(cbtn('Rent confirmed today', 'ink'), cbtn('Closed'))],
        ['<b>Sunrise Men’s Hostel</b>', 'Ameerpet', '₹5,500–7,000', '71 days ago · web form', '<span style="color: var(--mu);">Rent on request</span>', cbtns(cbtn('Rent confirmed today', 'ink'), cbtn('Closed'))],
      ])
    + '</div>')
x = slot(1440)
wr('f28-c14ToRefresh.dc.html', console(torefresh), '[variant of C14] console · Listed › To refresh: listed hostels past 50 days, Rent confirmed today / Closed, Export CSV · New (F28)', 1440, 900, (x, Y0))

# C14 Partners
partners = (segrow('Partners')
    + '<div style="display: grid; grid-template-columns: 420px minmax(0, 1fr); gap: 24px; align-content: start;">'
    '<div style="display: grid; gap: 12px; align-content: start;">'
    + H2 % 'Add a partner'
    + field('Name', 'Kiran Kumar') + field('Phone (WhatsApp)', '+91 98491 55020') + field('UPI ID', 'kiran.k@upi')
    + '<div style="display: grid; gap: 6px;">' + label('Code') + '<div style="height: 48px; padding: 0 12px; display: flex; align-items: center; border: 2px solid var(--dv); font-size: 15px; font-weight: 800;">HZ-PART-4</div></div>'
    + btn('Add partner', 'red', 'plus')
    + '</div>'
    '<div style="display: grid; gap: 12px; align-content: start;">'
    + H2 % 'Partners · 3 active · ₹260 due on the 5th'
    + table(['Code', 'Partner', 'Phone', 'Listed', 'Checked', '₹ due', 'Active', ''], [
        ['<b>HZ-PART-1</b>', 'Anil Reddy', '+91 98490 11223', '14', '12', '<b style="color: var(--gn);">₹240</b>', switch(True), cbtns(cbtn('Pause'))],
        ['<b>HZ-PART-2</b>', 'Sneha M.', '+91 99080 44551', '3', '1', '<b style="color: var(--gn);">₹20</b>', switch(True), cbtns(cbtn('Pause'))],
        ['<b>HZ-PART-3</b>', 'Imran Sheikh', '+91 90000 73311', '0', '0', '₹0', switch(True), cbtns(cbtn('Pause'))],
      ])
    + '</div></div>')
x = slot(1440)
wr('f28-c14Partners.dc.html', console(partners), '[variant of C14] console · Listed › Partners: add partner (code made for them), list with listed / checked counts, ₹ due, Active · New (F28)', 1440, 900, (x, Y0))

# ================= C15 variant: "added by Ravi (resident)"
s = rd('f26-c15.dc.html')
s = rep(s, '<span style="font-size: 12px; color: var(--mu);">Madhapur · unverified</span>',
        '<span style="font-size: 12px; color: var(--mu);">Madhapur · unverified</span><br><span style="font-size: 12px; font-weight: 600;">added by Ravi T. (resident) · owner phone matches <span style="color: var(--gn);">✓</span></span>')
s = rep(s, '<span style="font-size: 12px; color: var(--mu);">Kondapur · unverified</span>',
        '<span style="font-size: 12px; color: var(--mu);">Kondapur · unverified</span><br><span style="font-size: 12px; font-weight: 600;">added by partner HZ-PART-1 · owner phone <span style="color: var(--ad);">✗ different</span></span>')
s = rep(s, '<span style="font-size: 14px; color: var(--mu); line-height: 1.45;">Owners who tapped “Claim this hostel”. Call to check, then Done starts onboarding. Not the owner closes it.</span>', '')
s = rep(s, 'Today, 9:40 am', 'Today, 9:40 am<br><span style="font-size: 12px; color: var(--mu);">via claim link</span>')
x = slot(1440)
wr('f28-c15.dc.html', s, '[variant of C15] console · Claims: “added by Ravi (resident) · owner phone matches ✓”, partner line with ✗ · New (F28)', 1440, 900, (x, Y0))

# ---------- parts/f28.json
ROW_TITLE = {'kind': 'title1', 'maxW': X, 'text': 'F28 · Every Hyderabad hostel in: S92 addHostel, S93 myAdd, W8 app/list, W9 poster + variants; H1, S8, S79, T20, S22, C14, C15 changes', 'w': 240, 'x': 0, 'y': Y0 - 400}
parts = {'boards': {f: BOARDS[f] for f in ORDER}, 'order': ORDER,
         'row_note': {'f28': ROW_TITLE},
         'updated_in_place': ['r-filters.dc.html', 'me.dc.html', 'w3-stayNotYet.dc.html', 'f26-c14.dc.html'],
         'base': 'main-canvas v24 (docs/design/main-canvas/project/canvas.json), new row y = max y + 1200 = %d' % Y0}
json.dump(parts, open(PARTS + 'f28.json', 'w'), indent=1, ensure_ascii=False)
print(len(ORDER), 'boards;', len([f for f in ORDER if f not in parts['updated_in_place']]), 'new files; row y', Y0, 'row width', X)
