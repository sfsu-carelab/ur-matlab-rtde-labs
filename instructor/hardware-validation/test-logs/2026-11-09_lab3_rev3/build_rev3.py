"""Build Lab 3 manual Rev3 from the professor's Rev2 docx (prof.docx)."""
import copy, re, sys, zipfile
from lxml import etree

W = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
M = 'http://schemas.openxmlformats.org/officeDocument/2006/math'
XML = 'http://www.w3.org/XML/1998/namespace'
ns = {'w': W, 'm': M}
def w(t): return '{%s}%s' % (W, t)
def m(t): return '{%s}%s' % (M, t)

SRC, OUT, FIG = sys.argv[1], sys.argv[2], sys.argv[3]
zin = zipfile.ZipFile(SRC)
doc = etree.fromstring(zin.read('word/document.xml'))
body = doc.find('w:body', ns)
orig = list(body)

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

def expect(i, starts):
    t = text_of(orig[i])
    assert t.startswith(starts), (i, t[:80])

# ---------------------------------------------------------------- numbering
num = etree.fromstring(zin.read('word/numbering.xml'))
styles = etree.fromstring(zin.read('word/styles.xml'))
ln = [s for s in styles.findall('w:style', ns) if s.get(w('styleId')) == 'ListNumber'][0]
ln_num = ln.find('w:pPr/w:numPr/w:numId', ns).get(w('val'))
absid = [n for n in num.findall('w:num', ns) if n.get(w('numId')) == ln_num][0].find('w:abstractNumId', ns).get(w('val'))
maxid = max(int(n.get(w('numId'))) for n in num.findall('w:num', ns))
def new_list():
    global maxid
    maxid += 1
    n = etree.SubElement(num, w('num')); n.set(w('numId'), str(maxid))
    a = etree.SubElement(n, w('abstractNumId')); a.set(w('val'), absid)
    o = etree.SubElement(n, w('lvlOverride')); o.set(w('ilvl'), '0')
    s = etree.SubElement(o, w('startOverride')); s.set(w('val'), '1')
    return maxid
LIST_A, LIST_B = new_list(), new_list()

# ---------------------------------------------------------------- edits, keyed by original index
rep = {}          # index -> list of replacement elements ([] deletes)
def keep(i): return [orig[i]]

# title block
expect(2, 'Accompanying MATLAB file')
for t in orig[2].iter(w('t')):
    if 'jointSignConvention' in (t.text or ''):
        t.text = 'screw2hw.m, hw2screw.m, run_self_tests.p'

expect(4, 'In this lab you will derive')
setpar(orig[4], 'In this lab you will derive the forward kinematics of a Universal Robots e-series 6-DOF manipulator (worked example: UR3e) using the Product of Exponentials (PoE) formulation from screw theory. Forward kinematics relates the values of the joint angles to the pose of the end effector, meaning its orientation and its Cartesian position.')

expect(7, 'Identify the screw axis')
setpar(orig[7], 'Identify the rotation axis $ω$ and a point $q$ on that axis for every joint of a 6-DOF manipulator from its physical geometry.')
expect(8, 'Compute the 6x1 twist')
setpar(orig[8], 'Compute the 6x1 screw axis $S=(ω,v)$ for each joint using $v=-ω×q$.')
expect(10, 'Compute the final')
setpar(orig[10], 'Compute the final homogeneous transformation matrix $T$.')

# Part 1
expect(24, 'The default home configuration')
rep[24] = [
    para('The default home configuration for UR robots has the robot standing straight upright. Figure 1 is a side view of that pose drawn in the **base frame {s}**: the z-axis points up along the joint 1 axis, the y-axis points toward the side where the cable leaves the base, and the x-axis points into the page (right-hand rule). The wrist hangs out in the negative y direction, so every y coordinate of the arm is zero or negative at home. One figure serves every UR e-series robot (UR3e, UR5e and the others): they all share this joint layout and differ only in the six link lengths $L_{1}$ to $L_{6}$.'),
    para('The red arrow at each joint is its positive rotation direction $ω_{i}$, and the red curved arrow around it shows that rotation by the right-hand rule. These are the robot\'s own directions: the Teach Pendant counts a joint angle as positive in exactly this sense, and Universal Robots draws the same joint axes in its documentation (the blue arrows of Figure 2). Joints 1 and 5 point along +z, and joints 2, 3, 4 and 6 point along −y. Figure 2 is included so that you can see the real shape of the links behind the stick figure of Figure 1. Take every direction and length you need from Figure 1.'),
]
# figure 1 image size
EMU_W = 4114800
EMU_H = round(EMU_W * 1725 / 1187)
for e in orig[25].iter():
    if e.tag.endswith('}extent') or e.tag.endswith('}ext'):
        if e.get('cx'): e.set('cx', str(EMU_W)); e.set('cy', str(EMU_H))
