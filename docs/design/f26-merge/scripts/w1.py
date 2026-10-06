import re, os
P = '/tmp/claude-0/-home-user-hostelzy/58cdc0a8-c7d4-5e26-828b-40f705b32de2/scratchpad/canvas/project/'
def rd(f): return open(P + f).read()
def rep(s, old, new, n=1):
    c = s.count(old)
    assert c == n, (old[:80], c)
    return s.replace(old, new)
def title(s, t): return re.sub(r'<title>.*?</title>', '<title>' + t + '</title>', s, count=1)
def between(s, a, b, new, keep_a=False):
    i = s.index(a); j = s.index(b, i + len(a))
    return s[:i] + ((a) if keep_a else '') + new + s[j:]
OUT = []
def wr(name, s):
    open(P + name, 'w').write(s); OUT.append(name)

# --- snippets
I = {
 'arrow': '<path d="M5 12h14"/><path d="m12 5 7 7-7 7"/>',
 'check': '<path d="M20 6 9 17l-5-5"/>',
 'x': '<path d="M18 6 6 18M6 6l12 12"/>',
 'out': '<path d="M15 3h6v18h-6M10 17l5-5-5-5M15 12H3"/>',
 'swap': '<path d="M7 4 3 8l4 4M3 8h14M17 20l4-4-4-4M21 16H7"/>',
 'money': '<path d="M3 7h18v12H3z"/><path d="M16 13h2"/><path d="M5 7l11-3v3"/>',
 'msg': '<path d="M21 12a8 8 0 0 1-11.6 7.1L4 20l1.1-4.6A8 8 0 1 1 21 12z"/>',
 'plus': '<path d="M12 5v14M5 12h14"/>',
 'clock': '<circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/>',
 'wifi': '<path d="M2 2l20 20M8.5 16.5a5 5 0 0 1 7 0M5 13a10 10 0 0 1 5.2-2.8M19 13a10 10 0 0 0-2.3-1.7M2 8.8a15 15 0 0 1 4.2-2.7M22 8.8A15 15 0 0 0 10.7 5"/><circle cx="12" cy="20" r="1"/>',
 'pin': '<path d="M20 10c0 5-5.5 10.2-7.4 11.8a1 1 0 0 1-1.2 0C9.5 20.2 4 15 4 10a8 8 0 0 1 16 0"/><circle cx="12" cy="10" r="3"/>',
 'pencil': '<path d="M17 3l4 4L8 20H4v-4z"/>',
 'bell': '<path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9M10.3 21a1.9 1.9 0 0 0 3.4 0"/>',
 'chev': '<path d="m9 18 6-6-6-6"/>',
 'reload': '<path d="M21 12a9 9 0 1 1-3-6.7L21 8M21 3v5h-5"/>',
}
def ico(k, sz=18): return '<svg width="%d" height="%d" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="square" style="flex: none;">%s</svg>' % (sz, sz, I[k])
def btn(text, kind='red', icon='arrow', h=52, fs=15):
    st = {'red': 'background: var(--ac); color: var(--ai);', 'ink': 'background: var(--tx); color: var(--bg);', 'out': 'border: 2px solid var(--tx); color: var(--tx);'}[kind]
    return '<button style="width: 100%%; height: %dpx; padding: 0 16px; display: flex; justify-content: space-between; align-items: center; gap: 10px; font-weight: 800; font-size: %dpx; text-decoration: none; %s">%s%s</button>' % (h, fs, st, text, ico(icon) if icon else '')
def kick(t): return '<span style="font-size: 11px; font-weight: 600; letter-spacing: .1em; text-transform: uppercase; line-height: 1.3; color: var(--mu);">%s</span>' % t
def srow(l, v, vstyle='color: var(--tx);'):
    return '<div style="display: grid; grid-template-columns: 110px minmax(0, 1fr); gap: 12px; padding: 10px 16px; border-bottom: 1px solid var(--hl); font-size: 14px;"><span style="color: var(--mu);">%s</span><span style="font-weight: 600; %s">%s</span></div>' % (l, vstyle, v)
def sheet(k, t, rows, btns, note=''):
    nt = '<div style="padding: 12px 16px 0; font-size: 13px; line-height: 1.45; color: var(--mu);">%s</div>' % note if note else ''
    return ('<div style="position: absolute; inset: 0; display: flex; flex-direction: column; background: rgba(20,18,17,.55);"><div style="flex-grow: 1; min-height: 40px;"></div><div style="background: var(--bg); border-top: 2px solid var(--tx); padding-bottom: 24px;">'
            '<div style="display: flex; justify-content: space-between; align-items: center; gap: 12px; padding: 12px 16px; border-bottom: 2px solid var(--dv);"><span style="display: grid; gap: 2px;">%s<span style="font-weight: 800; font-size: 20px;">%s</span></span><button aria-label="Close" style="width: 44px; height: 44px; flex: none; display: grid; place-items: center; border: 1px solid var(--dv);">%s</button></div>'
            '<div>%s%s<div style="padding: 14px 16px 0; display: grid; gap: 8px;">%s</div></div></div></div>') % (k, t, ico('x'), ''.join(rows), nt, ''.join(btns))
