import json, re, os
SP = '/tmp/claude-0/-home-user-hostelzy/58cdc0a8-c7d4-5e26-828b-40f705b32de2/scratchpad/'
exec(open(SP + 'f26.py').read())
I['plate'] = '<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5"/>'
def single(tt, pdiv, dark=False):
    s = rd('holds.dc.html'); s = title(s, tt)
    s = s.replace('[data-hz] *{box-sizing:border-box}', VF + '[data-hz] *{box-sizing:border-box}', 1)
    i = s.index('<div data-hz'); j = s.rindex('</div>\n</x-dc>') + 6
    s = s[:i] + pdiv + s[j:]
    if dark:
        s = s.replace('{"dark": {"editor": "boolean", "default": false}', '{"dark": {"editor": "boolean", "default": true}').replace('(this.props.dark ?? false)', '(this.props.dark ?? true)')
    return s
GREENCHIP = lambda t: '<span style="justify-self: start; display: inline-flex; gap: 6px; align-items: center; padding: 4px 8px; background: var(--gb); color: var(--gn); font-size: 12px; font-weight: 800;">' + ico('plate', 14) + t + '</span>'
def bigbtn(t, on):
    st = 'background: var(--tx); color: var(--bg); border: 2px solid var(--tx);' if on else 'border: 2px solid var(--tx); color: var(--tx);'
    return '<button style="height: 56px; display: flex; justify-content: center; align-items: center; gap: 8px; font-size: 17px; font-weight: 800; %s">%s</button>' % (st, t)
F = {}
# F27-1 Home next meal card
card = ('<div style="margin: 14px 16px 0; padding: 14px; border: 2px solid var(--tx); display: grid; gap: 10px;">'
        '<div style="display: flex; justify-content: space-between; align-items: baseline;">' + kick('Next meal') + '<a href="#" style="font-size: 13px; font-weight: 800;">Plan the week ›</a></div>'
        '<span style="display: grid; gap: 2px;"><b style="font-size: 22px;">Dinner · 8:00 pm</b><span style="font-size: 14px; color: var(--mu);">Chapati, dal</span></span>'
        '<div style="display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 8px;">' + bigbtn('Eating' + ico('check', 18), True) + bigbtn('Skip', False) + '</div>'
        '<span style="font-size: 13px; color: var(--mu);">Closes at 5:00 pm · 31 eating so far</span>' + GREENCHIP('You saved 3 plates this week') + '</div>')
_ha = home2.index('<div style="padding: 20px 16px 6px; display: flex; justify-content: space-between; align-items: baseline; gap: 12px;">')
home27 = home2[:_ha] + card + home2[_ha:]
F['f27-1-home.dc.html'] = ('[F27-1] Resident Home · Next meal card: Eating / Skip', phone_div(home27), False)
F['f27-1-homeDark.dc.html'] = ('[F27-1] Resident Home · Next meal card [dark]', phone_div(home27), True)
# F27-2 Week plan
def cell(on):
    if on:
        return '<button aria-label="Eating" style="height: 40px; display: grid; place-items: center; background: var(--tx); color: var(--bg);">' + ico('check', 16) + '</button>'
    return '<button aria-label="Skip" style="height: 40px; display: grid; place-items: center; border: 2px dashed var(--dv); color: var(--mu); font-size: 12px; font-weight: 800;">Skip</button>'
days = [('Fri · today', 'yyy'), ('Sat', 'nnn'), ('Sun', 'nnn'), ('Mon', 'yyy'), ('Tue', 'yyn'), ('Wed', 'yyy'), ('Thu', 'yny')]
grid = '<div style="display: grid; grid-template-columns: 76px repeat(3, minmax(0, 1fr)); gap: 6px; align-items: center;"><span></span>' + ''.join('<span style="font-size: 11px; font-weight: 800; letter-spacing: .08em; text-transform: uppercase; color: var(--mu);">%s</span>' % m for m in ['Breakfast', 'Lunch', 'Dinner'])
for d, p in days:
    grid += '<b style="font-size: 14px;">%s</b>' % d + ''.join(cell(c == 'y') for c in p)
