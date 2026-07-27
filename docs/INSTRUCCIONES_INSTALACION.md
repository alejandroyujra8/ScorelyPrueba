# Guía de instalación y ejecución
## Sistema de gestión de torneos deportivos

Esta guía explica cómo descargar, configurar y ejecutar el proyecto completo después de clonarlo desde GitHub.

El sistema utiliza:

- **Base de datos:** PostgreSQL.
- **Backend:** FastAPI con Python 3.12.
- **Frontend:** React con Vite.
- **Entorno recomendado:** WSL Ubuntu.
- **Editor recomendado:** PyCharm o Visual Studio Code.
- **Puerto PostgreSQL usado por el proyecto:** `5433`.
- **Puerto del backend:** `8000`.
- **Puerto del frontend:** `5173`.

---

# 1. Requisitos previos

Antes de clonar el repositorio, comprueba que estén instaladas estas herramientas.

## 1.1 Git

```bash
git --version
```

## 1.2 Python 3.12

```bash
python3 --version
```

Resultado esperado aproximado:

```text
Python 3.12.x
```

## 1.3 Node.js y npm

```bash
node --version
npm --version
```

Se recomienda utilizar una versión LTS de Node.js.

## 1.4 PostgreSQL

```bash
psql --version
```

## 1.5 Servicio PostgreSQL

```bash
sudo systemctl status postgresql
```

Si está detenido:

```bash
sudo systemctl start postgresql
```

También se pueden revisar los clústeres disponibles:

```bash
pg_lsclusters
```

El proyecto está configurado para utilizar PostgreSQL en el puerto:

```text
5433
```

Comprueba la conexión:

```bash
psql -h localhost -p 5433 -U postgres
```

---

# 2. Clonar el repositorio

Ubícate en la carpeta donde guardarás el proyecto.

Ejemplo:

```bash
cd /home/$USER/dev/universidad
```

Clona el repositorio:

```bash
git clone <URL_DEL_REPOSITORIO>
```

Entra al proyecto:

```bash
cd torneos_deportivos
```

Comprueba el contenido:

```bash
ls
```

La estructura principal debe ser parecida a:

```text
torneos_deportivos/
├── backend/
├── frontend/
├── database/
├── .gitignore
└── README.md
```

---

# 3. Seleccionar la rama correcta

## Caso A: los cambios ya fueron integrados en `main`

```bash
git switch main
git pull origin main
```

## Caso B: todavía se debe trabajar con la rama de desarrollo

```bash
git fetch origin
git switch experimento-gran-cambio
git pull origin experimento-gran-cambio
```

Comprueba la rama actual:

```bash
git branch --show-current
```

---

# 4. Configurar PostgreSQL

## 4.1 Crear la base de datos

Conéctate a PostgreSQL:

```bash
psql -h localhost -p 5433 -U postgres
```

Dentro de `psql`, crea la base de datos:

```sql
CREATE DATABASE sistema_torneos_db;
```

Sal de `psql`:

```sql
\q
```

Si la base ya existe, no vuelvas a crearla.

Puedes comprobarlo con:

```bash
psql -h localhost -p 5433 -U postgres -lqt | cut -d '|' -f 1 | grep -w sistema_torneos_db
```

---

# 5. Importar la base de datos

El método recomendado es restaurar el archivo SQL completo exportado desde PostgreSQL.

## 5.1 Restauración mediante el archivo completo

Desde la raíz del proyecto:

```bash
cd /ruta/al/proyecto/torneos_deportivos
```

Ejecuta:

```bash
psql \
-h localhost \
-p 5433 \
-U postgres \
-d sistema_torneos_db \
-f database/export/sistema_torneos_db_completa.sql
```

Introduce la contraseña del usuario `postgres` cuando sea solicitada.

## 5.2 Comprobar la importación

```bash
psql -h localhost -p 5433 -U postgres -d sistema_torneos_db
```

Dentro de `psql`:

```sql
\dn
```

Deben aparecer esquemas parecidos a:

