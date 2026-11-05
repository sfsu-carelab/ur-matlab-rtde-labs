# Handoff notes - hardware session 3, 2026-11-04 afternoon, lab PC COSE-SEC414-17

Lab PC: COSE-SEC414-17 (Windows 11 Enterprise 10.0.26100), no admin, two USB-C ports.
MATLAB R2024b Update 5.
Robot: UR3e at 192.168.1.10. PC robot NIC "Ethernet 3" static 192.168.1.20/24 (IT set it).
Campus NIC "Ethernet" 130.212.86.144 (DHCP) up at the same time, so internet is available.
Goal today (Ryan): Lab 5 end to end on hardware, then its manual. Then Lab 6.

Read the 2026-10-28_183517 and 2026-11-04_session notes first. All findings there still apply.

Working agreement (Ryan, 2026-11-04): bug fixes do not need asking; structural or content
changes to the labs do.

## 0. Folder consolidation (15:45-15:55)

The session started in a GitHub-layout clone (`2026 Thesis\matlab-rtde`, from
`ur-matlab-rtde-labs-main.zip`). Ryan then downloaded the current Box folder
(`MATLAB + RTDE.zip` -> `2026 Thesis\Labs`, Box layout) and asked for one up-to-date folder.
Hash comparison showed changes in BOTH directions:

- Box download newer: Lab 1 manual Rev2, Lab 2 manual Rev7, Lab 5 manual Rev0 (20 KB vs a
  7 KB stub in the clone), Lab 2 Qualtrics survey wording, robot IP 192.168.1.10 in the four
  scripts and the runbook, CLAUDE.md was the older Mac version.
- Clone newer: CobotName fix in UR_PickPlace_Lab / UR_VisionPick_Lab / UR_VLA_Lab and the
  smoke test (2026-10-28), capture_realsense.m USB Webcams rewrite (2026-11-04), runbook
  webcam rows, smoke test layout fix (today), URServerScript_Robotiq2F.script, all test-logs,
  CLAUDE.md rewritten as the handoff.

Merge, into `Labs` (Box layout), which is now THE working folder:
- Code: clone versions with `192.168.0.20` replaced by `192.168.1.10` (UR_PickPlace_Lab.m,
  UR_VisionPick_Lab.m, UR_VLA_Lab.m, UR_HardwareSmokeTest.m, runbook). capture_realsense.m
  and CLAUDE.md copied as-is, then CLAUDE.md updated for the new folder.
- Manuals, surveys, archives, QArm material, Lab 3 answer key: Box versions kept.
- `URServerScript_Robotiq2F.script` and `test-logs/` copied into `Instructor - Hardware Validation`.
- GitHub-only files (README.md, LICENSE, CITATION.cff, .gitignore, resources/camera-setup
  CAD and the RealSense docx) parked in `2026 Thesis\github-mirror-extras`.
- Verified by MD5: every clone file is either identical to a Labs file or one of the 11
  expected supersessions. Then deleted: the clone folder and both zips.

Note for the Mac side: the Box copy never received the 2026-10-28 CobotName fix or the
2026-11-04 capture_realsense rewrite until this merge. Upload `Labs` back to Box.

## 1. Environment findings (start of session, 15:30)

- ping 192.168.1.10: 3/3 replies, <1 ms. TCP 30004: open (Test-NetConnection from 192.168.1.20).
- UR support package: installed (ProgramData, same path as PC 21). `urRTDEClient` on path.
- USB Webcams support package: NOT installed at the start. Ryan installed it from Add-Ons at
  15:42. State at 15:53: package files present at
  `C:\ProgramData\MATLAB\SupportPackages\R2024b\toolbox\matlab\webcam\supportpackages`
  (webcam.m, webcamlist.m, mex files), the path file
  `toolbox\local\path\hardwaresupportpkgs_matlab_webcam.phl` exists, and
  `matlabshared.supportpkg.getInstalled` returns 2 packages. BUT
  `appdata\installedProductData.json`, `prodcontents.json` and `compcontents.json` still list
  only the UR package (last written 11/03), and a fresh batch MATLAB has no `webcam` on its
  path (`which webcam` empty, 4 probes 15:49-15:53). Looks like the installer never ran its
  final registration step. Asked Ryan to finish the installer dialog and try `webcamlist` in
  the desktop.
