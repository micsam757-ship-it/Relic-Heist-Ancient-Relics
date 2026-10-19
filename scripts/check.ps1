#requires -Version 5.1
<#
.SYNOPSIS
    Runs the full local validation suite for Relic Heist: Ancient Relics.

.DESCRIPTION
    Builds the Rojo project, checks formatting, lints, runs the pure-logic test
    suite, and type-checks the pure modules. Exits non-zero if any check fails.

    Tools are resolved from PATH first, then from the Aftman bin directory
    (%USERPROFILE%\.aftman\bin), then from an optional directory named by the
    RELIC_HEIST_TOOLS environment variable. Run `aftman install` once to
    provision them.

.EXAMPLE
    pwsh scripts/check.ps1
#>
[CmdletBinding()]
param(
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Push-Location $root
$failures = @()

function Resolve-Tool {
    param([Parameter(Mandatory)][string]$Name)
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $aftman = Join-Path $env:USERPROFILE ".aftman\bin\$Name.exe"
    if (Test-Path -LiteralPath $aftman) { return $aftman }
    if ($env:RELIC_HEIST_TOOLS) {
        $candidates = @(
            (Join-Path $env:RELIC_HEIST_TOOLS "$Name.exe"),
            (Join-Path $env:RELIC_HEIST_TOOLS "$Name\$Name.exe"),
            (Join-Path (Join-Path $env:RELIC_HEIST_TOOLS "luau") "$Name.exe")
        )
        foreach ($candidate in $candidates) {
            if (Test-Path -LiteralPath $candidate) { return $candidate }
        }
    }
    throw "Tool '$Name' not found on PATH, in $env:USERPROFILE\.aftman\bin, or under RELIC_HEIST_TOOLS. Run 'aftman install'."
}

function Invoke-Check {
    param(
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][scriptblock]$Action
    )
    Write-Host "==> $Label" -ForegroundColor Cyan
    try {
        & $Action
        if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) {
            throw "$Label failed (exit $LASTEXITCODE)"
        }
        Write-Host "    OK" -ForegroundColor Green
    } catch {
        Write-Host "    FAILED: $_" -ForegroundColor Red
        $script:failures += $Label
    }
}

try {
    $stylua = Resolve-Tool stylua
    $selene = Resolve-Tool selene
    $luau = Resolve-Tool luau
    $luauAnalyze = Resolve-Tool luau-analyze
    $rojo = Resolve-Tool rojo

    if (-not $SkipBuild) {
        $out = Join-Path ([System.IO.Path]::GetTempPath()) "RelicHeist-ci.rbxlx"
        Invoke-Check "rojo build" { & $rojo build default.project.json -o $out }
    }

    Invoke-Check "stylua --check ." { & $stylua --check . }
    Invoke-Check "selene src tests" { & $selene src tests }
    Invoke-Check "luau tests/run_tests.luau" { & $luau tests/run_tests.luau }
    Invoke-Check "luau-analyze src/shared" { & $luauAnalyze src/shared/Domain src/shared/Config }
} finally {
    Pop-Location
}

if ($failures.Count -gt 0) {
    Write-Host ""
    Write-Host "$($failures.Count) check(s) failed: $($failures -join ', ')" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "All checks passed." -ForegroundColor Green
exit 0
