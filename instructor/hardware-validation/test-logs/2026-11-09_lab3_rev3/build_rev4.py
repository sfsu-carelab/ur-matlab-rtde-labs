"""Build Lab 3 manual Rev4 from Rev3 (as last saved by Dr. Quintero on Box, 2026-11-09 20:43).
Changes: Figure 2 removed, Task 3 variables defined and the offset explained,
variable-definition sweep, J1..J6 replaced by theta_hw."""
import sys, zipfile
from lxml import etree
from dx import *

SRC, OUT = sys.argv[1], sys.argv[2]
zin = zipfile.ZipFile(SRC)
doc = etree.fromstring(zin.read('word/document.xml'))
rels = etree.fromstring(zin.read('word/_rels/document.xml.rels'))
body = doc.find('w:body', ns)

def find(prefix, nth=0):
    hits = [p for p in body if p.tag == w('p') and text_of(p).startswith(prefix)]
    assert len(hits) > nth, ('not found', prefix)
    assert nth or len(hits) == 1, ('ambiguous', prefix, len(hits))
    return hits[nth]
def after(ref, *els):
    i = list(body).index(ref)
    for k, e in enumerate(els): body.insert(i + 1 + k, e)
def append(p, markup):
    for e in inline(markup): p.append(e)
def numid(p): return p.find('w:pPr/w:numPr/w:numId', ns).get(w('val'))
def cell_par(tbl, r, c): return tbl.findall('w:tr', ns)[r].findall('w:tc', ns)[c].find('w:p', ns)
def table_after(p):
    i = list(body).index(p)
    for e in list(body)[i+1:]:
        if e.tag == w('tbl'): return e

# ---- Overview and objectives
setpar(find('In this lab you will derive'), 'In this lab you will derive the forward kinematics (FK) of a Universal Robots e-series manipulator with six degrees of freedom (6-DOF), using the Product of Exponentials (PoE) formulation from screw theory. The UR3e is the worked example. Forward kinematics relates the values of the joint angles to the pose of the end effector, meaning its orientation and its Cartesian position.')
setpar(find('Compute the 6x1 screw axis'), 'Compute the 6x1 screw axis $S=(ω,v)$ for each joint, where $v=-ω×q$ is its linear velocity part.')
setpar(find('Assemble the home pose matrix'), 'Assemble the home pose matrix $M$, the pose of the end effector when all joint angles are zero, from the robot\'s dimensions.')
setpar(find('Compute the final homogeneous'), 'Compute the homogeneous transformation matrix $T$, the pose of the end effector for any set of joint angles.')
setpar(find('Verify your Forward Kinematics'), 'Verify your FK model against the physical robot.')

# ---- Background
setpar(find('For a kinematic-chain manipulator'), 'For a kinematic-chain manipulator with $n$ revolute joints ($n=6$ for the UR robots), the space-frame PoE formula gives the pose $T$ of the end effector, a 4x4 homogeneous transformation matrix, as a function of the joint angles $θ=(θ_{1},…,θ_{n})$:')
append(find('Each factor'), ' Here $[S_{i}]$ denotes the 4x4 matrix form of the screw axis $S_{i}$.')
append(find('Si=[ωi;vi]'), ' The space frame is the fixed base frame {s} of Figure 1.')

# ---- Part 1: one figure only
setpar(find('The red arrow at each joint'), 'The red arrow at each joint is its positive rotation direction $ω_{i}$, and the red curved arrow around it shows that rotation by the right-hand rule. These are the robot\'s own directions: the Teach Pendant counts a joint angle as positive in exactly this sense, and Universal Robots uses the same joint axes in its documentation. Joints 1 and 5 point along +z, and joints 2, 3, 4 and 6 point along −y. The six link lengths are labeled $L_{1}$ to $L_{6}$ from the base up, and the tool frame {b} is attached to the tool flange.')
cap2 = find('Figure 2')
img2 = list(body)[list(body).index(cap2) - 1]
assert img2.findall('.//' + w('drawing')) and 'rId9' in etree.tostring(img2).decode()
body.remove(img2); body.remove(cap2)
for r in rels:
    if r.get('Target') == 'media/image2.png': rels.remove(r)
new_cap = caption('Figure 1', 'UR e-series schematic at the home pose in the base frame {s}: joints numbered 1 to 6, link lengths $L_{1}$ to $L_{6}$, the positive rotation direction $ω$ of every joint (red arrows), and the tool frame {b} at the flange. Base frame axes: +y points left, +z points up, and +x points into the page.')
old_cap = find('Figure 1: UR e-series'); after(old_cap, new_cap); body.remove(old_cap)