- Camera: D435i on a USB-C port. Windows enumerates "...435i RGB" and "...435i Depth", status
  OK (USB\VID_8086&PID_0B3A).
- 16:01 FIRST FRAME CAPTURED (batch, scratchpad cam_probe.m with the package folder addpath'ed
  by hand as a diagnostic). webcamlist = {"...435i Depth", "...435i RGB"}. RGB camera
  AvailableResolutions: 1920x1080, 1280x720, 960x540, 848x480, 640x480, 640x360, 424x240,
  320x240, 320x180 (the USB 3 table; PC 21 on the USB 2 cable showed only 4 modes).
  Pinned 1280x720. First snapshot 0.58 s, next 5 in 0.12 s. Saved cam_probe_1280x720.png here.
  Image: bird's-eye view of the table, arm and gripper in the top centre, conveyor at left, a
  teal block and an orange-red block on the black table. Very dark with a strong cyan cast
  (mean RGB [16.3 52.0 37.4]); the LED strip seems to be the only light. Room lights on would
  help the HSV thresholds a lot.
- Add-On installer, second attempt: "The support package you selected is already installed.
  If you wish to reinstall it, uninstall it first from the Add-on Manager." But the Add-On
  Manager does not list it, so it cannot be uninstalled there.
- 16:05 ROOT CAUSE (support package registration on shared lab PCs): the installer log
  (`%LOCALAPPDATA%\Temp\mathworks_924414657.log`) says "Completed Install ... Register support
  package with Add-Ons: USBWEBCAM" at 15:42:03, but the registry files
  `C:\ProgramData\MATLAB\SupportPackages\R2024b\appdata\{installedProductData,prodcontents,compcontents}.json`
  are owned by SFSU\923388190 (the account that installed the UR package on 2026-11-03) with
  BUILTIN\Users = ReadAndExecute only. The appdata folder itself gives Users Write, so the
  installer could drop the package files and XML but could not update the three JSON files;
  it does not report that. Result: files on disk, package invisible to MATLAB startup and to
  the Add-On Manager. A write test from this account: "Access to the path ... is denied".
  Any support package installed from a student/instructor account on a PC provisioned this way
  will fail the same way. The UR package only works because 923388190 installed it.
- 16:07 Cleaned the half-install by hand (all webcam-specific, all created today): removed
  `toolbox\matlab\webcam`, `toolbox\matlab\webcamlivetaskexample`, `resources\MATLAB\*\webcam`,
  the webcam XML/JSON under `appdata\components|files|products`, and the two webcam `.phl`
  files under `toolbox\local\path`. UR package verified intact afterwards.
- Permanent fix (needs IT or account 923388190): install "MATLAB Support Package for USB
  Webcams" from that account on each lab PC (as the UR package was), or grant Users Modify on
  the three JSON files.
- Tried: `matlabshared.supportpkg.setSupportPackageRoot` to a folder under the user profile
  (would register both packages per user). Ryan: it asks for admin on this PC. Dead end.
- 16:15 FIX FOR THIS ACCOUNT, no admin: the `MATLABPATH` environment variable. Verified in
  batch that a folder listed there is on the path at startup (`which detect_block` resolved
  through it). Set as a USER environment variable (HKCU, no admin) to
  `C:\ProgramData\MATLAB\SupportPackages\R2024b\toolbox\matlab\webcam\supportpackages`.
  Ryan then reinstalls the package (files land in that folder again; registration still
  fails silently, which no longer matters) and restarts MATLAB. `webcamlist` then works with
  no addpath. To undo: delete the user variable MATLABPATH. This is PC/account configuration,
  not lab code; capture_realsense.m is unchanged. The Add-On Manager will keep saying the
  package is not installed, and the installer will keep saying it is.
- 16:16 VERIFIED. Ryan reinstalled, restarted the desktop: `which webcam` resolves, `webcamlist`
  shows both 435i entries. Batch smoke test dry run WITH the camera section
  (`2026-11-04_161635`): 0 FAIL, 0 WARN, 4 SKIP of 21. capture_realsense 720x1280x3 in 2.8 s
  -> camera.png; detect_block default green = 331576 px (the whole cyan-lit table, expected).
  Lab 5 Part 1 (camera path) is done on this PC.
