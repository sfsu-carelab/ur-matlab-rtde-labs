# Runbook: end-to-end hardware test of Labs 2 to 6

Purpose: run every lab's code on the real robot once, before students do, and bring back
enough evidence (logs, images, numbers) that the manuals and scripts can be corrected
without a second trip. Budget about three hours at the robot.

Everything the harness writes lands in `Instructor - Hardware Validation/test-logs/` inside
the Box folder, so it syncs back automatically. Anything you type by hand (pendant readouts,
table values, error text) goes in a text file in the same `test-logs/<timestamp>/` folder.

---

## 0. Before leaving

Bring:
- Laptop with Box Drive (backup copy of the `MATLAB + RTDE` folder on a USB stick too)
- Ethernet cable, RealSense D435if + USB 3 cable, wrist mount, colored blocks (two colors),
  a ruler, a "bowl" or marked square for Lab 6 place targets
- The Gemini API key (create at https://aistudio.google.com/apikey; restrict it to the
  Generative Language API or the API returns 403)
- Pendant admin password, robot IP (192.168.0.20), model (UR3e / UR5e)

Lab PC checklist (Windows 11, MATLAB):
- [ ] Box Drive signed in and the `Robot Hardware Education` folder visible (if not: copy the
      folder from the USB stick, and copy `test-logs/` back onto the stick at the end)
- [ ] MATLAB release noted: ______ (harness section 0 records it)
- [ ] Robotics System Toolbox, Image Processing Toolbox
- [ ] Robotics System Toolbox Support Package for Universal Robots UR Series Manipulators
      (Add-Ons > Get Hardware Support Packages; installs to the user folder, no admin)
- [ ] MATLAB Support Package for USB Webcams (Add-Ons > Get Hardware Support Packages, no
      admin needed); `webcamlist` in MATLAB shows the RealSense RGB camera. (Changed
      2026-11-04: the RealSense SDK wrapper is no longer used, the lab PCs cannot install it.)
- [ ] Internet access at the same time as the robot Ethernet link (Wi-Fi on). Lab 6 needs it.
- [ ] In MATLAB: `setenv('GEMINI_API_KEY', '...')` or `gemini_api_key.txt` in `Lab 06/Code`

Robot checklist (PolyScope X):
- [ ] Static IP 192.168.0.20 / 255.255.255.0, RTDE enabled (Lab 2 Part 4)
- [ ] URServerScript node in the program tree and PLAYING (green) (Lab 2 Parts 2-3)
- [ ] Payload and TCP set for gripper + camera (Lab 1 Section 3.2).
      WRITE DOWN the TCP offset from the pendant: [x y z] = [____ ____ ____] m
- [ ] Robotiq URCap installed and in the program (actuateGripper needs it)
- [ ] Speed slider 25 percent or less, e-stop in hand, workspace clear

---

## 1. Smoke test (30 min) - run this first

In MATLAB, `cd` to `MATLAB + RTDE/Instructor - Hardware Validation`, then:

```matlab
% 1a. no motion: environment, connect, read, FK, camera, API
r = UR_HardwareSmokeTest(DryRun=true, Model="UR3e", TCPOffset=[0 0 0.160]);

% 1b. with motion (elbow +5 deg, gripper, +2 cm up). It asks before moving.
r = UR_HardwareSmokeTest(Model="UR3e", TCPOffset=[0 0 0.160]);
```

Use the TCP offset you wrote down above. Read the summary at the end:

| Row | What a FAIL means | What to do |
|---|---|---|
| UR Series support package | not installed | Add-Ons, install, restart MATLAB |
| ping | wrong IP / cable / PC NIC not static | Lab 2 Part 4 |
| urRTDEClient connect | server script not playing, RTDE off | press Play on the pendant |
| FK position vs reported | TCP offset wrong, or a base-frame convention difference | rerun with the right TCPOffset; if it only passes "with 180 deg base yaw", note it: the Lab 3 manual needs a sentence about the base frame |
| pose layout, Z = element 6 | readCartesianPose is NOT [rot(3) xyz(3)] | STOP: Lab 5 and 6 assume this. Copy the printed pose and the measured deltas into notes |
| actuateGripper | URCap missing | pendant: install Robotiq URCap, add to program |
| capture_realsense | USB Webcams package not installed, camera not in webcamlist | install the package from Add-Ons; check the USB cable, try another port |
| gemini_generate | no key / no internet / model id retired | see the error hint; check Wi-Fi |

