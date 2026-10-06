import re
src = open('/tmp/claude-0/-home-user-hostelzy/58cdc0a8-c7d4-5e26-828b-40f705b32de2/scratchpad/w3.py').read()
exec(src[:src.index('# --- Screen: oRules')])
# bed squares
BED = {
 'free': 'background: var(--bg); border: 2px solid var(--tx); color: var(--tx);',
 'taken': 'background: var(--tk); border: 2px solid var(--dv); color: var(--mu);',
 'hold': 'background: repeating-linear-gradient(135deg, var(--sf) 0 4px, var(--bg) 4px 8px); border: 2px solid var(--dv); color: var(--mu);',
 'sel': 'background: var(--ac); border: 2px solid var(--ac); color: var(--ai);',
 'soon': 'background: var(--bg); border: 2px dashed var(--tx); color: var(--tx);',
}
def bed(st, label='', size=22, fs=10):
    return '<span aria-label="Bed, %s" style="width: %dpx; height: %dpx; display: grid; place-items: center; font-size: %dpx; font-weight: 800; %s">%s</span>' % (st, size, size, fs, BED[st], label)
def thing(name, bad=False, small=False):
    st = 'background: var(--ab); color: var(--ad); border: 1px solid var(--ac);' if bad else 'background: var(--bg); color: var(--tx); border: 1px solid var(--tx);'
    return '<span style="padding: 2px 5px; font-size: %dpx; font-weight: 800; letter-spacing: .04em; text-transform: uppercase; white-space: nowrap; %s">%s</span>' % (10 if small else 11, st, name + (' · not working' if bad else ''))
legend = ('<div style="display: flex; gap: 12px; flex-wrap: wrap; font-size: 12px; color: var(--mu);">'
          + ''.join('<span style="display: flex; gap: 5px; align-items: center;">%s%s</span>' % (bed(k, '', 12), t) for k, t in [('free', 'Free'), ('hold', 'On hold'), ('taken', 'Taken'), ('sel', 'Your pick')]) + '</div>')
pk = rd('picker.dc.html')
SEG2 = '<div style="display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); margin: 0 16px; border: 2px solid var(--tx);"><button style="padding: 10px 4px; font-size: 13px; font-weight: 600; text-align: center; background: var(--tx); color: var(--bg);">Plan</button><button style="padding: 10px 4px; font-size: 13px; font-weight: 600; text-align: center; background: transparent; color: var(--tx);">Room</button></div>'
def seg3(active):
    return '<div style="display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); margin: 0 16px; border: 2px solid var(--tx);">' + ''.join('<button style="padding: 10px 4px; font-size: 13px; font-weight: 600; text-align: center; %s">%s</button>' % ('background: var(--tx); color: var(--bg);' if n == active else 'background: transparent; color: var(--tx);', n) for n in ['Plan', 'Room', 'Building']) + '</div>'
bottom_bar = ('<div style="flex: none; border-top: 2px solid var(--tx); padding: 12px 16px; display: grid; grid-template-columns: minmax(0, 1fr) auto; gap: 12px; align-items: center;"><span style="display: grid;"><b style="font-size: 17px;">Bed 204-D · ₹5,800/mo</b><span style="font-size: 12px; color: var(--mu);">Floor 2 · window side · near the washer</span></span><button style="height: 50px; padding: 0 16px; display: flex; gap: 10px; align-items: center; font-weight: 800; font-size: 15px; background: var(--ac); color: var(--ai);">Continue' + ico('arrow') + '</button></div>')
def picker(tt, active, content):
    s = title(pk, tt)
    s = rep(s, SEG2, seg3(active))
    a = '<div style="display: flex; gap: 6px; padding: 12px 16px 6px; overflow: hidden;">'
    i = s.index(a); j = s.rindex('</div>\n</x-dc>')
    return s[:i] + content + bottom_bar + s[j:]

# ---------- NEW-1 Building view
def room_box(n, beds):
    return '<div style="border: 2px solid var(--tx); background: var(--bg); padding: 4px 5px; display: grid; gap: 4px;"><b style="font-size: 11px;">%s</b><span style="display: flex; gap: 3px;">%s</span></div>' % (n, ''.join(bed(b, '', 14) for b in beds))