- Gemini key: not checked yet.

## 2. Offline checks (batch)

- `test_vision_offline`: 6/6 PASS.
- Smoke test dry run `UR_HardwareSmokeTest(DryRun=true, RobotIP='192.168.1.10', Model='UR3e',
  TCPOffset=[0 0 0], SkipCamera=true, SkipGenAI=true)` -> folder `2026-11-04_153627`:
  - urRTDEClient connect 2.75 s PASS; readJointConfiguration deg = [0.22, -91.22, -66.34, -94.57, 86.9, 176.02];
    readCartesianPose = [1.6244, 0.0727, 2.8335, 0.3122, -0.1348, 0.4154]. PASS.
  - FAIL x3: "Lab 3 folder", "Lab 5 code folder", "Lab 6 code folder" not found in the GitHub
    layout clone (see section 3 fix). Sections 2 and 6 skipped as a result.
  - WARN: USB Webcams package not on path.
- Rerun after the fix -> folder `2026-11-04_153915`: 0 FAIL, 1 WARN (webcam), 5 SKIP. Lab
  folders found; FK position vs reported 0.0 mm as-is (680.2 mm with 180 deg yaw); Euler
  matches to 4 decimals again. Connect 1.52 s.
  (Both of these ran in the clone; the logs were copied into this folder's siblings.)

## 3. Code changes

| File | Line | Change | Why |
|---|---|---|---|
| `Instructor - Hardware Validation/UR_HardwareSmokeTest.m` | 61-66 | after `root = fileparts(here)`, if `root` has no `Lab 0*` folder and its parent has `labs/`, use the parent as root (4 lines + comment) | GitHub layout: the file sits two levels below the repo root, so `labs/lab3*` etc. were never found. Box layout unchanged. |
| `UR_PickPlace_Lab.m`, `UR_VisionPick_Lab.m`, `UR_VLA_Lab.m`, `UR_HardwareSmokeTest.m`, runbook | IP lines | `192.168.0.20` -> `192.168.1.10` (carried over from the Box side during the merge) | matches the room |
| `Lab 05/Code/capture_realsense.m` | 41-46 | settle loop 15 -> 30 snapshots, with a 2-line comment | measured 16:28: D435i RGB auto-exposure mean brightness frame 1-5 = 7/23/12, frame 10 = 21/50/33, frame 15 = 51/92/70, frame 20 = 74/112/89, frame 25 = 82/113/94, frame 30 = 87/113/96. At 15 frames the lab got a half-exposed image and no threshold worked. 30 frames take about 1.5 s. checkcode clean. |
| `Lab 04/UR_PickPlace_Lab.m` (moveTo), `Lab 05/Code/UR_VisionPick_Lab.m` (moveToJ, moveToC), `Lab 06/Code/UR_VLA_Lab.m` (moveToJ, moveToC), smoke test sections 3 and 5 | helper functions at the bottom of each file | APPROVED BY RYAN 16:40 ("proper fix"). After each send*AndWait the script now calls a new local `waitForArrival(readFcn, target, idx, tol)` that polls readJointConfiguration (tol 0.5 deg, all joints) or readCartesianPose (tol 2 mm, position only) every 0.2 s until the robot is at the target AND not moving between reads, cap 60 s. The library's boolean is no longer used for the decision. Error messages now say "within 60 s". Smoke test rows report "library returned [a b], arrived [c d]" and PASS on arrival. | The MathWorks wait gives up at EndTime + 5 s where 5 s is a private constant (`manipulatorRTDEInterface.DefaultTimeOut`, not settable); the documented 'TimeOut' name-value pair is ignored by `calculateTimeOut`. The pendant slider scales the move but not the wait, so below about 50 percent every move "failed" while the robot kept moving. Ryan wants to run everything slowly at will. Always waiting (not only on false) also covers a late "done" from move N being read as move N+1's result. Offline test (scratchpad test_wait.m): slow 3 s move -> true in 3.4 s; stalled -> false at the cap; Cartesian idx 4:6 only -> true; jitter then settle -> true. checkcode: 0 messages on the three lab scripts. |
| `Instructor - Hardware Validation/UR_HardwareSmokeTest.m` | findLab, ~L440 | when the pattern names the folder itself (`Lab 05*/Code`), `dir` returns `.` first; return `hits(1).folder` instead of `...\Code\.` | cosmetic path in the log rows (seen in run `2026-11-04_155603`) |
| same four files, `waitForArrival` (18:45) | helper now `waitForArrival(ur, readFcn, target, idx, tol)` plus a new local `serverIdle(ur)` | Arrival additionally requires `readMotionStatus(ur)` to report a state other than 'Executing', then `pause(0.3)` before returning. Call sites pass `ur` as the first argument. | FOUND ON HARDWARE (Lab 5 first pick, 25 percent slider): step 1/7 (Cartesian approach) arrived, step 2/7 (10 cm descent) never started; the arm sat exactly at the approach pose for the whole 60 s cap, no pendant popup, no library error. Cause, from the library source: `sendCartesianPoseAndWait` interpolates the pose in 5 cm steps (`CartResolution`), solves IK per step (an IK failure would throw `RTDEIKFail`, which did not happen), then `followJointWaypoints` writes the waypoints into the server script through the "fill" command (6) and starts them with command 7; the server runs them as a chain of movej calls with blend 0 at both ends and cannot read the command register until the last movej returns. The old `waitForArrival` declared arrival when the pose was within 2 mm and had not changed in 0.2 s; at a low slider the final millimetres are slower than that, so the next command's fill and run were written while the server was still blocked in the previous move and were lost (server read 0 afterwards and cleared its buffers). The server's done flag (output integer register 1, read by `readMotionStatus`: 1 = Executing, 2 = Succeeded) closes the race. Also explains the stepped look of the approach move Ryan saw: each 5 cm segment decelerates to a stop (library design, not our code). Lint 0 on the labs. Live check while parked: `readMotionStatus` = Succeeded. |
| `URServerScript_Robotiq2F_PolyScopeX.script` (19:10) | globals + programGrip/programRelease + resetTrajectoryParameters | New globals `gripperForcePercent = 0`, `gripperSpeedPercent = 50`, `lastGripperCommand = 0`. Grip/release now: write output int register 1 = 1, `rq_activate_and_wait()`, `rq_set_force_norm(...)`, `rq_set_speed_norm(...)`, `rq_close_and_wait()` / `rq_open_and_wait()`, register 1 = 2, `global lastGripperCommand = 4/5`; the branch only runs when `lastGripperCommand` differs (MATLAB never resets the command register after a gripper command, so the stock loop re-ran the close every cycle). `resetTrajectoryParameters` clears it. | Second pick attempt: steps 1-3 worked (descent and grip), step 4 (lift) never started. Same race as before, different blocker: the server sat in `rq_close_and_wait` for about 1 s while the lab paused 0.5 s and then wrote the lift's waypoints into a blocked server. Also the block was crushed: the PSX plugin closes at the last force set. Batch probe grip_probe2.m after reloading: release shows Executing at 0.1 s and Succeeded at 1.8 s (the open takes 1.7 s at 50 percent speed), arm did not move. |
| `UR_PickPlace_Lab.m`, `UR_VisionPick_Lab.m`, `UR_VLA_Lab.m` grip() + new `waitForGripper(ur)` | after `actuateGripper` | wait up to 1 s for the status flag to leave 'Succeeded' (the server picked the command up), then up to 10 s for it to come back, then pause 0.3 s; with a server script that does not report the flag this degrades to a 1.3 s wait. | see row above. Third pick attempt 19:25: all seven steps ran, "Vision-guided pick complete in 35.9 s" at a 25 percent slider, block picked and placed. LAB 5 WORKS END TO END. |
| `UR_VisionPick_Lab.m`, `UR_VLA_Lab.m` moveToC (19:40) | `sendCartesianPoseAndWait` replaced by `followCartesianWaypoints(ur, [mid; pose], WaypointTimes = [endTime/2, endTime], BlendRadius = 0.02)` where mid is the midpoint of the straight line (target orientation) | Ryan: the approach ran "in steps, not a smooth trajectory". Library source: sendCartesianPoseAndWait interpolates the line in 5 cm pieces (`CartResolution`) and sends them with `DefaultBlendRadius = 0`, a private constant that the documented BlendRadius pair cannot change, so every piece decelerates to a stop. followCartesianWaypoints runs the same interpolation but honours BlendRadius for interior points (first and last stay 0, and the last two segments cap the blend at 0.8 x segment length). The parser needs at least two rows (it indexes WaypointTimes(2)), hence the midpoint. The lab's own waitForArrival does the waiting. NOT YET RUN ON HARDWARE at the time of writing; if the server's one-movej-per-thread pattern turns out not to blend, the fallback is IK with the toolbox model plus one joint move, which needs Ryan's OK because it leaves the Cartesian API. |
| `UR_VisionPick_Lab.m`, `UR_VLA_Lab.m` moveToC + new `poseToJoints(ur, pose, q0)` (17:50) | moveToC now: `q = poseToJoints(ur, pose, q0)`, `sendJointConfigurationAndWait(ur, q, EndTime = endTime)`, then the usual waitForArrival on readCartesianPose. poseToJoints: `inverseKinematics` on `ur.RigidBodyTree` (public property), solved in 5 cm steps along the straight line from the current pose (`transformtraj`), each step seeded with the previous solution, final q returned; error `:ikFailed` if PoseErrorNorm > 1e-3. | The followCartesianWaypoints version (one row above) ran the full pick (27.2 s) but MATLAB warned "Ignoring waypoint times because blend radius is specified" and Ryan still saw a jerky approach: every Cartesian call in this toolbox executes the path as 5 cm movej pieces, with or without blend. Ryan: "why cant you just have one waypoint above the block and go to it". So the pose is converted to joint angles and sent as ONE time-parameterized joint move. CAUTION for anyone repeating this: `loadrobot('universalUR3e')` on its own is NOT the toolbox's frame; the client rotates its tree 180 degrees about Z (ROS base vs base_link), so FK from a plain loadrobot gives X and Y with the wrong sign (884 mm off at the touch pose). `ur.RigidBodyTree` reproduces readCartesianPose to 0.09 mm. Read-only test with today's numbers: descent IK from the approach pose lands on the joints Ryan jogged to within 0.0 deg (same elbow/wrist configuration), lift returns to the approach joints exactly, approach solve 0.57 s, sideways bow of the joint-interpolated 10 cm descent 4.1 mm at mid-stroke and 0 at the ends. Lint 0. This drops sendCartesianPoseAndWait from the labs; manual Table 1 and the learning objective are updated to match. HARDWARE VERIFIED 18:05: Ryan reran the full pick from the desktop, "worked great", approach/descent/lift each one smooth motion, no warnings. Test values then reverted to the NaN placeholders (scratchpad revert_test_values.ps1) and the TASK 2/4/5 comments reworded for the fixed camera and UR_CalibrateCamera. |
| `Lab 05/Lab 5 - Vision-Guided Pick and Place_Rev1.docx` (NEW, from Rev0; 17:58) | 26 paragraph/text replacements, done by exact string replacement in word/document.xml and re-zipped with .NET ZipFile (no Word/pandoc on this PC): accompanying files + UR_CalibrateCamera.m; camera is a FIXED bird's-eye mount on USB 3 (Ryan's decision) via the MATLAB Support Package for USB Webcams, no RealSense SDK; imaging pose = parking pose out of the picture; Table 1 row sendCartesianPoseAndWait -> sendJointConfigurationAndWait with poseToJoints; learning objective to match; Part 4 Task 4 rewritten around UR_CalibrateCamera (spread the points, red cross check, r to retake, placement 1 = ref_pick_pose, paste block); Part 5 ref_pick_pose from the script; Task 6 warning now says every move waits for arrival at any slider and adds a paragraph on one-joint-move motions and the gentle gripper force (gripperForcePercent); Part 6 depth via the second webcam device; Q1 reworded for the fixed camera. Verified by re-extracting the text: 0 "wrist", 0 sendCartesianPoseAndWait, 0 em dashes. Rev0 kept beside it. Not opened in Word (none here): open it once on a PC with Word before handing out. | Ryan: "update the lab docs" and "update lab 5 according to what we found today and what the student workflow should be now". |
| `Lab 02/Lab 2 - MATLAB and RTDE Installation Setup_Rev8.docx` (NEW, from Rev7; 18:00) and `Lab 02/URServerScript_Robotiq2F_PolyScopeX.script` (copy of the Instructor file) | Part 2 now hands out URServerScript_Robotiq2F_PolyScopeX.script from the Lab 2 folder (the "Open MATLAB... installationFilePath... copy from the support package" steps removed, replaced by "Download from the Lab 2 folder on Box; do not use the stock URServerScript.script, it was written for PolyScope 5"); explanation paragraph rewritten; every other mention of the file name updated (heading, program-tree check, USB and Select File steps). Same XML-edit method, Rev7 kept. | The stock MathWorks script does not compile on PolyScope X (rq_close/rq_open undefined); Ryan confirmed the Lab 2 change ("2. yes"). Lab 4 Rev1 L149 only says "the URServerScript node (built in Lab 2)", left as is. |
| GitHub push (18:10) | Commit `819be74` "Hardware session 2026-11-04 (PC17): ..." (34 files, author ryantcullen) exists only in the local MinGit clone `C:\Users\924414657\2026 Thesis\ur-matlab-rtde-labs` (MinGit 2.56 in `%LOCALAPPDATA%\Programs\MinGit`, core.autocrlf=input because the repo stores LF and Box files are CRLF). Ryan declined to make a token on this PC, so the commit is exported as `ur-matlab-rtde-labs-push.zip` (48.8 MB, in `2026 Thesis`) containing the staged GitHub-layout tree plus `ur-matlab-rtde-labs.bundle` (the commit itself) for pushing from his Mac. Staging script: scratchpad build_github_layout.ps1 (recreated from this table if lost: Box folder -> mirror layout, latest _RevN docx renamed without suffix, excludes KEY/instructor Lab 3, archive/, QArm, gemini_api_key.txt, calibration_results.txt). | NOT PUSHED at the end of this session. Check the GitHub history before assuming this session's work is on the mirror. |
| new `Lab 05/Code/UR_CalibrateCamera.m` (19:50) | whole file | APPROVED BY RYAN ("another script is cool"): guided Part 4 calibration at the MATLAB prompt. Per placement: Enter -> picture + detect_block with overlay (retake with r, retry on no blob); Enter -> readCartesianPose. Never moves the robot. Ends with fit_pixel_to_base residuals, the UV/XY/ref_pick_pose lines to paste, and calibration_results.txt next to the script. Settings block duplicates IP and thresholds (TODO). | Ryan: "the calibration should be done by students so the script should walk you thru it, not do it in terminal like we did." Camera and pose paths are the same calls exercised today; the prompt flow is not hardware-tested yet (needs a person at the pendant). |

