# Fit authored mask openings to the shared layout before exporting runtime textures.
[CmdletBinding()]
param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [switch]$Check
)
$ErrorActionPreference = 'Stop'
$layout = & (Join-Path $PSScriptRoot 'read-art-layout.ps1') -ProjectRoot $ProjectRoot
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies @([System.Drawing.Bitmap].Assembly.Location, [System.Drawing.Color].Assembly.Location,
    'System.Runtime', 'System.Collections', 'System.Private.Windows.GdiPlus', 'System.Private.Windows.Core') -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
public static class CabinetPreparation {
    static bool Mask(Color p, bool footer) {
        return p.A > 128 && (footer ? p.G > 130 && p.B > 140 && p.R < 90
            : p.R > 120 && p.B > 100 && p.R > p.G * 1.8 && p.B > p.G * 1.7);
    }
    static List<Rectangle> Openings(Color[] pixels, int width, int height, bool footer) {
        var visited = new bool[pixels.Length];
        var found = new List<Rectangle>();
        var queue = new Queue<int>();
        for (int start = 0; start < pixels.Length; start++) {
            if (visited[start] || !Mask(pixels[start], footer)) continue;
            visited[start] = true;
            queue.Enqueue(start);
            int left = width, top = height, right = 0, bottom = 0, count = 0;
            while (queue.Count > 0) {
                int i = queue.Dequeue(), x = i % width, y = i / width;
                left = Math.Min(left, x); right = Math.Max(right, x + 1);
                top = Math.Min(top, y); bottom = Math.Max(bottom, y + 1); count++;
                foreach (int next in new int[] { x > 0 ? i - 1 : -1, x + 1 < width ? i + 1 : -1,
                    y > 0 ? i - width : -1, y + 1 < height ? i + width : -1 }) {
                    if (next < 0 || visited[next] || !Mask(pixels[next], footer)) continue;
                    visited[next] = true; queue.Enqueue(next);
                }
            }
            if (count > pixels.Length / 50) found.Add(Rectangle.FromLTRB(left, top, right, bottom));
        }
        found.Sort((a, b) => a.Left.CompareTo(b.Left));
        if (found.Count != (footer ? 1 : 3)) throw new InvalidDataException("Expected three magenta wells and one cyan footer");
        return found;
    }
    static double Map(double value, double[] target, double[] source) {
        for (int i = 1; i < target.Length; i++) {
            if (target[i] <= target[i - 1] || source[i] <= source[i - 1])
                throw new InvalidDataException("Overlapping cabinet openings");
            if (value <= target[i]) return source[i - 1] + (value - target[i - 1])
                / (target[i] - target[i - 1]) * (source[i] - source[i - 1]);
        }
        return source[source.Length - 1];
    }
    static double[] TitleFace(Color[] pixels, int width, int headerBottom, double centerY) {
        // The blank face is the material surrounding the shared title anchor.
        // Measure its center section so screws, bevels and chamfered ends cannot bias alignment.
        var tops = new List<int>();
        var bottoms = new List<int>();
        for (int sample = 0; sample < 17; sample++) {
            int x = (int)(width * (0.46 + sample * 0.08 / 16));
            int anchor = (int)Math.Round(centerY);
            Color reference = pixels[anchor * width + x];
            if (reference.A < 192 || reference.GetSaturation() < 0.25)
                throw new InvalidDataException("The title anchor must lie inside a solid, blank nameplate face");
            Func<int, bool> face = y => {
                Color p = pixels[y * width + x];
                double hue = Math.Abs(p.GetHue() - reference.GetHue());
                hue = Math.Min(hue, 360 - hue);
                return p.A >= 192 && hue <= 14 && p.GetSaturation() >= reference.GetSaturation() * 0.5
                    && p.GetBrightness() >= reference.GetBrightness() * 0.55;
            };
            int top = anchor, bottom = anchor + 1;
            while (top > 0 && face(top - 1)) top--;
            while (bottom < headerBottom && face(bottom)) bottom++;
            tops.Add(top); bottoms.Add(bottom);
        }
        tops.Sort(); bottoms.Sort();
        int first = tops[tops.Count / 2], last = bottoms[bottoms.Count / 2];
        if (first <= 0 || last >= headerBottom || last - first < headerBottom * 0.15)
            throw new InvalidDataException("Cannot identify a separate blank nameplate within the header");
        return new double[] { first, last };
    }
    static bool Inside(int x, int y, double[] rect) {
        // One source texel of bleed keeps linear filtering clear of the frame edges.
        return x >= Math.Floor(rect[0]) - 1 && x <= Math.Ceiling(rect[2])
            && y >= Math.Floor(rect[1]) - 1 && y <= Math.Ceiling(rect[3]);
    }
    static bool[] FilterSilhouette(bool[] mask, int width, int height, bool expand) {
        var result = new bool[mask.Length];
        for (int y = 0; y < height; y++) for (int x = 0; x < width; x++) {
            bool value = !expand;
            for (int dy = -2; dy <= 2; dy++) {
                for (int dx = -2; dx <= 2; dx++) {
                    if (dx * dx + dy * dy > 4) continue;
                    bool solid = x + dx >= 0 && x + dx < width && y + dy >= 0 && y + dy < height
                        && mask[(y + dy) * width + x + dx];
                    if (solid == expand) { value = expand; break; }
                }
                if (value == expand) break;
            }
            result[y * width + x] = value;
        }
        return result;
    }
    static void CleanSilhouette(Color[] pixels, int width, int height) {
        // Source cutouts contain translucent matte noise and occasional pinholes.
        // Close tiny notches, then remove isolated spikes at roughly one output texel.
        // Genuine openings, including the rope handles, remain transparent.
        var solid = new bool[pixels.Length];
        for (int i = 0; i < pixels.Length; i++) solid[i] = pixels[i].A >= 192;
        var mask = FilterSilhouette(FilterSilhouette(solid, width, height, true), width, height, false);
        mask = FilterSilhouette(FilterSilhouette(mask, width, height, false), width, height, true);
        var visited = new bool[mask.Length];
        var queue = new Queue<int>();
        var cabinet = new List<int>();
        for (int start = 0; start < mask.Length; start++) {
            if (!mask[start] || visited[start]) continue;
            var component = new List<int>();
            visited[start] = true; queue.Enqueue(start);
            while (queue.Count > 0) {
                int i = queue.Dequeue(), x = i % width, y = i / width;
                component.Add(i);
                foreach (int next in new int[] { x > 0 ? i - 1 : -1, x + 1 < width ? i + 1 : -1,
                    y > 0 ? i - width : -1, y + 1 < height ? i + width : -1 }) {
                    if (next < 0 || visited[next] || !mask[next]) continue;
                    visited[next] = true; queue.Enqueue(next);
                }
            }
            if (component.Count > cabinet.Count) cabinet = component;
        }
        if (cabinet.Count < pixels.Length / 2) throw new InvalidDataException("Cabinet cutout must form one connected frame");
        var original = (Color[])pixels.Clone();
        Array.Clear(pixels, 0, pixels.Length);
        foreach (int i in cabinet) {
            Color color = original[i];
            if (!solid[i]) {
                int x = i % width, y = i / width, nearest = 33;
                for (int dy = -4; dy <= 4; dy++) for (int dx = -4; dx <= 4; dx++) {
                    int distance = dx * dx + dy * dy;
                    if (distance >= nearest || x + dx < 0 || x + dx >= width || y + dy < 0 || y + dy >= height) continue;
                    int next = (y + dy) * width + x + dx;
                    if (solid[next]) { nearest = distance; color = original[next]; }
                }
                if (nearest == 33) throw new InvalidDataException("Cutout repair has no neighboring material");
            }
            pixels[i] = Color.FromArgb(255, color.R, color.G, color.B);
        }
    }
    static Color Sample(Color[] pixels, int width, int height, double x, double y) {
        x = Math.Max(0, Math.Min(width - 1, x - 0.5));
        y = Math.Max(0, Math.Min(height - 1, y - 0.5));
        int ix = (int)x, iy = (int)y;
        double dx = x - ix, dy = y - iy, a = 0, r = 0, g = 0, b = 0;
        for (int row = 0; row < 2; row++) for (int col = 0; col < 2; col++) {
            Color p = pixels[Math.Min(height - 1, iy + row) * width + Math.Min(width - 1, ix + col)];
            double weight = (col == 0 ? 1 - dx : dx) * (row == 0 ? 1 - dy : dy) * p.A;
            a += weight; r += p.R * weight; g += p.G * weight; b += p.B * weight;
        }
        return a < 1 ? Color.FromArgb(0, 0, 0, 0) : Color.FromArgb((int)Math.Round(a),
            (int)Math.Round(r / a), (int)Math.Round(g / a), (int)Math.Round(b / a));
    }
    static void BleedTransparentEdges(Bitmap image) {
        // WoW filters straight-alpha textures. Carry the edge color into transparent
        // neighbors so bilinear samples do not pick up a white or black matte.
        using (var original = new Bitmap(image)) {
            for (int y = 0; y < image.Height; y++) for (int x = 0; x < image.Width; x++) {
                if (original.GetPixel(x, y).A != 0) continue;
                int nearest = 9;
                Color edge = Color.FromArgb(0, 0, 0, 0);
                for (int dy = -2; dy <= 2; dy++) for (int dx = -2; dx <= 2; dx++) {
                    int distance = dx * dx + dy * dy;
                    if (distance >= nearest || x + dx < 0 || x + dx >= image.Width || y + dy < 0 || y + dy >= image.Height) continue;
                    Color p = original.GetPixel(x + dx, y + dy);
                    if (p.A >= 64) { nearest = distance; edge = Color.FromArgb(0, p.R, p.G, p.B); }
                }
                image.SetPixel(x, y, edge);
            }
        }
    }
    public static void Prepare(string input, string output, int width, int height,
        double[][] wells, double[] footer, double[] title, int[] rgba, bool check) {
        using (var source = new Bitmap(input)) using (var result = new Bitmap(width, height, PixelFormat.Format32bppArgb)) {
            int sw = source.Width, sh = source.Height;
            var pixels = new Color[sw * sh];
            for (int y = 0; y < sh; y++) for (int x = 0; x < sw; x++) pixels[y * sw + x] = source.GetPixel(x, y);
            var openings = Openings(pixels, sw, sh, false);
            Rectangle bottom = Openings(pixels, sw, sh, true)[0];
            double top = 0, end = 0;
            foreach (var rect in openings) { top += rect.Top / 3.0; end += rect.Bottom / 3.0; }
            var tx = new double[] { 0, wells[0][0], wells[0][2], wells[1][0], wells[1][2], wells[2][0], wells[2][2], width };
            var sx = new double[] { 0, openings[0].Left, openings[0].Right, openings[1].Left, openings[1].Right, openings[2].Left, openings[2].Right, sw };
            var ty = new double[] { 0, wells[0][1], wells[0][3], footer[1], footer[3], height };
            var sy = new double[] { 0, top, end, bottom.Top, bottom.Bottom, sh };
            if (title != null && title.Length == 4) {
                double center = (title[1] + title[3]) / 2, scale = wells[0][1] / top;
                double[] face = TitleFace(pixels, sw, (int)top, center / scale);
                double halfHeight = (face[1] - face[0]) * scale / 2;
                ty = new double[] { 0, center - halfHeight, center + halfHeight, wells[0][1], wells[0][3], footer[1], footer[3], height };
                sy = new double[] { 0, face[0], face[1], top, end, bottom.Top, bottom.Bottom, sh };
            }
            var tfx = new double[] { 0, footer[0], footer[2], width };
            var sfx = new double[] { 0, bottom.Left, bottom.Right, sw };
            Color inset = Color.FromArgb(rgba[3], rgba[0], rgba[1], rgba[2]);
            // Remove mask color before resampling so antialiased boundaries cannot bleed pink/cyan.
            for (int i = 0; i < pixels.Length; i++) {
                Color p = pixels[i];
                if (p.A < 64) pixels[i] = Color.FromArgb(0, 0, 0, 0);
                else if ((p.R > p.G + 25 && p.B > p.G + 25) || (p.G > p.R + 50 && p.B > p.R + 50))
                    pixels[i] = Color.FromArgb(p.A, inset.R, inset.G, inset.B);
            }
            CleanSilhouette(pixels, sw, sh);
            for (int y = 0; y < height; y++) {
                for (int x = 0; x < width; x++) {
                    bool inside = Inside(x, y, footer);
                    foreach (var well in wells) inside |= Inside(x, y, well);
                    if (inside) { result.SetPixel(x, y, inset); continue; }
                    // Area samples retain smooth coverage when reducing the authored cutout.
                    double a = 0, r = 0, g = 0, b = 0;
                    for (int row = 0; row < 3; row++) for (int col = 0; col < 3; col++) {
                        double px = x + (col + 0.5) / 3, py = y + (row + 0.5) / 3;
                        double blend = Math.Max(0, Math.Min(1, (py - wells[0][3]) / (footer[1] - wells[0][3])));
                        double sourceX = Map(px, tx, sx) * (1 - blend) + Map(px, tfx, sfx) * blend;
                        Color p = Sample(pixels, sw, sh, sourceX, Map(py, ty, sy));
                        a += p.A; r += p.R * p.A; g += p.G * p.A; b += p.B * p.A;
                    }
                    result.SetPixel(x, y, a < 4.5 ? Color.FromArgb(0, 0, 0, 0) : Color.FromArgb(
                        (int)Math.Round(a / 9), (int)Math.Round(r / a), (int)Math.Round(g / a), (int)Math.Round(b / a)));
                }
            }
            BleedTransparentEdges(result);
            if (check) {
                using (var actual = new Bitmap(output)) {
                    if (actual.Width != width || actual.Height != height) throw new InvalidDataException("Stale cabinet dimensions: " + output);
                    for (int y = 0; y < height; y++) for (int x = 0; x < width; x++)
                        if (actual.GetPixel(x, y).ToArgb() != result.GetPixel(x, y).ToArgb())
                            throw new InvalidDataException("Stale prepared cabinet: " + output);
                }
            } else result.Save(output, ImageFormat.Png);
        }
    }
}
'@
$artDirectory = Join-Path $ProjectRoot 'public/art'
$rgba = [int[]]@($layout.insetColor | ForEach-Object { [Math]::Round($_ * 255) })
foreach ($asset in $layout.cabinets) {
    $title = if ($asset.PSObject.Properties['title']) { [double[]]$asset.title } else { $null }
    [CabinetPreparation]::Prepare((Join-Path $artDirectory ('cabinet-sources/' + $asset.name + '.png')),
        (Join-Path $artDirectory ($asset.name + '.png')), $asset.width, $asset.height,
        [double[][]]$asset.wells, [double[]]$asset.footer, $title, $rgba, $Check.IsPresent)
}
if ($Check) { Write-Output "Verified $($layout.cabinets.Count) cabinets against authored sources and shared geometry" }
else { Write-Output "Prepared $($layout.cabinets.Count) cabinets with identical reel and footer openings" }
