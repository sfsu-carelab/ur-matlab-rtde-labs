# Handoff notes - hardware validation session, 2026-10-28

Lab PC: COSE-SEC414-21 (Windows 11 Enterprise 10.0.26100), no admin rights for the account in use.
MATLAB: R2024b Update 5 (24.2.0.2863752). Same release as the Mac session.
Robot: UR3e, PolyScope X, URServerScript loaded as a Script Code node and playing.
People: Ryan at the robot, Claude Code on the lab PC (batch MATLAB only, never motion).

This file is appended to during the day. Newest entries at the bottom of each section.

## 1. Environment findings

- MATLAB R2024b Update 5. Robotics System Toolbox, Image Processing Toolbox, Computer Vision
  Toolbox all installed. Python is not configured in MATLAB (pyenv empty).
- UR support package was NOT installed at the start of the session. Installed by Ryan from
  Add-Ons during the session (no admin needed). It landed in
  `C:\ProgramData\MATLAB\SupportPackages\R2024b\toolbox\robotics\supportpackages\urseries`.
- RealSense SDK is NOT installed on this PC (no Intel RealSense folder under Program Files,
  `realsense.pipeline` not on the MATLAB path, no RealSense device enumerated). The SDK
  installer needs admin. Camera work (Lab 5 Parts 2-5, Lab 6) is deferred.
- Hardware constraint: the lab PC has ONE USB-C port. The robot Ethernet link uses a USB-C
  to Ethernet dongle, so the camera cannot be plugged in at the same time. A USB-C hub with
  Ethernet plus a USB 3 port is needed. Note that a hub with its own Ethernet chip is a new
  NIC to Windows and IT must set the static IP on it again.
- Network: the dongle (Realtek USB GbE, "Ethernet 3") is statically set by IT to
  192.168.1.11 / 255.255.255.0. The robot is at 192.168.1.10, NOT 192.168.0.20 as CLAUDE.md
  and the Lab 2 manual say. Ping and TCP port 30004 both answer. Students will not have admin
  on these PCs either, so the Lab 2 manual must match whatever IT configured, or IT must
  reconfigure. Every call today uses RobotIP="192.168.1.10".
- The PC's built-in Ethernet port is on the campus wired network (DHCP), so internet and the
  robot link are available at the same time. Lab 6 can work on this PC once the API key is in.
- MATLAB's startup.m on this PC is Quanser QUARC's (`C:\Program Files\Quanser\QUARC\quarc\@startup\startup.p`).
  In batch mode it throws "Dot indexing is not supported" from `quarc_tip_of_the_day` and
  warns about a missing path under another user's Downloads folder. Harmless, batch
  continues, but every batch log starts with that error block.
- Ryan's 128 GB SanDisk USB stick was a Linux live-USB image (ISO partition + EFI + ext
  persistence partition). It cannot be reformatted on this PC without admin (partition is
  write-protected). Resolved separately (script got onto the pendant another way).
- Gemini API key: not present on this PC (no `gemini_api_key.txt`, no `GEMINI_API_KEY`).

## 2. Offline checks (all batch mode, all PASS)

- `test_vision_offline`: 6/6 PASS.
- `test_vlm_offline`: Part 1 11/11 PASS. Part 2 skipped (no key).
- `UR_FK_Lab_KEY('UR3e')`: ALL TESTS PASS.
- `checkcode` on all 26 non-archive `.m` files: 3 cosmetic messages, no changes made:
  - `UR_HardwareSmokeTest.m` L138 "Value assigned to variable might be unused" (`ur = []`)
  - `UR_HardwareSmokeTest.m` L328 "Extra comma is unnecessary"
  - `test_vlm_offline.m` L23 "use isscalar instead of length comparison"

## 3. Smoke test, dry run (this folder, 2026-10-28_183517)

Command (batch, allowed by CLAUDE.md rule 1):
`UR_HardwareSmokeTest(DryRun=true, RobotIP='192.168.1.10', Model='UR3e', TCPOffset=[0 0 0], SkipCamera=true, SkipGenAI=true)`

Results: 1 FAIL, 1 WARN (RealSense), 5 SKIP, rest PASS. Connect took 3.20 s.

- readJointConfiguration: deg = [-0.74, -51.6, -109.11, -108.68, 88.42, 175.66]
- readCartesianPose: [1.6334, 0.0284, 3.1331, 0.2052, -0.1387, 0.5266]

### Section 2 finding (FK vs reported pose) - IMPORTANT, do not "fix" the FK files

Orientation: the reported pose(1:3) = [1.6334 0.0284 3.1331] equals the ZYX Euler angles
[yaw pitch roll] of the Lab 3 PoE FK rotation to all four printed decimals. The rotation
vector form does NOT match ([2.1325 2.2706 -0.0206]). Conclusions:

1. `readCartesianPose` elements 1:3 are ZYX Euler angles [thetaz thetay thetax], radians,
   of the tool rotation in the robot base frame. Not a rotation vector.
2. The Lab 3 PoE model's base frame IS the robot's base frame. No 180 degree base yaw.
   The "with 180 deg base yaw" rows are irrelevant; the as-is rows are the ones to use.
3. The joint sign convention `[1 -1 -1 -1 -1 -1]` and `hw2screw` are correct on hardware
   (the orientation would not match otherwise).

Position: FK flange [0.1346 -0.1353 0.3220] m vs reported [0.2052 -0.1387 0.5266] m,
error 216.5 mm with TCPOffset=[0 0 0]. The difference is mostly +0.205 m in base Z while
the tool Z axis points DOWN (tool z in base is about [0.01 -0.03 -1.00]), so no gripper
TCP explains it. Implied tool-frame offset would be [-0.0136 0.0720 -0.2037] m (nonsense).

RESOLVED (root cause, confirmed in the MathWorks package source): running the same joint
angles through the Lab 3 FK for every model in `ur_link_lengths` gives

    UR3e  err 216.5 mm      UR5e  err 0.0 mm      UR10e 224.1 mm     UR16e 68.2 mm

The arm on the bench is a UR3e (Ryan confirmed by eye). The pose MATLAB reports is the
UR5e forward kinematics of the live joint angles because:

- `urRTDEClient(ip)` defaults `CobotName` to `'universalUR5e'`
  (`@urRTDEClient\urRTDEClient.m` line 143) and builds a `rigidBodyTree` with `loadrobot`.
- `readCartesianPose` does NOT read `actual_TCP_pose` from the robot. It reads the joint
  angles and runs `computePoseFromJointAngles` on that rigid body tree
  (`manipulatorRTDEInterface.m` lines 276-309 and 1371-1394), returning
  `[tform2eul(T) tform2trvec(T)]`, i.e. ZYX Euler then xyz, of the model's last body `tool0`.
- `sendCartesianPoseAndWait` solves `inverseKinematics` on the same tree and streams joint
  targets (`interpolateCartesianPoses`, line 1267 on).

Consequences for the labs:

1. Every script must construct the client with the real model:
   `urRTDEClient(robotIP, 'CobotName', 'universalUR3e')`. Without it, on a UR3e,
   `readCartesianPose` is wrong by about 0.2 m and `sendCartesianPoseAndWait` would drive the
   arm to UR5e-IK joint angles, i.e. the wrong place. Labs 5 and 6 and smoke-test section 5
   depend on this. Package-supported names: universalUR3, UR3e, UR5, UR5e, UR10, UR10e,
   UR16, UR16e (no UR7e/UR12e/UR20/UR30).
2. The pendant TCP never enters `readCartesianPose` or `sendCartesianPoseAndWait`. Both work
   on the model flange (`tool0`). The smoke test's `TCPOffset` option should therefore stay
   [0 0 0]; section 2 is a model-vs-model check, not a pendant check. The pendant TCP and
   payload still matter for the robot's own safety limits and for `actuateGripper`, but not
   for where MATLAB thinks the tool is. Lab 5's "teach a reference pick pose, replace only
   X and Y" approach is self-consistent because the same model is used to read and to move.
3. The Lab 3 manual sentence about the base frame: no 180 degree yaw is needed. The
   MathWorks e-series tree is already rotated to match the hardware base frame, and the
   Lab 3 PoE model agrees with it exactly (orientation matched to 4 decimals).
4. `readCartesianPose` layout `[thetaz thetay thetax x y z]`, ZYX Euler in radians, metres,
   is confirmed from the source. Smoke-test section 5 (the +2 cm move) is now a check of the
   IK path rather than of the layout.

### Dry run 2 after the fix (folder 2026-10-28_184102)

Same command, smoke test now passes `CobotName = universalUR3e`. Result: 0 FAIL, 1 WARN
(RealSense), 5 SKIP. readCartesianPose = [1.6334 0.0284 3.1331 0.1346 -0.1353 0.3220],
FK position vs reported 0.0 mm as-is (381.7 mm with 180 deg yaw, confirming no yaw is
wanted). Connect 1.57 s. This is the baseline for the motion run.

### Motion run (folder 2026-10-28_184836), run by Ryan from the MATLAB desktop

`UR_HardwareSmokeTest(RobotIP="192.168.1.10", Model="UR3e", TCPOffset=[0 0 0], SkipCamera=true, SkipGenAI=true)`
Arm had been jogged to deg = [0.08, -90.7, -86.15, -94.42, 86.9, 176.01] beforehand.
Result: 2 FAIL, 1 WARN, 2 SKIP out of 23.

