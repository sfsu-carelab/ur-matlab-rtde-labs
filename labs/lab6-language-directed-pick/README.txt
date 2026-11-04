Lab 6 code - language-directed pick-and-place with a vision-language model (VLM)
================================================================================

Files
  gemini_generate.m        one REST call to the Gemini API (text + images), plain webwrite
  vlm_json.m               decode a JSON reply, tolerant of ```json fences
  vlm_point.m              "point to the red block" -> pixel [u v]
  vlm_plan.m               "put the red block on the blue square" -> pick + place pixels
  vlm_verify.m             before/after images -> did it work? (true/false + reason)
  xy_in_calibrated_area.m  refuse targets outside the Lab 5 calibration box
  genai_hello.m            Parts 1-2: first text / image / JSON calls, no robot
  UR_VLA_Lab.m             Parts 3-6: the staged robot script (reuses Lab 5 values)
  test_vlm_offline.m       run before class: offline parsing tests + live API check

Also needs on the path: Lab 5 Code folder (capture_realsense, detect_block,
fit_pixel_to_base, pixel_to_base).

API key (one per group, or one per class set by the instructor)
  1. Create a key at https://aistudio.google.com/apikey
  2. In MATLAB:   setenv('GEMINI_API_KEY', 'paste-key-here')     (this session only)
     or save it as the only line of a file named gemini_api_key.txt in this folder.
  3. Run  test_vlm_offline  - Part 2 confirms key, network and model id.
  NEVER paste the key into a script you hand in or upload. gemini_api_key.txt is
  listed in the repo .gitignore.

Network
  The robot link is a direct Ethernet cable with no internet. The PC must also
  be on Wi-Fi (or a second NIC) to reach the API. Section 7 of the hardware
  smoke test checks this.

Model
  Default: gemini-robotics-er-2-preview (Gemini Robotics-ER 2, pointing in
  [y, x] normalized to 0-1000). If Google retires it, change Model= in
  gemini_generate.m - see https://ai.google.dev/gemini-api/docs/robotics-overview
