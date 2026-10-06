import re
src = open('/tmp/claude-0/-home-user-hostelzy/58cdc0a8-c7d4-5e26-828b-40f705b32de2/scratchpad/w2.py').read()
exec(src[:src.index('# ---------- NEW boards')])
I['warn'] = '<path d="M12 3 2 21h20zM12 10v5M12 18v.5"/>'
I['star'] = '<path d="M12 2l3.1 6.3 6.9 1-5 4.9 1.2 6.8L12 17.8 5.8 21l1.2-6.8-5-4.9 6.9-1z"/>'
NAVS = {}
for f, k in [('holds.dc.html', 'tenant'), ('r-home.dc.html', 'resident'), ('r-today.dc.html', 'owner')]:
    NAVS[k] = re.search(r'<nav.*?</nav>', rd(f), re.S).group(0)
def plain_nav(n):  # no tab selected
    return n.replace('color: var(--tx); box-shadow: inset 0 3px 0 var(--ac);">', 'color: var(--mu);">')
FRAME = rd('holds.dc.html')
def phone(tt, body, nav=None):
    s = title(FRAME, tt)
    i = root_inner(s); j = s.rindex('</div>\n</x-dc>')
    return s[:i] + body + (nav or '') + s[j:]
def scroll(inner, pad='20px 16px'):
    return '<div style="flex-grow: 1; overflow: hidden; border-top: 2px solid var(--tx); padding: %s; display: grid; gap: 12px; align-content: start;">%s</div>' % (pad, inner)
def empty(ic, h, b, extra=''):
    icon = '<span style="width: 44px; height: 44px; display: grid; place-items: center; background: var(--sf);">' + ico(ic, 22) + '</span>' if ic else ''
    return '<div style="padding: 20px 16px; border: 2px dashed var(--dv); display: grid; gap: 8px; justify-items: start;">' + icon + '<b style="font-size: 18px;">' + h + '</b>' + mut(b) + extra + '</div>'
def lrow(ic, t, sub):
    return '<div style="display: grid; grid-template-columns: 36px minmax(0, 1fr) 16px; gap: 12px; align-items: center; padding: 12px 0; border-bottom: 1px solid var(--hl);"><span style="width: 36px; height: 36px; display: grid; place-items: center; background: var(--sf);">' + ico(ic) + '</span><span style="display: grid; gap: 1px;"><b style="font-size: 16px;">' + t + '</b><span style="font-size: 13px; color: var(--mu);">' + sub + '</span></span>' + ico('chev', 16) + '</div>'
def bottom(b): return '<div style="flex: none; border-top: 2px solid var(--tx); padding: 12px 16px 20px;">' + b + '</div>'
def roomhead(): return head('Anjani Residency · 2 sharing', 'Room 105')

# --- Screen: oRules (full)
def rule(n, t, sub):
    return '<div style="display: grid; grid-template-columns: 28px minmax(0, 1fr); gap: 12px; padding: 10px 0; border-bottom: 1px solid var(--hl);"><b style="width: 28px; height: 28px; display: grid; place-items: center; background: var(--tx); color: var(--bg); font-size: 14px;">%d</b><span style="display: grid; gap: 2px;"><b style="font-size: 15px;">%s</b><span style="font-size: 13px; color: var(--mu);">%s</span></span></div>' % (n, t, sub)
ladder = ('<div style="display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); border: 2px solid var(--tx);">'
          + ''.join('<div style="padding: 8px; display: grid; gap: 1px; %s"><span style="font-size: 11px; font-weight: 800; color: var(--mu);">%s</span><b style="font-size: 14px;">%s</b><span style="font-size: 12px; color: var(--mu);">%s</span></div>' % ('' if i == 2 else 'border-right: 1px solid var(--hl);', a, b, c) for i, (a, b, c) in enumerate([('STRIKE 1', 'Warning', 'Nothing changes yet'), ('STRIKE 2', 'Deals hidden', 'For 30 days'), ('STRIKE 3', 'Removed', 'From Hostelzy')])) + '</div>')