expect(26, 'Figure 1')
rep[26] = [caption('Figure 1', 'UR e-series schematic at the home pose in the base frame {s}: joints numbered 1 to 6, link lengths $L_{1}$ to $L_{6}$, and the positive rotation direction $ω$ of every joint (red arrows). Base frame axes: +y points left, +z points up, and +x points into the page.')]
expect(28, 'Figure 2')
rep[28] = [caption('Figure 2', 'The same home pose as drawn by Universal Robots (red = x, green = y, blue = z of each joint frame; a circled dot points out of the page, a circled cross into it). The blue arrows are the joint axes and agree with the red arrows of Figure 1.')]
expect(29, 'The link lengths are taken')
setpar(orig[29], 'The link lengths are taken directly from the Universal Robots documentation. Table 1 lists the UR3e values used in the worked example. Every other e-series model uses the same structure with different lengths, which the accompanying `ur_link_lengths.m` returns for the robot model you name. The MATLAB files use the same names, `L1` to `L6`.')
# Table 1: drop the "(d1)" style names
for tr in orig[31].findall('w:tr', ns)[1:]:
    p = tr.find('w:tc', ns).find('w:p', ns)
    for r in p.findall('w:r', ns): p.remove(r)

# worked example
expect(34, 'Step 1')
setpar(orig[34], '**Step 1 -** Find the rotation axis $ω_{2}$.  In the home configuration (Figure 1), the red arrow of joint 2 is horizontal and points along the −y direction of the base frame. Since $ω$ must be a unit vector: $ω_{2}=(0,-1,0)$.')
expect(37, '-ω2×q2'); expect(38, '-L1')
rep[37] = [display('-ω_{2}×q_{2}=-(0,-1,0)×(0,0,L_{1})=(0,1,0)×(0,0,L_{1})')]
rep[38] = [display('=((1)(L_{1})-(0)(0))\\hat{i}-((0)(L_{1})-(0)(0))\\hat{j}+((0)(0)-(1)(0))\\hat{k}=(L_{1})\\hat{i}-(0)\\hat{j}+(0)\\hat{k}')]
expect(39, 'so ')
setpar(orig[39], 'so $v_{2}=(L_{1},0,0)=(0.15185,0,0)$.')
expect(40, 'Stacking')
setpar(orig[40], 'Stacking $ω$ on top of $v$ gives the 6x1 screw axis vector:  $S_{2}=(ω_{2},v_{2})=[0,-1,0,L_{1},0,0]=[0,-1,0,0.15185,0,0]$. The symbolic form is what you will enter in MATLAB:  `[0, -1, 0, L1, 0, 0]`.')
expect(41, 'Physical check')
setpar(orig[41], 'Physical check: $v$ is the velocity of the point of the moving body that currently sits at the base origin. If the shoulder rotates at 1 rad/s about −y, a point at the origin (a distance $L_{1}$ below the axis) sweeps in the +x direction at $L_{1}$ m/s, which is exactly $v_{2}=(L_{1},0,0)$.')
expect(42, 'Check your understanding')
setpar(orig[42], 'Check your understanding: repeat Step 3 with a different point on the same axis, for example $q=(0,0.3,L_{1})$. The extra y component is parallel to $ω_{2}$, so it drops out of the cross product and $v_{2}$ is unchanged. If choosing a different point on the axis changes your $v$, something has gone wrong.')
expect(43, 'General cross product')
setpar(orig[43], '**General cross product formula.** For any two vectors $a=(a_{1},a_{2},a_{3})$ and $b=(b_{1},b_{2},b_{3})$: $a×b=(a_{2}b_{3}-a_{3}b_{2})\\hat{i}-(a_{1}b_{3}-a_{3}b_{1})\\hat{j}+(a_{1}b_{2}-a_{2}b_{1})\\hat{k}$. The worked example above is this formula with $a=-ω$ and $b=q$. You will need it with $ω$ along −y (joints 2, 3, 4 and 6) and along +z (joints 1 and 5).')
expect(44, 'Now derive the remaining')
setpar(orig[44], 'Now derive the remaining five screw axes the same way and record them in Table 2. Joints 3, 4 and 6 are directly analogous to joint 2: $ω=(0,-1,0)$ and $q$ on the base z-axis at the height of that joint. Read the heights from Figure 1: joint 3 is $L_{1}+L_{2}$ up, joint 4 is $L_{1}+L_{2}+L_{3}$ up, and joint 6 is a further $L_{5}$ above joint 4. Joint 1 is simpler still: its axis passes through the origin, so $q=(0,0,0)$ and $v=(0,0,0)$. Joint 5 is the only axis that does not cross the base z-axis: it is vertical and sits a distance $L_{4}$ out along −y, so its $q$ has a nonzero y component.')
expect(45, 'Joint 5 (wrist 2)'); rep[45] = []

