# UR3e VLA with MATLAB in the loop: architecture and workflow (plan, 2026-11-16, Mac session)

Written on the Mac after the PC 17 session, for pick-up on the lab PC. Desk study only: nothing
here was installed or run. It supersedes the "DECISION" at the end of `pi0_feasibility.md`
(LeRobot robot class on ur_rtde, SpaceMouse teleop, Jetson) on one point: Ryan's requirement
is now explicit.

## Requirements (Ryan, 2026-11-16)
- "The thesis story needs matlab for sure." MATLAB must stay in the control loop.
- "Some python is fine for fine tuning." Python is limited to training and serving the policy.
- Prefer WSL2 on the lab PC over the Jetson if it works; the Jetson AGX Orin is the fallback.

## Ruled out for the real robot
- Gemini Robotics-ER (current Lab 6): returns points, boxes and plans, never actions; the
  Gemini API offers no fine-tuning. In Lab 6 it acts as a language-prompted detector.
- MathWorks `robot-vla-simulink` (github.com/mathworks/robot-vla-simulink): a real VLA
  framework (Octo, RT-1-X through Python co-execution) but simulation only (Unreal), needs
  R2025b+, Simulink and Simulink 3D Animation, wraps pretrained models with no training path,
  and its README sends real hardware to ROS Toolbox. Possible classroom demo, not our stack.
- Pure Python robot client (ur_rtde + LeRobot robot class): works for others on UR5e, but takes
  MATLAB out of the loop, and ur_rtde on PolyScope X is not clearly supported.

## Verdict
The design is sound and every link has supporting evidence, but nobody has run this chain end
to end. Two things could still sink it: fine-tuning within 8 GB of GPU memory, and whether a
policy trained on scripted demonstrations generalizes. Both are cheap to test early.

## Architecture
Everything runs on the lab PC.

```
 Lab PC (Windows 11, RTX 4060 8 GB)
 +----------------------------+   observation (HTTP)    +--------------------------------+
 | MATLAB R2024b              | ----------------------> | WSL2 Ubuntu (Python)           |
 |  owns camera, robot, loop  | <---------------------- |  Policy server                 |
 |  1 capture frame, joints   |   action chunk (JSON)   |   loads fine-tuned SmolVLA     |
 |  2 webwrite observation    |                         |          ^ checkpoint          |
 |  3 safety-check the chunk  |   episodes (PNG + CSV)  |  LeRobot fine-tuning           |
 |  4 execute, urRTDEClient   | ----------------------> |   convert, train smolvla_base  |
 |  also records demos        |                         +--------------------------------+
 +----------------------------+                                 : fallback for training
      ^ frames        ^ v RTDE                                  : Jetson AGX Orin
 D435i camera     UR3e + Robotiq 2F-85 (pendant runs the MathWorks server script)
```

## Interfaces
| Interface | From, to | Content | Mechanism |
|---|---|---|---|
| Observation | MATLAB to server | one RGB frame (fixed D435i), six joint angles in degrees, gripper state, task sentence | `webwrite` to `localhost`, same pattern as `gemini_generate` |
| Action chunk | server to MATLAB | next N steps: six absolute joint targets + gripper command each | JSON reply |
| Robot command | MATLAB to UR3e | one joint target per step with a short `EndTime`, or the chunk as blended waypoints; `actuateGripper` on change | `urRTDEClient`, MathWorks API only |
| Dataset | MATLAB to LeRobot | per episode: frames + table of joints, gripper, next target, task | MATLAB writes PNG and CSV; a Python script converts with `LeRobotDataset.create / add_frame / save_episode` |

Rules: record the way you execute (same step size and move command in demos and at run time);
absolute joint targets, not deltas.

## Workflow
1. Environment (lab PC): Ubuntu 22.04 in WSL2, PyTorch with CUDA, LeRobot. Done when
   `torch.cuda.is_available()` and SmolVLA runs one inference.
2. Motion path (MATLAB, at the robot): time chained small moves; try a short chunk through
   `followJointWaypoints`. Choose one.