Section 2 prints the reported orientation next to the same rotation written as ZYX Euler
angles and as a rotation vector. Whichever one matches tells us what convention
`readCartesianPose` uses. Nothing in Labs 4-6 depends on it (they copy orientations from
a taught pose), but the manual should say which it is. Leave this in the log.

---

## 2. Lab 2 as a student (15 min)

Follow the manual literally, Parts 5-6:
- [ ] Add-Ons > Manage > UR support package > gear icon > Hardware Setup shows live joint angles
- [ ] The elbow +5 deg script from Part 6 runs from a new .m file
- [ ] Note anything in the manual that no longer matches PolyScope X menus (screenshots help)

## 3. Lab 3 (10 min)

- [ ] `UR_FK_Lab_KEY("UR3e")` (from `Lab 03/instructor`) prints ALL TESTS PASS offline
- [ ] Section 2 of the smoke test is the hardware check. Optional extra: at two different
      arm poses, read the pendant Move screen (TCP position) and compute
      `T = fk_space(S_list, M, hw2screw(q_deg))` after running the key; record both in notes

## 4. Lab 4 (40 min)

- [ ] `UR_PickPlace_Lab` with the NaN waypoints prints the connection readout and stops
- [ ] Teach the six waypoints on the pendant (Part 1), write them down, build the pendant
      program (Part 2), time it
- [ ] Enter the waypoints in the script, speed 10 percent, run. Record the cycle time printed
- [ ] Record: both cycle times, any move that failed (`moveFailed` message), whether the
      gripper closed on the cube and released it

## 5. Lab 5 (60 min)

- [ ] `img = capture_realsense(); imshow(img)` from the Lab 5 Code folder
- [ ] Imaging pose (Part 2): record J1-J6, run the staged script - it should move, show the
      image, stop
- [ ] HSV tune (Part 3): record the working thresholds for each block color you brought
- [ ] Calibration (Part 4): four placements, record UV and XY, note the RMS printed
- [ ] Reference pick pose and place waypoint (Part 5)
- [ ] Five vision-guided picks (Table 5). Record success and the estimated grasp offset
- [ ] KEEP the Lab 5 numbers (imaging pose, UV, XY, ref_pick_pose, thresholds): Lab 6 reuses
      them unchanged. Save them in `test-logs/<timestamp>/lab5_values.txt`

Known risks to watch: the camera wrapper on Windows (never run yet), the Cartesian pose
convention (smoke-test section 5 settles it), the active TCP vs the touch point.

## 6. Lab 6 pre-flight (30 min)

In the `Lab 06/Code` folder:
- [ ] `test_vlm_offline` - Part 1 must pass; Part 2 (live) tells us whether the key, the
      network and the model id `gemini-robotics-er-2-preview` work. If Part 2 fails with
      HTTP 400, try `ThinkingLevel="low"` in place of `ThinkingBudget` (edit the default in
      `gemini_generate.m`); if 404, the model id has changed (see README)
- [ ] `genai_hello` with the camera connected - save the printed replies
- [ ] `UR_VLA_Lab` with the Lab 5 values pasted in; set `target_object` and `instruction`.
      Run it stage by stage. For Stage D use 10 percent speed. Record: the pick/place
      pixels and base XY the model chose, whether the bounds check accepted them, pick
      success, and what `vlm_verify` said (both the verdict and the diagnostics text)
- [ ] Try two or three instructions of increasing difficulty, e.g. "put the red block on
      the blue square", "move the block that is closest to the robot into the bowl",
      "stack the blue block on the red block". Note which ones the model gets wrong

---

## 7. What to bring back

Automatic (Box sync): `test-logs/<timestamp>/smoketest.log`, `results.json`, `camera.png`,
`vlm_point.png`.

By hand, in the same folder:
- `notes.txt`: TCP offset, robot model, MATLAB release, every error message copied from the
  Command Window, pendant-vs-MATLAB cycle times, which smoke-test rows failed and why
- `lab5_values.txt`: the numbers listed in step 5
- Photos: the setup, the pendant program tree, any pendant error pop-ups

If Box Drive is not on the lab PC, zip `test-logs` onto the USB stick.
