# Lab 4 Rev4: simulated-student review, 2026-11-16 (after the hardware run)

Three fresh agents (no project knowledge; given only the Lab 1 to 3 manual text, the Lab 4
manual text as patched today, `UR_PickPlace_Lab.m` and the real Command Window output of
run 1) walked the lab as: a struggling junior, an average senior who skims, a strong senior
who probes edge cases. Read-only, no MATLAB, no robot.

## Verdicts
- Junior: NO as it stood. MATLAB half matches the script and the real output line for line;
  the pendant half names seven controls never seen in Labs 1 to 3 and the gripper screen had
  no location at all.
- Average senior: YES, barely (about 125 min; two instructor questions: gripper screen,
  Variable-tab reuse).
- Strong senior: YES with one edit tonight: delete "catch it".

## Gaps merged (duplicates removed; items the real run already settled dropped)
| # | Severity | Where | Problem | Done |
|---|---|---|---|---|
| 1 | SAFETY | Task 5 error bullet 2 | "the script releases it at Ready: catch it" invites a hand under a moving arm | fixed: open the gripper from the pendant while stopped, never reach in |
| 2 | SAFETY (minor) | Task 4 step 2 | "Nothing moves in this task", but Play with the group's own program loaded runs the pick-and-place | fixed: check the program name before Play |
| 3 | GUESS | Table 4 text | "X and Y within 2 mm" only holds at zero tilt; 3 deg of tilt gives about 9 mm and students will think the connection is wrong | fixed: Z about 174 mm higher, X and Y within about 15 mm, 3 mm per degree of tilt |
| 4 | GUESS | Before You Start | no minimum spacing of the tape marks; check 7 needs 50 mm | fixed: at least 10 cm apart |
| 5 | NIT | Table 2 Retract row | Retract listed with a node but never stored in Task 1; all three nearly stored a sixth node | fixed: note in Table 2 |
| 6 | NIT | Task 5 step 4 | "under 2 minutes" at 25 percent is about 2 min 15 s | fixed: a little over 2 minutes |
| 7 | NIT | Task 5 error bullet 1 | e-stop recovery needs Power On and Unlock before Play | fixed |
| 8 | near BLOCKER | Task 1 step 5 | Robotiq gripper screen had no location | fixed (Ryan): Application in the left sidebar, scroll down to URCaps, Robotiq |
| 9 | GUESS | Tasks 1 to 3 | Joints, 3D tab, Move Here, Edit Point, Variable tab, Timer node, Global Variables all first seen here | checked against the handbook (below); screenshots would still help, not done |
| 10 | NIT | Task 5 step 8 | students compared 30.4 s with the 50 percent estimate | not a manual error: that run was at 100 percent; 25 and 50 percent still unmeasured |
| 11 | NIT | Table 1 | readMotionStatus used by the script but not listed | not changed (internal helper) |
| 12 | NIT | check 1 | radians typed by mistake are caught only by check 3 with a misleading name | not changed |

## Pendant wording vs the PolyScope X Software Handbook (SW 10.12, PDF, 288 pages)
Downloaded and text-extracted with pypdf (Anaconda Python on PC 17). Result per claim:
- Create program: header program name, System Manager, add program icon, Create New Program,
  Program name, Confirm. MATCHES (14.1).
- Move panel: "Tap the Move icon on the sidebar" (the right drawer); fields Relative To
  (world, base, flange, tcp) and Active TCP; Translate tab with X, Y, Z plus-minus; Joints
  tool with an editable field per joint, type, Confirm. MATCHES (4.4, pages 35 to 39).
- Move Here: brown Move Here button below the X, Y, Z coordinate space in the 3D main screen;
  opens "Move robot into position"; long tap Move to Position; Tap Ok. MATCHES; the manual
  says hold Move to Position until the robot stops and omits the final Ok (pages 39, 140).
  Ryan, on the real pendant 2026-11-16: there is no Ok button in this flow, just the Move
  Here button in the 3D view, so the manual stays as written.
- Joint Move / Linear Move nodes: fields Motion Profile and Name; buttons Edit Point,
  Move Here, More; Name field has Value, Variable, Expression tabs. MATCHES (14.3.15, 14.3.16).
- Edit Point screen: tabs Move, Joints, TCP, Smart Skills; jog, Save; Joints tab: tap the
  bar, type, Save. MATCHES (page 158 to 159).
- Variable tab: "pick from a list of variables defined in the program; only variables of the
  appropriate type are shown"; waypoints are global variables (4.5.4). CONSISTENT with
  reusing a stored pose; not shown step by step for a Joint Move node.
- Move up / Move down icons reorder nodes. MATCHES (page 31 icon table).
- URCap nodes: "visible when you tap URCaps after Tool" in the Commands toolbox. MATCHES.
- Timer node: Variable field with Rename and Confirm; Action field with Start, Pause, Reset.
  MATCHES exactly (14.3.27). Global Variables: "Tap Global Variables in the sidebar", values
  shown with Play. MATCHES (4.5.4).
- Save: program name tab, save icon, Save / Save as / Discard changes. MATCHES (14.2).
- Power down: Robot State icon at the left of the footer; Shutdown dialog, Power Off.
  MATCHES (3.x).
- Script node: the 10.12 handbook has a "Script" node with Set Script and an Import script
  field fed from System Manager, Script Files. The Lab 2 manual (verified on this robot)
  uses "Script Code" node and "Select File", so the robot's software is newer than 10.12.
  Lab 4 keeps the Lab 2 wording.
- NOT COVERED by the handbook: node-name character rules, any dialog when Play is pressed
  away from the first waypoint, URCaps under the Application tab (Ryan's observation on the
  real pendant; the handbook lists twelve Application submenus without it).