grid += '</div>'
wk = (head('Anjani Residency · Food', 'Plan your meals') + '<div style="flex-grow: 1; overflow: hidden; border-top: 2px solid var(--tx); padding: 14px 16px; display: grid; gap: 12px; align-content: start;">'
      + mut('Tap a meal to switch between eating and skip. Everything is “eating” unless you skip.', 13) + grid
      + btn('Skip all weekend', 'out', None, 48, 15) + note('Each meal closes 3 h before it is served. A skip after that counts from the next meal.').replace('margin: 0 16px;', 'margin: 0;')
      + GREENCHIP('This week you’re saving 8 plates') + '</div>')
F['f27-2-week.dc.html'] = ('[F27-2] Week plan · 7 days × breakfast, lunch, dinner', ph(wk, nav_res('Home')), False)
# F27-3 Owner Today headcount
hc = ('<div style="margin: 0 16px 10px; padding: 12px; border: 2px solid var(--tx); display: grid; gap: 8px;"><div style="display: flex; justify-content: space-between; align-items: baseline;">' + kick('Dinner tonight') + '<span style="font-size: 12px; color: var(--mu);">Closes 5:00 pm</span></div>'
      '<div style="display: flex; justify-content: space-between; align-items: baseline;"><b style="font-size: 26px;">34 of 40 eating</b>' + ico('chev', 18) + '</div>'
      '<div role="img" aria-label="34 of 40 eating" style="height: 10px; border: 1px solid var(--tx); background: var(--sf);"><div style="width: 85%; height: 100%; background: var(--tx);"></div></div>'
      '<span style="font-size: 13px; color: var(--mu);">6 skipping · cook for 34</span></div>')
k = grp.index('<div style="padding: 0 16px 6px; display: flex; justify-content: space-between; align-items: baseline;">' + kick('Needs you · most urgent first'))
grp27 = grp[:k] + hc + grp[k:]
F['f27-3-today.dc.html'] = ('[F27-3] Owner Today · Headcount card', ph(grp27, NAV_O), False)
# F27-4 Owner Meals
def mrow(m, n, st, open_=False):
    return ('<div style="display: grid; grid-template-columns: minmax(0, 1fr) auto; gap: 8px; align-items: center; padding: 10px 0; border-bottom: 1px solid var(--hl);"><span style="display: grid;"><b style="font-size: 15px;">%s</b><span style="font-size: 12px; color: %s;">%s</span></span><b style="font-size: 18px;">%s</b></div>') % (m, 'var(--ad)' if open_ else 'var(--mu)', st, n)
th = 'padding: 5px 4px; font-size: 10px; font-weight: 800; letter-spacing: .06em; text-transform: uppercase; color: var(--mu); text-align: left; border-bottom: 2px solid var(--tx);'
td = 'padding: 5px 4px; font-size: 12px; border-bottom: 1px solid var(--hl);'
counts = [('Fri', 38, 29, 34), ('Sat', 30, 24, 26), ('Sun', 27, 22, 25), ('Mon', 38, 33, 35), ('Tue', 39, 30, 36), ('Wed', 37, 31, 34), ('Thu', 38, 28, 33)]
tbl = '<table style="width: 100%; border-collapse: collapse;"><thead><tr>' + ''.join('<th style="%s">%s</th>' % (th, h) for h in ['', 'Breakfast', 'Lunch', 'Dinner']) + '</tr></thead><tbody>' + ''.join('<tr><td style="%s font-weight: 800;">%s</td><td style="%s">%d</td><td style="%s">%d</td><td style="%s">%d</td></tr>' % (td, d, td, b, td, l, td, n) for d, b, l, n in counts) + '</tbody></table>'
meals = (head('Anjani Residency · Manage', 'Meals') + '<div style="flex-grow: 1; overflow: hidden; border-top: 2px solid var(--tx); padding: 12px 16px; display: grid; gap: 10px; align-content: start;">'
         + '<div style="padding: 10px 12px; background: var(--gb); color: var(--gn); display: flex; justify-content: space-between; align-items: baseline;"><b style="font-size: 14px;">Plates saved this month</b><b style="font-size: 24px;">412</b></div>'
         + '<div>' + kick('Today · of 40 residents') + mrow('Breakfast', '38', 'Closed 4:30 am') + mrow('Lunch', '29', 'Closed 9:30 am') + mrow('Dinner', '34', 'Open · closes 5:00 pm', True) + '</div>'
         + '<div style="display: grid; gap: 4px;">' + kick('Who’s skipping dinner · 6') + '<span style="font-size: 13px; line-height: 1.5;">Rahul V. 204-B · Arjun R. 204-A · Sai K. 204-C · Pranav S. 203-A · Faiz M. 101-A · Teja N. 102-B</span></div>'
         + '<div>' + kick('Next 7 days · eating') + tbl + '</div>'
         + '<div style="display: grid; gap: 6px;">' + kick('Count closes before each meal') + seg(['2 h', '3 h', '4 h'], '3 h') + '</div></div>')
