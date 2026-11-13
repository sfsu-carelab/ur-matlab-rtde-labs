# Lab 4 hardware checklist for Monday 2026-11-16 (students run it Tuesday)

Nothing in Lab 4 Rev2 has run on the robot. Work top to bottom; each item says what to look
at and what to write down. Fix the manual wording for anything marked WORDING the same day.
Ryan runs every robot motion from the MATLAB desktop with the e-stop in hand.

## 0. Lab PC and files (10 min)
- [ ] `git pull` in `C:\Users\924414657\2026 Thesis\ur-matlab-rtde-labs` (was at `ac14345`).
- [ ] `labs/lab4-pick-and-place/` has `UR_PickPlace_Lab.m` and `check_waypoints.p`.
- [ ] In MATLAB, in that folder: `which check_waypoints` prints the `.p` path, and
      `check_waypoints({[0 -80 -80 -110 90 0],[0 -80 -80 -110 90 0],[0 -80 -80 -110 90 0],[0 -80 -80 -110 90 0],[0 -80 -80 -110 90 0],[0 -80 -80 -110 90 0]},'universalUR3e')`
      prints the eight lines (several FAIL, that is expected). Confirms the Mac-built p-file
      runs on Windows.
- [ ] Optional: copy `labs/lab4-pick-and-place/instructor/` from Box (source, test, figure
      script are not on GitHub).

## 1. Robot prerequisites (5 min)
- [ ] Active TCP is the gripper TCP (0, 0, 174 mm), not zero. On 2026-11-06 it was zero. It
      affects the X, Y, Z readout, the jog and the linear moves.
- [ ] Payload set for the gripper; confirm the cube is light enough to leave it unchanged.
- [ ] Robotiq URCap X installed; the Lab 2 program with
      `URServerScript_Robotiq2F_PolyScopeX.script` exists.

## 2. Pendant wording, Part 1 and Part 2 (20 min) WORDING
Follow Task 1 and Task 2 literally and note every label that differs.
- [ ] New program: program name, "+ Program", "Create New Program", "Confirm".
- [ ] Move screen: field "Relative To" with "base"; field "Active TCP"; "Joints" tab; where
      the six joint angles and the TCP X, Y, Z are read; the X, Y, Z plus-minus buttons.
- [ ] The node list has "Joint Move" and "Linear Move" (or only "Move To" with a Move type).
- [ ] Node "Name" field: accepts `Ready`, `Pre_Pick`, `Pre_Place`. Try `Pre-Pick` once to see
      whether a hyphen is refused.
- [ ] "Edit Point" then "Save" stores the current pose. Where does a new node land (below
      the selected node)?
- [ ] "Move up" / "Move down" icons exist and reorder nodes.
- [ ] Reuse: a new Linear Move or Joint Move, Name field, "Variable" tab, pick `Pre_Pick`,
      "Confirm". Does the node then go to that stored pose? (Documented for Move To only.)
      If not: does typing angles in the Joints tab and "Save" store the typed values?
- [ ] Save: program name, your program, save icon, "Save". Opening the Lab 2 program: "Open".

## 3. Gripper on the pendant (10 min) WORDING
- [ ] Where the Robotiq gripper screen is and its labels (Scan, Activate, Open, Close).
- [ ] The gripper node: its name in the list (under URCaps?), how it is set to open or close,
      and whether the program waits for the fingers before the next move.
- [ ] Is activation needed again after switching programs or after a power cycle?

## 4. Ready position and waypoints (15 min)
- [ ] Jog to `[0 -80 -80 -110 90 0]`: does it look like Figure 1, is the gripper vertical, is
      it inside the room's keep-out limits, is the gripper at least 15 cm above the table?
- [ ] Rule check: with joint 5 = 90 and joints 2 + 3 + 4 = -270 the flange faces straight down.
- [ ] Teach Pick: with open fingers 5 mm above the table, does the 2F-85 clear the table and
      hold the cube? Note the cube size.
- [ ] Jog up in Z only: X and Y on the pendant stay within 2 mm (Table 3 check).
- [ ] Are both tape marks reachable with the tool vertical, by X, Y, Z jogging alone?

## 5. Pendant program, Task 3 (10 min)
- [ ] Play at 10 percent with the robot away from Ready: what happens first (any dialog)?
- [ ] The program runs once and stops.
- [ ] All four linear moves run; the gripper closes on the cube and releases it on the mark.
- [ ] Run at 50 percent: stopwatch cycle time (Table 5), place accuracy in mm.

## 6. MATLAB, Tasks 4 to 6 (30 min)
- [ ] Server program playing (green). `UR_PickPlace_Lab` with NaN waypoints: readout prints,
      script stops, robot does not move. Joint angles agree with the pendant within 0.1 deg.
- [ ] Type the six recorded waypoints. Run: all eight checks PASS. Write down the printed
      values (tilt, sideways mm, lift mm). A false FAIL here is the main risk: if one occurs,
      note the line and the values; the tolerances are at the top of
      `instructor/check_waypoints.m` (rebuild with `build_pfile`), or comment out the
      `if ~check_waypoints(...)` block in the script as a stopgap.
- [ ] Change one angle of `pre_pick_pos` by 5 deg and run: check 2 or 4 FAILS and the robot
      does not move. Restore it.
- [ ] Answer "no" at the prompt: nothing moves.
- [ ] Full run at 25 percent, "yes": eleven steps in order. Watch for:
      - step 2 opens the gripper at Ready (first gripper command after the server program
        starts: any activation delay or error?);
      - the gripper closes only after the arm has stopped at Pick, and the cube is held;
      - the joint-move descent to Pick and Place does not touch the table or push the cube;
      - total time (expect about 3 min) and the printed cycle time.
- [ ] Run at 50 percent: time (expect about 1.5 min). Record for Table 5.
- [ ] Run once at 10 percent: does every move finish inside the script's wait (50 s move
      against a 60 s cap), or does it stop with "Robot did not reach"?
- [ ] Stop the pendant program in mid-move: how long until MATLAB errors, and is the message
      understandable? Then follow the manual's recovery bullets and rerun.
- [ ] Start a run with the gripper closed and empty: step 2 opens it and the pick succeeds.
- [ ] Is the Move screen usable while the server program plays (Task 4 reads it)?

## 7. Switching between the two programs (5 min)
- [ ] Lab 4 program to Lab 2 program and back: any save prompt, anything lost?
- [ ] After switching, does the gripper still respond without a new Scan?

## 8. Wrap-up
- [ ] Total time for Parts 1 to 3 (target under 2 h 15 min for an average group).
- [ ] Append results to `HANDOFF-NOTES.md` in this folder, fix WORDING items in the manual
      (new rev if anything changes), commit and push, re-import the Lab 4 survey in Qualtrics.
- [ ] Lab 2 Rev9: read the new ready-position sentence in Part 6 on site and confirm it fits.
