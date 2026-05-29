Add-Type -AssemblyName System.Drawing

function Resize-Image {
    param([string]$src, [string]$dst, [int]$size)
    $srcImg = [System.Drawing.Image]::FromFile($src)
    $bmp = New-Object System.Drawing.Bitmap $size, $size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $g.DrawImage($srcImg, 0, 0, $size, $size)
    $g.Dispose()
    $srcImg.Dispose()
    $bmp.Save($dst, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Host "Created: $dst at ${size}px"
}

function Resize-Maskable {
    param([string]$src, [string]$dst, [int]$size)
    $padding = [int]($size * 0.12)
    $innerSize = $size - (2 * $padding)
    $srcImg = [System.Drawing.Image]::FromFile($src)
    $bmp = New-Object System.Drawing.Bitmap $size, $size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $bgColor = [System.Drawing.Color]::FromArgb(255, 15, 32, 39)
    $g.Clear($bgColor)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $g.DrawImage($srcImg, $padding, $padding, $innerSize, $innerSize)
    $g.Dispose()
    $srcImg.Dispose()
    $bmp.Save($dst, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Host "Created maskable: $dst at ${size}px"
}

$iconDir = "c:\Users\atubt\AndroidStudioProjects\stayhub\web\icons\"
$src512 = "${iconDir}Icon-512.png"

# Make a temp copy of the original 512 icon before we overwrite it
$tempSrc = "${iconDir}original_source.png"
Copy-Item $src512 $tempSrc

Resize-Image -src $tempSrc -dst "${iconDir}Icon-192.png" -size 192
Resize-Image -src $tempSrc -dst "${iconDir}Icon-512.png" -size 512
Resize-Maskable -src $tempSrc -dst "${iconDir}Icon-maskable-192.png" -size 192
Resize-Maskable -src $tempSrc -dst "${iconDir}Icon-maskable-512.png" -size 512

# Also make a proper favicon (32x32)
Resize-Image -src $tempSrc -dst "c:\Users\atubt\AndroidStudioProjects\stayhub\web\favicon.png" -size 32

# Clean up temp
Remove-Item $tempSrc

Write-Host "All icons generated successfully!"
