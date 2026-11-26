# Monday end-to-end check for Lab 5 Rev3 (before the Tuesday lab)

Work through it in order; each block depends on the one before. Budget about 2.5 hours, the
same as the students will need. Background is in `HANDOFF-NOTES.md` in this folder.

## 1. Get the files (10 min)
- [ ] On PC 17: `git pull` in the clone. Expect `e6c3429` or later.
- [ ] Confirm `labs/lab5-vision-guided-pick` has eight `.m` files, including the new
      `measure_color.m`.
- [ ] Open `Lab 5 - Vision-Guided Pick and Place.docx` in Word. Check the equations in the
      Background, that every numbered list restarts at 1, the table borders, and all six
      figures.

## 2. Code checks that have never run (15 min)
None of the edited code has been through MATLAB.
- [ ] `checkcode` on `UR_VisionPick_Lab.m`, `UR_CalibrateCamera.m`, `fit_pixel_to_base.m`,
      `capture_realsense.m`, `measure_color.m`: expect 0 messages.
- [ ] `test_vision_offline`: expect ALL OFFLINE VISION TESTS PASS.
- [ ] `webcamlist`: confirm the name contains both "RealSense" and "RGB" (the manual says so).
- [ ] `measure_color`: click the block, then the table. Two lines of h, s, v should print with
      sensible values (red block near h 0.03, s 0.8).

## 3. Pendant facts the manual assumes (10 min)
- [ ] With the server program playing, try to jog. The manual says the pendant will not jog
      while a program plays.
- [ ] With the server program stopped, open and close the gripper from Application > URCaps >
      Robotiq.
- [ ] Stop the server program, jog, then press Play again. The robot must not move on Play.

## 4. Walk the manual as a student (90 min)
Follow the steps literally and note anything you had to guess.
- [ ] Task 1: tape a pick area of about 15 x 20 cm, 25 to 45 cm from the base centre, with
      five marks. Confirm all five are in the picture at the current camera position. If not,
      move the camera now.
- [ ] Task 2: pick the imaging pose and run the script. Time the Ready-to-imaging move at 25
      percent; the manual says about 20 s.
- [ ] Task 3: apply the threshold rule from `measure_color`. Check you get one clean blob at
      the centre and at all four corners.
- [ ] Task 4: run `UR_CalibrateCamera` with five placements, starting each touch from Ready
      and using X/Y/Z only. Note the RMS (the simulation predicts 2 to 4 mm).
- [ ] Task 4 paste: copy the ten `UV`/`XY` lines and the `ref_pick_pose` line into the script.
      Confirm it runs with no syntax error.
- [ ] Task 5: teach the place waypoint with fingertips about 4 cm above the table.
- [ ] Task 6, first pick at 25 percent: confirm "Opening gripper..." prints and the gripper
      opens before step 1/7. This is the one new logic line.
- [ ] Task 6: do five picks at different spots. Note the grasp offsets and the printed cycle
      time at 25 percent and at 50 percent.

## 5. Failure cases worth two minutes each
- [ ] Leave the gripper closed, then run a pick: it should open before descending.
- [ ] Answer anything other than `yes`: the robot must not move.
- [ ] Put the block outside reach (beyond about 54 cm): expect "No joint solution" and no
      motion.
- [ ] Stop the program mid-pick: MATLAB should error within about a minute. Then follow the
      manual's recovery (jog up, open the gripper, Play, rerun).

## 6. Before Tuesday
- [ ] Reset your test values to the NaN placeholders in `UR_VisionPick_Lab.m`, and the default
      thresholds in both scripts.
- [ ] Delete `calibration_results.txt` from the lab folder.
- [ ] Re-import the Lab 5 Qualtrics file (objectives went from six items to five) and print
      the Rev1 paper form if you use paper.
- [ ] Check every student PC has the USB Webcams package visible to MATLAB (`webcamlist`
      works) and the camera on a USB 3 port.
- [ ] Set out per station: ruler, tape in a colour different from the block, one block, and
      the group's Lab 4 Ready position.
- [ ] Commit and push anything you changed, and write down what differed from the manual so
      the wording can be fixed before Tuesday.

If the new gripper-open line misbehaves, delete that one line in `UR_VisionPick_Lab.m`
(line 145, `grip(ur, 'release', gripSettle)` before step 1/7) and have students open the
gripper from the Robotiq screen before each run.
