using System;
using System.Drawing;
using System.Drawing.Imaging;

class Program
{
    static void Main(string[] args)
    {
        if (args.Length < 3) return;
        using var idle = new Bitmap(args[0]);
        using var flash = new Bitmap(args[1]);
        using var output = new Bitmap(idle.Width, idle.Height, PixelFormat.Format32bppArgb);

        using (var g = Graphics.FromImage(output))
        {
            g.CompositingMode = System.Drawing.Drawing2D.CompositingMode.SourceCopy;
            g.DrawImage(idle, 0, 0, idle.Width, idle.Height);

            var cx = idle.Width / 2f;
            var cy = idle.Height / 2f;
            var scale = 0.78f;
            var w = (int)(flash.Width * scale);
            var h = (int)(flash.Height * scale);
            var x = (int)(cx - w / 2f);
            var y = (int)(cy - h / 2f);
            g.CompositingMode = System.Drawing.Drawing2D.CompositingMode.SourceOver;
            g.DrawImage(flash, x, y, w, h);
        }

        output.Save(args[2], ImageFormat.Png);
    }
}
