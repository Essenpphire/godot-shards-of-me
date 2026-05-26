param(
	[string]$ManifestPath = "assets/images/puzzle/light_board_assets_manifest.json",
	[string]$OutputDir = "assets/images/puzzle",
	[string]$TmpDir = "tmp/imagegen/light_board",
	[switch]$SkipGeneration,
	[switch]$ProcessOnly
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

function Ensure-Dir([string]$Path) {
	if (-not (Test-Path -LiteralPath $Path)) {
		New-Item -ItemType Directory -Force -Path $Path | Out-Null
	}
}

function Get-KeyColor([string]$Prompt) {
	if ($Prompt -match "#ff00ff") {
		return [System.Drawing.Color]::FromArgb(255, 255, 0, 255)
	}
	return [System.Drawing.Color]::FromArgb(255, 0, 255, 0)
}

function Resize-Bitmap($Source, [int]$TargetWidth, [int]$TargetHeight) {
	$dest = New-Object System.Drawing.Bitmap($TargetWidth, $TargetHeight, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
	$graphics = [System.Drawing.Graphics]::FromImage($dest)
	$graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
	$graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
	$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
	$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
	$graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
	$graphics.DrawImage($Source, 0, 0, $TargetWidth, $TargetHeight)
	$graphics.Dispose()
	return $dest
}

function Crop-Bitmap($Source, [string]$CropMode) {
	$width = $Source.Width
	$height = $Source.Height
	$rect = $null

	if ($CropMode -eq "beam") {
		$cropHeight = [Math]::Min($height, [Math]::Max(1, [int]($width / 4)))
		$rect = New-Object System.Drawing.Rectangle(0, [int](($height - $cropHeight) / 2), $width, $cropHeight)
	} else {
		$side = [Math]::Min($width, $height)
		$rect = New-Object System.Drawing.Rectangle([int](($width - $side) / 2), [int](($height - $side) / 2), $side, $side)
	}

	return $Source.Clone($rect, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
}

function Remove-ChromaKey($Bitmap, $KeyColor) {
	$transparent = 0
	$partial = 0
	$total = $Bitmap.Width * $Bitmap.Height
	$out = New-Object System.Drawing.Bitmap($Bitmap.Width, $Bitmap.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)

	for ($y = 0; $y -lt $Bitmap.Height; $y++) {
		for ($x = 0; $x -lt $Bitmap.Width; $x++) {
			$c = $Bitmap.GetPixel($x, $y)
			$distance = [Math]::Max([Math]::Abs($c.R - $KeyColor.R), [Math]::Max([Math]::Abs($c.G - $KeyColor.G), [Math]::Abs($c.B - $KeyColor.B)))
			$alpha = 255
			if ($distance -le 18) {
				$alpha = 0
			} elseif ($distance -lt 140) {
				$alpha = [Math]::Min(255, [Math]::Max(0, [int](255 * (($distance - 18) / 122.0))))
			}

			if ($alpha -eq 0) {
				$transparent++
				$out.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(0, 0, 0, 0))
			} else {
				if ($alpha -lt 255) {
					$partial++
				}
				$r = $c.R
				$g = $c.G
				$b = $c.B
				if ($alpha -lt 255) {
					if ($KeyColor.G -gt 200) {
						$g = [Math]::Min($g, [Math]::Max($r, $b))
					} elseif ($KeyColor.R -gt 200 -and $KeyColor.B -gt 200) {
						$r = [Math]::Min($r, $g)
						$b = [Math]::Min($b, $g)
					}
				}
				$out.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($alpha, $r, $g, $b))
			}
		}
	}

	return @{
		Bitmap = $out
		Transparent = $transparent
		Partial = $partial
		Total = $total
	}
}

function Save-Png($Bitmap, [string]$Path) {
	Ensure-Dir ([System.IO.Path]::GetDirectoryName($Path))
	$Bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
}

Ensure-Dir $OutputDir
Ensure-Dir $TmpDir
Ensure-Dir (Join-Path $TmpDir "raw")

$manifest = Get-Content -Raw -LiteralPath $ManifestPath | ConvertFrom-Json
$jsonlPath = Join-Path $TmpDir "jobs.jsonl"
$mdPath = Join-Path $OutputDir "light_board_prompts.md"
$validationPath = Join-Path $OutputDir "light_board_validation.json"

$md = New-Object System.Collections.Generic.List[string]
$md.Add("# Light Board Image Prompts")
$md.Add("")
$jobs = New-Object System.Collections.Generic.List[string]

foreach ($asset in $manifest) {
	$md.Add("## $($asset.file)")
	$md.Add("")
	$md.Add("- Size: " + $asset.size)
	$md.Add("- Transparent: " + $asset.transparent)
	$md.Add("")
	$md.Add('~~~text')
	$md.Add($asset.prompt)
	$md.Add('~~~')
	$md.Add("")

	$job = [ordered]@{
		prompt = $asset.prompt
		size = $asset.api_size
		quality = "medium"
		out = $asset.raw
	}
	$jobs.Add(($job | ConvertTo-Json -Compress))
}

Set-Content -LiteralPath $mdPath -Value ($md -join "`n") -Encoding UTF8
Set-Content -LiteralPath $jsonlPath -Value ($jobs -join "`n") -Encoding UTF8

if ($SkipGeneration) {
	Write-Host "Wrote prompts: $mdPath"
	Write-Host "Wrote jobs: $jsonlPath"
	return
}

if (-not $ProcessOnly) {
	$imageGen = "C:\Users\bulbel\.codex\skills\.system\imagegen\scripts\image_gen.py"
	python $imageGen generate-batch --input $jsonlPath --out-dir (Join-Path $TmpDir "raw") --model gpt-image-2 --quality medium --force --concurrency 3 --no-augment
}

$validation = New-Object System.Collections.Generic.List[object]

foreach ($asset in $manifest) {
	$parts = $asset.size -split "x"
	$targetWidth = [int]$parts[0]
	$targetHeight = [int]$parts[1]
	$rawPath = Join-Path (Join-Path $TmpDir "raw") $asset.raw
	$outPath = Join-Path $OutputDir $asset.file

	if (-not (Test-Path -LiteralPath $rawPath)) {
		throw "Missing generated raw image: $rawPath"
	}

	$source = [System.Drawing.Bitmap]::FromFile((Resolve-Path -LiteralPath $rawPath))
	$cropped = Crop-Bitmap $source $asset.crop
	$resized = Resize-Bitmap $cropped $targetWidth $targetHeight
	$source.Dispose()
	$cropped.Dispose()

	$transparentPixels = 0
	$partialPixels = 0
	$totalPixels = $targetWidth * $targetHeight
	if ($asset.transparent) {
		$keyColor = Get-KeyColor $asset.prompt
		$result = Remove-ChromaKey $resized $keyColor
		$resized.Dispose()
		$resized = $result.Bitmap
		$transparentPixels = $result.Transparent
		$partialPixels = $result.Partial
		$totalPixels = $result.Total
		if ($transparentPixels -le 0) {
			$resized.Dispose()
			throw "Transparent asset has no fully transparent pixels after key removal: $($asset.file)"
		}
	}

	Save-Png $resized $outPath
	$resized.Dispose()

	$validation.Add([ordered]@{
		file = $asset.file
		width = $targetWidth
		height = $targetHeight
		transparent_required = [bool]$asset.transparent
		transparent_pixels = $transparentPixels
		partial_pixels = $partialPixels
		total_pixels = $totalPixels
	})
}

Set-Content -LiteralPath $validationPath -Value ($validation | ConvertTo-Json -Depth 4) -Encoding UTF8
Write-Host "Wrote prompts: $mdPath"
Write-Host "Wrote validation: $validationPath"