expect(47, 'Using')
setpar(orig[47], 'Using Figure 1, identify the unit rotation axis $ω_{i}$, a point $q_{i}$ on the axis, and compute $v_{i}=-ω_{i}×q_{i}$ for each joint. Fill in the table below. Symbolic entries in $L_{1}$ to $L_{6}$ are encouraged in Tables 2 and 3 (that is the form you will type into MATLAB); numbers are optional.')
expect(48, 'Table 2'); rep[48] = [caption('Table 2', 'Joint screw axes')]
hdr = orig[49].find('w:tr', ns).find('w:tc', ns).find('w:p', ns); setpar(hdr, 'Joint')

# R section folded into Task 2
expect(50, 'How to Build'); rep[50] = []; rep[51] = []; rep[52] = []; rep[53] = []
expect(55, 'Referring back')
first = orig[55]
for c in list(first):
    if c.tag in (w('r'), w('proofErr')): first.remove(c)
mth = first.find(m('oMath'))
i0 = list(first).index(mth)
for k, e in enumerate(inline('Using Figure 1, find the homogeneous transformation ')): first.insert(i0 + k, e)
for e in inline(' of the end effector at the robot home configuration.'): first.append(e)
rep[55] = [first,
    para('The position $p$ is the location of the tool flange in base coordinates at home. The rotation $R$ holds the three axes of the tool frame written in base coordinates, one axis per column: $R=[x_{tool}, y_{tool}, z_{tool}]$. Read the three directions from Figure 1. For example, the tool z-axis points along the base −y direction, so the third column of $R$ is (0, −1, 0). A valid rotation matrix has perpendicular unit columns and a determinant of +1.')]
rep[56] = []; rep[57] = []
expect(61, 'Table 4'); rep[61] = [caption('Table 4', 'End-effector orientation at home (the rotation matrix $R$, one row at a time)')]
h = orig[62].find('w:tr', ns).findall('w:tc', ns)
setpar(h[0].find('w:p', ns), 'Row of R'); setpar(h[1].find('w:p', ns), 'Row elements')

# Part 2
expect(66, 'Open the accompanying')
setpar(orig[66], 'Open the accompanying file `UR_FK_Lab.m` and find the section labeled **PART 2**. Enter your six screw axes into `S_list` (each row is $S_{i}=[ω_{x},ω_{y},ω_{z},v_{x},v_{y},v_{z}]$) and your 4x4 home configuration matrix into `M`. Write both symbolically in terms of the link-length variables `L1` to `L6` rather than as raw numbers. Your answer is then correct for every e-series robot, and you can prove it by re-running with a different model, for example `UR_FK_Lab("UR5e")`.')
expect(67, 'Steps to running')
setpar(orig[67], '**Steps to run the MATLAB file** `UR_FK_Lab.m`**:**')
expect(68, 'Put all seven')
setpar(orig[68], 'Put all six accompanying files in one folder and make that folder MATLAB\'s Current Folder (the address bar above the Command Window, or `cd(\'...\')`). If MATLAB reports "Unrecognized function or variable", the Current Folder is wrong.')
expect(69, 'In UR_FK_Lab.m')
setpar(orig[69], 'In `UR_FK_Lab.m` replace each NaN with an expression in `L1`, `L2`, `L3`, `L4`, `L5`, `L6`. These variables are defined a few lines above, so type them literally, for example `L1+L2`. Each row of `S_list` is one joint, `[omega(1:3) v(1:3)]`. The `.\'` after the matrix turns your rows into the columns that `fk_space.m` expects; leave it alone.')
expect(71, 'After a run')
setpar(orig[71], 'After a run, `S_list` and `M` stay in the base workspace (the Workspace panel beside the Command Window), so you can call `fk_space` with them directly, as Part 4 does. If you close MATLAB, run `UR_FK_Lab.m` again first.')