```text
auditoria
catalogo
competencia
finanzas
participantes
reportes
seguridad
```

Comprueba algunas tablas:

```sql
\dt competencia.*
```

Comprueba los usuarios de demostración:

```sql
SELECT
    id_usuario,
    numero_documento,
    correo
FROM seguridad.usuario
ORDER BY id_usuario;
```

Sal de `psql`:

```sql
\q
```

---

# 6. Alternativa: crear la base ejecutando los scripts

Utiliza este método solo cuando no exista el archivo:

```text
database/export/sistema_torneos_db_completa.sql
```

Los scripts deben ejecutarse respetando el orden definido en las carpetas de `database/`.

Ejemplo general:

```bash
psql -h localhost -p 5433 -U postgres \
-d sistema_torneos_db \
-f database/<CARPETA>/<ARCHIVO.sql>
```

No ejecutes los archivos en un orden arbitrario, porque algunos dependen de:

- Esquemas creados previamente.
- Tablas.
- Catálogos.
- Funciones.
- Procedimientos.
- Triggers.
- Vistas.
- Datos iniciales.

El archivo de exportación completa es la opción más rápida y segura para los integrantes del grupo.

---

# 7. Configurar el backend FastAPI

Entra al backend:

```bash
cd backend
```

## 7.1 Crear el entorno virtual

```bash
python3 -m venv venv
```

## 7.2 Activar el entorno virtual

```bash
source venv/bin/activate
```

Cuando esté activo, la terminal debe mostrar algo parecido a:

```text
(venv)
```

## 7.3 Actualizar `pip`

```bash
python -m pip install --upgrade pip
```

## 7.4 Instalar las dependencias

```bash
python -m pip install -r requirements.txt
```

Comprueba las importaciones principales:

```bash
python -c "import fastapi, psycopg, jwt, pwdlib; print('Dependencias del backend instaladas correctamente')"
```

---

# 8. Crear el archivo `.env` del backend

Desde la carpeta `backend`:

```bash
cp .env.example .env
```

Abre:

```text
backend/.env
```

Configúralo con valores locales.

Ejemplo:

```env
APP_NAME=Sistema de Gestion de Torneos
APP_ENV=development
APP_HOST=127.0.0.1
APP_PORT=8000

FRONTEND_ORIGINS=http://localhost:5173,http://127.0.0.1:5173

DB_HOST=localhost
DB_PORT=5433
DB_NAME=sistema_torneos_db
DB_USER=postgres
DB_PASSWORD=TU_CONTRASENIA_POSTGRESQL

DB_POOL_MIN_SIZE=1
DB_POOL_MAX_SIZE=10
DB_POOL_TIMEOUT=10

JWT_SECRET=REEMPLAZAR_POR_UNA_CLAVE_SEGURA
JWT_ALGORITHM=HS256
JWT_EXPIRE_MINUTES=120
```

## 8.1 Generar una clave JWT

Ejecuta:

```bash
python -c "import secrets; print(secrets.token_urlsafe(64))"
```

Copia el resultado y colócalo en:

```env
JWT_SECRET=CLAVE_GENERADA
```

No compartas ni subas el archivo `.env`.

---

# 9. Configurar contraseñas de usuarios de demostración

Desde la carpeta `backend`, con el entorno virtual activo:

```bash
python scripts/configurar_claves_demo.py
```

Resultado esperado aproximado:

```text
Usuarios demo actualizados: 13
Contrasenia temporal: Demo123*
```

Usuarios principales de demostración:

| Rol | Correo |
|---|---|
| Administrador | `admin.demo@torneos.test` |
| Organizador | `organizador.demo@torneos.test` |
| Árbitro | `arbitro.demo@torneos.test` |
| Jugador | `titanes1@torneos.test` |

Contraseña temporal:

```text
Demo123*
```

Estas credenciales son únicamente para desarrollo y demostración.

---

# 10. Comprobar el backend

## 10.1 Verificar sintaxis

Desde `backend/`:

```bash
python -m compileall app
```