def tag(t, kind='mu'):
    st = {'mu': 'border: 1px solid var(--dv); color: var(--mu);', 'red': 'background: var(--ab); color: var(--ad); border: 1px solid var(--ab);', 'ink': 'background: var(--tx); color: var(--bg); border: 1px solid var(--tx);'}[kind]
    return '<span style="flex: none; padding: 3px 7px; font-size: 11px; font-weight: 800; letter-spacing: .05em; text-transform: uppercase; white-space: nowrap; %s">%s</span>' % (st, t)
SHEET_START = '<div style="position: absolute; inset: 0; display: flex; flex-direction: column; background: rgba(20,18,17,.55);">'
def strip_sheet(s):
    i = s.index(SHEET_START); j = s.rindex('</div>\n</x-dc>')
    return s[:i] + s[j:]

# ================= Row A: app states with no board
# 1 Explore offline with cached list
s = rd('r-explore.dc.html')
s = title(s, 'Explore: offline, last list kept')
s = rep(s, 'Hyderabad · 18 beds free now', 'Hyderabad')
a = '<div style="flex-grow: 1; overflow: hidden; border-top: 2px solid var(--dv); padding-top: 14px;">'
s = rep(s, a, a + '<button style="margin: 0 16px 14px; width: calc(100% - 32px); padding: 10px 12px; border: 2px solid var(--tx); display: grid; grid-template-columns: 20px minmax(0, 1fr); gap: 10px; align-items: center; font-size: 14px; line-height: 1.35;">' + ico('wifi', 20) + '<span><b>Offline.</b> Hostels as of 2 Oct, 9:05 pm. Tap to try again.</span></button>')
s = rep(s, '#1 near you', 'Saved 2 Oct, 9:05 pm')
wr('w1-exploreCached.dc.html', s)

# 2 Map: no hostels here
s = rd('map.dc.html')
s = title(s, 'Map: no hostels in this area yet')
s = re.sub(r'<button aria-label="Hostel ₹[^"]*".*?</button>', '', s, flags=re.S)
s = rep(s, '</svg>Hitec City</button>', '</svg>Jubilee Hills</button>')
card = ('<div style="position: absolute; left: 12px; right: 12px; bottom: 12px; background: var(--bg); border: 2px solid var(--tx); padding: 14px; display: grid; gap: 6px;">'
        '<b style="font-size: 18px;">No hostels in Jubilee Hills yet</b><span style="font-size: 14px; color: var(--mu); line-height: 1.4;">We add hostels area by area, after we visit each one. Try a nearby area.</span>'
        '<div style="display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 8px; margin-top: 6px;">' + btn('Try Madhapur', 'red', 'arrow', 46, 14) + btn('Pick another area', 'out', 'pin', 46, 14) + '</div></div></div>')
i = s.index('<div style="position: absolute; left: 12px; right: 12px; bottom: 12px;'); j = s.index('<nav', i)
s = s[:i] + card + s[j:]
s = rep(s, 'bottom: 150px; padding: 1px 4px;', 'bottom: 180px; padding: 1px 4px;')
wr('w1-mapEmpty.dc.html', s)

# 3 Holds: ended and released
s = rd('holds.dc.html')
s = title(s, 'Holds: ended and released')
s = rep(s, 'background: var(--ab); color: var(--ad); border: 1px solid var(--ab);">Held</span>', 'border: 1px solid var(--dv); color: var(--mu);">Ended</span>')
s = rep(s, '<b style="font-size: 22px;">42:10</b><span style="font-size: 12px; color: var(--mu);">left</span>', '<b style="font-size: 22px; color: var(--mu);">0:00</b><span style="font-size: 12px; color: var(--mu);">30 Sep</span>')
s = rep(s, 'background: var(--tx); color: var(--bg); border: 1px solid var(--tx);">Booked</span><b style="font-size: 16px; margin-top: 2px;">Bed 201-C</b><span style="font-size: 13px; color: var(--mu);">Sai Sri Ladies Hostel · move in 5 Oct</span></span><span style="display: grid; justify-items: end;"><b style="font-size: 22px;">5 Oct</b><span style="font-size: 12px; color: var(--mu);">move in</span>',
        'border: 1px solid var(--dv); color: var(--mu);">Released</span><b style="font-size: 16px; margin-top: 2px;">Bed 102-C</b><span style="font-size: 13px; color: var(--mu);">Greenview Men’s PG · you let it go</span></span><span style="display: grid; justify-items: end;"><b style="font-size: 22px; color: var(--mu);">29 Sep</b><span style="font-size: 12px; color: var(--mu);">released</span>')
