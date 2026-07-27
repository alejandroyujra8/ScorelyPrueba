# Scorely - Instalación y ejecución en WSL/Linux

## 1. Descripción del proyecto

Scorely es un sistema web para la gestión de torneos deportivos. Permite administrar usuarios, equipos, jugadores, deportes, torneos, inscripciones, nóminas, pagos, partidos, resultados, premios, reportes y auditoría.

El proyecto está compuesto por:

- Backend desarrollado con Python y FastAPI.
- Frontend desarrollado con React y Vite.
- Base de datos PostgreSQL.
- Autenticación mediante JWT.
- Ejecución compatible con WSL/Linux.

## 2. Estructura principal

```text
sistema-torneos-deportivos/
├── backend/
├── frontend/
├── database/
│   └── export/sistema_torneos_db_completa.sql
├── README_WSL.md
└── README_WINDOWS.md
```

## 3. Requisitos

Se recomienda utilizar:

- WSL 2.
- Ubuntu.
- Python 3.12.
- Node.js LTS.
- npm.
- PostgreSQL 18.
- Git.

La versión de PostgreSQL utilizada para importar el respaldo debe ser igual o superior a la versión utilizada para generarlo.

## 4. Instalar herramientas en WSL

Actualizar los repositorios:

```bash
sudo apt update
sudo apt upgrade -y
```

Instalar herramientas generales:

```bash
sudo apt install -y \
  git \
  curl \
  unzip \
  build-essential \
  python3 \
  python3-pip \
  python3-venv \
  postgresql \
  postgresql-contrib
```

Verificar Python:

```bash
python3 --version
pip3 --version
```

Verificar PostgreSQL:

```bash
psql --version
```

Para instalar Node.js se recomienda utilizar NVM:

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash
```

Cerrar y volver a abrir la terminal o ejecutar:

```bash
source ~/.bashrc
```

Instalar Node.js LTS:

```bash
nvm install --lts
nvm use --lts
```

Verificar:

```bash
node --version
npm --version
```

## 5. Ubicar el proyecto

Ingresar a la carpeta del proyecto:

```bash
cd ~/ruta/al/sistema-torneos-deportivos
```

Comprobar la estructura:

```bash
ls
```

Deben aparecer al menos las siguientes carpetas:

```text
backend
frontend
database
```

## 6. Iniciar PostgreSQL

Ejecutar:

```bash
sudo service postgresql start
```

Verificar su estado:

```bash
sudo service postgresql status
```

También puede utilizarse:

```bash
sudo systemctl status postgresql
```

## 7. Crear la base de datos como administrador

La cuenta técnica de FastAPI no debe ser propietaria de la base ni de sus objetos. La restauración se realiza con `postgres` y luego se aplican los privilegios mínimos definidos por el proyecto.

```bash
sudo -u postgres dropdb --if-exists sistema_torneos_db
sudo -u postgres createdb sistema_torneos_db
```

## 8. Importar el script SQL completo

El archivo se encuentra en:

```text
database/export/sistema_torneos_db_completa.sql
```

Ejecutar desde la raíz del proyecto:

```bash
sudo -u postgres psql \
  -d sistema_torneos_db \
  -v ON_ERROR_STOP=1 \
  -f database/export/sistema_torneos_db_completa.sql
```

El archivo es SQL plano y se restaura con `psql`, no con `pg_restore`.

## 9. Crear la cuenta técnica y aplicar privilegios

```bash
sudo -u postgres psql \
  -d sistema_torneos_db \
  -v ON_ERROR_STOP=1 \
  -f database/08_roles/01_roles_privilegios.sql
```

El script solicitará claves para `usuario_fastapi`, `usr_scorely_consulta` y `usr_scorely_auditor`. La clave de `usuario_fastapi` debe coincidir con `DB_PASSWORD` en `backend/.env`.

Verificar:

```bash
sudo -u postgres psql \
  -d sistema_torneos_db \
  -v ON_ERROR_STOP=1 \
  -f database/08_roles/02_verificar_privilegios.sql
```

## 10. Verificar la instalación

```bash
psql \
  -U usuario_fastapi \
  -h localhost \
  -p 5432 \
  -d sistema_torneos_db \
  -W \
  -c "SELECT CURRENT_DATABASE(), CURRENT_USER;"
```

## 11. Configurar el backend

Ingresar al backend:

```bash
cd backend
```

Crear un entorno virtual:

```bash
python3 -m venv venv
```

Activarlo:

```bash
source venv/bin/activate
```

Actualizar pip:

```bash
python -m pip install --upgrade pip
```

Instalar las dependencias:

```bash
pip install -r requirements.txt
```

Copiar el archivo de ejemplo:

```bash
cp .env.example .env
```

Editar el archivo:

```bash
nano .env
```

La configuración principal debe contener valores similares a los siguientes:

```env
APP_NAME=Sistema de Gestion de Torneos
APP_ENV=development
APP_HOST=127.0.0.1
APP_PORT=8000

DB_HOST=localhost
DB_PORT=5432
DB_NAME=sistema_torneos_db
DB_USER=usuario_fastapi
DB_PASSWORD=CAMBIAR_ESTA_CONTRASENA

DB_POOL_MIN_SIZE=1
DB_POOL_MAX_SIZE=10
DB_POOL_TIMEOUT=10

