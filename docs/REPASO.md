## 1. Propósito general

El sistema administra torneos deportivos disputados por equipos.

Soporta deportes como:

```text
Fútbol
Futsal
Baloncesto
Voleibol
Tenis por equipos
Otros deportes configurables
```

El sistema cubre:

```text
Usuarios
Participantes
Equipos
Jugadores
Organizadores
Árbitros
Administradores
Deportes
Torneos
Fases
Jornadas
Inscripciones
Nóminas
Pagos
Partidos
Asistencia
Resultados
Premios
Reportes
Auditoría
```

La característica principal es que **la lógica de negocio importante está en PostgreSQL**. FastAPI no sustituye a la base de datos: la expone mediante HTTP.

---

# 2. El corazón: PostgreSQL

## 2.1 Organización por esquemas

La base de datos está dividida por responsabilidades.

### `catalogo`

Contiene valores controlados utilizados por las demás tablas:

```text
Estados de usuario
Estados de equipo
Estados de torneo
Estados de partido
Estados de inscripción
Estados de pago
Estados de fases y jornadas
Formatos de torneo
Tipos de fase
Métodos de pago
Tipos de premio
Roles dentro del torneo
```

La ventaja es que no se guardan textos inconsistentes como:

```text
activo
Activo
ACT
A
```

Las tablas principales referencian identificadores de catálogo.

---

### `seguridad`

Gestiona:

```text
Usuarios
Roles generales
Asignación de roles
Estado de las cuentas
Contraseñas almacenadas como hash
Último acceso
```

Una persona puede tener varios roles generales, por ejemplo:

```text
JUGADOR
ORGANIZADOR
ARBITRO
ADMINISTRADOR
```

Sin embargo, dentro de un torneo se aplican restricciones para evitar roles incompatibles.

Ejemplo:

```text
Una persona podría ser jugador en un torneo
y organizador en otro.
```

Pero no debería organizar o arbitrar un torneo donde participa como jugador si la regla de independencia lo impide.

---

### `participantes`

Contiene los perfiles deportivos:

```text
Jugador
Organizador
Árbitro
Equipo
Historial jugador-equipo
```

La entidad `usuario` representa a la persona.

Las tablas:

```text
participantes.jugador
participantes.organizador
participantes.arbitro
```

agregan la información especializada de cada rol.

Por eso una misma persona puede conservar una única identidad, pero tener diferentes perfiles.

---

### Historial de jugador y equipo

La tabla de membresías conserva:

```text
Equipo
Fecha de inicio
Fecha de finalización
Número de camiseta
Posición
Condición de delegado
Estado
Observaciones
```

Cuando un jugador cambia de equipo no se elimina el registro anterior.

Se hace:

```text
Membresía anterior → FINALIZADA
Nueva membresía → ACTIVA
```

Esto permite generar:

```text
Historial deportivo
Experiencia por equipo
Transferencias
Reportes por jugador
```

La base impide que el jugador cambie de equipo cuando participa en un torneo vigente, según las reglas implementadas.

---

### `competencia`

Es el núcleo operativo de los torneos.

Incluye:

```text
Deporte
Reglas
Lugares
Torneos
Fases
Grupos
Jornadas
Inscripciones
Nóminas
Partidos
Equipos del partido
Árbitros asignados
Participaciones de jugadores
Resultados finales
```

---

## 2.2 Deportes configurables

Cada deporte define, entre otros:

```text
Cantidad mínima de jugadores
Cantidad máxima
Cantidad de titulares
Tipo de marcador
Posibilidad de empate
Puntos por victoria
Puntos por empate
Puntos por derrota
Estado del deporte
```

Por ello no se necesita escribir lógica completamente distinta para cada deporte.

El sistema puede interpretar:

```text
Fútbol → marcador por goles
Baloncesto → marcador por puntos
Voleibol → marcador según configuración
```

---

## 2.3 Torneos

Cada torneo almacena:

```text
Deporte
Formato
Estado
Código
Nombre
Edición
Categoría
Rama
Fechas de inscripción
Fechas del torneo
Máximo de equipos
Mínimo y máximo de jugadores
Costo de inscripción
Moneda
Permiso de empate
Organizador responsable
```

El torneo atraviesa estados controlados, por ejemplo:

```text
BORRADOR
        ↓
INSCRIPCIONES_ABIERTAS
        ↓
INSCRIPCIONES_CERRADAS
        ↓
PROGRAMADO
        ↓
EN_CURSO
        ↓
FINALIZADO
```

Los triggers impiden saltos inválidos, por ejemplo:

```text
INSCRIPCIONES_CERRADAS → BORRADOR
```

---

## 2.4 Formatos de competencia

El modelo admite principalmente:

