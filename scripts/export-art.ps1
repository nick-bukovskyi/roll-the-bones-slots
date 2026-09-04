[CmdletBinding()]
param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [switch]$Check
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
# Finished PNGs are authoritative; conversion only adds transparent runtime padding
Add-Type -ReferencedAssemblies @([System.Drawing.Bitmap].Assembly.Location, [System.Drawing.Color].Assembly.Location,
    'System.Runtime', 'System.Private.Windows.GdiPlus', 'System.Private.Windows.Core') -TypeDefinition @'
using System;
using System.Drawing;
using System.IO;
public static class SlotTextureExport {
    public static void Export(string input,string output,bool check,int sourceWidth,int sourceHeight) {
        const int runtimeWidth=1024, runtimeHeight=1024;
        byte[] expected;
        using(var image=new Bitmap(input))
        using(var bytes=new MemoryStream()){
            if(image.Width!=sourceWidth || image.Height!=sourceHeight)
                throw new InvalidDataException("Expected a "+sourceWidth+"x"+sourceHeight+" canonical PNG: "+input);
            using(var writer=new BinaryWriter(bytes,System.Text.Encoding.UTF8,true)){
                writer.Write(new byte[]{0,0,2,0,0,0,0,0,0,0,0,0});
                writer.Write((ushort)runtimeWidth);writer.Write((ushort)runtimeHeight);
                writer.Write((byte)32);writer.Write((byte)0x28);
                for(int y=0;y<runtimeHeight;y++)for(int x=0;x<runtimeWidth;x++){
                    if(y<sourceHeight){
                        Color color=image.GetPixel(x,y);
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
    @{ Name = 'cabinet'; Width = 1024; Height = 630 },
    @{ Name = 'symbols'; Width = 1024; Height = 832 }
)) {
    [SlotTextureExport]::Export((Join-Path $artDirectory ($asset.Name + '.png')),
        (Join-Path $mediaDirectory ($asset.Name + '.tga')), $Check.IsPresent,
        $asset.Width, $asset.Height)
}
if ($Check) { Write-Output 'Verified both runtime textures match their canonical PNGs and transparent padding' }
else { Write-Output 'Exported cabinet and five-symbol atlas as padded 1024x1024 BGRA32 textures' }
