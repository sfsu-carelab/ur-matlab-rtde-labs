# Lab 4 student action log (UR3e, Robotiq 2F-85, PolyScope X)

Who I am: ME undergrad. All I know about this robot is Labs 1, 2 and 3. Numbers below are readings I wrote down (invented but kept consistent); I did not calculate any of them.

Format: N. [manual ref] ACTION. EXPECT. BASIS.

## Before You Start

1. [Before You Start, bullet 1] ACTION: Look at the Teach Pendant, bottom left Power button area, and check that the robot state says Active (powered on, unlocked). I change nothing. EXPECT: it says Active. BASIS: taught in Lab 1, Section 2.
2. [Before You Start, bullet 1] ACTION: Left sidebar, tap Application, tap End Effectors, look at the entry from Lab 1: Payload 0.921 kg, CoG (0, 0, 60), TCP (0, 0, 174 mm). I change nothing and tap out. EXPECT: the values from Lab 1 are still there. BASIS: taught in Lab 1, Section 3.2.
3. [Before You Start, bullet 2] ACTION: On the lab PC open Windows PowerShell, type `ping 192.168.1.10`, press Enter. EXPECT: four reply lines. BASIS: taught in Lab 2, Part 4 Task 3.
4. [Before You Start, bullet 3] ACTION: Put the cube next to the robot, look at the two tape marks, decide the left one (as I face the robot) is "pick" and the right one is "place". EXPECT: nothing. BASIS: GUESS (manual does not say which mark is which; I assume it does not matter).
5. [Before You Start, bullet 4] ACTION: In MATLAB, look at the Current Folder panel and check that UR_PickPlace_Lab.m and check_waypoints.p are listed. If not, use the folder browser to go to the lab4-pick-and-place folder. EXPECT: both files listed. BASIS: Lab 4 step text.
6. [Before You Start, warning] ACTION: Tell my lab partners to stand outside the arm's reach and put the pendant where my left hand rests next to the red e-stop. EXPECT: nothing. BASIS: Lab 4 step text.

## Part 1, Task 1: Record and Store the Waypoints

