$ErrorActionPreference = "Stop"

$pythonExe = (Get-Command python -ErrorAction Stop).Source
$pythonRuntime = (& $pythonExe -c "import sys; print(sys.executable)").Trim()
$pysideDir = (& $pythonRuntime -c "from pathlib import Path; import PySide6; print(Path(PySide6.__file__).resolve().parent)").Trim()

try {
    & $pythonExe -c "import PySide6" | Out-Null
} catch {
    throw "PySide6 is not installed in the active Python environment: $pythonExe"
}

if (-not (Get-Command pyside6-deploy -ErrorAction SilentlyContinue)) {
    throw "pyside6-deploy was not found in PATH."
}

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$specFile = Join-Path $projectRoot "pysidedeploy.spec"
$outputDir = Join-Path $projectRoot "deployment"
$rawAppDir = Join-Path $outputDir "foc_studio.dist"
$rawNuitkaDir = Join-Path $outputDir "main.dist"
$appDir = Join-Path $outputDir "foc_studio"
$sourceUiDir = Join-Path $projectRoot "ui"
$targetUiDir = Join-Path $appDir "ui"
$sourceQtQmlDir = Join-Path $pysideDir "qml"
$targetQtQmlDir = Join-Path $appDir "PySide6\\qml"

function Invoke-NuitkaFallback {
    Write-Host "pyside6-deploy did not leave a usable output directory. Falling back to direct Nuitka build..."

    & $pythonRuntime -m nuitka `
        main.py `
        --follow-imports `
        --enable-plugin=pyside6 `
        --output-dir=deployment `
        --noinclude-qt-translations `
        --static-libpython=no `
        --mingw64 `
        --assume-yes-for-downloads `
        --windows-console-mode=disable `
        --standalone `
        --include-qt-plugins=platforminputcontexts,qmllint,qmltooling
}

Write-Host "Using Python: $pythonRuntime"
Write-Host "Building Windows standalone package..."

Push-Location $projectRoot
try {
    & pyside6-deploy `
        -c $specFile `
        --extra-ignore-dirs ".agents,.vscode,deployment,dist,__pycache__" `
        -f
} finally {
    Pop-Location
}

if (-not (Test-Path $rawAppDir) -and -not (Test-Path $rawNuitkaDir)) {
    Push-Location $projectRoot
    try {
        Invoke-NuitkaFallback
    } finally {
        Pop-Location
    }
}

if (-not (Test-Path $rawAppDir) -and (Test-Path $rawNuitkaDir)) {
    $rawAppDir = $rawNuitkaDir
}

if (-not (Test-Path $rawAppDir)) {
    throw "Build finished but no deployment folder was found under $outputDir"
}

if (Test-Path $appDir) {
    Remove-Item $appDir -Recurse -Force
}
Move-Item $rawAppDir $appDir

$generatedExe = Join-Path $appDir "main.exe"
$finalExe = Join-Path $appDir "foc_studio.exe"
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

if (-not (Test-Path (Join-Path $appDir "foc_studio.exe"))) {
    throw "Build finished but foc_studio.exe was not found under $appDir"
}

Write-Host "Build completed."
Write-Host "Deliver this directory to other Windows users:"
Write-Host $appDir
