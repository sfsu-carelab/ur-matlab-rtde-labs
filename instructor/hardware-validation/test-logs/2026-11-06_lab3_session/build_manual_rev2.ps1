# Build "Lab 3 - Forward Kinematics.docx" Rev2 from Rev1 by editing document.xml directly.
# Run:  powershell -NoProfile -ExecutionPolicy Bypass -File build_rev2.ps1
$ErrorActionPreference = 'Stop'
$repo   = 'C:\Users\924414657\2026 Thesis\ur-matlab-rtde-labs'
$lab3   = Join-Path $repo 'labs\lab3-forward-kinematics'
$srcDoc = Join-Path $lab3 'Lab 3 - Forward Kinematics.docx'
$scr    = 'C:\Users\924414~1\AppData\Local\Temp\claude\b6d4761755c08687\a6c64996-18aa-463a-bbc6-09b441da97f1\scratchpad'
$work   = Join-Path $scr 'lab3docx\build'
$newFig = Join-Path $scr 'lab3fig\figure1_poe.png'
$outDoc = Join-Path $work 'Lab 3 - Forward Kinematics.docx'

if (Test-Path $work) { Remove-Item $work -Recurse -Force }
New-Item -ItemType Directory -Force $work | Out-Null
Copy-Item $srcDoc "$work\src.zip"
Expand-Archive "$work\src.zip" -DestinationPath "$work\x" -Force
$docPath = "$work\x\word\document.xml"
$utf8 = New-Object System.Text.UTF8Encoding $false
$xml = [IO.File]::ReadAllText($docPath, $utf8)
$log = @()

