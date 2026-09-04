[CmdletBinding()]
param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [switch]$Check
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
# Finished PNGs are authoritative; atlas exports preserve pixels, bar material fits its runtime strip
Add-Type -ReferencedAssemblies @([System.Drawing.Bitmap].Assembly.Location, [System.Drawing.Color].Assembly.Location,
    'System.Runtime', 'System.Private.Windows.GdiPlus', 'System.Private.Windows.Core') -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
public static class SlotTextureExport {
    public static void Export(string input,string output,bool check,int sourceWidth,int sourceHeight,
        int runtimeWidth,int runtimeHeight,bool fit) {
        byte[] expected;
        using(var image=new Bitmap(input))
        using(var fitted=fit ? new Bitmap(runtimeWidth,runtimeHeight,PixelFormat.Format32bppArgb) : null)
        using(var bytes=new MemoryStream()){
            if(image.Width!=sourceWidth || image.Height!=sourceHeight)
                throw new InvalidDataException("Expected a "+sourceWidth+"x"+sourceHeight+" canonical PNG: "+input);
            if(fit){
                using(var graphics=Graphics.FromImage(fitted))
                using(var attributes=new ImageAttributes()){
                    graphics.CompositingMode=CompositingMode.SourceCopy;
                    graphics.InterpolationMode=InterpolationMode.HighQualityBicubic;
                    graphics.PixelOffsetMode=PixelOffsetMode.HighQuality;
                    attributes.SetWrapMode(WrapMode.TileFlipXY);
                    graphics.DrawImage(image,new Rectangle(0,0,runtimeWidth,runtimeHeight),
                        0,0,sourceWidth,sourceHeight,GraphicsUnit.Pixel,attributes);
                }
            }
            var pixels=fitted ?? image;
            using(var writer=new BinaryWriter(bytes,System.Text.Encoding.UTF8,true)){
                writer.Write(new byte[]{0,0,2,0,0,0,0,0,0,0,0,0});
                writer.Write((ushort)runtimeWidth);writer.Write((ushort)runtimeHeight);
                writer.Write((byte)32);writer.Write((byte)0x28);
                for(int y=0;y<runtimeHeight;y++)for(int x=0;x<runtimeWidth;x++){
                    if(x<pixels.Width && y<pixels.Height){
                        Color color=pixels.GetPixel(x,y);
                        writer.Write(color.B);writer.Write(color.G);writer.Write(color.R);writer.Write(color.A);
                    } else {
                        writer.Write((byte)0);writer.Write((byte)0);writer.Write((byte)0);writer.Write((byte)0);
                    }
                }
            }
            expected=bytes.ToArray();
        }
        if(check){
            byte[] actual=File.ReadAllBytes(output);
            if(actual.Length!=expected.Length)throw new InvalidDataException("Stale texture export: "+output);
            for(int index=0;index<expected.Length;index++)
                if(actual[index]!=expected[index])throw new InvalidDataException("Stale texture export: "+output);
        } else {
            File.WriteAllBytes(output,expected);
        }
    }
}
'@
$artDirectory = Join-Path $ProjectRoot 'art'
$mediaDirectory = Join-Path $ProjectRoot 'media'
if (-not $Check) { New-Item -ItemType Directory -Path $mediaDirectory -Force | Out-Null }
foreach ($asset in @(
    @{ Name = 'cabinet'; Width = 1024; Height = 630; RuntimeWidth = 1024; RuntimeHeight = 1024; Fit = $false },
    @{ Name = 'symbols'; Width = 1024; Height = 832; RuntimeWidth = 1024; RuntimeHeight = 1024; Fit = $false },
    @{ Name = 'duration-fill'; Width = 1774; Height = 887; RuntimeWidth = 1024; RuntimeHeight = 128; Fit = $true }
)) {
    [SlotTextureExport]::Export((Join-Path $artDirectory ($asset.Name + '.png')),
        (Join-Path $mediaDirectory ($asset.Name + '.tga')), $Check.IsPresent,
        $asset.Width, $asset.Height, $asset.RuntimeWidth, $asset.RuntimeHeight, $asset.Fit)
}
if ($Check) { Write-Output 'Verified all runtime textures match their canonical PNG exports' }
else { Write-Output 'Exported padded cabinet and symbol atlas plus the compact 1024x128 duration fill' }