7. [Task 1 step 1] ACTION: Drag the speed slider at the bottom right of the pendant screen to 25%. EXPECT: slider shows 25%. BASIS: taught in Lab 1, Section 2.
8. [Task 1 step 1] ACTION: Left sidebar, tap Program. Tap the program name at the top of the screen. EXPECT: some kind of menu or dialog with a way to make a new program. BASIS: taught in Lab 2, Part 2 (it only said "by tapping the program name").
9. [Task 1 step 1] ACTION: In that menu tap the option that says New (or "+ New Program"). If it asks whether to save the currently open program, tap Save. EXPECT: a name field with an on-screen keyboard. BASIS: GUESS.
10. [Task 1 step 1] ACTION: Type `Lab4_Group1` on the on-screen keyboard and tap the confirm/OK button. EXPECT: the top of the screen now says Lab4_Group1 and the program tree shows only an empty Main Program line. BASIS: GUESS (Lab 4 gives the name, not the taps).
11. [Task 1 step 2] ACTION: Right sidebar, tap Move. Read the six joint values. They read about [0.00, -90.00, 0.00, -90.00, 0.00, 0.00], the arm is standing upright. EXPECT: Move screen with joint list and TCP position. BASIS: taught in Lab 1, Section 2 and Lab 3, Task 4.
12. [Task 1 step 2] ACTION: On the Move screen hold the arrow for Shoulder (joint 2) that makes the number go from -90 toward -80, release near -80, then tap in short presses until it reads -79.95. EXPECT: upper arm leans about 10 degrees. BASIS: jogging joints done in Lab 3, Task 4 (which arrow is "+" I find by a short tap).
13. [Task 1 step 2] ACTION: Hold the Elbow (joint 3) arrow that makes the number go negative until it reads about -80, short taps to -80.10. EXPECT: forearm folds over, about 80 degrees. BASIS: Lab 3, Task 4.
14. [Task 1 step 2] ACTION: Hold the Wrist 1 (joint 4) arrow from -90 to about -110, short taps to -109.98. I check on paper that -79.95 - 80.10 - 109.98 is about -270. EXPECT: wrist tips. BASIS: Lab 4 step text ("joints 2, 3 and 4 add up to -270").
15. [Task 1 step 2] ACTION: Hold the Wrist 2 (joint 5) arrow from 0 up to about 90, short taps to 90.03. EXPECT: gripper now points straight down at the table, like Figure 1. BASIS: Lab 4 step text ("joint 5 reads 90").
16. [Task 1 step 2] ACTION: Hold the Base (joint 1) arrow until it reads -15.02 so the gripper is roughly between the two tape marks. Leave Wrist 3 at 0.00. EXPECT: whole arm swings a little. BASIS: GUESS (manual says "of your choosing"; I picked a base angle that faces the marks).
17. [Task 1 step 2] ACTION: Hold a ruler vertically between the table and the fingertips. It reads about 21 cm. EXPECT: more than 15 cm. BASIS: Lab 4 step text.
18. [Task 1 step 3] ACTION: On the Move screen look at the frame selector next to the TCP position. Lab 3 called it "feature". I tap it and choose Base. EXPECT: X, Y, Z shown in the base frame. BASIS: taught in Lab 3, Task 4 (Lab 4 step 3 does not mention it; step 6 does, under the word "reference").
19. [Task 1 step 3] ACTION: Write in Table 3, row Ready: J1 -15.02, J2 -79.95, J3 -80.10, J4 -109.98, J5 90.03, J6 0.00, X 118.35, Y -279.10, Z 212.47. EXPECT: nothing. BASIS: Lab 4 step text.
20. [Task 1 step 4] ACTION: Left sidebar, tap Program. Tap the + icon under the Main Program line. EXPECT: a list of node types appears. BASIS: taught in Lab 2, Part 3 step 3.
21. [Task 1 step 4] ACTION: In the node list tap "Joint Move". (If I only saw "Move To" I would stop and read ahead; Part 2 says to use it and set Move type to Joint.) EXPECT: a Joint Move node appears under Main Program. BASIS: Lab 4 step text.
22. [Task 1 step 4] ACTION: Tap the new node to select it. In the panel that opens on the right, tap the name field (or a pencil icon next to the name), delete the default name, type `Ready`, tap OK. EXPECT: the node reads "Ready" in the tree. BASIS: GUESS (manual says "name it Ready" but not where the name field is).
23. [Task 1 step 4] ACTION: In the same node panel tap the button labelled Edit Point. EXPECT: a screen that looks like the Move screen with the current pose and a Save button. BASIS: Lab 4 step text (location of the button is a GUESS).
24. [Task 1 step 4] ACTION: Without touching any jog arrow, tap Save. EXPECT: back to the program tree; the Ready node no longer shows a warning/undefined mark. BASIS: Lab 4 step text.
25. [Task 1 step 5] ACTION: Look for the Robotiq gripper screen: left sidebar, tap Application, look for an entry named Robotiq or Gripper and tap it. If it is not there, tap the hamburger menu and look there. EXPECT: a screen with Activate, Open and Close buttons. BASIS: GUESS (no earlier lab showed where the URCap puts this screen).
26. [Task 1 step 5] ACTION: Tap Activate. Wait while the fingers close and open by themselves. EXPECT: status changes to activated after a few seconds. BASIS: Lab 4 step text (the wait is a GUESS).
27. [Task 1 step 5] ACTION: Tap Open. EXPECT: fingers fully open. BASIS: Lab 4 step text.
28. [Task 1 step 5] ACTION: Put the cube on the pick tape mark by hand, flat faces roughly square to the robot. EXPECT: nothing. BASIS: Lab 4 step text.
29. [Task 1 step 6] ACTION: Right sidebar, tap Move. Check that the frame selector still says Base (I set it in action 18). EXPECT: Base. BASIS: Lab 4 step text plus Lab 3, Task 4 (I assume "reference" and "feature" are the same control).
30. [Task 1 step 6] ACTION: Find the TCP position arrows on the Move screen (the ones labelled X, Y, Z, not the rotation ones and not the joint ones). Tap the X+ arrow once, briefly, and watch which way the gripper moves over the table. Same for Y+. EXPECT: gripper slides a few mm sideways without tilting; X and Y readouts change. BASIS: GUESS (Lab 3 only had me jog joints; Lab 4 says "jog only along X, Y and Z" but not which buttons).
31. [Task 1 step 6] ACTION: Hold the X arrow until X goes from 118 to about 142, then the Y arrow until Y goes from -279 to about -301, sighting from above so the gripper is over the cube. EXPECT: gripper centered above the cube, still about 21 cm up. BASIS: Lab 4 step text.
32. [Task 1 step 6] ACTION: Hold the Z down arrow. Z goes from 212 down; I release at about 60 mm, crouch to look from the side, then use short taps down to about 20 mm. EXPECT: open fingers come down on either side of the cube. BASIS: Lab 4 step text.
33. [Task 1 step 6] ACTION: The fingers are not parallel to the cube faces, so I turn the cube by hand about 15 degrees on the mark until two flat faces face the finger pads. EXPECT: cube square to the fingers. BASIS: Lab 4 step text ("turning the cube if needed").
34. [Task 1 step 6] ACTION: Short taps on X and Y to center the cube between the fingers (X 142.60, Y -301.25), then short taps on Z down until the fingertips look about 5 mm above the table (I slide a 5 mm stack of sticky notes under a fingertip). Z reads 7.40. EXPECT: fingertips just clear of the table. BASIS: Lab 4 step text (using sticky notes as a gauge is my own idea).
35. [Task 1 step 6] ACTION: Go back to the Robotiq gripper screen (same path as action 25) and tap Close. EXPECT: fingers close on the cube and stop; cube is held. BASIS: Lab 4 step text; path is the GUESS from action 25.
36. [Task 1 step 6] ACTION: Tap Open. EXPECT: fingers open, cube stays on the mark. BASIS: Lab 4 step text.
37. [Task 1 step 6] ACTION: Right sidebar, tap Move, read the values and write Table 3 row Pick: J1 -12.48, J2 -118.36, J3 -96.71, J4 -54.96, J5 90.03, J6 2.54, X 142.60, Y -301.25, Z 7.40. EXPECT: nothing. BASIS: Lab 4 step text.
38. [Task 1 step 6] ACTION: Left sidebar, tap Program. Tap the Ready node so it is selected, tap +, tap "Linear Move" in the node list. EXPECT: a Linear Move node appears below Ready. BASIS: Lab 4 step text ("node type listed in Table 2"); that + inserts below the selected node is a GUESS.
39. [Task 1 step 6] ACTION: Tap the new node, tap its name field, type `Pick`, OK. Tap Edit Point, then tap Save without jogging. EXPECT: node "Pick" stored at the current pose. BASIS: Lab 4 step text ("in the same way").
40. [Task 1 step 7] ACTION: Right sidebar, tap Move. Hold the Z up arrow until Z goes from 7.40 to about 87 (8 cm). Release at 87.52. EXPECT: gripper rises straight up, cube stays on the table. BASIS: Lab 4 step text.
41. [Task 1 step 7] ACTION: Write Table 3 row Pre-Pick: J1 -12.48, J2 -107.92, J3 -89.14, J4 -72.97, J5 90.03, J6 2.54, X 142.61, Y -301.24, Z 87.52. Copy the same nine numbers into the Retract row. EXPECT: nothing. BASIS: Lab 4 step text.
42. [Task 1 step 7] ACTION: Left sidebar, tap Program, tap the Pick node, tap +, tap "Joint Move". Tap the new node, name field, type `Pre-Pick`, OK, tap Edit Point, tap Save. EXPECT: node "Pre-Pick" below Pick. BASIS: Lab 4 step text. (I do not make a Retract node now because the text says "copy its values into the Retract row", only the row.)
43. [Task 1 step 8] ACTION: Right sidebar, tap Move. Hold the X arrow in the negative direction until X goes from 142.6 to about -96, then the Y arrow until Y reads about -319, sighting from above until the open fingers straddle the center of the place mark. Final X -96.30, Y -318.75. EXPECT: gripper travels sideways at 87 mm height to above the place mark. BASIS: Lab 4 step text.
44. [Task 1 step 8] ACTION: Hold the Z down arrow, release near 20 mm, short taps until Z reads 7.42 (as close as I can get to the Pick Z of 7.40). EXPECT: fingertips about 5 mm above the table at the place mark. There is no cube here; I judge by the tape. BASIS: Lab 4 step text.
45. [Task 1 step 8] ACTION: Write Table 3 row Place: J1 -52.80, J2 -121.05, J3 -92.44, J4 -56.54, J5 90.03, J6 -37.78, X -96.30, Y -318.75, Z 7.42. EXPECT: nothing. BASIS: Lab 4 step text.
46. [Task 1 step 8] ACTION: Left sidebar, tap Program, tap the Pre-Pick node, tap +, tap "Linear Move". Tap the new node, name field, type `Place`, OK, tap Edit Point, tap Save. EXPECT: node "Place" below Pre-Pick. BASIS: Lab 4 step text.
47. [Task 1 step 8] ACTION: Right sidebar, tap Move. Hold the Z up arrow until Z reads about 85. Release at 85.10. EXPECT: gripper rises straight up about 8 cm. BASIS: Lab 4 step text.
48. [Task 1 step 8] ACTION: Write Table 3 row Pre-Place: J1 -52.80, J2 -110.26, J3 -85.63, J4 -74.14, J5 90.03, J6 -37.78, X -96.31, Y -318.74, Z 85.10. EXPECT: nothing. BASIS: Lab 4 step text.
49. [Task 1 step 8] ACTION: Left sidebar, tap Program, tap the Place node, tap +, tap "Joint Move". Tap the new node, name field, type `Pre-Place`, OK, tap Edit Point, tap Save. EXPECT: node "Pre-Place" below Place. Tree is now: Ready, Pick, Pre-Pick, Place, Pre-Place. BASIS: Lab 4 step text.
50. [Task 1 step 9] ACTION: On paper compare rows: Pre-Pick vs Pick X 142.61 vs 142.60, Y -301.24 vs -301.25; Pre-Place vs Place X -96.31 vs -96.30, Y -318.74 vs -318.75. EXPECT: all within 2 mm. They are. BASIS: Lab 4 step text.

