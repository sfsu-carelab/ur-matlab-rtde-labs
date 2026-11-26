"""Build the Lab 5 manual Rev3 on the Lab 4 Rev5 template (styles, header, footer, numbering).
The body is written from scratch here; figures come from make_lab5_figures.py.
usage: build_lab5_rev3.py <Lab 4 Rev5 docx> <figure dir> <out docx>   (needs dx.py)"""
import copy, struct, sys, zipfile
from lxml import etree
from dx import *

SRC, FIGS, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
zin = zipfile.ZipFile(SRC)
doc = etree.fromstring(zin.read('word/document.xml'))
numx = etree.fromstring(zin.read('word/numbering.xml'))
rels = etree.fromstring(zin.read('word/_rels/document.xml.rels'))
body = doc.find('w:body', ns)
kids = list(body)

# ---- exemplars taken from the template before the body is emptied
ex_title = next(p for p in kids if p.find('w:pPr/w:pStyle', ns) is not None and p.find('w:pPr/w:pStyle', ns).get(w('val')) == 'Title')
ex_sub, ex_files = kids[1], kids[2]
ex_tbl = next(e for e in kids if e.tag == w('tbl'))
ex_pic = next(p for p in kids if p.tag == w('p') and p.find('.//' + w('drawing')) is not None)
sect = kids[-1]
for e in kids[:-1]: body.remove(e)
for r in list(rels):                       # the template's own picture is not used
    if r.get('Target') == 'media/image1.png': rels.remove(r)

out = []                                   # new body, in order
def add(*els):
    out.extend(els)
def P(markup, **k): add(para(markup, **k))
def H1(text): add(para(text, style='Heading1'))
def H2(text): add(para(text, style='Heading2'))
def bullets(*items):
    for s in items: add(para(s, style='ListBullet'))
def newlist():
    nid = max(int(n.get(w('numId'))) for n in numx.findall('w:num', ns)) + 1
    n = etree.SubElement(numx, w('num')); n.set(w('numId'), str(nid))
    a = etree.SubElement(n, w('abstractNumId')); a.set(w('val'), '7')
    o = etree.SubElement(n, w('lvlOverride')); o.set(w('ilvl'), '0')
    s = etree.SubElement(o, w('startOverride')); s.set(w('val'), '1')
    return nid
def steps(*items):
    """A numbered list that restarts at 1. An item may be (text, [code lines]) to put code under a step."""
    nid = newlist()
    for s in items:
        if isinstance(s, tuple):
            add(para(s[0], style='ListNumber', numid=nid))
            for c in s[1]: add(codeline(c, indent=720))
            if len(s) > 2: add(para(s[2], ind=720))
        else:
            add(para(s, style='ListNumber', numid=nid))

_para = para
def para(markup, style=None, jc=None, numid=None, kind='', ind=None):
    p = _para(markup, style=style, jc=jc, numid=numid, kind=kind)
    if ind:
        pr = p.find(w('pPr'))
        if pr is None: pr = etree.Element(w('pPr')); p.insert(0, pr)
        i = etree.SubElement(pr, w('ind')); i.set(w('left'), str(ind))
    return p
_codeline = codeline
def codeline(text, indent=None):
    p = _codeline(text)
    pr = etree.Element(w('pPr')); p.insert(0, pr)
    sp = etree.SubElement(pr, w('spacing')); sp.set(w('after'), '0')
    if indent: i = etree.SubElement(pr, w('ind')); i.set(w('left'), str(indent))
    return p
def code(*lines, indent=None):
    for c in lines: add(codeline(c, indent))
    add(_para(''))

def table(label, text, widths, header, rows, small=False):
    """Caption above the table (Lab 3 and Lab 4 style), LightGrid-Accent1 like the template."""
    add(caption(label, text))
    t = etree.Element(w('tbl')); t.append(copy.deepcopy(ex_tbl.find(w('tblPr'))))
    g = etree.SubElement(t, w('tblGrid'))
    for x in widths: c = etree.SubElement(g, w('gridCol')); c.set(w('w'), str(x))
    for r, cells in enumerate([header] + rows):
        tr = etree.SubElement(t, w('tr'))
        if r == 0:
            trp = etree.SubElement(tr, w('trPr')); c = etree.SubElement(trp, w('cnfStyle')); c.set(w('val'), '100000000000')
        for k, (x, cell) in enumerate(zip(widths, cells)):
            tc = etree.SubElement(tr, w('tc')); tp = etree.SubElement(tc, w('tcPr'))
            if k == 0: c = etree.SubElement(tp, w('cnfStyle')); c.set(w('val'), '001000000000')
            cw = etree.SubElement(tp, w('tcW')); cw.set(w('w'), str(x)); cw.set(w('type'), 'dxa')
            tc.append(_para(cell, kind='c' if small else ''))
    add(t, _para(''))

