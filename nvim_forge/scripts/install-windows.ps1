#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$RepoUrl = "https://github.com/cascad/forge-nvim.git",
    [string]$Branch = "main",
    [string]$InstallPath = (Join-Path $env:LOCALAPPDATA "nvim"),
    [switch]$SkipDependencies,
    [switch]$WithLanguages,
    [switch]$UseLocalSource,
    [switch]$NoBackup
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'lib\install-profile.ps1')
if ($env:FORGE_NVIM_COMPONENTS) {
    $env:FORGE_NVIM_COMPONENTS = Resolve-ForgeProfile -Components $env:FORGE_NVIM_COMPONENTS -Explicit $true
}

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Info {
    param([string]$Message)
    Write-Host "    $Message" -ForegroundColor DarkGray
}

function Test-Command {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Update-CurrentPath {
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    # Сохранить явно заданный process SDK/PATH и добавить новые системные пути.
    $paths = (($env:Path, $machinePath, $userPath) -join ';').Split(';') |
        Where-Object { $_ } | Select-Object -Unique
    $env:Path = $paths -join ';'

    $treeSitter = Get-ChildItem `
        -Path (Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages") `
        -Recurse `
        -Filter "tree-sitter.exe" `
        -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if ($treeSitter) {
        $env:Path = "$($treeSitter.DirectoryName);$env:Path"
    }
}

function Install-WingetPackage {
    param(
        [string]$Id,
        [string]$Name
    )

    if (-not (Test-Command "winget")) {
        if ($env:FORGE_NVIM_COMPONENTS) { throw 'winget is required for the selected component profile; package-manager bootstrap is not ready.' }
        Write-Warning "winget is not available; install $Name manually ($Id)."
        return
    }

    $installed = $false
    try {
        winget list --id $Id -e | Out-Null
        $installed = ($LASTEXITCODE -eq 0)
    } catch {
        $installed = $false
    }

    if ($installed) {
        Write-Info "$Name already installed"
        return
    }

    Write-Step "Installing $Name"
    winget install --id $Id -e --silent --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) { throw "Package install failed: $Id (exit $LASTEXITCODE)." }
}

function Install-Dependencies {
    if ($SkipDependencies) {
        Write-Info "Skipping dependency install"
        Update-CurrentPath
        return
    }

    Write-Step "Installing base dependencies"
    Install-WingetPackage -Id "Git.Git" -Name "Git"
    Install-WingetPackage -Id "Neovim.Neovim" -Name "Neovim"
    Install-WingetPackage -Id "BurntSushi.ripgrep.MSVC" -Name "ripgrep"
    Install-WingetPackage -Id "sharkdp.fd" -Name "fd"
    Install-WingetPackage -Id "Kitware.CMake" -Name "CMake"
    Install-WingetPackage -Id "LLVM.LLVM" -Name "LLVM"
    Install-WingetPackage -Id "tree-sitter.tree-sitter-cli" -Name "tree-sitter CLI"

    if (Test-ForgeComponent 'rust') {
        Install-WingetPackage -Id "Rustlang.Rustup" -Name "rustup"
    }
    if (Test-ForgeComponent 'go-runtime') {
        Install-WingetPackage -Id "GoLang.Go" -Name "Go"
    }
    if (Test-ForgeComponent 'python') {
        Install-WingetPackage -Id "Python.Python.3.12" -Name "Python"
    }
    if (Test-ForgeComponent 'node-runtime') { Install-WingetPackage -Id 'OpenJS.NodeJS.LTS' -Name 'Node.js LTS' }
    if (Test-ForgeComponent 'sql') { Install-WingetPackage -Id 'SQLite.SQLite' -Name 'SQLite' }
    if ($env:FORGE_NVIM_COMPONENTS -and (Test-ForgeComponent 'terminal')) { Install-WingetPackage -Id 'wez.wezterm' -Name 'WezTerm' }

    Update-CurrentPath
}

