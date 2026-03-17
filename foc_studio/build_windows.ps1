$ErrorActionPreference = "Stop"

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
$sourceUiDir = Join-Path $projectRoot "ui"
$targetUiDir = Join-Path $appDir "ui"
$sourceQtQmlDir = Join-Path $pysideDir "qml"
$targetQtQmlDir = Join-Path $appDir "PySide6\qml"
$iconPath = Join-Path $projectRoot "ui\assets\app.ico"

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

    & $pythonRuntime -m nuitka `
        main.py `
        --follow-imports `
        --enable-plugin=pyside6 `
        --output-dir=$outputDir `
        --noinclude-qt-translations `
        --static-libpython=no `
        --mingw64 `
        --assume-yes-for-downloads `
        --windows-console-mode=disable `
        --standalone `
        --remove-output `
        --disable-cache=ccache `
        --include-qt-plugins=platforminputcontexts,qmllint,qmltooling `
        --windows-icon-from-ico=$iconPath
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

if (Test-Path $targetUiDir) {
    Remove-Item $targetUiDir -Recurse -Force
}
Copy-Item $sourceUiDir $targetUiDir -Recurse -Force

if (Test-Path $targetQtQmlDir) {
    Remove-Item $targetQtQmlDir -Recurse -Force
}
Copy-Item $sourceQtQmlDir $targetQtQmlDir -Recurse -Force

Get-ChildItem $pysideDir -Filter "Qt6*.dll" -File | ForEach-Object {
    Copy-Item $_.FullName $appDir -Force
}

$softwareRenderer = Join-Path $pysideDir "opengl32sw.dll"
if (Test-Path $softwareRenderer) {
    Copy-Item $softwareRenderer $appDir -Force
}

if (Test-Path $rawBuildDir) {
    Remove-Item $rawBuildDir -Recurse -Force
}

if (-not (Test-Path (Join-Path $appDir "foc_studio.exe"))) {
    throw "Build finished but foc_studio.exe was not found under $appDir"
}

Write-Host "Build completed."
Write-Host "Deliver this directory to other Windows users:"
Write-Host $appDir