## Part 2, Task 2: Build the Program

51. [Task 2 step 1] ACTION: In the program tree tap the Pre-Pick node. Look for an up-arrow icon (on the node row or in a toolbar above/below the tree) and tap it once. EXPECT: order becomes Ready, Pre-Pick, Pick, Place, Pre-Place. BASIS: Lab 4 step text; where the Move up icon is, is a GUESS.
52. [Task 2 step 1] ACTION: Tap the Pre-Place node, tap the up-arrow icon once. EXPECT: order becomes Ready, Pre-Pick, Pick, Pre-Place, Place. BASIS: Lab 4 step text.
53. [Task 2 step 2] ACTION: Tap the Pick node, tap +, tap "Linear Move". Tap the new node, name field, type `Retract`, OK. EXPECT: Retract node between Pick and Pre-Place. BASIS: Lab 4 step text (node type from Table 2 and the eleven-node list).
54. [Task 2 step 2] ACTION: On the Retract node tap Edit Point. On the screen that opens tap the tab labelled Joints. EXPECT: six number fields, one per joint, showing the current robot angles. BASIS: Lab 4 step text.
55. [Task 2 step 2] ACTION: Tap the Base field, on the keypad type `-12.48`, confirm. Then Shoulder `-107.92`, Elbow `-89.14`, Wrist 1 `-72.97`, Wrist 2 `90.03`, Wrist 3 `2.54`, confirming each. I do not press any button that would move the robot there. EXPECT: the fields show my numbers; the robot does not move. BASIS: Lab 4 step text; that typing does not move the arm is a GUESS.
56. [Task 2 step 2] ACTION: Tap Save. EXPECT: back to the tree, Retract is defined. BASIS: Lab 4 step text.
57. [Task 2 step 2] ACTION: Tap the Place node (last in the tree), tap +, tap "Linear Move". Tap the new node, name field, type `Pre-Place`, OK. If the pendant refuses a duplicate name I type `Pre-Place 2`. EXPECT: a second Pre-Place node after Place. BASIS: Lab 4 step text (node type from the eleven-node list, item 10); duplicate name handling is a GUESS.
58. [Task 2 step 2] ACTION: On that node tap Edit Point, tap the Joints tab, type Base `-52.80`, Shoulder `-110.26`, Elbow `-85.63`, Wrist 1 `-74.14`, Wrist 2 `90.03`, Wrist 3 `-37.78`, tap Save. EXPECT: node defined. BASIS: Lab 4 step text.
59. [Task 2 step 2] ACTION: Tap the second Pre-Place node, tap +, tap "Joint Move". Tap the new node, name field, type `Ready` (or `Ready 2` if refused), OK. Tap Edit Point, Joints tab, type Base `-15.02`, Shoulder `-79.95`, Elbow `-80.10`, Wrist 1 `-109.98`, Wrist 2 `90.03`, Wrist 3 `0.00`, tap Save. EXPECT: second Ready node at the end. BASIS: Lab 4 step text.
60. [Task 2 step 3] ACTION: Tap the first Ready node, tap +, scroll the node list for an entry with "Robotiq" or "Gripper" in the name and tap it. EXPECT: a gripper node below Ready. BASIS: Lab 4 step text; the node's exact name is a GUESS.
61. [Task 2 step 3] ACTION: Tap the new gripper node; in its panel choose the Open option (a button, toggle or dropdown). EXPECT: node reads something like "Gripper Open". The real gripper may or may not move when I set this. BASIS: Lab 4 step text ("set each one to open or close"); the control is a GUESS.
62. [Task 2 step 3] ACTION: Tap the Pick node, tap +, tap the Robotiq gripper node, tap it, choose Close. EXPECT: gripper node between Pick and Retract. BASIS: Lab 4 step text.
63. [Task 2 step 3] ACTION: Tap the Place node, tap +, tap the Robotiq gripper node, tap it, choose Open. EXPECT: gripper node between Place and the second Pre-Place. BASIS: Lab 4 step text.
64. [Task 2, node list] ACTION: Read the tree top to bottom against the manual's list and count: Ready, Gripper open, Pre-Pick, Pick, Gripper close, Retract, Pre-Place, Place, Gripper open, Pre-Place, Ready. EXPECT: eleven nodes in that order, none with a warning mark. BASIS: Lab 4 step text.
65. [Task 2 step 4] ACTION: Tap the program name at the top of the screen and tap Save in the menu that opens (or tap a disk/save icon if I see one first). EXPECT: a short "saved" message. BASIS: GUESS (Lab 2 never had me save a program explicitly).

