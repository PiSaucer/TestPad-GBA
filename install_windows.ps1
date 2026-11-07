
# install_windows.ps1
# Copyright (c) 2026 PiSaucer
# Licensed under the MIT License

$ErrorActionPreference = "Stop"

function Info($message) {
    Write-Host $message
}

function Success($message) {
    Write-Host $message -ForegroundColor Green
}

function Fail($message) {
    Write-Host "Error: $message" -ForegroundColor Red
    exit 1
}

# Check Windows
if ($env:OS -ne "Windows_NT") {
    Fail "This script only supports Windows."
}

# Check administrator privileges
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)

if (-not $principal.IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)) {
    Fail "Run PowerShell as Administrator."
}

# Installation paths
$DEVKITPRO = "C:\devkitPro"
$DEVKITARM = Join-Path $DEVKITPRO "devkitARM"
$PACMAN = Join-Path $DEVKITPRO "msys2\usr\bin\pacman.exe"
$BASH = Join-Path $DEVKITPRO "msys2\usr\bin\bash.exe"
$MAKE = Join-Path $DEVKITPRO "msys2\usr\bin\make.exe"
$CYGPATH = Join-Path $DEVKITPRO "msys2\usr\bin\cygpath.exe"
$COMPILER = Join-Path $DEVKITARM "bin\arm-none-eabi-gcc.exe"

$SCRIPT_DIR = $PSScriptRoot
$INSTALLER = Join-Path $SCRIPT_DIR "devkitProUpdater.exe"

