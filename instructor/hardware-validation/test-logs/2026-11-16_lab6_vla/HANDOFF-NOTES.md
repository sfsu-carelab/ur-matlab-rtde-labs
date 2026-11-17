# 2026-11-16 (PC 17, afternoon): Lab 6 first live session

Ryan on PC 17 with the UR3e, after the Lab 4 hardware run earlier the same day. Goal: get the
VLA loop (Lab 6, `UR_VLA_Lab`) to move the robot for the first time, then start the manual.
Claude ran batch MATLAB only (offline tests, API calls, one camera capture, read-only robot
reads). Every motion is Ryan's, from the MATLAB desktop. This file is appended to during the
session; newest entries at the bottom of each section.

## 1. Start of session
- Offline: `test_vlm_offline` Part 1 11/11 PASS; `checkcode` on all eight Lab 6 `.m` files: 0
  messages (`offline_vlm_part1.log`).
- Network: robot 192.168.1.10 ping <1 ms, TCP 30004 open, campus NIC 130.212.86.144 up at
  the same time, TCP 443 to generativelanguage.googleapis.com open.
- Camera: not plugged in at the start; D435i RGB and Depth both enumerate (status OK) once
  Ryan plugged it into a USB-C port. User `MATLABPATH` still points at the webcam package
  folder, so batch MATLAB finds `webcam` with no addpath (the 2026-11-04 workaround holds).
- Gemini key: none at the start. Ryan created one at aistudio.google.com/apikey (step list
  given in chat) and saved `gemini_api_key.txt`.

## 2. Gemini API: what was learned (all verified live today)
- The key Google issues now is 53 characters and starts `AQ.`, not the old 39-character
  `AIza` form. It works.
