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