_img = [0]
media = {}
def figure(fname, label, text, width_in=6.0):
    _img[0] += 1; k = _img[0]
    data = open(f'{FIGS}/{fname}', 'rb').read()
    wpx, hpx = struct.unpack('>II', data[16:24])
    cx = int(width_in * 914400); cy = int(cx * hpx / wpx)
    rid = f'rId{100 + k}'; name = f'image{k}.png'
    media[f'word/media/{name}'] = data
    r = etree.SubElement(rels, '{http://schemas.openxmlformats.org/package/2006/relationships}Relationship')
    r.set('Id', rid); r.set('Type', 'http://schemas.openxmlformats.org/officeDocument/2006/relationships/image'); r.set('Target', f'media/{name}')
    p = copy.deepcopy(ex_pic)
    for br in p.iter(w('lastRenderedPageBreak')): br.getparent().remove(br)
    for el in p.iter():
        if el.tag.endswith('}extent') or el.tag.endswith('}ext'):
            if el.get('cx'): el.set('cx', str(cx)); el.set('cy', str(cy))
        if el.tag.endswith('}docPr'): el.set('id', str(k)); el.set('name', f'Picture {k}'); el.set('descr', text[:250])
        if el.tag.endswith('}cNvPr'): el.set('name', name)
        if el.tag.endswith('}blip'): el.set('{http://schemas.openxmlformats.org/officeDocument/2006/relationships}embed', rid)
        for a in list(el.attrib):
            if a.endswith('}anchorId') or a.endswith('}editId'): del el.attrib[a]
    pr = p.find(w('pPr')); kn = etree.SubElement(pr, w('keepNext'))
    add(p, caption(label, text))

SERVER = '`URServerScript_Robotiq2F_PolyScopeX.script`'

# =====================================================================================  TITLE BLOCK
t = copy.deepcopy(ex_title); setpar(t, 'Lab 5'); add(t)
s = copy.deepcopy(ex_sub); s.find('.//' + w('t')).text = 'Vision-Guided Pick-and-Place with Colored Blocks'; add(s)
f = copy.deepcopy(ex_files)
head = f.findall(w('r'))[0]
for c in f.findall(w('r'))[1:]: f.remove(c)
for e in inline('  `UR_VisionPick_Lab.m`, `UR_CalibrateCamera.m`, `capture_realsense.m`, `detect_block.m`, `fit_pixel_to_base.m`, `pixel_to_base.m`, `test_vision_offline.m`'): f.append(e)
add(f)

# =====================================================================================  OVERVIEW
H1('Overview')
P('In Lab 4 the robot picked up a cube from a position that you typed in by hand. In this lab a camera supplies that position. A camera fixed above the table takes a picture of the workspace, MATLAB finds a colored block in the picture, and a calibration that you build converts the position of the block in the picture into robot base coordinates. The robot then picks the block up wherever it lies inside the calibrated area.')
P('The overall objective is to calibrate the camera against the robot, and then to run and evaluate a pick whose target position is computed from a camera image.')

H1('Learning Objectives')
bullets(
    'Capture an image from the camera in MATLAB and locate a colored block in it by tuning HSV thresholds.',
    'Calibrate the mapping from image pixels to robot base coordinates with points touched by the robot, and judge from the residuals whether it is good enough to use.',
    'Explain why the calibration is valid only for a camera that has not moved and for objects on the table plane.',
    'Run a vision-guided pick safely, in which the robot moves to a position computed from a camera image.',
    'Given a failed detection or a missed pick, decide whether the cause is the thresholds, the calibration, or the reference pick pose.')