```text
Partido único
Eliminación directa
Fases de grupos
Combinación de grupos y llaves
```

La estructura es:

```text
Torneo
  └── Fases
        └── Jornadas
              └── Partidos
```

Una fase puede representar:

```text
Fase de grupos
Octavos
Cuartos
Semifinal
Final
Partido único
```

---

## 2.5 Inscripciones

Una inscripción vincula:

```text
Torneo + Equipo
```

La base controla:

```text
Estado del torneo
Límite máximo de equipos
Duplicidad del equipo
Costo requerido
Pago acumulado
Saldo pendiente
Número mínimo de jugadores
Número máximo de jugadores
```

El flujo es:

```text
Equipo solicita inscripción
        ↓
Se crea la inscripción
        ↓
Se registra la nómina
        ↓
Se registran pagos
        ↓
PostgreSQL calcula el saldo
        ↓
La inscripción puede habilitarse
```

---

## 2.6 Nóminas de jugadores

La nómina no usa simplemente todos los jugadores actuales del equipo.

Se crea una fotografía de los jugadores inscritos para ese torneo:

```text
Jugador
Número de camiseta
Delegado
Capitán
Estado dentro de la inscripción
Fecha de baja
```

Esto permite conservar el historial aunque el jugador cambie de equipo después.

La base evita que el mismo jugador participe con dos equipos en el mismo torneo.

---

## 2.7 Pagos

Los pagos son simulados, pero están modelados como operaciones reales.

Se registra:

```text
Inscripción
Método de pago
Estado
Monto
Moneda
Referencia
Fecha de pago
Usuario que registra
Usuario que verifica
Observaciones
```

Una inscripción puede pagarse en varias partes:

```text
Pago 1: 100 BOB
Pago 2: 100 BOB
Total: 200 BOB
```

Las funciones calculan:

```text
Total pagado
Saldo pendiente
Monto requerido
```

PostgreSQL impide:

```text
Pagar más que el saldo
Modificar un pago confirmado
Eliminar físicamente un pago
Duplicar referencias cuando corresponda
```

---

## 2.8 Partidos

Un partido pertenece a una jornada y, mediante ella, a una fase y a un torneo.

Guarda:

```text
Lugar
Código
Número
Ronda
Fecha y hora
Equipo local
Equipo visitante
Estado
Marcador
Desempate
Observaciones
```

Los procedimientos controlan:

```text
Programar partido
Asignar equipos
Asignar árbitros
Iniciar partido
Registrar asistencia
Registrar estadísticas
Finalizar partido
Generar resultados
```

---

## 2.9 Control de horarios

La base comprueba conflictos como:

```text
Dos partidos en el mismo lugar y horario
Un árbitro asignado a partidos simultáneos
Un equipo jugando dos partidos superpuestos
```

Estas validaciones se realizan en PostgreSQL para que no dependan exclusivamente del frontend o de FastAPI.

---

## 2.10 Asistencia y estadísticas

La relación entre jugador y partido conserva:

```text
Convocado
Asistió
Titular
Minutos jugados
Puntos o goles
Faltas
Amonestaciones
Expulsión
Lesión
Calificación
Estadísticas JSON
```

El campo `estadisticas` permite guardar información particular del deporte:

```json
{
  "goles": 2,
  "asistencias": 1,
  "atajadas": 0
}
```

La base evita casos incoherentes, como:

```text
Jugador titular sin asistencia
Jugador ausente con minutos jugados
Jugador no convocado que aparece como presente
```

---

## 2.11 Resultados y premios

Cuando finalizan los partidos y el torneo, se generan resultados como:

```text
Posición final
Partidos jugados
Ganados
Empatados
Perdidos
Marcador a favor
Marcador en contra
Diferencia
Puntos
```

Los premios están vinculados a una posición objetivo:

```text
Posición 1 → campeón
Posición 2 → subcampeón
Posición 3 → tercer lugar
```

La entrega conserva:

```text
Premio
Equipo ganador
Estado
Fecha de autorización
Fecha de entrega
Usuario que autoriza
Usuario que entrega
```

---

# 3. Funciones, procedimientos y triggers

## Funciones

Las funciones se utilizan para consultar y calcular valores.

Ejemplos:

```text
Total pagado de una inscripción
Saldo pendiente
Resumen del torneo
Finanzas del torneo
Rendimiento histórico del jugador
Historial del equipo
Tabla de posiciones
```

Las funciones devuelven datos sin que FastAPI tenga que reconstruir toda la lógica.

---

## Procedimientos almacenados

Los procedimientos ejecutan procesos completos.

Ejemplos:

```text
Registrar inscripción
Agregar jugador a nómina
Registrar pago
Programar partido
Asignar árbitro
Iniciar partido
Registrar participación
Finalizar partido
Finalizar fase
Finalizar torneo
Configurar premio
Generar entrega
Autorizar premio
Entregar premio
```

