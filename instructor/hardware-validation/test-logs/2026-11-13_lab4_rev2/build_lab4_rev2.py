"""Build Lab 4 manual Rev2 from Rev1 (styles, numbering, theme reused; body rewritten).
Header and footer are copied from the Lab 3 Rev4 manual so the two match.
usage: build_lab4_rev2.py <Lab4 Rev1 docx> <Lab3 Rev4 docx> <out docx> <figure1 png>"""
import sys, zipfile
from lxml import etree
from dx import *

SRC, L3, OUT, FIG = sys.argv[1:5]
R = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'
PR = 'http://schemas.openxmlformats.org/package/2006/relationships'
CT = 'http://schemas.openxmlformats.org/package/2006/content-types'
zin, z3 = zipfile.ZipFile(SRC), zipfile.ZipFile(L3)
doc = etree.fromstring(zin.read('word/document.xml'))
rels = etree.fromstring(zin.read('word/_rels/document.xml.rels'))
ctypes = etree.fromstring(zin.read('[Content_Types].xml'))
numx = etree.fromstring(zin.read('word/numbering.xml'))
body = doc.find('w:body', ns)
sect = body.find('w:sectPr', ns)
for c in list(body):
    if c is not sect: body.remove(c)

# ---------------------------------------------------------------- helpers
def add(*els):
    for e in els: sect.addprevious(e)
def H1(t): add(para(t, style='Heading1'))
def H2(t): add(para(t, style='Heading2'))
def P(t): add(para(t))
def B(t): add(para(t, style='ListBullet'))
_next = [max(int(n.get(w('numId'))) for n in numx.findall('w:num', ns)) + 1]
def newlist():
    """A fresh numbered list that restarts at 1 (same abstract list as ListNumber)."""
    nid = _next[0]; _next[0] += 1
    n = etree.SubElement(numx, w('num')); n.set(w('numId'), str(nid))
    a = etree.SubElement(n, w('abstractNumId')); a.set(w('val'), '7')
    o = etree.SubElement(n, w('lvlOverride')); o.set(w('ilvl'), '0')
    s = etree.SubElement(o, w('startOverride')); s.set(w('val'), '1')
    return nid
def steps(*items):
    nid = newlist()
    for t in items: add(para(t, style='ListNumber', numid=nid))
def table(label, text, widths, rows):
    add(caption(label, text))
    t = etree.Element(w('tbl')); pr = etree.SubElement(t, w('tblPr'))
    s = etree.SubElement(pr, w('tblStyle')); s.set(w('val'), 'LightGrid-Accent1')
    tw = etree.SubElement(pr, w('tblW')); tw.set(w('w'), '0'); tw.set(w('type'), 'auto')
    lk = etree.SubElement(pr, w('tblLook'))
    for k, v in dict(val='04A0', firstRow='1', lastRow='0', firstColumn='1', lastColumn='0', noHBand='0', noVBand='1').items(): lk.set(w(k), v)
    g = etree.SubElement(t, w('tblGrid'))
    for x in widths: c = etree.SubElement(g, w('gridCol')); c.set(w('w'), str(x))
    for row in rows:
        tr = etree.SubElement(t, w('tr'))
        for x, cell in zip(widths, row):
            tc = etree.SubElement(tr, w('tc')); tp = etree.SubElement(tc, w('tcPr'))
            cw = etree.SubElement(tp, w('tcW')); cw.set(w('w'), str(x)); cw.set(w('type'), 'dxa')
            tc.append(para(cell))
    add(t, para(''))
def link(text, url, rid):
    r = etree.SubElement(rels, '{%s}Relationship' % PR)
    r.set('Id', rid); r.set('Type', R + '/hyperlink'); r.set('Target', url); r.set('TargetMode', 'External')
    h = etree.Element(w('hyperlink')); h.set('{%s}id' % R, rid)
    rn = run(text); rp = rn.find(w('rPr'))
    c = etree.SubElement(rp, w('color')); c.set(w('val'), '0563C1')
    u = etree.SubElement(rp, w('u')); u.set(w('val'), 'single')
    h.append(rn); return h

