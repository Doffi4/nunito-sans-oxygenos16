param(
    [string]$OutputPath = "outputs\Nunito_Sans_KSU.zip"
)

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
if ([System.IO.Path]::IsPathRooted($OutputPath)) {
    $ZipPath = [System.IO.Path]::GetFullPath($OutputPath)
} else {
    $ZipPath = [System.IO.Path]::GetFullPath((Join-Path $Root $OutputPath))
}

$PackageFiles = @(
    'module.prop',
    'customize.sh',
    'post-fs-data.sh',
    'tools/patch-sans-family.awk',
    'system/fonts/Nunito-VF.ttf',
    'system/fonts/Nunito-Italic-VF.ttf',
    'LICENSES/OFL.txt'
)
foreach ($relative in $PackageFiles) {
    $source = Join-Path $Root $relative
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "Required package file is missing: $relative"
    }
}

$zipDirectory = Split-Path -Parent $ZipPath
[System.IO.Directory]::CreateDirectory($zipDirectory) | Out-Null
if (Test-Path -LiteralPath $ZipPath) {
    Remove-Item -LiteralPath $ZipPath -Force
}

Add-Type -AssemblyName System.IO.Compression
$archive = [System.IO.Compression.ZipArchive]::new(
    [System.IO.File]::Open($ZipPath, [System.IO.FileMode]::CreateNew),
    [System.IO.Compression.ZipArchiveMode]::Create,
    $false
)
try {
    foreach ($relative in $PackageFiles) {
        $entryName = $relative.Replace('\', '/')
        $entry = $archive.CreateEntry($entryName, [System.IO.Compression.CompressionLevel]::Optimal)
        $unixMode = if ($relative -like '*.sh') { [Convert]::ToInt32('81ED', 16) } else { [Convert]::ToInt32('81A4', 16) }
        $entry.ExternalAttributes = [int]($unixMode -shl 16)

        $sourceStream = [System.IO.File]::OpenRead((Join-Path $Root $relative))
        $targetStream = $entry.Open()
        try {
            $sourceStream.CopyTo($targetStream)
        } finally {
            $targetStream.Dispose()
            $sourceStream.Dispose()
        }
    }
} finally {
    $archive.Dispose()
}

# .NET marks ZIP entries as created on Windows. Android's unzip tools use the
# "version made by" platform byte before honoring Unix execute bits, so stamp
# the central-directory entries as Unix and write explicit 0644/0755 modes.
$bytes = [System.IO.File]::ReadAllBytes($ZipPath)
$wantedModes = @{}
foreach ($relative in $PackageFiles) {
    $name = $relative.Replace('\\', '/')
    $wantedModes[$name] = if ($relative -like '*.sh') { 0x81ED } else { 0x81A4 }
}
$patchedEntries = @{}
$index = 0
while ($index -le $bytes.Length - 46) {
    if ([System.BitConverter]::ToUInt32($bytes, $index) -ne 0x02014B50) {
        $index++
        continue
    }

    $nameLength = [System.BitConverter]::ToUInt16($bytes, $index + 28)
    $extraLength = [System.BitConverter]::ToUInt16($bytes, $index + 30)
    $commentLength = [System.BitConverter]::ToUInt16($bytes, $index + 32)
    $recordLength = 46 + $nameLength + $extraLength + $commentLength
    if ($index + $recordLength -gt $bytes.Length) {
        throw 'Malformed ZIP central-directory entry.'
    }

    $name = [System.Text.Encoding]::UTF8.GetString($bytes, $index + 46, $nameLength)
    if ($wantedModes.ContainsKey($name)) {
        [System.BitConverter]::GetBytes([uint16]0x0314).CopyTo($bytes, $index + 4)
        $externalAttributes = [uint32](([uint64]$wantedModes[$name]) -shl 16)
        [System.BitConverter]::GetBytes($externalAttributes).CopyTo($bytes, $index + 38)
        $patchedEntries[$name] = $true
    }
    $index += $recordLength
}
if ($patchedEntries.Count -ne $wantedModes.Count) {
    throw 'Could not set Unix permissions on every ZIP entry.'
}
[System.IO.File]::WriteAllBytes($ZipPath, $bytes)

$check = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
try {
    $actualNames = @($check.Entries | ForEach-Object { $_.FullName } | Sort-Object)
    $expectedNames = @($PackageFiles | ForEach-Object { $_.Replace('\', '/') } | Sort-Object)
    if (Compare-Object -ReferenceObject $expectedNames -DifferenceObject $actualNames) {
        throw 'ZIP entries do not match the module allowlist.'
    }
    foreach ($scriptName in @('customize.sh', 'post-fs-data.sh')) {
        $entry = $check.GetEntry($scriptName)
        $mode = ($entry.ExternalAttributes -shr 16) -band 0xFFFF
        if ($mode -ne [Convert]::ToInt32('81ED', 16)) {
            throw "Executable permission is missing from $scriptName (mode $mode)."
        }
    }
} finally {
    $check.Dispose()
}

$info = Get-Item -LiteralPath $ZipPath
Write-Output "Created $($info.FullName) ($($info.Length) bytes)"