## 10.2 Iniciar FastAPI

```bash
uvicorn app.main:app --reload
```

Resultado esperado:

```text
Uvicorn running on http://127.0.0.1:8000
Application startup complete
```

No cierres esta terminal mientras uses el backend.

---

# 11. Verificar los endpoints del backend

## 11.1 Endpoint principal

Abre en el navegador:

```text
http://127.0.0.1:8000/
```

## 11.2 Estado de FastAPI

```text
http://127.0.0.1:8000/api/salud
```

## 11.3 Estado de PostgreSQL

```text
http://127.0.0.1:8000/api/salud/base-datos
```

## 11.4 Swagger

```text
http://127.0.0.1:8000/docs
```

Swagger permite consultar y probar los endpoints disponibles.

---

# 12. Probar el login

Desde otra terminal:

```bash
curl -X POST \
-H "Content-Type: application/json" \
-d '{
  "identificador": "admin.demo@torneos.test",
  "contrasenia": "Demo123*"
}' \
http://127.0.0.1:8000/api/auth/login
```

La respuesta debe incluir:

```json
{
  "access_token": "TOKEN_JWT",
  "token_type": "bearer",
  "expires_in": 7200,
  "usuario": {
    "roles": [
      "ADMINISTRADOR"
    ]
  }
}
```

## 12.1 Autorizarse en Swagger

1. Ejecuta `POST /api/auth/login`.
2. Copia el campo `access_token`.
3. Pulsa el botón **Authorize**.
4. Pega solamente el token.
5. Prueba los endpoints protegidos.

---

# 13. Configurar el frontend React

Abre una terminal nueva.

Desde la raíz del proyecto:

```bash
cd frontend
```

## 13.1 Instalar dependencias

```bash
npm install
```

## 13.2 Crear el archivo `.env`

```bash
cp .env.example .env
```

Abre:

```text
frontend/.env
```

Debe contener:

```env
VITE_API_URL=http://127.0.0.1:8000
```

## 13.3 Iniciar React

```bash
npm run dev
```

Resultado esperado aproximado:

```text
Local: http://localhost:5173/
```

Abre:

```text
http://localhost:5173
```

No cierres esta terminal mientras uses el frontend.

---

# 14. Orden correcto para iniciar todo el sistema

Cada vez que trabajes con el proyecto, sigue este orden.

## Terminal 1: PostgreSQL

```bash
sudo systemctl start postgresql
pg_lsclusters
```

Comprueba que el clúster del puerto `5433` esté activo.

## Terminal 2: Backend

```bash
cd /ruta/al/proyecto/torneos_deportivos/backend
source venv/bin/activate
uvicorn app.main:app --reload
```

## Terminal 3: Frontend

```bash
cd /ruta/al/proyecto/torneos_deportivos/frontend
npm run dev
```

Direcciones:

| Servicio | Dirección |
|---|---|
| Frontend React | `http://localhost:5173` |
| Backend FastAPI | `http://127.0.0.1:8000` |
| Swagger | `http://127.0.0.1:8000/docs` |
| PostgreSQL | `localhost:5433` |

---

# 15. Roles y permisos

El sistema maneja cuatro roles principales.

## Administrador

Puede administrar todos los módulos y consultar la auditoría.

## Organizador

Puede gestionar:

- Equipos.
- Jugadores.
- Torneos.
- Fases.
- Jornadas.
- Inscripciones.
- Nóminas.
- Pagos.
- Partidos.
- Reportes.

## Árbitro

Puede:

- Consultar torneos y partidos.
- Iniciar partidos.
- Registrar asistencia.
- Registrar estadísticas.
- Finalizar partidos.
- Consultar resultados.

## Jugador

Puede principalmente consultar:

- Su perfil.
- Equipos.
- Torneos.
- Partidos.
- Resultados.
- Estadísticas y reportes permitidos.

---

# 16. Flujo general del sistema