i = s.index('<div style="margin: 12px 16px; padding: 12px; border: 2px solid var(--tx); display: grid; gap: 8px;">'); j = s.index('<nav', i)
s = s[:i] + '<div style="padding: 14px 16px; display: grid; gap: 10px;"><span style="font-size: 13px; color: var(--mu); line-height: 1.45;">Ended and released holds stay here for 7 days. Tap one to hold the bed again if it’s still free.</span>' + btn('Find a bed', 'out', 'arrow', 48, 14) + '</div></div>' + s[j:]
wr('w1-holdsEnded.dc.html', s)

# 4 Me: Your refund on top
s = rd('me.dc.html')
s = title(s, 'Me: Your refund on top after moving out')
k = '<b style="font-size: 16px;">Saved</b>'
i = s.rindex('<button style="width: 100%; display: grid; grid-template-columns: 36px', 0, s.index(k))
row = ('<button style="width: 100%; display: grid; grid-template-columns: 36px minmax(0, 1fr) 16px; gap: 12px; align-items: center; padding: 12px 16px; border-bottom: 1px solid var(--hl); background: var(--ab);">'
       '<span style="width: 36px; height: 36px; display: grid; place-items: center; background: var(--bg);">' + ico('money') + '</span>'
       '<span style="display: grid; gap: 1px;"><b style="font-size: 16px;">Your refund</b><span style="font-size: 13px; color: var(--ad); font-weight: 600;">₹2,000 · did it arrive?</span></span>' + ico('chev', 16) + '</button>')
s = s[:i] + row + s[i:]
wr('w1-meRefund.dc.html', s)

# 5 Resident Rent: stay not on Hostelzy yet
s = rd('r-home.dc.html')
s = title(s, 'Rent: your stay isn’t on Hostelzy yet')
i = s.index('<div data-hz=""'); i = s.index('>', i) + 1; j = s.index('<nav', i)
body = ('<div style="flex: none; padding: 12px 16px 12px; display: grid; gap: 4px;">' + kick('Your stay') + '<b style="display: block; font-size: 32px; line-height: 1.02; letter-spacing: -.025em;">Rent</b></div>'
        '<div style="flex-grow: 1; overflow: hidden; border-top: 2px solid var(--tx); padding: 20px 16px; display: grid; gap: 14px; align-content: start;">'
        '<div style="padding: 16px; border: 2px dashed var(--dv); display: grid; gap: 6px;"><b style="font-size: 18px;">Your stay isn’t on Hostelzy yet</b><span style="font-size: 14px; color: var(--mu); line-height: 1.45;">Once your owner adds you, your rent shows here: the amount, the due date and the owner’s UPI ID.</span></div>'
        '<span style="font-size: 13px; color: var(--mu); line-height: 1.45;">Joined with a code? Your owner still has to approve you. It usually takes a day.</span></div>')
s = s[:i] + body + s[j:]
s = s.replace('color: var(--tx); box-shadow: inset 0 3px 0 var(--ac);">', 'color: var(--mu);">', 1)
wr('w1-rNotYet.dc.html', s)

# 6 Owner Today: notice, move, refund
s = rd('r-today.dc.html')
s = title(s, 'Today: notice, move and refund cards')
def trow(ic, t, sub, right, rred, btns):
    rc = 'var(--ad)' if rred else 'var(--mu)'
    b = '<div style="display: grid; grid-template-columns: repeat(%d, minmax(0, 1fr)); gap: 8px;">%s</div>' % (len(btns), ''.join(btns)) if btns else ''
    return ('<div style="padding: 12px 16px; border-bottom: 1px solid var(--hl); display: grid; gap: 8px;"><div style="display: grid; grid-template-columns: 36px minmax(0, 1fr) auto; gap: 10px; align-items: center;"><span style="width: 36px; height: 36px; display: grid; place-items: center; background: var(--sf);">%s</span><span style="display: grid; gap: 1px;"><b style="font-size: 15px;">%s</b><span style="font-size: 12px; color: var(--mu);">%s</span></span><b style="font-size: 14px; color: %s;">%s</b></div>%s</div>') % (ico(ic), t, sub, rc, right, b)
