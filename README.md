# SCORELY
## Sistema Web de Gestión de Torneos Deportivos

Scorely es un sistema web universitario orientado a la organización y control de torneos deportivos por equipos. La aplicación centraliza usuarios, deportes, equipos, jugadores, torneos, inscripciones, pagos, partidos, resultados, reportes y auditoría.

## Arquitectura

La comunicación del sistema sigue esta estructura:

React + Vite -> FastAPI -> PostgreSQL

- Frontend: React, Vite y JavaScript.
- Backend: FastAPI y Python.
- Base de datos: PostgreSQL.
- Autenticación: JWT.
- Documentación de la API: Swagger.

React nunca se conecta directamente a PostgreSQL. Todas las operaciones pasan primero por FastAPI.

---

# 1. REQUISITOS

Se recomienda utilizar Windows 10 u 11 con los siguientes programas:

- Git.
- PostgreSQL 18.
- Python 3.13 o 3.14.
- Node.js 20 o superior.
- npm.
- Visual Studio Code.

Comprobar las instalaciones:

```powershell
git --version
py --version
node --version
npm --version
```

Comprobar que PostgreSQL está iniciado:

```powershell
Get-Service *postgres*
```

El estado debe aparecer como:

```text
Running
```

---

# 2. DESCARGAR EL PROYECTO

Abrir PowerShell en la carpeta donde se desea guardar el proyecto y ejecutar:

```powershell
git clone https://github.com/alejandroyujra8/ScorelyPrueba.git
cd ScorelyPrueba
```

La estructura principal esperada es:

```text
ScorelyPrueba/
├── backend/
├── database/
├── docs/
├── frontend/
├── scripts/
├── .gitignore
└── README.md
```

No se deben subir ni compartir estas carpetas o archivos:

```text
backend/.venv/
frontend/node_modules/
frontend/dist/
backend/.env
frontend/.env
```

Cada persona debe crear sus propios archivos `.env` porque contienen configuraciones locales y la contraseña de PostgreSQL.

---

# 3. CREAR UNA BASE DE DATOS NUEVA

Para evitar conflictos con versiones anteriores, se recomienda crear una base nueva llamada:

```text
sistema_torneos_db_final
```

No es necesario eliminar la base antigua.

## 3.1 Crear la base desde PowerShell

Desde la raíz del proyecto:

```powershell
$PG_BIN = "C:\Program Files\PostgreSQL\18\bin"
```

Crear la base:

```powershell
& "$PG_BIN\createdb.exe" `
  -U postgres `
  -h localhost `
  -p 5432 `
  sistema_torneos_db_final
```

PostgreSQL solicitará la contraseña del usuario `postgres`.

## 3.2 Importar toda la base de datos

Ejecutar desde la raíz del proyecto:

```powershell
& "$PG_BIN\psql.exe" `
  -U postgres `
  -h localhost `
  -p 5432 `
  -d sistema_torneos_db_final `
  -W `
  -v ON_ERROR_STOP=1 `
  -f ".\database\export\sistema_torneos_db_completa.sql"
```

La importación puede mostrar muchos mensajes como:

```text
CREATE TABLE
ALTER TABLE
CREATE FUNCTION
CREATE TRIGGER
INSERT
```

Eso es normal.

La importación termina correctamente cuando PowerShell vuelve a mostrar el prompt y no aparece un error que detenga el proceso.

## 3.3 Crear la base con pgAdmin 4

También se puede realizar desde pgAdmin:

1. Abrir pgAdmin 4.
2. Conectarse al servidor PostgreSQL local.
3. Hacer clic derecho en `Databases`.
4. Seleccionar `Create > Database`.
5. Escribir `sistema_torneos_db_final`.
6. Guardar.
7. Abrir Query Tool sobre la nueva base.
8. Abrir el archivo:

```text
database/export/sistema_torneos_db_completa.sql
```

9. Ejecutar todo el script.

## 3.4 Reiniciar la base de prueba

Solo cuando se quiera borrar y reconstruir la base de prueba:

```powershell
$PG_BIN = "C:\Program Files\PostgreSQL\18\bin"

