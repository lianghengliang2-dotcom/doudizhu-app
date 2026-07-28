Add-Type -AssemblyName System.Drawing

$appRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$iconRoot = Join-Path $appRoot 'icons'
[System.IO.Directory]::CreateDirectory($iconRoot) | Out-Null

function New-PwaIcon {
  param(
    [int]$Size,
    [bool]$Maskable,
    [string]$FileName
  )

  $bitmap = New-Object System.Drawing.Bitmap($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  $background = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml('#151515'))
  $panel = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml('#201914'))
  $gold = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml('#e2b84b'))
  $red = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml('#c82121'))
  $goldPen = New-Object System.Drawing.Pen([System.Drawing.ColorTranslator]::FromHtml('#e2b84b'), [Math]::Max(3, $Size * 0.025))
  $font = New-Object System.Drawing.Font('Arial', [single]($Size * 0.15), [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
  $format = New-Object System.Drawing.StringFormat
  try {
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.FillRectangle($background, 0, 0, $Size, $Size)
    $insetPct = 0.10
    if ($Maskable) { $insetPct = 0.20 }
    $inset = [int]($Size * $insetPct)
    $cardSize = $Size - (2 * $inset)
    $cardX = [single]$inset
    $cardY = [single]$inset
    $cardW = [single]$cardSize
    $cardH = [single]$cardSize
    $graphics.FillRectangle($panel, $cardX, $cardY, $cardW, $cardH)
    $graphics.DrawRectangle($goldPen, $cardX, $cardY, $cardW, $cardH)
    $sealSize = [single]($Size * 0.30)
    $sealX = [single](($Size - $sealSize) / 2)
    $sealY = [single]($Size * 0.25)
    $graphics.FillEllipse($red, $sealX, $sealY, $sealSize, $sealSize)
    $spx = [single]($Size * 0.50)
    $spy = [single]($Size * 0.29)
    $sp1 = [System.Drawing.PointF]::new($spx, $spy)
    $sp2 = [System.Drawing.PointF]::new([single]($Size * 0.40), [single]($Size * 0.43))
    $sp3 = [System.Drawing.PointF]::new([single]($Size * 0.60), [single]($Size * 0.43))
    $spade = @($sp1, $sp2, $sp3)
    $graphics.FillPolygon($gold, $spade)
    $format.Alignment = [System.Drawing.StringAlignment]::Center
    $format.LineAlignment = [System.Drawing.StringAlignment]::Center
    $labelX = [single]0
    $labelY = [single]($Size * 0.52)
    $labelW = [single]$Size
    $labelH = [single]($Size * 0.24)
    $graphics.DrawString('DDZ', $font, $gold, $labelX, $labelY, $format)
    $bitmap.Save((Join-Path $iconRoot $FileName), [System.Drawing.Imaging.ImageFormat]::Png)
  }
  finally {
    $format.Dispose()
    $font.Dispose()
    $goldPen.Dispose()
    $red.Dispose()
    $gold.Dispose()
    $panel.Dispose()
    $background.Dispose()
    $graphics.Dispose()
    $bitmap.Dispose()
  }
}

New-PwaIcon -Size 192 -Maskable $false -FileName 'icon-192.png'
New-PwaIcon -Size 512 -Maskable $false -FileName 'icon-512.png'
New-PwaIcon -Size 192 -Maskable $true -FileName 'maskable-192.png'
New-PwaIcon -Size 512 -Maskable $true -FileName 'maskable-512.png'