rows = (trow('out', 'Rahul Varma gave notice', 'Bed 204-B · Last day 31 Oct · New job', '2 h ago', False, [btn('Accept', 'red', 'check', 40, 13), btn('Say no', 'out', 'x', 40, 13)])
        + trow('swap', 'Sai Kiran asks to move to bed 201-C', 'Bed 204-C · Wants an AC room', 'Today', False, [btn('Accept', 'red', 'check', 40, 13), btn('Say no', 'out', 'x', 40, 13)])
        + trow('money', 'Refund ₹2,000 to Arjun Reddy', 'Moved out 3 Oct · due 10 Oct', 'Due 10 Oct', True, [btn('Mark refunded', 'red', 'arrow', 40, 13)])
        + trow('money', 'Refund sent to Teja Naidu', 'UPI ref 4021 9910 2245 · waiting for them to confirm', '', False, []))
i = s.index('<div style="flex-grow: 1; overflow: hidden;">'); j = s.index('<nav', i)
s = s[:i] + '<div style="flex-grow: 1; overflow: hidden;"><div style="padding: 0 16px 6px; display: flex; justify-content: space-between; align-items: baseline; gap: 12px;">' + kick('Needs you now · 3') + '<span style="font-size: 12px; font-weight: 800; color: var(--mu);">Soonest first</span></div><div style="border-top: 2px solid var(--tx);">' + rows + '</div><div style="padding: 12px 16px; font-size: 13px; color: var(--mu); line-height: 1.45;">Accept frees the bed from the last day. A move starts the new rent next month. Refunds are due 7 days after leaving.</div></div>' + s[j:]
wr('w1-oTodayMoves.dc.html', s)

# 7 Owner bed sheet: leaving, then moved out
base_sheet = rd('bedSheet.dc.html')
def bedsheet(tt, k, t, rows, btns, note=''):
    s = strip_sheet(base_sheet)
    s = title(s, tt)
    i = s.rindex('</div>\n</x-dc>')
    return s[:i] + sheet(kick(k), t, rows, btns, note) + s[i:]
s = bedsheet('Bed sheet: leaving, then moved out', 'Free from 31 Oct', 'Bed 204-B',
             [srow('Resident', 'Rahul Varma · rent paid'), srow('Room', '204 · 4 sharing · door side'), srow('Rent', '₹7,600 a month'), srow('Since', 'Mar 2026 · before Hostelzy'), srow('Advance', '₹3,000 · ₹1,000 kept on exit')],
             [btn('Message Rahul', 'out', 'msg'), btn('Rahul moved out', 'ink', 'out'), '<a href="#" style="padding-top: 4px; font-size: 14px; font-weight: 800; color: var(--tx);">Room 204 layout ›</a>'],
             'Tap “Rahul moved out” on the day he leaves. Then refund ₹2,000 within 7 days.')
wr('w1-bedSheetLeaving.dc.html', s)

# 8/9 Console: not set up, couldn't start
s = rd('cSignin.dc.html')
s = title(s, 'Team console: not set up yet')
i = s.index('<p style="margin: 0; color: var(--mu); font-size: 14px;">'); j = s.index('</div></div>', i)
s1 = s[:i] + '<p style="margin: 0; color: var(--mu); font-size: 14px; line-height: 1.5;">Not set up yet. The founder adds the Firebase web app config (docs/FOUNDER-TODO.md), then this page works.</p>' + tag('Founder step', 'red') + s[j:]
wr('w1-cNotSetup.dc.html', s1)
s2 = title(s, 'Team console: couldn’t start')
s2 = rep(s2, '>Team console</h1>', '>Couldn’t start</h1>')
s2 = s2[:i] + ('<p style="margin: 0; color: var(--mu); font-size: 14px; line-height: 1.5;">The console couldn’t reach Hostelzy. Check your internet, then try again.</p>'
               '<code style="padding: 10px 12px; background: var(--sf); font-size: 13px; color: var(--ad);">Firebase: network request failed</code>'
               + btn('Try again', 'ink', 'reload', 52, 15) + '<p style="margin: 0; color: var(--mu); font-size: 12px;">Still stuck? Send this message to the founder on WhatsApp.</p>') + s2[j:]
wr('w1-cError.dc.html', s2)

# ================= Row B: F24 items
# 13 price fixed: owner booked-bed sheet
s = bedsheet('Bed sheet: booked, price fixed', 'Booked through Hostelzy', 'Bed 204-D',
             [srow('Tenant', 'Ravi Teja · HZ-4830'), srow('Moves in', 'Mon 5 Oct'), srow('Price fixed', '₹5,800 a month for his whole stay'), srow('Hostelzy deal', '₹200 off every month · ₹1,500 lower advance', 'color: var(--gn);'), srow('Advance', '₹1,500 · paid 2 Oct')],
             [btn('Message Ravi', 'ink', 'msg')],
             'Ravi’s price and deal stay the same even if you change your rates or deals later. He sees the same on his booking.')
