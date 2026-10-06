import re
src = open('/tmp/claude-0/-home-user-hostelzy/58cdc0a8-c7d4-5e26-828b-40f705b32de2/scratchpad/w1.py').read()
exec(src[:src.index('# ================= Row A')])
I['qr'] = '<path d="M3 3h7v7H3zM14 3h7v7h-7zM3 14h7v7H3z"/><path d="M14 14h3v3h-3zM21 14v1M14 21h1M18 18h3v3"/>'
I['lock'] = '<rect x="4" y="11" width="16" height="10"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/>'
I['back'] = '<path d="m15 18-6-6 6-6"/>'
I['flag'] = '<path d="M4 21V4h12l-2 4 2 4H4"/>'
UPD = []
def upd(name, s): open(P + name, 'w').write(s); UPD.append(name)
def root_inner(s):
    i = s.index('<div data-hz=""'); i = s.index('>', i) + 1; return i
def head(k, t, back=True):
    b = '<button aria-label="Back" style="width: 44px; height: 44px; flex: none; display: grid; place-items: center; border: 1px solid var(--dv);">' + ico('back', 20) + '</button>' if back else ''
    return '<div style="flex: none; padding: 12px 16px 12px; display: flex; gap: 12px; align-items: flex-start;">' + b + '<div style="flex-grow: 1; display: grid; gap: 2px;">' + kick(k) + '<b style="display: block; font-size: 30px; line-height: 1.02; letter-spacing: -.025em;">' + t + '</b></div></div>'
def mut(t, fs=14): return '<span style="font-size: %dpx; color: var(--mu); line-height: 1.45;">%s</span>' % (fs, t)
def field(label, val, ph, pre=''):
    inp = '<input value="%s" placeholder="%s" style="height: 46px; padding: 0 12px; border: 0; background: var(--bg); font-size: 15px; width: 100%%;">' % (val, ph)
    box = ('<div style="display: grid; grid-template-columns: 64px minmax(0, 1fr); border: 2px solid var(--tx);"><span style="display: flex; align-items: center; padding: 0 12px; border-right: 2px solid var(--tx); font-weight: 800;">%s</span>%s</div>' % (pre, inp)) if pre else inp.replace('border: 0;', 'border: 2px solid var(--tx);')
    return '<label style="display: grid; gap: 6px;"><b style="font-size: 13px;">%s</b>%s</label>' % (label, box)

# ---------- NEW boards
# Settings: WhatsApp number sheet (owner)
s = rd('settings.dc.html'); s = title(s, 'Settings: your WhatsApp number (owner)')
s = rep(s, '<span style="font-size: 14px; color: var(--mu);">Ravi Teja</span>', '<span style="font-size: 14px; color: var(--mu);">Srinivas</span>')
i = s.rindex('</div>\n</x-dc>')
body = '<div style="padding: 14px 16px 0; display: grid; gap: 8px;">' + field('WhatsApp number', '98480 22110', '10-digit number', '+91') + mut('Only if you chat on a different number than you take calls on. Tenants who held a bed and your residents message you here.', 13) + '</div>'
s = s[:i] + sheet(kick('Settings'), 'Your WhatsApp number', [body], [btn('Save WhatsApp number', 'red', 'check'), btn('Use my phone number', 'out', None)]) + s[i:]
wr('w2-waSheet.dc.html', s)

# Owner only (manager)
s = rd('r-manage.dc.html'); s = title(s, 'Owner only: what a manager sees')
i = root_inner(s); j = s.index('<nav', i)
s = s[:i] + head('Anjani Residency · Manager', 'Owner only') + ('<div style="flex-grow: 1; overflow: hidden; border-top: 2px solid var(--tx); padding: 20px 16px; display: grid; gap: 12px; align-content: start;">'
    '<b style="font-size: 18px; line-height: 1.3;">Only the owner can see the Hostelzy plan and its invoices.</b>'
    + mut('You manage Anjani Residency: beds, residents, enquiries, complaints, food and room layouts. Ask Srinivas about the Hostelzy plan, deals, rates or Fair Play.')
    + btn('Back to Manage', 'out', 'back') + '</div>') + s[j:]
wr('w2-ownerOnly.dc.html', s)

# Report abuse sheet (owner reviews)
s = rd('oReviews.dc.html'); s = title(s, 'Reviews: report abuse')
s = s.replace('<div><button style="height: 40px; padding: 0 12px; font-weight: 800; font-size: 13px; border: 2px solid var(--tx);">Reply</button></div>',
              '<div style="display: flex; justify-content: space-between; align-items: center;"><button style="height: 40px; padding: 0 12px; font-weight: 800; font-size: 13px; border: 2px solid var(--tx);">Reply</button><a href="#" style="font-size: 13px; color: var(--mu);">Report abuse</a></div>', 1)
