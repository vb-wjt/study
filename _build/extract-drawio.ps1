# Extract all .drawio files under origin/ and tech-stack/ into _build/outlines.
# Re-run this whenever drawio files are updated.
#
# Usage: powershell -ExecutionPolicy Bypass -File _build\extract-drawio.ps1
#
# Notes:
#   - Only handles uncompressed mxfile XML (drawio "Edit Diagram" -> not compressed).
#     If your file has a compressed <diagram>...base64...</diagram>, the script will
#     report it and skip; toggle "Extras -> Edit Diagram" -> uncheck Compressed and re-save.

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$repoRoot   = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$sourceRoots = @(
    (Join-Path $repoRoot 'origin'),
    (Join-Path $repoRoot 'tech-stack')
)
$outRoot    = Join-Path $repoRoot '_build\outlines'

function Strip-Html {
    param([string]$html)
    if ([string]::IsNullOrWhiteSpace($html)) { return '' }
    $t = $html -replace '<br\s*/?>', "`n"
    $t = $t -replace '<[^>]+>', ''
    $t = [System.Net.WebUtility]::HtmlDecode($t)
    $t = $t -replace "`r", ''
    $t = ($t -split "`n" | ForEach-Object { ($_ -replace '\s+', ' ').Trim() } | Where-Object { $_ }) -join "`n"
    return $t.Trim()
}

function Extract-OneDrawio {
    param([System.IO.FileInfo]$drawio)

    $relPath  = $drawio.FullName.Substring($sourceRoot.Length + 1)
    $relDir   = Split-Path $relPath -Parent
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($drawio.Name)

    $outDir  = if ($relDir) { Join-Path $outRoot $relDir } else { $outRoot }
    $outFile = Join-Path $outDir "$baseName.outline.md"
    if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }

    [xml]$doc = Get-Content $drawio.FullName -Raw -Encoding UTF8

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("<!-- auto-generated from $relPath by _build/extract-drawio.ps1, do NOT edit -->")
    $lines.Add('')

    $diagrams = @($doc.mxfile.diagram)
    $pageIdx = 0
    $totalVertex = 0
    $totalEdge = 0
    $skipped = $false

    foreach ($diag in $diagrams) {
        $pageIdx++
        $pageName = if ($diag.name) { $diag.name } else { "Page $pageIdx" }
        $lines.Add("## [Page $pageIdx] $pageName")
        $lines.Add('')

        if (-not $diag.mxGraphModel) {
            $lines.Add('  > (compressed diagram, skipped — re-save with "Compressed" disabled)')
            $lines.Add('')
            $skipped = $true
            continue
        }

        $cells = @($diag.mxGraphModel.root.mxCell)

        $idToValue = @{}
        foreach ($c in $cells) {
            $v = Strip-Html $c.value
            if ($v) { $idToValue[$c.id] = $v }
        }

        $vertices = @($cells | Where-Object { $_.vertex -eq '1' })
        $edges    = @($cells | Where-Object { $_.edge -eq '1' })

        $vertexLines = New-Object System.Collections.Generic.List[string]
        foreach ($v in $vertices) {
            $val = Strip-Html $v.value
            if ($val) {
                $sub = $val -split "`n"
                $vertexLines.Add("  - $($sub[0])")
                for ($i = 1; $i -lt $sub.Count; $i++) {
                    $vertexLines.Add("      $($sub[$i])")
                }
            }
        }
        if ($vertexLines.Count -gt 0) {
            $lines.Add("### Nodes ($($vertexLines.Count))")
            $lines.AddRange([string[]]$vertexLines)
            $lines.Add('')
            $totalVertex += $vertexLines.Count
        }

        $edgeLines = New-Object System.Collections.Generic.List[string]
        foreach ($e in $edges) {
            $srcId = $e.source
            $tgtId = $e.target
            $src = if ($srcId -and $idToValue.ContainsKey($srcId)) { $idToValue[$srcId] } else { '?' }
            $tgt = if ($tgtId -and $idToValue.ContainsKey($tgtId)) { $idToValue[$tgtId] } else { '?' }
            $label = Strip-Html $e.value

            if ($src -eq '?' -and $tgt -eq '?' -and -not $label) { continue }

            $srcShort = ($src -split "`n")[0]
            $tgtShort = ($tgt -split "`n")[0]
            $labelShort = if ($label) { ($label -split "`n")[0] } else { '' }
            $line = "  - $srcShort  ->  $tgtShort"
            if ($labelShort) { $line += "    [$labelShort]" }
            $edgeLines.Add($line)
        }
        if ($edgeLines.Count -gt 0) {
            $lines.Add("### Edges ($($edgeLines.Count))")
            $lines.AddRange([string[]]$edgeLines)
            $lines.Add('')
            $totalEdge += $edgeLines.Count
        }
    }

    Set-Content -Path $outFile -Value ($lines -join "`r`n") -Encoding UTF8

    return [PSCustomObject]@{
        File     = $relPath
        Pages    = $pageIdx
        Vertices = $totalVertex
        Edges    = $totalEdge
        Status   = if ($skipped) { 'partial (compressed pages skipped)' } else { 'ok' }
        OutFile  = $outFile.Substring($repoRoot.Length + 1)
    }
}

$drawios = @()
foreach ($sr in $sourceRoots) {
    if (Test-Path $sr) {
        Write-Host "Scanning $sr for *.drawio ..."
        $found = Get-ChildItem -Path $sr -Recurse -Filter *.drawio
        if ($found) {
            foreach ($f in $found) {
                $drawios += [PSCustomObject]@{ File=$f; SourceRoot=$sr }
            }
        }
    }
}

if (-not $drawios) {
    Write-Host 'No drawio files found.'
    return
}

$results = @()
foreach ($entry in $drawios) {
    $sourceRoot = $entry.SourceRoot
    $d = $entry.File
    Write-Host "Processing: $($d.FullName.Substring($sourceRoot.Length + 1))"
    try {
        $results += Extract-OneDrawio -drawio $d
    } catch {
        Write-Warning "  FAILED: $_"
        $results += [PSCustomObject]@{
            File     = $d.FullName.Substring($sourceRoot.Length + 1)
            Pages    = 0
            Vertices = 0
            Edges    = 0
            Status   = "error: $($_.Exception.Message)"
            OutFile  = $null
        }
    }
}

Write-Host ''
Write-Host '=== Summary ==='
$results | Format-Table -AutoSize -Wrap
