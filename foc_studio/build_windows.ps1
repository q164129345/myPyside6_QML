$ErrorActionPreference = "Stop"

function Get-PortableImportDlls {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExePath
    )

    $pythonScript = @'
import struct
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = path.read_bytes()

def u16(offset: int) -> int:
    return struct.unpack_from("<H", data, offset)[0]

def u32(offset: int) -> int:
    return struct.unpack_from("<I", data, offset)[0]

pe_offset = u32(0x3C)
if data[pe_offset:pe_offset + 4] != b"PE\0\0":
    raise SystemExit("Unsupported PE file: %s" % path)

file_header = pe_offset + 4
num_sections = u16(file_header + 2)
size_opt = u16(file_header + 16)
opt = file_header + 20
magic = u16(opt)
pe32plus = magic == 0x20B
data_dir = opt + (112 if pe32plus else 96)
import_rva = u32(data_dir + 8)
section_table = opt + size_opt

sections = []
for index in range(num_sections):
    entry = section_table + index * 40
    virtual_size = u32(entry + 8)
    virtual_address = u32(entry + 12)
    size_raw = u32(entry + 16)
    ptr_raw = u32(entry + 20)
    sections.append((virtual_address, max(virtual_size, size_raw), ptr_raw))

def rva_to_offset(rva: int) -> int:
    for virtual_address, span, ptr_raw in sections:
        if virtual_address <= rva < virtual_address + span:
            return ptr_raw + (rva - virtual_address)
    raise ValueError(f"RVA not mapped: {rva:#x}")

if import_rva == 0:
    raise SystemExit(0)

offset = rva_to_offset(import_rva)
while True:
    original_first_thunk = u32(offset)
    time_date_stamp = u32(offset + 4)
    forwarder_chain = u32(offset + 8)
    name_rva = u32(offset + 12)
    first_thunk = u32(offset + 16)
    if (original_first_thunk, time_date_stamp, forwarder_chain, name_rva, first_thunk) == (0, 0, 0, 0, 0):
        break
    name_offset = rva_to_offset(name_rva)
    name_end = data.index(b"\0", name_offset)
    print(data[name_offset:name_end].decode("ascii", "ignore"))
    offset += 20
'@

    $dlls = @($pythonScript | & $pythonRuntime - $ExePath)
    return $dlls | Where-Object { $_ -and $_.Trim() }
}

function Test-ExeImportsDll {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExePath,
        [Parameter(Mandatory = $true)]
        [string]$DllName
    )

    $imports = Get-PortableImportDlls -ExePath $ExePath
    return $imports -icontains $DllName
}

function Move-RootRuntimeArtifactsToRuntime {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AppDir,
        [Parameter(Mandatory = $true)]
        [string]$RuntimeDir
    )

    Get-ChildItem $AppDir -File | Where-Object {
        $_.Extension -in @(".dll", ".pyd")
    } | ForEach-Object {
        Move-Item $_.FullName (Join-Path $RuntimeDir $_.Name) -Force
    }
}

function Assert-ReleaseLayout {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AppDir
    )

    $allowedRootNames = @("foc_studio.exe", "PySide6", "runtime", "shiboken6", "ui")
    $rootItems = Get-ChildItem $AppDir -Force
    $unexpectedItems = $rootItems | Where-Object { $_.Name -notin $allowedRootNames }
    if ($unexpectedItems) {
        $unexpectedNames = ($unexpectedItems | Select-Object -ExpandProperty Name) -join ", "
        throw "Unexpected root-level items in release directory: $unexpectedNames"
    }

    $rootBinaries = Get-ChildItem $AppDir -File | Where-Object {
        $_.Extension -in @(".dll", ".pyd")
    }
    if ($rootBinaries) {
        $binaryNames = ($rootBinaries | Select-Object -ExpandProperty Name) -join ", "
        throw "Root directory still contains runtime binary files: $binaryNames"
    }
}

