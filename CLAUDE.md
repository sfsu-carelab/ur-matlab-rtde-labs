# UR e-series MATLAB + RTDE teaching labs - project handoff

You are picking up work that earlier Claude Code sessions did with Ryan: on his Mac
(2026-10-28), then on lab PC COSE-SEC414-21 (2026-10-28 and 2026-11-04). The next session
runs on a different lab PC (one with two USB-C ports) plugged into the robot. Read this file
fully, then read the two handoff notes files listed under "Current state", before touching
anything.

## What this is
Six teaching labs for a UR e-series cobot (UR3e in the lab) driven from MATLAB over RTDE,
for Ryan's SFSU MSME thesis and an ASEE 2026 paper. Students run the `.m` scripts from the
MATLAB desktop; the manuals are the `.docx` files in each lab folder. Public mirror:
https://github.com/sfsu-carelab/ur-matlab-rtde-labs

Two folder layouts exist and the smoke test finds either:
- Box layout (this folder): `Lab 03 - Forward Kinematics/`, `Lab 05 - .../Code/`,
  `Lab 06 - .../Code/`, `Instructor - Hardware Validation/`.
- GitHub layout: `labs/lab3-forward-kinematics/`, `labs/lab5-vision-guided-pick/`,
  `labs/lab6-language-directed-pick/`, `instructor/hardware-validation/`.
The GitHub mirror deliberately omits the Lab 3 answer key (`instructor/UR_FK_Lab_KEY.m`),
the `archive/` folders and the Quanser QArm material inside the Lab 06 folder. Never push those.

| Lab | Folder | Code | Status (2026-11-04) |
|---|---|---|---|
| 1 Teach pendant and safety | `Lab 01 - ...` | none | taught before |
| 2 MATLAB + RTDE setup | `Lab 02 - ...` | snippet in the manual | connect/read verified on hardware 2026-10-28 |
| 3 Forward kinematics (PoE) | `Lab 03 - ...` | `UR_FK_Lab.m` + helpers, key in `instructor/` | verified on hardware: FK matches the reported pose to 0.0 mm, no base yaw |
| 4 Pick and place | `Lab 04 - ...` | `UR_PickPlace_Lab.m` | joint move and Cartesian move verified; gripper needs the Robotiq server script; full script not yet run |
| 5 Vision-guided pick | `Lab 05 - .../Code` | `UR_VisionPick_Lab.m` + helpers | camera path switched to USB Webcams package; NO frame captured yet (USB 2 cable); calibration not done |
| 6 Language-directed pick (VLM) | `Lab 06 - .../Code` | `UR_VLA_Lab.m` + Gemini client | 11 offline tests pass; live API never called (no key yet); never run on hardware; manual is an outline |

Instructor tooling: `Instructor - Hardware Validation/UR_HardwareSmokeTest.m` plus the
`RUNBOOK - End-to-end hardware test, Labs 2-6.md` in the same folder.

## Current state and next steps
Read, in order:
1. `Instructor - Hardware Validation/test-logs/2026-10-28_183517/HANDOFF-NOTES.md`
   (CobotName fix, readCartesianPose is the MODEL's FK not the pendant TCP, gripper stubs in
   the stock URServerScript, speed slider vs EndTime timeout).
2. `Instructor - Hardware Validation/test-logs/2026-11-04_session/HANDOFF-NOTES.md`
   (camera decision and the USB 2 cable finding, what is still open).

Ryan's working order, agreed 2026-11-04: make Lab 5 work end to end on hardware, THEN update
its manual; make Lab 6 work, THEN update its docs. No manual edits before the code runs.
Do one step at a time and report; do not fan out into side edits (runbook, smoke test,
manuals) without asking first.

Next PC checklist, before anything else:
- Static IP on the robot NIC (IT sets it; robot was 192.168.1.10, PC 192.168.1.11 in SEC414).
  Check `ping` and TCP 30004. The manuals still say 192.168.0.20; that is a doc fix for later.
- UR support package installed (Add-Ons, no admin). CobotName must be `universalUR3e`.
- "MATLAB Support Package for USB Webcams" installed (Add-Ons, no admin).
- Camera on a USB 3 cable/port: `webcamlist` shows "...435i RGB", `snapshot` returns a frame.
  On a USB 2 cable the camera enumerates, lists modes, and never delivers a frame (both in
  MATLAB and in Windows' own capture path). That was the 2026-11-04 blocker.
- Gemini key as the only line of `Lab 06 - .../Code/gemini_api_key.txt`, then
  `test_vlm_offline` Part 2 from batch.
- Pendant: `URServerScript_Robotiq2F.script` (gripper calls enabled) loaded and playing.
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
5. **Never put the Gemini API key in any file other than `Lab 06 - .../Code/gemini_api_key.txt`**,
   and never upload that file anywhere (it is in the mirror's `.gitignore`).
   `setenv('GEMINI_API_KEY', ...)` in MATLAB is the alternative.
6. No em dashes in any text you write for the manuals or questionnaires (Ryan's rule).
7. Git: never add a Co-Authored-By line. The lab PCs have no git; portable Git for Windows
   (user folder, no admin) or GitHub Desktop are the options. The 2026-11-04 session staged
   the push from a zip of the mirror because of that.

## Facts you need
- Robot: UR3e, PolyScope X, RTDE enabled, `URServerScript` loaded as a Script Code node and
  PLAYING (green) before MATLAB can command it (Lab 2 manual). The stock script's gripper
  functions are stubs; use `Instructor - Hardware Validation/URServerScript_Robotiq2F.script`.
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
Everything goes in `Instructor - Hardware Validation/test-logs/<timestamp>/`: the smoke test
writes `smoketest.log`, `results.json`, `camera.png`, `vlm_point.png` there on its own. You add
`HANDOFF-NOTES.md` (what was run, what passed, every error verbatim, every code change with
file, line and why, the Lab 5 numbers, Lab 6 instructions tried and what the model returned,
open questions) and `lab5_values.txt`. Changed `.m` files stay in place in their lab folders.
At the end of a session: push code, instructor tooling and test-logs to the GitHub mirror
(GitHub layout above), and remind Ryan to upload the folder back to Box through the browser.
Keep the Box folder names exactly as they are; the Mac side depends on them.