# =====================================================================================  BACKGROUND
H1('Background: From Pixels to a Pick')
P('Figure 1 shows the setup and the four steps that every vision-guided pick repeats. The camera is fixed above the table and looks down at it; it does not have to point exactly straight down. Before every picture the robot parks at the imaging pose, a waypoint that keeps the arm clear of the area in which blocks lie, so that nothing hides the block from the camera.')
figure('fig1_cell.png', 'Figure 1', 'The setup seen from the side, and the four steps of a vision-guided pick. The camera is fixed, and the robot waits at the imaging pose, outside the field of view, while the picture is taken.', 5.2)
P('MATLAB stores the picture as a grid of pixels, 1280 wide and 720 high. A position in the picture is given in pixel coordinates $(u, v)$: $u$ counts columns to the right and $v$ counts rows downward, both starting at the top left corner (Figure 2a). The robot works in its base frame, the fixed frame {s} of Lab 3 with its origin at the center of the robot base. In that frame a point on the table has coordinates $(X, Y)$ in meters (Figure 2b).')
figure('fig2_frames.png', 'Figure 2', 'The same block in two coordinate systems: (a) pixel coordinates $(u, v)$ in the camera image, and (b) base coordinates $(X, Y)$ on the table. The calibration matrix $A$ converts the first into the second. The image axes are usually rotated against the base axes, as drawn.', 6.0)
P('Because the camera does not move and every block rests on the same flat table, each pixel corresponds to exactly one point on the table. To a good approximation the correspondence is an affine map, which is a linear map plus a constant offset:')
add(display('X = a_{11} u + a_{12} v + a_{13}'))
add(display('Y = a_{21} u + a_{22} v + a_{23}'))
P('The six constants form the 2x3 calibration matrix $A$. They contain the scale of the picture in meters per pixel, the rotation between the image axes and the base axes, and where the picture lies on the table. You do not measure them one by one. Calibration means finding them from examples: you put the block at four spots, and at each spot you record the pixel position that the camera reports and the base position that the robot reports with its gripper on the block. The function `fit_pixel_to_base` then computes the $A$ that fits the four pairs best in the least-squares sense.')
P('The camera supplies only $X$ and $Y$. The height of the pick and the orientation of the gripper are taught once, as in Lab 4: you record one reference pick pose with the gripper on a block, and for every pick the script keeps that pose and replaces only its $X$ and $Y$. Table 1 lists the files that are new in this lab. The robot functions are the ones of Lab 4.')
table('Table 1', 'MATLAB files that are new in this lab', [3900, 4740], ['File and call', 'What it does'], [
    ['`img = capture_realsense()`', 'Opens the camera, lets its brightness settle, and returns one color picture. The call takes about 3 seconds.'],
    ['`[uv, mask] = detect_block(img, hsvLow, hsvHigh, minAreaPx)`', 'Finds the block by its color. `uv` is the pixel position `[u v]` of the block, or `NaN` if nothing passed the thresholds. `mask` marks the pixels that passed.'],
    ['`[A, res_mm, rms_mm] = fit_pixel_to_base(UV, XY)`', 'Computes the calibration matrix `A` from the calibration points, and returns the fit error at each point and overall, in millimeters.'],
    ['`XY = pixel_to_base(A, uv)`', 'Applies `A` to one pixel position and returns `[X Y]` in meters.'],
    ['`UR_CalibrateCamera`', 'Guides you through the calibration of Part 4 in the Command Window. It reads the camera and the robot and never moves the robot.'],
    ['`UR_VisionPick_Lab`', 'The main script. It runs in four stages and stops at the first stage whose values are still missing, so you run the same script again and again as the lab progresses.'],
    ['`test_vision_offline`', 'A self-test of the detection and calibration functions that needs no camera and no robot.']])
P('The four stages of `UR_VisionPick_Lab` are:')
bullets(
    'Stage 1 (works after Part 2): moves the robot to the imaging pose, takes a picture and shows it.',
    'Stage 2 (works properly after Part 3; before that it runs with default thresholds that do not fit your block): finds the block and shows where it was found.',
    'Stage 3 (works after Part 4): converts the pixel position to base coordinates and prints them.',
    'Stage 4 (works after Task 5): asks you to type `yes`, then picks the block up and places it.')

# =====================================================================================  BEFORE YOU START
H1('Before You Start')
bullets(
    'Through the Teach Pendant, the robot is Powered On with the brakes released, and the gripper TCP and payload are set as in Lab 1. The block is light, so the payload stays unchanged.',
    'The PC is connected to the robot by Ethernet (robot IP address 192.168.1.10), and the server program of Lab 2, the one that contains the Script Code node ' + SERVER + ', is saved on the robot.',
    'The camera (an Intel RealSense D435i) is on its fixed mount above the table and connected to a USB 3 port of the PC with a USB 3 cable. On a USB 2 port or cable the camera is detected but never delivers a picture.',
    'You have a ruler, tape for marking the table, and one colored block that fits between the open gripper fingers with at least 1 cm to spare on each side. Its color must differ clearly from the table and from everything else the camera sees. Remove other objects of a similar color from the table, and turn the room lights on.',
    'You have your Ready position from Lab 4 (Table 3 of Lab 4) at hand. You will use it again.',
    'The Lab 5 folder holds the seven files listed at the top of this manual. Make it the current folder of MATLAB.')
P('⚠️ In this lab the robot moves to a position that is computed from a camera image. A wrong threshold or a poor calibration sends it to a place that nobody taught. Keep everyone outside the reach of the arm while a script runs, keep one hand near the e-stop, and make every first run at a speed slider of 25%. Note also that `UR_VisionPick_Lab` moves the robot to the imaging pose as soon as it starts, without asking. Only the pick itself waits for you to type `yes`.')
P('⚠️ Do not move the camera, its mount or the table once you have started Part 4. The calibration is only valid for the camera position at which it was made.')
P('**Jogging and running.** You will switch many times between jogging the robot by hand and letting MATLAB move it. The Teach Pendant jogs the robot only while no program is playing, and MATLAB can move the robot only while the server program is playing (its node is Green). So stop the server program before you jog, and press Play again before you run `UR_VisionPick_Lab`. The robot moves only while a script is running: place and move the block by hand between runs, and keep your hands out of reach of the arm while a script runs. Reading the robot from MATLAB, which is all that `UR_CalibrateCamera` does, works in both states.')