# ---------------------------------------------------------------- helpers
function Esc([string]$s) { return $s.Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;') }
function RunXml([string]$kind, [string]$text) {
    $t = Esc $text
    switch ($kind) {
        'n' { return "<w:r><w:rPr><w:rFonts w:cs=`"Calibri`"/></w:rPr><w:t xml:space=`"preserve`">$t</w:t></w:r>" }
        'b' { return "<w:r><w:rPr><w:rFonts w:cs=`"Calibri`"/><w:b/></w:rPr><w:t xml:space=`"preserve`">$t</w:t></w:r>" }
        'i' { return "<w:r><w:rPr><w:rFonts w:cs=`"Calibri`"/><w:i/></w:rPr><w:t xml:space=`"preserve`">$t</w:t></w:r>" }
        'c' { return "<w:r><w:rPr><w:rFonts w:ascii=`"Consolas`" w:hAnsi=`"Consolas`" w:cs=`"Consolas`"/><w:shd w:val=`"clear`" w:fill=`"F2F2F2`"/></w:rPr><w:t xml:space=`"preserve`">$t</w:t></w:r>" }
        'm' { return "<m:oMath><m:r><m:t>$t</m:t></m:r></m:oMath>" }
    }
}
# mini markup: `code`  **bold**  //italic//  $$math$$
function Mk([string]$s) {
    $out = ''
    $re = '(`[^`]+`|\*\*[^*]+\*\*|//[^/]+//|\$\$[^$]+\$\$)'
    $parts = [regex]::Split($s, $re)
    foreach ($p in $parts) {
        if ($p -eq '') { continue }
        if ($p.StartsWith('`'))       { $out += RunXml 'c' $p.Trim('`') }
        elseif ($p.StartsWith('**'))  { $out += RunXml 'b' $p.Substring(2, $p.Length-4) }
        elseif ($p.StartsWith('//'))  { $out += RunXml 'i' $p.Substring(2, $p.Length-4) }
        elseif ($p.StartsWith('$$'))  { $out += RunXml 'm' $p.Substring(2, $p.Length-4) }
        else                          { $out += RunXml 'n' $p }
    }
    return $out
}
function Para([string]$s, [string]$style = '') {
    $pPr = ''
    if ($style -eq 'center') { $pPr = '<w:pPr><w:jc w:val="center"/></w:pPr>' }
    elseif ($style) { $pPr = "<w:pPr><w:pStyle w:val=`"$style`"/></w:pPr>" }
    return "<w:p>$pPr$(Mk $s)</w:p>"
}
function CaptionPara([string]$s) {
    return "<w:p><w:pPr><w:jc w:val=`"center`"/></w:pPr><w:r><w:rPr><w:rFonts w:cs=`"Calibri`"/><w:i/><w:sz w:val=`"20`"/></w:rPr><w:t xml:space=`"preserve`">$(Esc $s)</w:t></w:r></w:p>"
}
function Plain([string]$paraXml) { return ($paraXml -replace '<[^>]+>', '') }
function Paras() { return @([regex]::Matches($script:xml, '<w:p[ >](?:(?!</w:p>).)*</w:p>') | ForEach-Object { $_.Value }) }
function FindPara([string]$like) {
    $hits = @(Paras | Where-Object { (Plain $_) -like $like })
    if ($hits.Count -eq 0) { throw "paragraph not found: $like" }
    if ($hits.Count -gt 1) { throw "paragraph pattern ambiguous ($($hits.Count)): $like" }
    $p = $hits[0]
    if ($script:xml.IndexOf($p) -ne $script:xml.LastIndexOf($p)) { throw "paragraph xml not unique: $like" }
    return $p
}
function ReplacePara([string]$like, [string]$newXml) {
    $old = FindPara $like
    $script:xml = $script:xml.Replace($old, $newXml)
    $script:log += "replaced: $like"
}
function InsertAfter([string]$like, [string]$newXml) {
    $old = FindPara $like
    $script:xml = $script:xml.Replace($old, $old + $newXml)
    $script:log += "inserted after: $like"
}
function InsertBefore([string]$like, [string]$newXml) {
    $old = FindPara $like
    $script:xml = $script:xml.Replace($old, $newXml + $old)
    $script:log += "inserted before: $like"
}

# ---------------------------------------------------------------- E1 conventions paragraph
ReplacePara 'The default home configuration for UR robots*' (Para ('The default home configuration for UR robots has the robot standing straight upright. Figure 1 is a side view drawn in the **base frame {s}** that this lab uses: the z axis points up along the joint 1 axis, the y axis points to the LEFT of the page (the side where the cable leaves the base), and the x axis points INTO the page (right-hand rule). The wrist hangs out on the −y side, so every y coordinate of the arm is zero or negative at home. The red arrow at each joint is the positive rotation direction $$ω_i$$ that this lab uses for that joint: four of them point along +y, joint 1 points along +z and joint 5 points along −z (downward). These directions are a convention, but the self-tests in Part 3 and the helper functions in Part 4 assume exactly these, so use them. Figure 2 shows the same robot as Universal Robots draws it; its arrows follow a different convention, see its caption.'))

# ---------------------------------------------------------------- E2 Figure 1 image swap + caption
Copy-Item "$work\x\word\media\image1.png" "$work\x\word\media\image2.png"      # keep the UR drawing as Figure 2
Copy-Item $newFig "$work\x\word\media\image1.png" -Force
Add-Type -AssemblyName System.Drawing
$img = [System.Drawing.Image]::FromFile($newFig); $asp = $img.Height / $img.Width; $img.Dispose()
$cx = [int](4.9 * 914400); $cy = [int]($cx * $asp)
if ($xml -notmatch '<wp:extent cx="2764918" cy="4591050"/>') { throw 'Figure 1 extent not found' }
$xml = $xml.Replace('<wp:extent cx="2764918" cy="4591050"/>', "<wp:extent cx=`"$cx`" cy=`"$cy`"/>")
$xml = $xml.Replace('<a:ext cx="2770620" cy="4600518"/>', "<a:ext cx=`"$cx`" cy=`"$cy`"/>")
$log += "figure 1: new image, extent $cx x $cy EMU"
ReplacePara 'Figure 1 - UR e-series schematic diagram with link lengths labeled*' (CaptionPara 'Figure 1 - UR e-series schematic at the home pose in the base frame used in this lab: joints numbered 1 to 6, link lengths L1 to L6 with their MATLAB names, and the positive rotation direction ω of every joint (red arrows). +y points left, +z up, +x into the page.')

# ---------------------------------------------------------------- E3 Figure 2 (the original UR drawing)
$cx2 = [int](2.4 * 914400); $cy2 = [int]($cx2 * 1428 / 860)
$fig2 = "<w:p><w:pPr><w:jc w:val=`"center`"/></w:pPr><w:r><w:rPr><w:noProof/></w:rPr><w:drawing><wp:inline distT=`"0`" distB=`"0`" distL=`"0`" distR=`"0`"><wp:extent cx=`"$cx2`" cy=`"$cy2`"/><wp:effectExtent l=`"0`" t=`"0`" r=`"0`" b=`"0`"/><wp:docPr id=`"2`" name=`"Picture 2`"/><wp:cNvGraphicFramePr><a:graphicFrameLocks xmlns:a=`"http://schemas.openxmlformats.org/drawingml/2006/main`" noChangeAspect=`"1`"/></wp:cNvGraphicFramePr><a:graphic xmlns:a=`"http://schemas.openxmlformats.org/drawingml/2006/main`"><a:graphicData uri=`"http://schemas.openxmlformats.org/drawingml/2006/picture`"><pic:pic xmlns:pic=`"http://schemas.openxmlformats.org/drawingml/2006/picture`"><pic:nvPicPr><pic:cNvPr id=`"0`" name=`"image2.png`"/><pic:cNvPicPr/></pic:nvPicPr><pic:blipFill><a:blip r:embed=`"rId9`"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill><pic:spPr><a:xfrm><a:off x=`"0`" y=`"0`"/><a:ext cx=`"$cx2`" cy=`"$cy2`"/></a:xfrm><a:prstGeom prst=`"rect`"><a:avLst/></a:prstGeom></pic:spPr></pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r></w:p>"
$cap2 = CaptionPara 'Figure 2 - The same robot as drawn by Universal Robots for its DH parameter table (red = x, green = y, blue = z of each DH frame; a circled dot points out of the page, a circled cross into it). The blue arrows are the DH joint axes, which is also the sense the teach pendant counts in. On joints 2 to 6 they point OPPOSITE to the ω arrows of Figure 1. Use this figure to see the real link shapes and offsets; do not read ω from it.'
InsertAfter 'Figure 1 - UR e-series schematic at the home pose*' ($fig2 + $cap2)
$relsPath = "$work\x\word\_rels\document.xml.rels"
$rels = [IO.File]::ReadAllText($relsPath, $utf8)
if ($rels -match 'rId9') { throw 'rId9 already used' }
$rels = $rels.Replace('</Relationships>', '<Relationship Id="rId9" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/image2.png"/></Relationships>')
[IO.File]::WriteAllText($relsPath, $rels, $utf8)
$log += 'figure 2 added (rId9, media/image2.png)'

# ---------------------------------------------------------------- E4 cross product formula, joint guidance, joint 5 example
InsertBefore 'Now derive the remaining five screw axes*' (Para ('**General cross product formula.** For any two vectors $$a=(a₁,a₂,a₃)$$ and $$b=(b₁,b₂,b₃)$$: $$a×b=(a₂b₃−a₃b₂, a₃b₁−a₁b₃, a₁b₂−a₂b₁)$$. The worked example above is this formula with a = ω and b = q. You will need it with ω along +y (joints 2, 3, 4, 6), along +z (joint 1) and along −z (joint 5).'))
ReplacePara 'Now derive the remaining five screw axes*' (Para ('Now derive the remaining five screw axes the same way and record them in Table 2. Joints 3, 4 and 6 are directly analogous to joint 2: $$ω=(0,1,0)$$ and q on the base axis at the height of that joint. Read the heights from Figure 1: joint 3 is L1+L2 up, joint 4 is L1+L2+L3 up, and joint 6 is a further L5 above joint 4. Joint 1 is simpler still: its axis passes through the origin, so q = (0, 0, 0) and v = (0, 0, 0). Joint 5 is the one that catches people, so its first two steps are given here.'))
InsertAfter 'Now derive the remaining five screw axes*' ((Para ('**Joint 5 (wrist 2), Steps 1 and 2.** Its axis is vertical and, in this lab, its positive direction is taken DOWNWARD: $$ω₅=(0,0,−1)$$ (red arrow in Figure 1). The axis is offset from the base axis by L4 in the −y direction, so a convenient point on it is $$q₅=(0,−L₄,L₁+L₂+L₃)$$; any height works because the axis is vertical. **Step 3 is yours:** apply the general formula to $$v₅=−ω₅×q₅$$. Physical check: with ω₅ pointing down, a point of the wrist at the base origin would move along +x, so v₅ should point along +x. Notice that flipping the sign of ω also flips v. If you pick ω₅ = (0, 0, +1) instead, the self-test for wrist 2 in Part 3 will show the x coordinate with the right size and the wrong sign.')))

# ---------------------------------------------------------------- E5 rows -> columns
ReplacePara 'In Table 4, the rows R_x, R_y and R_z*' (Para ('Table 4 has one row per tool axis, but when you type M each of these vectors is a COLUMN: R = [x_tool, y_tool, z_tool], so R_x = x_tool goes down the first column of M, R_y = y_tool down the second and R_z = z_tool down the third, each written in base coordinates. (For this robot the correct R happens to be symmetric, so a transposed entry would still pass the self-tests. Get the convention right anyway; it matters for every other robot.)'))

# ---------------------------------------------------------------- E6 how to run the MATLAB file
$howto = (Para '**Running the MATLAB file**') +
  (Para ('Put all seven .m files in one folder and make that folder MATLAB''s Current Folder (the address bar above the Command Window, or `cd(''...'')`). If MATLAB reports "Unrecognized function or variable", the Current Folder is wrong.') 'ListBullet') +
  (Para ('In UR_FK_Lab.m replace each NaN with an expression in d1, a2, a3, d4, d5, d6. These variables are defined a few lines above, so type them literally, for example `-(d1+a2)`. Each row of S_list is one joint, [omega(1:3) v(1:3)]. The `.''` after the matrix turns your rows into the columns fk_space expects; leave it alone.') 'ListBullet') +
  (Para ('Run it by typing `UR_FK_Lab` in the Command Window and pressing Enter (`UR_FK_Lab()` is the same thing, and the green Run button in the Editor also works). `UR_FK_Lab("UR5e")` checks your symbolic answer on another robot and is optional.') 'ListBullet') +
  (Para ('After a run, S_list and M stay in the base workspace (the Workspace panel beside the Command Window), so you can call `fk_space` with them directly, as Part 4 does. If you close MATLAB, run UR_FK_Lab again first.') 'ListBullet')
InsertAfter 'Open the accompanying file UR_FK_Lab.m*' $howto

# ---------------------------------------------------------------- E7 Part 3 paragraph
ReplacePara 'Run UR_FK_Lab(). It executes*' (Para ('Run `UR_FK_Lab`. It executes the test cases below and prints PASS or FAIL for each. For a correct answer every error is at machine precision (about 1e-16 m); the PASS threshold is 1e-10 m. Test 1 only checks that the chain reproduces the M you typed, it cannot tell whether M is right: tests 2 and 3 check the position part of M and test 5(d) its rotation. Test 5(e) is a sanity check that the tool is never further from the base than the arm is long. If a test shows FAIL it names the joint it moved: recheck both ω and v of that row of S_list. A result of the right size with the wrong sign means that ω points the wrong way.'))

# ---------------------------------------------------------------- E8 Part 4: TCP warning, Task 3
$tcpWarn = FindPara '*TCP setting: your FK model ends at the tool flange*'
$xml = $xml.Replace($tcpWarn, $tcpWarn.Replace('</w:p>', (RunXml 'n' ' On PolyScope X the active TCP is set in the Installation section (TCP); check that its position offset reads 0, 0, 0 before starting Task 4.') + '</w:p>'))
$log += 'TCP warning extended'
ReplacePara 'Turn on the robot arm and move it to the upright home position*' (Para ('Turn on the robot arm and move it to the upright home position (Move screen, Smart Skills, Home). On the Move screen''s joint panel, record the six joint angle readings. Expect roughly [0, −90, 0, −90, 0, 0] degrees; small deviations are normal, but a value that is off by 90 or 180 degrees means the arm is not at Home or you are reading a different panel.'))
ReplacePara 'Notice that the angles are not all zero.*' (Para ('Notice that the angles are not all zero. Our PoE formula assumes all joint angles are zero at the home configuration. There is a second difference: on joints 2 through 6 the pendant''s positive rotation direction is opposite to the screw axes you derived. To see it, jog joint 2 a few degrees in the pendant''s positive direction: the arm tips toward −x, whereas the right-hand rule about the red ω₂ = +y arrow of Figure 1 tips it toward +x. The conversion therefore needs a sign flip as well as an offset:'))

# ---------------------------------------------------------------- E9 Task 4 steps
ReplacePara 'Convert from screw angles to hardware angles*' (Para ('Convert the screw angles to pendant angles with the formula above or with the helper `theta_hw = screw2hw(theta_screw, theta_home)`, where theta_home is the six numbers you recorded in Task 3 (all angles in degrees). For Pose 2, `screw2hw([0 -45 45 0 0 0], [0 -90 0 -90 0 0])` returns [0, −45, −45, −90, 0, 0].') 'ListNumber')
ReplacePara 'Command the robot to the resultant hardware angles*' (Para ('Check that the pose is clear of walls, the table and the camera (Pose 2 leans the upper arm 45 degrees toward −x), then command the robot to the pendant angles: Move screen, joint panel, type the six values and let the move finish. Speed slider at 25 percent, e-stop in hand.') 'ListNumber')
ReplacePara 'In MATLAB, run fk_space() with the original screw angles*' (Para ('In MATLAB, with S_list and M in the workspace from Part 3, run the FK on the ORIGINAL screw angles, not the pendant angles: `T = fk_space(S_list, M, [0 -45 45 0 0 0])`. The position is the last column, `p_fk = T(1:3,4)`, in metres. For Pose 2 on a UR3e this is (−0.172, −0.223, 0.623) m.') 'ListNumber')
ReplacePara 'Record the FK output and the TCP position*' (Para ('Read the TCP position from the pendant (Move screen, TCP panel, with the feature set to Base) and convert millimetres to metres: `p_robot = [X Y Z] / 1000`. Record both positions in Table 6.') 'ListNumber')
ReplacePara 'Compute the position error between the two*' (Para ('Compute the error in millimetres: `err_mm = norm(p_fk - p_robot) * 1000`. Under 3 mm is excellent and a few millimetres is success (the robot''s own calibration differs slightly from the nominal link lengths). A large, roughly constant offset at every pose usually means a TCP mismatch, see the warning at the start of Part 4. The right size with the wrong sign in one coordinate means a sign error in one ω.') 'ListNumber')

# ---------------------------------------------------------------- E10 Q1, Q2 without the answers
ReplacePara 'Q1.*' (Para ('**Q1.  **Four of the six joints share the same rotation axis direction ω. Which four, and what does that tell you about the robot''s kinematic structure?'))
ReplacePara 'Q2.*' (Para ('**Q2.  **The axis of joint 5 is vertical at the home pose. If you wanted joint 5 to rotate about a horizontal axis instead, what physical change to the robot would that require?'))

# ---------------------------------------------------------------- E11 Table 6 header, E12 em dashes
$hdr = '<w:t>Robot TCP (m)</w:t>'
if ($xml.IndexOf($hdr) -lt 0) { throw 'Table 6 header not found' }
$xml = $xml.Replace($hdr, '<w:t>Robot TCP (m) = pendant mm / 1000</w:t>')
$log += 'Table 6 header'
$em = [string][char]0x2014
$nEm = ([regex]::Matches($xml, $em)).Count
$xml = $xml.Replace(" $em ", ' - ').Replace($em, ' - ')
$log += "em dashes replaced: $nEm"

# ---------------------------------------------------------------- write, validate, zip
[IO.File]::WriteAllText($docPath, $xml, $utf8)
$null = [xml]$xml            # well-formedness check
$log += 'document.xml parses as XML'

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
if (Test-Path $outDoc) { Remove-Item $outDoc -Force }
$fs = [IO.File]::Open($outDoc, 'Create')
$zip = New-Object IO.Compression.ZipArchive($fs, [IO.Compression.ZipArchiveMode]::Create)
$root = (Get-Item "$work\x").FullName          # long form; Get-ChildItem returns long paths
$files = @(Get-ChildItem $root -Recurse -File)
$ct = $files | Where-Object { $_.Name -eq '[Content_Types].xml' }
$ordered = @($ct) + @($files | Where-Object { $_.Name -ne '[Content_Types].xml' })
foreach ($f in $ordered) {
    $entry = $f.FullName.Substring($root.Length + 1).Replace('\', '/')
    $null = [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $f.FullName, $entry, [IO.Compression.CompressionLevel]::Optimal)
}
$zip.Dispose(); $fs.Dispose()
$check = [IO.Compression.ZipFile]::OpenRead($outDoc)
$names = $check.Entries | ForEach-Object { $_.FullName }
$check.Dispose()
if ($names | Where-Object { $_.StartsWith('/') }) { throw 'zip entry with leading slash' }
if ($names[0] -ne '[Content_Types].xml') { throw 'content types not first' }
$log += "zip ok: $($names.Count) entries, first = $($names[0])"
$log | ForEach-Object { "  $_" }
"OUTPUT: $outDoc  ($((Get-Item $outDoc).Length) bytes)"