# Install devkitPro
if (Test-Path $PACMAN) {
    Success "devkitPro already installed. Skipping installer."
}
else {
    if (Test-Path $INSTALLER) {
        Success "devkitPro installer already downloaded."
    }
    else {
        Info "Downloading devkitPro installer..."

        $release = Invoke-RestMethod `
            -Uri "https://api.github.com/repos/devkitPro/installer/releases/latest"

        $asset = $release.assets |
            Where-Object {
                $_.name -match '\.exe$' -and
                $_.name -notmatch 'uninstall'
            } |
            Select-Object -First 1

        if (-not $asset) {
            Fail "Could not locate the official Windows installer."
        }

        Invoke-WebRequest `
            -Uri $asset.browser_download_url `
            -OutFile $INSTALLER
    }

    Info "Launching devkitPro installer..."
    Info "Select 'GBA Development' in the installer."

    $process = Start-Process `
        -FilePath $INSTALLER `
        -Wait `
        -PassThru

    if ($process.ExitCode -ne 0) {
        Fail "devkitPro installer failed with exit code $($process.ExitCode)."
    }
}

# Verify pacman
if (-not (Test-Path $PACMAN)) {
    Fail "devkitPro pacman not found at $PACMAN."
}

# Install GBA development tools
Info "Installing Game Boy Advance development tools..."

& $PACMAN -S --needed --noconfirm gba-dev

if ($LASTEXITCODE -ne 0) {
    Fail "Failed to install gba-dev."
}

# Verify required tools
foreach ($tool in @($BASH, $MAKE, $CYGPATH, $COMPILER)) {
    if (-not (Test-Path $tool)) {
        Fail "Required tool not found: $tool"
    }
}

Success "devkitARM installation verified."

# Configure persistent environment variables
Info "Configuring environment..."

[Environment]::SetEnvironmentVariable(
    "DEVKITPRO", $DEVKITPRO, "Machine"
)

[Environment]::SetEnvironmentVariable(
    "DEVKITARM", $DEVKITARM, "Machine"
)

$env:DEVKITPRO = $DEVKITPRO
$env:DEVKITARM = $DEVKITARM

Success "DEVKITPRO configured."
Success "DEVKITARM configured."

# Configure compiler PATH
Info "Configuring compiler PATH..."

$compilerPath = Join-Path $DEVKITARM "bin"
$machinePath = [Environment]::GetEnvironmentVariable(
    "Path", "Machine"
)

$pathEntries = @(
    $machinePath -split ';' |
        Where-Object {
            -not [string]::IsNullOrWhiteSpace($_)
        }
)

if ($pathEntries -notcontains $compilerPath) {
    [Environment]::SetEnvironmentVariable(
        "Path",
        (($pathEntries + $compilerPath) -join ';'),
        "Machine"
    )

    Success "devkitARM added to system PATH."
}
else {
    Success "devkitARM already in system PATH."
}

if (($env:Path -split ';') -notcontains $compilerPath) {
    $env:Path += ";$compilerPath"
}

# Configure PowerShell make wrapper
Info "Configuring PowerShell make command..."

# Resolve user's Documents directory
$documents = [Environment]::GetFolderPath(
    [Environment+SpecialFolder]::MyDocuments
)

$profilePaths = @(
    (Join-Path $documents "WindowsPowerShell\Microsoft.PowerShell_profile.ps1"),
    (Join-Path $documents "PowerShell\Microsoft.PowerShell_profile.ps1")
)

$startMarker = "# BEGIN DEVKITPRO GBA"
$endMarker = "# END DEVKITPRO GBA"

# Managed PowerShell configuration
$profileBlock = @'
# BEGIN DEVKITPRO GBA

# devkitPro environment variables
$env:DEVKITPRO = "C:\devkitPro"
$env:DEVKITARM = "C:\devkitPro\devkitARM"

# Run GNU Make through devkitPro MSYS2
function make {
    $bash = "C:\devkitPro\msys2\usr\bin\bash.exe"
    $cygpath = "C:\devkitPro\msys2\usr\bin\cygpath.exe"

    if (-not (Test-Path $bash)) {
        throw "devkitPro MSYS2 Bash not found."
    }

    if (-not (Test-Path $cygpath)) {
        throw "devkitPro cygpath not found."
    }

    # Get current directory
    $workingDirectory = (Get-Location).ProviderPath

    # Convert Windows path to MSYS2 path
    $unixDirectory = (& $cygpath -u $workingDirectory).Trim()

    if ($LASTEXITCODE -ne 0 -or -not $unixDirectory) {
        throw "Failed to convert working directory."
    }

    # Quote arguments for Bash
    $quotedArgs = @(
        foreach ($arg in $args) {
            "'" + ([string]$arg).Replace("'", "'\''") + "'"
        }
    ) -join " "

    # Escape working directory
    $escapedDirectory = "'" +
        $unixDirectory.Replace("'", "'\''") +
        "'"

    # Run make inside MSYS2
    $command = "export DEVKITPRO=/c/devkitPro; " +
        "export DEVKITARM=/c/devkitPro/devkitARM; " +
        "cd $escapedDirectory && /usr/bin/make $quotedArgs"

    & $bash -lc $command
}

# END DEVKITPRO GBA
'@

foreach ($profilePath in $profilePaths) {
    Info "Updating PowerShell profile: $profilePath"

    $directory = Split-Path $profilePath -Parent

    New-Item `
        -ItemType Directory `
        -Path $directory `
        -Force | Out-Null

    $content = if (Test-Path $profilePath) {
        Get-Content $profilePath -Raw
    }
    else {
        ""
    }

    # Back up existing profile before modification
    if (Test-Path $profilePath) {
        $backupPath = "$profilePath.bak"

        Copy-Item `
            -Path $profilePath `
            -Destination $backupPath `
            -Force

        Success "Profile backup created: $backupPath"
    }

    # Remove previously managed devkitPro blocks
    $managedPattern = "(?s)" +
        [regex]::Escape($startMarker) +
        ".*?" +
        [regex]::Escape($endMarker)

    $content = [regex]::Replace(
        $content,
        $managedPattern,
        ""
    )

    # Remove legacy direct make.exe wrapper
    $legacyPattern = '(?ms)^[ \t]*function make\s*\{\s*' +
        '[ \t]*&\s*"C:\\devkitPro\\msys2\\usr\\bin\\make\.exe"' +
        '[ \t]+@args\s*\}'

    $content = [regex]::Replace(
        $content,
        $legacyPattern,
        ""
    )

    # Remove stray MAKE lines from previous configurations
    $content = [regex]::Replace(
        $content,
        '(?im)^[ \t]*MAKE[ \t]*(?:\r?\n|$)',
        ''
    )

    # Append updated managed configuration
    $content = $content.TrimEnd() +
        "`r`n`r`n" +
        $profileBlock +
        "`r`n"

    Set-Content `
        -Path $profilePath `
        -Value $content `
        -Encoding UTF8

    Success "PowerShell profile updated."
}

# Verify GNU Make through MSYS2
Info "Verifying GNU Make..."

& $BASH -lc "/usr/bin/make --version"

if ($LASTEXITCODE -ne 0) {
    Fail "GNU Make verification failed."
}

Success "GNU Make verified."

# Verify PowerShell profile loads the correct wrapper
Info "Verifying PowerShell make configuration..."

& powershell.exe -NoLogo -Command @'
$ErrorActionPreference = "Stop"

$command = Get-Command make -CommandType Function -ErrorAction Stop

if ($command.Definition -notmatch '/usr/bin/make') {
    throw "Incorrect make wrapper loaded."
}

make --version

if ($LASTEXITCODE -ne 0) {
    exit 1
}
'@

if ($LASTEXITCODE -ne 0) {
    Fail "PowerShell make verification failed."
}

Success "PowerShell make configuration verified."

# Configure VS Code settings
$SOURCE = Join-Path $SCRIPT_DIR ".vscode\settings-windows.json"
$DEST = Join-Path $SCRIPT_DIR ".vscode\settings.json"

if (Test-Path $SOURCE) {
    Copy-Item $SOURCE $DEST -Force
    Success "VS Code settings configured."
}
else {
    Write-Warning "VS Code settings-windows.json not found."
}

Success "devkitPro GBA installation complete!"
Info "Close and reopen PowerShell, then run 'make'."
