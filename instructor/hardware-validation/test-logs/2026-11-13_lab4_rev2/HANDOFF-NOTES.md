# 2026-11-13 (Mac session): Lab 4 manual Rev2

Ryan asked for Lab 4 to be brought to the standard of the final Lab 3 manual (Rev4): to the
point, every term defined at first use, specific numbered steps. Nothing was run on the
robot in this session.

## Manual: `labs/lab4-pick-and-place/Lab 4 - Pick and Place.docx` (= `_Rev2`)
Built by `build_lab4_rev2.py` in this folder (needs `dx.py` from `../2026-11-09_lab3_rev3/`).
It reuses the Rev1 styles and rewrites the body; header and footer are copied from Lab 3
Rev4. Full text: `rev2_text.txt`.
- Objectives cut from six to four.
- Only terms that are NEW in Lab 4 are defined (MoveJ, MoveL, approach waypoint, `CobotName`,
  `EndTime`, `readCartesianPose`, `actuateGripper`, `moveEndTime`). Terms already defined in
  Lab 1 (Teach Pendant, TCP, waypoint, FreeDrive, speed slider, e-stop), Lab 2 (RTDE, URCap,
  server script, node, `urRTDEClient`, radians) and Lab 3 (NaN, `theta_hw`) are used without
  redefinition (Ryan, 2026-11-13). Joint angles are "joint 1 to joint 6" (no J1..J6).
- Table 1 lists only the functions and options that are new since Lab 2.
- New "Before You Start" list (TCP and payload from Lab 1, Lab 2 program and network, cube
  and two tape marks).
- Task 1 is eight numbered steps: Pick first, jog straight up for Pre-Pick, Retract takes
  the Pre-Pick values, X/Y check in Table 3 (TCP position now in mm, as the pendant shows).
- Task 2 gives the ten nodes explicitly (MoveJ/MoveL/gripper), in a new program so the Lab 2
  server-script program stays untouched.
- Task 4 says to compare joint angles only: the position line MATLAB prints is the flange
  position from the model, not the pendant TCP.
- Task 5: example waypoint line, slider at 10 percent and left alone (about 50 s per move,
  about 7 min per run), then 50 percent for the timed run; three "if it stops" bullets.
- Table numbers are unchanged (1 to 5), captions above the tables in the Lab 3 style.
- The "switch grip() to a URScript digital output" step is gone (it halts the server script).
- Author line dropped to match the Lab 3 title block. No em dashes.

## Script: `UR_PickPlace_Lab.m` (comments and printed labels only, no logic change)
- Header: usage line, INPUT / OUTPUT / EXAMPLE, server script named in full.
- Printed label "TCP position (m)" is now "Flange position (m)" (two places), with a comment:
  readCartesianPose is the model's flange position (hardware finding of 2026-10-28).
- Waypoint comments say "joint 1 (base) to joint 6 (wrist 3)" with an example line.
- EndTime comments and the cycle-time message state the speed slider scaling.
- `moveTo` and `grip` have INPUT lines; `grip` names the Robotiq server script.

## Checks
- `checkcode UR_PickPlace_Lab.m`: 0 messages.
- Simulated run on the Mac (`sim_runsim.m`: stub urRTDEClient / read / send / gripper / input
  functions that shadow the toolbox, a fake arm that takes EndTime/slider to arrive):
  NaN waypoints stop before motion; answering "no" aborts; "yes" runs the ten steps in order
  and ends at Home; the same at a 10 percent slider, where the library call returns before
  arrival. This exercises the script logic only, not the robot, RTDE or the gripper.
- docx: zip and XML parse, opens in python-docx, 5 tables, 0 em dashes. NOT opened in Word.

## Survey
Lab 4 learning-objective items reduced to the four new objectives in both Qualtrics import
files and the paper form (previous paper form kept as `_Rev1`, ignored). Qualtrics needs a
re-import.

## Not verified / open
- The full Lab 4 script has still never run end to end on the robot.
- PolyScope X screen and node names in Parts 1 and 2 are generic (Move screen, gripper node,
  "store that pose as the waypoint"); check against the pendant.
- "About 50 s per move at 10 percent" follows the 2026-10-28 slider finding (time = EndTime /
  slider); the 60 s arrival cap in `waitForArrival` leaves little margin at 10 percent.
- The Lab 2 manual snippet still calls `urRTDEClient(robotIP)` without `CobotName`.
- README.md and the runbook are still stale.

## Also
The Lab 3 instructor solutions docx that Dr. Quintero edited on Box (2026-11-10 14:56) was
copied Box to clone unchanged.

## Later the same day: simulated-student review
Three review agents (struggling junior, average senior, strong senior) walked through Rev2
and a mediator agent digested their findings. No manual-versus-script mismatch was found.
Applied to the manual:
- Task 1 now records AND stores each waypoint in the group's pendant program while the
  robot is there (was: re-jog to the recorded angles for every node in Task 2, the main time
  sink). Base feature is set before any jogging; Place is reached by jogging X and Y only.