La ventaja es que una operación compleja se ejecuta dentro de PostgreSQL.

FastAPI solamente realiza:

```sql
CALL competencia.sp_programar_partido(...);
```

---

## Triggers

Los triggers reaccionan automáticamente ante operaciones DML.

Controlan, entre otras cosas:

```text
Transiciones de estados
Membresías activas
Conflictos de roles
Horarios superpuestos
Pagos confirmados
Cambios de equipo
Límites de inscripción
Auditoría automática
```

No importa si una operación proviene de:

```text
FastAPI
psql
PyCharm
pgAdmin
Otro cliente
```

La regla seguirá aplicándose porque vive en PostgreSQL.

---

## Cursores

Los cursores se utilizan para recorrer conjuntos de registros cuando el proceso requiere tratamiento fila por fila.

Son apropiados para procesos como:

```text
Generar resultados de varios equipos
Generar entregas de premios
Procesar clasificaciones
Recorrer jugadores o inscripciones
```

Además, constituyen evidencia importante para la materia, cuya plantilla solicita consultas, procedimientos, funciones, vistas, cursores y triggers por integrante. 

---

# 4. Transacciones y rollback

Los procesos importantes se ejecutan como una unidad.

Ejemplo de transferencia:

```text
BEGIN
  Finalizar membresía actual
  Crear membresía nueva
COMMIT
```

Si la nueva membresía falla:

```text
ROLLBACK
```

Entonces tampoco se confirma el cierre de la anterior.

También se demostraron:

```text
SAVEPOINT
ROLLBACK TO SAVEPOINT
ROLLBACK completo
Manejo de excepciones PL/pgSQL
```

Esto evita datos parcialmente registrados.

---

# 5. Auditoría DML

El esquema:

```text
auditoria
```

registra automáticamente:

```text
Esquema
Tabla
Operación
Identificador del registro
Columnas modificadas
Datos anteriores
Datos nuevos
Cambios
Usuario de aplicación
Usuario PostgreSQL
Dirección IP
Request ID
Transacción
Fecha y hora
Aplicación
```

Ejemplo:

```text
React envía una solicitud
       ↓
FastAPI genera X-Request-ID
       ↓
FastAPI establece app.usuario_id
       ↓
PostgreSQL ejecuta UPDATE
       ↓
Trigger registra la auditoría
```

Esto permite saber:

```text
Quién hizo el cambio
Qué cambió
Cuándo cambió
Desde qué solicitud
En qué transacción
```

---

# 6. Vistas y reportes

El esquema:

```text
reportes
```

contiene vistas para:

```text
Usuarios y roles
Usuarios por estado
Jugadores y equipo actual
Historial jugador-equipo
Configuración de deportes
Programación de lugares
Resumen de torneos
Inscripciones y saldos
Partidos y marcadores
Asistencia
Pagos
Premios
Estadísticas de jugadores
Resultados finales
Auditoría
```

Estas vistas simplifican el backend.

En vez de realizar diez uniones en Python, FastAPI consulta:

```sql
SELECT *
FROM reportes.vw_torneos_resumen;
```

---

# 7. Cómo funciona FastAPI

## 7.1 Inicio de la aplicación

Al ejecutar:

```bash
uvicorn app.main:app --reload
```

ocurre:

```text
Uvicorn inicia
    ↓
FastAPI ejecuta lifespan
    ↓
Se abre el pool de Psycopg
    ↓
Se comprueba PostgreSQL
    ↓
La API comienza a recibir solicitudes
```

Cuando la aplicación se detiene:

```text
FastAPI cierra el pool
    ↓
Las conexiones se liberan correctamente
```

---

## 7.2 Pool de conexiones

No se crea una conexión nueva desde cero para cada solicitud.

Se utiliza:

```text
AsyncConnectionPool
```

Flujo:

```text
Solicitud HTTP
    ↓
FastAPI toma una conexión disponible
    ↓
Ejecuta consultas o procedimientos
    ↓
COMMIT si todo funciona
ROLLBACK si ocurre una excepción
    ↓
Devuelve la conexión al pool
```

---

## 7.3 Configuración

El archivo:

```text
backend/app/core/config.py
```

lee:

```text
backend/.env
```

Variables principales:

```text
DB_HOST
DB_PORT
DB_NAME
DB_USER
DB_PASSWORD
DB_POOL_MIN_SIZE
DB_POOL_MAX_SIZE
JWT_SECRET
JWT_ALGORITHM
JWT_EXPIRE_MINUTES
FRONTEND_ORIGINS
```

El `.env` real no se sube.

El archivo:

```text
backend/.env.example
```

