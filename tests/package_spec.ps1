# Exercise the real local packager using disposable, synthetic TOC fixtures
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$temporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$fixtureRoot = Join-Path $temporaryRoot ('RollTheBonesSlots-package-test-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $fixtureRoot
$fixtureScriptDirectory = Join-Path $fixtureRoot 'scripts'
$fixtureSourceDirectory = Join-Path $fixtureRoot 'src'
$fixtureTestsDirectory = Join-Path $fixtureRoot 'tests'
$fixtureDocsDirectory = Join-Path $fixtureRoot 'docs'
$fixturePublicDirectory = Join-Path $fixtureRoot 'public'
$fixtureArtDirectory = Join-Path $fixturePublicDirectory 'art'
$fixtureScreenshotsDirectory = Join-Path $fixturePublicDirectory 'screenshots'
$null = New-Item -ItemType Directory -Path $fixtureScriptDirectory, `
    $fixtureSourceDirectory, $fixtureTestsDirectory, $fixtureDocsDirectory, `
    $fixturePublicDirectory, $fixtureArtDirectory, $fixtureScreenshotsDirectory
$fixtureScript = Join-Path $fixtureScriptDirectory 'package.ps1'
Copy-Item -LiteralPath (Join-Path $projectRoot 'scripts/package.ps1') -Destination $fixtureScript
# The real export algorithm is covered by art_export_spec; exercise its package boundary here
Set-Content -LiteralPath (Join-Path $fixtureScriptDirectory 'export-art.ps1') -Value @'
param([switch]$Check)
if (-not $Check) { throw 'Packaging must check textures without exporting them' }
$failurePath = Join-Path (Split-Path -Parent $PSScriptRoot) 'public/art/export-error.txt'
if (Test-Path -LiteralPath $failurePath) { throw 'Stale texture export' }
'@
$fixtureToc = Join-Path $fixtureRoot 'RollTheBonesSlots.toc'
$fixtureIconMetadata = '## IconTexture: Interface\AddOns\RollTheBonesSlots\public\logo.tga'
$fixtureDist = Join-Path $fixtureRoot 'dist'
$checks = 0

function Assert-PackageRejected {
    param([string]$Name, [string]$ExpectedError)
    $failure = $null
    try { & $fixtureScript | Out-Null } catch { $failure = $_ }
    if (-not $failure -or $failure.Exception.Message -notmatch $ExpectedError) {
        throw "Expected $ExpectedError for $Name; got $failure"
    }
    if ((Get-FileHash -LiteralPath $existingArchive -Algorithm SHA256).Hash -ne $previousHash `
        -or @(Get-ChildItem -LiteralPath $fixtureDist -Force).Count -ne 1) {
        throw "$Name modified existing package output"
    }
}

try {
    # Invalid metadata must fail before the packager needs any runtime files
    $invalidDeclarations = @(
        @{ Name = 'missing'; Lines = @() },
        @{ Name = 'duplicate'; Lines = @('## Interface: 123456', '## Interface: 123456') },
        @{ Name = 'duplicate with whitespace'; Lines = @('## Interface: 123456', '  ## Interface: 654321') },
        @{ Name = 'empty'; Lines = @('## Interface:') },
        @{ Name = 'missing colon'; Lines = @('## Interface 123456') },
        @{ Name = 'nonnumeric'; Lines = @('## Interface: unknown') },
        @{ Name = 'multiple interfaces'; Lines = @('## Interface: 123456, 654321') },
        @{ Name = 'zero'; Lines = @('## Interface: 0') },
        @{ Name = 'negative'; Lines = @('## Interface: -123456') },
        @{ Name = 'fraction'; Lines = @('## Interface: 123456.5') }
    )
    foreach ($case in $invalidDeclarations) {
        Set-Content -LiteralPath $fixtureToc -Value (@('## Version: fixture') + $case.Lines)
        $failure = $null
        try { & $fixtureScript | Out-Null } catch { $failure = $_ }
        if (-not $failure -or $failure.Exception.Message -notmatch 'TOC Interface') {
            throw "Expected an Interface validation error for $($case.Name)"
        }
        if (Test-Path -LiteralPath $fixtureDist) {
            throw "Invalid $($case.Name) declaration created dist"
        }
        $checks++
    }

    # An invalid rebuild must also leave an existing generated archive untouched
    $null = New-Item -ItemType Directory -Path $fixtureDist
    $existingArchive = Join-Path $fixtureDist 'RollTheBonesSlots-fixture.zip'
    Set-Content -LiteralPath $existingArchive -Value 'previous package'
    $previousHash = (Get-FileHash -LiteralPath $existingArchive -Algorithm SHA256).Hash
    Set-Content -LiteralPath $fixtureToc -Value '## Version: fixture'
    $failure = $null
    try { & $fixtureScript | Out-Null } catch { $failure = $_ }
    if (-not $failure -or $failure.Exception.Message -notmatch 'TOC Interface') {
        throw 'Expected an Interface validation error before rebuilding'
    }
    if ((Get-FileHash -LiteralPath $existingArchive -Algorithm SHA256).Hash -ne $previousHash `
        -or @(Get-ChildItem -LiteralPath $fixtureDist -Force).Count -ne 1) {
        throw 'Invalid metadata modified existing package output'
    }
    $checks++

    # The guard checks syntax, not a second hard-coded compatibility authority
    Set-Content -LiteralPath (Join-Path $fixtureRoot 'README.md') -Value 'Synthetic package fixture'
    Set-Content -LiteralPath (Join-Path $fixtureRoot 'LICENSE') -Value 'Synthetic fixture license'
    Set-Content -LiteralPath (Join-Path $fixtureDocsDirectory 'CHANGELOG.md') -Value 'Synthetic fixture changelog'
    Set-Content -LiteralPath (Join-Path $fixtureSourceDirectory 'Main.lua') -Value 'local addonName, ns = ...'
    Set-Content -LiteralPath (Join-Path $fixtureArtDirectory 'cabinet.png') -Value 'Excluded source art'
    Set-Content -LiteralPath (Join-Path $fixtureArtDirectory 'jackpot.tga') -Value 'Obsolete standalone texture'
    Set-Content -LiteralPath (Join-Path $fixtureArtDirectory 'mockup.png') -Value 'Excluded mockup'
    Set-Content -LiteralPath (Join-Path $fixtureScreenshotsDirectory 'jackpot.png') -Value 'Excluded screenshot'
    Set-Content -LiteralPath (Join-Path $fixtureTestsDirectory 'fixture.lua') -Value 'Excluded test'
    Set-Content -LiteralPath (Join-Path $fixturePublicDirectory 'logo.png') -Value 'Excluded source logo'
    Set-Content -LiteralPath (Join-Path $fixturePublicDirectory 'curseforge-icon.png') -Value 'Excluded upload icon'
    $validTga = [byte[]]::new(18 + 4 * 4 * 4)
    $validTga[2] = 2
    $validTga[12] = 4
    $validTga[14] = 4
    $validTga[16] = 32
    $validTga[17] = 8
    foreach ($name in @('cabinet.tga', 'symbols.tga', 'duration-fill.tga')) {
        [IO.File]::WriteAllBytes((Join-Path $fixtureArtDirectory $name), $validTga)
    }
    [IO.File]::WriteAllBytes((Join-Path $fixturePublicDirectory 'logo.tga'), $validTga)
    $expectedPaths = @('RollTheBonesSlots.toc', 'LICENSE', 'docs/CHANGELOG.md', 'src/Main.lua', `
        'public/art/cabinet.tga', 'public/art/symbols.tga', 'public/art/duration-fill.tga', 'public/logo.tga')
    foreach ($interface in @('123456', '654321')) {
        Set-Content -LiteralPath $fixtureToc -Value @("## Interface: $interface", '## Version: fixture',
            $fixtureIconMetadata, 'src\Main.lua')
        & $fixtureScript | Out-Null
        $archive = [IO.Compression.ZipFile]::OpenRead($existingArchive)
        try {
            if ($archive.Entries.Count -ne $expectedPaths.Count) { throw 'Unexpected fixture archive contents' }
            foreach ($path in $expectedPaths) {
                if (@($archive.Entries | Where-Object { $_.FullName -ceq "RollTheBonesSlots/$path" }).Count -ne 1) {
                    throw "Missing or incorrectly cased fixture entry: $path"
                }
            }
            if ($archive.GetEntry('RollTheBonesSlots/public/art/jackpot.tga')) {
                throw 'Obsolete standalone Jackpot texture leaked into the archive'
            }
            $entry = $archive.GetEntry('RollTheBonesSlots/RollTheBonesSlots.toc')
            if (-not $entry) { throw 'Packaged TOC is missing' }
            $reader = [IO.StreamReader]::new($entry.Open())
            try { $packagedToc = $reader.ReadToEnd() } finally { $reader.Dispose() }
            if ($packagedToc -notmatch "(?m)^## Interface: $interface\r?$") {
                throw 'Packager did not preserve the declared Interface'
            }
        } finally { $archive.Dispose() }
        $checks++
    }

    # Invalid assets fail before replacing a known-good ZIP or leaving temporary output
    $previousHash = (Get-FileHash -LiteralPath $existingArchive -Algorithm SHA256).Hash
    $validToc = Get-Content -LiteralPath $fixtureToc
    foreach ($iconCase in @(
        @{ Lines = @(); Error = 'Expected one TOC IconTexture' },
        @{ Lines = @($fixtureIconMetadata, $fixtureIconMetadata); Error = 'Expected one TOC IconTexture' },
        @{ Lines = @('## IconTexture: Interface\AddOns\OtherAddon\logo.tga'); Error = 'inside this addon' },
        @{ Lines = @('## IconTexture: Interface\AddOns\RollTheBonesSlots\public\logo.png'); Error = 'TGA inside this addon' },
        @{ Lines = @('## IconTexture: Interface\AddOns\RollTheBonesSlots\..\logo.tga'); Error = 'Invalid path' }
    )) {
        Set-Content -LiteralPath $fixtureToc -Value @('## Interface: 654321', '## Version: fixture', 'src\Main.lua')
        foreach ($line in $iconCase.Lines) { Add-Content -LiteralPath $fixtureToc -Value $line }
        Assert-PackageRejected 'invalid logo metadata' $iconCase.Error
        $checks++
    }
    Set-Content -LiteralPath $fixtureToc -Value $validToc

    $logoPath = Join-Path $fixturePublicDirectory 'logo.tga'
    Remove-Item -LiteralPath $logoPath
    Assert-PackageRejected 'missing AddOns-list logo' 'Missing file or incorrect casing'
    [IO.File]::WriteAllBytes($logoPath, $validTga)
    $checks++

    $exportFailurePath = Join-Path $fixtureArtDirectory 'export-error.txt'
    Set-Content -LiteralPath $exportFailurePath -Value 'Synthetic stale export'
    Assert-PackageRejected 'stale artwork export' 'Stale texture export'
    Remove-Item -LiteralPath $exportFailurePath
    $checks++

    # A failed content check must discard its pending ZIP and preserve the previous archive
    function Get-FileHash {
        param([string]$LiteralPath, [string]$Algorithm)
        if ($LiteralPath -eq (Join-Path $fixtureSourceDirectory 'Main.lua')) {
            return [pscustomobject]@{ Hash = 'synthetic mismatch' }
        }
        Microsoft.PowerShell.Utility\Get-FileHash @PSBoundParameters
    }
    try {
        Assert-PackageRejected 'archive verification failure' 'Archive content mismatch'
        $checks++
    } finally {
        Remove-Item -LiteralPath Function:\Get-FileHash
    }

    foreach ($name in @('cabinet.tga', 'symbols.tga', 'duration-fill.tga')) {
        $assetPath = Join-Path $fixtureArtDirectory $name
        $omittedPath = Join-Path $fixtureArtDirectory "$name.omitted"
        Move-Item -LiteralPath $assetPath -Destination $omittedPath
        Assert-PackageRejected "missing $name" 'Missing file or incorrect casing'
        Move-Item -LiteralPath $omittedPath -Destination $assetPath
        $checks++
    }
    $cabinetPath = Join-Path $fixtureArtDirectory 'cabinet.tga'
    $wrongCasePath = Join-Path $fixtureArtDirectory 'Cabinet.tga'
    Rename-Item -LiteralPath $cabinetPath -NewName 'Cabinet.tga'
    Assert-PackageRejected 'incorrect media casing' 'Missing file or incorrect casing'
    Rename-Item -LiteralPath $wrongCasePath -NewName 'cabinet.tga'
    $checks++

    $invalidTextures = @(
        @{ Name = 'short header'; Length = 17; Error = 'uncompressed 32-bit true-color TGA' },
        @{ Name = 'color map'; Offset = 1; Value = 1; Error = 'uncompressed 32-bit true-color TGA' },
        @{ Name = 'RLE compression'; Offset = 2; Value = 10; Error = 'uncompressed 32-bit true-color TGA' },
        @{ Name = '24-bit pixels'; Offset = 16; Value = 24; Error = 'uncompressed 32-bit true-color TGA' },
        @{ Name = 'zero width'; Offset = 12; Value = 0; Error = 'TGA dimensions' },
        @{ Name = 'non-power-of-two height'; Offset = 14; Value = 3; Error = 'TGA dimensions' },
        @{ Name = 'excessive power-of-two width'; Width = 8192; Error = 'TGA dimensions' },
        @{ Name = 'truncated pixels'; Length = 81; Error = 'Truncated TGA pixel data' },
        @{ Name = 'missing image ID bytes'; Offset = 0; Value = 1; Error = 'Truncated TGA pixel data' }
    )
    foreach ($case in $invalidTextures) {
        $invalidTga = [byte[]]$validTga.Clone()
        if ($case.ContainsKey('Length')) { [Array]::Resize([ref]$invalidTga, $case.Length) }
        elseif ($case.ContainsKey('Width')) {
            $invalidTga[12] = $case.Width -band 255
            $invalidTga[13] = $case.Width -shr 8
        }
        else { $invalidTga[$case.Offset] = $case.Value }
        [IO.File]::WriteAllBytes($cabinetPath, $invalidTga)
        Assert-PackageRejected $case.Name $case.Error
        $checks++
    }
    [IO.File]::WriteAllBytes($cabinetPath, $validTga)
    $symbolsPath = Join-Path $fixtureArtDirectory 'symbols.tga'
    $truncatedSymbols = [byte[]]$validTga.Clone()
    [Array]::Resize([ref]$truncatedSymbols, $validTga.Length - 1)
    [IO.File]::WriteAllBytes($symbolsPath, $truncatedSymbols)
    Assert-PackageRejected 'truncated symbol atlas' 'Truncated TGA pixel data'
    [IO.File]::WriteAllBytes($symbolsPath, $validTga)
    $checks++
    Add-Content -LiteralPath $fixtureToc -Value 'public/art/cabinet.tga'
    Assert-PackageRejected 'duplicate runtime media' 'Duplicate package path'
    $checks++
    Write-Output "$checks package checks passed"
} finally {
    # Delete only the exact temporary fixture created by this test
    $resolvedFixture = (Resolve-Path -LiteralPath $fixtureRoot).Path
    $expectedFixture = [IO.Path]::GetFullPath($fixtureRoot)
    if (-not $resolvedFixture.Equals($expectedFixture, [StringComparison]::OrdinalIgnoreCase) `
        -or -not $resolvedFixture.StartsWith($temporaryRoot, [StringComparison]::OrdinalIgnoreCase) `
        -or (Split-Path -Leaf $resolvedFixture) -notmatch '^RollTheBonesSlots-package-test-[0-9a-f]{32}$') {
        throw 'Refusing cleanup outside the temporary package fixture'
    }
    Remove-Item -LiteralPath $resolvedFixture -Recurse -Force
}