Smoke test dry run from the consolidated `Labs` folder (`2026-11-04_155603`): 0 FAIL, 1 WARN
(webcam), 5 SKIP. Connect 1.55 s, FK 0.0 mm. The merge is verified working.

Leftover: the empty folder `2026 Thesis\matlab-rtde` could not be removed because the Claude
Code session was started inside it. Delete it by hand after the session (it has 0 files).

checkcode on the smoke test: the same two cosmetic messages as on 2026-10-28 (now L145 and
L337), nothing new.

TEMPORARY, for the hardware run only (revert before push/Box upload):
`Lab 05/Code/UR_VisionPick_Lab.m` L42 imaging_pose = [0.95 -71.2 -33.84 -142.19 89.36 180.96],
L49-50 hsvLow/hsvHigh = red band [0.95 0.50 0.30]/[0.05 1.00 1.00]. Each line carries a
"HARDWARE TEST 2026-11-04" comment with the release value. Since 18:30 UV/XY (five rows,
see lab5_values.txt), ref_pick_pose and place_pos are also filled in with the same marker;
all of them go back to NaN before release (the UV/XY tables back to four nan rows).

16:25 camera: after Ryan moved the camera, two batch captures failed with "The camera did
not return a frame for this resolution" / "Timeout occurred while trying to get a frame";
the device instance IDs are unchanged (not replugged) and the USB 3 mode list is still
there. Suspect the desktop MATLAB holds the camera. Also confirmed in this run: with the
user MATLABPATH variable set, batch MATLAB finds webcam with no addpath.