## Part 2, Task 3: Test the Program

66. [Task 3 step 1] ACTION: Look at the cube. It is still on the pick mark, turned the way I left it in action 33. I nudge nothing. EXPECT: nothing. BASIS: Lab 4 step text.
67. [Task 3 step 2] ACTION: Drag the speed slider (bottom right) to 10%. EXPECT: 10%. BASIS: Lab 4 step text; slider from Lab 1.
68. [Task 3 step 2] ACTION: Say "robot moving" out loud, rest my left hand by the e-stop, press Play at the bottom of the screen. If a popup asks me to confirm or hold a button to move to the start position, I do what it says. EXPECT: the robot moves slowly from Pre-Place (where I left it) to Ready, the gripper opens, then Pre-Pick, straight down to Pick, grip, up, across, down, release, up, back to Ready, then the program stops by itself. BASIS: Lab 4 step text; Play from Lab 2 Part 5; the popup handling is a GUESS.
69. [Task 3 step 2] ACTION: Wait and watch the whole cycle, about 2 minutes at 10%. EXPECT: cube ends on the place mark, robot at Ready, Play button back to its idle look. BASIS: Lab 4 step text.
70. [Task 3 step 3] ACTION: Nothing to correct: the gripper took the cube and did not touch the table. I skip the Edit Point correction. EXPECT: n/a. BASIS: Lab 4 step text (conditional step).
71. [Task 3 step 4] ACTION: Carry the cube by hand from the place mark back to the pick mark, same orientation as before. EXPECT: nothing. BASIS: GUESS (the manual does not say to put the cube back between runs, but the run cannot work otherwise).
72. [Task 3 step 4] ACTION: Drag the speed slider to 50%. Press Play. Hand at the e-stop. Watch the cycle. EXPECT: same sequence, about five times faster. BASIS: Lab 4 step text.
73. [Task 3 step 5] ACTION: Move the cube back to the pick mark again. Partner holds a phone stopwatch. I press Play and say "go"; partner starts the stopwatch, and stops it when the arm comes to rest at Ready. Slider untouched at 50%. EXPECT: a time around half a minute. We read 26.4 s. BASIS: Lab 4 step text (I read steps 4 and 5 as two separate runs; that is a GUESS).
74. [Task 3 step 5] ACTION: Measure with a ruler how far the cube sits from the place mark: about 1.5 mm. Write in Table 5, Teach Pendant column: cycle time 26.4 s, pick success Y, place accuracy good. EXPECT: nothing. BASIS: Lab 4 step text and Task 6 rating rule.
75. [Task 3, observations] ACTION: Write: picked and placed Y; test runs to get it working: 1; waypoints adjusted: none. EXPECT: nothing. BASIS: Lab 4 step text.