function Build-WindowsLauncher {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot,
        [Parameter(Mandatory = $true)]
        [string]$IconPath,
        [Parameter(Mandatory = $true)]
        [string]$OutputExe
    )

    $gccPath = (Get-Command gcc -ErrorAction Stop).Source
    $windresPath = (Get-Command windres -ErrorAction Stop).Source
    $launcherSource = Join-Path $ProjectRoot "windows_launcher.c"
    $iconPathForResource = $IconPath -replace "\\", "/"
    $resourceId = [guid]::NewGuid().ToString("N")
    $resourceScriptPath = Join-Path $env:TEMP "foc_studio_launcher_$resourceId.rc"
    $resourceObjectPath = Join-Path $env:TEMP "foc_studio_launcher_$resourceId.o"
    if (-not (Test-Path $launcherSource)) {
        throw "Windows launcher source file was not found: $launcherSource"
    }
    if (-not (Test-Path $IconPath)) {
        throw "Windows launcher icon file was not found: $IconPath"
    }

    try {
        Set-Content -Path $resourceScriptPath -Value "1 ICON `"$iconPathForResource`"" -Encoding ASCII

        & $windresPath `
            $resourceScriptPath `
            -O coff `
            -o $resourceObjectPath | Out-Host
        if ($LASTEXITCODE -ne 0) {
            throw "Building launcher icon resource failed with exit code $LASTEXITCODE"
        }

        & $gccPath `
            $launcherSource `
            $resourceObjectPath `
            -std=c11 `
            -municode `
            -mwindows `
            -Os `
            -s `
            -o $OutputExe | Out-Host
        if ($LASTEXITCODE -ne 0) {
            throw "Building windows launcher failed with exit code $LASTEXITCODE"
        }
    } finally {
        if (Test-Path $resourceScriptPath) {
            Remove-Item $resourceScriptPath -Force
        }
        if (Test-Path $resourceObjectPath) {
            Remove-Item $resourceObjectPath -Force
        }
    }
}

function Copy-RootDirectoriesToRuntime {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AppDir,
        [Parameter(Mandatory = $true)]
        [string]$RuntimeDir
    )

    foreach ($directoryName in @("PySide6", "shiboken6", "ui")) {
        $sourceDir = Join-Path $AppDir $directoryName
        $targetDir = Join-Path $RuntimeDir $directoryName
        if (-not (Test-Path $sourceDir)) {
            throw "Required release directory was not found: $sourceDir"
        }
        if (Test-Path $targetDir) {
            Remove-Item $targetDir -Recurse -Force
        }
        Copy-Item $sourceDir $targetDir -Recurse -Force
    }
}

function Invoke-NuitkaBuild {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PythonRuntime,
        [Parameter(Mandatory = $true)]
        [string]$OutputDir,
        [Parameter(Mandatory = $true)]
        [string]$IconPath,
        [Parameter(Mandatory = $true)]
        [string]$StaticLibPython
    )

    & $PythonRuntime -m nuitka `
        main.py `
        --follow-imports `
        --enable-plugin=pyside6 `
        --output-dir=$OutputDir `
        --noinclude-qt-translations `
        --static-libpython=$StaticLibPython `
        --mingw64 `
        --assume-yes-for-downloads `
        --windows-console-mode=disable `
        --standalone `
        --remove-output `
        --disable-cache=ccache `
        --include-qt-plugins=platforminputcontexts,qmllint,qmltooling `
        --windows-icon-from-ico=$IconPath | Out-Host

    return [int]$LASTEXITCODE
}

$pythonExe = (Get-Command python -ErrorAction Stop).Source
$pythonRuntime = (& $pythonExe -c "import sys; print(sys.executable)").Trim()
$pysideDir = (& $pythonRuntime -c "from pathlib import Path; import PySide6; print(Path(PySide6.__file__).resolve().parent)").Trim()

try {
    & $pythonRuntime -c "import PySide6" | Out-Null
} catch {
    throw "PySide6 is not installed in the active Python environment: $pythonRuntime"
}

try {
    & $pythonRuntime -m nuitka --version | Out-Null
} catch {
    throw "Nuitka is not installed in the active Python environment: $pythonRuntime"
}

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$outputDir = Join-Path $projectRoot "deployment"
$rawDistDir = Join-Path $outputDir "main.dist"
$rawBuildDir = Join-Path $outputDir "main.build"
$appDir = Join-Path $outputDir "foc_studio"
$runtimeDir = Join-Path $appDir "runtime"
$sourceUiDir = Join-Path $projectRoot "ui"
$targetUiDir = Join-Path $appDir "ui"
$sourceQtQmlDir = Join-Path $pysideDir "qml"
$targetQtQmlDir = Join-Path $appDir "PySide6\qml"
$iconPath = Join-Path $projectRoot "ui\assets\app.ico"
$rootExePath = Join-Path $appDir "foc_studio.exe"
$runtimeExePath = Join-Path $runtimeDir "foc_studio-runtime.exe"