# Part 3
expect(73, 'Run UR_FK_Lab.m')
setpar(orig[73], 'Run `UR_FK_Lab.m`. It executes the test cases below and prints PASS or FAIL for each. For a correct answer every error is at machine precision (about 1e-16 m); the PASS threshold is 1e-10 m. Test 1 only checks that the chain reproduces the $M$ you typed, so it cannot tell whether $M$ is right: tests 2 and 3 check the position part of $M$ and test 5(d) its rotation. Test 5(e) is a sanity check that the tool is never further from the base than the arm is long. If a test shows FAIL, it names the joint it moved: recheck both $ω$ and $v$ of that row of `S_list`. A result of the right size with the wrong sign means that $ω$ points the wrong way.')
rows = orig[75].findall('w:tr', ns)
c = rows[2].findall('w:tc', ns)
assert 'shoulder forward' in text_of(c[1])
setpar(c[1].find('w:p', ns), '$θ_{2}=+90^{∘}$ (shoulder)')
setpar(c[2].find('w:p', ns), '$x=-(L_{2}+L_{3}+L_{5}), z=L_{1}$ (arm horizontal along −x; y stays at $-(L_{4}+L_{6})$)')
c = rows[3].findall('w:tc', ns)
setpar(c[2].find('w:p', ns), 'Wrist offset swings from −y to +x')

