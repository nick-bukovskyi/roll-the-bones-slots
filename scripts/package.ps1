# Build and inspect a local development ZIP without installing or uploading
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$addonName = 'RollTheBonesSlots'
$tocLines = Get-Content -LiteralPath (Join-Path $projectRoot "$addonName.toc")
$interfaceLines = @($tocLines | Where-Object { $_ -match '^\s*##\s*Interface\b' })
if ($interfaceLines.Count -ne 1) { throw 'Expected exactly one TOC Interface declaration' }
if ($interfaceLines[0] -notmatch '^## Interface: [1-9][0-9]*$') {
    throw 'TOC Interface must declare one positive decimal interface number'
}
$versionLines = @($tocLines | Where-Object { $_ -match '^## Version: (.+)$' })
if ($versionLines.Count -ne 1) { throw 'Expected one TOC version' }
$version = $versionLines[0].Substring('## Version: '.Length)
if ($version -notmatch '^[A-Za-z0-9.-]+$') { throw 'Unsafe package version' }
$iconLines = @($tocLines | Where-Object { $_ -match '^## IconTexture: (.+)$' })
if ($iconLines.Count -ne 1) { throw 'Expected one TOC IconTexture declaration' }
$icon = $iconLines[0].Substring('## IconTexture: '.Length).Replace('\', '/')
$iconPrefix = "Interface/AddOns/$addonName/"
if (-not $icon.StartsWith($iconPrefix, [StringComparison]::Ordinal) -or -not $icon.EndsWith('.tga')) {
    throw 'IconTexture must refer to a TGA inside this addon'
}
$runtimePaths = @($tocLines | Where-Object {
    $_.Trim() -and -not $_.TrimStart().StartsWith('#')
} | ForEach-Object { $_.Trim().Replace('\', '/') })
# Textures are loaded by Lua, not listed as executable files in the TOC
$runtimeMediaPaths = @('public/art/cabinet.tga', 'public/art/cabinet-compact.tga', 'public/art/symbols.tga', 'public/art/duration-fill.tga',
    $icon.Substring($iconPrefix.Length))
$packagePaths = @("$addonName.toc", 'LICENSE', 'docs/CHANGELOG.md') + $runtimePaths + $runtimeMediaPaths
if (@($packagePaths | Select-Object -Unique).Count -ne $packagePaths.Count) { throw 'Duplicate package path' }

# Resolve every path segment with exact casing; never traverse outside this project
$sources = @{}
foreach ($path in $packagePaths) {
    if ([IO.Path]::IsPathRooted($path) -or $path -match '(^|/)\.\.?(/|$)|//') { throw "Invalid path: $path" }
    $currentPath = $projectRoot
    foreach ($segment in $path.Split('/')) {
        $entries = @(Get-ChildItem -LiteralPath $currentPath -Force | Where-Object { $_.Name -ceq $segment })
        if ($entries.Count -ne 1) { throw "Missing file or incorrect casing: $path" }
        $currentPath = $entries[0].FullName
    }
    if (-not (Test-Path -LiteralPath $currentPath -PathType Leaf)) { throw "Not a file: $path" }
    $sources[$path] = $currentPath
}

# Reject missing pixels or unsupported exports before creating or replacing a ZIP
foreach ($path in $runtimeMediaPaths) {
    $stream = [IO.File]::OpenRead($sources[$path])
    $reader = [IO.BinaryReader]::new($stream)
    try {
        $header = $reader.ReadBytes(18)
        if ($header.Length -ne 18 -or $header[1] -ne 0 -or $header[2] -ne 2 -or $header[16] -ne 32) {
            throw "Expected an uncompressed 32-bit true-color TGA: $path"
        }
        $width = [int]$header[12] + 256 * [int]$header[13]
        $height = [int]$header[14] + 256 * [int]$header[15]
        foreach ($dimension in @($width, $height)) {
            if ($dimension -lt 1 -or $dimension -gt 4096 -or ($dimension -band ($dimension - 1)) -ne 0) {
                throw "TGA dimensions must be powers of two between 1 and 4096: $path"
            }
        }
        if ($stream.Length -lt (18 + [int]$header[0] + $width * $height * 4)) {
            throw "Truncated TGA pixel data: $path"
        }
    } finally { $reader.Dispose() }
}

# Header checks cannot detect stale or changed pixels in an otherwise valid TGA
& (Join-Path $PSScriptRoot 'export-art.ps1') -Check

$outputDirectory = Join-Path $projectRoot 'dist'
$null = New-Item -ItemType Directory -Path $outputDirectory -Force
$archivePath = Join-Path $outputDirectory "$addonName-$version.zip"
$pendingPath = Join-Path $outputDirectory ("$addonName-" + [guid]::NewGuid().ToString('N') + '.tmp')
Add-Type -AssemblyName System.IO.Compression.FileSystem
try {
    $archive = [IO.Compression.ZipFile]::Open($pendingPath, [IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($path in $packagePaths) {
            $null = [IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $archive, $sources[$path], "$addonName/$path", [IO.Compression.CompressionLevel]::Optimal)
        }
    } finally { $archive.Dispose() }

    $archive = [IO.Compression.ZipFile]::OpenRead($pendingPath)
    try {
        if ($archive.Entries.Count -ne $packagePaths.Count) { throw 'Unexpected archive contents' }
        foreach ($path in $packagePaths) {
            $entry = @($archive.Entries | Where-Object { $_.FullName -ceq "$addonName/$path" })
            if ($entry.Count -ne 1) { throw "Missing archive entry: $path" }
            $stream = $entry[0].Open()
            $hasher = [Security.Cryptography.SHA256]::Create()
            try {
                $archiveHash = [BitConverter]::ToString($hasher.ComputeHash($stream)).Replace('-', '')
            } finally { $hasher.Dispose(); $stream.Dispose() }
            if ($archiveHash -ne (Get-FileHash -LiteralPath $sources[$path] -Algorithm SHA256).Hash) {
                throw "Archive content mismatch: $path"
            }
        }
    } finally { $archive.Dispose() }

    # Replace only this project's generated ZIP after content verification succeeds
    Move-Item -LiteralPath $pendingPath -Destination $archivePath -Force
} finally {
    if (Test-Path -LiteralPath $pendingPath) {
        Remove-Item -LiteralPath $pendingPath
    }
}
Write-Output "Built $archivePath"
Write-Output "Verified $($packagePaths.Count) files; no upload or installation"
Get-FileHash -LiteralPath $archivePath -Algorithm SHA256
