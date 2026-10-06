import re
src = open('/tmp/claude-0/-home-user-hostelzy/58cdc0a8-c7d4-5e26-828b-40f705b32de2/scratchpad/w4.py').read()
exec(src[:src.index('# ---------- NEW-1')])
UPD = []
# --- Owner Beds: Rooms · Building toggle (variant of S37), reuses the Building view
b = rd('w4-building.dc.html')
blk = b[b.index('<div style="border: 2px solid var(--tx); border-top-width: 6px;">'):]
blk = blk[:blk.index(legend)]
s = rd('beds.dc.html'); s = title(s, 'Beds: Rooms · Building toggle (owner)')
a = '<div style="display: flex; gap: 6px; padding: 0 16px 10px; overflow: hidden;">'
i = s.index(a); j = s.index('<nav', i)
seg = '<div style="display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); margin: 0 16px 10px; border: 2px solid var(--tx);"><button style="padding: 10px 4px; font-size: 13px; font-weight: 600; text-align: center;">Rooms</button><button style="padding: 10px 4px; font-size: 13px; font-weight: 600; text-align: center; background: var(--tx); color: var(--bg);">Building</button></div>'
own_legend = legend.replace('Your pick', 'Selected')
s = s[:i] + seg + '<div style="flex-grow: 1; overflow: hidden; padding: 0 16px; display: grid; gap: 10px; align-content: start;">' + blk + own_legend + mut('Same Building view tenants see. Tap a bed to open its bed sheet; tap a floor for its shared things.', 12) + '</div>' + s[j:]
wr('w4-oBedsBuilding.dc.html', s)

# --- Your plan: All plans + Past invoices (variant of S65)
s = rd('r-today.dc.html'); s = title(s, 'Your plan: all plans and past invoices')
i = root_inner(s); j = s.index('<nav', i)
def tier(name, price, note, mine=False):
    st = 'border: 2px solid var(--ac); background: var(--ab);' if mine else 'border: 1px solid var(--dv);'
    return '<div style="padding: 10px; display: grid; gap: 2px; %s"><span style="display: flex; justify-content: space-between; align-items: baseline;"><b style="font-size: 15px;">%s</b><b style="font-size: 16px;">%s<span style="font-size: 12px; font-weight: 600; color: var(--mu);">/mo</span></b></span><span style="font-size: 12px; color: var(--mu);">%s</span></div>' % (st, name + (' · your plan' if mine else ''), price, note)
def inv(code, month, amt, st):
    return '<div style="display: grid; grid-template-columns: minmax(0, 1fr) auto; gap: 8px; padding: 10px 0; border-bottom: 1px solid var(--hl); font-size: 14px;"><span style="display: grid;"><b>%s</b><span style="font-size: 12px; color: var(--mu);">%s</span></span><span style="text-align: right; display: grid;"><b>%s</b><span style="font-size: 12px; color: var(--mu);">%s</span></span></div>' % (month, code, amt, st)
body = (head('Anjani Residency · Manage', 'Your plan') + '<div style="flex-grow: 1; overflow: hidden; border-top: 2px solid var(--tx); padding: 14px 16px; display: grid; gap: 10px; align-content: start;">'
        '<div style="padding: 12px; border: 2px solid var(--tx); display: grid; gap: 2px;">' + kick('October invoice') + '<b style="font-size: 28px;">₹999 · Paid</b><span style="font-size: 13px; color: var(--mu);">Paid on 3 Oct. Next invoice 2 Nov.</span></div>'
        + kick('All plans · no commission') + tier('Up to 30 beds', '₹499', 'Everything below') + tier('31 to 80 beds', '₹999', 'You have 40 beds', True) + tier('80+ beds', '₹1,499', 'Plus a featured spot in your area')
        + '<div style="padding-top: 6px;">' + kick('Past invoices') + '</div><div>' + inv('HZ-INV-1024', 'October 2026', '₹999', 'Paid 3 Oct') + inv('—', 'September 2026', '₹0', 'Free trial') + '</div>'
        + mut('The plan changes with your bed count. Tap an invoice to share its receipt.', 12) + '</div>')
nav = NAVS['owner'].replace('color: var(--tx); box-shadow: inset 0 3px 0 var(--ac);">', 'color: var(--mu);">', 1)
nav = nav.replace('font-weight: 600; color: var(--mu);"><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="square" style="flex: none;"><path d="M3 13h5', 'font-weight: 600; color: var(--tx); box-shadow: inset 0 3px 0 var(--ac);"><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="square" style="flex: none;"><path d="M3 13h5', 1)
s = s[:i] + body + s[j:]
s = s[:s.index('<nav')] + nav + s[s.index('</nav>') + 6:]
wr('w4-planMore.dc.html', s)

# --- Owner Today: This month card gets N% full + bar
for f in ['r-today.dc.html', 'r-todayDark.dc.html']:
    s = rd(f)
    s = rep(s, '>This month</span></div>', '>This month</span><b style="font-size: 13px;">83% full</b></div>')
    k = '<span style="font-size: 12px; color: var(--mu);">rent pending</span></span></div>'
    s = rep(s, k, k + '<div role="img" aria-label="83% of beds taken" style="margin: 8px 16px 0; height: 8px; border: 1px solid var(--tx); background: var(--sf);"><div style="width: 83%; height: 100%; background: var(--tx);"></div></div>')
    open(P + f, 'w').write(s); UPD.append(f)
print(OUT, UPD)