def radio(t, on=False):
    return '<div style="display: flex; gap: 12px; align-items: center; padding: 12px; border: %s; background: %s; font-size: 15px; font-weight: 600;"><span style="width: 18px; height: 18px; flex: none; border: 2px solid var(--tx); background: %s;"></span>%s</div>' % ('2px solid var(--tx)' if on else '1px solid var(--dv)', 'var(--sf)' if on else 'transparent', 'var(--tx)' if on else 'transparent', t)
body = '<div style="padding: 14px 16px 0; display: grid; gap: 8px;">' + radio('Abusive or rude words', True) + radio('Personal details like a phone number') + radio('Not written by a resident') + radio('Something else') + mut('Reviews can’t be removed for being low. The Hostelzy team hides a review only if it breaks the rules.', 13) + '</div>'
i = s.rindex('</div>\n</x-dc>')
s = s[:i] + sheet(kick('Karthik M.’s review'), 'Report this review', [body], [btn('Send to Hostelzy', 'red', 'arrow')]) + s[i:]
wr('w2-reportAbuse.dc.html', s)

# Console: Reported reviews
s = rd('cHostels.dc.html'); s = title(s, 'Team console: reported reviews')
th = 'padding: 10px 12px; font-size: 12px; font-weight: 800; letter-spacing: .06em; text-transform: uppercase; color: var(--mu); text-align: left; border-bottom: 2px solid var(--tx);'
td = 'padding: 12px; border-bottom: 1px solid var(--hl); font-size: 14px; vertical-align: top;'
sb = lambda t, k='out': '<button style="height: 36px; padding: 0 12px; font-weight: 800; font-size: 13px; %s">%s</button>' % ('border: 2px solid var(--tx);' if k == 'out' else 'background: var(--ac); color: var(--ai);', t)
def rr(h, rv, st, why, since):
    return '<tr><td style="%s"><b>%s</b></td><td style="%s">%s</td><td style="%s">%s</td><td style="%s">%s</td><td style="%s">%s</td><td style="%s"><span style="display: flex; gap: 6px;">%s%s</span></td></tr>' % (td, h, td, rv, td, st, td, why, td, since, td, sb('Hide', 'red'), sb('Keep'))
tbl = ('<table style="width: 100%%; border-collapse: collapse;"><thead><tr>' + ''.join('<th style="%s">%s</th>' % (th, c) for c in ['Hostel', 'Review', 'Stars', 'Reported for', 'Since', 'Action']) + '</tr></thead><tbody>'
       + rr('Anjani Residency', 'Karthik M. · 30-day: “Owner is a cheat, call him on 98480…”', '★ 1', 'Abusive or rude words · Personal details (2 reports)', '2 Oct')
       + rr('Green Nest Co-living', 'Anil P. · exit: “Never stayed here, just checking”', '★ 2', 'Not written by a resident', '1 Oct')
       + rr('Sai Krupa PG', 'Divya K. · 30-day: (no words)', '★ 2', 'Something else', '29 Sep') + '</tbody></table>')
main = ('<main style="min-width: 0;"><div style="padding: 20px 24px 6px; display: grid; gap: 6px;"><h1 style="font-size: 28px; margin: 0; font-weight: 800;">Reported reviews</h1><span style="font-size: 14px; color: var(--mu);">Hide a review only if it breaks the rules (abuse, personal details, not a resident). A low rating is not a reason.</span></div><div style="padding: 8px 12px;">' + tbl + '</div></main>')
i = s.index('<main'); j = s.index('</main>') + 7
s = s[:i] + main + s[j:]
wr('w2-cReported.dc.html', s)