& "$PG_BIN\dropdb.exe" `
  -U postgres `
  -h localhost `
  -p 5432 `
  --if-exists `
  sistema_torneos_db_final

& "$PG_BIN\createdb.exe" `
  -U postgres `
  -h localhost `
  -p 5432 `
  sistema_torneos_db_final

& "$PG_BIN\psql.exe" `
  -U postgres `
  -h localhost `
  -p 5432 `
  -d sistema_torneos_db_final `
  -W `
  -v ON_ERROR_STOP=1 `
  -f ".\database\export\sistema_torneos_db_completa.sql"
```

---

# 4. CONFIGURAR Y EJECUTAR EL BACKEND

## 4.1 Entrar al backend

```powershell
cd backend
```

## 4.2 Crear el entorno virtual

```powershell
py -m venv .venv
```

## 4.3 Activar el entorno virtual

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\.venv\Scripts\Activate.ps1
```

La terminal debe comenzar con:

```text
(.venv)
```

## 4.4 Instalar dependencias

```powershell
python -m pip install -r requirements.txt
```

En Windows, el archivo `backend/requirements.txt` debe contener esta línea:

```text
uvloop==0.22.1; sys_platform != "win32"
```

No debe contener solamente:

```text
uvloop==0.22.1
```

`uvloop` no funciona en Windows y debe ignorarse mediante el marcador anterior.

## 4.5 Crear el archivo backend/.env

Ejecutar:

```powershell
Copy-Item .env.example .env -Force
notepad .env
```

Reemplazar el contenido con:

```env
APP_NAME=Sistema de Gestion de Torneos
APP_ENV=development
APP_HOST=127.0.0.1
APP_PORT=8000

DB_HOST=localhost
DB_PORT=5432
DB_NAME=sistema_torneos_db_final
DB_USER=postgres
DB_PASSWORD=COLOCAR_AQUI_LA_CONTRASENA_REAL_DE_POSTGRESQL

DB_POOL_MIN_SIZE=1
DB_POOL_MAX_SIZE=10
DB_POOL_TIMEOUT=10

JWT_SECRET=SCORELY_CLAVE_JWT_LOCAL_2026_MUY_SEGURA
JWT_ALGORITHM=HS256
JWT_EXPIRE_MINUTES=120

FRONTEND_ORIGINS=http://localhost:5173,http://127.0.0.1:5173
```

Cambiar únicamente:

```env
DB_PASSWORD=COLOCAR_AQUI_LA_CONTRASENA_REAL_DE_POSTGRESQL
```

por la contraseña real del usuario `postgres`.

No subir `backend/.env` a GitHub.

## 4.6 Preparar las contraseñas de demostración

Con el entorno virtual activo y dentro de `backend`:

```powershell
python -m scripts.configurar_claves_demo
```

Resultado esperado:

```text
Usuarios demo actualizados
Contrasenia temporal: Demo123*
```

## 4.7 Iniciar FastAPI

Para una ejecución estable:

```powershell
python -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

Para desarrollo con recarga automática:

```powershell
python -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

Esperar hasta ver:

```text
Application startup complete.
```

Mantener esta terminal abierta.

## 4.8 Comprobar el backend

Abrir:

```text
http://127.0.0.1:8000
```

Swagger:

```text
http://127.0.0.1:8000/docs
```

También se puede comprobar desde PowerShell:

```powershell
Test-NetConnection 127.0.0.1 -Port 8000
Invoke-RestMethod http://127.0.0.1:8000/
```

El primer comando debe mostrar:

```text
TcpTestSucceeded : True
```

---

# 5. CONFIGURAR Y EJECUTAR EL FRONTEND

Abrir una segunda terminal. No cerrar la terminal de FastAPI.

## 5.1 Entrar al frontend

Desde la raíz:

```powershell
cd frontend
```

## 5.2 Instalar dependencias

```powershell
npm install
```

## 5.3 Crear frontend/.env

```powershell
Copy-Item .env.example .env -Force
```

Dejar el contenido exactamente así:

```env
VITE_API_URL=http://127.0.0.1:8000
VITE_USE_MOCKS=false
```

No subir `frontend/.env` a GitHub.

## 5.4 Iniciar React en el puerto correcto

```powershell
npm run dev -- --port 5173 --strictPort
```

Resultado esperado:

```text
Local: http://localhost:5173/
```

El parámetro `--strictPort` evita que Vite cambie silenciosamente al puerto 5174.