```text
React
  ↓
Solicitud HTTP con JWT
  ↓
FastAPI valida usuario y roles
  ↓
FastAPI obtiene una conexión del pool
  ↓
FastAPI llama consultas, vistas o procedimientos
  ↓
PostgreSQL valida reglas mediante funciones y triggers
  ↓
PostgreSQL registra auditoría
  ↓
COMMIT si todo funciona
ROLLBACK si ocurre un error
  ↓
FastAPI devuelve JSON
  ↓
React actualiza la interfaz
```

---

# 17. Módulos disponibles en el backend

## Autenticación

```text
POST /api/auth/login
GET  /api/auth/me
```

## Catálogos

```text
GET /api/catalogos/{nombre_catalogo}
```

## Deportes

```text
GET    /api/deportes
GET    /api/deportes/{id}
POST   /api/deportes
PATCH  /api/deportes/{id}
DELETE /api/deportes/{id}
```

## Equipos

```text
GET    /api/equipos
GET    /api/equipos/{id}
POST   /api/equipos
PATCH  /api/equipos/{id}
DELETE /api/equipos/{id}
```

## Jugadores

```text
GET    /api/jugadores
GET    /api/jugadores/{id}
POST   /api/jugadores
PATCH  /api/jugadores/{id}
DELETE /api/jugadores/{id}

GET   /api/jugadores/{id}/membresias
POST  /api/jugadores/{id}/membresias
POST  /api/jugadores/{id}/transferencias
PATCH /api/jugadores/{id}/membresias/{id_membresia}/finalizar
```

## Torneos

```text
GET   /api/torneos
GET   /api/torneos/{id}
POST  /api/torneos
PATCH /api/torneos/{id}/estado

GET  /api/torneos/{id}/estructura
POST /api/torneos/{id}/fases
POST /api/torneos/fases/{id_fase}/jornadas
```

## Inscripciones y pagos

```text
GET  /api/inscripciones
GET  /api/inscripciones/{id}
POST /api/inscripciones

GET  /api/inscripciones/{id}/nomina
POST /api/inscripciones/{id}/nomina

GET  /api/inscripciones/{id}/pagos
POST /api/inscripciones/{id}/pagos
```

## Partidos

```text
GET   /api/partidos
GET   /api/partidos/{id}
POST  /api/partidos

GET  /api/partidos/opciones/lugares
GET  /api/partidos/opciones/arbitros

POST  /api/partidos/{id}/arbitros
PATCH /api/partidos/{id}/iniciar

GET  /api/partidos/{id}/participaciones
POST /api/partidos/{id}/participaciones

PATCH /api/partidos/{id}/finalizar
```

## Reportes

```text
GET /api/reportes/dashboard
GET /api/reportes/torneos/{id}/resumen
GET /api/reportes/torneos/{id}/finanzas
GET /api/reportes/torneos/{id}/resultados
GET /api/reportes/torneos/{id}/jugadores
GET /api/reportes/torneos/{id}/premios
GET /api/reportes/jugadores/{id}/rendimiento
GET /api/reportes/equipos/{id}/historial
GET /api/reportes/auditoria
```

El reporte de auditoría requiere el rol `ADMINISTRADOR`.

---

# 18. Errores frecuentes

## Error: `password authentication failed`

Revisa:

```text
backend/.env
```

Especialmente:

```env
DB_USER=postgres
DB_PASSWORD=TU_CONTRASENIA_REAL
```

Reinicia FastAPI después de modificar `.env`.

---

## Error: conexión rechazada en el puerto 5433

Comprueba:

```bash
pg_lsclusters
```

También:

```bash
sudo systemctl status postgresql
```

Prueba manualmente:

```bash
psql -h localhost -p 5433 -U postgres -d sistema_torneos_db
```

---

## Error: `No module named app`

FastAPI debe iniciarse desde la carpeta:

```text
torneos_deportivos/backend
```

Comprueba:

```bash
pwd
```

Después:

```bash
uvicorn app.main:app --reload
```

---

## Error: `No module named ...`

Activa el entorno virtual:

```bash
source venv/bin/activate
```

Instala nuevamente:

```bash
python -m pip install -r requirements.txt
```

---

## Error: `npm: command not found`

Instala una versión LTS de Node.js dentro de WSL.

Si utilizas `nvm`:

```bash
nvm install --lts
nvm use --lts
```

---

## Error de CORS

Comprueba que `backend/.env` incluya:

```env
FRONTEND_ORIGINS=http://localhost:5173,http://127.0.0.1:5173
```

Reinicia FastAPI.

---

## El frontend no encuentra el backend

Comprueba `frontend/.env`:

```env
VITE_API_URL=http://127.0.0.1:8000
```

Reinicia Vite:

```bash
npm run dev
```

---

## Token inválido o expirado

Inicia sesión otra vez.

El token de desarrollo expira según:

```env
JWT_EXPIRE_MINUTES=120
```

---

## La base ya contiene objetos y la importación falla

Para reinstalar desde cero:

```bash
psql -h localhost -p 5433 -U postgres -d postgres
```

Dentro de `psql`:

```sql
DROP DATABASE sistema_torneos_db;
CREATE DATABASE sistema_torneos_db;
\q
```

Después vuelve a importar:

```bash
psql \
-h localhost \
-p 5433 \
-U postgres \
-d sistema_torneos_db \
-f database/export/sistema_torneos_db_completa.sql
```

Este procedimiento elimina todos los datos locales de esa base.

---

# 19. Actualizar el proyecto desde GitHub

Antes de trabajar:

```bash
git status
```

Si no tienes cambios locales:

```bash
git pull
```

Si trabajas con la rama de desarrollo:

```bash
git switch experimento-gran-cambio
git pull origin experimento-gran-cambio
```

Después de un cambio en las dependencias del backend:

```bash
cd backend
source venv/bin/activate
python -m pip install -r requirements.txt
```

Después de un cambio en las dependencias del frontend:

```bash
cd frontend
npm install
```

Después de cambios en la base de datos, revisa los nuevos scripts SQL o vuelve a importar una base limpia cuando sea necesario.

---

# 20. Recomendaciones para el equipo

- No subir archivos `.env`.
- No subir `backend/venv`.
- No subir `frontend/node_modules`.
- No modificar directamente la rama `main` sin coordinación.
- Crear una rama por integrante o módulo.
- Antes de comenzar, ejecutar `git pull`.
- Antes de hacer `push`, ejecutar `git status`.
- No guardar contraseñas reales dentro del código.
- Utilizar Swagger para comprender los cuerpos JSON.
- Mantener PostgreSQL como fuente principal de reglas de negocio.
- Informar al equipo cuando se agreguen o modifiquen scripts SQL.

---

# 21. Comandos resumidos de instalación

```bash
# Clonar
git clone <URL_DEL_REPOSITORIO>
cd torneos_deportivos

# Seleccionar rama
git switch experimento-gran-cambio

# Crear base
psql -h localhost -p 5433 -U postgres \
-c "CREATE DATABASE sistema_torneos_db;"

# Importar base
psql -h localhost -p 5433 -U postgres \
-d sistema_torneos_db \
-f database/export/sistema_torneos_db_completa.sql

# Backend
cd backend
python3 -m venv venv
source venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
cp .env.example .env

# Editar backend/.env antes de continuar
python scripts/configurar_claves_demo.py
uvicorn app.main:app --reload

# Frontend, en otra terminal
cd ../frontend
npm install
cp .env.example .env
npm run dev
```

---

# 22. Comprobación final

El sistema está correctamente configurado cuando funcionan estas direcciones:

```text
Frontend:
http://localhost:5173

Backend:
http://127.0.0.1:8000

Swagger:
http://127.0.0.1:8000/docs

Salud de FastAPI:
http://127.0.0.1:8000/api/salud

Salud de PostgreSQL:
http://127.0.0.1:8000/api/salud/base-datos
```

Además, debe ser posible iniciar sesión con:

```text
Correo: admin.demo@torneos.test
Contraseña: Demo123*
```
