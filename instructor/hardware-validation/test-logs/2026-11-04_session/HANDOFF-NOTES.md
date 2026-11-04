# Handoff notes - hardware session 2, 2026-11-04

Lab PC: COSE-SEC414-21 (Windows 11 Enterprise 10.0.26100), no admin. MATLAB R2024b Update 5.
Robot: UR3e at 192.168.1.10 (PC dongle "Ethernet 3" static 192.168.1.11). Ping and port 30004 OK.
Goal today: get the camera and the Gemini call working, then Lab 6 (VLA) on the bird's-eye
workspace with colored blocks. Smoke-test runs land in sibling timestamped folders; this
folder holds the hand-written notes.

Read the 2026-10-28_183517 notes first: CobotName fix, gripper stubs in the stock
URServerScript, speed-slider vs EndTime timeout. All still apply.

## 1. Environment findings (start of session)

- Camera: D435i connected with a USB-C to USB-A cable (the PC has one USB-C port). Windows
  enumerates both "Intel(R) RealSense(TM) Depth Camera 435i RGB" and "... Depth" (status OK)
  directly on the xHCI root hub (USB\VID_8086&PID_0B3A). Whether the link is USB 3 or USB 2
  is not visible without the SDK; for the RGB stream alone it should not matter.
- RealSense SDK: still not installed (needs admin). realsense.pipeline not on the path.
- No other frame source on the PC either: no USB Webcams support package (webcamlist
  undefined), no Image Acquisition adaptors, no Python (python.exe absent, pyenv empty).
- Gemini key: not present (no gemini_api_key.txt, no GEMINI_API_KEY). Internet works
  (TCP 443 to generativelanguage.googleapis.com from the campus wired NIC).
- Robot: reachable at 192.168.1.10, RTDE port open.

## 2. Offline checks (batch, start of session)

- test_vision_offline: 6/6 PASS.  test_vlm_offline Part 1: 11/11 PASS, Part 2 skipped (no key).
- checkcode on the edited capture_realsense.m: clean.

## 3. Code changes

DECISION (Ryan, 2026-11-04): Lab 5 and Lab 6 use the MathWorks "USB Webcams" support
package as the official camera path, not the RealSense SDK wrapper. Reason: the lab PCs
have no admin rights, the SDK installer needs them, and the labs only use the RGB stream.
A first version that added the webcam path as a silent fallback next to the SDK path was
rejected ("no workarounds, the lab should require the package it uses") and reverted
before this rewrite.

| File | Change | Why |
|---|---|---|
| `Lab 05 - .../Code/capture_realsense.m` | rewritten: requires `webcam` (USB Webcams package), picks the webcamlist entry containing "RealSense" and "RGB", pins 1280x720 when available, 15 snapshots to settle auto-exposure, same H x W x 3 uint8 output. Function name kept so the smoke test, UR_VisionPick_Lab, UR_VLA_Lab and the manuals still call it. | see decision above |

Manual follow-up (Mac side): Lab 5 Part 1 must now say "install MATLAB Support Package for
USB Webcams from Add-Ons" instead of the RealSense SDK + MATLAB wrapper SOP. The smoke test
row "RealSense MATLAB wrapper" should check `webcam` instead (changed today, see below).

### Camera finding (afternoon): D435i enumerates but delivers NO frames over the USB 2 cable

- USB Webcams package installed by Ryan. `webcamlist` shows both "...435i Depth" and "...435i RGB".
  `webcam('...RGB')` opens and lists 1920x1080, 1280x720, 640x480, 424x240. `snapshot` at 424x240:
  "Timeout occurred while trying to get a frame from the webcam." At 640x480: MATLAB hung hard
  (Ctrl+C ineffective; process killed).
- Same result outside MATLAB through Windows MediaCapture (the Camera app's path):
  InitializeAsync OK, mode list = YUY2 424x240 @ 60/30/15/6, 640x480 @ 30/15/6,
  1280x720 @ 15/10/6, 1920x1080 @ 8 fps. That frame-rate table is the D435i USB 2 table
  (USB 3 offers 720p/1080p at 30). CapturePhoto timed out; a 4 s recording at 424x240 @ 6 fps
  produced a 0-byte file. So no frames at any mode, independent of MATLAB.
- Cable: USB-C (camera) to USB-A (PC), confirmed by Ryan NOT a USB 3 cable. The PC's one USB-C
  port is taken. Most likely cause: USB 2 cable/port cannot power or stream the D435i reliably
  (Intel specifies a USB 3 cable; enumerate-but-no-frames is the classic bad-cable symptom).
- Not possible without admin: disabling the Depth UVC device (Disable-PnpDevice: Generic
  failure), installing the RealSense SDK.
- Fix to try: a USB 3 (SuperSpeed, 5 Gbps) USB-C to USB-A cable into a blue/SS USB-A port, or a
  powered USB 3 hub. Then repeat `webcamlist` / `snapshot` in the desktop and the batch capture.

## 4. Lab 6 / workspace answers for Ryan

- No model fine-tuning exists or is needed: Gemini Robotics-ER is prompt-driven. What the
  workspace needs is the Lab 5 geometric calibration, which is four pixel-to-base pairs plus
  one taught reference pick pose. With a fixed bird's-eye camera the "imaging pose" is just
  any joint pose that keeps the arm out of the camera's view.
- Motion without calibration: Stage A of UR_VLA_Lab only does the joint move to the imaging
  pose. Stage D (the actual pick) refuses to run until UV, XY and ref_pick_pose are filled.

## 4b. End of session on this PC: switching to a lab PC with two USB-C ports

Ryan decided to move to a PC with two USB-C ports so the camera can use its USB 3 cable.
State to carry over is in this folder, in CLAUDE.md (rewritten today as the handoff), and in
the GitHub mirror once pushed. This PC has no git and no admin; the agent's attempt to fetch
portable Git was blocked by its own permission policy, so Ryan fetches it (or GitHub Desktop).

Push plan (GitHub layout): `labs/lab4-pick-and-place/UR_PickPlace_Lab.m`,
`labs/lab5-vision-guided-pick/{capture_realsense.m, UR_VisionPick_Lab.m}`, new
`labs/lab6-language-directed-pick/` (Code folder + outline + MathWorks link; NOT the Quanser
QArm material), new `instructor/hardware-validation/` (smoke test, runbook, Robotiq server
script, all test-logs), `CLAUDE.md` at the root, `gemini_api_key.txt` added to `.gitignore`.
Not pushed: the Lab 3 answer key, `archive/` folders, docx manuals (unchanged today; the
mirror's docx names differ from Box's `_RevN` names, Mac side decides).

## 5. Open items (updated during the day)

- [ ] USB Webcams support package installed (Ryan, Add-Ons)
- [ ] Camera frame captured in batch, resolution and USB behaviour noted
- [ ] Gemini key in place, test_vlm_offline Part 2 live
- [ ] Pendant running URServerScript_Robotiq2F.script (gripper actually closes)
- [ ] Smoke test dry run with camera + GenAI
- [ ] Lab 5 calibration numbers -> lab5_values.txt
- [ ] UR_VLA_Lab stage by stage