- **A key file with more than one line crashes MATLAB hard.** Ryan's first file had the key
  pasted twice with a blank line between. `webwrite` with that header value threw inside
  `restful.dll` during object destruction and MATLAB died with `std::terminate()` (no MATLAB
  error, no catch possible; logs `live_vlm_part2.log`, `api_probe_a.log`). `matlab.net.http`
  with the same value gives a clean error ("hex value 0D found in a header field",
  `api_probe_b.log`). `resolveApiKey` in `gemini_generate.m` does `strtrim`, which does not
  help with an internal line break. PROPOSED (student code, needs Ryan's OK): take the first
  non-empty line of the file and error if it contains whitespace. A student will do exactly
  what Ryan did.
- The file was rewritten as one line (same key, 53 bytes, no CR/LF) and everything passed
  from then on.
- `gemini-robotics-er-2-preview` answers `generateContent` (the official ER 2 docs show only
  the Interactions API, but the REST endpoint the lab uses works). Both the lab's default
  `thinkingConfig.thinkingBudget = 0` AND `thinkingLevel = "low"` are accepted; no HTTP 400.
  The CLAUDE.md "UNVERIFIED" note is now verified: no change needed. `modelVersion` reported
  back is `gemini-robotics-er-2-preview`. The models list for this key includes
  `gemini-robotics-er-2-preview` and `gemini-robotics-er-2-streaming-preview`.
- `test_vlm_offline` Part 2 (synthetic scene): ALL LIVE VLM TESTS PASS
  (`live_vlm_part2_run2.log`): text 2.1 s, point 2.4 s, plan 3.6 s, verify 4.4 s.
- **HTTP 429 (Too Many Requests)** hit on the 11th call in about 40 s (`vlm_real_frame.log`).
  The free tier of the ER 2 preview has a low per-minute limit. One `UR_VLA_Lab` attempt makes
  3 calls (point, plan, verify) plus 1 per retry, so a student who reruns quickly will see
  it. The lab's hint text already names 429. PROPOSED: one automatic retry after 20 s on 429
  in `gemini_generate` (needs Ryan's OK).

## 3. Camera frame and VLM on the real scene (`camera_1.png`, `vlm_point_real_frame.png`, `vlm_plan_real_frame.png`)
Frame 1280x720, capture 3.2 s, mean RGB [85.7 115.0 110.2] (room lights on, cyan cast as
before). Robot at Ready, so the gripper is in the top of the frame. Red block, teal block,
one red-and-white checkered paper square as the destination.

| Target | VLM point (px) | HSV centroid, 2026-11-04 bands (px) | apart |
|---|---|---|---|
| the red block | (437.8, 368.6) | (438.8, 370.1) | 1.8 px |
| the teal block | (650.2, 403.2) | (650.3, 396.3) | 6.9 px |
| the blue block | (646.4, 403.2), label "blue block" | (the teal block) | the model obliges |
| the checkered paper | (590.1, 277.9) | n/a | |

Plans (ThinkingLevel medium, 3.4 to 3.8 s): "Put the red block on the checkered paper" ->
pick red block (437.8, 368.6), place checkered paper (590.1, 278.6). "Put the teal block
next to the red block" -> pick teal (646.4, 401.8), place "location next to the red block"
(512.0, 367.9), to the right of the red block. The third plan (green block, should refuse)
hit the 429 and is to be rerun.

**The camera has moved since 2026-11-04** (compare `camera_1.png` with
`../2026-11-04_PC17_session/exp_probe_30.png`: the base clamp, the wall rail and the vacuum
fitting all sit in different places). The 2026-11-04 UV/XY calibration and imaging pose
cannot be reused; Ryan recalibrates with `UR_CalibrateCamera` (first hardware run of that
script's prompt flow).

## 4. Decisions (Ryan, late afternoon)
- Lab 6 must be self-contained: no "copy from Lab 5". Calibration therefore lives in Lab 6.
- Ryan's question "why calibrate at all with a VLA" was answered in chat: Robotics-ER returns
  pixels only, knows nothing about the camera pose, and offers no fine-tuning or action
  output; the four-point map is what turns its answer into base X,Y. End-to-end action
  policies (pi0, pi0.5, SmolVLA, GR00T, Google's on-device model) learn the camera placement
  from teleop demos instead, which is the same knowledge made implicit. Ryan was hoping for
  the latter.
- **Lab 6 is TABLED.** Fallback definition: Lab 6 stays what it is now, language and image
  based object detection and planning in place of colour-blob detection, on top of the same
  calibration and motion path as Lab 5. Nothing was moved on the robot for Lab 6 today, and
  the new calibration script has NOT been run on hardware.
- Next exploration (separate from the labs): what it would take to run pi0 or pi0.5 on this
  PC with the UR3e.

## 5. Code state (all lint clean, 0 messages)
- NEW `labs/lab6-language-directed-pick/UR_CalibrateCamera_VLM.m`: the Lab 5 calibration
  walk-through rewritten around `vlm_point` (describe the block in words, no HSV
  thresholds), prints `imaging_pose` (joints read at the placement 1 picture, arm out of
  view), `UV`, `XY`, `ref_pick_pose` ready to paste into `UR_VLA_Lab.m`, and writes
  `calibration_results.txt` (gitignored). Handles a model error (e.g. HTTP 429) or an empty
  answer by offering the spot again. Never moves the robot. NOT run on hardware yet.
- COPIED into the Lab 6 folder, unchanged: `capture_realsense.m`, `detect_block.m`,
  `fit_pixel_to_base.m`, `pixel_to_base.m` (self-contained folder; same duplication as the
  server script in Labs 2 and 4). If Lab 5's copies change, copy them again.
- `UR_VLA_Lab.m`: comments and three stop messages only ("copy from Lab 5" -> "run
  UR_CalibrateCamera_VLM and paste its lines"; header file list). No logic change.
- `labs/lab5-vision-guided-pick/UR_CalibrateCamera.m`: temporarily given the red band for a
  run that never happened; reverted to the shipped placeholder. Net change none.
- `gemini_api_key.txt` rewritten as one line (ignored file, not in git).

## 6. Open items
- [ ] UR_CalibrateCamera_VLM first hardware run (prompt flow, imaging pose line, RMS)
- [ ] UR_VLA_Lab Stage A to D from the desktop
- [ ] rerun the "green block" refusal plan after the rate limit clears
- [ ] decide on the two proposed gemini_generate changes (key file line break, 429 retry)
- [ ] Lab 6 README.txt and the outline still say "Lab 5 Code folder on the path" (doc fix,
      after the code runs)
- [x] CLAUDE.md Lab 6 row and "Facts" paragraph updated at the end of the session
- [ ] VLA side project (separate from the labs): see `pi0_feasibility.md` in this folder.
      Decision: LeRobot + SmolVLA on the lab's Jetson AGX Orin with SpaceMouse teleop.
      Waiting on the Orin's memory size and JetPack version.
- [ ] SUPERSEDED IN PART (Mac session, same evening): MATLAB must stay in the loop. Current
      plan and the four first tests are in `vla_matlab_in_loop_plan.md` in this folder
      (MATLAB + urRTDEClient executes, SmolVLA fine-tuned and served from WSL2 on PC 17,
      Jetson as fallback).

## 7. End of session
Commits 5205f40 (session work), e9b3d77 (pi0 note), and the wrap-up commit (this note,
CLAUDE.md) pushed to origin/main. Ryan to pull on the Mac and rsync into Box. The robot was
never moved for Lab 6 today; `UR_CalibrateCamera_VLM` is untested on hardware.
