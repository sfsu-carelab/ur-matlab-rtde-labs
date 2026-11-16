"""Build Lab 4 manual Rev3 from Rev2 as last saved by Dr. Quintero on Box (2026-11-13 22:31).
Targeted edits for his Rev2 feedback; paragraphs that are not named here keep his wording.
usage: build_lab4_rev3.py <prof Rev2 docx> <out docx>   (needs dx.py)"""
import copy, sys, zipfile
from lxml import etree
from dx import *

SRC, OUT = sys.argv[1], sys.argv[2]
zin = zipfile.ZipFile(SRC)
doc = etree.fromstring(zin.read('word/document.xml'))
numx = etree.fromstring(zin.read('word/numbering.xml'))
body = doc.find('w:body', ns)

def find(prefix, nth=None, scope=None):
    hits = [p for p in (scope if scope is not None else body).iter(w('p')) if text_of(p).startswith(prefix)]
    assert hits, ('not found', prefix)
    assert nth is not None or len(hits) == 1, ('ambiguous', prefix, len(hits))
    return hits[nth or 0]
def like(ref, markup):
    """New paragraph with the same paragraph properties (style, list) as ref."""
    p = etree.Element(w('p'))
    if ref.find(w('pPr')) is not None: p.append(copy.deepcopy(ref.find(w('pPr'))))
    for e in inline(markup): p.append(e)
    return p
def after(ref, *els):
    for e in reversed(els): ref.addnext(e)
def before(ref, *els):
    for e in els: ref.addprevious(e)
def append(p, markup):
    for e in inline(markup): p.append(e)
def table_after(p):
    e = p.getnext()
    while e.tag != w('tbl'): e = e.getnext()
    return e
def row(widths, cells):
    tr = etree.Element(w('tr'))
    for x, c in zip(widths, cells):
        tc = etree.SubElement(tr, w('tc')); tp = etree.SubElement(tc, w('tcPr'))
        cw = etree.SubElement(tp, w('tcW')); cw.set(w('w'), str(x)); cw.set(w('type'), 'dxa')
        tc.append(para(c))
    return tr
def newlist():
    nid = max(int(n.get(w('numId'))) for n in numx.findall('w:num', ns)) + 1
    n = etree.SubElement(numx, w('num')); n.set(w('numId'), str(nid))
    a = etree.SubElement(n, w('abstractNumId')); a.set(w('val'), '7')
    o = etree.SubElement(n, w('lvlOverride')); o.set(w('ilvl'), '0')
    s = etree.SubElement(o, w('startOverride')); s.set(w('val'), '1')
    return nid

SCRIPT = '`URServerScript_Robotiq2F_PolyScopeX.script`'

# ---- title block and setup: the lab folder is self-contained
append(find('Accompanying MATLAB file(s):'), ', ' + SCRIPT + ' (runs on the robot)')
t1 = table_after(find('Table 1:'))
t1.append(row([4320, 4320], ['`t0 = tic` and `cycleTime = toc(t0)`', 'The MATLAB stopwatch. `tic` starts a timer and `toc(t0)` returns the seconds elapsed since then. The script uses the pair to measure the cycle time.']))
setpar(find('The Lab 2 program that contains'), 'A program that contains the Script Code node ' + SCRIPT + ' is saved on the robot (the server program made in Lab 2). If it is missing, Task 4 shows how to rebuild it from the copy of the script in the Lab 4 folder. The PC is connected to the robot by Ethernet (robot IP address 192.168.1.10).')
setpar(find('UR_PickPlace_Lab.m is in the current folder'), 'The Lab 4 folder holds every file this lab needs: `UR_PickPlace_Lab.m`, `check_waypoints.p` and ' + SCRIPT + '. Make it the current folder of MATLAB.')

# ---- Ready position: required angles stated outright
t2 = table_after(find('Table 2:'))
setpar(find('The start and end pose', scope=t2), 'The start and end pose (Figure 1). Joints 2 to 6 must read −80, −80, −110, 90 and 0 degrees. Joint 1 is chosen by you.')
old = find('Figure 1:')
old.addnext(caption('Figure 1', 'The Ready position (side view): shoulder and elbow bent, tool flange facing down. Joints 2 to 6 read −80, −80, −110, 90 and 0 degrees. Joint 1 (base) is your choice.'))
body.remove(old)
setpar(find('On the Move screen, set Relative To'), 'On the Move screen, set Relative To to base and check that Active TCP is your robot gripper TCP. Open the Joints tab and set joints 2 to 6 to exactly −80, −80, −110, 90 and 0 degrees, the Ready position of Figure 1. For each joint, tap its value field, type the target and tap Confirm. Then tap Move Here and hold Move to Position until the robot stops. The plus-minus buttons work as well. These five angles are required: they make the tool flange face straight down, which every later step relies on and `check_waypoints.p` verifies. Joint 1 (base) is the only free choice: turn it until the gripper is over the area between the two tape marks.')