# ---- Worked example
setpar(find('Step 3 -'), '**Step 3 -** Compute $v_{2}=-ω_{2}×q_{2}$.  Writing the cross product out component by component, where $\\hat{i}$, $\\hat{j}$ and $\\hat{k}$ are the unit vectors along the x, y and z axes of the base frame:')

# ---- stray empty heading left before Task 2
t2 = find('Task 2: Determine the Home Pose')
prev = list(body)[list(body).index(t2) - 1]
if prev.tag == w('p') and not text_of(prev).strip() and prev.find('w:pPr/w:pStyle', ns) is not None:
    body.remove(prev)

# ---- Task 2
setpar(find('The position p is the location'), 'The position $p=(p_{x},p_{y},p_{z})$ is the location of the tool flange in base coordinates at home. The rotation matrix $R$ holds the three axes of the tool frame {b} written in base coordinates, one axis per column: $R=[x_{tool}, y_{tool}, z_{tool}]$, where $x_{tool}$, $y_{tool}$ and $z_{tool}$ are the unit vectors of the tool frame axes drawn at the flange in Figure 1. Read the three directions from Figure 1. For example, the tool z-axis points along the base −y direction, so the third column of $R$ is (0, −1, 0). A valid rotation matrix has perpendicular unit columns and a determinant of +1.')

# ---- Part 2
setpar(find('In UR_FK_Lab.m replace each'), 'In `UR_FK_Lab.m` replace each `NaN` (MATLAB\'s "not a number" placeholder) with an expression in `L1`, `L2`, `L3`, `L4`, `L5`, `L6`. These variables are defined a few lines above, so type them literally, for example `L1+L2`. Each row of `S_list` is one joint, `[omega(1:3) v(1:3)]`, that is the three components of $ω$ followed by the three components of $v$. The `.\'` after the matrix turns your rows into the columns that `fk_space.m` expects; leave it alone.')

# ---- Part 3
setpar(find('Run UR_FK_Lab.m. It executes'), 'Run `UR_FK_Lab.m`. It executes the test cases below and prints PASS or FAIL for each. Every configuration in Table 5 is given in screw angles $θ_{1}$ to $θ_{6}$, the joint angles of your PoE formula measured from the home configuration. For a correct answer every error is at machine precision (about $10^{-16}$ m); the PASS threshold is $10^{-10}$ m. Test 1 only checks that the chain reproduces the $M$ you typed, so it cannot tell whether $M$ is right: tests 2 and 3 check the position part of $M$ and test 5(d) its rotation. Test 5(e) is a sanity check that the tool is never further from the base than the arm is long. If a test shows FAIL, it names the joint it moved: recheck both $ω$ and $v$ of that row of `S_list`. A result of the right size with the wrong sign means that $ω$ points the wrong way.')

# ---- Part 4 intro
setpar(find('⚠️ Before moving the robot'), '⚠️ Before moving the robot: set the speed slider to 25%, clear the workspace, and keep the emergency stop (e-stop) within reach. In this lab the robot is only jogged from the Teach Pendant; nothing is commanded from MATLAB.')
setpar(find('If your group runs out of time'), 'If your group runs out of time on the robot, the same steps can be finished in URSim, the Universal Robots simulator, on your own computer. Its Teach Pendant screen shows the same joint angles and tool position. Expect an error close to zero there, because the simulator uses the nominal link lengths.')