function Get-FullPath {
    param([string]$Path)
    return [System.IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
}

function Test-SamePath {
    param(
        [string]$Left,
        [string]$Right
    )
    return ((Get-FullPath $Left).ToLowerInvariant() -eq (Get-FullPath $Right).ToLowerInvariant())
}

function Backup-Path {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    if ($NoBackup) {
        throw "Install path already exists: $Path. Remove it manually or run without -NoBackup to create a backup."
    }

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backup = "$Path.backup-$timestamp"
    Write-Step "Backing up existing config"
    Write-Info "$Path -> $backup"
    Move-Item -LiteralPath $Path -Destination $backup
}

function Copy-LocalRepo {
    param(
        [string]$Source,
        [string]$Destination
    )

    Write-Step "Copying local checkout"
    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    Get-ChildItem -LiteralPath $Source -Force |
        Where-Object { $_.Name -notin @(".git", "nvim.log") } |
        Copy-Item -Destination $Destination -Recurse -Force
}

function Install-Config {
    $scriptRoot = $PSScriptRoot
    if (-not $scriptRoot -and $MyInvocation.MyCommand.Path) {
        $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
    }
    $localRepoRoot = if ($scriptRoot) { Split-Path -Parent $scriptRoot } else { "" }
    $runningFromRepo = $localRepoRoot -and
                       (Test-Path -LiteralPath (Join-Path $localRepoRoot "init.lua")) -and
                       (Test-Path -LiteralPath (Join-Path $localRepoRoot "lua"))

    Write-Step "Installing forge-nvim"
    Write-Info "Target: $InstallPath"

    if ($localRepoRoot -and (Test-Path -LiteralPath $InstallPath) -and (Test-SamePath $InstallPath $localRepoRoot)) {
        Write-Info "Already running from the target config directory"
        return
    }

    if (Test-Path -LiteralPath (Join-Path $InstallPath ".git")) {
        $remote = ""
        try {
            $remote = (& git -C $InstallPath config --get remote.origin.url).Trim()
        } catch {
            $remote = ""
        }

        if ($remote -eq $RepoUrl -or $remote -like "*forge-nvim*") {
            Write-Step "Updating existing checkout"
            git -C $InstallPath fetch origin $Branch
            git -C $InstallPath checkout $Branch
            git -C $InstallPath pull --ff-only origin $Branch
            return
        }
    }

    Backup-Path -Path $InstallPath
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $InstallPath) | Out-Null

    if ($UseLocalSource) {
        if (-not $runningFromRepo) {
            throw "-UseLocalSource was requested, but this script is not running from a forge-nvim checkout."
        }
        Copy-LocalRepo -Source $localRepoRoot -Destination $InstallPath
        return
    }

    if (-not (Test-Command "git")) {
        if ($runningFromRepo) {
            Copy-LocalRepo -Source $localRepoRoot -Destination $InstallPath
            return
        }
        throw "git is required to clone $RepoUrl."
    }

    Write-Step "Cloning $RepoUrl"
    git clone --branch $Branch $RepoUrl $InstallPath
}

function Sync-Neovim {
    if (-not (Test-Command "nvim")) {
        throw "nvim is not available in PATH. Restart the terminal or install Neovim manually."
    }

    $installed = [IO.Path]::GetFullPath($InstallPath)
    $stageScript = Join-Path $installed 'scripts\setup-stage.lua'
    if (-not (Test-Path -LiteralPath $stageScript -PathType Leaf)) { throw "Installed setup stage not found: $stageScript" }
    $oldConfig = $env:XDG_CONFIG_HOME
    $oldApp = $env:NVIM_APPNAME
    try {
        $env:XDG_CONFIG_HOME = Split-Path -Parent $installed
        $env:NVIM_APPNAME = Split-Path -Leaf $installed
        foreach ($stage in @('plugins', 'parsers', 'tools')) {
            Write-Step "Preparing $stage"
            nvim --headless -i NONE -u (Join-Path $installed 'init.lua') -l $stageScript $stage
            if ($LASTEXITCODE -ne 0) { throw "Setup stage $stage failed (exit $LASTEXITCODE)." }
        }
    } finally {
        $env:XDG_CONFIG_HOME = $oldConfig
        $env:NVIM_APPNAME = $oldApp
    }
}

Install-Dependencies
Install-Config
Sync-Neovim

Write-Host ""
Write-Host "forge-nvim installed: $InstallPath" -ForegroundColor Green
Write-Host "Start with: nvim"