Mantener esta terminal abierta.

## 5.5 Abrir Scorely

```text
http://localhost:5173/login
```

---

# 6. USUARIOS DE DEMOSTRACIÓN

Todos utilizan la contraseña:

```text
Demo123*
```

Administrador:

```text
admin.demo@torneos.test
```

Organizador:

```text
organizador.demo@torneos.test
```

Árbitro:

```text
arbitro.demo@torneos.test
```

Jugador:

```text
titanes1@torneos.test
```

El rol administrador tiene acceso al Laboratorio SQL y a Auditoría.

---

# 7. ORDEN CORRECTO PARA EJECUTAR EL SISTEMA

Siempre seguir este orden:

```text
1. Verificar que PostgreSQL esté iniciado.
2. Iniciar FastAPI.
3. Esperar “Application startup complete”.
4. Iniciar React en el puerto 5173.
5. Abrir http://localhost:5173/login.
6. Iniciar sesión.
```

No abrir Scorely antes de que FastAPI termine de iniciar.

---

# 8. DETENER EL SISTEMA

En la terminal del frontend:

```text
Ctrl + C
```

En la terminal del backend:

```text
Ctrl + C
```

PostgreSQL puede permanecer activo como servicio de Windows.

---

# 9. SOLUCIÓN DE PROBLEMAS

## 9.1 “No se pudo conectar con el servidor”

Comprobar FastAPI:

```powershell
Test-NetConnection 127.0.0.1 -Port 8000
Invoke-RestMethod http://127.0.0.1:8000/
```

Comprobar `frontend/.env`:

```powershell
Get-Content frontend\.env
```

Debe mostrar:

```env
VITE_API_URL=http://127.0.0.1:8000
VITE_USE_MOCKS=false
```

Después de modificar `.env`, reiniciar Vite.

## 9.2 “No se proporcionó un token válido”

Cerrar sesión e iniciar nuevamente.

Cuando quede una sesión anterior en el navegador, abrir las herramientas del desarrollador con `F12`, entrar en Consola y ejecutar:

```javascript
localStorage.clear();
sessionStorage.clear();
window.location.replace("http://localhost:5173/login");
```

## 9.3 El frontend inicia en 5174

Existe otro Vite ejecutándose en 5173.

Cerrar procesos de prueba:

```powershell
Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
Where-Object { $_.LocalPort -in 5173,5174 } |
Select-Object -ExpandProperty OwningProcess -Unique |
ForEach-Object {
    taskkill /PID $_ /T /F
}
```

Después ejecutar:

```powershell
npm run dev -- --port 5173 --strictPort
```

## 9.4 El puerto 8000 está ocupado

```powershell
Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
Where-Object { $_.LocalPort -eq 8000 } |
Select-Object -ExpandProperty OwningProcess -Unique |
ForEach-Object {
    taskkill /PID $_ /T /F
}
```

Reiniciar FastAPI sin `--reload`:

```powershell
python -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

## 9.5 Error de contraseña de PostgreSQL

Revisar `backend/.env`:

```env
DB_HOST=localhost
DB_PORT=5432
DB_NAME=sistema_torneos_db_final
DB_USER=postgres
DB_PASSWORD=CONTRASENA_REAL
```

La contraseña debe ser la misma utilizada en pgAdmin y psql.

## 9.6 Error de uvloop en Windows

El mensaje suele indicar:

```text
RuntimeError: uvloop does not support Windows
```

Abrir:

```text
backend/requirements.txt
```

y verificar:

```text
uvloop==0.22.1; sys_platform != "win32"
```

Luego reconstruir el entorno virtual cuando sea necesario:

```powershell
deactivate
Remove-Item .venv -Recurse -Force
py -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
```

## 9.7 El torneo aparece como FINALIZADO y no permite cambiar estado

`FINALIZADO` es un estado terminal. No tiene una siguiente transición habilitada.

Para probar creación o modificaciones, utilizar un torneo en estado `BORRADOR` o crear uno nuevo.

---

# 10. COMPROBACIÓN RÁPIDA DEL LOGIN

Con FastAPI iniciado:

```powershell
$body = @{
  identificador = "admin.demo@torneos.test"
  contrasenia = "Demo123*"
} | ConvertTo-Json

