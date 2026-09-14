# Check shipped artwork against runtime geometry, including linear-filter bleed.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$layout = & (Join-Path $projectRoot 'scripts/read-art-layout.ps1')
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies @([System.Drawing.Bitmap].Assembly.Location, [System.Drawing.Color].Assembly.Location,
    'System.Runtime', 'System.Collections', 'System.Private.Windows.GdiPlus', 'System.Private.Windows.Core') -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Drawing;
public static class CabinetArtChecks {
    static bool Nameplate(Color p, bool brass) {
        // Independent color probes identify the blank face rather than the dark outline or screws.
        return p.A == 255 && (brass ? p.R > 150 && p.G > 90 && p.B < p.G * 0.75
            : p.R > 45 && p.R > p.G * 2 && p.R > p.B * 1.8);
    }
    static void CheckTitle(Bitmap image, double[] title, bool brass, string path) {
        double expected = (title[1] + title[3]) / 2;
        var centers = new List<double>();
        for (int sample = -3; sample <= 3; sample++) {
            int x = image.Width / 2 + sample * 5, top = (int)Math.Round(expected), bottom = top + 1;
            if (!Nameplate(image.GetPixel(x,top),brass)) throw new Exception("Title lies outside the nameplate: " + path);
            while (top > 0 && Nameplate(image.GetPixel(x,top-1),brass)) top--;
            while (bottom < image.Height && Nameplate(image.GetPixel(x,bottom),brass)) bottom++;
            centers.Add((top + bottom) / 2.0);
        }
        centers.Sort();
        if (Math.Abs(centers[3] - expected) > 2)
            throw new Exception("Nameplate face is off-center: " + centers[3] + " vs " + expected + ": " + path);
    }
    static void CheckRail(Bitmap image, double[][] wells, string path) {
        int first = image.Height, last = 0;
        for (int x = (int)Math.Ceiling(wells[0][0]); x < wells[2][2]; x++) {
            int top = 0;
            while (top < wells[0][1] && image.GetPixel(x,top).A < 192) top++;
            if (wells[0][1] - top < 22) throw new Exception("Compact top rail is too thin at " + x + ": " + path);
            first = Math.Min(first,top); last = Math.Max(last,top);
        }
        if (last - first > 3) throw new Exception("Compact top rail must have an even outer edge: " + path);
    }
    static void CheckSilhouette(Bitmap image, string path) {
        int width = image.Width, height = image.Height;
        var alpha = new byte[width * height];
        int solid = 0, start = -1;
        for (int y = 0; y < height; y++) for (int x = 0; x < width; x++) {
            int i = y * width + x;
            alpha[i] = image.GetPixel(x,y).A;
            if (alpha[i] >= 192) { solid++; start = i; }
        }
        var visited = new bool[alpha.Length];
        var queue = new Queue<int>();
        if (start < 0) throw new Exception("Missing cabinet silhouette: " + path);
        visited[start] = true; queue.Enqueue(start);
        int connected = 0;
        while (queue.Count > 0) {
            int i = queue.Dequeue(), x = i % width, y = i / width;
            connected++;
            for (int dy = -1; dy <= 1; dy++) for (int dx = -1; dx <= 1; dx++) {
                if (x+dx < 0 || x+dx >= width || y+dy < 0 || y+dy >= height) continue;
                int next = (y+dy)*width+x+dx;
                if (visited[next] || alpha[next] < 192) continue;
                visited[next] = true; queue.Enqueue(next);
            }
        }
        if (connected != solid) throw new Exception("Detached edge specks remain in the cabinet cutout: " + path);
        for (int y = 2; y < height-2; y++) for (int x = 2; x < width-2; x++) {
            int i = y*width+x;
            if (alpha[i] == 255) continue;
            if (alpha[i-2] == 255 && alpha[i+2] == 255 && alpha[i-2*width] == 255 && alpha[i+2*width] == 255)
                throw new Exception("Translucent pinhole in solid cabinet material at " + x + "," + y + ": " + path);
        }
    }
    public static void Check(string path, int width, int height, double[][] wells, double[] footer,
        double[] title, bool brass, bool straightRail, int[] rgba) {
        using (var image = new Bitmap(path)) {
            if (image.Width != width || image.Height != height) throw new Exception("Wrong cabinet dimensions: " + path);
            Color inset = Color.FromArgb(rgba[3], rgba[0], rgba[1], rgba[2]);
            var openings = new double[][] { wells[0], wells[1], wells[2], footer };
            foreach (var rect in openings) {
                for (int y = (int)Math.Floor(rect[1]) - 1; y <= Math.Ceiling(rect[3]); y++)
                    for (int x = (int)Math.Floor(rect[0]) - 1; x <= Math.Ceiling(rect[2]); x++)
                        if (image.GetPixel(x, y).ToArgb() != inset.ToArgb())
                            throw new Exception("Cabinet opening disagrees with the shared backing at " + x + "," + y + ": " + path);
            }
            int transparent = 0, material = 0;
            for (int y = 0; y < height; y++) for (int x = 0; x < width; x++) {
                Color p = image.GetPixel(x, y);
                if (p.A == 0) {
                    transparent++;
                    if (x > 0 && x + 1 < width && y > 0 && y + 1 < height) {
                        bool opaqueNeighbor = false, carriesEdgeColor = false;
                        foreach (Color neighbor in new Color[] { image.GetPixel(x-1,y), image.GetPixel(x+1,y), image.GetPixel(x,y-1), image.GetPixel(x,y+1) }) {
                            opaqueNeighbor |= neighbor.A >= 192;
                            carriesEdgeColor |= neighbor.A >= 64 && Math.Abs(p.R - neighbor.R) <= 2
                                && Math.Abs(p.G - neighbor.G) <= 2 && Math.Abs(p.B - neighbor.B) <= 2;
                        }
                        if (opaqueNeighbor && !carriesEdgeColor)
                            throw new Exception("Transparent edge loses its neighboring material color at " + x + "," + y + ": " + path);
                    }
                }
                if (p.A < 64) continue;
                if (p.ToArgb() != inset.ToArgb()) material++;
                if ((p.R > p.G + 25 && p.B > p.G + 25) || (p.G > p.R + 50 && p.B > p.R + 50))
                    throw new Exception("Technical mask color leaked into artwork: " + path);
            }
            if (transparent < width || material < width * height / 10)
                throw new Exception("Cabinet must retain transparent exterior and visible materials: " + path);
            if (image.GetPixel(0, 0).A != 0 || image.GetPixel(width - 1, height - 1).A != 0)
                throw new Exception("Cabinet exterior must remain transparent: " + path);
            CheckSilhouette(image,path);
            if (title != null && title.Length == 4) CheckTitle(image,title,brass,path);
            if (straightRail) CheckRail(image,wells,path);
        }
    }
}
'@
$rgba = [int[]]@($layout.insetColor | ForEach-Object { [Math]::Round($_ * 255) })
foreach ($asset in $layout.cabinets) {
    $title = if ($asset.PSObject.Properties['title']) { [double[]]$asset.title } else { $null }
    [CabinetArtChecks]::Check((Join-Path $projectRoot ('public/art/' + $asset.name + '.png')),
        $asset.width, $asset.height, [double[][]]$asset.wells, [double[]]$asset.footer, $title,
        ($asset.name -eq 'cabinet-captains-walnut'),
        ($asset.name -in @('cabinet-captains-walnut-compact','cabinet-tavern-oak-compact')), $rgba)
}
Write-Output "Verified all $($layout.cabinets.Count) cabinet textures: aligned openings and titles, solid cutouts, even Mini rails, and no mask color"