body = head('Anjani Residency · Settings', 'Fair Play rules') + scroll(mut('Tenants trust Hostelzy because every hostel plays by the same rules. Read them with your manager.')
    + '<div>' + rule(1, 'Add every resident within 3 days.', 'Name and phone. That is how a stay counts as came from the app or walked in.') + rule(2, 'Never take a Hostelzy tenant off the app.', 'Don’t ask them to cancel a hold or pay you outside the booking.') + rule(3, 'Honour the deal and exit rules.', 'The price, advance and maintenance shown at booking.') + rule(4, 'Keep beds and prices up to date.', 'Confirm free beds when we ask, every 3 days.') + '</div>'
    + '<div style="display: flex; justify-content: space-between;">' + kick('If a rule is broken') + '<b style="font-size: 13px;">No fines</b></div>' + ladder
    + mut('You always get 48 hours to explain. Fix a mistake in that time and there is no strike. 3 fixes in 6 months = 1 warning.', 13) + '<b style="font-size: 14px;">Accepted when you joined Hostelzy.</b>', '16px')
wr('w3-oRules.dc.html', phone('Fair Play rules (full)', body))

# --- Tenant states
wr('w3-holdGone.dc.html', phone('Hold: not on this phone any more', '<div style="flex: none; padding: 12px 16px;"><button aria-label="Back" style="width: 44px; height: 44px; display: grid; place-items: center; border: 1px solid var(--dv);">' + ico('back', 20) + '</button></div>' + scroll(mut('This hold isn’t on this phone any more.', 16)), NAVS['tenant']))
wr('w3-roomSignIn.dc.html', phone('Room: sign in to see room layouts', roomhead() + scroll(empty('lock', 'Sign in to see room layouts', 'Room layouts are only for people signed in to Hostelzy.') + mut('It takes one tap with Google. We never share your number with the hostel until you choose to.', 13))))
wr('w3-roomLoading.dc.html', phone('Room: loading the layout', roomhead() + '<div style="flex-grow: 1; border-top: 2px solid var(--tx); display: grid; place-items: center;">' + mut('Loading the layout…') + '</div>'))
wr('w3-roomCapped.dc.html', phone('Room: women’s PG daily cap', head('Sai Sri Ladies Hostel · 3 sharing', 'Room 302') + scroll(empty('lock', 'Floor plan shows after you hold a bed', 'For residents’ safety, a women’s PG shows a few rooms a day before a hold. Hold a bed to see every room.', btn('Pick a bed from Plan', 'out', 'arrow', 46, 14)) + mut('Hostelzy never shows gates, CCTV, exits or residents’ names on any plan.', 12))))
wr('w3-roomError.dc.html', phone('Room: couldn’t load this room', roomhead() + scroll(empty('warn', 'Couldn’t load this room', 'Check your internet and try again. You can still pick a bed from Plan or List.', btn('Try again', 'out', 'reload', 46, 14)))))
vf = lambda h, b: ('<div style="margin: 0 auto; width: 300px; height: 300px; background: var(--sf); border: 2px solid var(--tx); display: grid; place-items: center; padding: 24px;"><div style="display: grid; gap: 8px; justify-items: center; text-align: center;">' + ico('lock', 24) + '<b style="font-size: 17px;">' + h + '</b>' + mut(b, 13) + '</div></div>')
for name, tt, h, b in [('w3-scanOff', 'Scan: the camera is off for Hostelzy', 'The camera is off for Hostelzy', 'Allow it in your phone’s Settings → Apps → Hostelzy → Permissions, or type the code.'), ('w3-scanError', 'Scan: the camera didn’t start', 'The camera didn’t start', 'Type the code from the poster instead.')]:
    wr(name + '.dc.html', phone(tt, head('Join your PG', 'Scan the QR') + '<div style="flex-grow: 1; border-top: 2px solid var(--tx); padding: 24px 16px; display: grid; gap: 16px; align-content: start;">' + vf(h, b) + mut('Point it at the QR on the Hostelzy poster at your PG. The code fills in by itself and your owner gets the request.') + '</div>' + bottom(btn('Type the code instead', 'out', 'pencil'))))