3. Demonstrations (MATLAB, at the robot): Lab 5 is the teacher. Its calibrated pick runs
   repeatedly while a script logs frame, joints, gripper and next target at every step. A
   person only moves the block. Target 100 episodes, at least 10 per block position, a few
   task sentences. (LeRobot's guide: about 50 to start; 25 was not enough for a similar task.)
4. Conversion and fine-tuning (WSL2): convert, fine-tune `smolvla_base`, start at batch 8.
5. Serving (WSL2): small HTTP wrapper around the checkpoint. LeRobot's own async server is
   gRPC, which MATLAB cannot call directly.
6. Closed loop and evaluation (MATLAB, at the robot): capture, call, check the chunk against
   joint limits, a keep-out box and a maximum step, execute, repeat. Success rate at trained
   and unseen positions, Lab 5 as the baseline.

## Verification status
| Claim | Status | Basis |
|---|---|---|
| CUDA and PyTorch inside WSL2 | documented | NVIDIA CUDA on WSL guide |
| Ubuntu installs without admin on PC 17 | untested | WSL feature is on; one forum report says a standard user can add a distribution |
| SmolVLA needs fine-tuning, about 50 episodes | documented | LeRobot SmolVLA guide (20k steps, about 4 h on an A100) |
| Fine-tuning fits 12 GB | reported | RTX 3060 model card: batch 48 peaks at 11.7 GB, 64 runs out, 15 h for 41,801 steps |
| Fine-tuning fits 8 GB | untested | extrapolated to a smaller batch; no 8 GB report found |
| Custom dataset from our frames | documented | LeRobot dataset API; signatures change between versions |
| SmolVLA on a UR arm | reported | community UR5e projects over Python RTDE; none on UR3e or MATLAB |
| MATLAB single timed moves on our UR3e | verified on hardware | Labs 2 to 5 |
| Blended multi-waypoint moves and servoJ from MATLAB | in the server script, never run by us | `URServerScript_Robotiq2F_PolyScopeX.script` has `programMultipleMoveJ` and `programServoJ`; whether R2024b exposes `followJointWaypoints` / `sendServoJCommands` is unchecked (MathWorks pages could not be opened from the Mac) |
| Step-and-wait rate is practical | untested | needs a timing run |
| Scripted Lab 5 demos generalize | untested | the research question |

## Risks and fallbacks
| Risk | Fallback |
|---|---|
| No admin for the WSL distribution | one-time IT request; or train and serve on the Jetson and point `webwrite` at it |
| 8 GB not enough to train | train on the Jetson or a cloud GPU, copy the checkpoint back, still serve from WSL2 |
| Step-and-wait too slow or jerky | send each chunk as one `followJointWaypoints` call; `sendServoJCommands` if needed |
| Speed slider changes timing | one fixed slider value for recording and evaluation |
| Policy does not generalize | more positions per round; wrist camera; narrower task |
| Unsafe action | MATLAB rejects chunks outside joint limits, keep-out box or maximum step |
| Camera moves after recording | mark the mount; re-record if it moves |
| Disk (65 GB free) | reduced frame resolution; move finished datasets off the PC |

## First tests (do these before recording anything)
- [ ] `wsl --install -d Ubuntu-22.04` on PC 17 as the normal user (admin question).
- [ ] In WSL2: fine-tune `smolvla_base` on LeRobot's public pick-and-place sample for 200
      steps at batch 8, read peak GPU memory with `nvidia-smi` (8 GB question).
- [ ] In MATLAB on PC 17: `methods(ur)`, look for `followJointWaypoints` and
      `sendServoJCommands` (motion options in R2024b). Read-only, fine from batch.
- [ ] At the robot, from the MATLAB desktop (never batch): time 20 one-degree steps on one
      joint with `sendJointConfigurationAndWait`. Same safety scaffolding as the labs. The
      test script is not written yet.

## Sources
- https://huggingface.co/docs/lerobot/main/en/smolvla
- https://huggingface.co/khanhnd61/smolvla_so101_left_arm_3tasks
- https://huggingface.co/docs/lerobot/main/async
- https://docs.nvidia.com/cuda/wsl-user-guide/index.html
- https://huggingface.co/papers/2506.01844
- https://github.com/mathworks/robot-vla-simulink
- https://github.com/F-Fer/lerobot_ur5e_gello , https://github.com/r1b4z01d/VLA (found by search, not opened)
- https://www.mathworks.com/help/robotics/urseries/ref/urrtdeclient.html (not opened)
