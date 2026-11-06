# UR e-series MATLAB + RTDE teaching labs - project handoff

You are picking up work that earlier Claude Code sessions did with Ryan: on his Mac
(2026-10-28), on lab PC COSE-SEC414-21 (2026-10-28 and 2026-11-04), then on lab PC
COSE-SEC414-17 (2026-11-04 afternoon, two USB-C ports, plugged into the robot). Read this
file fully, then read the three handoff notes files listed under "Current state", before
touching anything.

THE WORKING FOLDER IS the git clone `C:\Users\924414657\2026 Thesis\ur-matlab-rtde-labs`
(origin = the GitHub mirror below, branch main). It is the ONLY copy on the lab PC; the old
Box-layout `Labs` folder was retired on 2026-11-06. Sync flow agreed with Ryan that day:
push from the lab PC to GitHub; Ryan pulls on his Mac; Ryan rsyncs the working tree (minus
`.git`) into Box from the Mac. GitHub, this clone and Box share one folder layout.

Git on this PC: portable MinGit at `C:\Users\924414657\AppData\Local\Programs\MinGit\cmd` and
gh at `C:\Users\924414657\AppData\Local\Programs\gh\bin`, both on the user PATH (a shell
opened before 2026-11-06 needs the full paths). gh is logged in as ryantcullen over HTTPS and
is git's credential helper, so `git push` just works.

## What this is
Six teaching labs for a UR e-series cobot (UR3e in the lab) driven from MATLAB over RTDE,
for Ryan's SFSU MSME thesis and an ASEE 2026 paper. Students run the `.m` scripts from the
MATLAB desktop; the manuals are the `.docx` files in each lab folder. Public mirror:
https://github.com/sfsu-carelab/ur-matlab-rtde-labs

One folder layout: `labs/lab1-teach-pendant-and-safety/` ... `labs/lab6-language-directed-pick/`,
`instructor/hardware-validation/`, `assessment/`, `resources/`. (The smoke test still also
recognises the old Box names, which is harmless.) Some material lives in the working tree on
the lab PC and in Box but is gitignored so it never reaches the public mirror: every
`archive/` folder, `*_Rev<n>.docx` and `.pdf` old manual revisions, the Lab 3 answer key
`instructor/UR_FK_Lab_KEY.m` and `instructor/test_all_models.m`, the Quanser
`QArm Lab 11 - Visual Servoing/` folder inside lab6, `gemini_api_key.txt` and
`calibration_results.txt`. Ignored files do not travel through git: they were copied to Box
once by hand and only change if someone edits them. Never force-add them.

| Lab | Folder | Code | Status (2026-11-04) |
|---|---|---|---|
| 1 Teach pendant and safety | `labs/lab1-teach-pendant-and-safety` | none | taught before |
| 2 MATLAB + RTDE setup | `labs/lab2-matlab-rtde-setup` | snippet in the manual | connect/read verified on hardware 2026-10-28 |
| 3 Forward kinematics (PoE) | `labs/lab3-forward-kinematics` | `UR_FK_Lab.m` + helpers, key in `instructor/` (ignored) | verified on hardware: FK matches the reported pose to 0.0 mm, no base yaw |
| 4 Pick and place | `labs/lab4-pick-and-place` | `UR_PickPlace_Lab.m` | joint move and Cartesian move verified; gripper needs the Robotiq server script; full script not yet run |
| 5 Vision-guided pick | `labs/lab5-vision-guided-pick` | `UR_VisionPick_Lab.m` + helpers | camera path switched to USB Webcams package; NO frame captured yet (USB 2 cable); calibration not done |
| 6 Language-directed pick (VLM) | `labs/lab6-language-directed-pick` | `UR_VLA_Lab.m` + Gemini client | 11 offline tests pass; live API never called (no key yet); never run on hardware; manual is an outline |

Instructor tooling: `instructor/hardware-validation/UR_HardwareSmokeTest.m` plus the
`RUNBOOK - End-to-end hardware test, Labs 2-6.md` in the same folder.

## Current state and next steps
Read, in order:
1. `instructor/hardware-validation/test-logs/2026-10-28_183517/HANDOFF-NOTES.md`
   (CobotName fix, readCartesianPose is the MODEL's FK not the pendant TCP, gripper stubs in
   the stock URServerScript, speed slider vs EndTime timeout).