def figure(png, rid, width_in, label, text):
    import struct
    data = open(png, 'rb').read(); pw, ph = struct.unpack('>II', data[16:24])
    cx = int(width_in * 914400); cy = int(cx * ph / pw)
    xml = ('<w:p xmlns:w="%s" xmlns:r="%s" xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" '
           'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">'
           '<w:pPr><w:jc w:val="center"/></w:pPr><w:r><w:drawing><wp:inline distT="0" distB="0" distL="0" distR="0">'
           '<wp:extent cx="%d" cy="%d"/><wp:effectExtent l="0" t="0" r="0" b="0"/><wp:docPr id="1" name="Picture 1"/>'
           '<wp:cNvGraphicFramePr><a:graphicFrameLocks noChangeAspect="1"/></wp:cNvGraphicFramePr>'
           '<a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:pic>'
           '<pic:nvPicPr><pic:cNvPr id="0" name="image1.png"/><pic:cNvPicPr/></pic:nvPicPr>'
           '<pic:blipFill><a:blip r:embed="%s"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>'
           '<pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="%d" cy="%d"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>'
           '</pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r></w:p>') % (W, R, cx, cy, rid, cx, cy)
    r = etree.SubElement(rels, '{%s}Relationship' % PR); r.set('Id', rid); r.set('Type', R + '/image'); r.set('Target', 'media/image1.png')
    d = etree.SubElement(ctypes, '{%s}Default' % CT); d.set('Extension', 'png'); d.set('ContentType', 'image/png')
    add(etree.fromstring(xml), caption(label, text))
    return data

# ---------------------------------------------------------------- title block (Lab 3 layout)
add(para('Lab 4', style='Title'))
p = etree.Element(w('p')); r = run('Pick-and-Place: Teach Pendant Programming and MATLAB RTDE Control', 'b')
rp = r.find(w('rPr')); c = etree.SubElement(rp, w('color')); c.set(w('val'), '2F5496'); s = etree.SubElement(rp, w('sz')); s.set(w('val'), '36')
p.append(r); add(p)
p = etree.Element(w('p')); r = etree.SubElement(p, w('r')); rp = etree.SubElement(r, w('rPr'))
f = etree.SubElement(rp, w('rFonts'))
for a, v in (('asciiTheme', 'majorHAnsi'), ('eastAsiaTheme', 'majorEastAsia'), ('hAnsiTheme', 'majorHAnsi'), ('cstheme', 'majorBidi')): f.set(w(a), v)
etree.SubElement(rp, w('b')); etree.SubElement(rp, w('bCs'))
c = etree.SubElement(rp, w('color')); c.set(w('val'), '365F91'); c.set(w('themeColor'), 'accent1'); c.set(w('themeShade'), 'BF')
for tag in ('sz', 'szCs'): s = etree.SubElement(rp, w(tag)); s.set(w('val'), '28')
t = etree.SubElement(r, w('t')); t.text = 'Accompanying MATLAB file(s):'
for e in inline('  `UR_PickPlace_Lab.m`, `check_waypoints.p`'): p.append(e)
add(p)

# ---------------------------------------------------------------- overview, objectives
H1('Overview')
P('In this lab you will program a UR e-series robot to pick up a cube and place it at a second location. You will do it twice: first with a program built on the Teach Pendant, and then from MATLAB over the RTDE connection that you set up in Lab 2.')
P('The overall objective is to record one set of waypoints, run the same task with both methods, and compare the two workflows.')
H1('Learning Objectives')
B('Design a waypoint sequence for a pick-and-place task, including the approach and retract points, and record it with the Teach Pendant.')
B('Build and safely test a pick-and-place program on the Teach Pendant using joint moves (MoveJ), linear moves (MoveL) and gripper commands.')
B('Run the same sequence from MATLAB over RTDE, after verifying the connection against the Teach Pendant readout.')
B('Compare the two workflows and justify which one fits a given automation task.')

