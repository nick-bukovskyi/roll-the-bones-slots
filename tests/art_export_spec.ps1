# Exercise the real artwork and logo exporter with disposable source PNGs
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies @([System.Drawing.Bitmap].Assembly.Location, [System.Drawing.Color].Assembly.Location,
    'System.Runtime', 'System.Private.Windows.GdiPlus', 'System.Private.Windows.Core') -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
public static class SlotArtExportFixture {
    public static void WriteLogo(string path) {
        using(var image = new Bitmap(1254, 1254, PixelFormat.Format32bppArgb))
        using(var graphics = Graphics.FromImage(image))
        using(var halfAlpha = new SolidBrush(Color.FromArgb(128, 0, 255, 0))) {
            graphics.Clear(Color.Transparent);
            graphics.FillRectangle(Brushes.Red, 627, 0, 627, 627);
            graphics.FillRectangle(halfAlpha, 0, 627, 627, 627);
            graphics.FillRectangle(Brushes.Blue, 627, 627, 627, 627);
            image.Save(path, ImageFormat.Png);
        }
    }
    public static void AssertLogoExports(string tgaPath, string pngPath) {
        byte[] data = File.ReadAllBytes(tgaPath);
        byte[] header = {0,0,2,0,0,0,0,0,0,0,0,0,0,1,0,1,32,0x28};
        if(data.Length != 18 + 256*256*4) throw new Exception("Incorrect AddOns-list logo length");
        for(int index = 0; index < header.Length; index++)
            if(data[index] != header[index]) throw new Exception("Incorrect AddOns-list logo header");
        uint[] expected = {0, 0xffff0000, 0x8000ff00, 0xff0000ff};
        using(var image = new Bitmap(pngPath)) {
            if(image.Width != 400 || image.Height != 400)
                throw new Exception("CurseForge icon must be 400x400");
            for(int row = 0; row < 2; row++) for(int column = 0; column < 2; column++) {
                uint tgaPixel = BitConverter.ToUInt32(data, 18 + 4*((32 + row*192)*256 + 32 + column*192));
                uint pngPixel = unchecked((uint)image.GetPixel(50 + column*300, 50 + row*300).ToArgb());
                if(tgaPixel != expected[row*2 + column] || pngPixel != expected[row*2 + column])
                    throw new Exception("Logo exports must preserve orientation, colors, and alpha");
            }
        }
    }
    private static Color Pixel(int x, int y, int seed) {
        // Include every alpha value, colored transparent pixels, and distinct rows
        return Color.FromArgb((x + 3*y) % 256, (x + seed*17) % 256,
            (y + seed*31) % 256, (x + y + seed*53) % 256);
    }
    public static void WritePng(string path, int seed, int width, int height) {
        using(var image = new Bitmap(width, height, PixelFormat.Format32bppArgb)) {
            for(int y = 0; y < height; y++)
                for(int x = 0; x < width; x++) image.SetPixel(x, y, Pixel(x, y, seed));
            image.Save(path, ImageFormat.Png);
        }
    }
    public static void AssertTga(string path, int seed, int sourceHeight) {
        byte[] data = File.ReadAllBytes(path);
        byte[] header = {0,0,2,0,0,0,0,0,0,0,0,0,0,4,0,4,32,0x28};
        if(data.Length != 18 + 1024*1024*4) throw new Exception("Incorrect TGA length: " + path);
        for(int index = 0; index < header.Length; index++)
            if(data[index] != header[index]) throw new Exception("Incorrect TGA header: " + path);
        for(int y = 0; y < 1024; y++) for(int x = 0; x < 1024; x++) {
            uint actual = BitConverter.ToUInt32(data, 18 + 4*(y*1024 + x));
            uint expected = y < sourceHeight ? unchecked((uint)Pixel(x, y, seed).ToArgb()) : 0;
            if(actual != expected) throw new Exception("Changed RGBA pixel at " + x + "," + y + ": " + path);
        }
    }
    private static Color FillPixel(int x, int y, int width, int height) {
        return Color.FromArgb(255, x < width/2 ? 180 : 60, y < height/2 ? 150 : 50, 30);
    }
    public static void WriteFill(string path) {
        using(var image = new Bitmap(1774, 887, PixelFormat.Format32bppArgb)) {
            for(int y = 0; y < image.Height; y++) for(int x = 0; x < image.Width; x++)
                image.SetPixel(x, y, FillPixel(x, y, image.Width, image.Height));
            image.Save(path, ImageFormat.Png);
        }
    }
    public static void AssertFill(string path) {
        byte[] data = File.ReadAllBytes(path);
        byte[] header = {0,0,2,0,0,0,0,0,0,0,0,0,0,4,128,0,32,0x28};
        if(data.Length != 18 + 1024*128*4) throw new Exception("Incorrect compact fill length");
        for(int index = 0; index < header.Length; index++)
            if(data[index] != header[index]) throw new Exception("Incorrect compact fill header");
        for(int y = 0; y < 128; y++) for(int x = 0; x < 1024; x++) {
            uint actual = BitConverter.ToUInt32(data, 18 + 4*(y*1024 + x));
            if((actual >> 24) != 255) throw new Exception("Transparent gap in the fitted fill");
        }
        // Interior and edge samples prove the entire material fits without cropping or padding
        foreach(int y in new[]{0, 16, 112, 127}) foreach(int x in new[]{0, 128, 896, 1023}) {
            uint actual = BitConverter.ToUInt32(data, 18 + 4*(y*1024 + x));
            uint expected = unchecked((uint)FillPixel(x, y, 1024, 128).ToArgb());
            if(actual != expected) throw new Exception("Changed fill quadrant at " + x + "," + y);
        }
    }
}
'@