## Part 3, Task 4: Connect and Verify

76. [Task 4 step 1] ACTION: Tap the program name at the top of the screen, tap Save. EXPECT: saved message. BASIS: Lab 4 step text; taps are the GUESS from action 65.
77. [Task 4 step 1] ACTION: Tap the program name again, tap Open (or Load) in the menu, and in the list tap the program my group made in Lab 2 (ours was called "Semester 2026"). EXPECT: the tree now shows one node, "Script Code: URServerScript_Robotiq2F_PolyScopeX.script". BASIS: Lab 4 step text; the Open and list taps are a GUESS (Lab 2 only created a program this way, never reopened one).
78. [Task 4 step 1] ACTION: Check the tree really shows the Script Code node with that file name. Leave the speed slider where it is (50%). Press Play at the bottom of the screen. EXPECT: the Script Code node turns green and stays green; the robot does not move. BASIS: taught in Lab 2, Part 5 step 1 and Part 6.
79. [Task 4 step 2] ACTION: In MATLAB, double-click UR_PickPlace_Lab.m in the Current Folder panel. Scroll to the banner "TASK 4 - ESTABLISH THE RTDE CONNECTION". Read line `robotIP = "192.168.1.10";` and line `cobotName = 'universalUR3e';`. Both already match, so I edit nothing. EXPECT: no change needed. BASIS: Lab 4 step text.
80. [Task 4 step 3] ACTION: Click in the Command Window, type `UR_PickPlace_Lab`, press Enter. EXPECT: after a few seconds, a box "RTDE Connection Established", Robot IP, "Joint angles (deg): [...]", "Flange position (m): [...]", then "Waypoints are not entered yet (TASK 5), so the robot will not move." Robot stays still. BASIS: Lab 4 step text.
81. [Task 4 step 4] ACTION: Copy from the Command Window into Table 4, MATLAB row: -15.02, -79.96, -80.10, -109.98, 90.03, 0.00. EXPECT: nothing. BASIS: Lab 4 step text.
82. [Task 4 step 4] ACTION: On the pendant, right sidebar, tap Move (the program keeps playing). Read the joint list into Table 4, Teach Pendant row: -15.02, -79.95, -80.10, -109.98, 90.03, 0.00. Then left sidebar, tap Program and check the node is still green. EXPECT: Move screen opens with the program still running. BASIS: Lab 4 step text; that I may open Move while a program plays is a GUESS (Lab 2 checkpoint implied it).
83. [Task 4 step 4] ACTION: Compute the Difference row by hand: 0.00, 0.01, 0.00, 0.00, 0.00, 0.00. EXPECT: all under 0.1. BASIS: Lab 4 step text.
84. [Task 4, note under Table 4] ACTION: Look at the "Flange position (m)" line and the pendant TCP, see that they differ, and do not compare them. EXPECT: they differ by about the gripper length. BASIS: Lab 4 step text.