# ---------------------------------------------------------------- background
H1('Background: Move Types and Approach Waypoints')
P('Every waypoint in this lab is recorded as six joint angles in degrees, in order from joint 1 (base) to joint 6 (wrist 3), exactly as the Teach Pendant displays them. These are the hardware angles `theta_hw` of Lab 3.')
P('The robot can travel between two waypoints in two ways. A **joint move** (MoveJ; the Joint Move node on the Teach Pendant) turns all six joints together so that they finish at the same time. It is the fastest way to travel, but the TCP follows a curved path. A **linear move** (MoveL; the Linear Move node) drives the TCP along a straight line. It is used for the short vertical moves down onto the cube and back up.')
P('A pick-and-place task therefore uses **approach waypoints**. The gripper first moves to a point directly above the cube, descends straight down, grips, and rises straight back up before it travels sideways. Without the approach waypoints the gripper would sweep in at an angle and push the cube or hit the table.')
P('`UR_PickPlace_Lab.m` uses the functions you ran in Lab 2 and requires the same server script to be running on the robot. Table 1 lists only what is new in this lab.')
table('Table 1', 'MATLAB functions and options that are new in this lab', [4320, 4320], [
    ['Function', 'What is new'],
    ['`ur = urRTDEClient(robotIP, \'CobotName\', \'universalUR3e\')`', '`CobotName` names the robot model, so that MATLAB uses the dimensions of your robot.'],
    ['`sendJointConfigurationAndWait(ur, q, EndTime = t)`', '`EndTime` schedules the move to take `t` seconds.'],
    ['`pose = readCartesianPose(ur)`', 'Returns a 1x6 vector: three orientation angles in radians, then the X, Y, Z position of the tool flange in meters (elements 4 to 6).'],
    ['`actuateGripper(ur, \'grip\')` and `actuateGripper(ur, \'release\')`', 'Closes or opens the Robotiq gripper.'],
])
P('You enter and read every angle in degrees. The script converts to and from radians.')

# ---------------------------------------------------------------- setup
H1('Before You Start')
B('The robot is powered on with the brakes released, and the gripper TCP and payload are set as in Lab 1. The cube is light, so the payload stays unchanged.')
B('The Lab 2 program that contains the Script Code node `URServerScript_Robotiq2F_PolyScopeX.script` is saved on the robot, and the PC is connected to the robot as in Lab 2 (robot IP address 192.168.1.10).')
B('You have one cube and two tape marks on the table, the pick location and the place location, both within easy reach of the robot.')
B('`UR_PickPlace_Lab.m` is in the current folder of MATLAB.')
P('⚠️ The robot moves under program control in this lab. Keep everyone outside the reach of the arm while a program runs, keep one hand near the e-stop, make the first run of the Teach Pendant program at 10% speed, and make the first MATLAB run at 25%.')

# ---------------------------------------------------------------- part 1
H1('Part 1 - Define the Waypoints')
P('The task uses the six waypoints of Table 2. The robot visits them in this order: Ready, Pre-Pick, Pick (close the gripper), Retract, Pre-Place, Place (open the gripper), Pre-Place, Ready. The gripper is also opened once at Ready, before the first approach.')
table('Table 2', 'Waypoint definitions and the Teach Pendant node used to reach each one', [1300, 1500, 5840], [
    ['Waypoint', 'Node', 'Definition'],
    ['Ready', 'Joint Move', 'The start and end pose, chosen by you: shoulder and elbow bent, tool flange facing down, gripper well above the table (Figure 1).'],
    ['Pre-Pick', 'Joint Move', 'The approach point: directly above the cube, 5 to 10 cm higher than Pick, with the same gripper orientation.'],
    ['Pick', 'Linear Move', 'The open gripper fingers are on either side of the cube, just above the table. The gripper closes here.'],
    ['Retract', 'Linear Move', 'Straight back up from Pick with the cube. This is the same pose as Pre-Pick, so it takes the same values.'],
    ['Pre-Place', 'Joint Move', 'The approach point directly above the place location, 5 to 10 cm higher than Place.'],
    ['Place', 'Linear Move', 'The cube rests on the place location. The gripper opens here.'],
])
FIGDATA = figure(FIG, 'rId23', 5.0, 'Figure 1', 'An example ready position, seen from the side: shoulder and elbow bent, tool flange facing down. The Teach Pendant joint angles of this pose are [0, −80, −80, −110, 90, 0] degrees.')
H2('Task 1: Record and Store the Waypoints')
P('You will write each pose in Table 3 for MATLAB and, while the robot is still there, store it as a node of a Teach Pendant program for Part 2.')
steps(
    'Set the speed slider to 25%. Tap the program name at the top of the screen, tap + Program, choose Create New Program, name it after your group, for example `Lab4_Group1`, and tap Confirm. Do not edit the Lab 2 program that holds the server script; you need it unchanged in Part 3.',
    'On the Move screen, set Relative To to base and check that Active TCP is your gripper TCP. Then open the Joints tab and jog the joints to a ready position of your choosing that looks like Figure 1, with the gripper at least 15 cm above the table. The tool flange faces straight down when joint 5 reads 90 and joints 2, 3 and 4 add up to −270, for example −80, −80 and −110.',
    'Record the ready position in Table 3: the six joint angles in degrees and the TCP position X, Y, Z in millimeters, both read from the Move screen.',
    'Store it in your program: tap + in the program tree and add a Joint Move node. Tap its Name field, type `Ready` and tap Confirm. Then tap Edit Point and, with the robot still at the pose, tap Save. Record and store every pose below in the same way, using the node type listed in Table 2. Node names take only letters, digits and underscores, so use `Pick`, `Pre_Pick`, `Place` and `Pre_Place`.',
    'Open the Robotiq gripper screen that the URCap adds to the Teach Pendant, activate the gripper (tap Scan if it is not detected) and open it. Put the cube on one of the two tape marks; that mark is the pick location.',
    'From here on jog only with the plus-minus buttons of X, Y and Z on the Move tab, so that the gripper keeps pointing straight down. Jog until the open fingers are on either side of the cube and about 5 mm above the table, turning the cube if needed so that the fingers close on two flat faces. Close the gripper once to confirm the grasp, then open it again. Record and store this pose as Pick.',
    'Jog straight up along Z by 5 to 10 cm. Record and store this pose as Pre-Pick, and copy its values into the Retract row.',
    'Jog along X and Y until the gripper is above the place mark, then jog down to the Z of Pick. Record and store this pose as Place. Jog straight up by 5 to 10 cm, then record and store Pre-Place.',
    'Check Table 3: Pre-Pick must have the same X and Y as Pick to within about 2 mm, and Pre-Place the same X and Y as Place.',
)
J = ['Joint %d (deg)' % k for k in range(1, 7)]
table('Table 3', 'Recorded waypoints: joint angles and TCP position from the Teach Pendant', [1140] + [800] * 6 + [900] * 3,
      [['Waypoint'] + J + ['X (mm)', 'Y (mm)', 'Z (mm)']] +
      [[n] + [''] * 9 for n in ('Ready', 'Pre-Pick', 'Pick', 'Retract', 'Pre-Place', 'Place')])