floors = [
    ('3', '1 free', [('301', ['taken', 'taken', 'free']), ('302', ['taken', 'taken']), ('303', ['taken', 'taken', 'taken'])], ['RO', 'Iron'], []),
    ('2', '4 free', [('201', ['taken', 'free', 'taken']), ('202', ['free', 'hold']), ('203', ['taken', 'free', 'taken']), ('204', ['taken', 'taken', 'taken', 'sel'])], ['Fridge', 'RO'], ['Washer']),
    ('1', '3 free', [('101', ['taken', 'taken', 'free', 'taken']), ('102', ['taken', 'taken', 'free']), ('105', ['free', 'taken'])], ['Fridge', 'RO', 'Washer'], []),
]
rows = ''
for n, free, rooms, ok, bad in floors:
    rows += ('<div style="display: grid; grid-template-columns: 44px minmax(0, 1fr); border-bottom: 2px solid var(--tx);">'
             '<div style="border-right: 2px solid var(--tx); display: grid; place-items: center; align-content: center; gap: 2px; padding: 6px 0;"><b style="font-size: 22px; line-height: 1;">%s</b><span style="font-size: 10px; color: var(--mu); text-align: center;">%s</span></div>'
             '<div style="padding: 8px; display: grid; gap: 6px; background: var(--sf);"><div style="display: flex; gap: 4px; flex-wrap: wrap;">%s</div><div style="display: flex; gap: 6px; flex-wrap: wrap;">%s</div></div></div>') % (n, free, ''.join(thing(t, small=True) for t in ok) + ''.join(thing(t, True, True) for t in bad), ''.join(room_box(r, b) for r, b in rooms))
rows += '<div style="display: grid; grid-template-columns: 44px minmax(0, 1fr);"><div style="border-right: 2px solid var(--tx); display: grid; place-items: center; padding: 8px 0;"><b style="font-size: 22px;">G</b></div><div style="padding: 10px 8px; font-size: 13px; color: var(--mu);">Reception · dining hall · bike parking · no beds</div></div>'
content = ('<div style="flex-grow: 1; overflow: hidden; padding: 12px 16px 8px; display: grid; gap: 10px; align-content: start;">'
           '<div style="display: flex; justify-content: space-between; align-items: baseline;">' + kick('Whole building · tap a free bed') + '<span style="font-size: 12px; color: var(--mu);">8 free</span></div>'
           '<div style="border: 2px solid var(--tx); border-top-width: 6px;">' + rows + '</div>'
           + legend + mut('Shared things sit on top of each floor; red = not working. Tap a floor for its shared things and their status.', 12) + '</div>')
wr('w4-building.dc.html', picker('Pick a bed: the whole building', 'Building', content))

# ---------- NEW-2 Floor map with shared things (tenant)
def mroom(n, sub, beds, h=104):
    return ('<div style="border: 2px solid var(--tx); background: var(--bg); padding: 6px; display: grid; gap: 6px; align-content: start; min-height: %dpx;"><span style="display: flex; justify-content: space-between; font-size: 12px;"><b>%s</b><span style="color: var(--mu);">%s</span></span>'
            '<span style="display: flex; gap: 4px; flex-wrap: wrap;">%s</span></div>') % (h, n, sub, ''.join(bed(st, l, 26, 11) for st, l in beds))
fm = ('<div style="border: 2px solid var(--tx); display: grid; gap: 0;">'
      '<div style="display: flex; justify-content: space-between; padding: 4px 8px; font-size: 10px; font-weight: 800; letter-spacing: .1em; text-transform: uppercase; color: var(--mu); border-bottom: 1px solid var(--hl);"><span>Windows · street</span><span>Floor 2</span></div>'
      '<div style="display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 6px; padding: 6px;">' + mroom('201', '3 · AC', [('taken', 'A'), ('free', 'B'), ('taken', 'C')]) + mroom('202', '2', [('free', 'A'), ('hold', 'B')]) + '</div>'
      '<div style="position: relative; height: 92px; margin: 0 6px; border-top: 2px dashed var(--dv); border-bottom: 2px dashed var(--dv); background: var(--sf);">'
      '<span style="position: absolute; left: 6px; top: 6px; font-size: 10px; font-weight: 800; letter-spacing: .1em; text-transform: uppercase; color: var(--mu);">← Stairs · Corridor</span>'
      '<span style="position: absolute; left: 6px; bottom: 8px;">' + thing('Fridge') + '</span>'
      '<span style="position: absolute; left: 96px; bottom: 8px;">' + thing('RO water') + '</span>'
      '<span style="position: absolute; right: 70px; top: 26px;">' + thing('Washer', True) + '</span>'
      '<span style="position: absolute; right: 6px; top: 6px; bottom: 6px; width: 56px; border: 2px solid var(--tx); background: var(--bg); display: grid; place-items: center; font-size: 11px; font-weight: 800;">WC</span></div>'
      '<div style="display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 6px; padding: 6px;">' + mroom('203', '3 · AC', [('taken', 'A'), ('free', 'B'), ('taken', 'C')], 96) + mroom('204', '4', [('taken', 'A'), ('taken', 'B'), ('taken', 'C'), ('sel', 'D')], 96) + mroom('205', '2', [('taken', 'A'), ('taken', 'B')], 96) + '</div>'
      '<div style="padding: 4px 8px; font-size: 11px; color: var(--mu); border-top: 1px solid var(--hl);">Geyser in the room washroom of 201, 202, 204, 205</div></div>')