## Part 3, Task 5: Enter the Waypoints and Run

85. [Task 5 step 1] ACTION: In the MATLAB Editor scroll to the banner "TASK 5 - ENTER YOUR WAYPOINTS". Change the line
    before: `    ready_pos     = nan(1,6);   % TODO: your ready position (start and end)`
    after:  `    ready_pos     = [-15.02 -79.95 -80.10 -109.98 90.03 0.00];   % TODO: your ready position (start and end)`
    EXPECT: no red underline. BASIS: Lab 4 step text.
86. [Task 5 step 1] ACTION: Change
    before: `    pre_pick_pos  = nan(1,6);   % TODO: directly above the cube`
    after:  `    pre_pick_pos  = [-12.48 -107.92 -89.14 -72.97 90.03 2.54];   % TODO: directly above the cube`
    BASIS: Lab 4 step text.
87. [Task 5 step 1] ACTION: Change
    before: `    pick_pos      = nan(1,6);   % TODO: fingers around the cube`
    after:  `    pick_pos      = [-12.48 -118.36 -96.71 -54.96 90.03 2.54];   % TODO: fingers around the cube`
    BASIS: Lab 4 step text.
88. [Task 5 step 1] ACTION: Change
    before: `    retract_pos   = nan(1,6);   % TODO: straight back up from Pick (same as Pre-Pick)`
    after:  `    retract_pos   = [-12.48 -107.92 -89.14 -72.97 90.03 2.54];   % TODO: straight back up from Pick (same as Pre-Pick)`
    BASIS: Lab 4 step text.
89. [Task 5 step 1] ACTION: Change
    before: `    pre_place_pos = nan(1,6);   % TODO: above the place location`
    after:  `    pre_place_pos = [-52.80 -110.26 -85.63 -74.14 90.03 -37.78];   % TODO: above the place location`
    BASIS: Lab 4 step text.