F['f27-4-meals.dc.html'] = ('[F27-4] Owner · Meals: counts, who’s skipping, 7 days, cut-off', ph(meals, navsel(NAV_O, 'Manage')), False)
# F27-5 push
push = ('<div style="flex-grow: 1; padding: 48px 16px 0; display: grid; gap: 14px; align-content: start; background: var(--sf);">'
        '<div style="display: grid; justify-items: center; gap: 2px;"><b style="font-size: 64px; line-height: 1; letter-spacing: -.03em;">4:00</b><span style="font-size: 15px; color: var(--mu);">Friday, 2 October</span></div>'
        '<div style="margin-top: 24px; background: var(--bg); border: 2px solid var(--tx); padding: 12px; display: grid; gap: 8px;">'
        '<span style="display: flex; justify-content: space-between; font-size: 12px; color: var(--mu);"><b style="letter-spacing: .06em;">HOSTELZY</b><span>now</span></span>'
        '<b style="font-size: 16px;">Dinner at 8 · Eating?</b><span style="font-size: 14px; color: var(--mu); line-height: 1.4;">Chapati, dal. Tap Skip if you won’t be here. Closes at 5:00 pm.</span>'
        '<div style="display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); border-top: 1px solid var(--hl); padding-top: 8px; gap: 8px;"><button style="height: 44px; font-size: 15px; font-weight: 800; text-align: center;">Eating</button><button style="height: 44px; font-size: 15px; font-weight: 800; text-align: center; border-left: 1px solid var(--hl);">Skip</button></div></div>'
        + mut('Sent 1 h before the count closes, only to residents who haven’t answered today.', 12) + '</div>')
F['f27-5-push.dc.html'] = ('[F27-5] Resident push · Dinner at 8 · Eating? with Eating / Skip', ph(push), False)
# F27-6 Plates saved card
ps = (head('Me', 'Plates saved') + '<div style="flex-grow: 1; overflow: hidden; border-top: 2px solid var(--tx); padding: 14px 16px; display: grid; gap: 12px; align-content: start;">'
      + '<div style="padding: 14px; background: var(--gb); color: var(--gn); display: grid; gap: 10px;">' + '<span style="display: grid;"><span style="font-size: 12px; font-weight: 800; letter-spacing: .1em; text-transform: uppercase;">You saved</span><b style="font-size: 44px; line-height: 1;">23 plates</b></span>'
      + '<div style="display: grid; border-top: 1px solid var(--gn);">' + ''.join('<div style="display: flex; justify-content: space-between; padding: 8px 0; border-bottom: 1px solid var(--gn); font-size: 15px;"><span>%s</span><b>%s</b></div>' % x for x in [('Anjani Residency saved', '412'), ('Hostelzy saved', '9,870')]) + '</div></div>'
      + mut('1 skip = 1 plate the kitchen didn’t cook. No ranking of people: nobody is judged for eating.', 13) + '</div>')
F['f27-6-saved.dc.html'] = ('[F27-6] Plates saved · you, your hostel, Hostelzy', ph(ps, nav_res('Me')), False)
# F27-7 hostel page chip
fd = food_new()
fd = fd.replace('<div style="padding: 0 10px;">', '<div style="padding: 0 16px 8px;">' + GREENCHIP('Cooks to count · 412 plates saved') + '</div><div style="padding: 0 10px;">', 1)
hp = ph(page_head('Scrolled to food') + scrollpage(fd + rules_row() + '<div style="padding: 16px 16px 0;">' + avail() + '</div>' + contact_locked()) + topbar_from())
F['f27-7-hostel.dc.html'] = ('[F27-7] Hostel page · “Cooks to count · 412 plates saved”', hp, False)
for name, (tt, pdiv, dark) in F.items():
    open(Q + name, 'w').write(single(tt, pdiv, dark))
json.dump(list(F.keys()), open(SP + 'f27files.json', 'w'))
print(list(F.keys()))
