# 2026-11-19 (PC 17, Claude alone): a real VLA (Octo) running from MATLAB R2024b

Ryan asked, from his Mac, to pull the repo and "get the VLA working for Lab 6", pointing at
MathWorks File Exchange 184183, "Vision-Language-Action (VLA) Models in Simulink"
(github.com/mathworks/robot-vla-simulink). Nobody was at the robot. Everything below ran in
batch: Python, `matlab -batch`, no robot connection, no camera (the 2026-11-16 frame
`../2026-11-16_lab6_vla/camera_1.png` stood in for the camera). The robot was not moved.

## 1. What the File Exchange item is (corrects the 2026-11-16 notes in one respect)
- It is a REAL VLA, not a pointing model: Octo (`octo-base`, 93M parameters, Berkeley) and
  RT-1-X take one RGB frame plus a sentence and return a 7-element action every step:
  end-effector translation delta (m), rotation delta (axis-angle, rad), gripper (+1 open,
  -1 close). `vla_matlab_in_loop_plan.md` (Mac, 2026-11-16) already had this right and
  ruled it out for three reasons; two of them still hold and one does not:
  - File Exchange says "Requires R2026b and later" (v1.0.5, 12 Aug 2026); the GitHub README
    says R2025b. The lab PCs have R2024b only. STILL TRUE, for the Simulink example.
  - It is an Unreal Engine simulation of a WidowX arm (green-screened onto a Bridge photo),
    and its README sends real hardware to ROS Toolbox. STILL TRUE.
  - "Not our stack": NOT TRUE for the part that matters. The policy block is one MATLAB
    System object (`robotpolicy.m`) that makes two Python calls through `pyenv`:
    `py.octoModel.OctoInference()` once and `model.step(py.numpy.array(img), task)` per
    step. Those two calls work from plain MATLAB R2024b with no Simulink. Verified today.
- Where it runs: a Python 3.10 process started by MATLAB (OutOfProcess), CPU only
  (`jax 0.4.23` CPU wheel, `tensorflow 2.15`), so no CUDA, no WSL2, no admin.