# ---- Task 3 (rewritten)
h3 = find('Task 3: Map the Pendant Angles'); h4 = find('Task 4: Compare with the Robot')
kids = list(body); i3, i4 = kids.index(h3), kids.index(h4)
LIST_A = [numid(p) for p in kids[i3+1:i4] if p.find('w:pPr/w:numPr', ns) is not None][0]
for p in kids[i3+1:i4]: body.remove(p)
LN = dict(style='ListNumber', numid=LIST_A); LB = dict(style='ListBullet')
after(h3,
    para('The Teach Pendant and your screw model do not show the same numbers for the same pose. This task relates the two. Three sets of joint angles are used. Each one is a list of six angles in degrees, one per joint, ordered from the base (joint 1) to wrist 3 (joint 6):'),
    para('$θ_{screw}$, written `theta_screw` in MATLAB: the screw angles. These are the joint angles $θ_{1}$ to $θ_{6}$ of your PoE formula, the ones `fk_space` expects. They are measured from the upright home configuration of Figure 1, so all six are zero in that pose.', **LB),
    para('$θ_{hw}$, written `theta_hw`: the hardware angles. These are the six joint angles that the Teach Pendant displays.', **LB),
    para('$θ_{home}$, written `theta_home`: the hardware angles that the Teach Pendant displays when the robot stands in the upright home configuration. They are the same for every UR e-series robot:', **LB),
    codeline('theta_home = [0, -90, 0, -90, 0, 0]  (degrees)'),
    para('Both sets of angles describe the same joints turning about the same axes in the same positive direction (the red arrows of Figure 1). The only difference is the pose at which each one reads zero: the screw angles are zero at the upright home configuration, while the Teach Pendant reads zero at a different pose chosen by Universal Robots. When a joint turns, both readings therefore change by the same amount, and the difference between them stays what it was at the home configuration. That constant difference is $θ_{home}$:'),
    display('θ_{hw}=θ_{screw}+θ_{home}        θ_{screw}=θ_{hw}-θ_{home}'),
    para('For example, with the robot upright, joint 2 reads −90 on the Teach Pendant and 0 in the screw model. Turn joint 2 by 30 degrees in the positive direction and the Teach Pendant reads −60 while the screw angle is 30. The difference is still −90.'),
    para('The helper functions `hw2screw` and `screw2hw` apply these two formulas with `theta_home` built in. The robot does not need to be moved to the upright pose.'),
    para('Check your model on one worked pose before going to the robot. Suppose the Teach Pendant shows the hardware angles `theta_hw = [30 -60 -60 -60 0 0]`.'),
    para('Convert them to screw angles: `theta_screw = hw2screw(theta_hw)` returns [30, 30, −60, 30, 0, 0]. Confirm the result by hand with the formula above.', **LN),
    para('Run your FK on the screw angles: `T = fk_space(S_list, M, theta_screw)`. `S_list` and `M` are in the workspace after Part 3, and `T` is the 4x4 pose of the tool flange.', **LN),
    para('The flange position is the last column of `T`: `p_fk = T(1:3,4)`, in meters. For a UR3e the result must be (0.0984, −0.2008, 0.6328) m. If yours differs, find the mistake before starting Task 4.', **LN),
)

# ---- Task 4 steps
setpar(find('Record the six joint angles'), 'Enter the six joint angles that the Teach Pendant shows, in degrees and in order from joint 1 to joint 6, as the hardware angles `theta_hw`, for example `theta_hw = [30 -60 -60 -60 0 0]`. Record them in Table 6 and convert them to screw angles: `theta_screw = hw2screw(theta_hw)`.')
setpar(find('Compute the FK position of the TCP'), 'Compute the TCP position that your FK model predicts, `p_fk`: first `T = fk_space(S_list, M, theta_screw)`, then `p_fk = T(1:3,4) + T(1:3,1:3)*tcp`. Here `T(1:3,4)` is the flange position and `T(1:3,1:3)` is the rotation matrix inside `T`, so the second term carries the tool offset from the flange out to the TCP. The result is in meters.')
setpar(find('Read the TCP position from the pendant'), 'Read the TCP position X, Y, Z that the Teach Pendant displays in millimeters (Move screen, TCP position, with the feature set to Base so that the position is given in the base frame). Convert it to meters as a column vector to get the measured TCP position, `p_robot = [X; Y; Z] / 1000` (note the semicolons).')
setpar(find('Compute the error in millimeters'), 'Compute the error `err_mm`, the distance in millimeters between the predicted and the measured TCP position: `err_mm = norm(p_fk - p_robot) * 1000`. Record the angles, both positions and the error in Table 6.')
t6 = table_after(find('Table 6'))
setpar(cell_par(t6, 0, 1), 'Hardware Angles theta_hw (deg)')
setpar(cell_par(t6, 0, 2), 'Screw Angles theta_screw (deg)')
t5 = table_after(find('Table 5'))
setpar(cell_par(t5, 0, 1), 'Configuration (screw angles)')

# ---- write
hdr = b'<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
zout = zipfile.ZipFile(OUT, 'w', zipfile.ZIP_DEFLATED)
for info in zin.infolist():
    if info.filename == 'word/media/image2.png': continue
    data = zin.read(info.filename)
    if info.filename == 'word/document.xml': data = hdr + etree.tostring(doc, encoding='UTF-8')
    elif info.filename == 'word/_rels/document.xml.rels': data = hdr + etree.tostring(rels, encoding='UTF-8')
    zout.writestr(info.filename, data)
zout.close(); print('wrote', OUT)
