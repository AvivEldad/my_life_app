$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$workspace = Split-Path -Parent $PSScriptRoot
$source = [System.Drawing.Image]::FromFile((Join-Path $workspace 'assets/branding/lifeforge-logo.png'))

function Save-IconPng([string]$RelativePath, [int]$Size) {
    $target = Join-Path $workspace $RelativePath
    $bitmap = [System.Drawing.Bitmap]::new($Size, $Size)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.DrawImage($source, 0, 0, $Size, $Size)
        $bitmap.Save($target, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}

try {
    $densities = @{ mdpi = 48; hdpi = 72; xhdpi = 96; xxhdpi = 144; xxxhdpi = 192 }
    foreach ($density in $densities.Keys) {
        Save-IconPng "android/app/src/main/res/mipmap-$density/ic_launcher.png" $densities[$density]
    }
    foreach ($platform in @('ios', 'macos')) {
        $directory = "$platform/Runner/Assets.xcassets/AppIcon.appiconset"
        $catalog = Get-Content -LiteralPath (Join-Path $workspace "$directory/Contents.json") -Raw | ConvertFrom-Json
        foreach ($entry in $catalog.images) {
            if (!$entry.filename) { continue }
            $size = [double]($entry.size.Split('x')[0]) * [double]($entry.scale.TrimEnd('x'))
            Save-IconPng "$directory/$($entry.filename)" ([int]$size)
        }
    }
    Save-IconPng 'web/favicon.png' 32
    foreach ($size in @(192, 512)) {
        Save-IconPng "web/icons/Icon-$size.png" $size
        Save-IconPng "web/icons/Icon-maskable-$size.png" $size
    }
    # Windows supports PNG frames within an ICO container.
    $frames = @()
    foreach ($size in @(16, 24, 32, 48, 64, 128, 256)) {
        $bitmap = [System.Drawing.Bitmap]::new($size, $size)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $memory = [System.IO.MemoryStream]::new()
        try {
            $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.DrawImage($source, 0, 0, $size, $size)
            $bitmap.Save($memory, [System.Drawing.Imaging.ImageFormat]::Png)
            $frames += @{ Size = $size; Data = $memory.ToArray() }
        } finally {
            $graphics.Dispose()
            $bitmap.Dispose()
            $memory.Dispose()
        }
    }
    $stream = [System.IO.File]::Create((Join-Path $workspace 'windows/runner/resources/app_icon.ico'))
    $writer = [System.IO.BinaryWriter]::new($stream)
    try {
        $writer.Write([uint16]0)
        $writer.Write([uint16]1)
        $writer.Write([uint16]$frames.Count)
        $offset = 6 + 16 * $frames.Count
        foreach ($frame in $frames) {
            $dimension = if ($frame.Size -eq 256) { 0 } else { $frame.Size }
            $writer.Write([byte]$dimension)
            $writer.Write([byte]$dimension)
            $writer.Write([byte]0)
            $writer.Write([byte]0)
            $writer.Write([uint16]1)
            $writer.Write([uint16]32)
            $writer.Write([uint32]$frame.Data.Length)
            $writer.Write([uint32]$offset)
            $offset += $frame.Data.Length
        }
        foreach ($frame in $frames) { $writer.Write([byte[]]$frame.Data) }
    } finally { $writer.Dispose() }
} finally { $source.Dispose() }
Write-Output 'Updated Android, iOS, macOS, Windows, and web icons.'
