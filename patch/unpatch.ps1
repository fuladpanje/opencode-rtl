# OpenCode-RTL - RTL text rendering fix for OpenCode Desktop
# Author: Reza Fuladpanjeh (https://fuladpanjeh.ir)
# License: MIT

param(
  [string]$AsarPath = ""
)

$ErrorActionPreference = "Stop"

function Find-AsarPath {
  param([string]$InputPath)

  if ($InputPath -and (Test-Path $InputPath)) {
    $Resolved = (Resolve-Path $InputPath).Path
    if (Test-Path $Resolved -PathType Leaf) {
      return $Resolved
    }

    $Direct = Join-Path $Resolved "resources\app.asar"
    if (Test-Path $Direct) {
      return (Resolve-Path $Direct).Path
    }

    $Nested = Get-ChildItem -Path $Resolved -Filter "app.asar" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($Nested) {
      return $Nested.FullName
    }
  }

  $processNames = @("OpenCode", "opencode", "opencode-desktop")
  foreach ($name in $processNames) {
    $processes = Get-Process -Name $name -ErrorAction SilentlyContinue
    foreach ($process in $processes) {
      try {
        $exe = $process.MainModule.FileName
        if ($exe) {
          $exeDir = Split-Path $exe -Parent
          $fromExe = Join-Path (Split-Path $exeDir -Parent) "resources\app.asar"
          if (Test-Path $fromExe) {
            return (Resolve-Path $fromExe).Path
          }
          $fromExeDir = Join-Path $exeDir "resources\app.asar"
          if (Test-Path $fromExeDir) {
            return (Resolve-Path $fromExeDir).Path
          }
        }
      } catch {}
    }
  }

  $candidates = @(
    "$env:LOCALAPPDATA\Programs\@opencode-aidesktop\resources\app.asar",
    "$env:LOCALAPPDATA\Programs\OpenCode\resources\app.asar",
    "$env:LOCALAPPDATA\Programs\opencode\resources\app.asar",
    "$env:LOCALAPPDATA\Programs\opencode-desktop\resources\app.asar",
    "$env:ProgramFiles\OpenCode\resources\app.asar",
    "$env:ProgramFiles\opencode\resources\app.asar",
    "$env:ProgramFiles\opencode-desktop\resources\app.asar",
    "${env:ProgramFiles(x86)}\OpenCode\resources\app.asar",
    "${env:ProgramFiles(x86)}\opencode\resources\app.asar",
    "${env:ProgramFiles(x86)}\opencode-desktop\resources\app.asar"
  )

  foreach ($candidate in $candidates) {
    if ($candidate -and (Test-Path $candidate)) {
      return (Resolve-Path $candidate).Path
    }
  }

  $searchRoots = @(
    "$env:LOCALAPPDATA\Programs",
    "$env:LOCALAPPDATA",
    "$env:ProgramFiles",
    "${env:ProgramFiles(x86)}"
  ) | Where-Object { $_ -and (Test-Path $_) }

  foreach ($root in $searchRoots) {
    $match = Get-ChildItem -Path $root -Filter "app.asar" -Recurse -ErrorAction SilentlyContinue |
      Where-Object { $_.FullName -match "(?i)opencode" } |
      Select-Object -First 1
    if ($match) {
      return $match.FullName
    }
  }

  Write-Host ""
  Write-Host "  OpenCode not found automatically." -ForegroundColor Yellow
  Write-Host "  Enter the path to OpenCode app.asar (or the install folder):" -ForegroundColor Yellow
  $UserInput = Read-Host "  Path"

  if (-not $UserInput) {
    throw "No path provided. Aborting."
  }

  $UserInput = $UserInput.Trim('"').Trim("'")

  if (Test-Path $UserInput -PathType Leaf) {
    return (Resolve-Path $UserInput).Path
  }

  $Direct = Join-Path $UserInput "resources\app.asar"
  if (Test-Path $Direct) {
    return (Resolve-Path $Direct).Path
  }

  $Nested = Get-ChildItem -Path $UserInput -Filter "app.asar" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($Nested) {
    return $Nested.FullName
  }

  throw "Could not find app.asar in: $UserInput"
}

$AsarPath = Find-AsarPath $AsarPath
$ResourcesDir = Split-Path $AsarPath -Parent
$Backup = Get-ChildItem $ResourcesDir -Filter "app.asar.backup.*" | Sort-Object Name | Select-Object -First 1

Write-Host ""
Write-Host "  ========================================" -ForegroundColor Magenta
Write-Host "         OpenCode-RTL - Restore" -ForegroundColor Magenta
Write-Host "  ========================================" -ForegroundColor Magenta
Write-Host ""

if (-not $Backup) {
  Write-Host "  Error: " -NoNewline
  Write-Host "No app.asar backup found in $ResourcesDir" -ForegroundColor Red
  throw "No app.asar backup found in $ResourcesDir."
}

Get-Process OpenCode -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

Write-Host "  Restoring " -NoNewline
Write-Host $Backup.FullName -ForegroundColor Yellow
Copy-Item $Backup.FullName $AsarPath -Force
Write-Host ""
Write-Host "  Done. " -NoNewline
Write-Host "Restart OpenCode." -ForegroundColor Green
Write-Host ""