JWT_SECRET=GENERAR_UNA_CLAVE_SECRETA_LARGA
JWT_ALGORITHM=HS256
JWT_EXPIRE_MINUTES=120

FRONTEND_ORIGINS=http://localhost:5173,http://127.0.0.1:5173
```

Guardar con:

```text
Ctrl + O
Enter
Ctrl + X
```

No debe compartirse el archivo `.env` que contiene contraseñas reales.

## 12. Ejecutar el backend

Con el entorno virtual activo ejecutar:

```bash
uvicorn app.main:app \
  --reload \
  --host 127.0.0.1 \
  --port 8000
```

El backend estará disponible en:

```text
http://127.0.0.1:8000
```

La documentación Swagger estará disponible en:

```text
http://127.0.0.1:8000/docs
```

Para detenerlo:

```text
Ctrl + C
```

## 13. Configurar el frontend

Abrir una nueva terminal WSL.

Ingresar al frontend:

```bash
cd ~/ruta/al/sistema-torneos-deportivos/frontend
```

Instalar dependencias:

```bash
npm install
```

Crear o editar:

```text
frontend/.env
```

Contenido:

```env
VITE_API_URL=http://127.0.0.1:8000
VITE_USE_MOCKS=false
```

También puede crearse desde terminal:

```bash
cat > .env <<'EOF'
VITE_API_URL=http://127.0.0.1:8000
VITE_USE_MOCKS=false
EOF
```

## 14. Ejecutar el frontend

Ejecutar:

```bash
npm run dev
```

La aplicación estará disponible en:

```text
http://localhost:5173
```

Para detenerla:

```text
Ctrl + C
```

## 15. Orden de ejecución

Cada vez que se utilice el sistema se recomienda seguir este orden:

### Terminal 1: PostgreSQL

```bash
sudo service postgresql start
```

### Terminal 2: Backend

```bash
cd backend
source venv/bin/activate
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

### Terminal 3: Frontend

```bash
cd frontend
npm run dev
```

## 16. Verificar la conexión del backend

Abrir:

```text
http://127.0.0.1:8000/docs
```

También puede consultarse el endpoint de salud:

```text
http://127.0.0.1:8000/api/salud
```

Luego ingresar al frontend:

```text
http://localhost:5173
```

## 17. Exportar nuevamente la base de datos

Para generar un nuevo respaldo SQL completo desde consola:

```bash
sudo -u postgres pg_dump \
  -d sistema_torneos_db \
  -Fp \
  --no-owner \
  --no-privileges \
  -f database/export/sistema_torneos_db_completa.sql
```

La opción:

```text
-Fp
```

genera un archivo SQL en formato plano.

Para comprobarlo:

```bash
ls -lh database/export/sistema_torneos_db_completa.sql
```

## 18. Generar una copia del código fuente

Desde la raíz del proyecto:

```bash
zip -r Scorely_Codigo_Fuente.zip . \
  -x "frontend/node_modules/*" \
  -x "frontend/dist/*" \
  -x "backend/venv/*" \
  -x "backend/.venv/*" \
  -x "*/__pycache__/*" \
  -x "*.pyc" \
  -x ".git/*" \
  -x "backend/.env" \
  -x "frontend/.env"
```

## 19. Problemas frecuentes

### PostgreSQL no está iniciado

```bash
sudo service postgresql start
```

### El comando psql no existe

```bash
sudo apt install postgresql-client
```

### El puerto 5432 está ocupado

Verificar:

```bash
sudo ss -ltnp | grep 5432
```

Después ajustar `DB_PORT` en:

```text
backend/.env
```

### Error de contraseña

Verificar que los siguientes valores coincidan:

```env
DB_USER=usuario_fastapi
DB_PASSWORD=CAMBIAR_ESTA_CONTRASENA
```

Puede cambiarse la contraseña desde PostgreSQL:

```bash
sudo -u postgres psql
```

```sql
ALTER ROLE usuario_fastapi
WITH PASSWORD 'NUEVA_CONTRASENA';
```

### Error durante la importación

Eliminar y volver a crear la base de datos:

```bash
sudo -u postgres dropdb \
  --if-exists \
  sistema_torneos_db

sudo -u postgres createdb sistema_torneos_db
```

Volver a importar:

```bash
sudo -u postgres psql \
  -d sistema_torneos_db \
  -v ON_ERROR_STOP=1 \
  -f database/export/sistema_torneos_db_completa.sql

sudo -u postgres psql \
  -d sistema_torneos_db \
  -v ON_ERROR_STOP=1 \
  -f database/08_roles/01_roles_privilegios.sql
```

### El frontend utiliza datos simulados

Comprobar:

```env
VITE_USE_MOCKS=false
```

Después reiniciar Vite:

```bash
npm run dev
```

## 20. Direcciones del sistema

| Servicio | Dirección |
|---|---|
| Frontend | `http://localhost:5173` |
| Backend | `http://127.0.0.1:8000` |
| Swagger | `http://127.0.0.1:8000/docs` |
| PostgreSQL | `localhost:5432` |

## 21. Consideraciones de seguridad

- No compartir el archivo `backend/.env`.
- No subir contraseñas reales al repositorio.
- No almacenar contraseñas en texto plano.
- Utilizar una clave JWT larga.
- Compartir solamente `.env.example`.
- No incluir las carpetas `venv` o `node_modules`.
- El Laboratorio SQL debe utilizarse únicamente con el rol Administrador.