2. `instructor/hardware-validation/test-logs/2026-11-04_session/HANDOFF-NOTES.md`
   (camera decision and the USB 2 cable finding, what is still open).
3. `instructor/hardware-validation/test-logs/2026-11-04_PC17_session/HANDOFF-NOTES.md`
   (PC 17: network OK, smoke test layout fix, folder consolidation, webcam package install
   state, Lab 5 progress).

Ryan's working order, agreed 2026-11-04: make Lab 5 work end to end on hardware, THEN update
its manual; make Lab 6 work, THEN update its docs. No manual edits before the code runs.
Do one step at a time and report; do not fan out into side edits (runbook, smoke test,
manuals) without asking first.

Next PC checklist, before anything else:
- Static IP on the robot NIC (IT sets it; robot 192.168.1.10, PC 192.168.1.11 on PC 21,
  192.168.1.20 on PC 17). Check `ping` and TCP 30004. The code and runbook now say
  192.168.1.10; the manuals may still say 192.168.0.20 (doc fix for later).
- UR support package installed (Add-Ons, no admin). CobotName must be `universalUR3e`.
- "MATLAB Support Package for USB Webcams" installed (Add-Ons, no admin) BY THE ACCOUNT THAT
  OWNS `C:\ProgramData\MATLAB\SupportPackages\R2024b\appdata\*.json` (on PC 17 that is the
  account that installed the UR package on 2026-11-03). From any other account the installer
  lays the files down but cannot update those read-only registry files, so the package stays
  invisible to MATLAB and to the Add-On Manager (found 2026-11-04 on PC 17, see the PC17
  notes). Session-only workaround: `addpath(<...>\toolbox\matlab\webcam\supportpackages)`.
