$ErrorActionPreference = "Stop"
$Raiz = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "=== VERIFICACIÓN SCORELY ===" -ForegroundColor Cyan

$Requeridos = @(
    "backend",
    "frontend",
    "database\export\sistema_torneos_db_completa.sql",
    "backend\app\main.py",
    "frontend\package.json"
)

foreach ($Ruta in $Requeridos) {
    $Completa = Join-Path $Raiz $Ruta
    if (-not (Test-Path $Completa)) {
        throw "Falta: $Ruta"
    }
}

Write-Host "Estructura del proyecto: OK" -ForegroundColor Green

$Python = Get-Command python -ErrorAction SilentlyContinue
if (-not $Python) {
    $Python = Get-Command py -ErrorAction SilentlyContinue
}
if (-not $Python) {
    throw "No se encontró Python."
}

Push-Location (Join-Path $Raiz "backend")
try {
    & $Python.Source -m compileall -q app
    if ($LASTEXITCODE -ne 0) {
        throw "La comprobación sintáctica de Python falló."
    }
    Write-Host "Sintaxis del backend: OK" -ForegroundColor Green
} finally {
    Pop-Location
}

$Node = Get-Command node -ErrorAction SilentlyContinue
$Npm = Get-Command npm -ErrorAction SilentlyContinue
if (-not $Node -or -not $Npm) {
    throw "No se encontraron Node.js y npm."
}

Push-Location (Join-Path $Raiz "frontend")
try {
    if (-not (Test-Path "node_modules")) {
        Write-Host "Instalando dependencias del frontend..." -ForegroundColor Yellow
        npm install
        if ($LASTEXITCODE -ne 0) {
            throw "npm install falló."
        }
    }

    npm run build
    if ($LASTEXITCODE -ne 0) {
        throw "La compilación del frontend falló."
    }
    Write-Host "Build del frontend: OK" -ForegroundColor Green
} finally {
    Pop-Location
}

Write-Host "" 
Write-Host "Verificación local completada." -ForegroundColor Green
Write-Host "Continúa con LISTA_VERIFICACION_PRESENTACION.md para las pruebas con PostgreSQL y los roles."