## 2. What was built (all under `C:\Users\924414657\vla-octo`, outside the repo, 2.9 GB)
| Folder | Content | How |
|---|---|---|
| `repo\` | clone of mathworks/robot-vla-simulink (main, 2 commits), reference only | `git clone --depth 1` |
| `win64\python\` | CPython 3.10.4 standalone (python-build-standalone 20220528), the exact build the repo's `installPythonEnv.m` downloads | `Invoke-WebRequest` + `tar` |
| `win64\python\lib\site-packages` | `pip install -r vlapy/requirements.txt -c vlapy/constraints.txt`, then `octo` at commit 241fb35 `--no-deps` (same as installPythonEnv) | `pip_install.log`, `pip_freeze.txt` |
| `vlapy\` | copy of the repo's `vlapy` (octoModel.py, rt1xModel.py) plus `octo-base\` weights | `https://ssd.mathworks.com/supportfiles/robotics/data/octoBaseModel.zip` (552 MB, same URL `installPythonEnv` uses), unzipped next to octoModel.py |
| `tests\` | `octo_probe.py`, `octo_from_matlab.m` and their logs (copied into this folder) | |

ONE FIX needed on top of the MathWorks recipe: the unpinned transitive dependency
`tensorflow-metadata` resolved to 1.21.0, which imports `google.protobuf.runtime_version`
(protobuf 5), while TF 2.15 pins protobuf 4. `from octo.model.octo_model import OctoModel`
failed with `ImportError: cannot import name 'runtime_version'`. Fixed with
`pip install tensorflow-metadata==1.14.0` (brings protobuf 3.20.3, absl-py 1.4.0). If the
environment is ever rebuilt, add `tensorflow-metadata==1.14.0` to the constraints.
Also installed: `pillow` was already present (12.3.0, pulled in by a dependency).

MATLAB side: R2024b supports Python 3.9 to 3.12, so 3.10.4 is fine. `pyenv` on PC 17 was
`NotLoaded` before today; nothing was persisted (the prototype sets it per session).
The "symlinks on Windows" warning from huggingface_hub at load is harmless: the weights
are local, nothing is downloaded.

## 3. Results (CPU, i9-14900K; RTX 4060 unused)
| Where | Load | Step 1, 2 (JAX compile) | Steps 3+ | Log |
|---|---|---|---|---|
| Python 3.10 direct | imports 6.0 s, OctoInference 6.4 s | 5.0 s, 6.7 s | 0.19 to 0.20 s | `octo_probe_python.log` |
| MATLAB R2024b, pyenv OutOfProcess | import 4.1 s, OctoInference 5.7 s | 6.7 s, 6.7 s | 0.20 to 0.22 s | `octo_from_matlab.log` |
| `UR_VLA_Octo_Prototype(DryRun=true, ImageFile=camera_1.png)` | 36.6 s (fresh pyenv) | 6.7 s, 6.9 s | 0.26 s | `dryrun_batch.log`, `octo_run_20261119_125143.csv` |

Actions on the 2026-11-16 frame (red and teal block, checkered paper, gripper at the top of
the frame), task "pick up the red block", same frame fed every step (open loop):

| step | dx, dy, dz (mm) | rot (rad, axis-angle) | gripper |
|---|---|---|---|
| 1 | +12.3, -20.9, -16.0 | +0.018, -0.006, +0.031 | +1 open |
| 2 | +4.2, -11.0, -5.1 | +0.013, -0.000, +0.019 | +1 |
| 3 | +0.9, -7.1, -1.9 | +0.009, +0.007, +0.010 | +1 |
| 4 | -0.1, -4.0, -4.2 | +0.010, +0.001, +0.016 | +1 |
| 5 | +3.7, +1.1, +3.6 | +0.003, -0.008, +0.009 | -1 close |
| 6 to 8 | about 1 to 6 mm | | -1 |

Python and MATLAB give the same numbers to 4 decimals (fixed JAX seed). The 4-step action
chunk plus the equal-weight ensemble makes later steps an average of earlier predictions,
which is why the deltas shrink on a frozen frame. Reading: the policy's prior is "go down
and a little sideways, then close", which is what a Bridge pick looks like. It cannot be
judged on a static frame; the test that counts is closed loop at the robot (section 5).

## 4. New file: `UR_VLA_Octo_Prototype.m` (this folder, instructor prototype, not student code)
MATLAB owns camera, robot and loop; Octo owns the decision:

    capture_realsense -> policy.step -> yaw-rotate, clamp to max_step_m -> keep-out box
    -> poseToJoints + one joint move (Lab 5/6 motion path) -> gripper on change -> repeat

Settings block: `task`, `start_pose` (NaN), keep-out box `xy_min/xy_max/z_min/z_max`
(NaN), `action_scale` 1.0, `max_step_m` 0.02, `action_yaw_deg` 0 (Bridge frame: +x away
from the robot, +y to its left; rotate into our base frame once we know where the camera
looks), `apply_rotation` false (gripper stays pointing down), `confirm_each_step` true
(Enter before every move, q quits), `moveEndTime` 1.5 s. Stops on a target outside the box.
Writes `octo_run_<timestamp>.csv` here (step, policy time, delta, gripper, current and target
pose, executed flag). `checkcode`: 0 messages. Modes:

    UR_VLA_Octo_Prototype                                   at the robot (Ryan, desktop, e-stop)
    UR_VLA_Octo_Prototype(DryRun=true)                      camera + policy, no robot
    UR_VLA_Octo_Prototype(DryRun=true, ImageFile="...png")  fully offline, batch OK (run today)

The motion helpers are copied from `UR_VLA_Lab.m` (waitForArrival with the server done
flag, poseToJoints on `ur.RigidBodyTree`, waitForGripper), so every hardware finding from
2026-11-04 is in. Hard rule 1 applies: Claude never runs it without DryRun.

## 5. Honest assessment: what "working" will take
- What we have now: a pretrained VLA emitting actions inside a MATLAB loop on R2024b, on the
  lab PC, with no GPU, no WSL2, no admin, 0.2 s per step. That is the thesis sentence "MATLAB
  in the loop with a VLA" made real, and a classroom demo for Lab 6 Part 5 or a Lab 7.
- What nobody has shown: Octo zero-shot on a UR3e. It was trained on Bridge (WidowX 250,
  over-the-shoulder camera, 256x256). Our camera is a bird's-eye D435i at 1280x720
  (squashed to 256x256 by the wrapper, as SimplerEnv does with Bridge's 640x480), the
  gripper is a Robotiq 2F-85, the table is black. Expect it to move in a plausible direction
  for a few steps and then wander. SimplerEnv reports Octo-base at roughly 15 to 30 percent
  success on Bridge tasks IN ITS OWN SETUP. The MathWorks example only works because it
  green-screens the simulated WidowX onto a real Bridge photo.
- Three cheap things to try first, at the robot, in this order:
  1. Camera viewpoint closer to Bridge: lower, in front of and to the side of the base,
     looking across the table at about 30 degrees, gripper in the lower middle of the frame.
     A second D435i position (or a phone-camera-style mount) rather than the bird's-eye.
  2. Task wording from Bridge: "put the red block on the checkered paper", "pick up the
     red block". Short, concrete nouns.
  3. `action_yaw_deg` so the policy's +x (away from the robot, toward the camera's far
     side) matches our base frame; `action_scale` 1 to 2.
- To make it reliably succeed on our robot it has to be fine-tuned on our own demonstrations.
  Octo's own fine-tuning is JAX and wants a GPU (Linux or WSL2 CUDA, not this Windows box),
  with data as an RLDS/TFDS dataset. The SmolVLA plan in
  `../2026-11-16_lab6_vla/vla_matlab_in_loop_plan.md` (LeRobot, PyTorch, WSL2 or the
  Jetson, HTTP server) remains the training path; its MATLAB side is the same loop as this
  prototype, only `policy.step` becomes a `webwrite`. The MATLAB demo recorder in that
  plan (Lab 5 pick as the teacher, log frame + joints + next target) can be written today.
- The File Exchange item itself: not installable here (R2025b/R2026b, Simulink, Simulink 3D
  Animation, Unreal). If the department ever has R2025b on one PC, the Simulink model runs
  the same Python environment built today (`installPythonEnv` would recreate it).

## 6. Lab 6 status after today: DECISION (Ryan, 2026-11-19, in chat)
**Lab 6 IS the action-output VLA loop**, not Gemini plus calibration. Ryan: "this is what
lab 6 will be." The 2026-11-16 fallback definition (Gemini Robotics-ER pointing and
planning on the Lab 5 four-point calibration) is retired as the lab's content. The current
`labs/lab6-language-directed-pick/` code (UR_VLA_Lab.m, Gemini client, UR_CalibrateCamera_VLM)
stays in the folder untouched for now; what replaces it grows out of
`UR_VLA_Octo_Prototype.m` once it has run on the robot. No student-facing file was edited
today (Ryan's order: code runs first, then docs).

What this implies for the lab design (to settle with Ryan):
- The pixel-to-base calibration disappears from Lab 6; the policy maps image to action
  itself. The safety layers stay (keep-out box, per-step clamp, typed yes, Enter per step)
  and become teaching content: a language model's action is still an unchecked number.
- Cameras: a fixed third-person camera as the policy's primary view (the bird's-eye, or
  better an oblique Bridge-like view), plus the FPV camera behind the gripper as the wrist
  view (Octo takes `image_wrist` at 128x128; the wrapper needs a small change to pass it).
  See the 2026-11-19 chat assessment: FPV alone as the primary is worse than the bird's-eye;
  both together match Octo's pretraining and are what a fine-tune wants.
- Zero-shot Octo is unlikely to finish a pick on the UR3e. Two ways the lab can still work:
  (a) students run the pretrained policy, log and analyze the action stream, and compare
  with Lab 5; or (b) the instructor fine-tunes on demonstrations beforehand (SmolVLA plan)
  so students run a policy that succeeds, then study what breaks it. Ryan to choose.

## 7. Open items
- [ ] At the robot (Ryan, desktop): fill `start_pose` and the keep-out box in
      `UR_VLA_Octo_Prototype.m`, run `DryRun=true` with the live camera first, then the real
      loop with `confirm_each_step = true`, speed slider 100 percent, 10 steps. Record the
      CSV and a screenshot per step.
- [ ] Try the Bridge-like camera position (section 5, item 1) and compare.
- [ ] Decide: Octo demo in Lab 6 Part 5 (students read the action vector, see it drift,
      explain why calibration-free is harder) vs. keep it instructor-only.
- [ ] If Ryan wants the fine-tuning path: write the MATLAB demo recorder from
      `vla_matlab_in_loop_plan.md` step 3 (no training needed to write and test it).
- [ ] The 2026-11-16 open items still stand: UR_CalibrateCamera_VLM first hardware run,
      UR_VLA_Lab Stage A to D, 429 retry and key-file line-break decisions.
- [ ] `C:\Users\924414657\vla-octo` is 2.9 GB in the user profile and not backed up
      anywhere; the recipe above rebuilds it in about 10 minutes online. The downloaded
      `octoBaseModel.zip` was deleted after extraction.

## 9. FIRST HARDWARE RUN (Ryan at the robot, 13:55, `octo_run_20261119_135503.csv`)
Setup: bird's-eye 435i only (the new wrist 435if enumerates on a USB 2 link and gives no
frames, cable on the way); start pose jogged by Ryan and read over RTDE,
joints [3.59 -101.4 -98.88 -69.58 89.36 180.9], flange (341, -111, 225) mm, tool 0.7 deg
from straight down; keep-out box X 0.25 to 0.50, Y -0.35 to 0.00, Z 0.100 to 0.30 m; task
"pick up the red block"; `max_step_m` 0.02, `action_yaw_deg` 0, rotation ignored; Enter
before every step. Desktop dry run first (Octo loaded in 5.1 s there).

| step | policy s | dx dy dz (mm) | gripper | flange after (mm) |
|---|---|---|---|---|
| 1 | 4.74 | +8.7 -6.0 -17.0 | open | 350.0 -116.9 207.8 |
| 2 | 6.62 | +6.0 -5.7 -11.1 | open | 356.0 -122.6 196.8 |
| 3 | 0.22 | +2.4 -2.7 -13.2 | open | 358.4 -125.3 183.6 |
| 4 | 0.21 | +1.8 -0.1 -16.6 | open | 360.2 -125.4 167.0 |
| 5 | 0.22 | +9.9 +5.7 -6.0 | CLOSE | 370.1 -119.7 161.0 |
| 6 | 0.22 | +0.4 +2.4 -6.9 | closed | 370.5 -117.4 154.1 |
| 7 | 0.22 | +1.4 -4.1 -6.1 | closed | 371.9 -121.5 148.0 |

Ryan stopped it after step 7. Every executed target became the next step's current pose
to the millimetre (the Lab 5/6 motion path holds). Net motion: 77 mm down, 31 mm +X,
11 mm -Y. The policy never looked for the block: it descended nearly straight and closed
the gripper at step 5 with the flange 61 mm above the grasp height (the fingers closed on
air). That is the same "go down, close" prior the static-frame runs showed; the closed loop
changed nothing. No clamp was hit (largest raw step 21 mm, clamped to 20), no bounds stop.
Expected for zero-shot Octo on this embodiment and viewpoint (section 5).

Ryan after the run: "i dont like the press enter every time thing." Changed in the
prototype: `confirm_each_step` now defaults to false, the loop runs to MaxSteps and q in
the figure window stops it after the current step (e-stop otherwise); the camera is opened
once and kept open (one `snapshot` per step instead of a 3 s `capture_realsense` call), with
the bird's-eye selected by the name pattern `435i RGB` so the wrist `435if` is never picked
by accident. The start pose and box above are in the file.

Still to try today, in order: the Bridge-style wording ("put the red block on the ...",
"pick up the red block" was used), `action_yaw_deg` once we decide where "away from the
robot" is in this frame, then the wrist camera as `image_wrist` when the cable arrives.

## 10. Option 2: execute the whole chunk as one blended move (Ryan: "do option 2", 14:10)
Ryan asked whether the policy could "make a whole plan and execute it smoothly". Answer
given: a VLA does not plan a task; Octo predicts 4 steps per picture and expects to be
asked again. What can change is execution. Options offered: (1) shorter faster single
steps, (2) run each 4-step chunk as one blended `followJointWaypoints` call and re-observe,
(3) `sendServoJCommands` streaming (exists on the client, not before fine-tuning).
Ryan chose 2. Implemented, verified offline and read-only, NOT yet run on the robot:

- `octoChunk.py` (in `C:\Users\924414657\vla-octo\vlapy\`, copy in this folder):
  `OctoChunkInference(OctoInference)` with `step_chunk(image, task)` returning the whole
  denormalized chunk: `world_vector` (4x3 m), `rot_axangle` (4x3 rad), `gripper` (4,
  +1/-1), `raw` (4x7). No ensembling. `octoModel.py` untouched. 0.19 s per call.
- `UR_VLA_Octo_Prototype.m`: per picture, the first `chunk_steps` (4) deltas are yaw-rotated
  and clamped one by one, summed into cumulative flange targets, EVERY target is checked
  against the keep-out box (the chunk is cut at the first outside waypoint and the loop
  stops after it), the targets are solved to joint angles chained from the current joints
  (`planWaypoints`), and sent as one `followJointWaypoints(ur, Q, WaypointTimes, Velocity
  0.3 rad/s, Acceleration 0.5, BlendRadius)` call; a gripper change inside the chunk splits
  the motion at that waypoint. Waypoints under 2 mm apart are merged and the blend radius is
  capped at 40 percent of the shortest segment (a blend larger than its segment is a
  URScript error that would stop the server program). One-row chunks fall back to the run-1
  single timed joint move. CSV now has a `chunk` column, one row per step.
- Verified: `checkcode` 0 messages; offline dry run on the start-pose frame, 3 pictures x 4
  steps (`dryrun_v3_chunk.log`); `test_plan_waypoints.m` read-only against the live robot
  at the start pose (`plan_waypoints_readonly.log`): a run-1-like chunk with one 1 mm step
  gave 3 of 4 waypoints kept, IK-to-FK error 0.00 mm at each, max joint step 4.2 deg, blend
  capped 10 -> 5.6 mm, 0.65 s to plan.
- FIRST CHUNK RUN (14:25) errored before any motion: `followJointWaypoints` "The value of
  'WaypointTimes' is invalid. Expected input to be an array with number of columns equal
  to 6." Read the toolbox source (`manipulatorRTDEInterfaceInputParser.m` L144-183,
  `manipulatorRTDEInterface.m` L505-526, `sharedRTDEInterface.m` L157-231):
  - the help text says one waypoint per ROW, but the parser sets Ncols = size(wp, 2) as
    "Number of Waypoints" and the method does `JointWaypoints'` "convert 6xN to Nx6": the
    matrix must be 6 x N, and WaypointTimes must have N columns;
  - with BlendRadius > 0 the times are zeroed and a warning is raised (so each segment is a
    movej at the given Velocity/Acceleration); with BlendRadius 0, times must be increasing;
  - the server-side chain gives the first and last waypoints blend 0 and caps the blend of
    the last two segments at 0.8 x the segment length; interior waypoints get the given radius.
  Fix in `moveThrough`: send `[q0; Q]'` (the current joints as waypoint 1, a zero-length
  movej, so every chunk target blends except the last) with Velocity, Acceleration and
  BlendRadius and no times. Verified with the toolbox parser offline
  (`test_fjw_parser.m`, `fjw_parser_offline.log`): 6x4 with blend parses to times
  [0 0 0 0] and blend 0.0056; the N x 6 form reproduces the live error. checkcode 0. The
  motion itself is still unverified; if the arm visibly stops at every waypoint anyway,
  option 3 (`sendServoJCommands`) is the remaining route. Arrival check on the last waypoint.

