# Lab 3 Rev3, 2026-11-09 (Mac session, no robot)

Trigger: Dr. Quintero edited the Rev2 manual on Box on 2026-11-08 (typed directly into the
text, no Word comments or tracked changes) and sent Ryan a long review email. Ryan's
decisions today: switch to the robot's own joint directions, simplify Part 4, name the
lengths L1 to L6, keep the lab a hardware lab with URSim only as a fallback, build a new
Rev3 file on top of the professor's Rev2.

## What changed

Convention (student-facing, approved by Ryan):
- Screw axes now use the directions the Teach Pendant counts as positive: joints 1 and 5
  about +z, joints 2, 3, 4 and 6 about -y. Pendant and screw angles differ only by
  `theta_home = [0 -90 0 -90 0 0]`. `jointSignConvention.m` deleted; `screw2hw`/`hw2screw`
  are a pure offset. Figure 1's red arrows now agree with the blue arrows of UR's own
  drawing (Figure 2), which removes the Figure 1 vs Figure 2 conflict.
- Link lengths renamed d1 a2 a3 d4 d5 d6 -> L1..L6 in `ur_link_lengths.m` (struct fields),
  `UR_FK_Lab.m`, key, self-tests, `UR_FK_Lab3_Verify.m`, `UR_HardwareSmokeTest.m`.
- Every function file has INPUT / OUTPUT / EXAMPLE in its header (professor's request).
- `run_self_tests` is shipped to students as `run_self_tests.p`. Source moved to
  `labs/lab3-forward-kinematics/instructor/run_self_tests.m` (gitignored); rebuild with
  `instructor/build_pfile.m`. The old readable version is still in the public git history.
- Self-test expected values rewritten for the new directions (test 2 now swings to -x, etc.).
- Figure 1 redrawn (`labs/lab3-forward-kinematics/instructor/figure1/`, moved out of
  `resources/` so the lab folder is self-contained): arrows reversed on joints 2 to 6,
  curved right-hand-rule arrows added, labels are L1..L6 only.
- `UR_FK_Lab3_Verify.m`: same six physical poses, rewritten as screw = pendant - home.

Manual Rev3 (`Lab 3 - Forward Kinematics.docx` = `_Rev3.docx`), built by `build_rev3.py`
in this folder from the professor's Rev2 (his header/footer, captions and wording kept):
- Part 1 rewritten for the new directions; says why Figure 2 is there and that one figure
  serves every e-series model.
- Worked example redone for omega_2 = (0,-1,0), v_2 = (L1,0,0); cross product in i/j/k form.
- Joint 5 answer removed (one hint left: its axis does not cross the base z-axis).
- "How to Build the Rotation Matrix R" cut to one paragraph inside Task 2.
- Part 4: Task 3 is the angle mapping with one worked pose (no robot motion, no upright
  Home needed). Task 4 is jog, read, compare at three poses, with the tool offset as a
  `tcp` vector the student reads from their own pendant (Robotiq 2F-85 from Lab 1 as the
  example). URSim mentioned in one sentence as the fallback.
- Full text: `rev3_text.txt`.

New: `labs/lab3-forward-kinematics/instructor/Lab 3 - Instructor Solutions.docx`
(gitignored): Tasks 1 to 4 answers, the 2026-11-06 robot measurements re-labelled in the new
convention, notes for the assessment questions.

## Verification (all offline, MATLAB R2024b on the Mac)
- `UR_FK_Lab_KEY` UR3e, UR5e, UR30: ALL TESTS PASS through the p-file.
- `test_all_models`: worst PoE vs UR DH disagreement 1.4e-15 m over 8 models, round trip 0.
- `UR_FK_Lab` template (NaN): prints the fill-in message and stops.
- 2026-11-06 robot data (pendant angles + robot TCP at 6 poses) through the new model:
  0.58 to 1.15 mm, same as measured that day.
- checkcode: 0 messages on every Lab 3 file and on `UR_FK_Lab3_Verify.m`; the smoke test
  keeps its two old cosmetic messages.
- Rev3 docx: zip entry names clean, every XML part parses, python-docx opens it, 0 em dashes.

## NOT done / open
- Nothing was run on the robot today. The pendant-positive directions are taken from the
  2026-10-28 and 2026-11-06 hardware results (old sign vector [1 -1 -1 -1 -1 -1]); a
  two-minute check on the robot (jog joint 2 positive, arm tips toward -x) would close it.
- Rev3 has not been opened in Word. Check Figure 1 size, the two display equations in the
  worked example, and list numbering in Tasks 3 and 4.
- PolyScope X screen names in Part 4 are still generic ("Installation, TCP", "Move screen").
- The 174 mm Robotiq TCP example is carried over from the earlier manual; confirm against
  Lab 1.
- URSim: the claim that its error is near zero assumes the simulator uses nominal lengths.
- README.md (five labs, RealSense wrapper, wrist camera) and the runbook are still stale.

## Later the same day
- Ryan opened Rev3 in Word and saved it (it opens fine); he removed "that is clear of the
  table, the walls and the camera" from Task 4 step 1.
- Task 4 tool-offset paragraph now sends students to the gripper manual (Robotiq manual
  Section 6.2.3, hyperlinked, same table as Lab 1 Section 3.2) instead of reading the TCP
  off the pendant, and says the same offset must be set as the TCP on the robot.
  `rev3_text.txt` in this folder predates both edits.
- Lab 3 survey: objective 5 reworded (home offset, no sign flips) and a "URSim (simulator)"
  model choice added, in both Qualtrics files and the paper form (previous form kept as _Rev1).