# Part 4 (rewritten)
expect(76, 'Part 4'); expect(80, 'Task 3'); expect(85, 'Task 4'); expect(93, 'Table 6'); expect(95, 'Table 6 -')
for i in range(77, 93): rep[i] = []
h2 = lambda t: para(t, style='Heading2')
rep[77] = [
    para('In this part you compare your FK model with the real robot. You jog the robot to a few poses with the Teach Pendant, read its joint angles and its tool position, and check that `fk_space` predicts the same position from the same angles.'),
    para('⚠️ Before moving the robot: set the speed slider to 25%, clear the workspace, and keep the e-stop within reach. In this lab the robot is only jogged from the Teach Pendant; nothing is commanded from MATLAB.'),
    para('If your group runs out of time on the robot, the same steps can be finished in URSim, the Universal Robots simulator, on your own computer. Its Teach Pendant screen shows the same joint angles and TCP position. Expect an error close to zero there, because the simulator uses the nominal link lengths.'),
    h2('Task 3: Map the Pendant Angles to Screw Angles'),
    para('The screw model measures every joint angle from the upright home configuration of Figure 1, where all six screw angles are zero. The Teach Pendant measures from a different zero. At that same upright pose it reads:'),
    codeline('theta_home = [0, -90, 0, -90, 0, 0]  (degrees)'),
    para('The rotation directions are the same in both (the red arrows of Figure 1), so the two sets of angles differ only by this constant offset:'),
    display('θ_{hw}=θ_{screw}+θ_{home}        θ_{screw}=θ_{hw}-θ_{home}'),
    para('The helper functions `hw2screw` and `screw2hw` apply these two formulas, with `theta_home` built in. All angles are in degrees. The robot does not need to be moved to the upright pose.'),
    para('Check your model on one worked pose before going to the robot. Suppose the pendant shows the joint angles [30, −60, −60, −60, 0, 0] degrees.'),
    para('Convert them to screw angles: `theta_screw = hw2screw([30 -60 -60 -60 0 0])` returns [30, 30, −60, 30, 0, 0]. Confirm the result by hand with the formula above.', style='ListNumber', numid=LIST_A),
    para('Run your FK on the screw angles: `T = fk_space(S_list, M, theta_screw)`. `S_list` and `M` are in the workspace after Part 3.', style='ListNumber', numid=LIST_A),
    para('The position is the last column of $T$: `p_fk = T(1:3,4)`, in meters. For a UR3e the result must be (0.0984, −0.2008, 0.6328) m. If yours differs, find the mistake before starting Task 4.', style='ListNumber', numid=LIST_A),
    h2('Task 4: Compare with the Robot'),
    para('⚠️ Tool offset: your FK model ends at the tool flange. The pendant reports the position of the active tool center point (TCP), which is the flange plus whatever tool offset is set on the robot. Find the TCP offset of your robot on the pendant (Installation, TCP) and enter it in MATLAB in meters as a column vector named `tcp`. For example, the Robotiq 2F-85 gripper set up in Lab 1 has a TCP offset of (0, 0, 174) mm, which gives `tcp = [0; 0; 0.174]`. A robot with no tool set has `tcp = [0; 0; 0]`.'),
    para('Jog the robot with the Teach Pendant (Move screen) to a pose of your choosing that is clear of the table, the walls and the camera. Move several joints, not just one.', style='ListNumber', numid=LIST_B),
    para('Record the six joint angles shown on the pendant in Table 6 and convert them to screw angles: `theta_screw = hw2screw([J1 J2 J3 J4 J5 J6])`.', style='ListNumber', numid=LIST_B),
    para('Compute the FK position of the TCP: `T = fk_space(S_list, M, theta_screw)`, then `p_fk = T(1:3,4) + T(1:3,1:3)*tcp`. The second term carries the tool offset from the flange out to the TCP.', style='ListNumber', numid=LIST_B),
    para('Read the TCP position from the pendant (Move screen, TCP position, with the feature set to Base) and convert millimeters to meters as a column vector: `p_robot = [X; Y; Z] / 1000` (note the semicolons).', style='ListNumber', numid=LIST_B),
    para('Compute the error in millimeters: `err_mm = norm(p_fk - p_robot) * 1000`. Record the angles, both positions and the error in Table 6.', style='ListNumber', numid=LIST_B),
    para('Repeat for two more poses. Across the three poses every joint should have moved at least once.', style='ListNumber', numid=LIST_B),
    para('How to read the result: an error under 3 mm is excellent and a few millimeters is a success, because the factory calibration of each robot differs slightly from the nominal link lengths. A large error that is about the same at every pose usually means the wrong `tcp`. An error near 1000 mm means one of the two vectors is a row instead of a column. The right size with the wrong sign in one coordinate means a sign error in one $ω$.'),
]
# Table 6
t6 = orig[94]; trs = t6.findall('w:tr', ns)
heads = ['Pose', 'Pendant Angles (deg)', 'Screw Angles (deg)', 'FK Position p_fk (m)', 'Robot TCP p_robot (m)', 'Error (mm)']
for tc, txt in zip(trs[0].findall('w:tc', ns), heads): setpar(tc.find('w:p', ns), txt)
for k, tr in enumerate(trs[1:4], 1):
    tcs = tr.findall('w:tc', ns)
    for t in tcs[0].iter(w('t')): t.text = str(k)
    for tc in tcs[1:]:
        p = tc.find('w:p', ns)
        for ch in list(p):
            if ch.tag != w('pPr'): p.remove(ch)
for tr in trs[4:]: t6.remove(tr)
rep[95] = []

# ---------------------------------------------------------------- rebuild body
for el in orig: body.remove(el)
for i, el in enumerate(orig):
    for e in rep.get(i, [el]): body.append(e)

# global word fixes in remaining text nodes
for t in doc.iter(w('t')):
    if t.text:
        t.text = t.text.replace('homogenous', 'homogeneous')

# ---------------------------------------------------------------- write package
zout = zipfile.ZipFile(OUT, 'w', zipfile.ZIP_DEFLATED)
hdr = b'<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
for info in zin.infolist():
    data = zin.read(info.filename)
    if info.filename == 'word/document.xml': data = hdr + etree.tostring(doc, encoding='UTF-8')
    elif info.filename == 'word/numbering.xml': data = hdr + etree.tostring(num, encoding='UTF-8')
    elif info.filename == 'word/media/image1.png': data = open(FIG, 'rb').read()
    zout.writestr(info.filename, data)
zout.close()
print('wrote', OUT)