## 11. RUN 2, chunk mode (14:31, `octo_run_20261119_143130.csv`): "it almost picked it up"
Same start pose, task "pick up the red block", red block moved under and ahead of the
gripper. 4 pictures, 16 steps, all executed, blended motion through each chunk. Ryan:
"holy shit lol it almost picked it up! very sick." The arm went from flange Z 225 mm to
110 mm (grasp height 100) in four chunks, with a clear hover (chunk 3: all deltas under
3 mm, the policy's "settle above the object" phase), then the gripper closed at the first
waypoint of chunk 4 at Z 133 mm and the arm kept descending to 110 mm with the fingers
closed, so it closed about 3 cm above the block instead of around it.

| chunk | policy s | net motion (mm) | gripper | flange Z after (mm) |
|---|---|---|---|---|
| 1 | 5.3 | +21 -31 -71 | open | 154 |
| 2 | 6.8 | +12 -9 -12 | open | 143 |
| 3 | 0.23 | +2 +2 -3 | open (hover) | 141 |
| 4 | 0.22 | +7 +16 -30 | CLOSE at step 1 | 110 |

Reading: unlike run 1 the policy tracked the block (the Y component reversed sign in chunk 4
toward it) and showed the Bridge pick structure (approach, hover, close, lift was about to
come). The miss is the gripper timing in Z: the WidowX fingers reach lower relative to its
camera than the Robotiq 2F-85 does at our flange height. Cheap fixes to try: start 2 to 3 cm
lower (the close then happens at the block), or `z_min` closer to the table; or delay the
close until the chunk has finished (a policy change, less honest). Ryan's choice: wait for the
USB 3 cable and try two cameras next (section 12).

## 12. Two cameras: the wrist image path (built 14:45 while waiting for the USB 3 cable)
octo-base config: observation tokenizers `primary` (image_primary, 256x256) and `wrist`
(image_wrist, 128x128), window 2, both pretrained. Without a wrist image the wrist tokenizer
is skipped (the "Skipping observation tokenizer: obs_wrist" warning in every run so far).
- `octoChunk.py`: `step_chunk(image, task, wrist_image=None)`. The wrist frame is resized to
  128x128 (lanczos3, like the primary), kept in its own 2-frame history, cleared on reset,
  and passed as `image_wrist`; an episode must give it on every step or on none (error
  otherwise). Python test on the start-pose frame with a fake wrist (the same frame
  downsampled): the skip warning disappears, actions change, first call 6 s, the second
  call 9 s (a second JAX compile for the 2-frame window), then 0.2 s expected.
- `UR_VLA_Octo_Prototype.m`: settings `use_wrist` (true), `wrist_camera` ("435if RGB"),
  `wrist_resolution` ("640x480", in both the USB 2 and USB 3 mode lists). Both cameras are
  opened once by name (`openCamera(pattern, resolution)`), one snapshot each per picture,
  the figure shows bird's-eye | wrist side by side. Offline: `ImageFile=` plus
  `WristImageFile=`. `use_wrist = false` is runs 1 and 2 exactly.
- NOT run with the real wrist camera: it still has no USB 3 cable. When it arrives: unplug
  and replug the 435if on the new cable, `webcamlist` must show "435if RGB", a `webcam` on it
  should list the long mode table (1920x1080 ... 320x180) and `snapshot` must return a frame
  (batch probe: `matlab -batch "c = webcam('Intel(R) RealSense(TM) Depth Camera 435if RGB'); disp(c.AvailableResolutions); imwrite(snapshot(c), 'wrist_probe.png')"`).
  Then the same `UR_VLA_Octo_Prototype` run, same start pose and task, for a direct
  comparison with run 2. Expect the first two pictures to take 6 to 9 s each.

## 13. Runs 3 and 4 and the measured box (14:45 to 15:10)
- Run 3 (`octo_run_20261119_144517.csv`, start pose 45 mm lower, flange Z 179 mm): stopped
  by the script's own floor. The policy was heading for Z 98 mm (the Lab 4 grasp line is
  100.4 mm) with the gripper still open; waypoint 4 of chunk 2 fell below z_min 0.100 and the
  rule then was "stop the loop". Changed: Z targets outside [z_min z_max] are clamped (the
  rest of the chunk shifted by the same amount) and the loop continues; X and Y outside still
  stop it.