90. [Task 5 step 1] ACTION: Change
    before: `    place_pos     = nan(1,6);   % TODO: down at the place location`
    after:  `    place_pos     = [-52.80 -121.05 -92.44 -56.54 90.03 -37.78];   % TODO: down at the place location`
    Then press Ctrl+S. EXPECT: the asterisk next to the file name in the Editor tab disappears. BASIS: Lab 4 step text.
91. [Task 5 step 2] ACTION: Look at the line `moveEndTime       = 5;` and leave it alone. EXPECT: nothing. BASIS: Lab 4 step text.
92. [Task 5 step 3] ACTION: Carry the cube from the place mark back to the pick mark, same orientation. On the pendant, Program screen, check the Script Code node is still green. EXPECT: green. BASIS: Lab 4 step text.
93. [Task 5 step 4] ACTION: Drag the speed slider from 50% to 25%. Tell my partners not to touch it. EXPECT: 25%, node still green. BASIS: Lab 4 step text.
94. [Task 5 step 5] ACTION: In the Command Window type `UR_PickPlace_Lab`, press Enter. EXPECT: the connection readout again, then a waypoint check with eight lines each ending PASS or FAIL, then the WARNING text and the prompt `Type "yes" to run the sequence:`. Robot still. BASIS: Lab 4 step text.
95. [Task 5 step 5] ACTION: Read the eight check lines one by one. All eight say PASS, so I correct nothing. EXPECT: eight PASS. BASIS: Lab 4 step text.
96. [Task 5 step 6] ACTION: Compare the printed "Joint angles (deg)" line with the pendant: right sidebar Move, read the six angles, then go back to Program. They match (-15.02, -79.95/-79.96, -80.10, -109.98, 90.03, 0.00). EXPECT: match within 0.1. BASIS: Lab 4 step text.
97. [Task 5 step 6] ACTION: Say "robot moving", left hand at the e-stop, with the right hand type `yes` at the prompt and press Enter. EXPECT: "Starting pick-and-place sequence..." then "[ 1/11] Moving to Ready..." (the robot is already at Ready so nothing visible happens), "[ 2/11] Opening gripper...", and so on to "[11/11] Returning to Ready...". Each move takes about 20 s. BASIS: Lab 4 step text.
98. [Task 5 step 6] ACTION: Wait about 3 minutes, watching every move and not touching the pendant or the slider. EXPECT: cube picked, carried, set on the place mark; then "Sequence complete in ... s" (it printed 171.8 s) and the Final State box. BASIS: Lab 4 step text.
99. [Task 5 step 7] ACTION: None. I read the step so I know that stopping the pendant program is the way to stop a run early; I did not need it. EXPECT: n/a. BASIS: Lab 4 step text.
100. [Task 5 step 8] ACTION: Carry the cube from the place mark back to the pick mark. EXPECT: nothing. BASIS: GUESS (not stated for the second MATLAB run, same reasoning as action 71).
101. [Task 5 step 8] ACTION: Drag the speed slider to 50%. Check on the Program screen that the Script Code node is still green. EXPECT: 50%, green. BASIS: Lab 4 step text.
102. [Task 5 step 8] ACTION: In the Command Window type `UR_PickPlace_Lab`, press Enter. Read the eight check lines (all PASS), glance that the joint angles match the Move screen, then at the prompt type `yes` and press Enter, hand at the e-stop. EXPECT: the same eleven printed steps, each move about 10 s. BASIS: Lab 4 step text.
103. [Task 5 step 8] ACTION: Wait about 1.5 minutes, hands off the slider. EXPECT: "Sequence complete in ... s". It printed 88.6 s. BASIS: Lab 4 step text.
104. [Task 5 step 8] ACTION: Measure the cube against the place mark with a ruler: about 2 mm off. Write in Table 5, MATLAB RTDE column: cycle time 88.6 s, pick success Y, place accuracy good. EXPECT: nothing. BASIS: Lab 4 step text.

## Part 3, Task 6: Compare the Two Methods

105. [Task 6] ACTION: Check Table 5 rows 1 to 3 are filled for both columns: 26.4 s / 88.6 s, Y / Y, good / good. Add a margin note that the MATLAB time is mostly moveEndTime (8 moves x 5 s / 0.5). EXPECT: nothing. BASIS: Lab 4 step text.
106. [Task 6] ACTION: Discuss with my partners and write Ease of programming: Teach Pendant 3, MATLAB 2. Ease of modification: Teach Pendant 3, MATLAB 1. EXPECT: nothing. BASIS: Lab 4 step text (the ratings are our opinion).
107. [Task 6, end] ACTION: Leave the robot at Ready with the server script still playing and the slider at 50%, and raise my hand to ask the instructor whether to stop the program and power down. EXPECT: instructor tells us. BASIS: GUESS (Lab 4 has no shutdown step; Lab 2 Part 7 has one but Lab 4 does not refer to it).

