Add-Type -AssemblyName System.Drawing

function Resize-Image {
    param([string]$src, [string]$dst, [int]$size)
    $srcImg = [System.Drawing.Image]::FromFile($src)
    $bmp = New-Object System.Drawing.Bitmap $size, $size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.DrawImage($srcImg, 0, 0, $size, $size)
    $g.Dispose()
    $srcImg.Dispose()
    $bmp.Save($dst, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Host "Created: $dst"
}

$iconDir = "c:\Users\atubt\AndroidStudioProjects\stayhub\web\icons\"
$src = $iconDir + "Icon-512.png"
$dst = $iconDir + "apple-touch-icon.png"

Resize-Image -src $src -dst $dst -size 180
Write-Host "Done!"