- Camera on a USB 3 cable/port: `webcamlist` shows "...435i RGB", `snapshot` returns a frame.
  On a USB 2 cable the camera enumerates, lists modes, and never delivers a frame (both in
  MATLAB and in Windows' own capture path). That was the 2026-11-04 blocker.
- Gemini key as the only line of `labs/lab6-language-directed-pick/gemini_api_key.txt`, then
  `test_vlm_offline` Part 2 from batch.
- Pendant: `URServerScript_Robotiq2F_PolyScopeX.script` (gripper calls enabled, PolyScope X
  names rq_close_and_wait / rq_open_and_wait) loaded and playing. The plain
  `URServerScript_Robotiq2F.script` uses PolyScope 5 names and does not compile on PolyScope X.
  Speed slider at 100 percent, or at least 50, and left alone during timed moves.

## Hard rules
1. **You never move the robot from a batch command.** Scripts that move the robot
   (`UR_HardwareSmokeTest` without `DryRun=true`, `UR_PickPlace_Lab`, `UR_VisionPick_Lab`,
   `UR_VLA_Lab`) are run by Ryan from the MATLAB desktop with the e-stop in hand. You may run
   `matlab -batch` for lint (`checkcode`), the offline tests (`test_vision_offline`,
   `test_vlm_offline`), `UR_FK_Lab_KEY`, a camera capture, the live Gemini test, and
   `UR_HardwareSmokeTest(DryRun=true, ...)`. `input()` does not work in batch mode.
   Note: a batch MATLAB that opens the camera while the desktop MATLAB holds it will hang;
   only one process can own the camera.
2. **Do not remove the safety scaffolding** in the student scripts: NaN placeholders that
   stop the script until filled, the typed "yes" confirmation, EndTime-parameterized moves,
   `xy_in_calibrated_area` in Lab 6. If a check gets in the way, ask Ryan.
3. **Keep the MathWorks API as the labs use it**: `urRTDEClient(ip, 'CobotName', 'universalUR3e')`,
   `readJointConfiguration`, `readCartesianPose` (1x6 `[thetaz thetay thetax x y z]`, ZYX
   Euler radians and metres, computed from the MODEL at the live joint angles, not the
   pendant TCP), `sendJointConfigurationAndWait(ur, q_rad, EndTime=t)`,
   `sendCartesianPoseAndWait(ur, pose, EndTime=t)`, `actuateGripper(ur, 'grip'|'release')`.
   No force read exists. Do not introduce ROS, Python-RTDE, or URScript sockets;
   `executeURScriptCommand` halts the URServerScript and breaks RTDE motion.
4. **Edit student-facing code conservatively and only after asking.** Fixes found on hardware
   go in as the smallest change that works, with a one-line comment saying what was observed,
   and the same note in the handoff file. No silent fallbacks or workarounds in student code:
   if a lab needs a package, the lab requires it openly.
5. **Never put the Gemini API key in any file other than `labs/lab6-language-directed-pick/gemini_api_key.txt`**,
   and never upload that file anywhere (it is in the mirror's `.gitignore`).
   `setenv('GEMINI_API_KEY', ...)` in MATLAB is the alternative.
6. No em dashes in any text you write for the manuals or questionnaires (Ryan's rule).
7. Git: never add a Co-Authored-By line. Commit as ryantcullen (already in `.git/config`).
   PC 17 has MinGit and gh on the user PATH (see top of this file); other lab PCs may not,
   in which case install the same way (user folder, no admin) rather than staging zips.

## Facts you need
- Robot: UR3e, PolyScope X, RTDE enabled, `URServerScript` loaded as a Script Code node and
  PLAYING (green) before MATLAB can command it (Lab 2 manual). The stock script's gripper
  functions are stubs; use `instructor/hardware-validation/URServerScript_Robotiq2F_PolyScopeX.script`
  (the non-PolyScopeX file keeps the PolyScope 5 names and fails to compile on this robot).
  Internet (campus wired NIC or Wi-Fi) and the robot link must be up at the same time for Lab 6.
- Lab 3 conventions: PoE screw model with `jointSignConvention() = [1 -1 -1 -1 -1 -1]`,
  `theta_home = [0 -90 0 -90 0 0]`, `hw2screw`/`screw2hw` convert pendant degrees to model
  degrees. Link lengths per model in `ur_link_lengths.m`. Verified on hardware 2026-10-28:
  the model base frame is the robot base frame and the orientation matches ZYX Euler.
- Lab 5: fixed imaging pose (with a fixed bird's-eye camera, any pose that keeps the arm out
  of view), affine pixel-to-base calibration from four TCP-touched points (`fit_pixel_to_base`,
  RMS under 3 mm excellent, over 5 mm redo), HSV detection with a hue wrap for red, pick via
  `sendCartesianPoseAndWait` using a taught reference pose with only X and Y replaced.
  `capture_realsense.m` now uses the USB Webcams support package (`webcam`, RGB sensor as a
  UVC camera, pinned to 1280x720). The RealSense SDK wrapper is no longer used.
- Lab 6: `gemini_generate.m` is a plain `webwrite` to
  `https://generativelanguage.googleapis.com/v1beta/models/<model>:generateContent` with the
  `x-goog-api-key` header; default model `gemini-robotics-er-2-preview`. Points come back as
  `[y, x]` normalized 0-1000; `vlm_point` converts to pixels. UNVERIFIED: whether this model
  accepts `generationConfig.thinkingConfig.thinkingBudget`. On HTTP 400, switch the default
  to `ThinkingLevel="low"`. On 404, the model id changed; check
  https://ai.google.dev/gemini-api/docs/models. No model fine-tuning exists or is needed;
  what the workspace needs is the Lab 5 calibration.
- MATLAB on these PCs: R2024b Update 5 at `C:\Program Files\MATLAB\R2024b\bin`. Batch:
  `matlab -batch "cd('<folder>'); test_vlm_offline"`. Every batch log starts with a harmless
  Quanser QUARC `startup.m` error block. Python is NOT installed on the lab PCs.

## Evidence and handoff
Everything goes in `instructor/hardware-validation/test-logs/<timestamp>/`: the smoke test
writes `smoketest.log`, `results.json`, `camera.png`, `vlm_point.png` there on its own. You add
`HANDOFF-NOTES.md` (what was run, what passed, every error verbatim, every code change with
file, line and why, the Lab 5 numbers, Lab 6 instructions tried and what the model returned,
open questions) and `lab5_values.txt`. Changed `.m` files stay in place in their lab folders.
At the end of a session: commit and `git push origin main` from the clone, then remind Ryan
to pull on his Mac and rsync the working tree into Box. Never commit the ignored material
listed under "What this is".