# --- Resident states
food_nav = NAVS['resident'].replace('color: var(--tx); box-shadow: inset 0 3px 0 var(--ac);">', 'color: var(--mu);">', 1)
food_nav = food_nav.replace('font-size: 11px; font-weight: 600; color: var(--mu);"><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="square" style="flex: none;"><path d="M7 3v8', 'font-size: 11px; font-weight: 600; color: var(--tx); box-shadow: inset 0 3px 0 var(--ac);"><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="square" style="flex: none;"><path d="M7 3v8', 1)
wr('w3-foodNoMenu.dc.html', phone('Food: no menu yet', head('Anjani Residency', 'Food', False) + scroll(mut('Srinivas hasn’t put the menu on Hostelzy yet. It shows here once they do.', 15)), food_nav))
wr('w3-stayNotYet.dc.html', phone('My stay: not on Hostelzy yet', head('Anjani Residency', 'My stay') + scroll('<div style="padding: 14px; border: 2px dashed var(--dv);">' + mut('Your stay isn’t on Hostelzy yet. Once Srinivas adds you, it shows here.') + '</div><div>'
    + lrow('swap', 'Move to another bed', '6 free beds here') + lrow('out', 'Give notice', '30 days · earliest last day 2 Nov') + lrow('star', 'Review your stay', 'Opens 3 Nov · after 30 days') + lrow('pencil', 'Fix a room layout', 'Any room in Anjani Residency') + '</div>' + mut('Advance ₹3,000 · ₹2,000 back when you leave', 13)), plain_nav(NAVS['resident'])))
def tl(t, s, done):
    return '<div style="display: grid; grid-template-columns: 14px minmax(0, 1fr); gap: 10px; padding: 8px 0;"><span style="width: 14px; height: 14px; margin-top: 3px; border: 2px solid var(--tx); background: %s;"></span><span style="display: grid; gap: 1px;"><b style="font-size: 14px;">%s</b><span style="font-size: 13px; color: var(--mu);">%s</span></span></div>' % ('var(--tx)' if done else 'transparent', t, s)
wr('w3-noticeGiven.dc.html', phone('Give notice: notice given', head('Bed 204-B', 'Give notice') + scroll('<span style="font-size: 11px; font-weight: 800; letter-spacing: .1em; text-transform: uppercase; color: var(--ad);">Notice given</span><b style="font-size: 28px; line-height: 1.1; letter-spacing: -.02em;">Your last day is Sun 1 Nov.</b>'
    + mut('Sent to Srinivas. They accept it in Hostelzy, then your bed shows “free soon”.') + btn('Tell Srinivas on WhatsApp', 'out', 'msg', 46, 14)
    + '<div>' + tl('Notice given', 'Today, 3 Oct', True) + tl('Srinivas accepts it', 'In Hostelzy', False) + tl('₹2,000 back to your UPI', 'Advance minus ₹1,000 maintenance, within 7 days of leaving. Hostelzy asks you when it arrives.', False) + '</div>'
    + '<a href="#" style="font-size: 14px; font-weight: 800; color: var(--ad);">Withdraw notice</a>') + bottom(btn('Review your stay', 'out', 'star'))))
chips = '<div style="display: flex; gap: 6px;">' + ''.join('<span style="height: 36px; padding: 0 12px; display: flex; align-items: center; font-size: 14px; font-weight: 800; border: %s; background: %s; color: %s;">%s</span>' % ('2px solid var(--tx)' if r == '205' else '1px solid var(--dv)', 'var(--tx)' if r == '205' else 'transparent', 'var(--bg)' if r == '205' else 'var(--tx)', r) for r in ['203', '204', '205', '206']) + '</div>'
wr('w3-rRoomNoLayout.dc.html', phone('Rooms: no layout yet (resident)', head('Anjani Residency · you live in 204', 'Room 205') + scroll(chips + empty('pencil', 'No layout yet', 'The owner draws this room first. Then you can fix it.')), plain_nav(NAVS['resident'])))
wr('w3-noRefund.dc.html', phone('Your refund: none waiting', head('Your stay', 'Your refund') + scroll(mut('No refund waiting.', 16)), NAVS['tenant'].replace('color: var(--tx); box-shadow: inset 0 3px 0 var(--ac);">', 'color: var(--mu);">').replace('font-weight: 600; color: var(--mu);"><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="square" style="flex: none;"><path d="M19 21v-2', 'font-weight: 600; color: var(--tx); box-shadow: inset 0 3px 0 var(--ac);"><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="square" style="flex: none;"><path d="M19 21v-2')))