## 3b. Gripper on PolyScope X: URServerScript_Robotiq2F.script does not compile (16:50)

Ryan loaded `URServerScript_Robotiq2F.script` on the pendant: compile error "rq_close is not
defined" (same as "a while ago"). So on this PolyScope X robot the PolyScope 5 Robotiq URCap
functions (rq_activate_and_wait, rq_close, rq_open) do not exist in the program scope. The
MathWorks hardware-setup page only documents those names (PolyScope 5 URCap).

Research (web, 16:50-17:00), what is known:
- Robotiq lists 2F-85 as supported on PolyScope X via a URCapX plugin (beta); its PolyScope X
  docs are behind a download form, not indexed. No public list of script functions found.
- The only PolyScope X Robotiq script call found anywhere is from Robotiq's knowledge base
  (Dec 2025, "Automatically Scan for a Robotiq Gripper in Polyscope X"):
      set_tool_communication(True,115200,0,1,1.0,3.5)
      gripper_connection_status=driver_gripper_client.scanBlocking()
  i.e. the PSX plugin exposes an OBJECT `driver_gripper_client` with methods, not rq_ functions.
  Activate/open/close method names are not published there.
- UR forum threads (42885 June 2026, 43338 Sept 2026) on 2F-85 + PolyScope X mention URCapX
  3.28.0.122467, a user claim that "script functions are the same as PolyScope 5", and nothing
  usable. The old DoF forum is a read-only archive (closed June 2023).