# ---------------------------------------------------------------- part 2
H1('Part 2 - Teach Pendant Program')
P('The finished program has the eleven nodes listed below: the Joint Move and Linear Move nodes that you stored in Task 1, three more move nodes that reuse stored poses, and three Robotiq Gripper nodes, which the URCap adds to the list of nodes under URCaps. If no gripper node appears in the list, ask your instructor to check that the URCap is installed.')
H2('Task 2: Build the Program')
steps(
    'Use the Move up and Move down icons to put your five stored nodes in the order of the list below.',
    'Add the three missing move nodes: Retract (Linear Move), the second Pre-Place (Linear Move) and the second Ready (Joint Move). For each one, tap its Name field, open the Variable tab, select the pose already stored (`Pre_Pick` for Retract, `Pre_Place`, `Ready`) and tap Confirm. The node then moves to that stored pose.',
    'Add the three Robotiq Gripper nodes and set each one to open or close as listed.',
    'Save the program: tap the program name, tap your program, tap the save icon and choose Save.',
)
P('The eleven nodes of the program:')
steps(
    'Joint Move to Ready',
    'Gripper: open',
    'Joint Move to Pre-Pick',
    'Linear Move to Pick',
    'Gripper: close',
    'Linear Move to Retract',
    'Joint Move to Pre-Place',
    'Linear Move to Place',
    'Gripper: open',
    'Linear Move to Pre-Place',
    'Joint Move to Ready',
)
P('The long moves between Ready, Pre-Pick and Pre-Place are joint moves because the shape of the path does not matter there. The four short moves next to the cube are linear so that the gripper travels vertically.')
H2('Task 3: Test the Program')
steps(
    'Put the cube on the pick mark. Do this before every run.',
    'Set the speed slider to 10% and press Play. The robot first moves to Ready, the first node, then runs the program once and stops. Keep your hand near the e-stop and watch every move.',
    'If the gripper misses the cube or touches the table, stop the program, tap Edit Point on that node, jog to the corrected pose and tap Save. Update that row of Table 3 (and the Retract row if you changed Pre-Pick). Then run again at 10%.',
    'When the whole sequence works at 10%, run it again at 50%.',
    'At 50%, time one full cycle with a stopwatch, from pressing Play until the robot is back at Ready. Record the time, the pick success and the place accuracy in Table 5.',
)
P('Record your observations:')
B('Did the robot pick up and place the cube? (Y/N): ___')
B('How many test runs did it take to get the sequence working? ___')
B('Which waypoints did you have to adjust, and why?')