# ---- Part 2: Timer nodes, consistent names
setpar(find('The finished program has the eleven nodes'), 'The finished program has the fourteen nodes listed below: the Joint Move and Linear Move nodes that you stored in Task 1, three more move nodes that reuse stored poses, three Robotiq Gripper nodes, which the URCap adds to the list of nodes under URCaps, and three Timer nodes that measure the cycle time. If no gripper node appears in the list, ask your instructor to check that the URCap is installed.')
g = find('Add the three Robotiq Gripper nodes')
after(g, like(g, 'Add the three Timer nodes at the places listed. For the first one, tap its Variable field, tap Rename, type `cycle_time` and tap Confirm, then set its Action field to Reset. The other two use the same variable, with the Action set to Start and to Pause.'))
setpar(find('The eleven nodes of the program:'), 'The fourteen nodes of the program:')
open1 = find('Gripper: open', nth=0)
after(open1, like(open1, 'Timer `cycle_time`: Reset'), like(open1, 'Timer `cycle_time`: Start'))
last = find('Joint Move to Ready', nth=1)
after(last, like(last, 'Timer `cycle_time`: Pause'))
setpar(find('Joint Move to Pre-Pick'), 'Joint Move to Pre_Pick')
setpar(find('Joint Move to Pre-Place'), 'Joint Move to Pre_Place')
setpar(find('Linear Move to Pre-Place'), 'Linear Move to Pre_Place')
append(find('The long moves between Ready'), ' The timer measures one cycle: it starts when the robot is at Ready with the gripper open and pauses when the robot is back at Ready. The MATLAB script times exactly the same interval, so the two cycle times in Table 5 can be compared.')
setpar(find('At 50%, time one full cycle'), 'At 50%, time one full cycle with the Timer nodes in the Teach Pendant program. When the program has stopped, tap Global Variables in the sidebar and read `cycle_time`, the seconds from Ready with the gripper open until the robot is back at Ready. Record the time, the pick success and the place accuracy in Table 5.')

# ---- Part 3 intro
setpar(find('UR_PickPlace_Lab.m runs the same eleven steps'), '`UR_PickPlace_Lab.m` runs the same eleven motion and gripper steps from MATLAB and times the same cycle with `tic` and `toc`. It connects to the robot, prints the current joint angles, and then moves through the waypoints you type into it. All of its moves are joint moves, and it opens and closes the gripper through the server script. Everything the script reports is printed in the MATLAB Command Window. Three safeguards are built in. Each waypoint starts as `NaN`, and the script stops before any motion while a `NaN` remains. It then runs `check_waypoints.p`, which computes where each waypoint puts the gripper and prints PASS or FAIL for eight checks, for example that Pre_Pick is directly above Pick and that the gripper points straight down. The robot does not move while any check fails. Finally the script asks you to type `yes` before the robot moves.')

# ---- Task 4
s1 = find('On the Teach Pendant, save your program.')
before(s1, like(s1, 'Leave the robot at your Ready position. Nothing moves in this task, and the comparison below is made at that pose.'))
setpar(s1, 'On the Teach Pendant, save your program. Then tap the program name, tap a program that contains the Script Code node ' + SCRIPT + ' (any group\'s copy works), tap Open, and press Play. The node must turn Green. If the robot has no such program, create a new one, tap +, add a Script Code node (not a Script node), tap Select File and choose the script from a USB drive that holds the copy from the Lab 4 folder.')
setpar(find('Copy the six joint angles from the line'), 'From the readout in the Command Window, copy the six angles of the line "Joint angles (deg)" and the three values of the line "Flange position (mm)" into the MATLAB row of Table 4. Read the six joint angles and the TCP position X, Y, Z from the Move screen of the Teach Pendant into the first row, and compute the differences.')
cap4 = find('Table 4:')
t4 = table_after(cap4)
cap4.addnext(caption('Table 4', 'Readout comparison at the Ready position: joint angles in degrees and position in millimeters'))
body.remove(cap4)
W4 = [1440] + [750] * 6 + [900] * 3
for g_ in list(t4.find(w('tblGrid'))): t4.find(w('tblGrid')).remove(g_)
for x in W4: c = etree.SubElement(t4.find(w('tblGrid')), w('gridCol')); c.set(w('w'), str(x))
for tr in t4.findall(w('tr')): t4.remove(tr)
t4.append(row(W4, ['Source'] + ['Joint %d' % k for k in range(1, 7)] + ['X', 'Y', 'Z']))
for name in ('Teach Pendant', 'MATLAB', 'Difference'): t4.append(row(W4, [name] + [''] * 9))
setpar(find('The two rows should agree to within 0.1 degrees.'), 'Table 4 is the proof, before anything moves, that MATLAB is connected to this robot and reads its joints in the same order and units as the Teach Pendant. The joint angles should agree to within 0.1 degrees; the small difference is rounding. If they do not agree, make sure the robot did not move between the two readings. The positions are expected to differ in one way: MATLAB reports the tool flange and the Teach Pendant reports the TCP. Because the tool points straight down at Ready, X and Y should agree to within about 2 mm, and the MATLAB Z should be higher by the Z offset of the gripper TCP that you set in Lab 1 (the length of the gripper). If MATLAB reports a connection error instead of a readout, recheck the Ethernet cable and that `ping 192.168.1.10` answers in a Windows Command Prompt.')