- Box measured with Ryan at the pendant (read over RTDE): open fingertips 2 to 3 mm above
  the table at flange Z 84.9 mm; highest wanted pose Z 530.5 mm (nothing above the robot in
  reach); the PolyScope X safety planes for the back wall and the curtain read at about
  X +105 and X -225 mm, both behind the base, so the Lab 4 X/Y edges (0.25 to 0.50,
  -0.35 to 0.00) stay. Advice given: keep the planes (hard layer), keep the box inside them
  (a plane hit is a protective stop that kills the server program and the MATLAB run).
- Run 4 (`octo_run_20261119_150950.csv`, floor 0.085, ceiling 0.530): 6 chunks, 24 steps,
  all executed. Descent to 91 mm, a 6 mm lift, CLOSE at 97 to 89 mm (the right height this
  time), the floor held Z at exactly 85.0 for three waypoints while the policy pushed down,
  then a 29 mm lift and a return to 92 mm with the fingers closed. Ryan: "it was dragging
  the fingertips across the table". The box worked; the 2 to 3 mm margin did not survive a
  closed gripper (a closing 2F-85 swings its tips lower) and 5 cm of table. Floor raised to
  0.095. Whether the fingers caught the block is not in the log (Ryan did not say).
- Run 5 (`octo_run_20261119_151427.csv`, floor 0.095): 12 chunks, 48 steps, all executed, the
  floor held Z at exactly 95.0 for 22 of them. The closed fingertips hit the table again
  (Ryan). The policy cycled close / lift / come back down / open / close four times, the
  Bridge regrasp pattern, so it never had the block. Floor raised to 0.105 (5 mm above the
  Lab 4 grasp line). Why 20 mm above the open-tip touch point: the 2F-85 pads swing outward
  as the fingers close, so an empty close reaches well below where the open tips were. The
  honest number is a measurement with the gripper closed (pendant), jogged down to touch.
