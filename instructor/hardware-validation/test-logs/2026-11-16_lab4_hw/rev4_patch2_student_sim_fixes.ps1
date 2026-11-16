$f = "C:\Users\924414~1\AppData\Local\Temp\claude\3c7be82c138dcb77\b9836b57-491b-469f-9f1d-dc136f71aab1\scratchpad\lab4docx\word\document.xml"
$xml = Get-Content $f -Raw -Encoding UTF8
$pairs = @(
  # 1 safety: never reach in
  @('If the gripper still holds the cube, the script releases it at Ready: catch it and put it back on the pick mark.',
    'If the gripper still holds the cube, open the gripper from the Robotiq screen on the Teach Pendant (Application, URCaps, Robotiq) while the robot is stopped, take the cube out and put it back on the pick mark. Never reach in while the script is running.'),
  # 2 Task 4 step 2: confirm the loaded program before Play
  @(' (any group''s copy works), tap Open, and press Play. The node must turn Green.',
    ' (any group''s copy works) and tap Open. Check that the program name at the top of the screen is now the server program and not your own Lab 4 program, because Play on your program would run the pick-and-place. Then press Play. The node must turn Green.'),
  # 3 Table 4 prediction
  @('Because the tool points straight down at Ready, X and Y should agree to within about 2 mm, and the MATLAB Z should be higher by the Z offset of the gripper TCP that you set in Lab 1 (the length of the gripper).',
    'Because the tool points straight down at Ready, the MATLAB Z should be higher by the Z offset of the gripper TCP that you set in Lab 1 (about 174 mm, the length of the gripper), and X and Y should agree to within about 15 mm. They would agree exactly with the tool perfectly vertical; each degree of tilt moves the TCP about 3 mm sideways from the flange.'),
  # 4 tape marks spacing
  @('You have one cube and two tape marks on the table, the pick location and the place location, both within easy reach of the robot.',
    'You have one cube and two tape marks on the table, the pick location and the place location, at least 10 cm apart and both within easy reach of the robot.'),
  # 5 Retract not stored
  @('Straight back up from Pick with the cube. This is the same pose as Pre-Pick, so it takes the same values.',
    'Straight back up from Pick with the cube. This is the same pose as Pre-Pick, so it takes the same values and is not stored in Task 1; its node is added in Task 2 from the stored Pre_Pick.'),
  # 6 timing at 25 percent
  @('(about 12 seconds per move, under 2 minutes in total)',
    '(about 12 seconds per move, a little over 2 minutes in total)'),
  # 7 e-stop recovery
  @('Clear the stop on the Teach Pendant, press Play so that the node is ',
    'Clear the stop on the Teach Pendant (after an e-stop: release the button, then Power On and Unlock as in Lab 1), press Play so that the node is '),
  # 8 Robotiq screen location
  @('Open the Robotiq gripper screen that the URCap adds to the Teach Pendant, activate the gripper',
    'Open the Robotiq gripper screen: tap Application in the left sidebar, scroll down to URCaps and tap Robotiq. Activate the gripper')
)
foreach ($p in $pairs) {
  $n = ([regex]::Matches($xml, [regex]::Escape($p[0]))).Count
  Write-Output ("occurrences: $n  <- " + $p[0].Substring(0, [Math]::Min(50, $p[0].Length)))
  if ($n -ne 1) { throw "expected exactly one occurrence" }
  $xml = $xml.Replace($p[0], $p[1])
}
[IO.File]::WriteAllText($f, $xml, (New-Object System.Text.UTF8Encoding($false)))
Write-Output "patched"
