# Lab 6 - Language-Directed Pick-and-Place with a Vision-Language Model (OUTLINE, Rev0 draft)

Accompanying MATLAB files: genai_hello.m, UR_VLA_Lab.m, gemini_generate.m, vlm_json.m,
vlm_point.m, vlm_plan.m, vlm_verify.m, xy_in_calibrated_area.m, test_vlm_offline.m
(plus the Lab 5 files capture_realsense.m, detect_block.m, fit_pixel_to_base.m, pixel_to_base.m)

Status: code written and tested offline (2026-10-28). To be typeset into the Lab 5 docx
style after the first live run on the robot confirms the model's behavior.

## Overview
In Lab 5 you told the robot what a block looks like with three numbers (an HSV range).
In this lab you tell it in a sentence. A vision-language model (VLM) hosted in the cloud
receives the camera image and your instruction, and answers with pixel coordinates: where
to pick, where to place. Your Lab 5 calibration turns those pixels into robot coordinates
exactly as before. After the move, a second picture goes back to the model with the
question "did it work?", and the script re-plans if the answer is no. That loop, perceive -
plan - act - verify, is the shape of every current vision-language-action (VLA) system; here
each stage is a function you can read.

## Prerequisites
- Labs 1 to 5 completed; the Lab 5 values at hand (imaging pose, calibration table UV/XY,
  reference pick pose, HSV thresholds)
- A Gemini API key (free, Google AI Studio) - one per group, issued by the instructor
- The lab PC on the internet (Wi-Fi) at the same time as the robot Ethernet link
- Two blocks of different colors and one "destination" (a bowl, a taped square)

## Learning objectives
- Call a hosted generative model from MATLAB with webwrite, read the JSON it returns, and
  account for what it costs (tokens, latency)
- Explain the difference between a classical detector (HSV threshold) and a VLM, and measure
  when each one is better
- Convert the model's normalized [y, x] points to pixels and then to base coordinates, and
  explain why the Lab 5 calibration is still required
- Design prompts that make the model answer in a fixed machine-readable format
- Add two safety layers between a language model and a moving robot: a workspace bounds
  check and a human confirmation
- Close the loop with a verification step and explain its limits

## Background
1. What a VLM is (a model that takes images and text, returns text); what a VLA adds
   (actions). Gemini Robotics-ER is a VLM trained to answer spatial questions: points,
   boxes, trajectories. It returns points as [y, x] normalized 0-1000 - note the order.
2. Why we still calibrate: the model sees pixels, not metres. It cannot know where the
   camera is. Pixel to base is your Lab 5 affine map; everything in this lab sits on top of it.
3. Structured output: ask for JSON, parse with jsondecode, never regex the prose.
4. Non-determinism and safety: the same prompt can give different answers; the robot must
   never move to an unchecked point. Bounds check + confirmation + low speed.
5. Latency and cost: a pointing call takes 1-5 s; thinking levels trade speed for accuracy.

Table 1 - Key functions (one row per file, as in Lab 5).

## Part 1 - Your first model call (no robot)
Task 1: save the API key; run genai_hello. Record in Table 2 the three replies and token
counts. Run it twice; note which replies changed.

## Part 2 - Pointing with words (Stages A-B)
Task 2: paste the Lab 5 imaging pose and calibration; set target_object. Run UR_VLA_Lab.
Table 3: for each of three blocks/colors, the VLM point, the HSV centroid, the distance
in px, and the time taken. Try two deliberately ambiguous descriptions ("the block",
"the small one") and record what came back.

## Part 3 - Planning from an instruction (Stage C)
Task 3: set instruction. Record the pick/place pixels, the base XY, the bounds check
verdict and the model's reason. Then write an instruction that sends the place point OUTSIDE
the calibrated area and show that the script refuses to move (Table 4).

## Part 4 - Execute and verify (Stage D)
Task 4: paste ref_pick_pose. Speed 10 percent. Run five instructions (Table 5): instruction,
pick success, place success, verify verdict, diagnostics text, attempts used. Include one
case where you move the block by hand between planning and execution, so the first attempt
fails and the retry loop runs.

## Part 5 - Prompt engineering (optional)
Edit the prompt in vlm_plan.m (e.g. ask for a safety margin from other objects, or for the
block's orientation angle). Record what changed.

## Assessment questions
Q1. The model returned a point for "the red block" when there was no red block. What in
the pipeline caught it, or should have? Name the two layers in this lab that stand between
the model's answer and the motor command.
Q2. Compare the VLM point with the HSV centroid over Table 3. Which was closer to the true
center, which was faster, and which would you trust under changed lighting? Under a new
object you have never seen?
Q3. Why does the VLM output still need the Lab 5 calibration? What would it take for the
model to output base-frame coordinates directly, and why is that harder to trust?
Q4. vlm_verify judged a failed pick as a success (or vice versa) in trial __. Explain one
way a before/after image pair can mislead the model, and one additional sensor or check
that would fix it.
Q5. The loop here is plan - act - verify - re-plan, once per attempt. A true VLA policy
runs at several hertz. List two things that would have to change in this script, and two
reasons the calibration-plus-fixed-pose approach would break at that rate.

Deliverable: Tables 2 to 5, one screenshot of a Stage C overlay, and a live run of one
instruction for the instructor.