- The PSX "Scan" step: the gripper port is only configured when the Scan button is pressed
  before running a program, unless the snippet above is in the program.

RESOLVED (17:20). Ryan supplied the Robotiq PolyScope X plugin download
(`Robotiq URCap_Polyscope X for Adaptive Grippers_3.28.0 beta.zip`: user guide PDF plus
`Robotiq-3.28.0.122467.urcapx`). The .urcapx is a gzip tar holding two Docker images; the
backend image `robotiqbff` contains `app/robotiq-bff.jar`, and inside it
`com/robotiq/urcap/gripper/impl/GripperXmlRpcPreamble.script` is the URScript preamble the
plugin injects into every program (frontend `robotiq-application.worker.js` calls
`getGripperPreambleScript()` for the program preamble). The user guide PDF has no script list.

What the preamble defines (gripper socket "1" = slave id 9, all talk to the plugin's driver
container through `driver_gripper_client = rpc_factory("xmlrpc", ...)`):
- `rq_activate_and_wait(gripper_socket="1")` activates only if not already activated
- `rq_close_and_wait(gripper_socket="1")`, `rq_open_and_wait(gripper_socket="1")`
- `rq_move_and_wait_norm(position, gripper_socket="1")` (0..100 percent), `_mm`, `_inches`
- `rq_set_speed_norm(speed, ...)`, `rq_set_force_norm(force, ...)` (0..100)
- `rq_is_object_detected()`, `rq_current_pos_norm()`, `rq_is_gripper_activated(slave_id=9)`,
  `rq_is_gripper_connected(slave_id=9)`, `rq_activate_all_grippers(reset=False)`, `rq_reset()`
