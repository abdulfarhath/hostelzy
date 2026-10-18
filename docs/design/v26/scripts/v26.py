"""v26 assembly (Design, 2026-10-18): v25 live index + F31 parts + the SCREENS gaps (T35, T36, T37, W9 sent).
Run from the repo root after scripts/f31.py. Writes project/canvas.json, the new/retitled boards and publish.json."""
import json, re, os, subprocess
V25 = 'docs/design/v25/project/canvas.json'
MC = 'docs/design/main-canvas/project'
OUT = 'docs/design/v26/project'
d = json.load(open(V25))
p = json.load(open('docs/design/v26/parts/f31.json'))
B = d['boards']
for f, b in p['boards'].items(): B[f]['title'] = b['title']
DROP = ['z-f21-Help.dc.html', 'z-f21-Stay.dc.html']   # archive rows, stay in git (main-canvas/project)
delete = list(p['retire']) + DROP
for f in delete:
    del B[f]
    d['order'].remove(f)

def src(f):
    return open(f'{OUT}/{f}').read() if os.path.exists(f'{OUT}/{f}') else open(f'{MC}/{f}').read()
def retitle(f, t):
    s = re.sub(r'<title>.*?</title>', lambda m: f'<title>{t}</title>', src(f), count=1)
    open(f'{OUT}/{f}', 'w').write(s); B[f]['title'] = t

changed = []
# T36 and the W9 sent state: existing boards, now counted
retitle('f29-joinFormDone.dc.html', '[T36] joinForm · Sent: “<owner> will approve · we’ll notify you” · Updated (v26)')
retitle('f28-wListSent.dc.html', '[W9 · sent] app/list/ · Sent: “We’ll call you within 2 days to confirm” · Updated (v26)')
changed += ['f29-joinFormDone.dc.html', 'f28-wListSent.dc.html']

# New boards, built on the joinFormDone shell (same head, tokens, script)
base = src('f29-joinFormDone.dc.html')
pre, rest = base.split('<div data-hz=', 1)
body, post = rest.rsplit('</x-dc>', 1)
HEAD = ('<div style="flex: none; padding: 12px 16px 12px; display: flex; gap: 12px; align-items: flex-start;"><button aria-label="Back" style="width: 44px; height: 44px; flex: none; display: grid; place-items: center; border: 1px solid var(--dv);"><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="square" style="flex: none;"><path d="m15 18-6-6 6-6"/></svg></button><div style="flex-grow: 1; display: grid; gap: 2px;"><span style="font-size: 11px; font-weight: 600; letter-spacing: .1em; text-transform: uppercase; line-height: 1.3; color: var(--mu);">{k}</span><b style="display: block; font-size: 30px; line-height: 1.02; letter-spacing: -.025em;">{t}</b></div></div>')
ROOT = '<div data-hz="" data-theme="{{theme}}" style="width: 390px; height: 844px; position: relative; background: var(--bg); color: var(--tx); font-family: Archivo, system-ui, sans-serif; display: flex; flex-direction: column; overflow: hidden;">'
assert ROOT in '<div data-hz=' + body
myadd = src('f28-myAdd.dc.html')
NAV = myadd[myadd.index('<nav '):myadd.index('</nav>') + 6]
PLUS = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="square" style="flex: none;"><path d="M12 5v14M5 12h14"/></svg>'
CTA = '<button style="width: 100%; height: 52px; padding: 0 16px; display: flex; justify-content: space-between; align-items: center; gap: 10px; font-weight: 800; font-size: 15px; text-decoration: none; background: var(--ac); color: var(--ai);">{l}' + PLUS + '</button>'
def board(f, title, inner):
    s = re.sub(r'<title>.*?</title>', lambda m: f'<title>{title}</title>', pre, count=1) + ROOT + inner + '</div>\n</x-dc>' + post
    open(f'{OUT}/{f}', 'w').write(s)

# T35 · myAdd empty (Build: kicker "Me", "No hostel added yet", Add a hostel)
board('f28-myAddEmpty.dc.html', '[T35] myAdd · No hostel added yet: Add a hostel · New (v26)',
      HEAD.format(k='Me', t='Your hostel on Hostelzy')
      + '<div style="flex-grow: 1; overflow: hidden; border-top: 2px solid var(--tx); padding: 24px; display: grid; gap: 10px; align-content: start;"><b style="font-size: 18px;">No hostel added yet</b>'
      + CTA.format(l='Add a hostel') + '</div>' + NAV)
# T37 · joinForm closed (Build: the red box, "This bed was just taken, ask your owner.")
board('f29-joinFormClosed.dc.html', '[T37] joinForm · Closed: “This bed was just taken, ask your owner.” · New (v26)',
      HEAD.format(k='Bed 203-B · ₹8,000/month', t='Join Anjani Residency')
      + '<div style="flex-grow: 1; overflow: hidden; border-top: 2px solid var(--tx); padding: 16px; display: grid; align-content: start;"><div style="padding: 14px; background: var(--ab); border: 2px solid var(--ad); color: var(--ad); font-size: 15px; font-weight: 800; line-height: 1.4;">This bed was just taken, ask your owner.</div></div>')
NEW = {'f28-myAddEmpty.dc.html': (6580, 61515, '[T35] myAdd · No hostel added yet: Add a hostel · New (v26)', 'f28-myAddQueued.dc.html'),
       'f29-joinFormClosed.dc.html': (7050, 60251, '[T37] joinForm · Closed: “This bed was just taken, ask your owner.” · New (v26)', 'f29-driveNA.dc.html')}
for f, (x, y, t, after) in NEW.items():
    B[f] = {'h': 844, 'title': t, 'w': 390, 'x': x, 'y': y}
    d['order'].insert(d['order'].index(after) + 1, f)
    changed.append(f)
json.dump(d, open(f'{OUT}/canvas.json', 'w'), ensure_ascii=False, indent=1, sort_keys=True)

files = sorted(set(os.listdir(OUT)))
add = ['canvas.json'] + [f for f in files if f.endswith('.dc.html')]
json.dump({'add_or_change': ['project/' + f for f in add], 'delete': ['project/' + f for f in delete]},
          open('docs/design/v26/publish.json', 'w'), indent=1)

# checks
for f in add[1:]: assert f in B, f
assert len(B) == len(d['order']) == len(set(d['order'])) and set(B) == set(d['order'])
cnt = [b['title'] for b in B.values() if re.match(r'\[[SHTCW]\d+( · sent)?\]', b['title'])]
print('boards', len(B), 'counted', len(cnt), 'files to publish', len(add), 'delete', len(delete))
