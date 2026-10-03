param(
    [ValidateSet(400, 450)]
    [int]$RegularWeight = 450,
    [string]$OutputPath = ''
)

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
$Variant = if ($RegularWeight -eq 400) { 'Regular-400' } else { 'Slightly-Bolder-450' }
if (-not $OutputPath) { $OutputPath = "outputs\Nunito_Sans_v1.2.0_$Variant.zip" }
if ([System.IO.Path]::IsPathRooted($OutputPath)) {
    $ZipPath = [System.IO.Path]::GetFullPath($OutputPath)
} else {
    $ZipPath = [System.IO.Path]::GetFullPath((Join-Path $Root $OutputPath))
}

$PackageFiles = @(
    'module.prop',
    'customize.sh',
    'post-fs-data.sh',
    'late-load.sh',
    'nunito.conf',
    'tools/root-manager.sh',
    'tools/prepare-fonts.sh',
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
        $entry.LastWriteTime = [DateTimeOffset]::new(2026, 10, 3, 0, 0, 0, [TimeSpan]::Zero)
        $unixMode = if ($relative -like '*.sh') { [Convert]::ToInt32('81ED', 16) } else { [Convert]::ToInt32('81A4', 16) }
        $entry.ExternalAttributes = [int]($unixMode -shl 16)

        $targetStream = $entry.Open()
        try {
            if ($relative -match '\.(sh|awk|prop|conf)$') {
                $content = [System.IO.File]::ReadAllText((Join-Path $Root $relative)).Replace("`r`n", "`n")
                if ($relative -eq 'nunito.conf') {
                    $content = $content -replace '(?m)^regular_weight=\d+$', "regular_weight=$RegularWeight"
                }
                if ($relative -eq 'module.prop') {
                    $content = $content -replace '(?m)^name=.*$', "name=Nunito Sans (Android 16, $RegularWeight)"
                    $content = $content -replace '(?m)^version=.*$', "version=1.2.0 ($Variant)"
                }
                $payload = [System.Text.UTF8Encoding]::new($false).GetBytes($content)
                $targetStream.Write($payload, 0, $payload.Length)
            } else {
                $sourceStream = [System.IO.File]::OpenRead((Join-Path $Root $relative))
                try { $sourceStream.CopyTo($targetStream) } finally { $sourceStream.Dispose() }
            }
        } finally {
            $targetStream.Dispose()
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
    foreach ($scriptName in ($PackageFiles | Where-Object { $_ -like '*.sh' })) {
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