# ---------------------------------------------------------------- part 3
H1('Part 3 - MATLAB RTDE Program')
P('`UR_PickPlace_Lab.m` runs the same eleven steps from MATLAB. It connects to the robot, prints the current joint angles, and then moves through the waypoints you type into it. All of its moves are joint moves, and it opens and closes the gripper through the server script. Three safeguards are built in. Each waypoint starts as `NaN`, and the script stops before any motion while a `NaN` remains. It then runs `check_waypoints.p`, which computes where each waypoint puts the gripper and prints PASS or FAIL for eight checks, for example that Pre-Pick is directly above Pick and that the gripper points straight down. The robot does not move while any check fails. Finally the script asks you to type `yes` before the robot moves.')
H2('Task 4: Connect and Verify')
steps(
    'On the Teach Pendant, save your program. Then tap the program name, tap a Lab 2 program that contains the Script Code node `URServerScript_Robotiq2F_PolyScopeX.script` (any group\'s copy works), tap Open, and press Play. The node must turn green.',
    'In MATLAB, open `UR_PickPlace_Lab.m` and find the section labeled TASK 4. Check that `robotIP` is the IP address of your robot (`"192.168.1.10"`) and that `cobotName` matches your robot model: `\'universalUR3e\'` for a UR3e, `\'universalUR5e\'` for a UR5e, and so on.',
    'Type `UR_PickPlace_Lab` in the Command Window and press Enter. The script prints the connection readout and then stops, because the waypoints are still `NaN`. The robot does not move.',
    'Copy the six joint angles from the line "Joint angles (deg)" into the MATLAB row of Table 4. Read the same six angles from the Move screen of the Teach Pendant into the first row, and compute the difference.',
)
table('Table 4', 'Joint angle readout comparison (degrees)', [1920] + [1120] * 6, [
    ['Source', 'Joint 1', 'Joint 2', 'Joint 3', 'Joint 4', 'Joint 5', 'Joint 6'],
    ['Teach Pendant'] + [''] * 6, ['MATLAB'] + [''] * 6, ['Difference'] + [''] * 6])
P('The two rows should agree to within 0.1 degrees. If they do not, make sure the robot did not move between the two readings. If MATLAB reports a connection error, recheck the cable and the IP address, as in Lab 2. The readout also prints a position line. It is the position of the tool flange computed by MATLAB, in meters, so it differs from the TCP position on the Teach Pendant by the length of the gripper. Compare the joint angles only.')
H2('Task 5: Enter the Waypoints and Run')
steps(
    'In `UR_PickPlace_Lab.m`, find the section labeled TASK 5. Replace each `nan(1,6)` with the six joint angles of that waypoint from Table 3, in degrees and in order from joint 1 to joint 6. For example: `pick_pos = [35.20 -98.41 -112.63 -59.02 90.05 35.11];`. Fill in all six waypoints (`ready_pos`, `pre_pick_pos`, `pick_pos`, `retract_pos`, `pre_place_pos`, `place_pos`) and save the file.',
    'Leave `moveEndTime = 5` unchanged. It is the time in seconds scheduled for each move when the speed slider is at 100%.',
    'Put the cube on the pick mark, as before every run, and check that the server script node is green. The script opens the gripper itself after it reaches Ready.',
    'Set the speed slider to 25% and do not touch it while the script runs. At 25% each move takes about 20 seconds, so the full sequence takes about 3 minutes.',
    'Run `UR_PickPlace_Lab` again and read the waypoint check that it prints. If any line shows FAIL, the robot will not move: correct the waypoint that the line names, in the script and in Table 3, and run again. If the pose itself is wrong, store it again on the Teach Pendant as in Task 3.',
    'When all eight checks pass, confirm that the printed joint angles match the Move screen, then type `yes` and press Enter. Any other answer cancels the run. Keep your hand near the e-stop and watch every move. The script prints each of its eleven steps as it starts.',
    'To stop a run early without the e-stop, stop the program on the Teach Pendant, as in the Lab 2 checkpoint. MATLAB then ends with an error within about a minute.',
    'When the sequence works at 25%, set the slider to 50% and run it once more (about 1.5 minutes). The script prints the total cycle time when it finishes. Record it in Table 5.',
)
P('If the script stops with an error:')
B('"Robot did not reach ...": the server script is not running, the robot is in a protective stop, or the speed slider is below 10%. Clear the stop on the Teach Pendant, press Play so that the node is green again, and rerun the script.')
B('Before you rerun: if the robot stopped at Pick or Place, jog straight up clear of the table first, because the first move of the script goes directly to Ready. If the gripper still holds the cube, the script releases it at Ready: catch it and put it back on the pick mark.')
B('If the arm moves but the gripper does not, the program on the Teach Pendant is not the Robotiq server script of Lab 2. Load the correct program.')
H2('Task 6: Compare the Two Methods')
P('Fill in Table 5 from your runs at 50% speed. The MATLAB cycle time is set mostly by `moveEndTime`, because every move is scheduled to take that long however short it is. Keep this in mind when you compare the two times. Rate the place accuracy as good if the cube lands within about 2 mm of the mark, fair within 5 mm, and poor otherwise.')
table('Table 5', 'Teach Pendant program compared with the MATLAB program', [4320, 2160, 2160], [
    ['Metric', 'Teach Pendant', 'MATLAB RTDE'],
    ['Total cycle time at 50% speed (seconds)', '', ''],
    ['Pick success (Y/N)', '', ''],
    ['Place accuracy (good / fair / poor)', '', ''],
    ['Ease of programming (1 = easy, 5 = difficult)', '', ''],
    ['Ease of modification (1 = easy, 5 = difficult)', '', ''],
])