Write-Host "Using Python: $pythonRuntime"
Write-Host "Building Windows standalone package with Nuitka..."

if (-not (Test-Path $iconPath)) {
    throw "Application icon file was not found: $iconPath"
}

Push-Location $projectRoot
try {
    if (Test-Path $rawDistDir) {
        Remove-Item $rawDistDir -Recurse -Force
    }
    if (Test-Path $rawBuildDir) {
        Remove-Item $rawBuildDir -Recurse -Force
    }
    if (Test-Path $appDir) {
        Remove-Item $appDir -Recurse -Force
    }

    $buildExitCode = Invoke-NuitkaBuild `
        -PythonRuntime $pythonRuntime `
        -OutputDir $outputDir `
        -IconPath $iconPath `
        -StaticLibPython "yes"
    if ($buildExitCode -ne 0) {
        Write-Host "Static libpython build is not available in this environment. Retrying with dynamic libpython..."
        $buildExitCode = Invoke-NuitkaBuild `
            -PythonRuntime $pythonRuntime `
            -OutputDir $outputDir `
            -IconPath $iconPath `
            -StaticLibPython "no"
    }
    if ($buildExitCode -ne 0) {
        throw "Nuitka build failed with exit code $buildExitCode"
    }
} finally {
    Pop-Location
}

if (-not (Test-Path $rawDistDir)) {
    throw "Build finished but the expected distribution folder was not found: $rawDistDir"
}

Move-Item $rawDistDir $appDir

$generatedExe = Join-Path $appDir "main.exe"
if (Test-Path $generatedExe) {
    Rename-Item $generatedExe "foc_studio.exe"
}

if (-not (Test-Path $rootExePath)) {
    throw "Build finished but foc_studio.exe was not found under $appDir"
}

if (-not (Test-Path $runtimeDir)) {
    New-Item -ItemType Directory -Path $runtimeDir | Out-Null
}

if (Test-Path $targetUiDir) {
    Remove-Item $targetUiDir -Recurse -Force
}
Copy-Item $sourceUiDir $targetUiDir -Recurse -Force

if (Test-Path $targetQtQmlDir) {
    Remove-Item $targetQtQmlDir -Recurse -Force
}
Copy-Item $sourceQtQmlDir $targetQtQmlDir -Recurse -Force

Move-RootRuntimeArtifactsToRuntime -AppDir $appDir -RuntimeDir $runtimeDir

Get-ChildItem $pysideDir -Filter "Qt6*.dll" -File | ForEach-Object {
    Copy-Item $_.FullName $runtimeDir -Force
}

$softwareRenderer = Join-Path $pysideDir "opengl32sw.dll"
if (Test-Path $softwareRenderer) {
    Copy-Item $softwareRenderer $runtimeDir -Force
}

$importsPythonDll = Test-ExeImportsDll -ExePath $rootExePath -DllName "python310.dll"
$rootPythonDlls = @(Get-ChildItem $appDir -Filter "python*.dll" -File -ErrorAction SilentlyContinue)

if ($importsPythonDll -or $rootPythonDlls.Count -gt 0) {
    Write-Host "Static libpython validation failed. Falling back to launcher layout..."

    if (Test-Path $runtimeExePath) {
        Remove-Item $runtimeExePath -Force
    }
    Move-Item $rootExePath $runtimeExePath -Force
    Copy-RootDirectoriesToRuntime -AppDir $appDir -RuntimeDir $runtimeDir
    Build-WindowsLauncher -ProjectRoot $projectRoot -IconPath $iconPath -OutputExe $rootExePath
}

Assert-ReleaseLayout -AppDir $appDir

$finalRootImports = Get-PortableImportDlls -ExePath $rootExePath
$rootImportSummary = ($finalRootImports -join ", ")
Write-Host "Root executable imports: $rootImportSummary"

if (Test-Path $rawBuildDir) {
    Remove-Item $rawBuildDir -Recurse -Force
}

Write-Host "Build completed."
Write-Host "Deliver this directory to other Windows users:"
Write-Host $appDir