# =====================================================================================  PART 1
H1('Part 1 - Camera Check')
P('Before the robot is involved, confirm that MATLAB has what it needs and that the camera sees the right part of the table.')
H2('Task 1: Verify the Software and the Camera View')
steps(
    'In MATLAB, make the Lab 5 folder the current folder. Type `test_vision_offline` in the Command Window and press Enter. It runs the detection and calibration functions on made-up images and must end with the line ALL OFFLINE VISION TESTS PASS. If it stops with an error that names `bwareaopen` or `regionprops`, the Image Processing Toolbox is missing on your PC: tell your instructor.',
    'Type `webcamlist` and press Enter. MATLAB lists the cameras it can see, and one of the names must contain both RealSense and RGB. If MATLAB does not recognize `webcamlist`, the MATLAB Support Package for USB Webcams is missing: on the Home tab click Add-Ons, then Get Hardware Support Packages, search for that name, install it and restart MATLAB. If the camera is not in the list, unplug its cable at both ends, plug it into a USB 3 port (usually marked blue or SS) and try again.',
    ('If the arm is parked over the table, stop any program that is playing and jog the arm aside. Then take a picture and display it:', ['img = capture_realsense();', 'figure; imshow(img)'],
     'You should see the table from above, as in Figure 4a. Only one program can use the camera at a time, so if the call fails with a timeout, close any other program or MATLAB window that has the camera open.'),
    'Check the picture. It must be sharp and evenly lit, and nothing in it other than your block may have the color of the block. If the picture is dark or has a strong color cast, the room lights are off.',
    'Choose the pick area, the part of the table from which the robot will pick blocks. It must be completely visible in the picture and within easy reach of the robot: for a UR3e, every part of it between about 25 and 45 cm from the center of the robot base, measured with the ruler. A rectangle of about 15 cm by 20 cm is enough. Mark its four corners on the table with small pieces of tape whose color differs from the block, and number the marks 1 to 4 around the rectangle. Take another picture to confirm that all four marks are visible. If the camera does not see such an area, ask your instructor to adjust the camera now; it must not be moved later.')

# =====================================================================================  PART 2
H1('Part 2 - The Imaging Pose')
P('The imaging pose is the waypoint at which the robot waits while the camera takes the picture. It is stored as six joint angles, like the waypoints of Lab 4. A good imaging pose has no part of the arm or the gripper above the pick area, because an arm in the picture can hide the block or shift the position at which the block is found. The robot base itself may be visible at the edge of the picture, as in Figure 4a.')
H2('Task 2: Choose and Record the Imaging Pose')
steps(
    'Set the speed slider to 25%. If a program is playing on the Teach Pendant, stop it. On the Move screen, jog the robot to your Ready position from Lab 4: open the Joints tab, type the six angles, then open the 3D tab in the left sidebar, tap Move Here and hold Move to Position until the robot stops.',
    'From the Ready position, move the arm out of the picture. On the Joints tab, either turn joint 1 until the arm points away from the pick area, or fold the arm up and back toward the base with the +/- buttons of joints 2 and 3, a few degrees at a time while you watch the arm. Stay clear of the walls and of the camera mount, and keep the gripper at least 20 cm above the table.',
    'Take a picture as in Task 1, step 3, and check it: all four tape marks are visible, and no part of the arm or gripper lies over the pick area. If the arm is in the way, move it farther and take the picture again.',
    'Read the six joint angles from the Move screen and record them in the first row of Table 2.',
    'In MATLAB, open `UR_VisionPick_Lab.m`. In the section labeled CONNECTION, check that `robotIP` is the IP address of your robot (on a robot other than a UR3e, also change `\'universalUR3e\'` on the next line, here and in `UR_CalibrateCamera.m`). In the section labeled TASK 2, replace `nan(1,6)` with your six angles, in degrees and in order from joint 1 to joint 6. For example: `imaging_pose = [0.95 -71.20 -33.84 -142.19 89.36 180.96];`. Save the file.',
    'On the Teach Pendant, tap the program name, tap a program that contains the Script Code node ' + SERVER + ' and tap Open, as in Lab 4, Task 4. Press Play. The node must turn Green. If Play reports that the gripper was not found, apply the Tool I/O fix of Lab 4, Task 3.',
    'Type `UR_VisionPick_Lab` in the Command Window and press Enter. The robot is already at the imaging pose, so it barely moves. MATLAB Figure 1 shows the camera picture. MATLAB Figure 2 also opens, with no detection or a wrong one, because the thresholds are not tuned yet. The script then stops with a message that no block was detected or that the calibration table is not complete. All of this is expected at this point.',
    'Test the move itself once. Stop the program on the Teach Pendant, jog back to your Ready position, press Play, and run `UR_VisionPick_Lab` again with your hand near the e-stop. The robot must travel to the imaging pose in one smooth move, which takes about 20 seconds at 25%, and the new picture must again show the pick area free of the arm.')