- Section 1 and 2: PASS, FK vs reported 0.0 mm again at the new pose.
- Section 3 (sendJointConfigurationAndWait, elbow +5 deg and back, EndTime=3): FAIL.
  Returned [0 0] (timeout both ways), max joint error 4.477 deg out and 4.263 deg back,
  16.4 s total for two calls, i.e. each call hit the 8 s limit (EndTime 3 + DefaultTimeOut 5).
  The arm moved only about 0.5 deg of 5 in the first 8 s and was about 4.3 deg from the
  start pose after the second call, so the first movej was still running slowly while the
  second was issued. See analysis below.
- Section 4 (actuateGripper grip/release): "PASS" in 2.0 s, but see the URServerScript
  finding below: the stock script does NOT drive a gripper.
- Section 5 (sendCartesianPoseAndWait +2 cm): PASS, returned [1 1], dZ +20.0 mm, dXY 0.0,
  dRot 0.000, return error 0.0 mm. The IK path on the UR3e model works end to end.

### URServerScript finding: gripper commands are stubs in the stock script

The script shipped in the support package
(`...\urseries\resources\URServerScript.script`, the one copied to the pendant) has the
Robotiq calls commented out:

    def programGrip():     # rq_activate_and_wait() / rq_close() are comments
    def programRelease():  # rq_activate_and_wait() / rq_open()  are comments

so `actuateGripper(ur,'grip')` only prints "Grip action initiated on gripper" in the
pendant log and returns. The MATLAB side cannot tell. Ryan confirmed by eye: the fingers
did not move during section 4. MathWorks documents this on the RTDE hardware-setup page
(https://www.mathworks.com/help/robotics/urseries/ug/hardware-setup-for-ur-series-cobots-rtde.html,
"Load and Play UR Program on Hardware"): uncomment `rq_activate_and_wait()` + `rq_close()`
under Task4 and `rq_activate_and_wait()` + `rq_open()` under Task5 for a 2-finger gripper.
A ready copy with those four lines enabled is saved as
`Instructor - Hardware Validation/URServerScript_Robotiq2F.script` (LF line endings, no BOM;
only those four lines differ from the stock file). It must be loaded on the pendant in
place of the stock script, and the Robotiq URCap must be installed. This belongs in the
Lab 2 manual (Part 2, where the script is loaded) and in the smoke test row text.

### Section 3 explanation (speed slider)

Ryan was changing the pendant speed slider throughout the run because the motion looked
too slow, so sections 3 and 5 ran at different slider values. The slider scales
time-parameterized movej, so a 3 s EndTime at slider s takes 3/s seconds while
`sendJointConfigurationAndWait` gives up after EndTime + 5 s and returns false. The elbow
did move out and back (seen by eye), so the commands executed, just slower than the wait.
Rule for the manuals: with EndTime-parameterized moves the pendant slider must satisfy
EndTime/s < EndTime + 5, so 50 percent or more for EndTime 5 s (Lab 4 default). Say
"EndTime sets the pace, leave the slider at 100 percent or at least 50" rather than
"slider 25 percent". Also note that a false return does not stop the robot: the move keeps
running on the controller. To be re-tested with the slider held fixed.

## 4. Code changes

All four are the same one-line change plus a two-line comment. Nothing else touched.

| File | Line | Change | Why |
|---|---|---|---|
| `Instructor - Hardware Validation/UR_HardwareSmokeTest.m` | 140 | `urRTDEClient(opts.RobotIP, 'CobotName', char("universal" + opts.Model))` | model must match the arm (see section 3) |
| `Lab 04 - Pick and Place/UR_PickPlace_Lab.m` | 35 | `urRTDEClient(robotIP, 'CobotName', 'universalUR3e')` | same |
| `Lab 05 - .../Code/UR_VisionPick_Lab.m` | 32 | same | same |
| `Lab 06 - .../Code/UR_VLA_Lab.m` | 33 | same | same |

Still to update on the Mac side (not code, not done today): the Lab 2 manual snippet
(Part 6) and the Lab 4/5/6 manuals wherever they show `urRTDEClient(robotIP)`; the GitHub
mirror; CLAUDE.md rule 3 should list the `CobotName` argument as part of the API. The
robot IP in the manuals (192.168.0.20) also does not match this room (192.168.1.10).

## 5. Open questions

- Why is the reported TCP 0.2 m above the FK flange with the tool pointing down? Pendant TCP
  settings needed.
- Lab 2 manual IP (192.168.0.20) vs this room (robot 192.168.1.10, PC 192.168.1.11).
- Camera and Lab 6 deferred until a USB-C hub and an admin for the RealSense SDK are available.