wr('w1-oPriceFixed.dc.html', s)

# 20 featured spot on Explore
s = rd('r-explore.dc.html')
s = title(s, 'Explore: featured spot for an 80+ bed hostel')
s = rep(s, '#1 near you', 'Featured · 96 beds')
s = rep(s, '<b style="font-size: 17px;">Anjani Residency</b>', '<b style="font-size: 17px;">Orchid Grand Men’s PG</b>')
s = rep(s, 'Men · Madhapur · 2.1 km from Hitec City · 9 free', 'Men · Madhapur · 1.4 km from Hitec City · 12 free')
a = '<div style="flex-grow: 1; overflow: hidden; border-top: 2px solid var(--dv); padding-top: 14px;">'
s = rep(s, a, a + '<div style="padding: 0 16px 8px; display: flex; justify-content: space-between; gap: 8px;">' + kick('Featured in Madhapur') + '<a href="#" style="font-size: 12px; font-weight: 800; color: var(--mu);">Why? ›</a></div>')
first_end = '<span style="color: var(--mu);">electricity extra</span></span></div>'
i = s.index(first_end) + len(first_end)
s = s[:i] + '<div style="padding: 0 16px 8px; border-top: 2px solid var(--tx); padding-top: 12px;">' + kick('Ranked by residents · never paid') + '</div>' + s[i:]
s = s.replace('<span style="position: absolute; right: 8px; top: 8px; width: 40px; height: 40px; display: grid; place-items: center; background: var(--bg); color: var(--ad);">', '', 0)
s = rep(s, '<b style="font-size: 17px;">Sai Sri Ladies Hostel</b>', '<b style="font-size: 17px;">Anjani Residency</b>')
s = rep(s, 'Women · Kondapur · 3.4 km · 6 free', 'Men · Madhapur · 2.1 km · #1 near you · 9 free')
wr('w1-featured.dc.html', s)

# 23 edit name (settings sheet) + About you never pre-filled
s = rd('settings.dc.html')
s = title(s, 'Settings: edit your name')
s = rep(s, '<b style="font-size: 16px; color: var(--tx);">Name</b><span style="font-size: 14px; color: var(--mu);">Ravi Teja</span>', '<b style="font-size: 16px; color: var(--tx);">Name</b><span style="display: flex; gap: 6px; align-items: center; font-size: 14px; color: var(--mu);">Ravi Teja' + ico('chev', 16) + '</span>')
i = s.rindex('</div>\n</x-dc>')
field = ('<div style="padding: 14px 16px 0; display: grid; gap: 6px;"><label style="display: grid; gap: 6px;"><b style="font-size: 13px;">Your name</b><input value="Ravi Teja" placeholder="Full name" style="height: 46px; padding: 0 12px; border: 2px solid var(--tx); background: var(--bg); font-size: 15px; width: 100%;"></label>'
         '<span style="font-size: 13px; color: var(--mu); line-height: 1.4;">Owners see this on your holds and enquiries. Use the name on your ID.</span></div>')
s = s[:i] + sheet(kick('Settings'), 'Your name', [field], [btn('Save name', 'red', 'check'), btn('Cancel', 'out', None)]) + s[i:]
wr('w1-editName.dc.html', s)

s = rd('about.dc.html')
s = title(s, 'About you: name empty, Google name as a hint')
s = rep(s, '<input value="Ravi Teja" placeholder=""', '<input value="" placeholder="Full name"')
s = rep(s, 'font-size: 15px; width: 100%;"></label>', 'font-size: 15px; width: 100%;"></label><div style="margin-top: 8px; display: flex; gap: 8px; align-items: center; flex-wrap: wrap; font-size: 13px; color: var(--mu);">Google says <button style="height: 32px; padding: 0 10px; border: 1px solid var(--dv); font-size: 13px; font-weight: 800; color: var(--tx);">Use “Ravi Teja”</button></div>')
wr('w1-aboutEmpty.dc.html', s)

# 21 deals paused on the hostel page
s = rd('r-detail.dc.html')
s = title(s, 'Hostel page: deals paused, walk-in prices')
s = rep(s, '<div style="padding: 10px; display: grid; gap: 2px; background: var(--gb); border-bottom: 2px solid var(--tx);"><span style="font-size: 11px; font-weight: 800; letter-spacing: .08em; color: var(--gn);">HOSTELZY DEAL</span><b style="font-size: 22px; line-height: 1.1; color: var(--gn);">Save ₹2,700 in 6 months</b><span style="font-size: 13px; color: var(--gn); font-weight: 600;">₹1,500 off the advance + ₹200 off every month</span></div>',
        '<div style="padding: 10px; display: grid; gap: 2px; background: var(--sf); border-bottom: 2px solid var(--tx);"><span style="font-size: 11px; font-weight: 800; letter-spacing: .08em; color: var(--mu);">HOSTELZY DEALS PAUSED</span><b style="font-size: 20px; line-height: 1.1;">Walk-in prices for now</b><span style="font-size: 13px; color: var(--mu);">This hostel’s deals are paused for a while. Holds and bookings work as normal.</span></div>')