- Measured: closed fingertips resting on the table at flange Z 96.2 mm (open tips 2 to 3 mm
  up at 84.9), so the empty close reaches 11 mm lower than the open tips. Floor stays 0.105,
  9 mm above the closed touch point.

## 14. Wrist camera live (15:40, a USB-C to camera cable Ryan found)
`webcamlist` shows both units; the 435if opens with the full mode table (1920x1080 down to
320x180, nine modes), first frame in 0.47 s at 640x480, `wrist_probe.png` saved after the
30-frame settle: table from behind the gripper, closed fingers at the bottom edge, the teal
block at the left. So the 2026-11-04 diagnosis holds: the four-mode list and no frames was
the USB 2 link, not the camera. Two-camera runs are now `UR_VLA_Octo_Prototype(Wrist=true)`.

## 15. Run 6, first two-camera run (16:19, `octo_run_20261119_161954.csv`)
`UR_VLA_Octo_Prototype(Wrist=true)`, floor 0.105, same start pose. All 20 pictures, 80
steps executed, no stop. Policy time 7.5 and 8.4 s for the first two pictures (two JAX
compiles), then 0.27 s. Behaviour: a close-open flicker in chunks 1 and 2 while still 18 cm
up (noise), then the gripper stayed OPEN for the remaining 18 chunks. The arm descended in
small steps to the floor at 105 mm (chunks 14 and 18 to 20), wandered 7 cm in +Y along the
way, lifted and came back twice, and never committed to a grasp. Ryan: "it seems like its a
little better at picking up the block and making small adjustments but its inconsistent and
still cannot grab the block if its not placed basically directly under it." Compared with the
one-camera runs 2 to 5, which closed every time (too early or at the floor), the wrist view
made the policy more hesitant. One run, so not a conclusion. Ryan's question "what can we do
besides fine-tuning" is answered in section 16.