# Map pin (aPin)
s = rd('r-home.dc.html'); s = title(s, 'Add hostel: map pin at the gate')
i = root_inner(s); j = s.index('</nav>') + 6
mapbg = 'background-color: var(--sf); background-image: linear-gradient(90deg, transparent 0 46%, var(--bg) 46% 50%, transparent 50%), linear-gradient(0deg, transparent 0 62%, var(--bg) 62% 65%, transparent 65%), linear-gradient(20deg, transparent 0 30%, var(--bg) 30% 32%, transparent 32%);'
lab = lambda t, l, tp: '<span style="position: absolute; left: %dpx; top: %dpx; font-size: 12px; font-weight: 800; letter-spacing: .1em; text-transform: uppercase; color: var(--mu);">%s</span>' % (l, tp, t)
pin = '<span aria-hidden="true" style="position: absolute; left: 50%; top: 50%; transform: translate(-50%, -100%); display: grid; justify-items: center;"><span style="width: 28px; height: 28px; border-radius: 50%; background: var(--ac); border: 4px solid #fff;"></span><span style="width: 3px; height: 18px; background: var(--ac);"></span></span>'
s = s[:i] + head('New hostel · Madhapur', 'Map pin') + ('<div style="flex-grow: 1; position: relative; border-top: 2px solid var(--tx); ' + mapbg + '">' + lab('Madhapur', 40, 90) + lab('Hitec City', 200, 380) + pin
    + '<span style="position: absolute; right: 8px; bottom: 6px; padding: 1px 4px; background: var(--bg); font-size: 10px; color: var(--mu);">© OpenStreetMap</span></div>'
    '<div style="flex: none; border-top: 2px solid var(--tx); padding: 12px 16px 20px; display: grid; gap: 8px;"><b style="font-size: 15px;">Pin at 17.44812, 78.39104</b>'
    + btn('Use my location', 'out', 'pin') + btn('Save pin', 'red', 'check') + '</div>') + s[j:]
wr('w2-aPin.dc.html', s)

# QR: camera sheet and scan screen
s = rd('gateRes.dc.html'); s = title(s, 'Join your PG: use your camera?')
s = rep(s, '>Scan the poster QR<', '>Scan the QR<')
i = s.rindex('</div>\n</x-dc>')
allow = '<button style="width: 100%; height: 60px; padding: 0 16px; display: flex; justify-content: space-between; align-items: center; background: var(--ac); color: var(--ai);"><span style="display: grid; text-align: left;"><b style="font-size: 15px;">Allow camera</b><span style="font-size: 12px;">Your phone asks next</span></span>' + ico('arrow') + '</button>'
s = s[:i] + sheet(kick('Join your PG'), 'Use your camera?', ['<div style="padding: 14px 16px 0;">' + mut('Only to read the QR on your PG’s Hostelzy poster. Nothing is recorded or saved, and nobody sees your camera.') + '</div>'], [allow, btn('Type the code instead', 'out', 'pencil')]) + s[i:]
wr('w2-qrCamera.dc.html', s)
s = rd('r-home.dc.html'); s = title(s, 'Join your PG: scan the QR')
i = root_inner(s); j = s.index('</nav>') + 6
vf = ('<div style="margin: 0 auto; width: 300px; height: 300px; position: relative; background: #201e1d; border: 2px solid var(--tx);">'
      '<span style="position: absolute; inset: 40px; border: 2px solid #f8f4f4;"></span><span style="position: absolute; left: 40px; right: 40px; top: 50%; height: 2px; background: var(--ac);"></span></div>')
s = s[:i] + head('Join your PG', 'Scan the QR') + ('<div style="flex-grow: 1; border-top: 2px solid var(--tx); padding: 24px 16px; display: grid; gap: 16px; align-content: start;">' + vf
    + mut('Point it at the QR on the Hostelzy poster at your PG. The code fills in by itself and your owner gets the request.') + '</div>'
    '<div style="flex: none; border-top: 2px solid var(--tx); padding: 12px 16px 20px;">' + btn('Type the code instead', 'out', 'pencil') + '</div>') + s[j:]
wr('w2-qrScan.dc.html', s)

# Today: rates card + strike card
s = rd('r-today.dc.html'); s = title(s, 'Today: are your rates still right? and Fair Play strike')
chip = lambda t: '<span style="padding: 4px 8px; border: 1px solid var(--dv); font-size: 13px; font-weight: 600;">%s</span>' % t
cards = ('<div style="flex-grow: 1; overflow: hidden; border-top: 2px solid var(--tx); padding: 14px 16px; display: grid; gap: 14px; align-content: start;">'
         '<div style="padding: 12px; background: var(--ab); color: var(--ad); display: grid; gap: 2px;"><b style="font-size: 15px;">Fair Play: strike 2 of 3</b><span style="font-size: 13px;">Deals hidden until 2 Nov</span></div>'
         '<div style="padding: 14px; border: 2px solid var(--tx); display: grid; gap: 10px;"><b style="font-size: 18px;">Are your rates still right?</b>' + mut('Last confirmed 3 Sep. Tenants see the date you last confirmed them.', 13)
         + '<div style="display: flex; gap: 6px; flex-wrap: wrap;">' + chip('2 sharing · ₹9,000') + chip('3 sharing · ₹7,000') + chip('3 sharing AC · ₹8,200') + chip('4 sharing · ₹6,000') + '</div>'
         '<div style="display: grid; grid-template-columns: minmax(0, 1fr) 120px; gap: 8px;">' + btn('Rates still right', 'red', 'check', 44, 14) + btn('Change', 'out', 'chev', 44, 14) + '</div>'
         + mut('Not confirmed for a month: tenants see “Not confirmed in over a month” on your prices.', 12) + '</div></div>')
