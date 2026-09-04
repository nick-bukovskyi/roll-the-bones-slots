param([string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
# Mechanical cutout/export of the approved generated sheets, not runtime code
Add-Type -ReferencedAssemblies @([System.Drawing.Bitmap].Assembly.Location, [System.Drawing.Color].Assembly.Location,
    'System.Runtime', 'System.Collections', 'System.Private.Windows.GdiPlus', 'System.Private.Windows.Core') -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
public static class SlotArtExport {
    static Bitmap Cut(Bitmap source, bool cutlassOpenings) {
        var result = new Bitmap(source.Width, source.Height, PixelFormat.Format32bppArgb);
        using (var g = Graphics.FromImage(result)) g.DrawImageUnscaled(source, 0, 0);
        int w = result.Width, h = result.Height;
        // Preserve genuine transparent output rather than keying its painted highlights
        if(source.GetPixel(0,0).A<255 && source.GetPixel(w-1,0).A<255 &&
            source.GetPixel(0,h-1).A<255 && source.GetPixel(w-1,h-1).A<255)return result;
        var visited = new bool[w*h];
        var pending = new Queue<int>();
        for(int x=0;x<w;x++){pending.Enqueue(x);pending.Enqueue((h-1)*w+x);}
        for(int y=0;y<h;y++){pending.Enqueue(y*w);pending.Enqueue(y*w+w-1);}
        if(cutlassOpenings){
            // Enclosed openings in the two cutlass guards are also background
            pending.Enqueue((int)(h*1055.0/1254)*w+(int)(w*140.0/1254));
            pending.Enqueue((int)(h*1055.0/1254)*w+(int)(w*490.0/1254));
        }
        while(pending.Count>0){
            int p=pending.Dequeue(); if(visited[p])continue; visited[p]=true;
            int x=p%w,y=p/w; Color c=result.GetPixel(x,y);
            int min=Math.Min(c.R,Math.Min(c.G,c.B)), max=Math.Max(c.R,Math.Max(c.G,c.B));
            // Only background-connected neutral checkerboard is removed
            if(c.A!=0 && (min<180 || max-min>22))continue;
            result.SetPixel(x,y,Color.FromArgb(0,0,0,0));
            if(x>0)pending.Enqueue(p-1); if(x+1<w)pending.Enqueue(p+1);
            if(y>0)pending.Enqueue(p-w); if(y+1<h)pending.Enqueue(p+w);
        }
        return result;
    }
    static void DrawSymbol(Bitmap output,Bitmap symbol,Rectangle cell){
        int left=symbol.Width,top=symbol.Height,right=-1,bottom=-1;
        for(int y=0;y<symbol.Height;y++)for(int x=0;x<symbol.Width;x++){
            if(symbol.GetPixel(x,y).A==0)continue;
            left=Math.Min(left,x);right=Math.Max(right,x);
            top=Math.Min(top,y);bottom=Math.Max(bottom,y);
        }
        if(right<left || bottom<top)throw new InvalidDataException("Symbol cutout is empty");
        var bounds=Rectangle.FromLTRB(left,top,right+1,bottom+1);
        double scale=370.0/Math.Max(bounds.Width,bounds.Height);
        int width=(int)Math.Round(bounds.Width*scale),height=(int)Math.Round(bounds.Height*scale);
        using(var g=Graphics.FromImage(output)){
            g.SetClip(cell);
            g.CompositingMode=CompositingMode.SourceCopy;
            g.FillRectangle(Brushes.Transparent,cell);
            g.InterpolationMode=InterpolationMode.HighQualityBicubic;
            g.DrawImage(symbol,new Rectangle(cell.X+(cell.Width-width)/2,cell.Y+(cell.Height-height)/2,width,height),
                bounds,GraphicsUnit.Pixel);
        }
    }
    static void ReplaceRumCell(Bitmap output,string rumInput){
        using(var sheet=new Bitmap(rumInput)){
            if(sheet.Width!=sheet.Height || sheet.Width%2!=0)
                throw new InvalidDataException("Expected an even square generated rum sheet");
            int cell=sheet.Width/2;
            using(var source=sheet.Clone(new Rectangle(cell,cell,cell,cell),PixelFormat.Format32bppArgb))
            using(var bottle=Cut(source,false))
                // Discard every regenerated pixel outside symbol four
                DrawSymbol(output,bottle,new Rectangle(512,512,512,512));
        }
    }
    static void Save(Bitmap output,string png,string tga){
        output.Save(png,ImageFormat.Png);
        using(var writer=new BinaryWriter(File.Create(tga))){
            writer.Write(new byte[]{0,0,2,0,0,0,0,0,0,0,0,0});
            writer.Write((ushort)output.Width);writer.Write((ushort)output.Height);
            writer.Write((byte)32);writer.Write((byte)0x28);
            for(int y=0;y<output.Height;y++)for(int x=0;x<output.Width;x++){
                Color c=output.GetPixel(x,y);
                writer.Write(c.B);writer.Write(c.G);writer.Write(c.R);writer.Write(c.A);
            }
        }
    }
    public static void ExportJackpot(string input,string png,string tga){
        using(var original=new Bitmap(input))
        using(var chest=Cut(original,false))
        using(var output=new Bitmap(512,512,PixelFormat.Format32bppArgb)){
            DrawSymbol(output,chest,new Rectangle(0,0,512,512));
            Save(output,png,tga);
        }
    }
    public static void Export(string input,string png,string tga,bool cabinet,string rumInput){
        using(var original=new Bitmap(input))
        using(var cut=Cut(original,!cabinet))
        using(var output=new Bitmap(1024,1024,PixelFormat.Format32bppArgb)){
            using(var g=Graphics.FromImage(output)){
                g.CompositingMode=CompositingMode.SourceCopy;
                g.InterpolationMode=InterpolationMode.HighQualityBicubic;
                if(cabinet)g.DrawImage(cut,new Rectangle(0,0,1024,630),new Rectangle(124,90,1334,820),GraphicsUnit.Pixel);
                else g.DrawImage(cut,new Rectangle(0,0,1024,1024),new Rectangle(0,0,cut.Width,cut.Height),GraphicsUnit.Pixel);
            }
            if(!cabinet)ReplaceRumCell(output,rumInput);
            Save(output,png,tga);
        }
    }
}
'@
$artDirectory = Join-Path $ProjectRoot 'art'
$mediaDirectory = Join-Path $ProjectRoot 'media'
New-Item -ItemType Directory -Path $mediaDirectory -Force | Out-Null
foreach ($asset in @('cabinet', 'symbols')) {
    [SlotArtExport]::Export((Join-Path $artDirectory ($asset + '-source.png')),
        (Join-Path $artDirectory ($asset + '.png')), (Join-Path $mediaDirectory ($asset + '.tga')), $asset -eq 'cabinet',
        (Join-Path $artDirectory 'rum-source.png'))
}
[SlotArtExport]::ExportJackpot((Join-Path $artDirectory 'jackpot-source.png'),
    (Join-Path $artDirectory 'jackpot.png'), (Join-Path $mediaDirectory 'jackpot.tga'))
Write-Output 'Exported two 1024x1024 textures and one 512x512 Jackpot texture with transparent cutouts'