s = re.sub(r'<span style="padding: 9px 10px; display: grid; gap: 1px; border-left: 1px solid var\(--hl\); background: var\(--gb\);"><b style="font-size: 17px; color: var\(--gn\);">₹[0-9,]+</b><span style="font-size: 12px; color: var\(--mu\); text-decoration: line-through;">(₹[0-9,]+) walk-in</span>',
           r'<span style="padding: 9px 10px; display: grid; gap: 1px; border-left: 1px solid var(--hl);"><b style="font-size: 17px; color: var(--tx);">\1</b><span style="font-size: 12px; color: var(--mu);">walk-in price</span>', s)
s = rep(s, 'Green = with Hostelzy. Struck out = walk-in price. Advance with Hostelzy ₹1,500 (walk-in ₹3,000).', 'Everyone pays the walk-in price while deals are paused. Advance ₹3,000.')
s = s.replace('From ₹5,800/mo', 'From ₹6,000/mo').replace('₹8,800 to move in', '₹9,000 to move in')
wr('w1-dealsPaused.dc.html', s)

# 7 AC under repair (tenant room view)
s = rd('room.dc.html')
s = title(s, 'Room: AC under repair')
s = rep(s, 'font-size: 10px; font-weight: 800;">AC UNIT</span>', 'font-size: 10px; font-weight: 800; color: var(--ad);">AC · UNDER REPAIR</span>')
s = rep(s, '<div style="padding: 12px; border: 2px solid var(--tx); display: grid; gap: 4px;"><b style="font-size: 16px;">Bed B · free</b>',
        '<div style="padding: 10px 12px; background: var(--ab); color: var(--ad); font-size: 14px; line-height: 1.4;"><b>AC under repair.</b> Complaint raised 1 Oct. The owner is fixing it.</div><div style="padding: 12px; border: 2px solid var(--tx); display: grid; gap: 4px;"><b style="font-size: 16px;">Bed B · free</b>')
s = rep(s, 'Window side · under the fan · AC airflow · door 4 m away', 'Window side · under the fan · AC under repair · door 4 m away')
wr('w1-acRepair.dc.html', s)

# 8 Hold for a walk-in
s = bedsheet('Bed sheet: free bed, hold for a walk-in', 'Free', 'Bed 202-A',
             [srow('Room', '202 · 2 sharing · window side'), srow('Rent', '₹9,000 a month'), srow('Free since', '28 Sep')],
             [btn('Add tenant to this bed', 'ink', 'plus'), btn('Hold for a walk-in', 'out', 'clock')],
             'Someone at the gate? A walk-in hold keeps this bed off Hostelzy for 1 hour. It frees itself after that.')
wr('w1-walkInHold.dc.html', s)
s = bedsheet('Bed sheet: held for a walk-in', 'On hold · walk-in', 'Bed 202-A',
             [srow('Held', '52 min left', 'color: var(--ad);'), srow('Held by', 'You · today 6:10 pm'), srow('Room', '202 · 2 sharing · window side'), srow('Rent', '₹9,000 a month')],
             [btn('Add tenant to this bed', 'ink', 'plus'), btn('Release now', 'out', 'x')],
             'Tenants see this bed as “On hold” until the hour ends.')
wr('w1-walkInHeld.dc.html', s)

# 14 Did you join? three choices
s = rd('holds.dc.html')
s = title(s, 'Holds: Did you join? three answers')
i = s.index('<div style="margin: 12px 16px; padding: 12px; border: 2px solid var(--tx); display: grid; gap: 8px;">'); j = s.index('<nav', i)
q = ('<div style="margin: 12px 16px; padding: 12px; border: 2px solid var(--tx); display: grid; gap: 8px;"><b style="font-size: 15px;">Did you join Greenview Men’s PG?</b>'
     '<span style="font-size: 13px; color: var(--mu); line-height: 1.4;">Your hold on bed 102-C ended on 30 Sep. One tap helps us keep owners fair.</span>'
     + btn('Yes, I joined', 'red', 'check', 44, 14) + '<div style="display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 8px;">' + btn('Not yet', 'out', None, 44, 14) + btn('Still deciding', 'out', None, 44, 14) + '</div>'
     '<span style="font-size: 12px; color: var(--mu);">Your answer goes to Hostelzy, never to the owner.</span>'
     '<a href="#" style="font-size: 13px; font-weight: 800; color: var(--ad);">The owner asked me to skip the app ›</a></div></div>')