i = s.index('<div style="flex-grow: 1; overflow: hidden;">'); j = s.index('<nav', i)
s = s[:i] + cards + s[j:]
wr('w2-oTodayRates.dc.html', s)

# Picker: women's PG floor locked, and list mode
pk = rd('picker.dc.html')
a = '<div style="display: flex; gap: 6px; padding: 12px 16px 6px; overflow: hidden;">'
i = pk.index(a); j = pk.rindex('</div>\n</x-dc>')
s = title(pk, 'Pick a bed: women’s PG floor plan locked until a hold').replace('>Anjani Residency<', '>Sai Sri Ladies Hostel<', 1)
s = s[:i] + ('<div style="flex-grow: 1; padding: 24px 16px; display: grid; gap: 12px; align-content: start; justify-items: start;">' + ico('lock', 28) + '<b style="font-size: 20px;">Floor plan shows after you hold a bed</b>'
    + mut('For residents’ safety, the full floor plan of a women’s PG opens only after a hold. Each room’s own layout is in the Room tab.') + btn('See rooms in the Room tab', 'out', 'arrow')
    + mut('Hostelzy never shows gates, CCTV, exits or residents’ names on any plan.', 12) + '</div>') + s[j:]
wr('w2-floorLocked.dc.html', s)
def lrow(b, sub, st, price):
    return '<button style="width: 100%; display: grid; grid-template-columns: 44px minmax(0, 1fr) auto; gap: 12px; align-items: center; padding: 12px 16px; border-bottom: 1px solid var(--hl);"><span style="width: 44px; height: 44px; display: grid; place-items: center; border: 2px solid var(--tx); font-size: 9px; color: var(--mu);">bed</span><span style="display: grid; gap: 1px;"><b style="font-size: 16px;">Bed ' + b + '</b><span style="font-size: 12px; color: var(--mu);">' + sub + '</span><span style="font-size: 12px; font-weight: 600;">' + st + '</span></span><b style="font-size: 15px;">' + price + '</b></button>'
s = title(pk, 'Pick a bed: list, cheapest first')
s = s[:i] + ('<div style="flex-grow: 1; overflow: hidden;"><div style="padding: 12px 16px 6px;">' + kick('6 beds you can take · cheapest first') + '</div><div style="border-top: 2px solid var(--tx);">'
    + lrow('204-D', 'Floor 2 · 4 sharing · Non-AC · shared bath', 'Window side · Free now', '₹5,800')
    + lrow('301-A', 'Floor 3 · 4 sharing · Non-AC · shared bath', 'Door side · Free from 15 Oct', '₹5,800')
    + lrow('102-C', 'Floor 1 · 3 sharing · Non-AC · attached bath', 'Under a fan · Free now', '₹6,800')
    + lrow('203-B', 'Floor 2 · 3 sharing · AC · attached bath', 'Window side · Free now', '₹8,000')
    + lrow('202-A', 'Floor 2 · 2 sharing · Non-AC · attached bath', 'Window side · Free now', '₹8,800') + '</div></div>'
    '<div style="flex: none; border-top: 2px solid var(--tx); padding: 12px 16px; display: grid; grid-template-columns: minmax(0, 1fr) auto; gap: 12px; align-items: center;"><span style="display: grid;"><b style="font-size: 17px;">Bed 204-D · ₹5,800/mo</b><span style="font-size: 12px; color: var(--mu);">Window side · under a fan</span></span><button style="height: 50px; padding: 0 16px; display: flex; gap: 10px; align-items: center; font-weight: 800; font-size: 15px; background: var(--ac); color: var(--ai);">Continue' + ico('arrow') + '</button></div>') + s[j:]
wr('w2-pickerList.dc.html', s)