- NOT defined: `rq_close()`, `rq_open()`, `rq_move()` (the PolyScope 5 non-blocking names).
  That is the whole compile error. The error named rq_close and not rq_activate_and_wait,
  which confirms the preamble is present in the program scope.
- No scan call is in the preamble; the Dec 2025 knowledge-base snippet
  (`set_tool_communication(...)` + `driver_gripper_client.scanBlocking()`) is only needed when
  the gripper has not been scanned from the Robotiq page before Play. It was not added to the
  server script. If actuateGripper does nothing, scan the gripper from the Robotiq application
  page first, then Play.

Fix: new file `Instructor - Hardware Validation/URServerScript_Robotiq2F_PolyScopeX.script`
(copy of the MathWorks Robotiq2F script, LF endings, no BOM) with programGrip() calling
`rq_activate_and_wait()` then `rq_close_and_wait()`, and programRelease() calling
`rq_activate_and_wait()` then `rq_open_and_wait()`. Nothing else changed. CLAUDE.md now points
at the PolyScopeX file. The _and_wait calls block the server loop for the gripper travel time
(well under 1 s on a 2F-85), which is fine because MATLAB's actuateGripper does not wait anyway.
VERIFIED (17:35): the PolyScopeX script compiled and played green on the pendant on the first
try. Batch probe (scratchpad grip_probe.m: connect, actuateGripper grip, 3 s, release, 3 s)
with the arm parked at the imaging pose: actuateGripper returned in 0.01 s each, the 2F-85
closed and opened as commanded (Ryan watched), zero joint drift. No Scan was needed. So the
MathWorks actuateGripper path works on PolyScope X with this script. First time the gripper
has worked from MATLAB on this robot.