s = s[:i] + q + s[j:]
wr('w1-didJoin.dc.html', s)

# 27 Tell me when it's ready
s = rd('room.dc.html')
s = title(s, 'Room: layout coming soon, tell me when it’s ready')
i = s.index('<div data-hz=""'); i = s.index('>', i) + 1; j = s.index('<div style="flex: none; border-top: 2px solid var(--tx); padding: 12px 16px;', i)
body = ('<div style="flex: none; padding: 12px 16px 12px; display: flex; gap: 12px; align-items: flex-start;"><button aria-label="Back" style="width: 44px; height: 44px; flex: none; display: grid; place-items: center; border: 1px solid var(--dv);"><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="square" style="flex: none;"><path d="m15 18-6-6 6-6"/></svg></button><div style="display: grid; gap: 2px;">' + kick('Anjani Residency · 2 sharing') + '<b style="display: block; font-size: 30px; line-height: 1.02; letter-spacing: -.025em;">Room 105</b></div></div>'
        '<div style="flex-grow: 1; overflow: hidden; border-top: 2px solid var(--tx); padding: 16px; display: grid; gap: 14px; align-content: start;">'
        '<div style="padding: 20px 16px; border: 2px dashed var(--dv); display: grid; gap: 8px; justify-items: start;">' + ico('pencil', 24) + '<b style="font-size: 18px;">Layout coming soon</b><span style="font-size: 14px; color: var(--mu); line-height: 1.45;">The owner is drawing this room. You can still pick a bed from Plan or List, and see the photos.</span>'
        '<button style="margin-top: 6px; width: 100%; height: 48px; padding: 0 16px; display: flex; justify-content: space-between; align-items: center; font-weight: 800; font-size: 14px; background: var(--tx); color: var(--bg);">We’ll tell you when it’s ready' + ico('check') + '</button>'
        '<span style="font-size: 12px; color: var(--mu);">One notification when Room 105’s layout is published. Turn it off in Settings › Notifications.</span></div>'
        '<span style="font-size: 13px; color: var(--mu); line-height: 1.45;">Layouts are drawn by the owner, or by Hostelzy after a visit, so what you see matches the room.</span></div>')
s = s[:i] + body + s[j:]
s = s.replace('Bed 204-B · ₹5,800/mo', 'Bed 105-A · ₹8,800/mo')
wr('w1-notifyReady.dc.html', s)

# 22 notification switches
s = rd('settings.dc.html')
s = title(s, 'Settings: notification switches')
def sw(t, sub, on=True):
    tr = 'justify-content: flex-end; padding: 2px; background: var(--tx);"><span style="width: 16px; height: 16px; background: var(--bg);"></span>' if on else 'justify-content: flex-start; padding: 2px; background: transparent;"><span style="width: 16px; height: 16px; background: var(--tx);"></span>'
    return '<div style="display: grid; grid-template-columns: minmax(0, 1fr) auto; gap: 12px; align-items: center; padding: 10px 16px; border-bottom: 1px solid var(--hl);"><span style="display: grid; gap: 1px;"><b style="font-size: 16px;">%s</b><span style="font-size: 13px; color: var(--mu);">%s</span></span><span role="switch" aria-checked="%s" aria-label="%s" style="width: 44px; height: 24px; flex: none; border: 2px solid var(--tx); display: flex; %s</span></div>' % (t, sub, 'true' if on else 'false', t, tr)
a = kick('Notifications') + '</div><div style="border-top: 2px solid var(--tx);">'
i = s.index(a) + len(a); j = s.index('</div><div style="padding: 20px 16px 6px;', i)
s = s[:i] + sw('Holds and bookings', 'When the owner confirms or replies') + sw('Rent reminders', '3 days before and on the day') + sw('New free beds', 'In areas you searched') + sw('Layout ready', 'Rooms you asked to hear about', False) + '<div style="padding: 8px 16px; font-size: 12px; color: var(--mu);">Saved to your account. Hostelzy sends only what’s on.</div>' + s[j:]
wr('w1-notifSwitches.dc.html', s)