# Explore: nothing matches the filters
s = rd('r-explore.dc.html'); s = title(s, 'Explore: nothing matches the filters')
a = '<div style="flex-grow: 1; overflow: hidden; border-top: 2px solid var(--dv); padding-top: 14px;">'
i = s.index(a); j = s.index('<nav', i)
s = s[:i] + a + '<div style="padding: 18px 16px; display: grid; gap: 10px; justify-items: start;"><b style="font-size: 20px;">Nothing matches yet.</b>' + mut('Try a higher budget or any room type.') + '<button style="padding: 10px 14px; border: 2px solid var(--tx); font-weight: 800; font-size: 14px;">Clear filters</button></div></div>' + s[j:]
s = s.replace('Hyderabad · 18 beds free now', 'Hyderabad · 0 beds match')
wr('w2-exploreNoMatch.dc.html', s)

# Resident Food: whole week
s = rd('r-home.dc.html'); s = title(s, 'Food: the whole week')
s = s.replace('color: var(--tx); box-shadow: inset 0 3px 0 var(--ac);">', 'color: var(--mu);">', 1)
s = rep(s, 'font-size: 11px; font-weight: 600; color: var(--mu);"><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="square" style="flex: none;"><path d="M7 3v8', 'font-size: 11px; font-weight: 600; color: var(--tx); box-shadow: inset 0 3px 0 var(--ac);"><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="square" style="flex: none;"><path d="M7 3v8')
i = root_inner(s); j = s.index('<nav', i)
days = [('Mon', 'Idli, sambar', 'Rice, dal, cabbage fry'), ('Tue', 'Poha', 'Rice, rasam, beans fry'), ('Wed', 'Upma, chutney', 'Veg biryani, raita'), ('Thu', 'Puri, aloo curry', 'Rice, sambar, potato fry'), ('Fri', 'Dosa, peanut chutney', 'Rice, tomato pappu, curd'), ('Sat', 'Pongal', 'Chicken curry or paneer'), ('Sun', 'Bread omelette', 'Rice, dal, egg curry')]
cell = 'padding: 10px 8px; border-bottom: 1px solid var(--hl); font-size: 13px; vertical-align: top;'
rows = ''.join('<tr style="%s"><td style="%s font-weight: 800;">%s</td><td style="%s">%s</td><td style="%s">%s</td></tr>' % ('background: var(--ab);' if d == 'Fri' else '', cell, d, cell, b, cell, l) for d, b, l in days)
thc = 'padding: 8px; font-size: 11px; font-weight: 800; letter-spacing: .08em; text-transform: uppercase; color: var(--mu); text-align: left; border-bottom: 2px solid var(--tx);'
s = s[:i] + ('<div style="flex: none; padding: 12px 16px; display: flex; justify-content: space-between; align-items: flex-end;"><div style="display: grid; gap: 4px;">' + kick('Anjani Residency') + '<b style="font-size: 32px; line-height: 1.02; letter-spacing: -.025em;">Food</b></div><a href="#" style="font-size: 14px; font-weight: 800; color: var(--tx); padding-bottom: 6px;">‹ By day</a></div>'
    '<div style="flex-grow: 1; overflow: hidden; border-top: 2px solid var(--tx); padding: 0 8px;"><table style="width: 100%; border-collapse: collapse;"><thead><tr><th style="' + thc + ' width: 52px;"></th><th style="' + thc + '">Breakfast · 7:30</th><th style="' + thc + '">Lunch · 12:30</th></tr></thead><tbody>' + rows + '</tbody></table>'
    '<div style="padding: 10px 8px;">' + mut('Today is highlighted. Swipe sideways for dinner. Tap a day to open it.', 12) + '</div></div>') + s[j:]
wr('w2-foodWeek.dc.html', s)

# Owner room layout: residents say it's wrong
s = rd('oLayout.dc.html'); s = title(s, 'Room layout: residents say it’s wrong')
s = rep(s, '<span>Hostelzy drew a new version · check and publish</span><span>v2 · drawn 1 Oct</span>', '<span>Residents say this layout is wrong</span><span>2 said “No”</span>')
s = rep(s, '<div style="flex-grow: 1; overflow: hidden;"><div style="margin: 0 16px; position: relative; height: 280px;', '<div style="flex-grow: 1; overflow: hidden;"><div style="margin: 0 16px 10px; font-size: 13px; color: var(--mu); line-height: 1.45;">2 residents answered “No” in the 30-day review. Check the room, fix the layout and publish it again.</div><div style="margin: 0 16px; position: relative; height: 280px;')
s = s.replace('>Publish v2<', '>Edit the layout<').replace('>Ask Hostelzy<', '>Ask Hostelzy to draw it<')
wr('w2-layoutWrong.dc.html', s)