sirve como plantilla para los compañeros.

---

## 7.4 Capas del backend

Los primeros módulos utilizan una estructura más organizada:

```text
Ruta
  ↓
Servicio
  ↓
Repositorio
  ↓
PostgreSQL
```

Ejemplo de deportes:

```text
deportes.py
    ↓
deporte_service.py
    ↓
deporte_repository.py
    ↓
competencia.deporte
```

Los módulos posteriores se simplificaron para ahorrar tiempo:

```text
Ruta
  ↓
Procedimiento o vista PostgreSQL
```

Esto es válido porque PostgreSQL es el centro del proyecto.

---

# 8. Módulos HTTP disponibles

## Salud

```text
GET /api/salud
GET /api/salud/base-datos
```

Comprueban FastAPI y PostgreSQL.

---

## Autenticación

```text
POST /api/auth/login
GET  /api/auth/me
```

El login acepta:

```text
Correo
o
Número de documento
```

Devuelve:

```text
JWT
Tiempo de expiración
Usuario
Roles
```

---

## Catálogos

```text
GET /api/catalogos/{nombre_catalogo}
```

Se utiliza para llenar selectores de React.

Ejemplo:

```text
/api/catalogos/formatos-torneo
/api/catalogos/metodos-pago
/api/catalogos/estados-partido
```

---

## Deportes

```text
GET
GET por ID
POST
PATCH
DELETE lógico
```

---

## Equipos

```text
Listar
Buscar
Crear
Editar
Desactivar
Reactivar
```

---

## Jugadores

```text
Perfil
Membresías
Historial
Transferencias
Desactivación
```

---

## Torneos

```text
Crear torneo
Listar
Obtener detalle
Cambiar estado
Crear fase
Crear jornada
Consultar estructura
```

---

## Inscripciones y pagos

```text
Registrar equipo
Consultar inscripción
Agregar nómina
Consultar nómina
Registrar pago
Consultar pagos
```

---

## Partidos

```text
Programar
Asignar árbitro
Iniciar
Registrar asistencia
Registrar estadísticas
Finalizar
Consultar resultado
```

---

## Reportes

```text
Dashboard
Resumen del torneo
Finanzas
Resultados
Jugadores
Premios
Rendimiento individual
Historial del equipo
Auditoría
```

---

# 9. JWT y privilegios

## Administrador

Puede:

```text
Administrar todo
Gestionar catálogos operativos
Gestionar deportes
Gestionar equipos
Gestionar jugadores
Gestionar torneos
Gestionar inscripciones
Registrar pagos
Administrar partidos
Consultar auditoría
```

## Organizador

Puede:

```text
Gestionar equipos
Gestionar jugadores
Crear y organizar torneos
Gestionar inscripciones
Registrar pagos
Programar partidos
Asignar árbitros
Consultar reportes
```

## Árbitro

Puede:

```text
Consultar torneos y partidos
Iniciar partidos
Registrar asistencia
Registrar estadísticas
Finalizar partidos
Consultar resultados
```

## Jugador

Puede principalmente:

```text
Consultar perfil
Consultar equipo
Consultar torneos
Consultar partidos
Consultar resultados
Consultar estadísticas
```

En el backend, los permisos se aplican mediante dependencias como:

```python
requerir_roles_id(
    "ADMINISTRADOR",
    "ORGANIZADOR",
)
```

El administrador se considera acceso completo.

---

# 10. Flujo completo desde React hasta PostgreSQL

```text
Usuario abre React
        ↓
Envía correo y contraseña
        ↓
FastAPI valida el hash
        ↓
FastAPI genera JWT
        ↓
React guarda el token
        ↓
React envía Authorization: Bearer TOKEN
        ↓
FastAPI identifica al usuario
        ↓
FastAPI consulta roles activos
        ↓
Se verifica el permiso
        ↓
Se establece app.usuario_id
        ↓
Se llama función, procedimiento o consulta
        ↓
PostgreSQL aplica triggers y restricciones
        ↓
Se registra auditoría
        ↓
COMMIT
        ↓
FastAPI devuelve JSON
        ↓
React actualiza la interfaz
```

---

# 11. Estado real del proyecto

## Terminado o preparado

```text
Modelo PostgreSQL
Datos iniciales
Procedimientos
Funciones
Triggers
Auditoría
Vistas
Reportes
Transacciones
Pruebas SQL principales
FastAPI
Pool asincrónico
JWT
Roles
CORS
Swagger
Contrato API
Servicios base para React
```

## Pendiente

```text
Interfaz React completa
Páginas
Componentes
Rutas protegidas del frontend
Formularios
Tablas
Dashboard visual
Manejo visual de errores
Manual de usuario
Informe final
Distribución formal del trabajo entre 7 integrantes
```