$projectRoot = Split-Path -Parent $PSScriptRoot
$exportScript = Join-Path $projectRoot 'scripts/export-art.ps1'
$temporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$fixtureRoot = Join-Path $temporaryRoot ('RollTheBonesSlots-art-test-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $fixtureRoot
$publicDirectory = Join-Path $fixtureRoot 'public'
$artDirectory = Join-Path $publicDirectory 'art'
$checks = 0

function Get-FixtureState {
    # Hashes catch writes; fixed timestamps also catch rewrites of identical bytes
    $entries = Get-ChildItem -LiteralPath $fixtureRoot -Recurse -Force | Sort-Object FullName
    return ($entries | ForEach-Object {
        if ($_.PSIsContainer) { "directory|$($_.FullName)" }
        else { "$($_.FullName)|$($_.Length)|$($_.LastWriteTimeUtc.Ticks)|$((Get-FileHash -LiteralPath $_.FullName).Hash)" }
    }) -join "`n"
}

function Assert-ExportCheckRejected {
    param([string]$Name, [string]$ExpectedError)
    $before = Get-FixtureState
    $failure = $null
    try { & $exportScript -ProjectRoot $fixtureRoot -Check | Out-Null } catch { $failure = $_ }
    if (-not $failure -or ($ExpectedError -and $failure.Exception.Message -notmatch $ExpectedError)) {
        throw "Expected export check rejection for $Name; got $failure"
    }
    if ((Get-FixtureState) -cne $before) { throw "Export check changed fixture files for $Name" }
}

try {
    $null = New-Item -ItemType Directory -Path $publicDirectory, $artDirectory
    $cabinetSource = Join-Path $artDirectory 'cabinet.png'
    $symbolsSource = Join-Path $artDirectory 'symbols.png'
    $fillSource = Join-Path $artDirectory 'duration-fill.png'
    [SlotArtExportFixture]::WritePng($cabinetSource, 1, 1024, 630)
    [SlotArtExportFixture]::WritePng($symbolsSource, 2, 1024, 832)
    [SlotArtExportFixture]::WriteFill($fillSource)
    [SlotArtExportFixture]::WriteLogo((Join-Path $publicDirectory 'logo.png'))
    & $exportScript -ProjectRoot $fixtureRoot | Out-Null
    $cabinetOutput = Join-Path $artDirectory 'cabinet.tga'
    $symbolsOutput = Join-Path $artDirectory 'symbols.tga'
    $fillOutput = Join-Path $artDirectory 'duration-fill.tga'
    $logoOutput = Join-Path $publicDirectory 'logo.tga'
    $curseforgeOutput = Join-Path $publicDirectory 'curseforge-icon.png'
    [SlotArtExportFixture]::AssertTga($cabinetOutput, 1, 630)
    [SlotArtExportFixture]::AssertTga($symbolsOutput, 2, 832)
    [SlotArtExportFixture]::AssertFill($fillOutput)
    [SlotArtExportFixture]::AssertLogoExports($logoOutput, $curseforgeOutput)
    $checks += 4
    if (@(Get-ChildItem -LiteralPath $artDirectory -File).Count -ne 6) {
        throw 'Export created unexpected artwork files'
    }
    $checks++

    foreach ($logoExport in @($logoOutput, $curseforgeOutput)) {
        $freshLogo = [IO.File]::ReadAllBytes($logoExport)
        $staleLogo = [byte[]]$freshLogo.Clone()
        $staleLogo[$staleLogo.Length - 1] = $staleLogo[$staleLogo.Length - 1] -bxor 1
        [IO.File]::WriteAllBytes($logoExport, $staleLogo)
        Assert-ExportCheckRejected 'altered logo export' 'Stale texture export'
        [IO.File]::WriteAllBytes($logoExport, $freshLogo)
        $checks++
    }

    foreach ($file in Get-ChildItem -LiteralPath $fixtureRoot -File -Recurse) {
        $file.LastWriteTimeUtc = [datetime]::new(2001, 1, 1, 0, 0, 0, [DateTimeKind]::Utc)
    }
    $before = Get-FixtureState
    & $exportScript -ProjectRoot $fixtureRoot -Check | Out-Null
    if ((Get-FixtureState) -cne $before) { throw 'Successful export check modified fixture files' }
    $checks++

    $freshSymbols = [IO.File]::ReadAllBytes($symbolsOutput)
    $staleSymbols = [byte[]]$freshSymbols.Clone()
    $staleSymbols[22] = $staleSymbols[22] -bxor 1
    [IO.File]::WriteAllBytes($symbolsOutput, $staleSymbols)
    Assert-ExportCheckRejected 'altered output pixel' 'Stale texture export'
    [IO.File]::WriteAllBytes($symbolsOutput, $freshSymbols)
    $checks++

    $freshFill = [IO.File]::ReadAllBytes($fillOutput)
    $staleFill = [byte[]]$freshFill.Clone()
    $staleFill[22] = $staleFill[22] -bxor 1
    [IO.File]::WriteAllBytes($fillOutput, $staleFill)
    Assert-ExportCheckRejected 'altered compact fill' 'Stale texture export'
    [IO.File]::WriteAllBytes($fillOutput, $freshFill)
    $checks++

    Remove-Item -LiteralPath $fillOutput
    Assert-ExportCheckRejected 'missing compact fill export' ''
    [IO.File]::WriteAllBytes($fillOutput, $freshFill)
    $checks++

    # Missing sources are rejected rather than silently accepting an old export
    $sourceBytes = [IO.File]::ReadAllBytes($symbolsSource)
    Remove-Item -LiteralPath $symbolsSource
    Assert-ExportCheckRejected 'missing canonical PNG' ''
    [IO.File]::WriteAllBytes($symbolsSource, $sourceBytes)
    $checks++

    [SlotArtExportFixture]::WritePng($cabinetSource, 1, 1024, 629)
    Assert-ExportCheckRejected 'wrong cabinet dimensions' 'Expected a 1024x630 canonical PNG'
    $checks++

    [SlotArtExportFixture]::WritePng($cabinetSource, 1, 1024, 630)
    [SlotArtExportFixture]::WritePng($symbolsSource, 2, 1023, 832)
    Assert-ExportCheckRejected 'wrong symbols dimensions' 'Expected a 1024x832 canonical PNG'
    $checks++
    Write-Output "$checks art export checks passed"
} finally {
    # Delete only the exact temporary fixture created by this test
    $resolvedFixture = (Resolve-Path -LiteralPath $fixtureRoot).Path
    $expectedFixture = [IO.Path]::GetFullPath($fixtureRoot)
    if (-not $resolvedFixture.Equals($expectedFixture, [StringComparison]::OrdinalIgnoreCase) `
        -or -not $resolvedFixture.StartsWith($temporaryRoot, [StringComparison]::OrdinalIgnoreCase) `
        -or (Split-Path -Leaf $resolvedFixture) -notmatch '^RollTheBonesSlots-art-test-[0-9a-f]{32}$') {
        throw 'Refusing cleanup outside the temporary art fixture'
    }
    Remove-Item -LiteralPath $resolvedFixture -Recurse -Force
}