chips = ('<div style="display: flex; gap: 6px; padding: 12px 16px 6px; overflow: hidden;">' + ''.join('<button style="height: 40px; padding: 0 12px; font-size: 14px; font-weight: 800; %s">%s</button>' % ('border: 2px solid var(--tx); background: var(--tx); color: var(--bg);' if f == 'Floor 2 · 4 free' else 'border: 1px solid var(--dv); background: transparent; color: var(--tx);', f) for f in ['Floor 1 · 3 free', 'Floor 2 · 4 free', 'Floor 3 · 1 free']) + '</div>')
content = (chips + '<div style="flex-grow: 1; overflow: hidden; padding: 6px 16px 8px; display: grid; gap: 8px; align-content: start;">' + fm + legend
           + mut('Fridge, RO and washer are drawn where they really are. Tap one to see if it’s working. Residents keep this right.', 12) + '</div>')
wr('w4-floorMap.dc.html', picker('Pick a bed: floor map with shared things', 'Plan', content))

# ---------- NEW-3 Owner floor plan (Beds › Floor plan)
s = rd('beds.dc.html'); s = title(s, 'Beds: floor plan with residents and shared things')
a = '<div style="display: flex; gap: 6px; padding: 0 16px 10px; overflow: hidden;">'
i = s.index(a); j = s.index('<nav', i)
def oroom(n, sub, beds, foot, h=118):
    cells = ''.join('<span style="min-height: 44px; padding: 4px; display: flex; flex-direction: column; justify-content: space-between; font-size: 10px; font-weight: 800; %s"><span>%s</span><span style="font-size: 11px;">%s</span></span>' % (BED[st], l, who) for st, l, who in beds)
    return ('<div style="border: 2px solid var(--tx); background: var(--bg); padding: 6px; display: grid; gap: 5px; align-content: start; min-height: %dpx;"><span style="display: flex; justify-content: space-between; font-size: 12px;"><b>%s</b><span style="color: var(--mu);">%s</span></span>'
            '<span style="display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 4px;">%s</span><span style="font-size: 10px; color: var(--mu);">%s</span></div>') % (h, n, sub, cells, foot)
segFP = '<div style="display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); margin: 0 16px 10px; border: 2px solid var(--tx);"><button style="padding: 10px 4px; font-size: 13px; font-weight: 600; text-align: center; background: var(--tx); color: var(--bg);">Floor plan</button><button style="padding: 10px 4px; font-size: 13px; font-weight: 600; text-align: center;">All floors</button></div>'
fchips = ('<div style="display: flex; gap: 6px; padding: 0 16px 8px; overflow: hidden;">' + ''.join('<button style="height: 38px; padding: 0 12px; font-size: 13px; font-weight: 800; %s">%s</button>' % ('border: 2px solid var(--tx); background: var(--tx); color: var(--bg);' if f == 'Floor 2 · 3 free' else 'border: 1px solid var(--dv);', f) for f in ['Floor 1 · 2 free', 'Floor 2 · 3 free', 'Floor 3 · 2 free']) + '</div>')
plan = ('<div style="border: 2px solid var(--tx);">'
        '<div style="display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 6px; padding: 6px;">' + oroom('201', '3 · AC', [('taken', 'A', 'SK'), ('free', 'B', 'Free'), ('taken', 'C', 'NG')], 'Rent ₹8,200') + oroom('202', '2', [('free', 'A', 'Free'), ('hold', 'B', 'Hold')], 'Rent ₹9,000') + '</div>'
        '<div style="position: relative; height: 74px; margin: 0 6px; border-top: 2px dashed var(--dv); border-bottom: 2px dashed var(--dv); background: var(--sf);">'
        '<span style="position: absolute; left: 6px; top: 5px; font-size: 10px; font-weight: 800; letter-spacing: .1em; text-transform: uppercase; color: var(--mu);">← Stairs · Corridor</span>'
        '<span style="position: absolute; left: 6px; bottom: 6px;">' + thing('Fridge') + '</span><span style="position: absolute; left: 90px; bottom: 6px;">' + thing('RO') + '</span>'
        '<span style="position: absolute; right: 64px; top: 22px;">' + thing('Washer', True) + '</span>'
        '<span style="position: absolute; right: 6px; top: 6px; bottom: 6px; width: 50px; border: 2px solid var(--tx); background: var(--bg); display: grid; place-items: center; font-size: 11px; font-weight: 800;">WC</span></div>'
        '<div style="display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 6px; padding: 6px;">' + oroom('203', '3 · AC', [('taken', 'A', 'PS'), ('free', 'B', 'Free'), ('taken', 'C', 'TN')], 'Rent ₹8,200') + oroom('204', '4', [('taken', 'A', 'AR'), ('soon', 'B', '31 Oct'), ('taken', 'C', 'SK'), ('taken', 'D', 'MF')], 'Rent ₹6,000') + '</div></div>')