# --- Owner states
wr('w3-noCases.dc.html', phone('Fair Play: no open cases', '<div style="flex: none; padding: 12px 16px; display: flex; gap: 12px; align-items: flex-start;"><button aria-label="Back" style="width: 44px; height: 44px; flex: none; display: grid; place-items: center; border: 1px solid var(--dv);">' + ico('back', 20) + '</button><div style="display: grid; gap: 2px;">' + kick('Fair Play') + '<b style="font-size: 24px; line-height: 1.1;">No open cases</b></div></div>' + '<div style="flex-grow: 1; border-top: 2px solid var(--tx);"></div>', plain_nav(NAVS['owner'])))
def olay(tt, strip, h, b):
    return phone(tt, head('Anjani Residency · Beds', 'Room 105 layout') + '<div style="flex: none; margin: 0 16px 10px; padding: 8px 12px; background: var(--ab); color: var(--ad); font-size: 13px; font-weight: 800;">' + strip + '</div>'
        + scroll(empty('pencil', h, b)) + '<div style="flex: none; border-top: 2px solid var(--tx); padding: 12px 16px 20px; display: grid; grid-template-columns: minmax(0, 1fr) 150px; gap: 8px;">' + btn('Create a layout', 'red', 'pencil') + btn('Ask Hostelzy', 'out', None) + '</div>', plain_nav(NAVS['owner']))
wr('w3-oLayoutNone.dc.html', olay('Room layout: no layout yet (owner)', 'No layout yet', 'No layout yet', 'Draw it yourself in a few minutes and publish it, or ask the Hostelzy team to draw it for you, free.'))
wr('w3-oLayoutDrawing.dc.html', olay('Room layout: Hostelzy is drawing it', 'Asked Hostelzy · 22 h left · done within 48 h', 'Hostelzy is drawing it', 'You asked on 2 Oct, 10:12 · L shape · 14 × 12 ft. Done within 48 hours; you get a notification.'))

# --- Console
cbase = rd('f24-cLayoutHelp.dc.html')
def console(tt, main):
    s = title(cbase, tt); i = s.index('<main'); j = s.index('</main>') + 7
    return s[:i] + main + s[j:]
seg = '<div style="display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); border: 2px solid var(--tx);">' + ''.join('<button style="padding: 10px 4px; font-size: 13px; font-weight: 600; text-align: center; %s">%s</button>' % ('background: var(--tx); color: var(--bg);' if n == 'L shape' else '', n) for n in ['Rectangle', 'L shape', 'T shape', 'U shape', 'Angled corner', 'Narrow end', 'Alcove', 'Custom']) + '</div>'
inp = lambda l, v: '<label style="display: grid; gap: 6px; font-size: 13px; font-weight: 800;">%s<input value="%s" style="height: 44px; padding: 0 12px; border: 2px solid var(--tx); background: var(--bg); font-size: 15px;"></label>' % (l, v)
grid = 'background-color: var(--bg); background-image: repeating-linear-gradient(0deg, var(--hl) 0 1px, transparent 1px 24px), repeating-linear-gradient(90deg, var(--hl) 0 1px, transparent 1px 24px);'
preview = '<div style="height: 420px; border: 2px solid var(--tx); position: relative; ' + grid + '"><div style="position: absolute; left: 48px; top: 48px; width: 336px; height: 288px; border: 4px solid var(--tx); clip-path: polygon(0 0, 100% 0, 100% 66%, 70% 66%, 70% 100%, 0 100%);"></div><span style="position: absolute; right: 8px; bottom: 6px; font-size: 12px; color: var(--mu);">1 square = 1 ft</span></div>'
main = ('<main style="min-width: 0; padding: 20px 24px; display: grid; grid-template-columns: 420px minmax(0, 1fr); gap: 24px; align-content: start;"><div style="display: grid; gap: 14px; align-content: start;"><h2 style="margin: 0; font-size: 24px; font-weight: 800;">Anjani Residency · Room 105</h2>'
        '<b style="font-size: 13px;">Shape</b>' + seg + '<div style="display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 10px;">' + inp('Width (ft)', '14') + inp('Length (ft)', '12') + '</div>'
        '<div style="display: flex; gap: 8px;"><button style="height: 40px; padding: 0 14px; font-weight: 800; background: var(--ac); color: var(--ai);">Send to owner ✓</button><button style="height: 40px; padding: 0 14px; font-weight: 800; border: 2px solid var(--tx);">Back to the request</button></div>'
        + mut('The owner’s app places the beds, fans and windows inside these walls; they check it and publish.', 13) + '</div>' + preview + '</main>')
