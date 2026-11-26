# 2026-11-25 (Mac session): Lab 5 manual Rev3

Ryan asked for Lab 5 to be brought to the standard of Labs 3 and 4 (definitions at first use,
specific numbered steps, captions, and above all diagrams), with the same two audits as
before: the lab code run against simulated hardware, and simulated students who know only
Labs 1 to 4. Nothing was run on the robot. MATLAB is no longer installed on the Mac, so
NOTHING HERE WAS LINTED OR RUN IN MATLAB (see "Not verified").

Start state: GitHub main = Mac clone = Box at `2ed4e55`, checked with `git fetch` and
`diff -rq` before any edit.

## Manual: `labs/lab5-vision-guided-pick/Lab 5 - Vision-Guided Pick and Place.docx` (= `_Rev3`)
Built by `build_lab5_rev3.py` in this folder (needs `dx.py` from `../2026-11-09_lab3_rev3/`)
on the Lab 4 Rev5 docx as template, so Lab 5 now has the same styles, header, footer, list
and table formats as Labs 3 and 4 (Rev2 was a different, plain template). Full text:
`rev3_text.txt`. Figures: `make_lab5_figures.py` (Python, matplotlib) writes `figures/`.
- Structure now follows Lab 4: Overview with the overall objective, five objectives,
  Background, Before You Start, Parts 1 to 5 with Tasks 1 to 6 as numbered steps, captions
  above tables and below figures. Part, Task and Table numbers are unchanged from Rev2, so
  the script comments still point at the right places. Author, Prerequisites and References
  sections are gone (their content is in Before You Start).
- Six figures (Rev2 had none): 1 the cell from the side plus the four-step pipeline, 2 pixel
  frame against base frame, 3 the three HSV channels with the red wrap-around, 4 a real
  detection (the 2026-11-04 frame `exp_probe_30.png` run through a Python port of
  `detect_block`, which reproduces the hardware centroid 538.1, 635.7 and area 4410 px),
  5 calibration spots spread against clustered plus the touch from the side, 6 the seven
  steps of the pick.
- New terms defined once at first use: imaging pose, pixel coordinates, affine map,
  calibration, HSV, threshold, mask, blob, centroid, residual, RMS, inverse kinematics.
  Terms from Labs 1 to 4 are used without redefinition.
