# Extract all .xmind files under origin/ and tech-stack/ into _build/raw and _build/outlines.
# Re-run this whenever xmind files are updated.
#
# Usage: powershell -ExecutionPolicy Bypass -File _build\extract-xmind.ps1

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Add-Type -AssemblyName System.IO.Compression.FileSystem

$repoRoot   = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$sourceRoots = @(
    (Join-Path $repoRoot 'origin'),
    (Join-Path $repoRoot 'tech-stack')
)
$rawRoot    = Join-Path $repoRoot '_build\raw'
$outRoot    = Join-Path $repoRoot '_build\outlines'

function Walk-Topic {
    param($topic, [int]$level)
    $lines = New-Object System.Collections.Generic.List[string]
    if ($null -eq $topic) { return $lines }

    $indent = '  ' * [Math]::Max(0, $level - 1)
    $title  = if ($topic.title) { $topic.title -replace "`r?`n", ' ' } else { '(untitled)' }

    if ($level -eq 0) {
        $lines.Add("# $title")
        $lines.Add('')
    } else {
        $lines.Add("$indent- $title")
    }

    if ($topic.notes -and $topic.notes.plain -and $topic.notes.plain.content) {
        $noteText = ($topic.notes.plain.content -replace "`r?`n", ' ').Trim()
        if ($noteText) { $lines.Add("$indent  > note: $noteText") }
    }

    if ($topic.image -and $topic.image.src) {
        $lines.Add("$indent  > image: $($topic.image.src)")
    }

    if ($topic.href) {
        $lines.Add("$indent  > link: $($topic.href)")
    }

    if ($topic.children) {
        if ($topic.children.attached) {
            foreach ($child in $topic.children.attached) {
                $lines.AddRange([string[]](Walk-Topic -topic $child -level ($level + 1)))
            }
        }
        if ($topic.children.detached) {
            foreach ($child in $topic.children.detached) {
                $lines.AddRange([string[]](Walk-Topic -topic $child -level ($level + 1)))
            }
        }
    }

    return $lines
}

function Extract-OneXmind {
    param([System.IO.FileInfo]$xmind)

    $relPath  = $xmind.FullName.Substring($sourceRoot.Length + 1)
    $relDir   = Split-Path $relPath -Parent
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($xmind.Name)

    $rawDir = if ($relDir) { Join-Path $rawRoot (Join-Path $relDir $baseName) } else { Join-Path $rawRoot $baseName }
    $outDir = if ($relDir) { Join-Path $outRoot $relDir } else { $outRoot }
    $outFile = Join-Path $outDir "$baseName.outline.md"

    if (Test-Path $rawDir) { Remove-Item $rawDir -Recurse -Force }
    New-Item -ItemType Directory -Path $rawDir -Force | Out-Null
    if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }

    [System.IO.Compression.ZipFile]::ExtractToDirectory($xmind.FullName, $rawDir)

    $contentPath = Join-Path $rawDir 'content.json'
    if (-not (Test-Path $contentPath)) {
        Write-Warning "  no content.json (legacy XMind 8?), skip outline: $relPath"
        return [PSCustomObject]@{ File=$relPath; Status='no-content.json'; OutFile=$null }
    }

    $sheets = Get-Content $contentPath -Raw -Encoding UTF8 | ConvertFrom-Json

    $allLines = New-Object System.Collections.Generic.List[string]
    $allLines.Add("<!-- auto-generated from $relPath by _build/extract-xmind.ps1, do NOT edit -->")
    $allLines.Add('')

    $sheetIdx = 0
    foreach ($sheet in $sheets) {
        $sheetIdx++
        $sheetTitle = if ($sheet.title) { $sheet.title } else { "Sheet $sheetIdx" }
        if ($sheets.Count -gt 1) {
            $allLines.Add("## [Sheet $sheetIdx] $sheetTitle")
            $allLines.Add('')
        }
        $allLines.AddRange([string[]](Walk-Topic -topic $sheet.rootTopic -level 0))
        $allLines.Add('')
    }

    Set-Content -Path $outFile -Value ($allLines -join "`r`n") -Encoding UTF8

    return [PSCustomObject]@{ File=$relPath; Status='ok'; OutFile=$outFile.Substring($repoRoot.Length + 1) }
}

$xminds = @()
foreach ($sr in $sourceRoots) {
    if (Test-Path $sr) {
        Write-Host "Scanning $sr for *.xmind ..."
        $found = Get-ChildItem -Path $sr -Recurse -Filter *.xmind
        if ($found) {
            foreach ($f in $found) {
                $xminds += [PSCustomObject]@{ File=$f; SourceRoot=$sr }
            }
        }
    }
}

if (-not $xminds) {
    Write-Host 'No xmind files found.'
    return
}

$results = @()
foreach ($entry in $xminds) {
    $sourceRoot = $entry.SourceRoot
    $x = $entry.File
    Write-Host "Processing: $($x.FullName.Substring($sourceRoot.Length + 1))"
    try {
        $results += Extract-OneXmind -xmind $x
    } catch {
        Write-Warning "  FAILED: $_"
        $results += [PSCustomObject]@{
            File=$x.FullName.Substring($sourceRoot.Length + 1)
            Status="error: $($_.Exception.Message)"
            OutFile=$null
        }
    }
}

Write-Host ''
Write-Host '=== Summary ==='
$results | Format-Table -AutoSize -Wrap