# ---------- UPDATES to existing boards
s = rd('w1-editName.dc.html')
s = rep(s, '>Your name</span></span><button aria-label="Close"', '>Change your name</span></span><button aria-label="Close"')
s = rep(s, '<input value="Ravi Teja" placeholder="Full name"', '<input value="" placeholder="Ravi Teja"')
s = rep(s, 'Owners see this on your holds and enquiries. Use the name on your ID.', 'Owners see this name on your holds, enquiries and stay.')
s = s.replace(btn('Cancel', 'out', None), '')
s = title(s, 'Settings: change your name')
upd('w1-editName.dc.html', s)

s = rd('w1-aboutEmpty.dc.html')
s = rep(s, '<input value="" placeholder="Full name"', '<input value="" placeholder="Ravi Teja"')
s = re.sub(r'<div style="margin-top: 8px; display: flex; gap: 8px;.*?</button></div>', '<div style="margin-top: 6px; font-size: 13px; color: var(--mu);">Type the name owners should see.</div>', s, count=1, flags=re.S)
upd('w1-aboutEmpty.dc.html', s)

s = rd('w1-didJoin.dc.html')
s = rep(s, 'Your hold on bed 102-C ended on 30 Sep. One tap helps us keep owners fair.', 'Your hold on bed 102-C ended on 30 Sep. One tap helps us keep owners fair. If you joined, your ₹100 Member reward unlocks once the owner confirms your stay.')
s = rep(s, 'Your answer goes to Hostelzy, never to the owner.', 'Only the Hostelzy team sees your answer, never the owner.')
s = s.replace(btn('Not yet', 'out', None, 44, 14), btn('Not yet', 'out', 'x', 44, 14)).replace(btn('Still deciding', 'out', None, 44, 14), btn('Still deciding', 'out', 'clock', 44, 14))
upd('w1-didJoin.dc.html', s)

s = rd('w1-notifyReady.dc.html')
s = rep(s, 'The owner is drawing this room. You can still pick a bed from Plan or List, and see the photos.', 'The owner hasn’t published this room’s layout yet. You can still pick a bed from Plan or List, and see the photos.')
s = re.sub(r'<button style="margin-top: 6px; width: 100%; height: 48px;.*?</button>', '<div style="margin-top: 6px; width: 100%; padding: 12px; background: var(--sf); display: flex; gap: 10px; align-items: center;">' + ico('bell') + '<b style="font-size: 15px;">We’ll tell you</b></div>', s, count=1, flags=re.S)
s = rep(s, 'One notification when Room 105’s layout is published. Turn it off in Settings › Notifications.', 'You get a notification when the owner publishes room 105’s layout.')
upd('w1-notifyReady.dc.html', s)

s = rd('w1-notifSwitches.dc.html')
s = re.sub(r'<div style="display: grid; grid-template-columns: minmax\(0, 1fr\) auto; gap: 12px; align-items: center; padding: 10px 16px; border-bottom: 1px solid var\(--hl\);"><span style="display: grid; gap: 1px;"><b style="font-size: 16px;">Layout ready</b>.*?</span></span></div>', '', s, count=1, flags=re.S)
assert 'Layout ready' not in s
s = rep(s, '3 days before and on the day', '3 days before')
upd('w1-notifSwitches.dc.html', s)

s = rd('w1-walkInHeld.dc.html')
s = rep(s, btn('Add tenant to this bed', 'ink', 'plus') + btn('Release now', 'out', 'x'), btn('Release hold', 'ink', 'x'))
upd('w1-walkInHeld.dc.html', s)

s = rd('w1-featured.dc.html')
s = rep(s, 'Featured · 96 beds', 'Featured')
s = re.sub(r'<div style="padding: 0 16px 8px; display: flex; justify-content: space-between; gap: 8px;">.*?Why\? ›</a></div>', '', s, count=1, flags=re.S)
s = re.sub(r'<div style="padding: 0 16px 8px; border-top: 2px solid var\(--tx\); padding-top: 12px;">.*?</span></div>', '', s, count=1, flags=re.S)
assert 'Why?' not in s and 'never paid' not in s
upd('w1-featured.dc.html', s)