# 18 console: strikes on Hostels
s = rd('cHostels.dc.html')
s = title(s, 'Team console: hostels with Fair Play strikes')
s = s.replace('font-weight: 600; text-decoration: none; color: var(--mu);">Hostels</a>', 'font-weight: 600; text-decoration: none; color: var(--tx); background: var(--sf); box-shadow: inset 4px 0 0 var(--ac);">Hostels</a>')
th = 'padding: 10px 12px; font-size: 12px; font-weight: 800; letter-spacing: .06em; text-transform: uppercase; color: var(--mu); text-align: left; border-bottom: 2px solid var(--tx);'
td = 'padding: 12px; border-bottom: 1px solid var(--hl); font-size: 14px; vertical-align: top;'
def hrow(name, area, st, stk, stkSub, act, sel=False):
    bg = ' background: var(--ab);' if sel else ''
    return '<tr style="%s"><td style="%s"><b>%s</b><br><span style="color: var(--mu);">%s</span></td><td style="%s">%s</td><td style="%s"><b>%s</b><br><span style="color: var(--mu);">%s</span></td><td style="%s">%s</td></tr>' % (bg, td, name, area, td, st, td, stk, stkSub, td, act)
sbtn = lambda t, k='out': '<button style="height: 36px; padding: 0 12px; font-weight: 800; font-size: 13px; %s">%s</button>' % ('border: 2px solid var(--tx);' if k == 'out' else 'background: var(--ac); color: var(--ai);', t)
table = ('<table style="width: 100%%; border-collapse: collapse;"><thead><tr><th style="%s">Hostel</th><th style="%s">Status</th><th style="%s">Fair Play</th><th style="%s"></th></tr></thead><tbody>' % (th, th, th, th)
         + hrow('Anjani Residency', 'Madhapur · Men', tag('live', 'ink'), 'Strike 1 of 3 · Warning', 'FP-0142 · 12 Sep · nothing changed', sbtn('Pause'))
         + hrow('Green Nest Co-living', 'Madhapur · Co-living', tag('live', 'ink'), 'Strike 2 of 3 · Deals hidden', 'FP-0006 · 3 Oct · deals back on 2 Nov', sbtn('Pause'), True)
         + hrow('Sai Krupa PG', 'Ameerpet · Men', tag('removed', 'red'), 'Strike 3 of 3 · Removed', 'FP-0009 · 30 Sep · hidden from tenants', sbtn('Open cases'))
         + hrow('Lakshmi Ladies Hostel', 'SR Nagar · Women', tag('draft'), 'No strikes', 'Layout fixes against it: 1 of 3 in 6 months', sbtn('Go live'))
         + '</tbody></table>')
detail = ('<section style="border-left: 2px solid var(--tx); padding: 20px; display: grid; gap: 12px; align-content: start;">' + kick('Green Nest Co-living · Fair Play') + '<h2 style="margin: 0; font-size: 24px; font-weight: 800;">Strike 2 of 3 · deals hidden for 30 days</h2>'
          '<div style="display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); border: 2px solid var(--tx);">'
          '<div style="padding: 10px; display: grid; gap: 2px; border-right: 1px solid var(--hl);"><b>Strike 1</b><span style="font-size: 13px; color: var(--mu);">Warning · 4 Aug</span></div>'
          '<div style="padding: 10px; display: grid; gap: 2px; border-right: 1px solid var(--hl); background: var(--ab); color: var(--ad);"><b>Strike 2</b><span style="font-size: 13px;">Deals hidden · 3 Oct → 2 Nov</span></div>'
          '<div style="padding: 10px; display: grid; gap: 2px; color: var(--mu);"><b>Strike 3</b><span style="font-size: 13px;">Removed from Hostelzy</span></div></div>'
          '<div style="font-size: 14px; line-height: 1.5;">Deals come back on their own on <b>Mon 2 Nov</b>. Tenants see walk-in prices until then. Listing, holds and residents keep working.</div>'
          '<div style="padding: 10px 12px; background: var(--sf); font-size: 13px; line-height: 1.5; color: var(--mu);">Counted from the server: 3 layout fixes in 6 months = 1 warning. Strikes come only from a decided case, after 48 hours for the owner’s side. No fines.</div>'
          '<div style="display: flex; gap: 8px;">' + sbtn('See FP-0006') + sbtn('Lift strike 2') + '</div></section>')
main = ('<main style="min-width: 0; display: grid; grid-template-columns: minmax(0, 1fr) 460px;"><div style="min-width: 0;"><div style="padding: 20px 24px 12px; display: flex; justify-content: space-between; align-items: baseline; gap: 16px;"><h1 style="font-size: 28px; margin: 0; font-weight: 800;">Hostels</h1><span style="font-size: 13px; color: var(--mu);">4 in Hostelzy · 2 with strikes</span></div><div style="padding: 0 12px;">' + table + '</div></div>' + detail + '</main>')
i = s.index('<main'); j = s.index('</main>') + len('</main>')
s = s[:i] + main + s[j:]
wr('w1-cStrikes.dc.html', s)

# cCases: correct strike label
s = rd('cCases.dc.html')
s = s.replace('Strike · warning', 'Strike 1 of 3 · warning')
open(P + 'cCases.dc.html', 'w').write(s)
print(len(OUT), OUT)
