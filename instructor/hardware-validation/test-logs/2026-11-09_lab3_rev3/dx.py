import copy, re, sys, zipfile
from lxml import etree
W = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
M = 'http://schemas.openxmlformats.org/officeDocument/2006/math'
XML = 'http://www.w3.org/XML/1998/namespace'
ns = {'w': W, 'm': M}
def w(t): return '{%s}%s' % (W, t)
def m(t): return '{%s}%s' % (M, t)
# ---------------------------------------------------------------- run builders
def rpr(kind):
    p = etree.Element(w('rPr'))
    if kind == 'code':
        f = etree.SubElement(p, w('rFonts'))
        for a in ('ascii', 'hAnsi', 'cs'): f.set(w(a), 'Consolas')
        s = etree.SubElement(p, w('shd')); s.set(w('val'), 'clear'); s.set(w('color'), 'auto'); s.set(w('fill'), 'F2F2F2')
        return p
    f = etree.SubElement(p, w('rFonts')); f.set(w('cs'), 'Calibri')
    if 'b' in kind: etree.SubElement(p, w('b')); etree.SubElement(p, w('bCs'))
    if 'i' in kind: etree.SubElement(p, w('i'))
    if 'c' in kind: s = etree.SubElement(p, w('sz')); s.set(w('val'), '20')
    return p

def run(text, kind=''):
    r = etree.Element(w('r')); r.append(rpr(kind))
    t = etree.SubElement(r, w('t')); t.text = text; t.set('{%s}space' % XML, 'preserve')
    return r

def mrun(text, sty=None):
    r = etree.Element(m('r'))
    if sty:
        pr = etree.SubElement(r, m('rPr')); s = etree.SubElement(pr, m('sty')); s.set(m('val'), sty)
    wp = etree.SubElement(r, w('rPr')); f = etree.SubElement(wp, w('rFonts'))
    f.set(w('ascii'), 'Cambria Math'); f.set(w('hAnsi'), 'Cambria Math')
    t = etree.SubElement(r, m('t')); t.text = text; t.set('{%s}space' % XML, 'preserve')
    return r

def mnodes(s):
    """Tiny linear math syntax: X_{..} X^{..} \\hat{x}; everything else literal."""
    out, buf, i = [], '', 0
    def flush():
        nonlocal buf
        if buf: out.append(mrun(buf)); buf = ''
    def group(j):
        depth, k = 1, j
        while depth:
            if s[k] == '{': depth += 1
            elif s[k] == '}': depth -= 1
            k += 1
        return s[j:k-1], k
    while i < len(s):
        if s.startswith('\\hat{', i):
            flush(); inner, i = group(i + 5)
            acc = etree.Element(m('acc')); e = etree.SubElement(acc, m('e')); e.append(mrun(inner, 'bi'))
            out.append(acc)
        elif s[i] in '_^' and i + 1 < len(s) and s[i+1] == '{':
            if buf:
                base = mrun(buf[-1]); buf = buf[:-1]; flush()
            else:
                base = out.pop()
            inner, j = group(i + 2)
            tag = 'sSub' if s[i] == '_' else 'sSup'
            el = etree.Element(m(tag)); e = etree.SubElement(el, m('e')); e.append(base)
            sub = etree.SubElement(el, m('sub' if s[i] == '_' else 'sup'))
            for n in mnodes(inner): sub.append(n)
            out.append(el); i = j
        else:
            buf += s[i]; i += 1
    flush()
    return out

def omath(s):
    o = etree.Element(m('oMath'))
    for n in mnodes(s): o.append(n)
    return o

TOK = re.compile(r'(\*\*.+?\*\*|`.+?`|\$.+?\$)')
def inline(markup, kind=''):
    els = []
    for part in TOK.split(markup):
        if not part: continue
        if part.startswith('**'): els.append(run(part[2:-2], kind + 'b'))
        elif part.startswith('`'): els.append(run(part[1:-1], 'code'))
        elif part.startswith('$'): els.append(omath(part[1:-1]))
        else: els.append(run(part, kind))
    return els

def para(markup, style=None, jc=None, numid=None, kind=''):
    p = etree.Element(w('p'))
    if style or jc or numid is not None:
        pr = etree.SubElement(p, w('pPr'))
        if style: s = etree.SubElement(pr, w('pStyle')); s.set(w('val'), style)
        if numid is not None:
            n = etree.SubElement(pr, w('numPr'))
            a = etree.SubElement(n, w('ilvl')); a.set(w('val'), '0')
            b = etree.SubElement(n, w('numId')); b.set(w('val'), str(numid))
        if jc: j = etree.SubElement(pr, w('jc')); j.set(w('val'), jc)
    for e in inline(markup, kind): p.append(e)
    return p

def display(*lines):
    p = etree.Element(w('p')); mp = etree.SubElement(p, m('oMathPara'))
    for s in lines: mp.append(omath(s))
    return p

def caption(label, text):
    p = etree.Element(w('p')); pr = etree.SubElement(p, w('pPr')); j = etree.SubElement(pr, w('jc')); j.set(w('val'), 'center')
    p.append(run(label + ':', 'bic'))
    for e in inline(' ' + text, 'ic'): p.append(e)
    return p

def codeline(text):
    p = etree.Element(w('p')); r = run(text, 'code')
    s = etree.SubElement(r.find(w('rPr')), w('sz')); s.set(w('val'), '20')
    p.append(r); return p

def setpar(p, markup, kind=''):
    """Replace the content of an existing paragraph, keeping its pPr."""
    for c in list(p):
        if c.tag != w('pPr'): p.remove(c)
    for e in inline(markup, kind): p.append(e)
    return p

def text_of(el):
    return ''.join(t.text or '' for t in el.iter() if t.tag in (w('t'), m('t')))