## 4. Lab 5 numbers

(see lab5_values.txt when filled)

### HSV probe on the 16:01 frame (scratchpad hsv_probe.m, detect_block from the lab)

Sampled HSV (median): orange-red block H 0.040 S 0.88 V 0.17; teal block H 0.457 S 1.00 V 0.19;
black table H 0.403 S 0.77 V 0.11. The whole table reads as dark cyan because of the LED strip,
so the teal block is only 0.05 in hue away from the background and both blocks are below the
lab's default V floor of 0.25.
- lab default green band: 34 blobs, largest 91k px (the table itself). Useless as is.
- red wrap [0.95 0.5 0.25]-[0.05 1 1]: 0 blobs (V too low).
- red wrap wide [0.93 0.4 0.2]-[0.08 1 1]: 1 blob, 391 px at [592.8 695.4] = the red block,
  but it sits at the bottom edge of the frame (v 695 of 720) and is partly cut off.
- teal [0.45 0.35 0.25]-[0.58 1 1]: 25 blobs, largest 75k px (background). Useless.
Conclusion: lighting, not thresholds. Room lights on (or any white light) should fix both the
darkness and the cyan cast; then re-probe. Also move the blocks into the middle of the frame.

### HSV probe on the 16:16 frame, lights on (test-logs/2026-11-04_161635/camera.png)

Ryan turned the room lights on and moved the camera so only the robot base is in frame.
Medians: red block H 0.033 S 0.81 V 0.65; teal block H 0.478 S 0.95 V 0.51; table H 0.436
S 0.58 V 0.25 (still a cyan cast, but now separable).
- red, the manual's example band [0.95 0.5 0.3]-[0.05 1 1]: block = largest blob 4598 px at
  (699.4, 538.0). Strays 1109 and 528 px = the red pouch bottom right.
- teal [0.47 0.55 0.35]-[0.54 1 1]: block = largest blob 2952 px at (817.3, 371.2). Strays
  1090 and 843 px = a blue object behind the base and a patch on the conveyor edge.
- lab default green band: 34 blobs, largest 209687 px (table). Students must retune, as the
  manual already says.
Values recorded in lab5_values.txt. Lab 5 Part 1 (camera) and Part 3 (thresholds) are done.

## 5. Open items

- [x] USB Webcams support package installed (Ryan, 15:42) but NOT registered, see section 1
- [ ] `webcamlist` shows "...435i RGB" and `snapshot` returns a frame at 1280x720 (batch probe
      script: scratchpad cam_probe.m; saves cam_probe.png)
- [x] Smoke test root-folder fix for the GitHub layout (done, section 3)
- [x] Folder consolidation (section 0)
- [ ] Pendant running URServerScript_Robotiq2F.script, speed slider 100 percent
- [ ] Lab 5: imaging pose, HSV thresholds, 4-point calibration, ref_pick_pose, place_pos
- [ ] Gemini key, test_vlm_offline Part 2 live
- [ ] Push to the GitHub mirror (rebuild the GitHub layout from Labs + github-mirror-extras)
- [ ] Ryan uploads `Labs` back to Box through the browser