wr('w3-cLayoutEditor.dc.html', console('Team console: layout help, draw the walls', main))
wr('w3-cLoadError.dc.html', console('Team console: couldn’t load', '<main style="min-width: 0; padding: 20px 24px;"><p style="margin: 0; font-size: 15px;">Couldn’t load: Missing or insufficient permissions.</p></main>'))

# --- Web: no-code states
s = rd('wR.dc.html'); s = title(s, 'r/: link has no HZ code')
s = re.sub(r'<div style="border: 2px solid var\(--tx\); background: var\(--sf\);.*?</p></div>', '<p style="margin: 12px 0 18px;">This link has no HZ code. Ask the sender for the full link.</p>', s, count=1, flags=re.S)
s = re.sub(r'<a href="#" style="[^"]*background: var\(--ac\);[^"]*">Open in Hostelzy</a>', '', s, count=1)
assert 'HZ-4821' not in s and '>Open in Hostelzy</a>' not in s
wr('w3-wRNoCode.dc.html', s)
s = rd('wJ.dc.html'); s = title(s, 'j/: link has no invite code')
before = s
s = re.sub(r'<div style="border: 2px solid var\(--tx\); background: var\(--sf\);.*?</p></div>', '<p style="margin: 12px 0 18px;">This link has no invite code. Ask your hostel owner for the full link.</p>', s, count=1, flags=re.S)
s = re.sub(r'<a href="#" style="[^"]*background: var\(--ac\);[^"]*">Open in Hostelzy</a>', '', s, count=1)
assert s != before and 'ANJ-7Q2' not in s and '>Open in Hostelzy</a>' not in s, 'wJ'
wr('w3-wJNoCode.dc.html', s)

# --- Web: site root, old prototype (drawn as it is, for the record)
s = rd('f17-Desktop.dc.html'); s = title(s, 'Site root: old web prototype')
i = root_inner(s); j = s.rindex('</div>\n</x-dc>')
chip2 = lambda t, on=False: '<span style="padding: 8px 14px; border: 2px solid var(--tx); font-size: 14px; font-weight: 700; %s">%s</span>' % ('background: var(--tx); color: var(--bg);' if on else '', t)
body = ('<header style="flex: none; height: 72px; padding: 0 32px; display: flex; align-items: center; gap: 24px; border-bottom: 2px solid var(--tx);"><b style="font-size: 22px; display: flex; gap: 8px; align-items: center;"><span style="width: 18px; height: 14px; border: 2px solid var(--tx);"></span>Hostelzy</b>'
        '<span style="display: flex; gap: 6px; font-size: 13px; font-weight: 700;">EN · తెలుగు · हिंदी</span><span style="flex-grow: 1;"></span>' + chip2('Find a bed', True) + chip2('My stay') + chip2('Owner') + chip2('Hostelzy HQ') + '</header>'
        '<div style="flex-grow: 1; padding: 64px 32px; display: grid; gap: 20px; align-content: start; max-width: 960px;">'
        '<span style="padding: 4px 8px; background: var(--ab); color: var(--ad); font-size: 12px; font-weight: 800; justify-self: start;">OLD PROTOTYPE · not the app’s design</span>'
        '<h1 style="margin: 0; font-size: 56px; line-height: 1.02; font-weight: 900; letter-spacing: -.03em;">Pick the exact bed. Not just the hostel.</h1>'
        '<p style="margin: 0; font-size: 18px; color: var(--mu); max-width: 720px;">Every floor, room and bed of PGs near your office or college, live. Hold the one you want and talk to the owner on WhatsApp.</p>'
        '<div style="display: grid; grid-template-columns: minmax(0, 1fr) 160px; border: 2px solid var(--tx);"><input value="girls PG under 10k near Mindspace, AC, no curfew" style="height: 56px; padding: 0 16px; border: 0; background: var(--bg); font-size: 16px;"><button style="background: var(--ac); color: var(--ai); font-weight: 800; font-size: 16px; text-align: center;">Show beds</button></div>'
        '<div style="display: flex; gap: 8px; flex-wrap: wrap; align-items: center; font-size: 14px;"><b>Popular:</b>' + ''.join('<span style="padding: 6px 10px; border: 1px solid var(--dv);">%s</span>' % t for t in ['PG near Mindspace', 'PG near DLF Cyber City', 'Hostels near JNTU', 'PG near Ameerpet']) + '</div></div>')
s = s[:i] + body + s[j:]
wr('w3-wRoot.dc.html', s)
print(len(OUT), OUT)
