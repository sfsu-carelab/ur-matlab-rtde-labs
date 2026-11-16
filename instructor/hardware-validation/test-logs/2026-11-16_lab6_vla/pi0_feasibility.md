# What it would take to run pi0 / pi0.5 on the UR3e from lab PC 17 (assessment, 2026-11-16)

Written at Ryan's request after Lab 6 was tabled. Nothing here was installed or run; it is
a desk study from the openpi and LeRobot documentation plus an inventory of PC 17.

## Verdict
Doable as a thesis side project, not on this PC alone. The lab PC becomes the robot client.
Training, and probably inference, happen on a GPU somewhere else. About 6 to 10 weeks part
time and a few hundred dollars of cloud GPU time.

## PC 17 inventory
| Item | Finding | Consequence |
|---|---|---|
| GPU | NVIDIA RTX 4060, 8 GB (driver 566.24) | openpi: inference > 8 GB, LoRA fine-tune > 22.5 GB, full > 70 GB. Nothing trains here; inference is at the line. |
| CPU, RAM, disk | i9-14900K, 32 GB, 65 GB free on C: | fine for a robot client and data recording |
| OS | Windows 11 Enterprise, no admin | openpi tested on Ubuntu 22.04 only. WSL2 feature on, no distro installed (`wsl --install -d Ubuntu-22.04` may work without admin; untested). No Docker. |
| Python | Anaconda 3.12.7 at `C:\ProgramData\anaconda3`, no torch | `pip install --target` works without admin, so a client stack is possible |

## What openpi expects (from its README, remote_inference.md and examples/ur5)
- Data as a LeRobot dataset; a `TrainConfig`; `compute_norm_stats.py`; `train.py`;
  `serve_policy.py` (websocket, port 8000). Robot side installs only `openpi-client`
  (`packages/openpi-client`), minimal dependencies, no GPU needed.
- Checkpoints: pi0_base, pi0_fast_base, pi05_base, plus DROID / ALOHA / LIBERO experts. No
  UR checkpoint. Experts "may or may not work on your particular robot".
- `examples/ur5`: state = 6 joints + gripper (7), actions = joint deltas + absolute gripper,
  images `base_rgb` and `wrist_rgb` (wrist can be masked for pi0), prompt from the LeRobot
  `task` field, fine-tune from `pi0_base` with UR5e norm stats (`asset_id="ur5e"`),
  30k steps. pi0 was pretrained on UR5e data, so this is the closest match to a UR3e.
- Demo count not stated. Community practice for one pick-and-place task: 100 to 300
  teleop episodes.

## Plan
1. Robot client in Python (1 to 2 weeks): `ur_rtde` (joint reads, servoJ at 10 to 20 Hz),
   `pyrealsense2`, a keep-out box like `UR_FK_Lab3_Verify`. Gripper on PolyScope X: reuse
   the register pattern of `URServerScript_Robotiq2F_PolyScopeX.script` (Python writes an
   input register, the pendant script calls `rq_close_and_wait`), because no Python library
   drives the Robotiq on PolyScope X directly. The MathWorks server program and the ur_rtde
   control script cannot run at the same time; this is a separate pendant program.
2. Teleop and data (1 to 2 weeks): 3Dconnexion SpaceMouse (about 150 USD) driving servoL,
   the DROID recipe. Freedrive hand-guiding is free but puts the operator's arm in every
   image. 100 to 200 episodes of one task at 10 Hz into a LeRobot dataset. Wrist camera
   optional for pi0; the UR5 example used one.
3. Training in the cloud (1 week with iterations): pi0 LoRA or pi0.5 on one A100 80 GB
   (RunPod / Lambda, 2 to 3 USD per hour, 10 to 20 h per run). Colab Pro A100 40 GB clears
   the 22.5 GB LoRA line. Ask whether SFSU has a GPU node.
4. Deployment (1 to 2 weeks): policy server on a 24 GB cloud GPU or a campus Linux box,
   `openpi-client` on PC 17 over the websocket. Latency of a few hundred ms is fine because
   pi0 returns action chunks.

## Alternatives and caveats
- SmolVLA (LeRobot, 450M params): fine-tunes in 10 to 16 GB at batch 8 (3 to 6 h on an L4),
  inference fits the 4060 or CPU. LeRobot also carries pi0 and pi0.5 policies, so one
  LeRobot stack covers record, train, eval. LeRobot has no UR driver; the community fork
  `eee336/leUr5` (ur_rtde based, UR5e) shows the shape of the robot class to write.
- A fine-tuned policy bakes the camera placement into its weights: move the camera, re-record.
  The four-point calibration in Labs 5 and 6 is the same knowledge made explicit.
- Hardware to buy: SpaceMouse; optionally a wrist camera and mount.

## Sources
- https://github.com/Physical-Intelligence/openpi (README: requirements table, checkpoints, fine-tuning steps)
- https://github.com/Physical-Intelligence/openpi/blob/main/docs/remote_inference.md
- https://github.com/Physical-Intelligence/openpi/blob/main/examples/ur5/README.md
- https://huggingface.co/docs/lerobot/main/hardware_guide
- https://huggingface.co/papers/2506.01844 (SmolVLA)
- https://github.com/eee336/leUr5
- https://www.roboticscenter.ai/learn/collect-robot-training-data