# console: Fair Play case detail with strikes (replaces the Hostels-with-strikes idea; console Hostels shows no strikes)
s = rd('cCases.dc.html'); s = title(s, 'Team console: Fair Play case, strikes and signals')
line = lambda k, v: '<div style="display: grid; grid-template-columns: 170px minmax(0, 1fr); gap: 12px; padding: 10px 0; border-bottom: 1px solid var(--hl); font-size: 14px;"><span style="color: var(--mu);">%s</span><span>%s</span></div>' % (k, v)
det = ('<main style="min-width: 0; display: grid; grid-template-columns: minmax(0, 1fr) 420px;"><section style="padding: 20px 24px; display: grid; gap: 4px; align-content: start;">' + kick('FP-0006 · Green Nest Co-living · Decide') + '<h1 style="margin: 0 0 10px; font-size: 26px; font-weight: 800;">Hold confirmed, then “bed not available” at the visit</h1>'
       + line('Owner’s reply', '“The bed was given to a walk-in, I forgot to update.” · 1 Oct')
       + line('Photos', 'Owner’s photo · Tenant’s photo &nbsp;<a href="#">Replace tenant’s photo</a>')
       + line('Strikes', '<b>1 strike · warning (4 Aug)</b>')
       + line('Fair Play rules', 'agreed 1 Oct')
       + line('Did you join?', 'Joined 2 · Not yet 1 · Still deciding 0')
       + '<div style="display: flex; gap: 8px; padding-top: 16px;">' + sb('Close · no issue') + sb('Ask for more…') + '<button style="height: 36px; padding: 0 12px; font-weight: 800; font-size: 13px; background: var(--ac); color: var(--ai);">Strike 2 · deals hidden for 30 days</button></div>'
       + '<p style="margin: 8px 0 0; font-size: 13px; color: var(--mu);">Strikes: 1 warning · 2 deals hidden for 30 days · 3 removed from Hostelzy. 3 layout fixes in 6 months count as one warning.</p></section>'
       '<section style="border-left: 2px solid var(--tx); padding: 20px; display: grid; gap: 8px; align-content: start;"><h2 style="margin: 0; font-size: 20px; font-weight: 800;">Signals · Green Nest Co-living</h2>'
       + ''.join('<div style="display: flex; justify-content: space-between; padding: 10px 0; border-bottom: 1px solid var(--hl); font-size: 14px;"><span>%s</span>%s</div>' % (t, tag(n, k)) for t, n, k in [('Hold cancelled, bed taken within 7 days', '2', 'red'), ('Tenant said joined, owner added as walk-in', '1', 'red'), ('“Did you join?” Yes, owner silent 3 days', '0', 'mu'), ('Owner asked to skip the app (tenant report)', '1', 'red'), ('Free bed not confirmed for 7 days', '0', 'mu'), ('Layout fixes in 6 months', '1', 'mu')])
       + '</section></main>')
i = s.index('<main'); j = s.index('</main>') + 7
s = s[:i] + det + s[j:]
upd('w1-cStrikes.dc.html', s)

s = rd('f24-trustedPerks.dc.html')
s = re.sub(r'<div style="display: grid; grid-template-columns: 36px minmax\(0, 1fr\); gap: 12px; align-items: center; padding: 10px 0; border-bottom: 1px solid var\(--hl\);"><span[^>]*><svg[^>]*><path d="M3 7h18v12H3z"/><path d="M16 13h2"/><path d="M5 7l11-3v3"/></svg></span><span style="display: grid; gap: 1px;"><b style="font-size: 15px;">Lower-advance deals</b>.*?</span></span></div>', '', s, count=1, flags=re.S)
assert 'Lower-advance' not in s
s = s.replace('You hear about them 1 hour before everyone else', 'When a bed turns free, you can hold it 1 hour before everyone else')
s = s.replace('You keep it with 6 months in Hostelzy hostels, rent paid on time and no complaints from owners.', 'You keep it with 6 months in Hostelzy hostels and rent paid on time.')
upd('f24-trustedPerks.dc.html', s)

for f in ['r-filters.dc.html', 'f23-Filters.dc.html']:
    s = rd(f)
    nb = '<button style="padding: 10px 4px; font-size: 13px; font-weight: 600; text-align: center; background: transparent; color: var(--tx);">'
    s = rep(s, nb + 'Nearest</button>' + nb + 'Lowest price</button>', nb + 'Nearest</button>' + nb + 'Best deals</button>' + nb + 'Lowest price</button>')
    s = s.replace('grid-template-columns: repeat(3, minmax(0, 1fr)); margin: 0; border: 2px solid var(--tx);"><button style="padding: 10px 4px; font-size: 13px; font-weight: 600; text-align: center; background: var(--tx); color: var(--bg);">Recommended', 'grid-template-columns: repeat(4, minmax(0, 1fr)); margin: 0; border: 2px solid var(--tx);"><button style="padding: 10px 4px; font-size: 13px; font-weight: 600; text-align: center; background: var(--tx); color: var(--bg);">Recommended')
    upd(f, s)

