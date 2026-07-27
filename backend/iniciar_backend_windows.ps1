Set-Location $PSScriptRoot

if (-not (Test-Path ".\.venv\Scripts\Activate.ps1")) {
    Write-Host "No se encontró el entorno virtual .venv." -ForegroundColor Red
    Write-Host "Ejecuta primero: py -m venv .venv"
    exit 1
}

Set-ExecutionPolicy `
    -Scope Process `
    -ExecutionPolicy Bypass `
    -Force

.\.venv\Scripts\Activate.ps1

python -m uvicorn `
    app.main:app `
    --loop app.core.selector_event_loop:crear_event_loop `
    --host 127.0.0.1 `
    --port 8000