- Content corrections against Rev2:
  - Rev2 said readCartesianPose reports the active TCP. It reports the model's FLANGE
    (finding of 2026-10-28). The manual now says so, and explains why every touch must be
    made with the gripper pointing straight down (from Ready, X/Y/Z buttons only).
  - "25 mm blocks" removed. The lab blocks are about 50 mm (blob areas of 4000 to 4600 px
    at 1.0 mm/px).
  - First run at a 25 percent slider (hardware-verified value, and Lab 4's), was 10.
  - With four points the residuals come out nearly equal and the RMS is about half the real
    touch scatter, so "redo the worst point" is replaced by "repeat all four placements".
- New procedure content: `test_vision_offline` and `webcamlist` checks first; a taped pick
  area (about 15 x 20 cm, 25 to 45 cm from the base) whose four corners are the calibration
  spots; a click-to-measure HSV recipe (`ginput` plus `rgb2hsv`) with a rule for the limits;
  the stop-to-jog / play-to-run rule stated once; jog straight up before any script run;
  place waypoint 4 cm above the table; three checks before typing yes; a diagnosis list
  (thresholds, calibration or reference pose) and error-message bullets.

## Scripts (labs/lab5-vision-guided-pick)
One logic change, the rest is comments and printed text.
- `UR_VisionPick_Lab.m`, Stage 4: NEW LINE `grip(ur, 'release', gripSettle)` with the message
  "Opening gripper..." after the typed yes and before step 1/7. Found by two of the three
  simulated students: nothing opened the gripper before the descent, so a gripper left
  closed by an aborted run would be driven onto the block. Same thing Lab 4 does at Ready.
  NOT RUN ON THE ROBOT. If it misbehaves, delete that one line and tell students to open the
  gripper from the Robotiq screen before each run.
- `UR_VisionPick_Lab.m`, text only: header no longer says wrist camera, payload or RealSense
  wrapper, and notes that Stage 1 moves without asking; prompt says 25 percent; `grip`
  comment; TASK 4 and TASK 5 comment lines; the POOR label says repeat the calibration.
- `UR_CalibrateCamera.m`, text only: Table 3 is now Table 4 (two places); "TCP at" is now
  "Flange at"; SETTINGS comment names CONNECTION and TASK 3; prerequisites say the server
  program may be stopped; the poor-fit message no longer names a worst placement (the unused
  `worst` variable went with it).
- `fit_pixel_to_base.m` and `capture_realsense.m`: help text only.

## Audit 1: the code against simulated hardware (`sim/`, Python port)
`kin.py` (UR3e kinematics, reproduces the five 2026-11-04 hardware poses to 0.1 mm),
`cell.py` (pinhole camera at 1 mm/px, rendered table and blocks, robot and server timing),
`port.py` (line-by-line port of the student code), `s1` to `s4` (the runs).
No blocker in the code logic: the NaN gates, the yes prompt and the seven steps behave as
written, with no dropped command from 10 to 100 percent slider. Numbers that shaped the manual:
- Tilt of the gripper at the touch is the dominant error. Touches made by X/Y/Z jogging from
  a tool-down pose (0 to 1 deg): RMS 1.9 mm, pick error median 2.1, max 6.4 mm. With 0 to 3
  deg of tilt: 2.5 / 3.8 / 13.5 mm. The 2026-11-04 hardware touches were tilted 1.7 to 4.7 deg.
- Four spots clustered in one half: RMS still looks fine (2.3 mm) while picks miss by a
  median 8 and up to 33 mm.
- Starting the pick script with the fingers still around a 50 mm block hits the block 87
  percent of the time (the first move goes straight to the imaging pose). Same for a place
  waypoint at table height. With the place 40 mm up the sideways sweep is 0 to 2 mm.
- An arm 5 to 10 cm above the block during a calibration picture shifts the centroid by 3 to
  9.5 px with the cross still on the block; at 20 cm up the shift is under 0.5 px.
- Reach: the approach IK fails (no motion) from 0.54 m; under about 0.22 m the elbow folds
  and the descent bows up to 18 mm. Hence 25 to 45 cm.
- Below about 8 percent slider the script errors while the robot is still moving (10 s
  library wait plus the 60 s cap). Cycle in the model: 108 s at 25 percent, 59 s at 50, 34 s
  at 100. The hardware runs logged as "25 percent" on 2026-11-04 (35.9 s, 27.2 s) match 100
  percent in the model, so either the slider was not at 25 or time does not scale as
  EndTime/slider. The manual says "about 20 seconds per move at 25%"; check it.
- Default green thresholds on the cyan table: the script reports "Block detected" on a
  table-sized blob and goes on to stage 3. The manual says this is expected in Task 2.
- A larger object of the block's colour wins; a block left at the drop-off is picked again.
- The click rule (hue +/- 0.05, s and v floors 0.3 below the click) gave exactly one blob
  for red and for teal; teal passes only on the saturation floor.

## Audit 2: three simulated students (Labs 1 to 4 text, Lab 5 Rev3 text, figures, scripts)
Struggling junior, hurried average senior, strong senior. All three: the lab can be
finished from the manual, in about 2.5 to 3 hours, with recoveries. Applied from them:
- Gripper never opened before the pick (script fix above).
- Paste step split in two (pasting all nine lines into TASK 4 left ref_pick_pose at NaN).
- "Repeat steps 3 to 7" no longer reads as "start the script again"; warning that an extra
  Enter records the robot wherever it is; two Enters after "no block found".
- Block orientation: sides parallel to the table edges, fingers squared with joint 6 at
  placement 1 only (Rev3 draft asked for an orientation the student could not know yet).
- Placement 1 sets the pick height and orientation: now said in the touch step.
- HSV snippet without the transpose apostrophe; "click a plain spot"; clearer wording of the
  limit rule and of the table check; which number of hsvLow to change.
- Ruler and tape listed; camera mount named as an obstacle; what to do if the camera does not
  see a usable area; MATLAB Figure 2 also opens in Task 2; move duration stated; slider rule
  and grasp-offset estimate moved into the step where they are needed; place waypoint taught
  from Ready with X/Y/Z only; units of place_pos against ref_pick_pose.
- Corrections: readCartesianPose is in Lab 4 Table 1; what the constants of A contain; the
  pick-area size against the 25 to 45 cm ring; tilt explained as disagreement between
  touches; the four-point RMS understates the scatter.
- Repeats removed: Tool I/O fix and power-down now refer to Lab 4.
- Q1 (block on a 20 mm spacer, with a sketch), Q4 and Q5 reworded.
Not applied, for Ryan to decide:
- An independent check of the map before the first pick (predict, then touch and compare).
- Objective 5 (diagnosis) is supported by the troubleshooting list only; no deliberate-fault
  exercise.
- The student scripts still carry dated hardware notes in their comments.

## Later the same day: five calibration points and a colour helper (Ryan: "go for it on both")
- Calibration now uses FIVE placements: the four corners of the pick area plus its centre
  (tape mark 5). `UR_CalibrateCamera.m` default `nPlacements = 5`; `UR_VisionPick_Lab.m`
  TASK 4 placeholders have five rows; manual text, Table 4 and Figure 5 updated; the paste
  step is now ten lines over ten lines. Earlier bullets in this file that say "four" describe
  the first Rev3 build.
- New student file `measure_color.m`: takes a picture, asks for a click on the block and one
  on the table, prints h, s, v of each (5 x 5 patch averaged in RGB, then converted). It
  replaces the three typed lines of Task 3 step 2. Camera only, no robot. NOT RUN (no MATLAB
  on the Mac): run it once on a lab PC before handing out.
- Rev3 on Box was replaced in place (it had been there for under an hour and was unchanged).

## Survey
Lab 5 learning-objective items cut from six to five, worded as the five objectives, in both
Qualtrics import files and the paper form (now `_Rev1`; `_Rev0` moved to `archive/`).
Qualtrics needs a re-import.

## Not verified
- No MATLAB on the Mac: the edited `.m` files were not linted or run. Before handing out, on
  a lab PC: `checkcode` on the four edited files, `test_vision_offline`, and one run of
  `UR_VisionPick_Lab` and `UR_CalibrateCamera` from the desktop.
- `measure_color.m` is new and was not run.
- The docx passed the container checks (zip order, XML parse, python-docx, 5 tables, 6
  figures, 0 em dashes) and was looked at through Quick Look only, which does not render
  equations or list restarts. Open it once in Word.
- To check on the pendant: that the Move screen does not jog while a program plays (the
  manual tells students to stop the server program before jogging, which is safe either
  way); that the Robotiq screen opens the gripper with the server program stopped; about 20
  s per move at 25 percent; the exact `webcamlist` name (the manual says it contains
  RealSense and RGB, which is what `capture_realsense` looks for).
- The whole Rev3 student flow, in particular the taped pick area inside 25 to 45 cm being
  fully in the camera picture at the current camera position.
