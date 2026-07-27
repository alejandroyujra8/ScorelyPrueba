# Scorely — Frontend

Interfaz React + Vite del sistema de gestión de torneos deportivos.

## Requisitos

- Node.js 20.19+ o 22.12+
- npm

## Ejecución

```powershell
npm install
npm run dev
```

La aplicación inicia normalmente en `http://localhost:5173`.

## Variables de entorno

El archivo `.env` incluido usa datos simulados:

```env
VITE_API_URL=http://127.0.0.1:8000
VITE_USE_MOCKS=true
```

Para conectarse con FastAPI:

```env
VITE_API_URL=http://127.0.0.1:8000
VITE_USE_MOCKS=false
```

Después de cambiar `.env`, reinicia Vite.

## Usuarios mock

| Rol | Identificador |
|---|---|
| Administrador | `admin.demo@torneos.test` |
| Organizador | `organizador.demo@torneos.test` |
| Árbitro | `arbitro.demo@torneos.test` |
| Jugador | `titanes1@torneos.test` |

Contraseña temporal para todos: `Demo123*`.

## Arquitectura

Las páginas consumen servicios de `src/services/`. Cada servicio selecciona datos mock o API real mediante `VITE_USE_MOCKS`. Los datos simulados están centralizados en `src/mocks/`.

## Comprobación

```powershell
npm run build
```
