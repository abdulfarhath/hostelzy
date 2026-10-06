import json, re
SP = '/tmp/claude-0/-home-user-hostelzy/58cdc0a8-c7d4-5e26-828b-40f705b32de2/scratchpad/'
exec(open(SP + 'f27.py').read())
O = SP + 'v23/project/'
c = json.load(open(SP + 'remote4/project/canvas.json')); B = c['boards']
def w(name, tt, pdiv, dark=False):
    open(O + name, 'w').write(single(tt, pdiv, dark))
N = ' · New (F27)'; U27 = ' · Updated (F27)'
# updates in place
w('r-home.dc.html', '[S23] rHome · Next meal card: Eating / Skip, plates saved; week table below' + U27, phone_div(home27)); B['r-home.dc.html']['title'] = '[S23] rHome · Next meal card: Eating / Skip, plates saved; week table below' + U27
w('f26-homeDark.dc.html', '[dark] rHome · Home with the next meal card (dark)' + U27, phone_div(home27), True); B['f26-homeDark.dc.html']['title'] = '[dark] rHome · Home with the next meal card (dark)' + U27
w('r-today.dc.html', '[S36] oToday · Dinner tonight headcount card, then Holds · Payments · Fixes' + U27, ph(grp27, NAV_O)); B['r-today.dc.html']['title'] = '[S36] oToday · Dinner tonight headcount card, then Holds · Payments · Fixes' + U27
w('r-todayDark.dc.html', '[dark] oToday · Today with the headcount card (dark)' + U27, ph(grp27, NAV_O), True); B['r-todayDark.dc.html']['title'] = '[dark] oToday · Today with the headcount card (dark)' + U27
# new boards
new = [
 ('f27-week.dc.html', '[S90] mealPlan · Week plan: 7 days × breakfast, lunch, dinner, Skip all weekend' + N, ph(wk, nav_res('Home'))),
 ('f27-meals.dc.html', '[S91] oMeals · Meals: counts, who’s skipping, 7 days, cut-off, plates saved' + N, ph(meals, navsel(NAV_O, 'Manage'))),
 ('f27-saved.dc.html', '[variant of S22] rewards · Plates saved: you, your hostel, Hostelzy' + N, ph(ps, nav_res('Me'))),
 ('f27-hostelChip.dc.html', '[variant of S13] detail · “Cooks to count · 412 plates saved” under the food table' + N, hp),
 ('f27-push.dc.html', '[not counted · system notification] Dinner at 8 · Eating? with Eating / Skip' + N, ph(push)),
]
bottom_main = max(v['y'] + v['h'] for k, v in B.items() if v['y'] < c['notes']['arch0']['y'] - 400) if 'arch0' in c['notes'] else None
# place the row after the lowest non-archive board
mains = [v for v in B.values() if 'archive' not in v.get('title', '')]
y = max(v['y'] + v['h'] for v in mains) + 420
c['notes']['r27'] = {'kind': 'title1', 'maxW': len(new) * 470, 'text': 'F27 · Save food (founder approved 6 Oct) · S90, S91 + cards', 'w': 240, 'x': 0, 'y': y - 300}
x = 0
for name, tt, pdiv in new:
    w(name, tt, pdiv)
    B[name] = {'x': x, 'y': y, 'w': 390, 'h': 844, 'title': tt}; c['order'].append(name); x += 470
# overlap check with existing boards
for name, *_ in new:
    b = B[name]
    for k, v in B.items():
        if k == name: continue
        if not (b['x'] + b['w'] <= v['x'] or v['x'] + v['w'] <= b['x'] or b['y'] + b['h'] <= v['y'] or v['y'] + v['h'] <= b['y']):
            print('OVERLAP', name, k)
json.dump(c, open(O + 'canvas.json', 'w'), ensure_ascii=False, indent=1)
cnt = {'main': 0, 'variant': 0, 'dark': 0, 'not': 0, 'arch': 0}
for v in B.values():
    t = v.get('title', '')
    if 'archive' in t: cnt['arch'] += 1
    elif t.startswith('[variant'): cnt['variant'] += 1
    elif t.startswith('[dark]'): cnt['dark'] += 1
    elif t.startswith('[not counted'): cnt['not'] += 1
    else: cnt['main'] += 1
print(len(B), cnt, y)
