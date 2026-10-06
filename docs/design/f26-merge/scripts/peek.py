import re,sys
P='canvas/project/'
for f in sys.argv[1:]:
    s=open(P+f).read()
    s=s[s.index('<div data-hz'):s.index('</x-dc>')]
    s=re.sub(r'<svg.*?</svg>','[i]',s,flags=re.S)
    s=re.sub(r' style="[^"]*"','',s)
    s=s[:s.find('<nav')] + '[NAV]' if '<nav' in s else s
    print('=====',f); print(s)