table('Table 2', 'Taught waypoints: joint angles in degrees', [1740] + [1150] * 6,
      ['Waypoint'] + ['Joint %d' % k for k in range(1, 7)],
      [['Imaging pose'] + [''] * 6, ['Place (Task 5)'] + [''] * 6])

# =====================================================================================  PART 3
H1('Part 3 - Detect the Block')
P('The camera stores every pixel as three numbers: red, green and blue (RGB). A change in the lighting changes all three at once, which makes it hard to pick out one color in RGB. `detect_block` therefore converts the picture to HSV, a second way of describing the same color with three numbers (Figure 3). Hue (h) is the color itself, as a position on the color scale. Saturation (s) is how pure the color is, from gray to vivid. Value (v) is how bright the pixel is; it is unrelated to the pixel coordinate $v$. In MATLAB all three run from 0 to 1.')
figure('fig3_hsv.png', 'Figure 3', 'The three HSV channels, each on a scale from 0 to 1, with typical hue bands for three block colors. Red lies at both ends of the hue scale. For a red block the lower hue limit is therefore larger than the upper one, and `detect_block` then accepts hues above the lower limit or below the upper limit.', 6.0)
P('A threshold is a pair of limits on one channel. In the script, `hsvLow` holds the three lower limits and `hsvHigh` the three upper limits, each as `[h s v]`. A pixel passes if all three of its values lie between the limits. The pixels that pass form the mask, and a connected group of them is called a blob. `detect_block` ignores blobs smaller than `minAreaPx` pixels, which removes specks of noise, and returns the centroid of the largest blob, which is the average position of its pixels (Figure 4). Good thresholds give one blob that covers the top of the block and nothing else.')
figure('fig4_detection.png', 'Figure 4', 'A real example from the lab camera with a red block and the thresholds `hsvLow = [0.95 0.50 0.30]`, `hsvHigh = [0.05 1.00 1.00]`. (a) The camera picture, cropped. (b) The detection: the mask is tinted and the red cross marks the centroid. The teal block is ignored because its hue is outside the limits.', 6.0)
H2('Task 3: Tune the Thresholds')
steps(
    'Leave the robot at the imaging pose with the server program playing. While no script is running, put the block in the middle of the pick area.',
    ('Measure the color of the block. Type the three lines below in the Command Window, exactly as printed. After the second line, a crosshair appears over the picture: click once on a plain, evenly colored spot on the top face of the block.',
     ['img = capture_realsense(); imshow(img)', '[x, y] = ginput(1);', 'rgb2hsv(reshape(double(img(round(y), round(x), :)) / 255, 1, 3))'],
     'MATLAB prints three numbers: the h, s and v of the pixel that you clicked. Record them in the first row of Table 3. Then click in the Command Window, repeat the last two lines (the up-arrow key recalls them) and click on the bare table next to the block. Record those values in the second row.'),
    'Choose the limits from the measured values. For hue, take 0.05 below and 0.05 above the hue of the block. If the lower limit comes out negative, add 1 to it; if the upper limit comes out above 1, subtract 1 from it (this is the red case of Figure 3). The lower saturation limit is the measured s minus 0.3, and the lower value limit is the measured v minus 0.3, but neither less than 0.1. Both upper limits are 1. For example, a block measured at h = 0.03, s = 0.81, v = 0.65 gives `hsvLow = [0.98 0.51 0.35]` and `hsvHigh = [0.08 1.00 1.00]`.',
    'Check that the bare table does not pass. Take the three numbers that you measured on the table (second row of Table 3): at least one of them must lie outside your limits by 0.05 or more. For example, a table measured at s = 0.30 fails a lower saturation limit of 0.51 by 0.21. If all three numbers lie inside your limits, find the channel in which the block and the table differ most and move the limit of that channel to halfway between the two measured numbers.',
    'Type your limits into TASK 3 of `UR_VisionPick_Lab.m`, save the file and run the script (click in the Command Window first, so that your typing goes there). MATLAB Figure 2 shows the result as in Figure 4b, and the Command Window prints the pixel position of the block. The script then stops because the calibration table is not complete.',
    'Judge MATLAB Figure 2. If parts of the top face of the block are not tinted, lower the second or the third number of `hsvLow` (saturation or value) by 0.1, or widen the hue limits by 0.02 on each side. If the table or another object is tinted, raise the second number of `hsvLow` by 0.1 or narrow the hue limits. Change one number at a time and run the script again. The detection is good when the tint covers most of the top face, the red cross sits on the block, and nothing else in the picture is tinted.',
    'Move the block to each of the four tape marks in turn and run the script each time. The block must be found at all four corners. Lighting is rarely even across a table, so a threshold that works in the middle can fail at a corner.',
    'Record your final limits in Table 3. Then open `UR_CalibrateCamera.m` and copy `robotIP`, `hsvLow`, `hsvHigh` and `minAreaPx` into its SETTINGS section, and save the file.')
