$f = "C:\Users\924414~1\AppData\Local\Temp\claude\3c7be82c138dcb77\b9836b57-491b-469f-9f1d-dc136f71aab1\scratchpad\lab4docx\word\document.xml"
$xml = Get-Content $f -Raw -Encoding UTF8
$M = [string][char]0x2212   # Unicode minus, as the manual uses it
$pairs = @(
  @('The start and end pose (Figure 1). Joints 2 to 6 must read ~80, ~80, ~110, 90 and 0 degrees. Joint 1 is chosen by you.',
    'The start and end pose (Figure 1). Any pose with joint 5 = 90, joint 6 = 0 and joints 2 + 3 + 4 = ~270 degrees, which makes the tool flange face straight down. Choose joints 1 to 3 so that the arm clears the walls near your robot and the gripper is at least 15 cm above the table.'),
  @(' The Ready position (side view): shoulder and elbow bent, tool flange facing down. Joints 2 to 6 read ~80, ~80, ~110, 90 and 0 degrees. Joint 1 (base) is your choice.',
    ' An example Ready position (side view): shoulder and elbow bent, tool flange facing down, at joint angles 0, ~80, ~80, ~110, 90 and 0 degrees. Your own Ready position must satisfy joint 5 = 90, joint 6 = 0 and joints 2 + 3 + 4 = ~270; joints 1 to 3 are your choice.'),
  @('On the Move screen, set Relative To to base and check that Active TCP is your robot gripper TCP. Open the Joints tab and set joints 2 to 6 to exactly ~80, ~80, ~110, 90 and 0 degrees, the Ready position of Figure 1. For each joint, tap its value field, type the target and tap Confirm. Then open the 3D tab in the left sidebar, tap Move Here and hold Move to Position until the robot stops. The plus-minus buttons work as well. These five angles are required: they make the tool flange face straight down, which every later step relies on and ',
    'On the Move screen, set Relative To to base and check that Active TCP is your robot gripper TCP. Open the Joints tab and set the six joints to your Ready position. The rule is joint 5 = 90, joint 6 = 0, and joints 2, 3 and 4 adding up to ~270 degrees (for example ~80, ~80 and ~110, as in Figure 1). It makes the tool flange face straight down, which every later step relies on and '),
  @(' verifies. Joint 1 (base) is the only free choice: turn it until the gripper is over the area between the two tape marks.',
    ' verifies. Choose joint 1 and the split between joints 2, 3 and 4 so that the arm stays clear of the walls near your robot and the gripper is over the area between the two tape marks, at least 15 cm above the table. For each joint, tap its value field, type the target and tap Confirm. Then open the 3D tab in the left sidebar, tap Move Here and hold Move to Position until the robot stops. The plus-minus buttons work as well.')
)
foreach ($p in $pairs) {
  $old = $p[0].Replace('~', $M); $new = $p[1].Replace('~', $M)
  $n = ([regex]::Matches($xml, [regex]::Escape($old))).Count
  Write-Output ("occurrences: $n  <- " + $p[0].Substring(0, 40))
  if ($n -ne 1) { throw "expected exactly one occurrence" }
  $xml = $xml.Replace($old, $new)
}
[IO.File]::WriteAllText($f, $xml, (New-Object System.Text.UTF8Encoding($false)))
Write-Output "patched"
