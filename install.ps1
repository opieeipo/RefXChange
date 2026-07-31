<#
.SYNOPSIS
    Install RefXChange on Windows.

.DESCRIPTION
    RefXChange is a Bash program, so Windows needs a bash: Git for Windows
    (Git Bash) or WSL. This script finds one, copies the program under
    %LOCALAPPDATA%\Programs\RefXChange, drops a refxchange.cmd shim in its bin
    directory, and adds that directory to your user PATH.

.EXAMPLE
    .\install.ps1
    .\install.ps1 -Prefix D:\Tools\RefXChange
    .\install.ps1 -Uninstall
#>
[CmdletBinding()]
param(
    [string]$Prefix = (Join-Path $env:LOCALAPPDATA 'Programs\RefXChange'),
    [switch]$Uninstall,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$SrcDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$BinDir  = Join-Path $Prefix 'bin'
$DataDir = Join-Path $Prefix 'share\refxchange'
$Shim    = Join-Path $BinDir 'refxchange.cmd'

function Find-Bash {
    $candidates = @(
        (Get-Command bash.exe -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Source),
        "$env:ProgramFiles\Git\bin\bash.exe",
        "${env:ProgramFiles(x86)}\Git\bin\bash.exe",
        "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe"
    )
    foreach ($c in $candidates) {
        if ($c -and (Test-Path $c)) { return $c }
    }
    return $null
}

function Remove-FromUserPath([string]$dir) {
    $current = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (-not $current) { return }
    $kept = ($current -split ';' | Where-Object { $_ -and $_.TrimEnd('\') -ne $dir.TrimEnd('\') }) -join ';'
    [Environment]::SetEnvironmentVariable('Path', $kept, 'User')
}

function Add-ToUserPath([string]$dir) {
    $current = [Environment]::GetEnvironmentVariable('Path', 'User')
    $entries = @()
    if ($current) { $entries = $current -split ';' | Where-Object { $_ } }
    if ($entries | Where-Object { $_.TrimEnd('\') -eq $dir.TrimEnd('\') }) {
        Write-Host "$dir is already on your user PATH."
        return
    }
    [Environment]::SetEnvironmentVariable('Path', (($entries + $dir) -join ';'), 'User')
    Write-Host "Added $dir to your user PATH (open a new terminal to pick it up)."
}

if ($Uninstall) {
    $removed = $false
    if (Test-Path $Prefix) {
        Remove-Item -Recurse -Force $Prefix
        Write-Host "Removed $Prefix"
        $removed = $true
    }
    Remove-FromUserPath $BinDir
    if (-not $removed) { Write-Host "Nothing to uninstall at $Prefix" }
    exit 0
}

$bash = Find-Bash
if (-not $bash) {
    Write-Error @'
No bash found. Install Git for Windows (https://git-scm.com/download/win)
or enable WSL, then re-run this script.
'@
    exit 3
}
Write-Host "Using bash: $bash"

if ((Test-Path $Shim) -and -not $Force) {
    Write-Host "RefXChange is already installed at $Prefix - reinstalling."
}

New-Item -ItemType Directory -Force -Path $BinDir, $DataDir, (Join-Path $DataDir 'lib') | Out-Null

Copy-Item (Join-Path $SrcDir 'refxchange.sh') $DataDir -Force
Copy-Item (Join-Path $SrcDir 'lib\*.sh') (Join-Path $DataDir 'lib') -Force

# Message catalogs. msgfmt ships with Git for Windows in some builds only, so
# compiling is best-effort; without it the CLI falls back to English.
$locales = Join-Path $SrcDir 'locale'
if (Test-Path $locales) {
    Copy-Item $locales (Join-Path $DataDir 'locale') -Recurse -Force
    $msgfmt = Get-Command msgfmt.exe -ErrorAction SilentlyContinue
    if ($msgfmt) {
        Get-ChildItem (Join-Path $DataDir 'locale') -Recurse -Filter 'refxchange.po' | ForEach-Object {
            & $msgfmt.Source -o (Join-Path $_.DirectoryName 'refxchange.mo') $_.FullName
        }
    } else {
        Write-Host "Note: msgfmt not found - messages stay in English."
    }
}

# The shim hands the installed script to bash. Forward slashes keep both Git
# Bash and WSL happy with the path.
$scriptPath = (Join-Path $DataDir 'refxchange.sh') -replace '\\', '/'
@"
@echo off
"$bash" "$scriptPath" %*
"@ | Set-Content -Path $Shim -Encoding ASCII

Write-Host "Installed $Shim"
Write-Host "          $DataDir"
Add-ToUserPath $BinDir
Write-Host ""
Write-Host "Verify with: refxchange --version"