P('When you finish, stop the program on the Teach Pendant, jog the robot to your ready position, and power down as in Lab 2, Part 7.')

# ---------------------------------------------------------------- assessment
H1('Assessment Questions')
for q in (
    'Q1.  What is the difference between MoveJ and MoveL? When would you prefer one over the other? Give an example of each from this lab. The MATLAB script used joint moves only: why was that acceptable for the short moves near the cube?',
    'Q2.  Why do we use approach waypoints (Pre-Pick and Pre-Place) instead of moving directly from Ready to Pick? What could go wrong without them?',
    'Q3.  Compare programming the task on the Teach Pendant with programming it in MATLAB. Give two advantages and two disadvantages of each method.',
    'Q4.  Suppose the pick location moves to a new spot on the table. Describe the steps needed to update (a) the Teach Pendant program and (b) the MATLAB program. Which is faster to modify?',
    'Q5.  In industry a robot may need to pick objects whose location changes, for example from a conveyor belt. Which method is better suited to this, and why? What sensor would you add, and how would the RTDE method make that easier?',
):
    P(q)

# ---------------------------------------------------------------- header / footer from Lab 3
for kind, rid in (('header', 'rId21'), ('footer', 'rId22')):
    r = etree.SubElement(rels, '{%s}Relationship' % PR)
    r.set('Id', rid); r.set('Type', R + '/' + kind); r.set('Target', kind + '1.xml')
    o = etree.SubElement(ctypes, '{%s}Override' % CT)
    o.set('PartName', '/word/%s1.xml' % kind)
    o.set('ContentType', 'application/vnd.openxmlformats-officedocument.wordprocessingml.%s+xml' % kind)
for k, (kind, rid) in enumerate((('header', 'rId21'), ('footer', 'rId22'))):
    e = etree.Element(w(kind + 'Reference')); e.set(w('type'), 'default'); e.set('{%s}id' % R, rid)
    sect.insert(k, e)

hdr = b'<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
new = {'word/document.xml': doc, 'word/_rels/document.xml.rels': rels, '[Content_Types].xml': ctypes, 'word/numbering.xml': numx}
zout = zipfile.ZipFile(OUT, 'w', zipfile.ZIP_DEFLATED)
for info in zin.infolist():
    data = zin.read(info.filename)
    if info.filename in new: data = hdr + etree.tostring(new[info.filename], encoding='UTF-8')
    zout.writestr(info.filename, data)
for kind in ('header', 'footer'):
    zout.writestr('word/%s1.xml' % kind, z3.read('word/%s1.xml' % kind))
zout.writestr('word/media/image1.png', FIGDATA)
zout.close(); print('wrote', OUT)