for f in ['r-detail.dc.html', 'r-detailDark.dc.html']:
    s = rd(f)
    s = rep(s, 'Same price for every bed of a type. Food included. Electricity extra, by meter.</div>', 'Same price for every bed of a type. Food included. Electricity extra, by meter.<br><b style="color: var(--tx);">Confirmed by the owner</b> · 3 Oct</div>')
    upd(f, s)

s = rd('gateOwn.dc.html')
a = '<button style="width: 100%; height: 54px; padding: 0 16px; display: flex; justify-content: space-between; align-items: center; gap: 10px; font-weight: 800; font-size: 15px; text-decoration: none; background: var(--ac); color: var(--ai);">Request a visit'
s = rep(s, a, '<button style="width: 100%; padding: 12px; background: var(--sf); display: grid; grid-template-columns: minmax(0, 1fr) 16px; gap: 10px; align-items: center; text-align: left;"><span style="display: grid; gap: 2px;"><b style="font-size: 15px;">Manager at a PG?</b><span style="font-size: 13px; color: var(--mu);">Join it with the MGR- code your owner sent you.</span></span>' + ico('chev', 16) + '</button>' + a)
upd('gateOwn.dc.html', s)

s = rd('add-addR.dc.html')
s = rep(s, '<b style="font-size: 13px;">Joined on</b>', '<div style="display: flex; gap: 10px; align-items: center; font-size: 14px; font-weight: 600;"><span style="width: 20px; height: 20px; border: 2px solid var(--tx);"></span>Lived here before Hostelzy</div><b style="font-size: 13px;">Joined on</b>')
upd('add-addR.dc.html', s)

s = rd('review.dc.html')
segb = lambda t, on: '<button style="padding: 10px 4px; font-size: 13px; font-weight: 600; text-align: center; background: %s; color: %s;">%s</button>' % ('var(--tx)' if on else 'transparent', 'var(--bg)' if on else 'var(--tx)', t)
s = rep(s, '<div style="padding: 14px 16px; display: grid; gap: 8px;"><b style="font-size: 13px;">Anything others should know? (optional)</b>',
        '<div style="padding: 14px 16px 0; display: grid; gap: 8px;"><b style="font-size: 13px;">Is the room layout right?</b><div style="display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); border: 2px solid var(--tx);">' + segb('Yes', True) + segb('Mostly', False) + segb('No', False) + '</div></div><div style="padding: 14px 16px; display: grid; gap: 8px;"><b style="font-size: 13px;">Anything others should know? (optional)</b>')
upd('review.dc.html', s)

s = rd('menu.dc.html')
k = 'Residents and tenants see it after you tap Save.'
n = s.count(k)
box = ('<div style="padding: 12px; border: 2px solid var(--tx); display: grid; gap: 8px;">' + kick('Meal times') + mut('Not set. Residents’ meal reminders use the usual times: breakfast 7:30, lunch 12:30, dinner 8:00.', 13) + btn('Set meal times', 'out', 'clock', 46, 14) + '</div>')
i = s.index(k); i = s.rindex('<', 0, i)
s = s[:i] + box + s[i:]
upd('menu.dc.html', s)

# console nav: add Rewards and Reported reviews everywhere, in the console's order
for f in sorted(os.listdir(P)):
    if not f.endswith('.dc.html'): continue
    s = rd(f)
    if '>Layout fixes</a>' not in s: continue
    m = re.search(r'<a href="#" style="([^"]*)color: var\(--mu\);">Layout help</a>', s) or re.search(r'<a href="#" style="([^"]*)color: var\(--mu\);">Onboarding</a>', s)
    inactive = '<a href="#" style="%scolor: var(--mu);">%%s</a>' % m.group(1)
    if '>Rewards</a>' not in s:
        s = re.sub(r'(<a href="#" style="[^"]*">Layout help</a>)', lambda mm: mm.group(1) + inactive % 'Rewards', s, count=1)
    if '>Reported reviews</a>' not in s:
        act = f.startswith('w2-cReported')
        a2 = inactive % 'Reported reviews'
        if act:
            a2 = a2.replace('color: var(--mu);">', 'color: var(--tx); background: var(--sf); box-shadow: inset 4px 0 0 var(--ac);">')
        s = re.sub(r'(<a href="#" style="[^"]*">Layout fixes</a>)', lambda mm: mm.group(1) + a2, s, count=1)
    if f == 'w2-cReported.dc.html':
        s = s.replace('color: var(--tx); background: var(--sf); box-shadow: inset 4px 0 0 var(--ac);">Hostels</a>', 'color: var(--mu);">Hostels</a>')
    open(P + f, 'w').write(s)
    if f not in OUT and f not in UPD: UPD.append(f)
print('NEW', OUT); print('UPD', UPD)
