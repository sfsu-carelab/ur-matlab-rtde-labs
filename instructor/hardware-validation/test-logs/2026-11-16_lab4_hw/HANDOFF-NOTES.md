# 2026-11-16 (PC 17): Lab 4 verified on hardware, manual Rev4

Ryan on PC 17 with the UR3e. Goal: confirm that Lab 4 Rev3 (built on his Mac from Dr.
Quintero's feedback) runs end to end on the robot and that a student can follow it without
guessing. Every robot motion was run by Ryan from the MATLAB desktop with the e-stop in hand.
Claude ran only batch MATLAB that reads (connect, readJointConfiguration, readCartesianPose,
readMotionStatus, check_waypoints). Logs in this folder:
`task4_connect_read_batch.log`, `ready_pose_read_batch.log`, `waypoint_reads_batch.log`,
`check_waypoints_batch.log`, `run1_desktop_output.txt`.

## What passed
- `git pull` to 12d8d4f (Lab 4 Rev3). `checkcode UR_PickPlace_Lab.m`: 0 messages.
- The Mac-built `check_waypoints.p` runs on Windows R2024b (eight lines printed, expected
  FAILs on a degenerate set, ALL CHECKS PASS on the real set below).
- `labs/lab4-pick-and-place/URServerScript_Robotiq2F_PolyScopeX.script` is byte-identical to
  the instructor copy.
- Network: PC 192.168.1.20, robot 192.168.1.10, ping under 1 ms, TCP 30004 open.
- Task 4 path: `urRTDEClient('192.168.1.10','CobotName','universalUR3e')`, joint read and
  flange read work. Robot was at the upright pose [0.14 -89.87 -0.06 -89.43 0.10 0.05],
  flange [-1.0 -223.2 693.9] mm.
- Task 5 path, RUN 1 at a 100 percent slider (Ryan meant 25 but the slider was at 100):
  all eleven steps in order, cube picked and placed on the mark, no table contact, back at
  Ready. Cycle time Ready to Ready 30.4 s, which matches 7 moves x 3 s plus two gripper
  actions and the 0.5 s of polling pauses per move. Full output in `run1_desktop_output.txt`.

## Measured values (UR3e in its corner, gripper TCP 174 mm)
| Waypoint | Joints (deg) | Flange X Y Z (mm, model) |
|---|---|---|
| Ready | -9.31 -90.34 -84.99 -97.55 90.68 -1.76 | 269.6 -175.9 316.5 |
| Pre-Pick | 7.63 -129.35 -71.43 -70.06 86.83 6.22 | 451.9 -76.9 171.4 |
| Pick | 7.62 -137.46 -77.74 -55.64 86.84 6.26 | 451.8 -76.9 100.4 |
| Retract | = Pre-Pick | |
| Pre-Place | -25.28 -120.86 -86.82 -58.45 87.94 16.09 | 308.9 -294.5 175.8 |
| Place | -25.29 -130.32 -92.62 -43.19 87.96 16.13 | 308.8 -294.5 106.2 |

check_waypoints on this set: tilt 3.0 deg at Ready, 4.4 deg at Pre-Place (limit 5);
Pre-Pick 71 mm above Pick, Pre-Place 70 mm above Place, 0.1 mm sideways; Place +5.8 mm
relative to Pick (limit 10); Pick to Place 260 mm; Ready 216 mm above Pick.
The waypoints were read over RTDE while Ryan jogged; the student script shipped with the
NaN placeholders restored.

## Changes made today
1. **Ready position is a rule, not fixed angles** (Ryan: the Rev3 pose [-80 -80 -110 90 0]
   would hit the wall for robots in other corners of the room). Rule: joint 5 = 90,
   joint 6 = 0, joints 2 + 3 + 4 = -270 (tool flange straight down, which check 3 of
   check_waypoints already enforces); joints 1 to 3 chosen by the group so that the arm
   clears their walls and the gripper is at least 15 cm above the table. The old angles
   stay as the worked example in Figure 1. Edited: Table 2 Ready row, Figure 1 caption,
   Task 1 step 2 of the manual; `ready_pos` comment in `UR_PickPlace_Lab.m` (comment only).
2. **"Move Here" located**: Task 1 step 2 now says "open the 3D tab in the left sidebar, tap
   Move Here and hold Move to Position" (Ryan, from the pendant).
3. `UR_PickPlace_Lab.m` line 100 comment: "20 s per move at 25 percent" (left over from the
   5 s setting) is now "12 s per move at 25 percent". No logic changed in the script today.
4. Manual file: `Lab 4 - Pick and Place.docx` is now **Rev4**; the committed Rev3 is kept
   as the ignored `Lab 4 - Pick and Place_Rev3.docx`. Python is not on the lab PC, so the
   docx was patched in place (document.xml text runs replaced, zip rebuilt with
   forward-slash entry names; the first attempt with
   `ZipFile::CreateFromDirectory` produced backslash entry names and an unreadable docx).
   Verified: XML parses, 0 em dashes, Word opens it (308 paragraphs, 5 tables) and finds
   the new sentences. The same three passages were mirrored into
   `../2026-11-16_lab4_rev3/build_lab4_rev3.py` and `rev3_text.txt` so a rebuild on the
   Mac keeps them.

## Findings worth knowing
- With the server program STOPPED on the pendant, `urRTDEClient`, the joint and pose reads
  AND `readMotionStatus` (state "Not Executing") all still succeed. The script cannot tell
  a stopped server from an idle one; a move would end in the 60 s "Robot did not reach"
  error, which the manual's first error bullet already covers.
- The dashboard server port 29999 does not answer on this PolyScope X, so program state
  cannot be read from the PC.
- Tilt grew from 3.0 deg at Ready to 4.4 deg at Pre-Place while jogging with the X/Y/Z
  buttons (should keep orientation). Close to the 5 deg limit; a student who jogs the same
  way could see a check 3 FAIL. If that happens, the tolerance is at the top of
  `instructor/check_waypoints.m` (rebuild with `build_pfile.m`).
- A batch `matlab -batch "UR_PickPlace_Lab"` is blocked by the Claude Code permission
  classifier even with NaN waypoints; the connect/read snippet is the way to do Task 4
  from batch.

## Not verified (open)
- Runs at 25 and 50 percent (the students' first run and the Table 5 number). Ryan chose
  to stop after the 100 percent run. The 2026-11-04 slider finding (library wait returns
  early, waitForArrival covers it) is unchanged in logic and was exercised only in the Mac
  simulation.
- Part 2 on the pendant: Joint Move / Linear Move nodes, Name field and the Variable tab
  for reused poses, the Robotiq Gripper node under URCaps, the three Timer nodes and the
  Global Variables readout of `cycle_time`, program save and switching. Wording still
  comes from the PolyScope X handbook (SW 10.12) and the 2026-11-13 simulated dry run.
- Robotiq screen labels (Scan, Activate, Open, Close) and whether activation survives a
  program switch.
- Stop-in-mid-move behaviour (time to the MATLAB error, recovery bullets).
- Gripper-closed-at-start case (step 2 should open it).
- Lab 2 Rev9 Part 6 sentence not read on site.