table('Table 3', 'Measured colors and final thresholds', [3240, 1800, 1800, 1800], ['', 'h', 's', 'v'],
      [['Block, measured (step 2)', '', '', ''], ['Table, measured (step 2)', '', '', ''], ['`hsvLow`, final', '', '', ''], ['`hsvHigh`, final', '', '', '']])

# =====================================================================================  PART 4
H1('Part 4 - Pixel-to-Base Calibration')
P('You now collect the four pairs of positions from which $A$ is computed. `UR_CalibrateCamera` guides you: for each spot it takes a picture and finds the block, then waits while you jog the gripper onto the block, and then reads the position of the robot. The pixel positions go into the matrix `UV` and the base positions into the matrix `XY`, one row per spot.')
P('Two details decide how accurate the calibration is. First, `readCartesianPose` returns the position of the tool flange (Lab 4, Table 1), and the script uses the flange position for the calibration and for the pick alike. The flange is directly above the block only if the gripper points straight down (Figure 5c). A gripper that is tilted differently from one touch to the next puts about 3 mm of disagreement per degree into the calibration. For this reason every touch starts from your Ready position, in which the tool points straight down, and uses only the X, Y and Z buttons, which move the gripper without turning it. Second, the four spots must surround the pick area (Figure 5a). The fitted map is accurate between the calibration spots and drifts outside them, so four spots close together (Figure 5b) give a map that looks good at those spots and misses by 10 mm or more elsewhere.')
figure('fig5_calibration.png', 'Figure 5', 'Calibration. (a) Four spots at the corners of the pick area give a map that is accurate over the whole area. (b) Four spots close together do not. (c) The touch: the open gripper points straight down with the block centered between the fingers, so that the $X$ and $Y$ of the tool flange are the $X$ and $Y$ of the block.', 6.0)
P('After the fourth spot the script reports how well the map fits. The residual of a calibration point is the distance, in millimeters, between the position that the robot measured and the position that the fitted map predicts for the same pixel. The RMS (root mean square) of the four residuals summarizes them in one number.')
H2('Task 4: Calibrate with UR_CalibrateCamera')
steps(
    'Stop the server program on the Teach Pendant, because you will jog. Check that the speed slider is at 25%. Open the Robotiq gripper screen (Application, URCaps, Robotiq), activate the gripper if the screen asks for it, and open the gripper.',
    'Put the block on tape mark 1 with its sides parallel to the edges of the table. Keep the block in this same orientation at every spot and in every later pick. The arm is still at the imaging pose, out of the picture.',
    'Type `UR_CalibrateCamera` in the Command Window and press Enter. The script prints the current joint angles and asks for placement 1. Press Enter to take the picture. MATLAB Figure 1 shows the detection. Click in the Command Window. If the red cross is on your block, press Enter once to keep it; otherwise type `r` and press Enter to take the picture again. If no block was found, press Enter twice to retry. Record u and v in Table 4. The script now waits for the touch: do not press Enter again until step 6, because that Enter records wherever the robot is at that moment.',
    'Jog to your Ready position (Joints tab, Move Here), which points the tool straight down. From here until the script asks for the next picture, jog only with the +/- buttons of X, Y and Z on the Move screen, with Relative To set to base.',
    'Without touching the block, jog the open gripper over the block and then down, until the fingers are on either side of the block and their tips are about 5 mm above the table. Look from the front and from the side and correct with X and Y until the block is centered between the fingers. At placement 1 only, if the fingers are not square to the faces of the block, turn joint 6 on the Joints tab until they are, and do not turn joint 6 again afterwards. Do not close the gripper: it would push the block away from the position that the camera recorded. Take particular care at placement 1, because its touch becomes the reference pick pose: every later pick uses its height and its gripper orientation.',
    'Press Enter in MATLAB. The script reads the robot and prints the position of the flange. Record X and Y in Table 4.',
    'Jog straight up with Z until the fingertips are at least 10 cm above the block. Then move the arm out of the picture again, as in Task 2: turn joint 1 away from the pick area, or type the angles of the imaging pose in the Joints tab and use Move Here.',
    'The script is still running and now asks for placement 2. Do not start it again. Move the block to the next tape mark, in the same orientation, and repeat steps 3 to 7 from "Press Enter to take the picture" for placements 2, 3 and 4. If MATLAB Figure 1 shows the arm over the pick area, move the arm farther away and type `r` to retake the picture.',
    'After placement 4 the script prints the four residuals, the RMS, and three assignments that begin with `UV =`, `XY =` and `ref_pick_pose =` (nine lines in total). Record the residuals and the RMS in Table 4. An RMS under 3 mm is excellent and 3 to 5 mm is acceptable. Above 5 mm, run `UR_CalibrateCamera` again and repeat all four placements. With only four points the residuals come out nearly equal, so they show that something went wrong but not at which spot, and the RMS is about half of the real scatter of your touches. The real test of the calibration is the pick in Task 6. The usual causes are a block that moved between the picture and the touch, a gripper that was tilted or off center, or an arm that was in the picture.',
    'Copy the results into `UR_VisionPick_Lab.m` in two parts. First select the eight printed lines of `UV = [ ... ];` and `XY = [ ... ];` in the Command Window, copy them, and paste them over the eight lines of the two placeholder matrices in TASK 4, from `UV = [ nan nan ;` to the last `nan nan ];`. Then copy the single printed line `ref_pick_pose = [ ... ];` and paste it over the line `ref_pick_pose = nan(1,6);` in TASK 5. Save the file. The script also saved a copy of the results as `calibration_results.txt` in the Lab 5 folder.')
