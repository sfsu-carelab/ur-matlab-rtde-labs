# Lab 3 deep pass and hardware verification, 2026-11-06 (PC 17, UR3e)

Session with Ryan on lab PC COSE-SEC414-17. Goal: take a hard look at the Lab 3 manual
and code, test the lab with simulated students, and verify the FK end to end on the robot
without Ryan doing any calculation by hand. Everything here was done from the git clone
(`C:\Users\924414657\2026 Thesis\ur-matlab-rtde-labs`); the Box-layout folder is gone.

## 1. What was run and what passed

### Offline (batch MATLAB, log `offline_key_and_models.log`)
- `UR_FK_Lab_KEY('UR3e')`: ALL TESTS PASS.
- `test_all_models`: PoE vs UR DH model, worst 1.29e-15 m over 300 random poses on all
  eight models; screw2hw/hw2screw round trip 0.
- `checkcode` on the seven student files: clean.
- `UR_FK_Lab` as shipped (NaN): prints the "fill in PART 2 first" message and stops. Good.
- `UR_FK_Lab_KEY('UR5e')`: ALL TESTS PASS with the same symbolic entries.

### Live, read-only (batch MATLAB, log `live_check_working_pose.log`, script `lab3_live_check.m`)
New this session: the robot's own TCP pose and the active TCP offset are read from the
controller's secondary client interface (TCP port 30002, ROBOT_STATE message type 16,
CARTESIAN_INFO sub-package type 4, big-endian doubles). This is the number the pendant
shows in the Move screen with Feature = Base, so the manual's Task 4 comparison can be
done without anyone reading the pendant. Works on PolyScope X.

At the arm's working pose, pendant joints [0.73 -71.16 -34.21 -142.11 89.28 180.77] deg:
- FK flange vs `readCartesianPose`: 0.00 mm, Euler diff 2e-10 rad (model vs model, as on
  2026-10-28).
- FK flange vs the ROBOT's TCP (port 30002): 1.02 mm, 0.338 deg. Active TCP = [0 0 0].

### Motion: Lab 3 Task 4 (Table 6) run by Ryan from the MATLAB desktop
Tool: `instructor/hardware-validation/UR_FK_Lab3_Verify.m` (new). For each pose it
converts screw angles with `screw2hw`, moves with `sendJointConfigurationAndWait`
(EndTime 6 s) plus the labs' `waitForArrival`, reads joints over RTDE and the robot TCP
over port 30002, runs `fk_space` on the SCREW angles exactly as the manual tells students
to, and logs FK vs robot. Returns to the start pose. Has a DryRun option and a keep-out
box (see section 3).

| Pose | screw angles (deg) | pendant angles (deg) | FK position (m) | robot TCP (m) | err mm | ori deg | log folder |
|---|---|---|---|---|---|---|---|
| 1 home | [0 0 0 0 0 0] | [0 -90 0 -90 0 0] | [0.0000 -0.2232 0.6940] | [-0.0006 -0.2237 0.6934] | 1.03 | 0.349 | 151343 |
| 2 (manual) | [0 -45 45 0 0 0] | [0 -45 -45 -90 0 0] | [-0.1722 -0.2232 0.6226] | [-0.1727 -0.2239 0.6219] | 1.14 | 0.349 | 151343 |
| 3 | [30 -30 60 -30 0 0] | [30 -60 -60 -60 0 0] | [0.0984 -0.2008 0.6328] | [0.0983 -0.2016 0.6323] | 0.92 | 0.303 | 151343 |
| 4 | [-30 30 -30 30 0 0] | [-30 -120 30 -120 0 0] | [0.0308 -0.2755 0.6499] | [0.0298 -0.2754 0.6494] | 1.19 | 0.376 | 152626 |
| 5 | [-20 20 20 -40 60 0] | [-20 -110 -20 -50 -60 0] | [0.0715 -0.2145 0.6294] | [0.0709 -0.2146 0.6293] | 0.63 | 0.276 | 152626 |
| 6 | [-45 30 -30 -30 -60 90] | [-45 -120 30 -60 60 -90] | [-0.0205 -0.2300 0.6898] | [-0.0210 -0.2299 0.6896] | 0.59 | 0.251 | 152626 |

Measured joints matched the commanded pendant angles to 0.000 deg at every pose. Every
joint was exercised. Worst: 1.19 mm, 0.38 deg.

Interpretation of the residual: it is about 1 mm and 0.3 deg at every pose, including
home, so it is not a sign or offset error. It is the robot's factory kinematic calibration
(each UR ships with per-joint corrections to the nominal DH table) against the nominal
link lengths the lab uses. This is the textbook answer to Assessment Q4.

## 2. Code state

No student file was changed this session. New file:
`instructor/hardware-validation/UR_FK_Lab3_Verify.m` (instructor only, moves the robot,
run from the desktop). The read-only `lab3_live_check.m` is kept in this folder as a
reference for the port 30002 reader.