- Task 2 is four steps: arrange the ten nodes, set joint or linear, add gripper nodes, save.
- Home is flagged as not the Smart Skills Home button (Lab 1's upright pose).
- Task 3: after correcting a waypoint, update Table 3; record pick success and place accuracy.
- Task 4: open "a Lab 2 program" (any group's copy); mismatch and connection-error advice
  separated (CobotName does not affect the joint readout).
- Task 5: first MATLAB run at 25 percent (about 3 min) instead of 10 percent (about 7 min),
  50 percent run about 1.5 min; gripper must be open (script does not check); how to stop a
  run from the pendant; printed angles are checked against the Move screen.
- Error bullets: slider below 10 percent added; jog straight up before rerunning after a
  stop at Pick or Place (first move goes directly to Home).
- Table 5 place accuracy has a criterion (2 mm / 5 mm); Q1's last sentence reworded.
Script, text only: prompt says 25 percent and "leave it alone"; error text says "slider is
at 10 percent or higher"; comment "see Q3" is now "see Task 6"; comment example is 25 percent.
Lint clean and the four simulated runs pass again.

Questions only the pendant or Ryan can answer (manual wording is generic until then):
1. Is Lab 4's Home the Lab 2 "Ready Position" smart skill, or six specific angles?
2. Where is the Robotiq open/close control, does it work while the server program plays,
   and does the gripper need activation after power-up?
3. Exact taps to add a move node, set joint or linear, and store the current pose; can one
   stored waypoint be reused by several nodes?
4. Does Play ask to move to the start position, and does a program loop by default?
5. Is the cube light enough that the payload stays unchanged?
6. Lab 2 Part 6 says the Ready Position was "practiced in Lab 1"; Lab 1 never mentions it.

## Later still: Ryan's answers to the open questions, applied
- No Smart Skills in the labs any more. Students jog to a READY position of their own choosing
  (shoulder and elbow bent, tool flange facing down); it is the first node of the program
  tree. Lab 4 "Home" is renamed Ready everywhere, FreeDrive and Align to Z-axis are gone,
  and Figure 1 (`figure1_ready.png` in this folder, drawn by
  `labs/lab4-pick-and-place/instructor/make_lab4_figure1.m`, which is gitignored because it
  contains the Lab 3 screw axes) shows an example at pendant angles [0 -70 -110 -90 90 0]. Checked
  numerically: the flange faces straight down when joint 5 = 90 and joints 2+3+4 = -270.
- Pendant steps now follow the PolyScope X Software Handbook (SW 10.12 PDF): tap + in the
  program tree, Joint Move / Linear Move nodes (or Move To with Move type Joint / Linear),
  Name, Edit Point, jog, Save; Edit Point has a Joints tab where angles can be typed; Move up
  and Move down icons reorder nodes; a program runs once unless a Loop node is added.
- Gripper: on the pendant through the Robotiq URCap (activate, open, close; gripper nodes in
  the program). From MATLAB through the server script, which calls rq_activate_and_wait()
  before every grip and release, so no separate activation from MATLAB.
- The program and the script now have ELEVEN steps: the gripper is opened once at Ready.
  SCRIPT LOGIC CHANGE: one `grip(ur,'release',...)` step added after the first move, and
  `home_pos` renamed `ready_pos` (messages say Ready). Lint clean; simulated runs pass.
- Payload: the cube is light, so the payload stays unchanged (Ryan).
- Lab 2 manual Rev9 (`build_lab2_rev9.py`): the Part 6 sentence that sent students to
  Move > Smart Skills > Ready Position "as you practiced in Lab 1" now tells them to jog to a
  ready position of their choosing. Nothing else in Lab 2 changed (Part 7 still mentions the
  built-in Smart Skills Home for power-down; the snippet still lacks CobotName).
- Still generic, check on the pendant: the name and location of the Robotiq gripper screen
  and node, and "set the reference to Base" (the handbook calls the field "Relative To").

## Waypoint check (Dr. Quintero liked the Lab 3 p-file; Ryan asked for the Lab 4 equivalent)
- New student file `labs/lab4-pick-and-place/check_waypoints.p`. Source
  `instructor/check_waypoints.m` and `instructor/test_check_waypoints.m` are gitignored (the
  source contains the Lab 3 forward kinematics); `instructor/build_pfile.m` rebuilds the p-file.
- `ok = check_waypoints(wps, cobotName)` prints PASS or FAIL for eight checks and never talks
  to the robot: (1) six waypoints of six finite angles within +/-360 and not radians,
  (2) Retract equals Pre-Pick within 1 deg, (3) tool within 5 deg of straight down at every
  waypoint, (4, 5) Pre-Pick / Pre-Place within 5 mm sideways of Pick / Place and 20 to 200 mm
  higher, (6) Place within 10 mm of the Pick height, (7) Pick and Place at least 50 mm apart,
  (8) Ready at least 100 mm above Pick. Tolerances are constants at the top of the source.
- SCRIPT LOGIC CHANGE in `UR_PickPlace_Lab.m`: new variable `cobotName = 'universalUR3e'`
  (passed to urRTDEClient and to the check), and `if ~check_waypoints(wps, cobotName), return, end`
  between the NaN check and the typed "yes". If the check ever gives a false FAIL on
  hardware, comment out that `if` block and note it here.
- Tests: `test_check_waypoints` (33 cases on UR3e, UR5e, UR10e: one valid set and ten broken
  ones each, plus an unknown model) passes against the p-file; lint clean; the simulated
  script runs pass, including a run where a shifted Pre-Pick must block motion.
- Figure 1 example ready pose changed to [0 -80 -80 -110 90 0] (gripper about 20 cm above the
  table on a UR3e) so that it satisfies check 8 and the "at least 15 cm" step.
- Manual: accompanying files list the p-file; Part 3 intro and Task 4 step 2 and Task 5
  steps 5 and 6 describe the check and `cobotName`.