# ---- Task 5
setpar(find('Leave moveEndTime = 5 unchanged.'), 'Leave `moveEndTime = 3` unchanged. The script schedules every move by time, not by speed: at a 100% speed slider each move takes `moveEndTime` seconds, however short it is, and a lower slider stretches it (6 seconds at 50%, 12 seconds at 25%). Timed moves are slow and predictable, which suits a first program.')
setpar(find('Set the speed slider to 25% and do not touch'), 'Set the speed slider to 25% for the first run, so that typed waypoints are tried slowly (about 12 seconds per move, under 2 minutes in total). Do not touch the slider while the script runs: the script waits for each move for the time that the slider implies.')
setpar(find('Run UR_PickPlace_Lab again and read'), 'Run `UR_PickPlace_Lab` again and read the waypoint check that it prints in the MATLAB Command Window: eight numbered lines, each ending in PASS or FAIL, with the measured value below it. If any line shows FAIL, the robot will not move: correct the waypoint that the line names, in the script and in Table 3, and run again. If the pose itself is wrong, store it again on the Teach Pendant as in Task 3.')
setpar(find('When all eight checks pass'), 'When the Command Window shows ALL CHECKS PASS, confirm that the joint angles printed above the check match the Move screen, then type `yes` in the Command Window and press Enter. Any other answer cancels the run. Keep your hand near the e-stop and watch every move. The Command Window lists each of the eleven steps as it starts.')
setpar(find('To stop a run early without the e-stop'), 'To stop a run early without the e-stop, stop the program on the Teach Pendant. MATLAB then ends with an error within about a minute.')
setpar(find('When the sequence works at 25%'), 'When the sequence works at 25%, set the slider to 50% and run it once more (6 seconds per move, about 1 minute). When it finishes, the Command Window prints the cycle time. It is measured with `tic` and `toc` over the same interval as the Timer nodes of Task 3: from Ready with the gripper open until the robot is back at Ready. Record it in Table 5.')
setpar(find('If the arm moves but the gripper does not'), 'If the arm moves but the gripper does not, the program playing on the Teach Pendant is not the Robotiq server program. Load the correct program (Task 4, step 2).')

# ---- Task 6 and closing
t5 = table_after(find('Table 5:'))
setpar(find('Total cycle time at 50% speed', scope=t5), 'Cycle time at 50% speed, Ready to Ready (seconds)')
end = find('When you finish, stop the program')
setpar(end, 'When you finish, power down the robot:')
nid = newlist()
after(end,
      para('Stop the program on the Teach Pendant.', style='ListNumber', numid=nid),
      para('Jog the robot to your Ready position.', style='ListNumber', numid=nid),
      para('Tap the Robot State icon at the left of the footer and power off the robot arm.', style='ListNumber', numid=nid),
      para('Press the power button on the Teach Pendant. If a Shutdown dialog appears, tap Power Off.', style='ListNumber', numid=nid))

# ---- Assessment: questions answerable from what the lab had students do
setpar(find('Q3.'), 'Q3.  In this lab the same waypoints, taught once on the Teach Pendant, were run by two programs. Compare the two programs as you experienced them: give two advantages and two disadvantages of each, using your observations (building and testing effort, cycle time in Table 5, place accuracy, what happened when something went wrong).')
setpar(find('Q4.'), 'Q4.  Suppose the pick mark is moved 10 cm to the side. List the steps of this lab that you would repeat to update (a) the Teach Pendant program and (b) the MATLAB program. Which steps are the same for both, and why does the MATLAB program still depend on the Teach Pendant?')
setpar(find('Q5.'), 'Q5.  In the MATLAB program each waypoint is a variable, for example `pick_pos`, that you typed in by hand. If a camera reported where the cube is, which waypoints would have to change, and which could stay as taught? Explain why replacing a typed value by a computed one is simpler in the MATLAB program than in the Teach Pendant program.')

hdr = b'<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
new = {'word/document.xml': doc, 'word/numbering.xml': numx}
zout = zipfile.ZipFile(OUT, 'w', zipfile.ZIP_DEFLATED)
for info in zin.infolist():
    data = zin.read(info.filename)
    if info.filename in new: data = hdr + etree.tostring(new[info.filename], encoding='UTF-8')
    zout.writestr(info, data)
zout.close(); print('wrote', OUT)