table('Table 4', 'Calibration points and fit quality', [1340, 1400, 1400, 1500, 1500, 1500],
      ['Placement', 'u (px)', 'v (px)', 'X (m)', 'Y (m)', 'Residual (mm)'],
      [[str(k), '', '', '', '', ''] for k in range(1, 5)] + [['RMS (mm)', '', '', '', '', '']])

# =====================================================================================  PART 5
H1('Part 5 - Vision-Guided Pick')
P('With the calibration entered, `UR_VisionPick_Lab` can run its last stage. It takes the reference pick pose `ref_pick_pose`, which is the pose of the flange at your placement 1 touch, and replaces its $X$ and $Y$ by the position computed from the picture. The orientation of the gripper and the height of the pick stay as you taught them. It then runs the seven steps of Figure 6. The approach point is 10 cm directly above the pick pose, for the reason given in Lab 4.')
figure('fig6_sequence.png', 'Figure 6', 'The seven steps of the vision-guided pick. Only the $X$ and $Y$ of the pick pose and of the approach point come from the camera. The imaging pose, the place waypoint, the pick height and the gripper orientation are taught.', 5.6)
P('The pick pose is a position in space, while `sendJointConfigurationAndWait` needs joint angles. The script converts one into the other by inverse kinematics (IK), the reverse of the forward kinematics of Lab 3: given a pose of the flange, find joint angles that produce it. It solves the problem numerically on the robot model of MATLAB (the function `poseToJoints` in the script) and sends every motion as one joint move.')
H2('Task 5: Teach the Place Waypoint')
steps(
    'With the server program stopped, jog to your Ready position, and from there jog with the X, Y and Z buttons only to the place where blocks will be dropped off. Choose a spot outside the pick area but within easy reach, with the fingertips about 4 cm above the table. At that height the released block drops a short distance, and the gripper does not sweep along the table when it arrives or leaves.',
    'Read the six joint angles from the Move screen, record them in the second row of Table 2, and type them into `place_pos` in TASK 5 of `UR_VisionPick_Lab.m`. Note the units: `place_pos` is six joint angles in degrees, while `ref_pick_pose` above it is a flange pose in radians and meters that you do not edit. Save the file.',
    'Jog straight up until the gripper is at least 15 cm above the table.')
H2('Task 6: Run the Vision-Guided Pick')
steps(
    'Put the block at a new spot inside the pick area, at least 3 cm inside the tape marks, in the same orientation as during the calibration. The camera and the table must not have moved since Task 4. Check that the speed slider is at 25%, and do not touch the slider while the script runs. On the Teach Pendant, press Play on the server program. The node must be Green.',
    'Run `UR_VisionPick_Lab`. The robot moves to the imaging pose and the camera takes the picture. The Command Window prints the pixel position of the block, the calibration residuals with the RMS, and the predicted position of the block, X and Y in meters. It then prints a warning and waits.',
    'Before you answer, make three checks. In MATLAB Figure 2, the red cross is on the block. The printed RMS is the value in Table 4. The predicted X and Y lie between the smallest and the largest X and Y of Table 4, which means that the target is inside the calibrated area. If any check fails, press Enter without typing anything. That cancels the run, and the robot does not move.',
    'If all three checks pass, type `yes` and press Enter. Keep your hand near the e-stop and watch every move. The script first opens the gripper, and the Command Window then lists each of the seven moves of Figure 6 as it starts, from [1/7] to [7/7]. At 25% every move takes about 20 seconds, so one pick takes about 2 minutes. During [2/7], watch the fingers come down on either side of the block and estimate the grasp offset: how far the center of the block is from the midpoint between the fingers, to the nearest 5 mm. If the fingers are about to land on top of the block, stop the program on the Teach Pendant; MATLAB then ends with an error within about a minute.',
    'When the Command Window prints "Vision-guided pick complete", record the trial in Table 5, including the grasp offset that you estimated.',
    'Take the block away from the drop-off spot. A block that is left there would be found and picked in the next run. Put it at another new spot, in the same orientation, and run the script again, until you have five trials: one in the middle of the pick area and one about 3 cm inside each corner. When two trials in a row have succeeded at 25%, you may set the slider to 50% for the remaining trials. Keep it at 10% or higher, since below that the script gives up waiting while the robot is still moving.')