body = (segFP + fchips + '<div style="flex-grow: 1; overflow: hidden; padding: 0 16px; display: grid; gap: 8px; align-content: start;">' + plan
        + '<div style="padding: 8px 10px; background: var(--ab); color: var(--ad); font-size: 13px;"><b>Washer, floor 2: not working.</b> Marked by a resident · 2 h ago. Tap it to mark Fixed.</div>'
        + mut('Initials = who sleeps there. Tap a bed to manage it, or a shared thing to change it.', 12) + '</div>')
s = s[:i] + body + s[j:]
s = s.replace('font-weight: 600; color: var(--mu);"><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="square" style="flex: none;"><path d="M3 19V6', 'font-weight: 600; color: var(--tx); box-shadow: inset 0 3px 0 var(--ac);"><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="square" style="flex: none;"><path d="M3 19V6', 1) if 'box-shadow: inset 0 3px 0 var(--ac);"><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="square" style="flex: none;"><path d="M3 19V6' not in s else s
wr('w4-oFloorPlan.dc.html', s)

# ---------- NEW-4 Owner menu week table
s = rd('r-today.dc.html'); s = title(s, 'Food menu: By day · Week (owner)')
i = root_inner(s); j = s.index('<nav', i)
days = [('Mon', 'Idli, sambar', 'Rice, dal, cabbage fry', 'Chapati, paneer'), ('Tue', 'Poha', 'Rice, rasam, beans', 'Egg curry, rice'), ('Wed', 'Upma', 'Veg biryani, raita', 'Dal, chapati'), ('Thu', 'Puri, aloo', 'Rice, sambar, fry', 'Chicken curry'), ('Fri', 'Dosa, chutney', 'Rice, tomato pappu', 'Fried rice, gobi'), ('Sat', 'Pongal', 'Chicken or paneer', 'Khichdi, curd'), ('Sun', 'Bread omelette', 'Rice, dal, egg', '—')]
c = 'padding: 8px 6px; border-bottom: 1px solid var(--hl); font-size: 12px; vertical-align: top;'
th = 'padding: 6px; font-size: 10px; font-weight: 800; letter-spacing: .08em; text-transform: uppercase; color: var(--mu); text-align: left; border-bottom: 2px solid var(--tx);'
rows = ''.join('<tr style="%s"><td style="%s font-weight: 800;">%s</td><td style="%s">%s</td><td style="%s">%s</td><td style="%s%s">%s</td></tr>' % ('background: var(--ab);' if d == 'Fri' else '', c, d, c, b, c, l, c, ' color: var(--mu);' if dn == '—' else '', dn if dn != '—' else 'Not set') for d, b, l, dn in days)
body = (head('Anjani Residency · Manage', 'Food menu') + '<div style="display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); margin: 0 16px 10px; border: 2px solid var(--tx);"><button style="padding: 10px 4px; font-size: 13px; font-weight: 600; text-align: center;">By day</button><button style="padding: 10px 4px; font-size: 13px; font-weight: 600; text-align: center; background: var(--tx); color: var(--bg);">Week</button></div>'
        '<div style="flex-grow: 1; overflow: hidden; border-top: 2px solid var(--tx); padding: 0 10px;"><table style="width: 100%; border-collapse: collapse; table-layout: fixed;"><thead><tr><th style="' + th + ' width: 44px;"></th><th style="' + th + '">Breakfast</th><th style="' + th + '">Lunch</th><th style="' + th + '">Dinner</th></tr></thead><tbody>' + rows + '</tbody></table>'
        '<div style="padding: 10px 6px; display: grid; gap: 6px;">' + mut('Today is highlighted. Tap a day to edit it. Residents and tenants see the same week.', 12)
        + '<span style="font-size: 12px; color: var(--ad); font-weight: 600;">Sunday dinner is not set. Tenants see “Not set” for it.</span></div></div>')
nav = NAVS['owner'].replace('color: var(--tx); box-shadow: inset 0 3px 0 var(--ac);">', 'color: var(--mu);">', 1)
nav = nav.replace('font-weight: 600; color: var(--mu);"><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="square" style="flex: none;"><path d="M3 13h5', 'font-weight: 600; color: var(--tx); box-shadow: inset 0 3px 0 var(--ac);"><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="square" style="flex: none;"><path d="M3 13h5', 1)
s = s[:i] + body + s[j:]
s = s[:s.index('<nav')] + nav + s[s.index('</nav>') + 6:]
wr('w4-oMenuWeek.dc.html', s)
print(OUT)