## 16. What zero-shot has left (assessment for Ryan, 16:30) and the crop
Ryan's bird's-eye is an oblique view, not top-down. That is fine: Bridge's camera is also an
over-the-shoulder oblique view with the arm entering from the top of the frame. What differs
is scale: in `primary_now.png` the gripper and the blocks occupy the middle third of a
1280x720 frame, so a block is about 10 pixels wide after the 256x256 resize, where Bridge
objects fill the frame. On the wrist: Octo's dataset table
(`octo/data/oxe/oxe_dataset_configs.py`, `bridge_dataset`) has `"wrist": None`, so the
Bridge pick behaviour was learned from the fixed camera only; octo-base's wrist tokenizer
was trained on other robots' data. Options in the order to try, none of them fine-tuning:
1. Crop the primary frame to the work area (DONE: `primary_crop = [220 80 640 640]`, the
   figure shows the crop). Expected to be the biggest single change.
2. Calibrate the action frame yaw (`action_yaw_deg`, still 0): two short runs with the
   block offset only in +X, then only in +Y, and read which way the policy moves.
3. Wrist on vs off, A/B over a few runs each, before keeping it.
4. A lighter sheet on the black bench and toy-like objects (Ryan is getting a sheet).
5. Average a few diffusion samples per chunk to take the sampling jitter out of the drift.
The real fix for consistency stays fine-tuning (vla_matlab_in_loop_plan.md).