table('Table 5', 'Vision-guided pick trials', [800, 1840, 1200, 1200, 1300, 2300],
      ['Trial', 'Predicted X, Y (m)', 'Detected (Y/N)', 'Picked (Y/N)', 'Grasp offset (mm)', 'Notes'],
      [[str(k), '', '', '', '', ''] for k in range(1, 6)])
P('If a run does not go as planned, find the cause before you change anything:')
bullets(
    'No block is found, or the red cross is not on the block: the thresholds no longer fit the lighting, or another object of the same color is in the picture. Return to Task 3.',
    'The red cross is on the block, but the gripper arrives more than about 10 mm away from it, by a different amount at different spots: the calibration is poor. Check that the camera has not moved and repeat Task 4.',
    'The gripper arrives centered over the block, but too high, too low, or with its fingers turned against the faces of the block: the reference pick pose is wrong. Repeat Task 4 and take more care with the placement 1 touch, or check that the block lies in the orientation used during the calibration.',
    '"No joint solution near the current pose": the target is out of reach, or the imaging pose is so far from the pick area that the script finds no path between them. Check the predicted X and Y against Table 4, move the block closer to the middle of the pick area, or choose an imaging pose closer to your Ready position.',
    '"Joint move ... did not complete" or "Cartesian move ... did not complete" although the target was within reach: the server program is not playing, the robot is in a protective stop, or the speed slider is below 10%. Clear the stop on the Teach Pendant as in Lab 4, press Play so that the node is Green, and run the script again.',
    'Before you run the script again after a stop: if the robot stopped near the table, jog straight up first, because the first move of the script goes directly to the imaging pose. If the gripper still holds the block, open it from the Robotiq screen and take the block out. Never reach in while the script is running.')
P('When you finish, stop the program, jog the robot to your Ready position and power it down as at the end of Lab 4.')

# =====================================================================================  OPTIONAL, QUESTIONS
H1('Part 6 - Going Further (Optional)')
P('The D435i also measures depth, the distance from the camera to each pixel. The USB Webcams package lists the depth stream as a second camera: `webcamlist` shows a name that ends in Depth next to the RGB one. Capture it with `webcam` and `snapshot` while the robot is at the imaging pose, read the value at the centroid of your block, and compare it with the value on the bare table. Could you use this to pick blocks of two different heights with one calibration? What would replace the fixed pick height?')
H1('Assessment Questions')
def Q(n, text):
    p = etree.Element(w('p')); p.append(run('Q%d.' % n, 'b'))
    for e in inline('  ' + text): p.append(e)
    add(p)
Q(1, 'The calibration is valid only while the camera stays where it was calibrated, and only for blocks that rest on the table. Explain why. Then suppose a block is placed on a spacer 20 mm thick without repeating the calibration. Sketch the camera, the block and the table from the side, and use the sketch to explain whether the predicted X and Y are wrong by the same amount everywhere in the picture.')
Q(2, 'How did you arrive at your final HSV thresholds, and which of the three channels separated your block from the table? What happened, or what would happen, to the detection when the room lighting changes? Name one change to the setup, in hardware or in software, that would make the detection more robust.')
Q(3, 'Compare the calibration RMS in Table 4 with the grasp offsets in Table 5. List three distinct sources of error between the camera image and the gripper fingers, and state which one you believe is the largest in your setup and why.')
Q(4, 'The gripper approaches every block with the one orientation that you taught, so the block had to lie in the same orientation every time. What additional quantity would the system need in order to pick a long rectangular block that lies at any angle, and how could it be computed from the detection mask?')
Q(5, 'In Lab 4, Q5 asked which waypoints would change if a camera reported where the cube is. You have now built that system. For each quantity that is still taught in this lab, name a sensor or a method that could supply it automatically. What would fail if the blocks arrived on a moving conveyor, and why?')
P('**Deliverable:** completed Tables 2 through 5, and a vision-guided pick demonstrated live to your instructor.')

# =====================================================================================  WRITE
for e in out: sect.addprevious(e)
hdr = b'<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
new = {'word/document.xml': doc, 'word/numbering.xml': numx, 'word/_rels/document.xml.rels': rels}
zout = zipfile.ZipFile(OUT, 'w', zipfile.ZIP_DEFLATED)
for info in zin.infolist():
    if info.filename == 'word/media/image1.png': continue
    data = zin.read(info.filename)
    if info.filename in new: data = hdr + etree.tostring(new[info.filename], encoding='UTF-8')
    zout.writestr(info, data)
for name, data in media.items(): zout.writestr(name, data)
zout.close(); print('wrote', OUT, 'with', len(media), 'figures')
