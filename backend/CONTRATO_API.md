# Contrato API - Sistema de Torneos

## Direcciones

Backend:

http://127.0.0.1:8000

Swagger:

http://127.0.0.1:8000/docs

Frontend:

http://localhost:5173

---

## Autenticacion

### Login

POST /api/auth/login

Body:

{
  "identificador": "admin.demo@torneos.test",
  "contrasenia": "Demo123*"
}

Respuesta:

{
  "access_token": "token",
  "token_type": "bearer",
  "expires_in": 7200,
  "usuario": {
    "id_usuario": 1,
    "numero_documento": "7000001",
    "nombres": "Andrea",
    "apellido_paterno": "Rojas",
    "apellido_materno": "Mamani",
    "correo": "admin.demo@torneos.test",
    "estado_codigo": "ACTIVO",
    "roles": [
      "ADMINISTRADOR"
    ]
  }
}

Las solicitudes protegidas deben enviar:

Authorization: Bearer TOKEN

### Usuario actual

GET /api/auth/me

---

## Roles

ADMINISTRADOR:
- Acceso completo.
- Acceso a auditoria.

ORGANIZADOR:
- Gestiona equipos, jugadores, torneos, inscripciones,
  pagos, partidos y reportes.

ARBITRO:
- Consulta informacion.
- Inicia partidos.
- Registra asistencia.
- Finaliza partidos.

JUGADOR:
- Consulta equipos, torneos, partidos, resultados
  y reportes.

CONSULTA:
- Acceso de solo lectura al panel, torneos, partidos y reportes permitidos.

---

## Catalogos

GET /api/catalogos/{nombre_catalogo}

Valores aceptados:

- estados-torneo
- formatos-torneo
- estados-inscripcion
- metodos-pago
- estados-pago
- estados-partido
- tipos-fase
- estados-fase
- estados-jornada
- roles-torneo
- tipos-premio
- tipos-documento
- estados-usuario
- estados-perfil
- roles-sistema
- tipos-arbitro-partido
- estados-equipo
- estados-deporte

---

## Usuarios y roles

Requiere rol ADMINISTRADOR.

GET /api/usuarios
GET /api/usuarios/{id}
POST /api/usuarios
PATCH /api/usuarios/{id}
DELETE /api/usuarios/{id}
PATCH /api/usuarios/{id}/contrasenia

---

## Deportes

GET /api/deportes
GET /api/deportes/{id}
POST /api/deportes
PATCH /api/deportes/{id}
DELETE /api/deportes/{id}

---

## Equipos

GET /api/equipos
GET /api/equipos/{id}
POST /api/equipos
PATCH /api/equipos/{id}
DELETE /api/equipos/{id}

Filtros:

- estado
- busqueda
- limite
- desplazamiento

---

## Jugadores

GET /api/jugadores
GET /api/jugadores/{id}
GET /api/jugadores/opciones/usuarios
POST /api/jugadores
PATCH /api/jugadores/{id}
DELETE /api/jugadores/{id}

GET /api/jugadores/{id}/membresias
POST /api/jugadores/{id}/membresias
POST /api/jugadores/{id}/transferencias
PATCH /api/jugadores/{id}/membresias/{id_membresia}/finalizar

---

## Torneos

GET /api/torneos
GET /api/torneos/{id}
POST /api/torneos
PATCH /api/torneos/{id}
PATCH /api/torneos/{id}/estado

GET /api/torneos/{id}/estructura
POST /api/torneos/{id}/fases
POST /api/torneos/fases/{id_fase}/jornadas

---

## Inscripciones y pagos

GET /api/inscripciones
GET /api/inscripciones/{id}
POST /api/inscripciones

GET /api/inscripciones/{id}/nomina
POST /api/inscripciones/{id}/nomina

GET /api/inscripciones/{id}/pagos
POST /api/inscripciones/{id}/pagos

---

## Partidos

GET /api/partidos
GET /api/partidos/{id}
POST /api/partidos

GET /api/partidos/opciones/lugares
GET /api/partidos/opciones/arbitros

POST /api/partidos/{id}/arbitros
PATCH /api/partidos/{id}/iniciar

GET /api/partidos/{id}/participaciones
POST /api/partidos/{id}/participaciones

PATCH /api/partidos/{id}/finalizar

---

## Reportes

GET /api/reportes/dashboard

GET /api/reportes/torneos/{id}/resumen
GET /api/reportes/torneos/{id}/finanzas
GET /api/reportes/torneos/{id}/resultados
GET /api/reportes/torneos/{id}/jugadores
GET /api/reportes/torneos/{id}/premios

GET /api/reportes/jugadores/{id}/rendimiento
GET /api/reportes/equipos/{id}/historial

GET /api/reportes/auditoria

El reporte de auditoria requiere rol ADMINISTRADOR.
El reporte financiero requiere ADMINISTRADOR u ORGANIZADOR.

---

## Laboratorio SQL

Requiere exclusivamente el rol ADMINISTRADOR. Ejecuta cada script dentro de un punto de guardado y revierte los cambios al finalizar.

POST /api/sql-lab/ejecutar
GET /api/sql-lab/objetos

El endpoint de objetos devuelve los triggers y las rutinas que contienen cursores para mostrarlos como accesos rápidos en el frontend.

---

## Codigos HTTP

200:
Operacion correcta.

201:
Registro creado.

401:
Token inexistente, invalido o expirado.

403:
Usuario autenticado sin permisos.

404:
Registro no encontrado.

409:
Conflicto o registro duplicado.

422:
Datos invalidos o regla de PostgreSQL incumplida.

500:
Error interno del servidor.

---

## Usuarios demo

Administrador:

admin.demo@torneos.test

Organizador:

organizador.demo@torneos.test

Arbitro:

arbitro.demo@torneos.test

Jugador:

titanes1@torneos.test

Contrasenia temporal:

Demo123*