## 17. Run 7 (white sheet, crop) and the sideways-tracking test (16:35 to 17:10)
Run 7 (`octo_run_20261119_163506.csv`, one camera, crop, white sheet, block image-right of
the gripper per Ryan): 9 cm in -Y over two chunks, almost no X; Ryan stopped it: "it
correctly decided to move laterally to adjust, but it moved laterally in the wrong
direction, away from the block." Image axes of this camera (from the frame geometry and a
+Y jog read over RTDE): +X = image-down, +Y = image-right. So the arm went image-left.

Offline test, no robot: two frames through the same crop, `primary_sheet.png` (block
image-LEFT of the gripper, arm at the start pose) and `primary_jogY.png` (block image-RIGHT,
arm 4 cm lower). First attempt gave eight identical samples: the vlapy wrapper seeds JAX
with `init_rng=0` on every new object, so "resampling" needs `OctoChunkInference(init_rng=i)`.
With eight seeds per frame, chunk sums in mm (mean +- std):

| frame | as is: dy | mirrored left-right: dy |
|---|---|---|
| block LEFT | -30 +- 37 (6 of 8 negative) | -20 +- 18 (7 of 8) |
| block RIGHT | -60 +- 54 (7 of 8) | -76 +- 54 (7 of 8) |

The sideways sign does not depend on which side the block is on, and does not flip when the
image is mirrored. So the policy is NOT reading the block's lateral position from this view;
-y is a viewpoint-driven bias. A mirror or rotation in `action_xy_map` cannot fix that (it
would only redirect the bias), so the map stays eye(2). Diffusion-head spread is large
(std about equal to the mean), another reason to average seeds per chunk (section 16, item 5).
Next: match the Bridge camera placement (web lookup in progress), then a clean placement
test (block left / right / far with the arm fixed, three frames, eight seeds each).