Invoke-RestMethod `
  -Uri "http://127.0.0.1:8000/api/auth/login" `
  -Method Post `
  -ContentType "application/json" `
  -Body $body
```

Debe devolver campos como:

```text
access_token
token_type
expires_in
usuario
```

No compartir públicamente el token completo.

---

# 11. VERIFICACIÓN ANTES DE SUBIR A GITHUB

Desde la raíz del proyecto comprobar:

```powershell
git status
```

No deben subirse:

```text
backend/.env
backend/.venv/
frontend/.env
frontend/node_modules/
frontend/dist/
```

Comprobar la corrección de uvloop:

```powershell
Select-String -Path backend\requirements.txt -Pattern "uvloop"
```

Debe mostrar:

```text
uvloop==0.22.1; sys_platform != "win32"
```

Comprobar el frontend de ejemplo:

```powershell
Get-Content frontend\.env.example
```

Debe mostrar:

```env
VITE_API_URL=http://127.0.0.1:8000
VITE_USE_MOCKS=false
```

Comprobar que el script completo de la base existe:

```powershell
Test-Path .\database\export\sistema_torneos_db_completa.sql
```

Debe mostrar:

```text
True
```

Realizar el build:

```powershell
cd frontend
npm run build
cd ..
```

---

# 12. SUBIR EL PROYECTO AL REPOSITORIO DE PRUEBA

Repositorio:

```text
https://github.com/alejandroyujra8/ScorelyPrueba.git
```

Ejecutar los siguientes comandos desde la raíz de la carpeta corregida:

```powershell
git init
git branch -M main
git remote remove origin 2>$null
git remote add origin https://github.com/alejandroyujra8/ScorelyPrueba.git
git add .
git status
git commit -m "Version final de prueba de Scorely"
git push -u origin main
```

Antes del `commit`, revisar cuidadosamente `git status`.

Si `origin` ya existe:

```powershell
git remote set-url origin https://github.com/alejandroyujra8/ScorelyPrueba.git
```

Si Git solicita identidad:

```powershell
git config --global user.name "Alejandro Yujra"
git config --global user.email "CORREO_ASOCIADO_A_GITHUB"
```

Luego repetir:

```powershell
git add .
git commit -m "Version final de prueba de Scorely"
git push -u origin main
```

---

# 13. SUBIR CORRECCIONES POSTERIORES

Después de modificar archivos:

```powershell
git status
git add .
git commit -m "Corrige funcionamiento y documentacion de Scorely"
git push origin main
```

---

# 14. ACTUALIZAR EL PROYECTO EN OTRA COMPUTADORA

Cuando un compañero ya haya clonado el proyecto:

```powershell
git pull origin main
```

Después actualizar dependencias:

Backend:

```powershell
cd backend
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
```

Frontend:

```powershell
cd ..\frontend
npm install
```

Si la estructura de la base cambió, no mezclarla con una versión antigua. Crear nuevamente:

```text
sistema_torneos_db_final
```

e importar:

```text
database/export/sistema_torneos_db_completa.sql
```

---

# 15. LISTA FINAL DE PRUEBA

Antes de compartir el repositorio, verificar:

```text
[ ] PostgreSQL está iniciado.
[ ] La base sistema_torneos_db_final fue creada.
[ ] El script completo se importó sin detenerse por errores.
[ ] backend/.env usa la contraseña correcta.
[ ] frontend/.env usa VITE_USE_MOCKS=false.
[ ] FastAPI inicia en 127.0.0.1:8000.
[ ] Swagger abre en 127.0.0.1:8000/docs.
[ ] React inicia únicamente en localhost:5173.
[ ] El login funciona con admin.demo@torneos.test.
[ ] Dashboard carga datos reales.
[ ] Torneos, equipos y partidos cargan.
[ ] Laboratorio SQL carga para el administrador.
[ ] npm run build termina sin errores.
[ ] No se subieron .env, .venv ni node_modules.
```

---

# 16. TECNOLOGÍAS

- PostgreSQL.
- Python.
- FastAPI.
- Psycopg.
- JWT.
- React.
- Vite.
- React Router.
- JavaScript.
- HTML.
- CSS.

---

# 17. NOTA

Este repositorio es una versión de prueba compartida para comprobar el funcionamiento completo de Scorely antes de actualizar el repositorio oficial del proyecto.