Three code issues found (not yet fixed, student-facing, need Ryan's go):
1. `run_self_tests.m` test 5(d): a CORRECT answer scores 7.15e-11 against tol 1e-10
   because `Rexp` is typed to 10 decimals. Store it exactly (it is the product of the six
   rotations, link-length independent) or give 5(d) its own tolerance such as 1e-8.
2. `run_self_tests.m` failure summary says "(and M for tests 1 and 5d)". 5(d) also fails
   on a wrong screw axis; all three simulated students failed 5(d) with a correct M.
3. Test 1 compares T to the M the student typed, so it passes for any M. Harmless, but
   the manual's Table 5 says "T should equal M exactly" as if M were being verified.

## 3. Safety event and room geometry

Run 2 (folder 151343) was e-stopped by Ryan at pose 4 of the first plan,
[-45 -60 90 -30 45 0] screw, FK x = -0.26 m: it was heading for the side wall. Nothing was
hit. Ryan then configured safety planes on the pendant. Room facts for future sessions:
- The cable exits toward the back wall, so the back wall is on the robot's +y side.
- Facing the robot from the front (back wall behind it), the side wall is on your LEFT,
  which is the robot's -x side.
- Free space: -y (toward the operator) and +x. x = -0.17 m (manual's pose 2) was fine.
- `UR_FK_Lab3_Verify` now computes elbow, wrist 1, wrist 2, wrist 3 and flange positions
  for every pose and refuses to move if any point has x < -0.18, y > 0.06 or z < 0.20 m.
- Leaning the arm toward +x and rotating the base POSITIVE swings it toward +y (the back
  wall). Rotate the base negative to swing a +x lean toward -y.
- A safety-plane violation is a protective stop; the script would then report "did not
  reach" and abort. Keep poses inside the box rather than relying on the planes.
Folder 152605 is an empty aborted start (no rows) and was deleted.

## 4. Manual review: three simulated students (personas A strong-math/weak-MATLAB,
B DH-background/trusts figures, C weakest/needs every step)

All three completed Parts 1 to 3 (A and B in two runs, C in two runs) and all three hit
the same trap:

**Figure 1 contradicts the lab's convention.** The figure is the Universal Robots DH
drawing with L1 to L6 added. Its blue (z) arrows point -y on joints 2, 3, 4 and 6 and +z
on joint 5, i.e. the hardware sense. The lab's screw axes are +y and -z (that is exactly
why `jointSignConvention` is [1 -1 -1 -1 -1 -1]). The manual never says the arrows are
not the omega directions. All three students copied the worked example for joints 2, 3,
4, 6, took joint 5 from the arrow, failed test 5(b) and 5(d), and recovered only because
5(b) names "Wrist 2". The only statement that omega_5 = (0,0,-1) is in Assessment Q2;
Q1 likewise prints omega for joints 2, 3, 4, 6. The figure also has no axis letters or
legend (RGB = xyz, circle-dot/circle-cross are never explained), the only clue that +y
points page-left is a small green arrow at the base, joints are not numbered (only
"Link 0..5"), and the L5 dimension is easy to misread.

Secondary gaps, all cheap:
- Table 4 calls the columns of R "rows R_x, R_y, R_z". The correct R is symmetric so a
  transposed entry still passes; the self-test cannot catch the misconception.
- General cross-product formula never written; the worked example never covers an omega
  along z with a q off the base axis (joint 5).
- Part 4 never shows a complete call `T = fk_space(S_list, M, [0 -45 45 0 0 0])`, never
  says the position is `T(1:3,4)`, never says pendant mm vs Table 6 m, no error formula
  `norm(T(1:3,4) - p_robot)*1000`, and S_list/M only exist after UR_FK_Lab has run in the
  same session.
- Task 3 never states the expected home reading [0 -90 0 -90 0 0].
- No PolyScope X screen paths for: set TCP to zero, read TCP with Feature = Base, jog one
  joint, type six joint targets.
- "each ROW is S_i" in the file next to ".' transpose so each COLUMN is one screw axis"
  confused the weakest student; also "run UR_FK_Lab()" vs pressing Run, "base workspace".
- Manual says errors are "typically near machine epsilon, ~1e-16" but 5(d) prints 7e-11
  and 5(e) prints a reach that is never explained.
Student time estimates: 65 min (B) to 3 to 4 h (C) for Parts 1 to 3; most of the spread
is Figure 1.

## 5. Proposed next steps (need Ryan's go; manual edits now allowed since the code is
verified on hardware)

Code (small):
1. Fix 5(d) tolerance/precision, fix the failure summary wording, and say in the manual
   that test 1 is a consistency check, not a check of M.
Manual (Lab 3 docx, Rev1 -> Rev2):
2. Replace or annotate Figure 1: labelled base axes (x into page, +y to the LEFT, z up),
   joints numbered 1 to 6, each omega drawn in the lab's convention, legend for colours
   and circle symbols. Add one sentence: the coloured triads are UR's DH frames; the screw
   directions for joints 2 to 6 are the opposite of their blue arrows, which is the same
   reversal as the sign flip in Part 4.
3. Put omega_5 = (0,0,-1) and the reason in Part 1; rewrite Q1 and Q2 so they do not
   print the answers.
4. Table 4: say columns. Add the general cross-product formula and a second worked
   example for joint 5.
5. Part 4 as a checklist with PolyScope X screen names, expected theta_home, the exact
   MATLAB lines (fk_space call, T(1:3,4), error in mm), and the mm to m note. Consider
   making the instructor verification numbers above the sample answers for Table 6.
6. Add a "Running the MATLAB file" box (one folder, Current Folder, type the name or press
   Run, what "saved to the base workspace" means).
Runbook: add `UR_FK_Lab3_Verify` to section 3 (Lab 3) and the room/keep-out note.

## 6. Open questions
- Lab 3 manual Table 6 pose 2 is at x = -0.17 m in this room: fine today, but the manual
  should tell students to check the arm's clearance before commanding any pose.
- Whether to show students the port 30002 TCP reader (it makes Task 4 almost automatic);
  current manual intent is that they read the pendant themselves.
