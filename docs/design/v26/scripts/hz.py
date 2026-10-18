"""Span-accurate HTML element finder for the .dc.html boards (keeps every other byte identical)."""
import re, html as H
from html.parser import HTMLParser
VOID={'input','br','img','hr','meta','link','source','wbr','col','area','base','track','embed','param'}
class El:
    __slots__=('tag','attrs','start','cstart','cend','end','parent','children','text')
    def __init__(s,tag,attrs,start,parent):
        s.tag=tag; s.attrs=dict(attrs); s.start=start; s.cstart=None; s.cend=None; s.end=None; s.parent=parent; s.children=[]; s.text=''
    @property
    def style(s): return s.attrs.get('style','')
    def __repr__(s): return f'<{s.tag} {s.text[:50]!r}>'
class P(HTMLParser):
    def __init__(s,raw):
        super().__init__(convert_charrefs=True); s.raw=raw; s.lines=[0]
        for m in re.finditer('\n',raw): s.lines.append(m.end())
        s.stack=[]; s.all=[]; s.root=None
    def off(s):
        l,c=s.getpos(); return s.lines[l-1]+c
    def handle_starttag(s,tag,attrs):
        st=s.off(); e=El(tag,attrs,st,s.stack[-1] if s.stack else None)
        e.cstart=st+len(s.get_starttag_text())
        if e.parent: e.parent.children.append(e)
        s.all.append(e)
        if tag in VOID: e.cend=e.end=e.cstart; return
        s.stack.append(e)
    def handle_startendtag(s,tag,attrs):
        st=s.off(); e=El(tag,attrs,st,s.stack[-1] if s.stack else None)
        e.cstart=e.cend=e.end=st+len(s.get_starttag_text())
        if e.parent: e.parent.children.append(e)
        s.all.append(e)
    def handle_endtag(s,tag):
        st=s.off()
        # pop to matching
        for i in range(len(s.stack)-1,-1,-1):
            if s.stack[i].tag==tag:
                for e in s.stack[i+1:]: e.cend=e.end=st
                e=s.stack[i]; e.cend=st; e.end=s.raw.index('>',st)+1; del s.stack[i:]; return
    def handle_data(s,data):
        for e in s.stack: e.text+=data
class Doc:
    def __init__(s,raw):
        s.raw=raw; p=P(raw); p.feed(raw); s.els=p.all
        for e in s.els:
            if e.end is None: e.cend=e.end=len(raw)
            e.text=re.sub(r'\s+',' ',e.text).strip()
    def find(s,text=None,tag=None,style=None,exact=False,all=False,contains=None):
        r=[]
        for e in s.els:
            if tag and e.tag!=tag: continue
            if style and style not in e.style: continue
            if text is not None:
                if exact:
                    if e.text!=text: continue
                elif text not in e.text: continue
            r.append(e)
        if text is not None and not exact:
            # innermost: drop those that have a child also matching
            rs=set(id(x) for x in r)
            r=[e for e in r if not any(id(c) in rs for c in e.children)]
        if all: return r
        if len(r)!=1: raise KeyError(f'{len(r)} matches for text={text!r} tag={tag} style={style}: {r[:4]}')
        return r[0]
    def outer(s,e): return s.raw[e.start:e.end]
    def inner(s,e): return s.raw[e.cstart:e.cend]
def apply(raw,ops):
    """ops: list of (start,end,replacement). Non-overlapping; applied from the end."""
    for st,en,rep in sorted(ops,key=lambda o:-o[0]): raw=raw[:st]+rep+raw[en:]
    return raw