## Table 3 as I filled it

| Waypoint | J1 | J2 | J3 | J4 | J5 | J6 | X (mm) | Y (mm) | Z (mm) |
|---|---|---|---|---|---|---|---|---|---|
| Ready | -15.02 | -79.95 | -80.10 | -109.98 | 90.03 | 0.00 | 118.35 | -279.10 | 212.47 |
| Pre-Pick | -12.48 | -107.92 | -89.14 | -72.97 | 90.03 | 2.54 | 142.61 | -301.24 | 87.52 |
| Pick | -12.48 | -118.36 | -96.71 | -54.96 | 90.03 | 2.54 | 142.60 | -301.25 | 7.40 |
| Retract | -12.48 | -107.92 | -89.14 | -72.97 | 90.03 | 2.54 | 142.61 | -301.24 | 87.52 |
| Pre-Place | -52.80 | -110.26 | -85.63 | -74.14 | 90.03 | -37.78 | -96.31 | -318.74 | 85.10 |
| Place | -52.80 | -121.05 | -92.44 | -56.54 | 90.03 | -37.78 | -96.30 | -318.75 | 7.42 |

## Where I guessed or hesitated

Guesses (action numbers in brackets):

1. [4] Which tape mark is pick and which is place: the manual never says, and never says whether it matters.
2. [9, 10] What to tap after tapping the program name to get a NEW program and type its name: Lab 2 and Lab 4 both stop at "tap the program name".
3. [16] Which base angle to use for Ready: "of your choosing" with only one example where joint 1 is 0.
4. [22] Where the node name is edited: "name it Ready" gives no field or icon.
5. [23] Where Edit Point is: I assumed it is in the panel of the selected node.
6. [25, 35] Where the Robotiq gripper screen is: "the screen that the URCap adds" with no menu path; no earlier lab opened it.
7. [26] That Activate takes a few seconds and moves the fingers: not described.
8. [30] Which buttons jog along X, Y, Z and which way + goes: Lab 3 only jogged joints. Also "reference" (Lab 4) vs "feature" (Lab 3) for the Base selector; I assumed they are the same thing.
9. [38] Where a new node lands when I tap +: I assumed below the selected node. If it always goes to the end, my node order and the number of Move up taps in Task 2 would be different.
10. [51] Where the Move up and Move down icons are.
11. [55] That typing joint angles in the Joints tab does not move the robot, and that no extra "apply" is needed before Save.
12. [57, 59] Whether two nodes may share the name Pre-Place or Ready.
13. [60, 61] The name of the Robotiq gripper node in the list and how to set it to open or close (and whether setting it moves the real gripper).
14. [65, 76] How to save a program: "Save the program" with no button named; Lab 2 never saved explicitly.
15. [68] Whether Play shows a "move to start position" confirmation when the robot is not at the first node (I started from Pre-Place), and what to do with it.
16. [71, 100] Putting the cube back on the pick mark before each repeat run: only stated for the first run of each method.
17. [73] Whether Task 3 steps 4 and 5 are one run at 50% or two.
18. [77] How to open an existing program (Open/Load and the list) and which one is "a Lab 2 program".
19. [82] Whether I can open the Move screen while the server program is playing without stopping it.
20. [107] What to do with the robot at the end: no stop, save or power-down instruction in Lab 4.

Hesitations that were not guesses:

- [18] Step 3 asks for X, Y, Z before step 6 tells me to set the reference to Base. I set Base early because of Lab 3; a classmate who did not would record Ready in a different frame.
- [21] Table 2 says "Joint Move" but the "Move To" fallback is only explained later, at the start of Part 2.
- [42] "Copy its values into the Retract row" made me unsure whether to also store a Retract node in Task 1. I did not; Task 2 step 2 then confirmed it.
- [44] "Jog down to the Z of Pick" at the place mark with no cube there: I could not check the height against anything but the number.
- [78] The slider was still at 50% from Task 3 when I pressed Play on the server script; the manual only sets 25% later in Task 5 step 4. I was not sure it mattered since nothing moves.
- [97] Step 1 of the MATLAB sequence is "Moving to Ready" but the robot was already there, so for a moment I thought it had hung.
- [94, 95] I did not know what the eight check lines would look like, only "PASS or FAIL".