## 18. The Bridge camera, from SimplerEnv (web lookup, 17:15)
BridgeData V2 pages and paper say only "an RGBD camera that is fixed in an over-the-shoulder
view" (RealSense D435, 640x480, 5 Hz; a wide-angle wrist camera exists but the paper's
policies used "only the over-the-shoulder camera view"). The numbers are in SimplerEnv:
`ManiSkill2_real2sim/mani_skill2_real2sim/agents/configs/widowx/defaults.py`, robot
`widowx_bridge_dataset_camera_setup`, "the camera used in the Bridge dataset":
`p = [0.00, -0.16, 0.336]`, `q = [0.909182, -0.0819809, 0.347277, 0.214629]` (w x y z), in
the WidowX base_link frame, 640x480, intrinsics fx = fy = 623.6 (about 55 deg horizontal).
Worked out from q (SAPIEN camera: x forward, y left, z up):
- camera forward = (0.667, 0.333, -0.667): looks along the arm (+x), 27 deg toward the
  robot's left (+y), pitched 42 deg down; the optical axis meets the table about 34 cm in
  front of the base on the centre line (the WidowX base sits on the table);
- the base is 36 deg below the optical axis and to the left: OUT of frame at the bottom
  left, so the ARM ENTERS FROM THE BOTTOM-LEFT and reaches up the image into the scene;
- image-up is away from the robot (+x), image-left is the robot's left (+y).
Our bird's-eye is on the far side of the bench looking back at the robot: the arm enters
from the TOP, +X is image-down, +Y is image-right. That is the Bridge view rotated by
about 180 deg, and is the likeliest reason the policy does not localise the block from it
(section 17). Two ways to match Bridge: (a) rotate our frame 180 deg in software before the
policy (then the policy's x/y land on our X/Y with the identity map, see the derivation
above), tested offline below; (b) remount the camera Bridge-style: at the robot's right
shoulder, 16 cm to -Y of the base centre, 34 cm above the table, pitched 42 deg down and
yawed 27 deg toward +Y, aimed at a point 34 cm in front of the base. The UR3e work area
(X 0.25 to 0.50) sits where the WidowX's does, so (b) is mostly a bracket.

Offline result for (a), same two frames, eight seeds, chunk sums in mm:

| frame | as is: dy | rotated 180: dy |
|---|---|---|
| block LEFT | -30 +- 37 | -15 +- 26 (5 of 8 negative) |
| block RIGHT | -60 +- 54 | -33 +- 40 (7 of 8) |

Still -y on both sides, so a software rotation of this view is not enough: the perspective
(looking back at the robot, a UR3e with a Robotiq instead of a WidowX) is still foreign.
Option (b), the physical remount, is the remaining zero-shot lever on the view.

## 8. Sync
`git pull` brought 223cb34 (Mac: the SmolVLA plan) before any work; nothing else was ahead.
This folder was committed and pushed at the end of the session. Box is not mounted on PC 17;
Ryan pulls on the Mac and rsyncs into Box as agreed on 2026-11-06.

## Sources
- https://www.mathworks.com/matlabcentral/fileexchange/184183-vision-language-action-vla-models-in-simulink (v1.0.5, R2026b+)
- https://github.com/mathworks/robot-vla-simulink (README, robotpolicy.m, vlapy/, installPythonEnv.m, test/testRobotPolicy.m)
- https://blogs.mathworks.com/autonomous-systems/?p=1373 (RobotPolicy block announcement, Feb 2025)
- https://github.com/octo-models/octo , https://huggingface.co/rail-berkeley/octo-base
- https://github.com/simpler-env/SimplerEnv (the wrapper's origin and the Bridge success rates)
