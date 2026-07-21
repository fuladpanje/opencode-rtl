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
$BackupPath = Join-Path $ResourcesDir ("app.asar.backup.{0}" -f (Get-Date -Format "yyyyMMdd-HHmmss"))

Write-Host ""
Write-Host "  ========================================" -ForegroundColor Cyan
Write-Host "         OpenCode-RTL v2.0.0" -ForegroundColor Cyan
Write-Host "  ========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Author : " -NoNewline
Write-Host "Reza Fuladpanjeh" -ForegroundColor Yellow -NoNewline
Write-Host " (fuladpanjeh.ir)"
Write-Host "  Target : " -NoNewline
Write-Host $AsarPath -ForegroundColor DarkGray
Write-Host ""

Write-Host "  [1/3] " -NoNewline
Write-Host "Stopping OpenCode..." -ForegroundColor White -NoNewline
Get-Process OpenCode -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Write-Host " done" -ForegroundColor Green

Write-Host "  [2/3] " -NoNewline
Write-Host "Patching asar directly..." -ForegroundColor White -NoNewline
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PatchScript = Join-Path $ScriptDir "asar-patch.js"
node $PatchScript $AsarPath
Write-Host " done" -ForegroundColor Green

Write-Host "  [3/3] " -NoNewline
Write-Host "Finished!" -ForegroundColor Green
Write-Host ""
Write-Host "  Restart OpenCode to use RTL support." -ForegroundColor Cyan
Write-Host ""
