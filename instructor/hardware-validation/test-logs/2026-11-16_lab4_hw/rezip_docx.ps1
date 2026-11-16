param([string]$Dir, [string]$Out, [string]$Dest)
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$Dir = (Get-Item $Dir).FullName.TrimEnd('\')
if (Test-Path $Out) { Remove-Item $Out -Force }
$rel = Get-ChildItem $Dir -Recurse -File | ForEach-Object { $_.FullName.Substring($Dir.Length + 1).Replace('\', '/') }
$ordered = @('[Content_Types].xml') + @($rel | Where-Object { $_ -ne '[Content_Types].xml' })
$zip = [IO.Compression.ZipFile]::Open($Out, 'Create')
foreach ($f in $ordered) {
    [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, (Join-Path $Dir $f), $f, 'Optimal') | Out-Null
}
$zip.Dispose()
Copy-Item $Out $Dest -Force
$z = [IO.Compression.ZipFile]::OpenRead($Dest)
Write-Output ("entries: " + $z.Entries.Count)
$z.Entries | ForEach-Object { $_.FullName }
$e = $z.GetEntry('word/document.xml')
$r = New-Object IO.StreamReader($e.Open()); $t = $r.ReadToEnd(); $r.Close(); $z.Dispose()
[xml]$doc = $t
Write-Output ("xml parses: " + ($null -ne $doc))
Write-Output ("new sentence present: " + $t.Contains('Then open the 3D tab in the left sidebar, tap Move Here'))
Write-Output ("em dashes: " + ([regex]::Matches($t, [char]0x2014)).Count)
Get-Item $Dest | Select-Object Length
