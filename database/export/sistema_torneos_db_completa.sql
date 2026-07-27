--
-- PostgreSQL database dump
--

\restrict VaKjxPAfIgMj01fxTFF27XpzMsaikr0Qe9wuqTOs9pHIh1dxW6YOXcz0htDcAoa

-- Dumped from database version 16.14 (Ubuntu 16.14-0ubuntu0.24.04.1)
-- Dumped by pg_dump version 16.14 (Ubuntu 16.14-0ubuntu0.24.04.1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: auditoria; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA auditoria;


--
-- Name: SCHEMA auditoria; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA auditoria IS 'Contiene registros de auditoria y seguimiento de operaciones DML.';


--
-- Name: catalogo; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA catalogo;


--
-- Name: SCHEMA catalogo; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA catalogo IS 'Contiene estados, tipos y otros datos de referencia del sistema.';


--
-- Name: competencia; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA competencia;


--
-- Name: SCHEMA competencia; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA competencia IS 'Contiene deportes, torneos, inscripciones, jornadas y partidos.';


--
-- Name: finanzas; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA finanzas;


--
-- Name: SCHEMA finanzas; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA finanzas IS 'Contiene pagos, premios y entregas de premios.';


--
-- Name: participantes; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA participantes;


--
-- Name: SCHEMA participantes; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA participantes IS 'Contiene perfiles deportivos, equipos y membresias de jugadores.';


--
-- Name: reportes; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA reportes;


--
-- Name: SCHEMA reportes; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA reportes IS 'Contiene vistas y estructuras destinadas a reportes y estadisticas.';


--
-- Name: seguridad; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA seguridad;


--
-- Name: SCHEMA seguridad; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA seguridad IS 'Contiene usuarios, roles, permisos y datos relacionados con autenticacion.';


--
-- Name: fn_diferencias_jsonb(jsonb, jsonb); Type: FUNCTION; Schema: auditoria; Owner: -
--

CREATE FUNCTION auditoria.fn_diferencias_jsonb(p_datos_anteriores jsonb, p_datos_nuevos jsonb) RETURNS jsonb
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT COALESCE(
        JSONB_OBJECT_AGG(
            diferencias.columna,
            JSONB_BUILD_OBJECT(
                'anterior',
                diferencias.valor_anterior,
                'nuevo',
                diferencias.valor_nuevo
            )
        ),
        '{}'::JSONB
    )
    FROM (
        SELECT
            COALESCE(
                anterior.clave,
                nuevo.clave
            ) AS columna,

            anterior.valor
                AS valor_anterior,

            nuevo.valor
                AS valor_nuevo

        FROM JSONB_EACH(
            COALESCE(
                p_datos_anteriores,
                '{}'::JSONB
            )
        ) AS anterior (
            clave,
            valor
        )

        FULL OUTER JOIN JSONB_EACH(
            COALESCE(
                p_datos_nuevos,
                '{}'::JSONB
            )
        ) AS nuevo (
            clave,
            valor
        )
            ON nuevo.clave =
               anterior.clave

        WHERE anterior.valor
              IS DISTINCT FROM
              nuevo.valor
    ) AS diferencias;
$$;


--
-- Name: fn_historial_entrega_premio(); Type: FUNCTION; Schema: auditoria; Owner: -
--

CREATE FUNCTION auditoria.fn_historial_entrega_premio() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_usuario_aplicacion BIGINT;
BEGIN
    v_usuario_aplicacion :=
        COALESCE(
            NULLIF(
                CURRENT_SETTING(
                    'app.usuario_id',
                    TRUE
                ),
                ''
            )::BIGINT,
            NEW.entregado_por,
            NEW.autorizado_por
        );

    IF TG_OP = 'INSERT' THEN
        INSERT INTO auditoria.historial_entrega_premio (
            id_entrega_premio,
            id_estado_anterior,
            id_estado_nuevo,
            operacion,
            usuario_aplicacion,
            detalle
        )
        VALUES (
            NEW.id_entrega_premio,
            NULL,
            NEW.id_estado_entrega_premio,
            'INSERT',
            v_usuario_aplicacion,
            JSONB_BUILD_OBJECT(
                'id_torneo_premio',
                NEW.id_torneo_premio,
                'id_resultado_torneo',
                NEW.id_resultado_torneo
            )
        );

    ELSIF NEW.id_estado_entrega_premio <>
          OLD.id_estado_entrega_premio THEN

        INSERT INTO auditoria.historial_entrega_premio (
            id_entrega_premio,
            id_estado_anterior,
            id_estado_nuevo,
            operacion,
            usuario_aplicacion,
            detalle
        )
        VALUES (
            NEW.id_entrega_premio,
            OLD.id_estado_entrega_premio,
            NEW.id_estado_entrega_premio,
            'UPDATE',
            v_usuario_aplicacion,
            JSONB_BUILD_OBJECT(
                'fecha_autorizacion',
                NEW.fecha_autorizacion,
                'fecha_entrega',
                NEW.fecha_entrega
            )
        );
    END IF;

    RETURN NEW;
END;
$$;


--
-- Name: fn_historial_inscripcion(); Type: FUNCTION; Schema: auditoria; Owner: -
--

CREATE FUNCTION auditoria.fn_historial_inscripcion() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_usuario_aplicacion BIGINT;
BEGIN
    v_usuario_aplicacion :=
        COALESCE(
            NULLIF(
                CURRENT_SETTING(
                    'app.usuario_id',
                    TRUE
                ),
                ''
            )::BIGINT,
            NEW.registrado_por
        );

    IF TG_OP = 'INSERT' THEN
        INSERT INTO auditoria.historial_estado_inscripcion (
            id_inscripcion,
            id_estado_anterior,
            id_estado_nuevo,
            operacion,
            usuario_aplicacion,
            detalle
        )
        VALUES (
            NEW.id_inscripcion,
            NULL,
            NEW.id_estado_inscripcion,
            'INSERT',
            v_usuario_aplicacion,
            JSONB_BUILD_OBJECT(
                'monto_requerido',
                NEW.monto_requerido,
                'moneda',
                NEW.moneda
            )
        );

    ELSIF NEW.id_estado_inscripcion <>
          OLD.id_estado_inscripcion THEN

        INSERT INTO auditoria.historial_estado_inscripcion (
            id_inscripcion,
            id_estado_anterior,
            id_estado_nuevo,
            operacion,
            usuario_aplicacion,
            detalle
        )
        VALUES (
            NEW.id_inscripcion,
            OLD.id_estado_inscripcion,
            NEW.id_estado_inscripcion,
            'UPDATE',
            v_usuario_aplicacion,
            JSONB_BUILD_OBJECT(
                'fecha_actualizacion',
                NEW.fecha_actualizacion
            )
        );
    END IF;

    RETURN NEW;
END;
$$;


--
-- Name: fn_historial_pago(); Type: FUNCTION; Schema: auditoria; Owner: -
--

CREATE FUNCTION auditoria.fn_historial_pago() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_usuario_aplicacion BIGINT;
BEGIN
    v_usuario_aplicacion :=
        COALESCE(
            NULLIF(
                CURRENT_SETTING(
                    'app.usuario_id',
                    TRUE
                ),
                ''
            )::BIGINT,
            NEW.verificado_por,
            NEW.registrado_por
        );

    IF TG_OP = 'INSERT' THEN
        INSERT INTO auditoria.historial_estado_pago (
            id_pago,
            id_estado_anterior,
            id_estado_nuevo,
            operacion,
            usuario_aplicacion,
            detalle
        )
        VALUES (
            NEW.id_pago,
            NULL,
            NEW.id_estado_pago,
            'INSERT',
            v_usuario_aplicacion,
            JSONB_BUILD_OBJECT(
                'monto',
                NEW.monto,
                'moneda',
                NEW.moneda,
                'referencia',
                NEW.referencia
            )
        );

    ELSIF NEW.id_estado_pago <>
          OLD.id_estado_pago THEN

        INSERT INTO auditoria.historial_estado_pago (
            id_pago,
            id_estado_anterior,
            id_estado_nuevo,
            operacion,
            usuario_aplicacion,
            detalle
        )
        VALUES (
            NEW.id_pago,
            OLD.id_estado_pago,
            NEW.id_estado_pago,
            'UPDATE',
            v_usuario_aplicacion,
            JSONB_BUILD_OBJECT(
                'fecha_verificacion',
                NEW.fecha_verificacion
            )
        );
    END IF;

    RETURN NEW;
END;
$$;


--
-- Name: fn_historial_partido(); Type: FUNCTION; Schema: auditoria; Owner: -
--

CREATE FUNCTION auditoria.fn_historial_partido() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_usuario_aplicacion BIGINT;
    v_detalle_equipos JSONB;
BEGIN
    v_usuario_aplicacion :=
        COALESCE(
            NULLIF(
                CURRENT_SETTING(
                    'app.usuario_id',
                    TRUE
                ),
                ''
            )::BIGINT,
            NEW.actualizado_por,
            NEW.creado_por
        );

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id_partido_equipo',
                equipo.id_partido_equipo,
                'id_inscripcion',
                equipo.id_inscripcion,
                'marcador',
                equipo.marcador,
                'marcador_desempate',
                equipo.marcador_desempate,
                'puntos_tabla',
                equipo.puntos_tabla,
                'clasificado',
                equipo.clasificado
            )
            ORDER BY equipo.id_partido_equipo
        ),
        '[]'::JSONB
    )
    INTO v_detalle_equipos
    FROM competencia.partido_equipo equipo
    WHERE equipo.id_partido =
          NEW.id_partido;

    IF TG_OP = 'INSERT' THEN
        INSERT INTO auditoria.historial_estado_partido (
            id_partido,
            id_estado_anterior,
            id_estado_nuevo,
            operacion,
            usuario_aplicacion,
            detalle
        )
        VALUES (
            NEW.id_partido,
            NULL,
            NEW.id_estado_partido,
            'INSERT',
            v_usuario_aplicacion,
            JSONB_BUILD_OBJECT(
                'codigo',
                NEW.codigo,
                'fecha_hora_inicio',
                NEW.fecha_hora_inicio,
                'fecha_hora_fin',
                NEW.fecha_hora_fin,
                'equipos',
                v_detalle_equipos
            )
        );

    ELSIF NEW.id_estado_partido <>
          OLD.id_estado_partido THEN

        INSERT INTO auditoria.historial_estado_partido (
            id_partido,
            id_estado_anterior,
            id_estado_nuevo,
            operacion,
            usuario_aplicacion,
            detalle
        )
        VALUES (
            NEW.id_partido,
            OLD.id_estado_partido,
            NEW.id_estado_partido,
            'UPDATE',
            v_usuario_aplicacion,
            JSONB_BUILD_OBJECT(
                'fecha_hora_inicio',
                NEW.fecha_hora_inicio,
                'fecha_hora_fin',
                NEW.fecha_hora_fin,
                'equipos',
                v_detalle_equipos
            )
        );
    END IF;

    RETURN NEW;
END;
$$;


--
-- Name: fn_proteger_auditoria_dml(); Type: FUNCTION; Schema: auditoria; Owner: -
--

CREATE FUNCTION auditoria.fn_proteger_auditoria_dml() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    RAISE EXCEPTION
        'Los registros de auditoria no pueden modificarse ni eliminarse'
        USING ERRCODE = '42501';
END;
$$;


--
-- Name: FUNCTION fn_proteger_auditoria_dml(); Type: COMMENT; Schema: auditoria; Owner: -
--

COMMENT ON FUNCTION auditoria.fn_proteger_auditoria_dml() IS 'Impide modificaciones y eliminaciones directas sobre la auditoria.';


--
-- Name: fn_registrar_auditoria_dml(); Type: FUNCTION; Schema: auditoria; Owner: -
--

CREATE FUNCTION auditoria.fn_registrar_auditoria_dml() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'auditoria'
    AS $$
DECLARE
    v_configuracion RECORD;

    v_datos_anteriores JSONB;
    v_datos_nuevos JSONB;

    v_fila_identificador JSONB;
    v_identificador JSONB :=
        '{}'::JSONB;

    v_cambios JSONB;
    v_columnas_modificadas TEXT[];

    v_columna TEXT;

    v_usuario_aplicacion BIGINT;

    v_ip_cliente VARCHAR(64);
    v_id_solicitud VARCHAR(120);
    v_aplicacion VARCHAR(150);
BEGIN
    SELECT
        configuracion.columnas_pk,
        configuracion.columnas_excluidas,
        configuracion.auditar_insert,
        configuracion.auditar_update,
        configuracion.auditar_delete
    INTO
        v_configuracion
    FROM auditoria.configuracion_auditoria configuracion
    WHERE configuracion.esquema =
          TG_TABLE_SCHEMA
      AND configuracion.tabla =
          TG_TABLE_NAME
      AND configuracion.activo = TRUE;

    IF NOT FOUND THEN
        IF TG_OP = 'DELETE' THEN
            RETURN OLD;
        END IF;

        RETURN NEW;
    END IF;


    IF TG_OP = 'INSERT'
       AND v_configuracion.auditar_insert = FALSE THEN

        RETURN NEW;
    END IF;


    IF TG_OP = 'UPDATE'
       AND v_configuracion.auditar_update = FALSE THEN

        RETURN NEW;
    END IF;


    IF TG_OP = 'DELETE'
       AND v_configuracion.auditar_delete = FALSE THEN

        RETURN OLD;
    END IF;


    IF TG_OP = 'INSERT' THEN
        v_datos_anteriores := NULL;
        v_datos_nuevos := TO_JSONB(NEW);
        v_fila_identificador := TO_JSONB(NEW);

    ELSIF TG_OP = 'UPDATE' THEN
        v_datos_anteriores := TO_JSONB(OLD);
        v_datos_nuevos := TO_JSONB(NEW);
        v_fila_identificador := TO_JSONB(NEW);

    ELSIF TG_OP = 'DELETE' THEN
        v_datos_anteriores := TO_JSONB(OLD);
        v_datos_nuevos := NULL;
        v_fila_identificador := TO_JSONB(OLD);
    END IF;


    FOREACH v_columna IN ARRAY
        v_configuracion.columnas_excluidas
    LOOP
        IF v_datos_anteriores IS NOT NULL THEN
            v_datos_anteriores :=
                v_datos_anteriores
                - v_columna;
        END IF;

        IF v_datos_nuevos IS NOT NULL THEN
            v_datos_nuevos :=
                v_datos_nuevos
                - v_columna;
        END IF;
    END LOOP;


    FOREACH v_columna IN ARRAY
        v_configuracion.columnas_pk
    LOOP
        v_identificador :=
            v_identificador
            ||
            JSONB_BUILD_OBJECT(
                v_columna,
                v_fila_identificador
                -> v_columna
            );
    END LOOP;


    v_cambios :=
        auditoria.fn_diferencias_jsonb(
            v_datos_anteriores,
            v_datos_nuevos
        );


    IF TG_OP = 'UPDATE'
       AND v_cambios = '{}'::JSONB THEN

        RETURN NEW;
    END IF;


    SELECT COALESCE(
        ARRAY_AGG(
            columna
            ORDER BY columna
        ),
        ARRAY[]::TEXT[]
    )
    INTO v_columnas_modificadas
    FROM JSONB_OBJECT_KEYS(
        v_cambios
    ) AS diferencias(columna);


    BEGIN
        v_usuario_aplicacion :=
            NULLIF(
                CURRENT_SETTING(
                    'app.usuario_id',
                    TRUE
                ),
                ''
            )::BIGINT;

    EXCEPTION
        WHEN INVALID_TEXT_REPRESENTATION THEN
            v_usuario_aplicacion := NULL;
    END;


    v_ip_cliente :=
        COALESCE(
            NULLIF(
                CURRENT_SETTING(
                    'app.ip_cliente',
                    TRUE
                ),
                ''
            ),
            INET_CLIENT_ADDR()::TEXT
        );


    v_id_solicitud :=
        NULLIF(
            CURRENT_SETTING(
                'app.request_id',
                TRUE
            ),
            ''
        );


    v_aplicacion :=
        NULLIF(
            CURRENT_SETTING(
                'application_name',
                TRUE
            ),
            ''
        );


    INSERT INTO auditoria.auditoria_dml (
        esquema,
        tabla,
        operacion,

        identificador_registro,

        datos_anteriores,
        datos_nuevos,
        cambios,

        columnas_modificadas,

        usuario_aplicacion,
        usuario_postgresql,
        usuario_sesion,

        aplicacion,
        ip_cliente,
        id_solicitud,

        id_transaccion,
        pid_backend
    )
    VALUES (
        TG_TABLE_SCHEMA,
        TG_TABLE_NAME,
        TG_OP,

        v_identificador,

        v_datos_anteriores,
        v_datos_nuevos,
        v_cambios,

        v_columnas_modificadas,

        v_usuario_aplicacion,
        CURRENT_USER,
        SESSION_USER,

        v_aplicacion,
        v_ip_cliente,
        v_id_solicitud,

        TXID_CURRENT(),
        PG_BACKEND_PID()
    );


    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;

    RETURN NEW;
END;
$$;


--
-- Name: FUNCTION fn_registrar_auditoria_dml(); Type: COMMENT; Schema: auditoria; Owner: -
--

COMMENT ON FUNCTION auditoria.fn_registrar_auditoria_dml() IS 'Funcion generica utilizada por los triggers de auditoria DML.';


--
-- Name: sp_configurar_tabla_auditoria(name, name, boolean, boolean, boolean, boolean); Type: PROCEDURE; Schema: auditoria; Owner: -
--

CREATE PROCEDURE auditoria.sp_configurar_tabla_auditoria(IN p_esquema name, IN p_tabla name, IN p_activo boolean, IN p_auditar_insert boolean DEFAULT true, IN p_auditar_update boolean DEFAULT true, IN p_auditar_delete boolean DEFAULT true)
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE auditoria.configuracion_auditoria
    SET
        activo =
            p_activo,

        auditar_insert =
            p_auditar_insert,

        auditar_update =
            p_auditar_update,

        auditar_delete =
            p_auditar_delete

    WHERE esquema =
          p_esquema
      AND tabla =
          p_tabla;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'No existe configuracion de auditoria para %.%',
            p_esquema,
            p_tabla;
    END IF;

    CALL auditoria.sp_instalar_triggers_auditoria();
END;
$$;


--
-- Name: sp_instalar_triggers_auditoria(); Type: PROCEDURE; Schema: auditoria; Owner: -
--

CREATE PROCEDURE auditoria.sp_instalar_triggers_auditoria()
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_configuracion RECORD;

    cursor_configuraciones CURSOR FOR
        SELECT
            configuracion.esquema,
            configuracion.tabla,
            configuracion.activo
        FROM auditoria.configuracion_auditoria configuracion
        ORDER BY
            configuracion.esquema,
            configuracion.tabla;
BEGIN
    OPEN cursor_configuraciones;

    LOOP
        FETCH cursor_configuraciones
        INTO v_configuracion;

        EXIT WHEN NOT FOUND;


        IF TO_REGCLASS(
            FORMAT(
                '%I.%I',
                v_configuracion.esquema,
                v_configuracion.tabla
            )
        ) IS NULL THEN

            RAISE NOTICE
                'La tabla %.% no existe. Se omite.',
                v_configuracion.esquema,
                v_configuracion.tabla;

            CONTINUE;
        END IF;


        EXECUTE FORMAT(
            'DROP TRIGGER IF EXISTS trg_auditoria_dml ON %I.%I',
            v_configuracion.esquema,
            v_configuracion.tabla
        );


        IF v_configuracion.activo = TRUE THEN
            EXECUTE FORMAT(
                'CREATE TRIGGER trg_auditoria_dml
                 AFTER INSERT OR UPDATE OR DELETE
                 ON %I.%I
                 FOR EACH ROW
                 EXECUTE FUNCTION auditoria.fn_registrar_auditoria_dml()',
                v_configuracion.esquema,
                v_configuracion.tabla
            );

            RAISE NOTICE
                'Auditoria instalada en %.%',
                v_configuracion.esquema,
                v_configuracion.tabla;

        ELSE
            RAISE NOTICE
                'Auditoria desactivada en %.%',
                v_configuracion.esquema,
                v_configuracion.tabla;
        END IF;
    END LOOP;

    CLOSE cursor_configuraciones;
END;
$$;


--
-- Name: fn_calcular_resultado_partido(); Type: FUNCTION; Schema: competencia; Owner: -
--

CREATE FUNCTION competencia.fn_calcular_resultado_partido() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_estado_nuevo VARCHAR(40);
    v_tipo_fase VARCHAR(40);

    v_puntos_victoria SMALLINT;
    v_puntos_empate SMALLINT;
    v_puntos_derrota SMALLINT;

    v_id_equipo_a BIGINT;
    v_marcador_a INTEGER;
    v_desempate_a INTEGER;

    v_id_equipo_b BIGINT;
    v_marcador_b INTEGER;
    v_desempate_b INTEGER;

    v_id_ganador SMALLINT;
    v_id_perdedor SMALLINT;
    v_id_empate SMALLINT;

    v_clasifica_ganador BOOLEAN;
BEGIN
    SELECT codigo
    INTO v_estado_nuevo
    FROM catalogo.estado_partido
    WHERE id_estado_partido =
          NEW.id_estado_partido;

    IF v_estado_nuevo <> 'FINALIZADO' THEN
        RETURN NEW;
    END IF;

    SELECT
        tipo.codigo,
        deporte.puntos_victoria,
        deporte.puntos_empate,
        deporte.puntos_derrota
    INTO
        v_tipo_fase,
        v_puntos_victoria,
        v_puntos_empate,
        v_puntos_derrota
    FROM competencia.jornada jornada
    INNER JOIN competencia.fase_torneo fase
        ON fase.id_fase_torneo =
           jornada.id_fase_torneo
    INNER JOIN catalogo.tipo_fase tipo
        ON tipo.id_tipo_fase =
           fase.id_tipo_fase
    INNER JOIN competencia.torneo torneo
        ON torneo.id_torneo =
           fase.id_torneo
    INNER JOIN competencia.deporte deporte
        ON deporte.id_deporte =
           torneo.id_deporte
    WHERE jornada.id_jornada =
          NEW.id_jornada;

    SELECT
        id_resultado_equipo_partido
    INTO v_id_ganador
    FROM catalogo.resultado_equipo_partido
    WHERE codigo = 'GANADOR';

    SELECT
        id_resultado_equipo_partido
    INTO v_id_perdedor
    FROM catalogo.resultado_equipo_partido
    WHERE codigo = 'PERDEDOR';

    SELECT
        id_resultado_equipo_partido
    INTO v_id_empate
    FROM catalogo.resultado_equipo_partido
    WHERE codigo = 'EMPATE';

    SELECT
        id_partido_equipo,
        marcador,
        COALESCE(
            marcador_desempate,
            0
        )
    INTO
        v_id_equipo_a,
        v_marcador_a,
        v_desempate_a
    FROM competencia.partido_equipo
    WHERE id_partido =
          NEW.id_partido
    ORDER BY id_partido_equipo
    LIMIT 1;

    SELECT
        id_partido_equipo,
        marcador,
        COALESCE(
            marcador_desempate,
            0
        )
    INTO
        v_id_equipo_b,
        v_marcador_b,
        v_desempate_b
    FROM competencia.partido_equipo
    WHERE id_partido =
          NEW.id_partido
    ORDER BY id_partido_equipo
    OFFSET 1
    LIMIT 1;

    v_clasifica_ganador :=
        v_tipo_fase IN (
            'PARTIDO_UNICO',
            'ELIMINACION',
            'FINAL'
        );

    IF v_marcador_a > v_marcador_b
       OR (
            v_marcador_a = v_marcador_b
            AND v_desempate_a > v_desempate_b
       ) THEN

        UPDATE competencia.partido_equipo
        SET
            id_resultado_equipo_partido =
                v_id_ganador,
            puntos_tabla =
                v_puntos_victoria,
            clasificado =
                v_clasifica_ganador
        WHERE id_partido_equipo =
              v_id_equipo_a;

        UPDATE competencia.partido_equipo
        SET
            id_resultado_equipo_partido =
                v_id_perdedor,
            puntos_tabla =
                v_puntos_derrota,
            clasificado = FALSE
        WHERE id_partido_equipo =
              v_id_equipo_b;

    ELSIF v_marcador_b > v_marcador_a
       OR (
            v_marcador_a = v_marcador_b
            AND v_desempate_b > v_desempate_a
       ) THEN

        UPDATE competencia.partido_equipo
        SET
            id_resultado_equipo_partido =
                v_id_perdedor,
            puntos_tabla =
                v_puntos_derrota,
            clasificado = FALSE
        WHERE id_partido_equipo =
              v_id_equipo_a;

        UPDATE competencia.partido_equipo
        SET
            id_resultado_equipo_partido =
                v_id_ganador,
            puntos_tabla =
                v_puntos_victoria,
            clasificado =
                v_clasifica_ganador
        WHERE id_partido_equipo =
              v_id_equipo_b;

    ELSE
        UPDATE competencia.partido_equipo
        SET
            id_resultado_equipo_partido =
                v_id_empate,
            puntos_tabla =
                v_puntos_empate,
            clasificado = FALSE
        WHERE id_partido =
              NEW.id_partido;
    END IF;

    RETURN NEW;
END;
$$;


--
-- Name: fn_torneo_partido(bigint); Type: FUNCTION; Schema: competencia; Owner: -
--

CREATE FUNCTION competencia.fn_torneo_partido(p_id_partido bigint) RETURNS bigint
    LANGUAGE sql STABLE
    AS $$
    SELECT torneo.id_torneo
    FROM competencia.partido partido
    INNER JOIN competencia.jornada jornada
        ON jornada.id_jornada =
           partido.id_jornada
    INNER JOIN competencia.fase_torneo fase
        ON fase.id_fase_torneo =
           jornada.id_fase_torneo
    INNER JOIN competencia.torneo torneo
        ON torneo.id_torneo =
           fase.id_torneo
    WHERE partido.id_partido =
          p_id_partido;
$$;


--
-- Name: fn_validar_arbitro_partido(); Type: FUNCTION; Schema: competencia; Owner: -
--

CREATE FUNCTION competencia.fn_validar_arbitro_partido() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_id_torneo BIGINT;
    v_estado_partido VARCHAR(40);
    v_fecha_inicio TIMESTAMPTZ;
    v_fecha_fin TIMESTAMPTZ;
BEGIN
    SELECT
        competencia.fn_torneo_partido(
            partido.id_partido
        ),
        estado.codigo,
        partido.fecha_hora_inicio,
        partido.fecha_hora_fin
    INTO
        v_id_torneo,
        v_estado_partido,
        v_fecha_inicio,
        v_fecha_fin
    FROM competencia.partido partido
    INNER JOIN catalogo.estado_partido estado
        ON estado.id_estado_partido =
           partido.id_estado_partido
    WHERE partido.id_partido =
          NEW.id_partido;

    IF v_estado_partido IN (
        'FINALIZADO',
        'CANCELADO'
    ) THEN
        RAISE EXCEPTION
            'No se pueden asignar arbitros a un partido %',
            v_estado_partido;
    END IF;

    IF TG_OP = 'UPDATE'
       AND (
            NEW.id_partido <>
            OLD.id_partido
            OR NEW.id_arbitro <>
               OLD.id_arbitro
       ) THEN

        RAISE EXCEPTION
            'No se puede cambiar el partido o el arbitro de la asignacion';
    END IF;

    IF NEW.activo = TRUE
       AND NOT EXISTS (
            SELECT 1
            FROM competencia.usuario_torneo_rol asignacion
            INNER JOIN catalogo.rol_torneo rol
                ON rol.id_rol_torneo =
                   asignacion.id_rol_torneo
            WHERE asignacion.id_torneo =
                  v_id_torneo
              AND asignacion.id_usuario =
                  NEW.id_arbitro
              AND rol.codigo = 'ARBITRO'
              AND asignacion.activo = TRUE
              AND asignacion.fecha_fin IS NULL
       ) THEN

        RAISE EXCEPTION
            'El usuario no tiene rol de arbitro en este torneo';
    END IF;

    IF NEW.activo = TRUE
       AND v_fecha_inicio IS NOT NULL
       AND v_fecha_fin IS NOT NULL
       AND EXISTS (
            SELECT 1
            FROM competencia.arbitro_partido otro_arbitro
            INNER JOIN competencia.partido otro_partido
                ON otro_partido.id_partido =
                   otro_arbitro.id_partido
            INNER JOIN catalogo.estado_partido otro_estado
                ON otro_estado.id_estado_partido =
                   otro_partido.id_estado_partido
            WHERE otro_arbitro.id_arbitro =
                  NEW.id_arbitro
              AND otro_arbitro.activo = TRUE
              AND otro_arbitro.fecha_fin IS NULL
              AND otro_arbitro.id_arbitro_partido <>
                  COALESCE(
                      NEW.id_arbitro_partido,
                      0
                  )
              AND otro_partido.id_partido <>
                  NEW.id_partido
              AND otro_estado.codigo <>
                  'CANCELADO'
              AND otro_partido.fecha_hora_inicio
                  IS NOT NULL
              AND otro_partido.fecha_hora_fin
                  IS NOT NULL
              AND v_fecha_inicio <
                  otro_partido.fecha_hora_fin
              AND v_fecha_fin >
                  otro_partido.fecha_hora_inicio
       ) THEN

        RAISE EXCEPTION
            'El arbitro ya tiene otro partido en ese horario';
    END IF;

    RETURN NEW;
END;
$$;


--
-- Name: fn_validar_equipo_grupo(); Type: FUNCTION; Schema: competencia; Owner: -
--

CREATE FUNCTION competencia.fn_validar_equipo_grupo() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_fase_grupo BIGINT;
    v_torneo_fase BIGINT;
    v_tipo_fase VARCHAR(40);
    v_torneo_inscripcion BIGINT;
    v_estado_inscripcion VARCHAR(40);
    v_estado_torneo VARCHAR(40);
    v_maximo_equipos SMALLINT;
    v_cantidad_equipos INTEGER;
BEGIN
    SELECT
        grupo.id_fase_torneo,
        grupo.cantidad_maxima_equipos,
        tipo.codigo,
        torneo.id_torneo,
        estado_torneo.codigo
    INTO
        v_fase_grupo,
        v_maximo_equipos,
        v_tipo_fase,
        v_torneo_fase,
        v_estado_torneo
    FROM competencia.grupo_torneo grupo
    INNER JOIN competencia.fase_torneo fase
        ON fase.id_fase_torneo =
           grupo.id_fase_torneo
    INNER JOIN catalogo.tipo_fase tipo
        ON tipo.id_tipo_fase =
           fase.id_tipo_fase
    INNER JOIN competencia.torneo torneo
        ON torneo.id_torneo =
           fase.id_torneo
    INNER JOIN catalogo.estado_torneo estado_torneo
        ON estado_torneo.id_estado_torneo =
           torneo.id_estado_torneo
    WHERE grupo.id_grupo_torneo =
          NEW.id_grupo_torneo;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'El grupo seleccionado no existe';
    END IF;

    IF NEW.id_fase_torneo <> v_fase_grupo THEN
        RAISE EXCEPTION
            'El grupo no pertenece a la fase seleccionada';
    END IF;

    IF v_tipo_fase <> 'GRUPOS' THEN
        RAISE EXCEPTION
            'Solo una fase de grupos puede recibir equipos';
    END IF;

    SELECT
        inscripcion.id_torneo,
        estado.codigo
    INTO
        v_torneo_inscripcion,
        v_estado_inscripcion
    FROM competencia.inscripcion inscripcion
    INNER JOIN catalogo.estado_inscripcion estado
        ON estado.id_estado_inscripcion =
           inscripcion.id_estado_inscripcion
    WHERE inscripcion.id_inscripcion =
          NEW.id_inscripcion;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'La inscripcion seleccionada no existe';
    END IF;

    IF v_torneo_inscripcion <> v_torneo_fase THEN
        RAISE EXCEPTION
            'La inscripcion no pertenece al torneo de la fase';
    END IF;

    IF v_estado_inscripcion <> 'HABILITADA' THEN
        RAISE EXCEPTION
            'Solo las inscripciones habilitadas pueden asignarse a grupos';
    END IF;

    IF v_estado_torneo NOT IN (
        'INSCRIPCIONES_ABIERTAS',
        'INSCRIPCIONES_CERRADAS'
    ) THEN
        RAISE EXCEPTION
            'No se pueden modificar grupos cuando el torneo esta %',
            v_estado_torneo;
    END IF;

    SELECT COUNT(*)
    INTO v_cantidad_equipos
    FROM competencia.equipo_grupo equipo_grupo
    WHERE equipo_grupo.id_grupo_torneo =
          NEW.id_grupo_torneo
      AND equipo_grupo.id_equipo_grupo <>
          COALESCE(
              NEW.id_equipo_grupo,
              0
          );

    IF v_cantidad_equipos >= v_maximo_equipos THEN
        RAISE EXCEPTION
            'El grupo alcanzo el limite de % equipos',
            v_maximo_equipos;
    END IF;

    RETURN NEW;
END;
$$;


--
-- Name: fn_validar_fase_torneo(); Type: FUNCTION; Schema: competencia; Owner: -
--

CREATE FUNCTION competencia.fn_validar_fase_torneo() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_formato VARCHAR(40);
    v_tipo_fase VARCHAR(40);
    v_fecha_inicio_torneo DATE;
    v_fecha_fin_torneo DATE;
    v_cantidad_fases INTEGER;
BEGIN
    SELECT
        formato.codigo,
        torneo.fecha_inicio_torneo,
        torneo.fecha_fin_torneo
    INTO
        v_formato,
        v_fecha_inicio_torneo,
        v_fecha_fin_torneo
    FROM competencia.torneo torneo
    INNER JOIN catalogo.formato_torneo formato
        ON formato.id_formato_torneo =
           torneo.id_formato_torneo
    WHERE torneo.id_torneo = NEW.id_torneo;

    SELECT codigo
    INTO v_tipo_fase
    FROM catalogo.tipo_fase
    WHERE id_tipo_fase = NEW.id_tipo_fase;

    IF v_formato = 'PARTIDO_UNICO'
       AND v_tipo_fase <> 'PARTIDO_UNICO' THEN

        RAISE EXCEPTION
            'El formato PARTIDO_UNICO solo admite una fase PARTIDO_UNICO';
    END IF;

    IF v_formato = 'FASE_GRUPOS'
       AND v_tipo_fase <> 'GRUPOS' THEN

        RAISE EXCEPTION
            'El formato FASE_GRUPOS solo admite fases de grupos';
    END IF;

    IF v_formato = 'ELIMINACION_DIRECTA'
       AND v_tipo_fase NOT IN ('ELIMINACION', 'FINAL') THEN

        RAISE EXCEPTION
            'El formato ELIMINACION_DIRECTA no admite la fase %',
            v_tipo_fase;
    END IF;

    IF v_formato = 'GRUPOS_Y_LLAVES'
       AND v_tipo_fase NOT IN (
            'GRUPOS',
            'ELIMINACION',
            'FINAL'
       ) THEN

        RAISE EXCEPTION
            'El formato GRUPOS_Y_LLAVES no admite la fase %',
            v_tipo_fase;
    END IF;

    IF v_formato = 'PARTIDO_UNICO' THEN
        SELECT COUNT(*)
        INTO v_cantidad_fases
        FROM competencia.fase_torneo
        WHERE id_torneo = NEW.id_torneo
          AND id_fase_torneo
              <> COALESCE(NEW.id_fase_torneo, 0);

        IF v_cantidad_fases >= 1 THEN
            RAISE EXCEPTION
                'Un torneo de partido unico solo puede tener una fase';
        END IF;
    END IF;

    IF NEW.fecha_inicio IS NOT NULL
       AND NEW.fecha_inicio < v_fecha_inicio_torneo THEN

        RAISE EXCEPTION
            'La fase no puede iniciar antes que el torneo';
    END IF;

    IF NEW.fecha_fin IS NOT NULL
       AND NEW.fecha_fin > v_fecha_fin_torneo THEN

        RAISE EXCEPTION
            'La fase no puede finalizar despues que el torneo';
    END IF;

    RETURN NEW;
END;
$$;


--
-- Name: fn_validar_grupo_torneo(); Type: FUNCTION; Schema: competencia; Owner: -
--

CREATE FUNCTION competencia.fn_validar_grupo_torneo() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_tipo_fase VARCHAR(40);
BEGIN
    SELECT tipo.codigo
    INTO v_tipo_fase
    FROM competencia.fase_torneo fase
    INNER JOIN catalogo.tipo_fase tipo
        ON tipo.id_tipo_fase = fase.id_tipo_fase
    WHERE fase.id_fase_torneo = NEW.id_fase_torneo;

    IF v_tipo_fase <> 'GRUPOS' THEN
        RAISE EXCEPTION
            'Solo una fase de tipo GRUPOS puede contener grupos';
    END IF;

    RETURN NEW;
END;
$$;


--
-- Name: fn_validar_inscripcion(); Type: FUNCTION; Schema: competencia; Owner: -
--

CREATE FUNCTION competencia.fn_validar_inscripcion() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_estado_torneo VARCHAR(40);
    v_estado_equipo VARCHAR(40);
    v_maximo_equipos SMALLINT;
    v_costo_inscripcion NUMERIC(12, 2);
    v_moneda CHAR(3);
    v_cantidad_inscritos INTEGER;
BEGIN
    IF TG_OP = 'UPDATE' THEN
        IF NEW.id_torneo <> OLD.id_torneo
           OR NEW.id_equipo <> OLD.id_equipo THEN

            RAISE EXCEPTION
                'No se puede cambiar el torneo o el equipo de una inscripcion';
        END IF;
    END IF;

    SELECT
        estado.codigo,
        torneo.cantidad_maxima_equipos,
        torneo.costo_inscripcion,
        torneo.moneda
    INTO
        v_estado_torneo,
        v_maximo_equipos,
        v_costo_inscripcion,
        v_moneda
    FROM competencia.torneo torneo
    INNER JOIN catalogo.estado_torneo estado
        ON estado.id_estado_torneo =
           torneo.id_estado_torneo
    WHERE torneo.id_torneo = NEW.id_torneo;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'El torneo seleccionado no existe';
    END IF;

    SELECT estado.codigo
    INTO v_estado_equipo
    FROM participantes.equipo equipo
    INNER JOIN catalogo.estado_equipo estado
        ON estado.id_estado_equipo =
           equipo.id_estado_equipo
    WHERE equipo.id_equipo = NEW.id_equipo;

    IF v_estado_equipo <> 'ACTIVO' THEN
        RAISE EXCEPTION
            'Solo se pueden inscribir equipos activos';
    END IF;

    IF TG_OP = 'INSERT' THEN
        IF v_estado_torneo <> 'INSCRIPCIONES_ABIERTAS' THEN
            RAISE EXCEPTION
                'El torneo no tiene las inscripciones abiertas';
        END IF;

        SELECT COUNT(*)
        INTO v_cantidad_inscritos
        FROM competencia.inscripcion inscripcion
        INNER JOIN catalogo.estado_inscripcion estado
            ON estado.id_estado_inscripcion =
               inscripcion.id_estado_inscripcion
        WHERE inscripcion.id_torneo = NEW.id_torneo
          AND estado.codigo NOT IN (
              'RECHAZADA',
              'RETIRADA'
          );

        IF v_cantidad_inscritos >= v_maximo_equipos THEN
            RAISE EXCEPTION
                'El torneo alcanzo el limite de % equipos',
                v_maximo_equipos;
        END IF;

        NEW.monto_requerido := v_costo_inscripcion;
        NEW.moneda := v_moneda;
    ELSE
        IF NEW.monto_requerido <> OLD.monto_requerido
           OR NEW.moneda <> OLD.moneda THEN

            RAISE EXCEPTION
                'No se puede modificar el monto requerido ni la moneda';
        END IF;
    END IF;

    NEW.fecha_actualizacion := CURRENT_TIMESTAMP;

    RETURN NEW;
END;
$$;


--
-- Name: fn_validar_jornada(); Type: FUNCTION; Schema: competencia; Owner: -
--

CREATE FUNCTION competencia.fn_validar_jornada() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_fecha_inicio_fase DATE;
    v_fecha_fin_fase DATE;
BEGIN
    SELECT
        fase.fecha_inicio,
        fase.fecha_fin
    INTO
        v_fecha_inicio_fase,
        v_fecha_fin_fase
    FROM competencia.fase_torneo fase
    WHERE fase.id_fase_torneo = NEW.id_fase_torneo;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'La fase seleccionada no existe';
    END IF;

    IF NEW.fecha_inicio IS NOT NULL
       AND NEW.fecha_inicio::DATE < v_fecha_inicio_fase THEN

        RAISE EXCEPTION
            'La jornada no puede iniciar antes que la fase';
    END IF;

    IF NEW.fecha_fin IS NOT NULL
       AND NEW.fecha_fin::DATE > v_fecha_fin_fase THEN

        RAISE EXCEPTION
            'La jornada no puede finalizar despues que la fase';
    END IF;

    RETURN NEW;
END;
$$;


--
-- Name: fn_validar_jugador_inscripcion(); Type: FUNCTION; Schema: competencia; Owner: -
--

CREATE FUNCTION competencia.fn_validar_jugador_inscripcion() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_id_torneo BIGINT;
    v_id_equipo BIGINT;
    v_estado_torneo VARCHAR(40);
    v_estado_inscripcion VARCHAR(40);
    v_minimo_jugadores SMALLINT;
    v_maximo_jugadores SMALLINT;
    v_estado_membresia VARCHAR(40);
    v_jugador_membresia BIGINT;
    v_equipo_membresia BIGINT;
    v_fecha_fin_membresia DATE;
    v_cantidad_jugadores INTEGER;
BEGIN
    IF TG_OP = 'UPDATE' THEN
        IF NEW.id_inscripcion <> OLD.id_inscripcion
           OR NEW.id_jugador <> OLD.id_jugador
           OR NEW.id_jugador_equipo <>
              OLD.id_jugador_equipo THEN

            RAISE EXCEPTION
                'No se puede cambiar la inscripcion, jugador o membresia';
        END IF;
    END IF;

    SELECT
        inscripcion.id_torneo,
        inscripcion.id_equipo,
        estado_inscripcion.codigo,
        estado_torneo.codigo,
        torneo.cantidad_minima_jugadores,
        torneo.cantidad_maxima_jugadores
    INTO
        v_id_torneo,
        v_id_equipo,
        v_estado_inscripcion,
        v_estado_torneo,
        v_minimo_jugadores,
        v_maximo_jugadores
    FROM competencia.inscripcion inscripcion
    INNER JOIN catalogo.estado_inscripcion estado_inscripcion
        ON estado_inscripcion.id_estado_inscripcion =
           inscripcion.id_estado_inscripcion
    INNER JOIN competencia.torneo torneo
        ON torneo.id_torneo = inscripcion.id_torneo
    INNER JOIN catalogo.estado_torneo estado_torneo
        ON estado_torneo.id_estado_torneo =
           torneo.id_estado_torneo
    WHERE inscripcion.id_inscripcion =
          NEW.id_inscripcion;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'La inscripcion seleccionada no existe';
    END IF;

    IF v_estado_inscripcion IN (
        'RECHAZADA',
        'RETIRADA'
    ) THEN
        RAISE EXCEPTION
            'No se pueden registrar jugadores en una inscripcion %',
            v_estado_inscripcion;
    END IF;

    IF v_estado_torneo IN (
        'PROGRAMADO',
        'EN_CURSO',
        'FINALIZADO',
        'CANCELADO'
    ) THEN
        RAISE EXCEPTION
            'La nomina no puede modificarse cuando el torneo esta %',
            v_estado_torneo;
    END IF;

    SELECT
        membresia.id_jugador,
        membresia.id_equipo,
        membresia.fecha_fin,
        estado.codigo
    INTO
        v_jugador_membresia,
        v_equipo_membresia,
        v_fecha_fin_membresia,
        v_estado_membresia
    FROM participantes.jugador_equipo membresia
    INNER JOIN catalogo.estado_membresia estado
        ON estado.id_estado_membresia =
           membresia.id_estado_membresia
    WHERE membresia.id_jugador_equipo =
          NEW.id_jugador_equipo;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'La membresia del jugador no existe';
    END IF;

    IF v_jugador_membresia <> NEW.id_jugador THEN
        RAISE EXCEPTION
            'La membresia no pertenece al jugador seleccionado';
    END IF;

    IF v_equipo_membresia <> v_id_equipo THEN
        RAISE EXCEPTION
            'El jugador no pertenece al equipo inscrito';
    END IF;

    IF v_fecha_fin_membresia IS NOT NULL
       OR v_estado_membresia <> 'ACTIVA' THEN

        RAISE EXCEPTION
            'La membresia del jugador no se encuentra activa';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM competencia.jugador_inscripcion jugador
        INNER JOIN competencia.inscripcion otra_inscripcion
            ON otra_inscripcion.id_inscripcion =
               jugador.id_inscripcion
        WHERE otra_inscripcion.id_torneo = v_id_torneo
          AND otra_inscripcion.id_equipo <> v_id_equipo
          AND jugador.id_jugador = NEW.id_jugador
          AND jugador.fecha_baja IS NULL
          AND jugador.id_jugador_inscripcion <>
              COALESCE(
                  NEW.id_jugador_inscripcion,
                  0
              )
    ) THEN
        RAISE EXCEPTION
            'El jugador ya pertenece a otro equipo del mismo torneo';
    END IF;

    IF TG_OP = 'INSERT' THEN
        SELECT COUNT(*)
        INTO v_cantidad_jugadores
        FROM competencia.jugador_inscripcion jugador
        WHERE jugador.id_inscripcion =
              NEW.id_inscripcion
          AND jugador.fecha_baja IS NULL;

        IF v_cantidad_jugadores >=
           v_maximo_jugadores THEN

            RAISE EXCEPTION
                'La nomina alcanzo el limite de % jugadores',
                v_maximo_jugadores;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;


--
-- Name: fn_validar_jugador_partido(); Type: FUNCTION; Schema: competencia; Owner: -
--

CREATE FUNCTION competencia.fn_validar_jugador_partido() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_partido_equipo BIGINT;
    v_inscripcion_partido BIGINT;
    v_estado_partido VARCHAR(40);
    v_inscripcion_jugador BIGINT;
    v_estado_jugador VARCHAR(40);
    v_fecha_baja TIMESTAMPTZ;
BEGIN
    SELECT
        equipo.id_partido,
        equipo.id_inscripcion,
        estado.codigo
    INTO
        v_partido_equipo,
        v_inscripcion_partido,
        v_estado_partido
    FROM competencia.partido_equipo equipo
    INNER JOIN competencia.partido partido
        ON partido.id_partido =
           equipo.id_partido
    INNER JOIN catalogo.estado_partido estado
        ON estado.id_estado_partido =
           partido.id_estado_partido
    WHERE equipo.id_partido_equipo =
          NEW.id_partido_equipo;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'El equipo del partido no existe';
    END IF;

    IF NEW.id_partido <> v_partido_equipo THEN
        RAISE EXCEPTION
            'El equipo seleccionado no pertenece al partido';
    END IF;

    IF v_estado_partido NOT IN (
        'PROGRAMADO',
        'EN_CURSO'
    ) THEN
        RAISE EXCEPTION
            'No se puede modificar participacion en un partido %',
            v_estado_partido;
    END IF;

    IF TG_OP = 'UPDATE'
       AND (
            NEW.id_partido <>
            OLD.id_partido
            OR NEW.id_partido_equipo <>
               OLD.id_partido_equipo
            OR NEW.id_jugador_inscripcion <>
               OLD.id_jugador_inscripcion
       ) THEN

        RAISE EXCEPTION
            'No se puede cambiar el partido, equipo o jugador';
    END IF;

    SELECT
        jugador.id_inscripcion,
        estado.codigo,
        jugador.fecha_baja
    INTO
        v_inscripcion_jugador,
        v_estado_jugador,
        v_fecha_baja
    FROM competencia.jugador_inscripcion jugador
    INNER JOIN catalogo.estado_jugador_inscripcion estado
        ON estado.id_estado_jugador_inscripcion =
           jugador.id_estado_jugador_inscripcion
    WHERE jugador.id_jugador_inscripcion =
          NEW.id_jugador_inscripcion;

    IF v_inscripcion_jugador <>
       v_inscripcion_partido THEN

        RAISE EXCEPTION
            'El jugador no pertenece al equipo del partido';
    END IF;

    IF v_estado_jugador <> 'HABILITADO'
       OR v_fecha_baja IS NOT NULL THEN

        RAISE EXCEPTION
            'El jugador no se encuentra habilitado en la nomina';
    END IF;

    IF NEW.asistio = TRUE
       AND NEW.convocado = FALSE THEN

        RAISE EXCEPTION
            'Un jugador que asistio debe estar convocado';
    END IF;

    IF NEW.titular = TRUE
       AND (
            NEW.convocado = FALSE
            OR NEW.asistio = FALSE
       ) THEN

        RAISE EXCEPTION
            'Un titular debe estar convocado y haber asistido';
    END IF;

    NEW.fecha_actualizacion :=
        CURRENT_TIMESTAMP;

    RETURN NEW;
END;
$$;


--
-- Name: fn_validar_partido(); Type: FUNCTION; Schema: competencia; Owner: -
--

CREATE FUNCTION competencia.fn_validar_partido() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_id_fase BIGINT;
    v_id_torneo BIGINT;
    v_fecha_inicio_torneo DATE;
    v_fecha_fin_torneo DATE;
    v_estado_torneo VARCHAR(40);
    v_estado_partido_nuevo VARCHAR(40);
    v_estado_partido_anterior VARCHAR(40);
    v_fecha_inicio_jornada TIMESTAMPTZ;
    v_fecha_fin_jornada TIMESTAMPTZ;
    v_fase_grupo BIGINT;
    v_lugar_activo BOOLEAN;
    v_torneo_siguiente BIGINT;
BEGIN
    SELECT
        jornada.id_fase_torneo,
        fase.id_torneo,
        torneo.fecha_inicio_torneo,
        torneo.fecha_fin_torneo,
        estado_torneo.codigo,
        jornada.fecha_inicio,
        jornada.fecha_fin
    INTO
        v_id_fase,
        v_id_torneo,
        v_fecha_inicio_torneo,
        v_fecha_fin_torneo,
        v_estado_torneo,
        v_fecha_inicio_jornada,
        v_fecha_fin_jornada
    FROM competencia.jornada jornada
    INNER JOIN competencia.fase_torneo fase
        ON fase.id_fase_torneo =
           jornada.id_fase_torneo
    INNER JOIN competencia.torneo torneo
        ON torneo.id_torneo =
           fase.id_torneo
    INNER JOIN catalogo.estado_torneo estado_torneo
        ON estado_torneo.id_estado_torneo =
           torneo.id_estado_torneo
    WHERE jornada.id_jornada =
          NEW.id_jornada;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'La jornada seleccionada no existe';
    END IF;

    SELECT codigo
    INTO v_estado_partido_nuevo
    FROM catalogo.estado_partido
    WHERE id_estado_partido =
          NEW.id_estado_partido;

    IF TG_OP = 'UPDATE' THEN
        SELECT codigo
        INTO v_estado_partido_anterior
        FROM catalogo.estado_partido
        WHERE id_estado_partido =
              OLD.id_estado_partido;

        IF v_estado_partido_anterior IN (
            'FINALIZADO',
            'CANCELADO'
        ) THEN
            RAISE EXCEPTION
                'Un partido % no puede modificarse',
                v_estado_partido_anterior;
        END IF;
    END IF;

    IF v_estado_torneo IN (
        'FINALIZADO',
        'CANCELADO'
    ) THEN
        RAISE EXCEPTION
            'No se pueden modificar partidos de un torneo %',
            v_estado_torneo;
    END IF;

    IF NEW.id_grupo_torneo IS NOT NULL THEN
        SELECT id_fase_torneo
        INTO v_fase_grupo
        FROM competencia.grupo_torneo
        WHERE id_grupo_torneo =
              NEW.id_grupo_torneo;

        IF v_fase_grupo <> v_id_fase THEN
            RAISE EXCEPTION
                'El grupo no pertenece a la fase de la jornada';
        END IF;
    END IF;

    IF NEW.id_lugar IS NOT NULL THEN
        SELECT activo
        INTO v_lugar_activo
        FROM competencia.lugar
        WHERE id_lugar = NEW.id_lugar;

        IF v_lugar_activo = FALSE THEN
            RAISE EXCEPTION
                'El lugar seleccionado se encuentra inactivo';
        END IF;
    END IF;

    IF v_estado_partido_nuevo <> 'BORRADOR'
       AND (
            NEW.id_lugar IS NULL
            OR NEW.fecha_hora_inicio IS NULL
            OR NEW.fecha_hora_fin IS NULL
       ) THEN

        RAISE EXCEPTION
            'Un partido no borrador requiere fecha, hora y lugar';
    END IF;

    IF NEW.fecha_hora_inicio IS NOT NULL
       AND NEW.fecha_hora_inicio::DATE <
           v_fecha_inicio_torneo THEN

        RAISE EXCEPTION
            'El partido no puede iniciar antes que el torneo';
    END IF;

    IF NEW.fecha_hora_fin IS NOT NULL
       AND NEW.fecha_hora_fin::DATE >
           v_fecha_fin_torneo THEN

        RAISE EXCEPTION
            'El partido no puede finalizar despues que el torneo';
    END IF;

    IF v_fecha_inicio_jornada IS NOT NULL
       AND NEW.fecha_hora_inicio IS NOT NULL
       AND NEW.fecha_hora_inicio <
           v_fecha_inicio_jornada THEN

        RAISE EXCEPTION
            'El partido no puede iniciar antes que la jornada';
    END IF;

    IF v_fecha_fin_jornada IS NOT NULL
       AND NEW.fecha_hora_fin IS NOT NULL
       AND NEW.fecha_hora_fin >
           v_fecha_fin_jornada THEN

        RAISE EXCEPTION
            'El partido no puede finalizar despues que la jornada';
    END IF;

    IF NEW.id_partido_siguiente IS NOT NULL THEN
        v_torneo_siguiente :=
            competencia.fn_torneo_partido(
                NEW.id_partido_siguiente
            );

        IF v_torneo_siguiente <> v_id_torneo THEN
            RAISE EXCEPTION
                'El partido siguiente debe pertenecer al mismo torneo';
        END IF;
    END IF;

    IF NEW.id_lugar IS NOT NULL
       AND NEW.fecha_hora_inicio IS NOT NULL
       AND NEW.fecha_hora_fin IS NOT NULL
       AND EXISTS (
            SELECT 1
            FROM competencia.partido otro
            INNER JOIN catalogo.estado_partido estado
                ON estado.id_estado_partido =
                   otro.id_estado_partido
            WHERE otro.id_partido <>
                  COALESCE(
                      NEW.id_partido,
                      0
                  )
              AND otro.id_lugar =
                  NEW.id_lugar
              AND estado.codigo <> 'CANCELADO'
              AND otro.fecha_hora_inicio IS NOT NULL
              AND otro.fecha_hora_fin IS NOT NULL
              AND NEW.fecha_hora_inicio <
                  otro.fecha_hora_fin
              AND NEW.fecha_hora_fin >
                  otro.fecha_hora_inicio
       ) THEN

        RAISE EXCEPTION
            'El lugar ya tiene otro partido en ese horario';
    END IF;

    IF NEW.fecha_hora_inicio IS NOT NULL
       AND NEW.fecha_hora_fin IS NOT NULL
       AND EXISTS (
            SELECT 1
            FROM competencia.partido_equipo actual
            INNER JOIN competencia.inscripcion ins_actual
                ON ins_actual.id_inscripcion =
                   actual.id_inscripcion
            INNER JOIN competencia.partido_equipo otro_equipo
                ON otro_equipo.id_partido <>
                   actual.id_partido
            INNER JOIN competencia.inscripcion ins_otro
                ON ins_otro.id_inscripcion =
                   otro_equipo.id_inscripcion
            INNER JOIN competencia.partido otro
                ON otro.id_partido =
                   otro_equipo.id_partido
            INNER JOIN catalogo.estado_partido estado_otro
                ON estado_otro.id_estado_partido =
                   otro.id_estado_partido
            WHERE actual.id_partido =
                  COALESCE(
                      NEW.id_partido,
                      0
                  )
              AND ins_actual.id_equipo =
                  ins_otro.id_equipo
              AND estado_otro.codigo <> 'CANCELADO'
              AND otro.fecha_hora_inicio IS NOT NULL
              AND otro.fecha_hora_fin IS NOT NULL
              AND NEW.fecha_hora_inicio <
                  otro.fecha_hora_fin
              AND NEW.fecha_hora_fin >
                  otro.fecha_hora_inicio
       ) THEN

        RAISE EXCEPTION
            'Uno de los equipos ya tiene otro partido en ese horario';
    END IF;

    IF NEW.fecha_hora_inicio IS NOT NULL
       AND NEW.fecha_hora_fin IS NOT NULL
       AND EXISTS (
            SELECT 1
            FROM competencia.arbitro_partido actual
            INNER JOIN competencia.arbitro_partido otro_arbitro
                ON otro_arbitro.id_arbitro =
                   actual.id_arbitro
               AND otro_arbitro.id_partido <>
                   actual.id_partido
               AND otro_arbitro.activo = TRUE
               AND otro_arbitro.fecha_fin IS NULL
            INNER JOIN competencia.partido otro
                ON otro.id_partido =
                   otro_arbitro.id_partido
            INNER JOIN catalogo.estado_partido estado_otro
                ON estado_otro.id_estado_partido =
                   otro.id_estado_partido
            WHERE actual.id_partido =
                  COALESCE(
                      NEW.id_partido,
                      0
                  )
              AND actual.activo = TRUE
              AND actual.fecha_fin IS NULL
              AND estado_otro.codigo <> 'CANCELADO'
              AND otro.fecha_hora_inicio IS NOT NULL
              AND otro.fecha_hora_fin IS NOT NULL
              AND NEW.fecha_hora_inicio <
                  otro.fecha_hora_fin
              AND NEW.fecha_hora_fin >
                  otro.fecha_hora_inicio
       ) THEN

        RAISE EXCEPTION
            'Uno de los arbitros ya tiene otro partido en ese horario';
    END IF;

    NEW.fecha_actualizacion :=
        CURRENT_TIMESTAMP;

    RETURN NEW;
END;
$$;


--
-- Name: fn_validar_partido_equipo(); Type: FUNCTION; Schema: competencia; Owner: -
--

CREATE FUNCTION competencia.fn_validar_partido_equipo() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_id_torneo BIGINT;
    v_id_grupo BIGINT;
    v_estado_partido VARCHAR(40);
    v_fecha_inicio TIMESTAMPTZ;
    v_fecha_fin TIMESTAMPTZ;
    v_torneo_inscripcion BIGINT;
    v_id_equipo BIGINT;
    v_estado_inscripcion VARCHAR(40);
    v_cantidad_equipos INTEGER;
BEGIN
    SELECT
        competencia.fn_torneo_partido(
            partido.id_partido
        ),
        partido.id_grupo_torneo,
        estado.codigo,
        partido.fecha_hora_inicio,
        partido.fecha_hora_fin
    INTO
        v_id_torneo,
        v_id_grupo,
        v_estado_partido,
        v_fecha_inicio,
        v_fecha_fin
    FROM competencia.partido partido
    INNER JOIN catalogo.estado_partido estado
        ON estado.id_estado_partido =
           partido.id_estado_partido
    WHERE partido.id_partido =
          NEW.id_partido;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'El partido seleccionado no existe';
    END IF;

    IF v_estado_partido IN (
        'FINALIZADO',
        'CANCELADO'
    ) THEN
        RAISE EXCEPTION
            'No se pueden modificar equipos de un partido %',
            v_estado_partido;
    END IF;

    IF TG_OP = 'UPDATE' THEN
        IF NEW.id_partido <> OLD.id_partido
           OR NEW.id_inscripcion <>
              OLD.id_inscripcion
           OR NEW.id_condicion_equipo <>
              OLD.id_condicion_equipo THEN

            RAISE EXCEPTION
                'No se puede cambiar el partido, equipo o condicion';
        END IF;
    END IF;

    SELECT
        inscripcion.id_torneo,
        inscripcion.id_equipo,
        estado.codigo
    INTO
        v_torneo_inscripcion,
        v_id_equipo,
        v_estado_inscripcion
    FROM competencia.inscripcion inscripcion
    INNER JOIN catalogo.estado_inscripcion estado
        ON estado.id_estado_inscripcion =
           inscripcion.id_estado_inscripcion
    WHERE inscripcion.id_inscripcion =
          NEW.id_inscripcion;

    IF v_torneo_inscripcion <> v_id_torneo THEN
        RAISE EXCEPTION
            'El equipo no esta inscrito en el torneo del partido';
    END IF;

    IF v_estado_inscripcion <> 'HABILITADA' THEN
        RAISE EXCEPTION
            'Solo participan inscripciones habilitadas';
    END IF;

    IF TG_OP = 'INSERT' THEN
        SELECT COUNT(*)
        INTO v_cantidad_equipos
        FROM competencia.partido_equipo
        WHERE id_partido =
              NEW.id_partido;

        IF v_cantidad_equipos >= 2 THEN
            RAISE EXCEPTION
                'El partido ya tiene dos equipos';
        END IF;
    END IF;

    IF v_id_grupo IS NOT NULL
       AND NOT EXISTS (
            SELECT 1
            FROM competencia.equipo_grupo
            WHERE id_grupo_torneo =
                  v_id_grupo
              AND id_inscripcion =
                  NEW.id_inscripcion
       ) THEN

        RAISE EXCEPTION
            'El equipo no pertenece al grupo del partido';
    END IF;

    IF v_fecha_inicio IS NOT NULL
       AND v_fecha_fin IS NOT NULL
       AND EXISTS (
            SELECT 1
            FROM competencia.partido_equipo otro_equipo
            INNER JOIN competencia.inscripcion otra_inscripcion
                ON otra_inscripcion.id_inscripcion =
                   otro_equipo.id_inscripcion
            INNER JOIN competencia.partido otro_partido
                ON otro_partido.id_partido =
                   otro_equipo.id_partido
            INNER JOIN catalogo.estado_partido otro_estado
                ON otro_estado.id_estado_partido =
                   otro_partido.id_estado_partido
            WHERE otra_inscripcion.id_equipo =
                  v_id_equipo
              AND otro_partido.id_partido <>
                  NEW.id_partido
              AND otro_estado.codigo <>
                  'CANCELADO'
              AND otro_partido.fecha_hora_inicio
                  IS NOT NULL
              AND otro_partido.fecha_hora_fin
                  IS NOT NULL
              AND v_fecha_inicio <
                  otro_partido.fecha_hora_fin
              AND v_fecha_fin >
                  otro_partido.fecha_hora_inicio
       ) THEN

        RAISE EXCEPTION
            'El equipo ya tiene otro partido en ese horario';
    END IF;

    RETURN NEW;
END;
$$;


--
-- Name: fn_validar_resultado_torneo(); Type: FUNCTION; Schema: competencia; Owner: -
--

CREATE FUNCTION competencia.fn_validar_resultado_torneo() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_torneo_inscripcion BIGINT;
    v_estado_torneo VARCHAR(40);
BEGIN
    SELECT
        inscripcion.id_torneo
    INTO
        v_torneo_inscripcion
    FROM competencia.inscripcion inscripcion
    WHERE inscripcion.id_inscripcion =
          NEW.id_inscripcion;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'La inscripcion seleccionada no existe';
    END IF;

    IF v_torneo_inscripcion <> NEW.id_torneo THEN
        RAISE EXCEPTION
            'La inscripcion no pertenece al torneo';
    END IF;

    SELECT estado.codigo
    INTO v_estado_torneo
    FROM competencia.torneo torneo
    INNER JOIN catalogo.estado_torneo estado
        ON estado.id_estado_torneo =
           torneo.id_estado_torneo
    WHERE torneo.id_torneo =
          NEW.id_torneo;

    IF v_estado_torneo <> 'EN_CURSO' THEN
        RAISE EXCEPTION
            'Los resultados finales solo pueden generarse cuando el torneo esta EN_CURSO';
    END IF;

    IF TG_OP = 'UPDATE'
       AND (
            NEW.id_torneo <> OLD.id_torneo
            OR NEW.id_inscripcion <>
               OLD.id_inscripcion
       ) THEN

        RAISE EXCEPTION
            'No se puede cambiar el torneo o la inscripcion del resultado';
    END IF;

    NEW.diferencia_marcador :=
        NEW.marcador_favor
        - NEW.marcador_contra;

    RETURN NEW;
END;
$$;


--
-- Name: fn_validar_rol_torneo(); Type: FUNCTION; Schema: competencia; Owner: -
--

CREATE FUNCTION competencia.fn_validar_rol_torneo() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_codigo_rol VARCHAR(40);
    v_estado_torneo VARCHAR(40);
BEGIN
    IF NEW.activo = FALSE THEN
        RETURN NEW;
    END IF;

    SELECT codigo
    INTO v_codigo_rol
    FROM catalogo.rol_torneo
    WHERE id_rol_torneo = NEW.id_rol_torneo;

    SELECT estado.codigo
    INTO v_estado_torneo
    FROM competencia.torneo torneo
    INNER JOIN catalogo.estado_torneo estado
        ON estado.id_estado_torneo = torneo.id_estado_torneo
    WHERE torneo.id_torneo = NEW.id_torneo;

    IF v_estado_torneo IN ('FINALIZADO', 'CANCELADO') THEN
        RAISE EXCEPTION
            'No se pueden asignar roles a un torneo %',
            v_estado_torneo;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM seguridad.usuario_rol usuario_rol
        INNER JOIN seguridad.rol rol
            ON rol.id_rol = usuario_rol.id_rol
        WHERE usuario_rol.id_usuario = NEW.id_usuario
          AND rol.codigo = v_codigo_rol
          AND usuario_rol.activo = TRUE
          AND usuario_rol.fecha_fin IS NULL
    ) THEN
        RAISE EXCEPTION
            'El usuario no tiene asignado el rol general %',
            v_codigo_rol;
    END IF;

    IF v_codigo_rol = 'JUGADOR'
       AND NOT EXISTS (
            SELECT 1
            FROM participantes.jugador
            WHERE id_usuario = NEW.id_usuario
       ) THEN

        RAISE EXCEPTION
            'El usuario no tiene un perfil de jugador';
    END IF;

    IF v_codigo_rol = 'ARBITRO'
       AND NOT EXISTS (
            SELECT 1
            FROM participantes.arbitro
            WHERE id_usuario = NEW.id_usuario
       ) THEN

        RAISE EXCEPTION
            'El usuario no tiene un perfil de arbitro';
    END IF;

    IF v_codigo_rol = 'ORGANIZADOR'
       AND NOT EXISTS (
            SELECT 1
            FROM participantes.organizador
            WHERE id_usuario = NEW.id_usuario
       ) THEN

        RAISE EXCEPTION
            'El usuario no tiene un perfil de organizador';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM competencia.usuario_torneo_rol asignacion
        INNER JOIN catalogo.conflicto_rol_torneo conflicto
            ON (
                conflicto.id_rol_torneo_a
                    = LEAST(
                        NEW.id_rol_torneo,
                        asignacion.id_rol_torneo
                    )
                AND conflicto.id_rol_torneo_b
                    = GREATEST(
                        NEW.id_rol_torneo,
                        asignacion.id_rol_torneo
                    )
            )
        WHERE asignacion.id_torneo = NEW.id_torneo
          AND asignacion.id_usuario = NEW.id_usuario
          AND asignacion.activo = TRUE
          AND asignacion.fecha_fin IS NULL
          AND asignacion.id_usuario_torneo_rol
                <> COALESCE(
                    NEW.id_usuario_torneo_rol,
                    0
                )
    ) THEN
        RAISE EXCEPTION
            'El usuario ya tiene un rol incompatible dentro del torneo';
    END IF;

    RETURN NEW;
END;
$$;


--
-- Name: fn_validar_torneo(); Type: FUNCTION; Schema: competencia; Owner: -
--

CREATE FUNCTION competencia.fn_validar_torneo() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_formato VARCHAR(40);
    v_minimo_deporte SMALLINT;
    v_maximo_deporte SMALLINT;
BEGIN
    SELECT
        formato.codigo
    INTO
        v_formato
    FROM catalogo.formato_torneo formato
    WHERE formato.id_formato_torneo = NEW.id_formato_torneo;

    IF v_formato IS NULL THEN
        RAISE EXCEPTION
            'El formato de torneo seleccionado no existe';
    END IF;

    SELECT
        deporte.cantidad_minima_jugadores,
        deporte.cantidad_maxima_jugadores
    INTO
        v_minimo_deporte,
        v_maximo_deporte
    FROM competencia.deporte deporte
    WHERE deporte.id_deporte = NEW.id_deporte;

    IF NEW.cantidad_minima_jugadores < v_minimo_deporte THEN
        RAISE EXCEPTION
            'La cantidad minima de jugadores del torneo no puede ser menor que %',
            v_minimo_deporte;
    END IF;

    IF NEW.cantidad_maxima_jugadores > v_maximo_deporte THEN
        RAISE EXCEPTION
            'La cantidad maxima de jugadores del torneo no puede superar %',
            v_maximo_deporte;
    END IF;

    IF v_formato = 'PARTIDO_UNICO'
       AND NEW.cantidad_maxima_equipos <> 2 THEN

        RAISE EXCEPTION
            'Un torneo de partido unico debe permitir exactamente 2 equipos';
    END IF;

    NEW.fecha_actualizacion := CURRENT_TIMESTAMP;

    RETURN NEW;
END;
$$;


--
-- Name: fn_validar_transicion_inscripcion(); Type: FUNCTION; Schema: competencia; Owner: -
--

CREATE FUNCTION competencia.fn_validar_transicion_inscripcion() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_estado_anterior VARCHAR(40);
    v_estado_nuevo VARCHAR(40);
    v_estado_torneo VARCHAR(40);
    v_total_pagado NUMERIC(12, 2);
BEGIN
    IF NEW.id_estado_inscripcion =
       OLD.id_estado_inscripcion THEN

        RETURN NEW;
    END IF;

    SELECT codigo
    INTO v_estado_anterior
    FROM catalogo.estado_inscripcion
    WHERE id_estado_inscripcion =
          OLD.id_estado_inscripcion;

    SELECT codigo
    INTO v_estado_nuevo
    FROM catalogo.estado_inscripcion
    WHERE id_estado_inscripcion =
          NEW.id_estado_inscripcion;

    SELECT estado.codigo
    INTO v_estado_torneo
    FROM competencia.torneo torneo
    INNER JOIN catalogo.estado_torneo estado
        ON estado.id_estado_torneo =
           torneo.id_estado_torneo
    WHERE torneo.id_torneo = NEW.id_torneo;

    IF v_estado_anterior IN (
        'RECHAZADA',
        'RETIRADA'
    ) THEN
        RAISE EXCEPTION
            'Una inscripcion % no puede cambiar de estado',
            v_estado_anterior;
    END IF;

    IF v_estado_anterior = 'HABILITADA'
       AND v_estado_nuevo NOT IN ('RETIRADA') THEN

        RAISE EXCEPTION
            'Una inscripcion habilitada solo puede retirarse';
    END IF;

    IF v_estado_nuevo = 'HABILITADA' THEN
        v_total_pagado :=
            finanzas.fn_total_pagado_inscripcion(
                NEW.id_inscripcion
            );

        IF v_total_pagado < NEW.monto_requerido THEN
            RAISE EXCEPTION
                'La inscripcion no tiene el pago completo';
        END IF;
    END IF;

    IF v_estado_nuevo = 'RETIRADA'
       AND v_estado_torneo IN (
            'EN_CURSO',
            'FINALIZADO'
       ) THEN

        RAISE EXCEPTION
            'No se puede retirar un equipo de un torneo %',
            v_estado_torneo;
    END IF;

    RETURN NEW;
END;
$$;


--
-- Name: fn_validar_transicion_partido(); Type: FUNCTION; Schema: competencia; Owner: -
--

CREATE FUNCTION competencia.fn_validar_transicion_partido() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_estado_anterior VARCHAR(40);
    v_estado_nuevo VARCHAR(40);
    v_estado_torneo VARCHAR(40);
    v_tipo_fase VARCHAR(40);
    v_permite_empate BOOLEAN;
    v_transicion_valida BOOLEAN := FALSE;
    v_cantidad_equipos INTEGER;
    v_cantidad_arbitros_principales INTEGER;
    v_marcadores INTEGER[];
    v_desempates INTEGER[];
BEGIN
    IF NEW.id_estado_partido =
       OLD.id_estado_partido THEN
        RETURN NEW;
    END IF;

    SELECT codigo
    INTO v_estado_anterior
    FROM catalogo.estado_partido
    WHERE id_estado_partido =
          OLD.id_estado_partido;

    SELECT codigo
    INTO v_estado_nuevo
    FROM catalogo.estado_partido
    WHERE id_estado_partido =
          NEW.id_estado_partido;

    SELECT
        estado_torneo.codigo,
        tipo_fase.codigo,
        torneo.permite_empate
    INTO
        v_estado_torneo,
        v_tipo_fase,
        v_permite_empate
    FROM competencia.jornada jornada
    INNER JOIN competencia.fase_torneo fase
        ON fase.id_fase_torneo =
           jornada.id_fase_torneo
    INNER JOIN catalogo.tipo_fase tipo_fase
        ON tipo_fase.id_tipo_fase =
           fase.id_tipo_fase
    INNER JOIN competencia.torneo torneo
        ON torneo.id_torneo =
           fase.id_torneo
    INNER JOIN catalogo.estado_torneo estado_torneo
        ON estado_torneo.id_estado_torneo =
           torneo.id_estado_torneo
    WHERE jornada.id_jornada =
          NEW.id_jornada;

    v_transicion_valida :=
        CASE
            WHEN v_estado_anterior = 'BORRADOR'
                AND v_estado_nuevo IN (
                    'PROGRAMADO',
                    'CANCELADO'
                )
                THEN TRUE

            WHEN v_estado_anterior = 'PROGRAMADO'
                AND v_estado_nuevo IN (
                    'EN_CURSO',
                    'SUSPENDIDO',
                    'CANCELADO'
                )
                THEN TRUE

            WHEN v_estado_anterior = 'SUSPENDIDO'
                AND v_estado_nuevo IN (
                    'PROGRAMADO',
                    'EN_CURSO',
                    'CANCELADO'
                )
                THEN TRUE

            WHEN v_estado_anterior = 'EN_CURSO'
                AND v_estado_nuevo IN (
                    'FINALIZADO',
                    'SUSPENDIDO',
                    'CANCELADO'
                )
                THEN TRUE

            ELSE FALSE
        END;

    IF v_transicion_valida = FALSE THEN
        RAISE EXCEPTION
            'Transicion de partido no permitida: % -> %',
            v_estado_anterior,
            v_estado_nuevo;
    END IF;

    SELECT COUNT(*)
    INTO v_cantidad_equipos
    FROM competencia.partido_equipo
    WHERE id_partido =
          NEW.id_partido;

    IF v_estado_nuevo = 'PROGRAMADO' THEN
        IF v_cantidad_equipos <> 2 THEN
            RAISE EXCEPTION
                'Un partido programado debe tener exactamente 2 equipos';
        END IF;

        IF NEW.id_lugar IS NULL
           OR NEW.fecha_hora_inicio IS NULL
           OR NEW.fecha_hora_fin IS NULL THEN

            RAISE EXCEPTION
                'El partido programado requiere lugar y horario';
        END IF;

        IF v_estado_torneo NOT IN (
            'INSCRIPCIONES_CERRADAS',
            'PROGRAMADO',
            'EN_CURSO'
        ) THEN
            RAISE EXCEPTION
                'El torneo no esta listo para programar partidos';
        END IF;
    END IF;

    IF v_estado_nuevo IN (
        'EN_CURSO',
        'FINALIZADO'
    ) THEN
        IF v_estado_torneo <> 'EN_CURSO' THEN
            RAISE EXCEPTION
                'El torneo debe estar EN_CURSO';
        END IF;

        IF v_cantidad_equipos <> 2 THEN
            RAISE EXCEPTION
                'El partido debe tener exactamente 2 equipos';
        END IF;
    END IF;

    IF v_estado_nuevo = 'EN_CURSO' THEN
        SELECT COUNT(*)
        INTO v_cantidad_arbitros_principales
        FROM competencia.arbitro_partido arbitro
        INNER JOIN catalogo.tipo_arbitro_partido tipo
            ON tipo.id_tipo_arbitro_partido =
               arbitro.id_tipo_arbitro_partido
        WHERE arbitro.id_partido =
              NEW.id_partido
          AND tipo.codigo = 'PRINCIPAL'
          AND arbitro.activo = TRUE
          AND arbitro.fecha_fin IS NULL;

        IF v_cantidad_arbitros_principales <> 1 THEN
            RAISE EXCEPTION
                'El partido requiere exactamente un arbitro principal';
        END IF;
    END IF;

    IF v_estado_nuevo = 'FINALIZADO' THEN
        SELECT
            ARRAY_AGG(
                marcador
                ORDER BY id_partido_equipo
            ),
            ARRAY_AGG(
                COALESCE(
                    marcador_desempate,
                    0
                )
                ORDER BY id_partido_equipo
            )
        INTO
            v_marcadores,
            v_desempates
        FROM competencia.partido_equipo
        WHERE id_partido =
              NEW.id_partido;

        IF v_marcadores[1] IS NULL
           OR v_marcadores[2] IS NULL THEN

            RAISE EXCEPTION
                'Los dos equipos deben tener marcador';
        END IF;

        IF v_marcadores[1] = v_marcadores[2] THEN
            IF v_tipo_fase <> 'GRUPOS'
               OR v_permite_empate = FALSE THEN

                IF v_desempates[1] =
                   v_desempates[2] THEN

                    RAISE EXCEPTION
                        'El partido requiere un marcador de desempate';
                END IF;
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;


--
-- Name: fn_validar_transicion_torneo(); Type: FUNCTION; Schema: competencia; Owner: -
--

CREATE FUNCTION competencia.fn_validar_transicion_torneo() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_estado_anterior VARCHAR(40);
    v_estado_nuevo VARCHAR(40);
    v_transicion_valida BOOLEAN := FALSE;
BEGIN
    IF NEW.id_estado_torneo = OLD.id_estado_torneo THEN
        RETURN NEW;
    END IF;

    SELECT codigo
    INTO v_estado_anterior
    FROM catalogo.estado_torneo
    WHERE id_estado_torneo = OLD.id_estado_torneo;

    SELECT codigo
    INTO v_estado_nuevo
    FROM catalogo.estado_torneo
    WHERE id_estado_torneo = NEW.id_estado_torneo;

    v_transicion_valida :=
        CASE
            WHEN v_estado_anterior = 'BORRADOR'
                AND v_estado_nuevo IN (
                    'INSCRIPCIONES_ABIERTAS',
                    'CANCELADO'
                )
                THEN TRUE

            WHEN v_estado_anterior = 'INSCRIPCIONES_ABIERTAS'
                AND v_estado_nuevo IN (
                    'INSCRIPCIONES_CERRADAS',
                    'CANCELADO'
                )
                THEN TRUE

            WHEN v_estado_anterior = 'INSCRIPCIONES_CERRADAS'
                AND v_estado_nuevo IN (
                    'PROGRAMADO',
                    'CANCELADO'
                )
                THEN TRUE

            WHEN v_estado_anterior = 'PROGRAMADO'
                AND v_estado_nuevo IN (
                    'EN_CURSO',
                    'CANCELADO'
                )
                THEN TRUE

            WHEN v_estado_anterior = 'EN_CURSO'
                AND v_estado_nuevo IN (
                    'FINALIZADO',
                    'CANCELADO'
                )
                THEN TRUE

            ELSE FALSE
        END;

    IF v_transicion_valida = FALSE THEN
        RAISE EXCEPTION
            'Transicion de estado no permitida: % -> %',
            v_estado_anterior,
            v_estado_nuevo;
    END IF;

    RETURN NEW;
END;
$$;


--
-- Name: sp_agregar_jugador_inscripcion(bigint, bigint, smallint, boolean, boolean, bigint, character varying); Type: PROCEDURE; Schema: competencia; Owner: -
--

CREATE PROCEDURE competencia.sp_agregar_jugador_inscripcion(IN p_id_inscripcion bigint, IN p_id_jugador bigint, IN p_numero_camiseta smallint, IN p_es_capitan boolean, IN p_es_delegado boolean, IN p_registrado_por bigint, IN p_observaciones character varying DEFAULT NULL::character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_id_equipo BIGINT;
    v_id_jugador_equipo BIGINT;
    v_id_estado SMALLINT;
BEGIN
    SELECT id_equipo
    INTO v_id_equipo
    FROM competencia.inscripcion
    WHERE id_inscripcion =
          p_id_inscripcion;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'La inscripcion % no existe',
            p_id_inscripcion;
    END IF;

    SELECT membresia.id_jugador_equipo
    INTO v_id_jugador_equipo
    FROM participantes.jugador_equipo membresia
    INNER JOIN catalogo.estado_membresia estado
        ON estado.id_estado_membresia =
           membresia.id_estado_membresia
    WHERE membresia.id_jugador =
          p_id_jugador
      AND membresia.id_equipo =
          v_id_equipo
      AND membresia.fecha_fin IS NULL
      AND estado.codigo = 'ACTIVA';

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'El jugador no tiene una membresia activa con el equipo';
    END IF;

    SELECT id_estado_jugador_inscripcion
    INTO v_id_estado
    FROM catalogo.estado_jugador_inscripcion
    WHERE codigo = 'HABILITADO';

    INSERT INTO competencia.jugador_inscripcion (
        id_inscripcion,
        id_jugador,
        id_jugador_equipo,
        id_estado_jugador_inscripcion,
        numero_camiseta,
        es_capitan,
        es_delegado,
        registrado_por,
        observaciones
    )
    VALUES (
        p_id_inscripcion,
        p_id_jugador,
        v_id_jugador_equipo,
        v_id_estado,
        p_numero_camiseta,
        p_es_capitan,
        p_es_delegado,
        p_registrado_por,
        p_observaciones
    );
END;
$$;


--
-- Name: sp_asignar_arbitro_partido(bigint, bigint, character varying, bigint, character varying); Type: PROCEDURE; Schema: competencia; Owner: -
--

CREATE PROCEDURE competencia.sp_asignar_arbitro_partido(IN p_id_partido bigint, IN p_id_arbitro bigint, IN p_tipo_arbitro character varying, IN p_asignado_por bigint, IN p_observaciones character varying DEFAULT NULL::character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_id_tipo_arbitro SMALLINT;
BEGIN
    SELECT id_tipo_arbitro_partido
    INTO v_id_tipo_arbitro
    FROM catalogo.tipo_arbitro_partido
    WHERE codigo =
          UPPER(p_tipo_arbitro)
      AND activo = TRUE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'El tipo de arbitro % no existe',
            p_tipo_arbitro;
    END IF;

    INSERT INTO competencia.arbitro_partido (
        id_partido,
        id_arbitro,
        id_tipo_arbitro_partido,
        asignado_por,
        observaciones
    )
    VALUES (
        p_id_partido,
        p_id_arbitro,
        v_id_tipo_arbitro,
        p_asignado_por,
        p_observaciones
    );
END;
$$;


--
-- Name: sp_asignar_equipo_grupo(bigint, bigint, bigint, smallint, bigint, character varying); Type: PROCEDURE; Schema: competencia; Owner: -
--

CREATE PROCEDURE competencia.sp_asignar_equipo_grupo(IN p_id_fase_torneo bigint, IN p_id_grupo_torneo bigint, IN p_id_inscripcion bigint, IN p_posicion_sorteo smallint, IN p_asignado_por bigint, IN p_observaciones character varying DEFAULT NULL::character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO competencia.equipo_grupo (
        id_fase_torneo,
        id_grupo_torneo,
        id_inscripcion,
        posicion_sorteo,
        asignado_por,
        observaciones
    )
    VALUES (
        p_id_fase_torneo,
        p_id_grupo_torneo,
        p_id_inscripcion,
        p_posicion_sorteo,
        p_asignado_por,
        p_observaciones
    );
END;
$$;


--
-- Name: sp_finalizar_fase(bigint, bigint); Type: PROCEDURE; Schema: competencia; Owner: -
--

CREATE PROCEDURE competencia.sp_finalizar_fase(IN p_id_fase_torneo bigint, IN p_actualizado_por bigint)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_id_torneo BIGINT;
    v_estado_torneo VARCHAR(40);

    v_cantidad_partidos INTEGER;
    v_partidos_pendientes INTEGER;
    v_partidos_finalizados INTEGER;

    v_id_estado_finalizada SMALLINT;
BEGIN
    PERFORM SET_CONFIG(
        'app.usuario_id',
        p_actualizado_por::TEXT,
        TRUE
    );

    SELECT
        fase.id_torneo,
        estado.codigo
    INTO
        v_id_torneo,
        v_estado_torneo
    FROM competencia.fase_torneo fase
    INNER JOIN competencia.torneo torneo
        ON torneo.id_torneo =
           fase.id_torneo
    INNER JOIN catalogo.estado_torneo estado
        ON estado.id_estado_torneo =
           torneo.id_estado_torneo
    WHERE fase.id_fase_torneo =
          p_id_fase_torneo;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'La fase % no existe',
            p_id_fase_torneo;
    END IF;

    IF v_estado_torneo <> 'EN_CURSO' THEN
        RAISE EXCEPTION
            'El torneo debe estar EN_CURSO para finalizar una fase';
    END IF;

    SELECT
        COUNT(*),
        COUNT(*) FILTER (
            WHERE estado.codigo NOT IN (
                'FINALIZADO',
                'CANCELADO'
            )
        ),
        COUNT(*) FILTER (
            WHERE estado.codigo = 'FINALIZADO'
        )
    INTO
        v_cantidad_partidos,
        v_partidos_pendientes,
        v_partidos_finalizados
    FROM competencia.partido partido
    INNER JOIN competencia.jornada jornada
        ON jornada.id_jornada =
           partido.id_jornada
    INNER JOIN catalogo.estado_partido estado
        ON estado.id_estado_partido =
           partido.id_estado_partido
    WHERE jornada.id_fase_torneo =
          p_id_fase_torneo;

    IF v_cantidad_partidos = 0 THEN
        RAISE EXCEPTION
            'La fase no tiene partidos registrados';
    END IF;

    IF v_partidos_pendientes > 0 THEN
        RAISE EXCEPTION
            'La fase tiene % partidos pendientes',
            v_partidos_pendientes;
    END IF;

    IF v_partidos_finalizados = 0 THEN
        RAISE EXCEPTION
            'La fase debe tener al menos un partido finalizado';
    END IF;

    SELECT id_estado_fase
    INTO v_id_estado_finalizada
    FROM catalogo.estado_fase
    WHERE codigo = 'FINALIZADA';

    UPDATE competencia.fase_torneo
    SET id_estado_fase =
        v_id_estado_finalizada
    WHERE id_fase_torneo =
          p_id_fase_torneo;
END;
$$;


--
-- Name: sp_finalizar_partido(bigint, integer, integer, integer, integer, bigint, character varying); Type: PROCEDURE; Schema: competencia; Owner: -
--

CREATE PROCEDURE competencia.sp_finalizar_partido(IN p_id_partido bigint, IN p_marcador_local integer, IN p_marcador_visitante integer, IN p_marcador_desempate_local integer, IN p_marcador_desempate_visitante integer, IN p_actualizado_por bigint, IN p_observaciones character varying DEFAULT NULL::character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_estado_actual VARCHAR(40);
    v_id_estado_finalizado SMALLINT;
    v_id_condicion_local SMALLINT;
    v_id_condicion_visitante SMALLINT;
BEGIN
    SELECT estado.codigo
    INTO v_estado_actual
    FROM competencia.partido partido
    INNER JOIN catalogo.estado_partido estado
        ON estado.id_estado_partido =
           partido.id_estado_partido
    WHERE partido.id_partido =
          p_id_partido;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'El partido % no existe',
            p_id_partido;
    END IF;

    IF v_estado_actual <> 'EN_CURSO' THEN
        RAISE EXCEPTION
            'Solo se puede finalizar un partido EN_CURSO';
    END IF;

    SELECT id_condicion_equipo
    INTO v_id_condicion_local
    FROM catalogo.condicion_equipo_partido
    WHERE codigo = 'LOCAL';

    SELECT id_condicion_equipo
    INTO v_id_condicion_visitante
    FROM catalogo.condicion_equipo_partido
    WHERE codigo = 'VISITANTE';

    UPDATE competencia.partido_equipo
    SET
        marcador =
            p_marcador_local,
        marcador_desempate =
            p_marcador_desempate_local
    WHERE id_partido =
          p_id_partido
      AND id_condicion_equipo =
          v_id_condicion_local;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'El partido no tiene equipo local';
    END IF;

    UPDATE competencia.partido_equipo
    SET
        marcador =
            p_marcador_visitante,
        marcador_desempate =
            p_marcador_desempate_visitante
    WHERE id_partido =
          p_id_partido
      AND id_condicion_equipo =
          v_id_condicion_visitante;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'El partido no tiene equipo visitante';
    END IF;

    SELECT id_estado_partido
    INTO v_id_estado_finalizado
    FROM catalogo.estado_partido
    WHERE codigo = 'FINALIZADO';

    UPDATE competencia.partido
    SET
        id_estado_partido =
            v_id_estado_finalizado,
        actualizado_por =
            p_actualizado_por,
        observaciones =
            COALESCE(
                p_observaciones,
                observaciones
            )
    WHERE id_partido =
          p_id_partido;
END;
$$;


--
-- Name: sp_finalizar_torneo(bigint, bigint); Type: PROCEDURE; Schema: competencia; Owner: -
--

CREATE PROCEDURE competencia.sp_finalizar_torneo(IN p_id_torneo bigint, IN p_actualizado_por bigint)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_estado_actual VARCHAR(40);
    v_fases_pendientes INTEGER;
    v_partidos_pendientes INTEGER;
    v_partidos_finalizados INTEGER;
    v_id_estado_finalizado SMALLINT;
BEGIN
    PERFORM SET_CONFIG(
        'app.usuario_id',
        p_actualizado_por::TEXT,
        TRUE
    );

    SELECT estado.codigo
    INTO v_estado_actual
    FROM competencia.torneo torneo
    INNER JOIN catalogo.estado_torneo estado
        ON estado.id_estado_torneo =
           torneo.id_estado_torneo
    WHERE torneo.id_torneo =
          p_id_torneo;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'El torneo % no existe',
            p_id_torneo;
    END IF;

    IF v_estado_actual <> 'EN_CURSO' THEN
        RAISE EXCEPTION
            'Solo puede finalizarse un torneo EN_CURSO';
    END IF;

    SELECT COUNT(*)
    INTO v_fases_pendientes
    FROM competencia.fase_torneo fase
    INNER JOIN catalogo.estado_fase estado
        ON estado.id_estado_fase =
           fase.id_estado_fase
    WHERE fase.id_torneo =
          p_id_torneo
      AND estado.codigo <>
          'FINALIZADA';

    IF v_fases_pendientes > 0 THEN
        RAISE EXCEPTION
            'El torneo tiene % fases pendientes',
            v_fases_pendientes;
    END IF;

    SELECT
        COUNT(*) FILTER (
            WHERE estado.codigo NOT IN (
                'FINALIZADO',
                'CANCELADO'
            )
        ),
        COUNT(*) FILTER (
            WHERE estado.codigo = 'FINALIZADO'
        )
    INTO
        v_partidos_pendientes,
        v_partidos_finalizados
    FROM competencia.partido partido
    INNER JOIN competencia.jornada jornada
        ON jornada.id_jornada =
           partido.id_jornada
    INNER JOIN competencia.fase_torneo fase
        ON fase.id_fase_torneo =
           jornada.id_fase_torneo
    INNER JOIN catalogo.estado_partido estado
        ON estado.id_estado_partido =
           partido.id_estado_partido
    WHERE fase.id_torneo =
          p_id_torneo;

    IF v_partidos_pendientes > 0 THEN
        RAISE EXCEPTION
            'El torneo tiene % partidos pendientes',
            v_partidos_pendientes;
    END IF;

    IF v_partidos_finalizados = 0 THEN
        RAISE EXCEPTION
            'El torneo no tiene partidos finalizados';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM competencia.resultado_torneo
        WHERE id_torneo =
              p_id_torneo
    ) THEN
        CALL competencia.sp_generar_resultados_torneo(
            p_id_torneo,
            p_actualizado_por
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM competencia.resultado_torneo
        WHERE id_torneo =
              p_id_torneo
          AND posicion_final = 1
    ) THEN
        RAISE EXCEPTION
            'El torneo no tiene un campeon registrado';
    END IF;

    SELECT id_estado_torneo
    INTO v_id_estado_finalizado
    FROM catalogo.estado_torneo
    WHERE codigo = 'FINALIZADO';

    UPDATE competencia.torneo
    SET
        id_estado_torneo =
            v_id_estado_finalizado,
        fecha_actualizacion =
            CURRENT_TIMESTAMP
    WHERE id_torneo =
          p_id_torneo;
END;
$$;


--
-- Name: sp_generar_resultados_torneo(bigint, bigint); Type: PROCEDURE; Schema: competencia; Owner: -
--

CREATE PROCEDURE competencia.sp_generar_resultados_torneo(IN p_id_torneo bigint, IN p_generado_por bigint)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_formato VARCHAR(40);
    v_estado_torneo VARCHAR(40);

    v_cantidad_grupos INTEGER;
    v_id_grupo BIGINT;

    v_id_fase_final BIGINT;
    v_cantidad_partidos_finales INTEGER;
    v_id_partido_final BIGINT;

    v_posicion SMALLINT := 0;

    v_partidos_jugados BIGINT;
    v_partidos_ganados BIGINT;
    v_partidos_empatados BIGINT;
    v_partidos_perdidos BIGINT;
    v_marcador_favor BIGINT;
    v_marcador_contra BIGINT;
    v_diferencia BIGINT;
    v_puntos BIGINT;

    v_fila RECORD;

    cursor_posiciones CURSOR FOR
        SELECT *
        FROM reportes.fn_tabla_posiciones_grupo(
            v_id_grupo
        )
        ORDER BY posicion;

    cursor_final CURSOR FOR
        SELECT
            partido_equipo.id_inscripcion,
            resultado.codigo AS resultado
        FROM competencia.partido_equipo partido_equipo
        INNER JOIN catalogo.resultado_equipo_partido resultado
            ON resultado.id_resultado_equipo_partido =
               partido_equipo.id_resultado_equipo_partido
        WHERE partido_equipo.id_partido =
              v_id_partido_final
        ORDER BY
            CASE resultado.codigo
                WHEN 'GANADOR' THEN 1
                WHEN 'PERDEDOR' THEN 2
                ELSE 3
            END;
BEGIN
    PERFORM SET_CONFIG(
        'app.usuario_id',
        p_generado_por::TEXT,
        TRUE
    );

    IF EXISTS (
        SELECT 1
        FROM competencia.resultado_torneo
        WHERE id_torneo =
              p_id_torneo
    ) THEN
        RAISE EXCEPTION
            'El torneo ya tiene resultados finales registrados';
    END IF;

    SELECT
        formato.codigo,
        estado.codigo
    INTO
        v_formato,
        v_estado_torneo
    FROM competencia.torneo torneo
    INNER JOIN catalogo.formato_torneo formato
        ON formato.id_formato_torneo =
           torneo.id_formato_torneo
    INNER JOIN catalogo.estado_torneo estado
        ON estado.id_estado_torneo =
           torneo.id_estado_torneo
    WHERE torneo.id_torneo =
          p_id_torneo;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'El torneo % no existe',
            p_id_torneo;
    END IF;

    IF v_estado_torneo <> 'EN_CURSO' THEN
        RAISE EXCEPTION
            'El torneo debe estar EN_CURSO para generar resultados';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM competencia.fase_torneo fase
        INNER JOIN catalogo.estado_fase estado
            ON estado.id_estado_fase =
               fase.id_estado_fase
        WHERE fase.id_torneo =
              p_id_torneo
          AND estado.codigo <>
              'FINALIZADA'
    ) THEN
        RAISE EXCEPTION
            'Todas las fases deben estar finalizadas';
    END IF;

    IF v_formato = 'FASE_GRUPOS' THEN
        SELECT
            COUNT(*),
            MIN(grupo.id_grupo_torneo)
        INTO
            v_cantidad_grupos,
            v_id_grupo
        FROM competencia.grupo_torneo grupo
        INNER JOIN competencia.fase_torneo fase
            ON fase.id_fase_torneo =
               grupo.id_fase_torneo
        WHERE fase.id_torneo =
              p_id_torneo;

        IF v_cantidad_grupos <> 1 THEN
            RAISE EXCEPTION
                'Un torneo solamente de grupos requiere un unico grupo para generar posiciones generales automaticamente';
        END IF;

        OPEN cursor_posiciones;

        LOOP
            FETCH cursor_posiciones
            INTO v_fila;

            EXIT WHEN NOT FOUND;

            INSERT INTO competencia.resultado_torneo (
                id_torneo,
                id_inscripcion,
                posicion_final,
                partidos_jugados,
                partidos_ganados,
                partidos_empatados,
                partidos_perdidos,
                marcador_favor,
                marcador_contra,
                diferencia_marcador,
                puntos,
                generado_por
            )
            VALUES (
                p_id_torneo,
                v_fila.id_inscripcion,
                v_fila.posicion,
                v_fila.partidos_jugados,
                v_fila.partidos_ganados,
                v_fila.partidos_empatados,
                v_fila.partidos_perdidos,
                v_fila.marcador_favor,
                v_fila.marcador_contra,
                v_fila.diferencia_marcador,
                v_fila.puntos,
                p_generado_por
            );
        END LOOP;

        CLOSE cursor_posiciones;

    ELSE
        SELECT fase.id_fase_torneo
        INTO v_id_fase_final
        FROM competencia.fase_torneo fase
        WHERE fase.id_torneo =
              p_id_torneo
        ORDER BY fase.numero_orden DESC
        LIMIT 1;

        SELECT
            COUNT(*),
            MIN(partido.id_partido)
        INTO
            v_cantidad_partidos_finales,
            v_id_partido_final
        FROM competencia.partido partido
        INNER JOIN competencia.jornada jornada
            ON jornada.id_jornada =
               partido.id_jornada
        INNER JOIN catalogo.estado_partido estado
            ON estado.id_estado_partido =
               partido.id_estado_partido
        WHERE jornada.id_fase_torneo =
              v_id_fase_final
          AND estado.codigo =
              'FINALIZADO';

        IF v_cantidad_partidos_finales <> 1 THEN
            RAISE EXCEPTION
                'La ultima fase debe contener exactamente un partido finalizado';
        END IF;

        OPEN cursor_final;

        LOOP
            FETCH cursor_final
            INTO v_fila;

            EXIT WHEN NOT FOUND;

            v_posicion :=
                v_posicion + 1;

            SELECT *
            INTO
                v_partidos_jugados,
                v_partidos_ganados,
                v_partidos_empatados,
                v_partidos_perdidos,
                v_marcador_favor,
                v_marcador_contra,
                v_diferencia,
                v_puntos
            FROM reportes.fn_estadistica_inscripcion_torneo(
                p_id_torneo,
                v_fila.id_inscripcion
            );

            INSERT INTO competencia.resultado_torneo (
                id_torneo,
                id_inscripcion,
                posicion_final,
                partidos_jugados,
                partidos_ganados,
                partidos_empatados,
                partidos_perdidos,
                marcador_favor,
                marcador_contra,
                diferencia_marcador,
                puntos,
                generado_por
            )
            VALUES (
                p_id_torneo,
                v_fila.id_inscripcion,
                v_posicion,
                v_partidos_jugados,
                v_partidos_ganados,
                v_partidos_empatados,
                v_partidos_perdidos,
                v_marcador_favor,
                v_marcador_contra,
                v_diferencia,
                v_puntos,
                p_generado_por
            );
        END LOOP;

        CLOSE cursor_final;
    END IF;
END;
$$;


--
-- Name: sp_iniciar_partido(bigint, bigint); Type: PROCEDURE; Schema: competencia; Owner: -
--

CREATE PROCEDURE competencia.sp_iniciar_partido(IN p_id_partido bigint, IN p_actualizado_por bigint)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_id_estado_en_curso SMALLINT;
BEGIN
    SELECT id_estado_partido
    INTO v_id_estado_en_curso
    FROM catalogo.estado_partido
    WHERE codigo = 'EN_CURSO';

    UPDATE competencia.partido
    SET
        id_estado_partido =
            v_id_estado_en_curso,
        actualizado_por =
            p_actualizado_por
    WHERE id_partido =
          p_id_partido;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'El partido % no existe',
            p_id_partido;
    END IF;
END;
$$;


--
-- Name: sp_programar_partido(bigint, bigint, character varying, smallint, timestamp with time zone, timestamp with time zone, bigint, bigint, bigint, bigint, character varying, character varying); Type: PROCEDURE; Schema: competencia; Owner: -
--

CREATE PROCEDURE competencia.sp_programar_partido(IN p_id_jornada bigint, IN p_id_lugar bigint, IN p_codigo character varying, IN p_numero_partido smallint, IN p_fecha_hora_inicio timestamp with time zone, IN p_fecha_hora_fin timestamp with time zone, IN p_id_inscripcion_local bigint, IN p_id_inscripcion_visitante bigint, IN p_creado_por bigint, IN p_id_grupo_torneo bigint DEFAULT NULL::bigint, IN p_nombre_ronda character varying DEFAULT NULL::character varying, IN p_observaciones character varying DEFAULT NULL::character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_id_partido BIGINT;
    v_id_estado_borrador SMALLINT;
    v_id_estado_programado SMALLINT;
    v_id_condicion_local SMALLINT;
    v_id_condicion_visitante SMALLINT;
    v_id_resultado_pendiente SMALLINT;
BEGIN
    IF p_id_inscripcion_local =
       p_id_inscripcion_visitante THEN

        RAISE EXCEPTION
            'Un equipo no puede enfrentarse contra si mismo';
    END IF;

    SELECT id_estado_partido
    INTO v_id_estado_borrador
    FROM catalogo.estado_partido
    WHERE codigo = 'BORRADOR';

    SELECT id_estado_partido
    INTO v_id_estado_programado
    FROM catalogo.estado_partido
    WHERE codigo = 'PROGRAMADO';

    SELECT id_condicion_equipo
    INTO v_id_condicion_local
    FROM catalogo.condicion_equipo_partido
    WHERE codigo = 'LOCAL';

    SELECT id_condicion_equipo
    INTO v_id_condicion_visitante
    FROM catalogo.condicion_equipo_partido
    WHERE codigo = 'VISITANTE';

    SELECT id_resultado_equipo_partido
    INTO v_id_resultado_pendiente
    FROM catalogo.resultado_equipo_partido
    WHERE codigo = 'PENDIENTE';

    INSERT INTO competencia.partido (
        id_jornada,
        id_grupo_torneo,
        id_lugar,
        id_estado_partido,
        codigo,
        numero_partido,
        nombre_ronda,
        fecha_hora_inicio,
        fecha_hora_fin,
        creado_por,
        observaciones
    )
    VALUES (
        p_id_jornada,
        p_id_grupo_torneo,
        p_id_lugar,
        v_id_estado_borrador,
        UPPER(p_codigo),
        p_numero_partido,
        p_nombre_ronda,
        p_fecha_hora_inicio,
        p_fecha_hora_fin,
        p_creado_por,
        p_observaciones
    )
    RETURNING id_partido
    INTO v_id_partido;

    INSERT INTO competencia.partido_equipo (
        id_partido,
        id_inscripcion,
        id_condicion_equipo,
        id_resultado_equipo_partido
    )
    VALUES
        (
            v_id_partido,
            p_id_inscripcion_local,
            v_id_condicion_local,
            v_id_resultado_pendiente
        ),
        (
            v_id_partido,
            p_id_inscripcion_visitante,
            v_id_condicion_visitante,
            v_id_resultado_pendiente
        );

    UPDATE competencia.partido
    SET
        id_estado_partido =
            v_id_estado_programado,
        actualizado_por =
            p_creado_por
    WHERE id_partido =
          v_id_partido;
END;
$$;


--
-- Name: sp_registrar_inscripcion(bigint, bigint, bigint, character varying); Type: PROCEDURE; Schema: competencia; Owner: -
--

CREATE PROCEDURE competencia.sp_registrar_inscripcion(IN p_id_torneo bigint, IN p_id_equipo bigint, IN p_registrado_por bigint, IN p_observaciones character varying DEFAULT NULL::character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_id_estado SMALLINT;
BEGIN
    SELECT id_estado_inscripcion
    INTO v_id_estado
    FROM catalogo.estado_inscripcion
    WHERE codigo = 'PENDIENTE';

    INSERT INTO competencia.inscripcion (
        id_torneo,
        id_equipo,
        id_estado_inscripcion,
        monto_requerido,
        moneda,
        registrado_por,
        observaciones
    )
    VALUES (
        p_id_torneo,
        p_id_equipo,
        v_id_estado,
        0,
        'BOB',
        p_registrado_por,
        p_observaciones
    );
END;
$$;


--
-- Name: sp_registrar_participacion_jugador(bigint, bigint, boolean, boolean, boolean, smallint, integer, smallint, smallint, boolean, boolean, numeric, jsonb, bigint, character varying); Type: PROCEDURE; Schema: competencia; Owner: -
--

CREATE PROCEDURE competencia.sp_registrar_participacion_jugador(IN p_id_partido bigint, IN p_id_jugador_inscripcion bigint, IN p_convocado boolean, IN p_asistio boolean, IN p_titular boolean, IN p_minutos_jugados smallint, IN p_puntos_anotados integer, IN p_faltas smallint, IN p_amonestaciones smallint, IN p_expulsado boolean, IN p_lesionado boolean, IN p_calificacion numeric, IN p_estadisticas jsonb, IN p_registrado_por bigint, IN p_observaciones character varying DEFAULT NULL::character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_id_inscripcion BIGINT;
    v_id_partido_equipo BIGINT;
BEGIN
    SELECT id_inscripcion
    INTO v_id_inscripcion
    FROM competencia.jugador_inscripcion
    WHERE id_jugador_inscripcion =
          p_id_jugador_inscripcion;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'El jugador de la nomina no existe';
    END IF;

    SELECT id_partido_equipo
    INTO v_id_partido_equipo
    FROM competencia.partido_equipo
    WHERE id_partido =
          p_id_partido
      AND id_inscripcion =
          v_id_inscripcion;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'El equipo del jugador no participa en el partido';
    END IF;

    INSERT INTO competencia.jugador_partido (
        id_partido,
        id_partido_equipo,
        id_jugador_inscripcion,
        convocado,
        asistio,
        titular,
        minutos_jugados,
        puntos_anotados,
        faltas,
        amonestaciones,
        expulsado,
        lesionado,
        calificacion,
        estadisticas,
        registrado_por,
        observaciones
    )
    VALUES (
        p_id_partido,
        v_id_partido_equipo,
        p_id_jugador_inscripcion,
        p_convocado,
        p_asistio,
        p_titular,
        p_minutos_jugados,
        p_puntos_anotados,
        p_faltas,
        p_amonestaciones,
        p_expulsado,
        p_lesionado,
        p_calificacion,
        COALESCE(
            p_estadisticas,
            '{}'::JSONB
        ),
        p_registrado_por,
        p_observaciones
    )
    ON CONFLICT (
        id_partido,
        id_jugador_inscripcion
    )
    DO UPDATE SET
        convocado =
            EXCLUDED.convocado,
        asistio =
            EXCLUDED.asistio,
        titular =
            EXCLUDED.titular,
        minutos_jugados =
            EXCLUDED.minutos_jugados,
        puntos_anotados =
            EXCLUDED.puntos_anotados,
        faltas =
            EXCLUDED.faltas,
        amonestaciones =
            EXCLUDED.amonestaciones,
        expulsado =
            EXCLUDED.expulsado,
        lesionado =
            EXCLUDED.lesionado,
        calificacion =
            EXCLUDED.calificacion,
        estadisticas =
            EXCLUDED.estadisticas,
        registrado_por =
            EXCLUDED.registrado_por,
        observaciones =
            EXCLUDED.observaciones,
        fecha_actualizacion =
            CURRENT_TIMESTAMP;
END;
$$;


--
-- Name: sp_registrar_resultado_manual(bigint, bigint, smallint, bigint, character varying); Type: PROCEDURE; Schema: competencia; Owner: -
--

CREATE PROCEDURE competencia.sp_registrar_resultado_manual(IN p_id_torneo bigint, IN p_id_inscripcion bigint, IN p_posicion_final smallint, IN p_generado_por bigint, IN p_observaciones character varying DEFAULT NULL::character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_partidos_jugados BIGINT;
    v_partidos_ganados BIGINT;
    v_partidos_empatados BIGINT;
    v_partidos_perdidos BIGINT;
    v_marcador_favor BIGINT;
    v_marcador_contra BIGINT;
    v_diferencia BIGINT;
    v_puntos BIGINT;
BEGIN
    SELECT *
    INTO
        v_partidos_jugados,
        v_partidos_ganados,
        v_partidos_empatados,
        v_partidos_perdidos,
        v_marcador_favor,
        v_marcador_contra,
        v_diferencia,
        v_puntos
    FROM reportes.fn_estadistica_inscripcion_torneo(
        p_id_torneo,
        p_id_inscripcion
    );

    INSERT INTO competencia.resultado_torneo (
        id_torneo,
        id_inscripcion,
        posicion_final,
        partidos_jugados,
        partidos_ganados,
        partidos_empatados,
        partidos_perdidos,
        marcador_favor,
        marcador_contra,
        diferencia_marcador,
        puntos,
        generado_por,
        observaciones
    )
    VALUES (
        p_id_torneo,
        p_id_inscripcion,
        p_posicion_final,
        v_partidos_jugados,
        v_partidos_ganados,
        v_partidos_empatados,
        v_partidos_perdidos,
        v_marcador_favor,
        v_marcador_contra,
        v_diferencia,
        v_puntos,
        p_generado_por,
        p_observaciones
    );
END;
$$;


--
-- Name: fn_actualizar_inscripcion_por_pago(); Type: FUNCTION; Schema: finanzas; Owner: -
--

CREATE FUNCTION finanzas.fn_actualizar_inscripcion_por_pago() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_total_pagado NUMERIC(12, 2);
    v_monto_requerido NUMERIC(12, 2);
    v_estado_actual VARCHAR(40);
    v_nuevo_estado VARCHAR(40);
    v_id_nuevo_estado SMALLINT;
BEGIN
    SELECT
        inscripcion.monto_requerido,
        estado.codigo
    INTO
        v_monto_requerido,
        v_estado_actual
    FROM competencia.inscripcion inscripcion
    INNER JOIN catalogo.estado_inscripcion estado
        ON estado.id_estado_inscripcion =
           inscripcion.id_estado_inscripcion
    WHERE inscripcion.id_inscripcion =
          NEW.id_inscripcion;

    IF v_estado_actual IN (
        'RECHAZADA',
        'RETIRADA'
    ) THEN
        RETURN NEW;
    END IF;

    v_total_pagado :=
        finanzas.fn_total_pagado_inscripcion(
            NEW.id_inscripcion
        );

    IF v_total_pagado >= v_monto_requerido THEN
        v_nuevo_estado := 'HABILITADA';
    ELSIF v_total_pagado > 0 THEN
        v_nuevo_estado := 'PAGO_PENDIENTE';
    ELSE
        v_nuevo_estado := 'PENDIENTE';
    END IF;

    IF v_estado_actual <> v_nuevo_estado THEN
        SELECT id_estado_inscripcion
        INTO v_id_nuevo_estado
        FROM catalogo.estado_inscripcion
        WHERE codigo = v_nuevo_estado;

        UPDATE competencia.inscripcion
        SET
            id_estado_inscripcion =
                v_id_nuevo_estado,
            fecha_actualizacion =
                CURRENT_TIMESTAMP
        WHERE id_inscripcion =
              NEW.id_inscripcion;
    END IF;

    RETURN NEW;
END;
$$;


--
-- Name: fn_saldo_inscripcion(bigint); Type: FUNCTION; Schema: finanzas; Owner: -
--

CREATE FUNCTION finanzas.fn_saldo_inscripcion(p_id_inscripcion bigint) RETURNS numeric
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
    v_monto_requerido NUMERIC(12, 2);
    v_total_pagado NUMERIC(12, 2);
BEGIN
    SELECT monto_requerido
    INTO v_monto_requerido
    FROM competencia.inscripcion
    WHERE id_inscripcion = p_id_inscripcion;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'La inscripcion % no existe',
            p_id_inscripcion;
    END IF;

    v_total_pagado :=
        finanzas.fn_total_pagado_inscripcion(
            p_id_inscripcion
        );

    RETURN GREATEST(
        v_monto_requerido - v_total_pagado,
        0
    );
END;
$$;


--
-- Name: fn_total_pagado_inscripcion(bigint); Type: FUNCTION; Schema: finanzas; Owner: -
--

CREATE FUNCTION finanzas.fn_total_pagado_inscripcion(p_id_inscripcion bigint) RETURNS numeric
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
    v_total NUMERIC(12, 2);
BEGIN
    SELECT COALESCE(SUM(pago.monto), 0)
    INTO v_total
    FROM finanzas.pago pago
    INNER JOIN catalogo.estado_pago estado
        ON estado.id_estado_pago = pago.id_estado_pago
    WHERE pago.id_inscripcion = p_id_inscripcion
      AND estado.codigo = 'CONFIRMADO';

    RETURN v_total;
END;
$$;


--
-- Name: fn_validar_entrega_premio(); Type: FUNCTION; Schema: finanzas; Owner: -
--

CREATE FUNCTION finanzas.fn_validar_entrega_premio() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_id_torneo_premio BIGINT;
    v_posicion_objetivo SMALLINT;

    v_id_torneo_resultado BIGINT;
    v_posicion_resultado SMALLINT;

    v_estado_torneo VARCHAR(40);
    v_estado_anterior VARCHAR(40);
    v_estado_nuevo VARCHAR(40);

    v_transicion_valida BOOLEAN := FALSE;
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION
            'Las entregas de premios no pueden eliminarse';
    END IF;

    SELECT
        torneo_premio.id_torneo,
        torneo_premio.posicion_objetivo
    INTO
        v_id_torneo_premio,
        v_posicion_objetivo
    FROM finanzas.torneo_premio torneo_premio
    WHERE torneo_premio.id_torneo_premio =
          NEW.id_torneo_premio;

    SELECT
        resultado.id_torneo,
        resultado.posicion_final
    INTO
        v_id_torneo_resultado,
        v_posicion_resultado
    FROM competencia.resultado_torneo resultado
    WHERE resultado.id_resultado_torneo =
          NEW.id_resultado_torneo;

    IF v_id_torneo_premio <>
       v_id_torneo_resultado THEN

        RAISE EXCEPTION
            'El premio y el resultado pertenecen a torneos diferentes';
    END IF;

    IF v_posicion_objetivo <>
       v_posicion_resultado THEN

        RAISE EXCEPTION
            'La posicion del ganador no coincide con la posicion premiada';
    END IF;

    SELECT estado.codigo
    INTO v_estado_torneo
    FROM competencia.torneo torneo
    INNER JOIN catalogo.estado_torneo estado
        ON estado.id_estado_torneo =
           torneo.id_estado_torneo
    WHERE torneo.id_torneo =
          v_id_torneo_premio;

    SELECT codigo
    INTO v_estado_nuevo
    FROM catalogo.estado_entrega_premio
    WHERE id_estado_entrega_premio =
          NEW.id_estado_entrega_premio;

    IF TG_OP = 'UPDATE' THEN
        IF NEW.id_torneo_premio <>
           OLD.id_torneo_premio
           OR NEW.id_resultado_torneo <>
              OLD.id_resultado_torneo THEN

            RAISE EXCEPTION
                'No se puede cambiar el premio o el resultado de una entrega';
        END IF;

        SELECT codigo
        INTO v_estado_anterior
        FROM catalogo.estado_entrega_premio
        WHERE id_estado_entrega_premio =
              OLD.id_estado_entrega_premio;

        IF v_estado_anterior =
           v_estado_nuevo THEN

            NEW.fecha_actualizacion :=
                CURRENT_TIMESTAMP;

            RETURN NEW;
        END IF;

        v_transicion_valida :=
            CASE
                WHEN v_estado_anterior = 'PENDIENTE'
                     AND v_estado_nuevo IN (
                         'AUTORIZADO',
                         'ANULADO'
                     )
                    THEN TRUE

                WHEN v_estado_anterior = 'AUTORIZADO'
                     AND v_estado_nuevo IN (
                         'ENTREGADO',
                         'ANULADO'
                     )
                    THEN TRUE

                ELSE FALSE
            END;

        IF v_transicion_valida = FALSE THEN
            RAISE EXCEPTION
                'Transicion de entrega no permitida: % -> %',
                v_estado_anterior,
                v_estado_nuevo;
        END IF;
    END IF;

    IF v_estado_nuevo IN (
        'AUTORIZADO',
        'ENTREGADO'
    )
       AND v_estado_torneo <>
           'FINALIZADO' THEN

        RAISE EXCEPTION
            'El torneo debe estar FINALIZADO para autorizar o entregar premios';
    END IF;

    IF v_estado_nuevo = 'PENDIENTE' THEN
        NEW.autorizado_por := NULL;
        NEW.entregado_por := NULL;
        NEW.fecha_autorizacion := NULL;
        NEW.fecha_entrega := NULL;

    ELSIF v_estado_nuevo = 'AUTORIZADO' THEN
        IF NEW.autorizado_por IS NULL THEN
            RAISE EXCEPTION
                'La autorizacion requiere un usuario responsable';
        END IF;

        NEW.fecha_autorizacion :=
            COALESCE(
                NEW.fecha_autorizacion,
                CURRENT_TIMESTAMP
            );

        NEW.entregado_por := NULL;
        NEW.fecha_entrega := NULL;

    ELSIF v_estado_nuevo = 'ENTREGADO' THEN
        IF NEW.autorizado_por IS NULL
           OR NEW.fecha_autorizacion IS NULL THEN

            RAISE EXCEPTION
                'El premio debe estar autorizado antes de ser entregado';
        END IF;

        IF NEW.entregado_por IS NULL THEN
            RAISE EXCEPTION
                'La entrega requiere un usuario responsable';
        END IF;

        NEW.fecha_entrega :=
            COALESCE(
                NEW.fecha_entrega,
                CURRENT_TIMESTAMP
            );
    END IF;

    NEW.fecha_actualizacion :=
        CURRENT_TIMESTAMP;

    RETURN NEW;
END;
$$;


--
-- Name: fn_validar_pago(); Type: FUNCTION; Schema: finanzas; Owner: -
--

CREATE FUNCTION finanzas.fn_validar_pago() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_estado_pago_nuevo VARCHAR(40);
    v_estado_pago_anterior VARCHAR(40);
    v_estado_inscripcion VARCHAR(40);
    v_monto_requerido NUMERIC(12, 2);
    v_moneda CHAR(3);
    v_total_confirmado NUMERIC(12, 2);
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION
            'Los pagos no se eliminan; deben conservarse por auditoria';
    END IF;

    SELECT codigo
    INTO v_estado_pago_nuevo
    FROM catalogo.estado_pago
    WHERE id_estado_pago = NEW.id_estado_pago;

    SELECT
        estado.codigo,
        inscripcion.monto_requerido,
        inscripcion.moneda
    INTO
        v_estado_inscripcion,
        v_monto_requerido,
        v_moneda
    FROM competencia.inscripcion inscripcion
    INNER JOIN catalogo.estado_inscripcion estado
        ON estado.id_estado_inscripcion =
           inscripcion.id_estado_inscripcion
    WHERE inscripcion.id_inscripcion =
          NEW.id_inscripcion;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'La inscripcion seleccionada no existe';
    END IF;

    IF v_estado_inscripcion IN (
        'RECHAZADA',
        'RETIRADA'
    ) THEN
        RAISE EXCEPTION
            'No se pueden registrar pagos para una inscripcion %',
            v_estado_inscripcion;
    END IF;

    IF TG_OP = 'UPDATE' THEN
        SELECT codigo
        INTO v_estado_pago_anterior
        FROM catalogo.estado_pago
        WHERE id_estado_pago =
              OLD.id_estado_pago;

        IF v_estado_pago_anterior = 'CONFIRMADO' THEN
            RAISE EXCEPTION
                'Un pago confirmado no puede modificarse';
        END IF;

        IF NEW.id_inscripcion <>
           OLD.id_inscripcion THEN

            RAISE EXCEPTION
                'No se puede cambiar la inscripcion de un pago';
        END IF;

        IF NEW.monto <> OLD.monto
           OR NEW.moneda <> OLD.moneda THEN

            RAISE EXCEPTION
                'No se puede modificar el monto ni la moneda del pago';
        END IF;

        IF v_estado_pago_anterior IN (
            'RECHAZADO',
            'ANULADO'
        ) THEN
            RAISE EXCEPTION
                'Un pago % no puede cambiar de estado',
                v_estado_pago_anterior;
        END IF;
    END IF;

    NEW.moneda := v_moneda;
    NEW.fecha_actualizacion := CURRENT_TIMESTAMP;

    IF v_estado_pago_nuevo = 'CONFIRMADO' THEN
        IF NEW.verificado_por IS NULL THEN
            RAISE EXCEPTION
                'Un pago confirmado requiere un usuario verificador';
        END IF;

        IF NEW.fecha_verificacion IS NULL THEN
            NEW.fecha_verificacion :=
                CURRENT_TIMESTAMP;
        END IF;

        SELECT COALESCE(SUM(pago.monto), 0)
        INTO v_total_confirmado
        FROM finanzas.pago pago
        INNER JOIN catalogo.estado_pago estado
            ON estado.id_estado_pago =
               pago.id_estado_pago
        WHERE pago.id_inscripcion =
              NEW.id_inscripcion
          AND estado.codigo = 'CONFIRMADO'
          AND pago.id_pago <>
              COALESCE(NEW.id_pago, 0);

        IF v_total_confirmado + NEW.monto >
           v_monto_requerido THEN

            RAISE EXCEPTION
                'El pago excede el saldo pendiente de la inscripcion';
        END IF;
    ELSE
        NEW.verificado_por := NULL;
        NEW.fecha_verificacion := NULL;
    END IF;

    RETURN NEW;
END;
$$;


--
-- Name: fn_validar_torneo_premio(); Type: FUNCTION; Schema: finanzas; Owner: -
--

CREATE FUNCTION finanzas.fn_validar_torneo_premio() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_estado_torneo VARCHAR(40);
    v_tipo_premio VARCHAR(40);
BEGIN
    SELECT estado.codigo
    INTO v_estado_torneo
    FROM competencia.torneo torneo
    INNER JOIN catalogo.estado_torneo estado
        ON estado.id_estado_torneo =
           torneo.id_estado_torneo
    WHERE torneo.id_torneo =
          NEW.id_torneo;

    IF v_estado_torneo IN (
        'FINALIZADO',
        'CANCELADO'
    ) THEN
        RAISE EXCEPTION
            'No se pueden configurar premios en un torneo %',
            v_estado_torneo;
    END IF;

    SELECT tipo.codigo
    INTO v_tipo_premio
    FROM finanzas.premio premio
    INNER JOIN catalogo.tipo_premio tipo
        ON tipo.id_tipo_premio =
           premio.id_tipo_premio
    WHERE premio.id_premio =
          NEW.id_premio;

    IF v_tipo_premio = 'ECONOMICO'
       AND NEW.valor_economico <= 0 THEN

        RAISE EXCEPTION
            'Un premio economico debe tener un valor mayor que cero';
    END IF;

    IF TG_OP = 'UPDATE'
       AND NEW.id_torneo <> OLD.id_torneo THEN

        RAISE EXCEPTION
            'No se puede cambiar el torneo del premio';
    END IF;

    NEW.moneda := UPPER(NEW.moneda);

    RETURN NEW;
END;
$$;


--
-- Name: sp_autorizar_entrega_premio(bigint, bigint, character varying); Type: PROCEDURE; Schema: finanzas; Owner: -
--

CREATE PROCEDURE finanzas.sp_autorizar_entrega_premio(IN p_id_entrega_premio bigint, IN p_autorizado_por bigint, IN p_observaciones character varying DEFAULT NULL::character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_id_estado_autorizado SMALLINT;
BEGIN
    PERFORM SET_CONFIG(
        'app.usuario_id',
        p_autorizado_por::TEXT,
        TRUE
    );

    SELECT id_estado_entrega_premio
    INTO v_id_estado_autorizado
    FROM catalogo.estado_entrega_premio
    WHERE codigo = 'AUTORIZADO';

    UPDATE finanzas.entrega_premio
    SET
        id_estado_entrega_premio =
            v_id_estado_autorizado,
        autorizado_por =
            p_autorizado_por,
        fecha_autorizacion =
            CURRENT_TIMESTAMP,
        observaciones =
            COALESCE(
                p_observaciones,
                observaciones
            )
    WHERE id_entrega_premio =
          p_id_entrega_premio;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'La entrega % no existe',
            p_id_entrega_premio;
    END IF;
END;
$$;


--
-- Name: sp_configurar_premio_torneo(bigint, bigint, smallint, numeric, character, bigint, character varying); Type: PROCEDURE; Schema: finanzas; Owner: -
--

CREATE PROCEDURE finanzas.sp_configurar_premio_torneo(IN p_id_torneo bigint, IN p_id_premio bigint, IN p_posicion_objetivo smallint, IN p_valor_economico numeric, IN p_moneda character, IN p_registrado_por bigint, IN p_descripcion character varying DEFAULT NULL::character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO finanzas.torneo_premio (
        id_torneo,
        id_premio,
        posicion_objetivo,
        valor_economico,
        moneda,
        descripcion_entrega,
        registrado_por
    )
    VALUES (
        p_id_torneo,
        p_id_premio,
        p_posicion_objetivo,
        p_valor_economico,
        UPPER(p_moneda),
        p_descripcion,
        p_registrado_por
    );
END;
$$;


--
-- Name: sp_confirmar_pago(bigint, bigint, character varying); Type: PROCEDURE; Schema: finanzas; Owner: -
--

CREATE PROCEDURE finanzas.sp_confirmar_pago(IN p_id_pago bigint, IN p_verificado_por bigint, IN p_observaciones character varying DEFAULT NULL::character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_id_estado_confirmado SMALLINT;
    v_estado_actual VARCHAR(40);
BEGIN
    SELECT estado.codigo
    INTO v_estado_actual
    FROM finanzas.pago pago
    INNER JOIN catalogo.estado_pago estado
        ON estado.id_estado_pago =
           pago.id_estado_pago
    WHERE pago.id_pago = p_id_pago;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'El pago % no existe',
            p_id_pago;
    END IF;

    IF v_estado_actual <> 'PENDIENTE' THEN
        RAISE EXCEPTION
            'Solo los pagos pendientes pueden confirmarse';
    END IF;

    SELECT id_estado_pago
    INTO v_id_estado_confirmado
    FROM catalogo.estado_pago
    WHERE codigo = 'CONFIRMADO';

    UPDATE finanzas.pago
    SET
        id_estado_pago =
            v_id_estado_confirmado,
        verificado_por =
            p_verificado_por,
        fecha_verificacion =
            CURRENT_TIMESTAMP,
        observaciones =
            COALESCE(
                p_observaciones,
                observaciones
            )
    WHERE id_pago = p_id_pago;
END;
$$;


--
-- Name: sp_entregar_premio(bigint, bigint, character varying); Type: PROCEDURE; Schema: finanzas; Owner: -
--

CREATE PROCEDURE finanzas.sp_entregar_premio(IN p_id_entrega_premio bigint, IN p_entregado_por bigint, IN p_observaciones character varying DEFAULT NULL::character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_id_estado_entregado SMALLINT;
BEGIN
    PERFORM SET_CONFIG(
        'app.usuario_id',
        p_entregado_por::TEXT,
        TRUE
    );

    SELECT id_estado_entrega_premio
    INTO v_id_estado_entregado
    FROM catalogo.estado_entrega_premio
    WHERE codigo = 'ENTREGADO';

    UPDATE finanzas.entrega_premio
    SET
        id_estado_entrega_premio =
            v_id_estado_entregado,
        entregado_por =
            p_entregado_por,
        fecha_entrega =
            CURRENT_TIMESTAMP,
        observaciones =
            COALESCE(
                p_observaciones,
                observaciones
            )
    WHERE id_entrega_premio =
          p_id_entrega_premio;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'La entrega % no existe',
            p_id_entrega_premio;
    END IF;
END;
$$;


--
-- Name: sp_generar_entregas_premios(bigint, bigint); Type: PROCEDURE; Schema: finanzas; Owner: -
--

CREATE PROCEDURE finanzas.sp_generar_entregas_premios(IN p_id_torneo bigint, IN p_usuario bigint)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_estado_torneo VARCHAR(40);
    v_id_estado_pendiente SMALLINT;
    v_fila RECORD;

    cursor_premios CURSOR FOR
        SELECT
            torneo_premio.id_torneo_premio,
            resultado.id_resultado_torneo
        FROM finanzas.torneo_premio torneo_premio
        INNER JOIN competencia.resultado_torneo resultado
            ON resultado.id_torneo =
               torneo_premio.id_torneo
           AND resultado.posicion_final =
               torneo_premio.posicion_objetivo
        WHERE torneo_premio.id_torneo =
              p_id_torneo
          AND NOT EXISTS (
              SELECT 1
              FROM finanzas.entrega_premio entrega
              WHERE entrega.id_torneo_premio =
                    torneo_premio.id_torneo_premio
          )
        ORDER BY torneo_premio.posicion_objetivo;
BEGIN
    PERFORM SET_CONFIG(
        'app.usuario_id',
        p_usuario::TEXT,
        TRUE
    );

    SELECT estado.codigo
    INTO v_estado_torneo
    FROM competencia.torneo torneo
    INNER JOIN catalogo.estado_torneo estado
        ON estado.id_estado_torneo =
           torneo.id_estado_torneo
    WHERE torneo.id_torneo =
          p_id_torneo;

    IF v_estado_torneo <> 'FINALIZADO' THEN
        RAISE EXCEPTION
            'El torneo debe estar FINALIZADO';
    END IF;

    SELECT id_estado_entrega_premio
    INTO v_id_estado_pendiente
    FROM catalogo.estado_entrega_premio
    WHERE codigo = 'PENDIENTE';

    OPEN cursor_premios;

    LOOP
        FETCH cursor_premios
        INTO v_fila;

        EXIT WHEN NOT FOUND;

        INSERT INTO finanzas.entrega_premio (
            id_torneo_premio,
            id_resultado_torneo,
            id_estado_entrega_premio,
            observaciones
        )
        VALUES (
            v_fila.id_torneo_premio,
            v_fila.id_resultado_torneo,
            v_id_estado_pendiente,
            'Entrega generada automaticamente'
        );
    END LOOP;

    CLOSE cursor_premios;
END;
$$;


--
-- Name: sp_registrar_pago(bigint, character varying, character varying, numeric, character varying, bigint, bigint, character varying); Type: PROCEDURE; Schema: finanzas; Owner: -
--

CREATE PROCEDURE finanzas.sp_registrar_pago(IN p_id_inscripcion bigint, IN p_metodo_pago character varying, IN p_estado_pago character varying, IN p_monto numeric, IN p_referencia character varying, IN p_registrado_por bigint, IN p_verificado_por bigint DEFAULT NULL::bigint, IN p_observaciones character varying DEFAULT NULL::character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_id_metodo_pago SMALLINT;
    v_id_estado_pago SMALLINT;
    v_moneda CHAR(3);
BEGIN
    SELECT id_metodo_pago
    INTO v_id_metodo_pago
    FROM catalogo.metodo_pago
    WHERE codigo = UPPER(p_metodo_pago)
      AND activo = TRUE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'El metodo de pago % no existe',
            p_metodo_pago;
    END IF;

    SELECT id_estado_pago
    INTO v_id_estado_pago
    FROM catalogo.estado_pago
    WHERE codigo = UPPER(p_estado_pago)
      AND activo = TRUE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'El estado de pago % no existe',
            p_estado_pago;
    END IF;

    SELECT moneda
    INTO v_moneda
    FROM competencia.inscripcion
    WHERE id_inscripcion =
          p_id_inscripcion;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'La inscripcion % no existe',
            p_id_inscripcion;
    END IF;

    INSERT INTO finanzas.pago (
        id_inscripcion,
        id_metodo_pago,
        id_estado_pago,
        monto,
        moneda,
        referencia,
        registrado_por,
        verificado_por,
        fecha_verificacion,
        observaciones
    )
    VALUES (
        p_id_inscripcion,
        v_id_metodo_pago,
        v_id_estado_pago,
        p_monto,
        v_moneda,
        p_referencia,
        p_registrado_por,
        p_verificado_por,
        CASE
            WHEN UPPER(p_estado_pago) = 'CONFIRMADO'
                THEN CURRENT_TIMESTAMP
            ELSE NULL
        END,
        p_observaciones
    );
END;
$$;


--
-- Name: fn_validar_cambio_jugador_equipo(); Type: FUNCTION; Schema: participantes; Owner: -
--

CREATE FUNCTION participantes.fn_validar_cambio_jugador_equipo() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_id_jugador BIGINT;
    v_id_equipo_actual BIGINT;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_id_jugador := OLD.id_jugador;
        v_id_equipo_actual := OLD.id_equipo;

        IF EXISTS (
            SELECT 1
            FROM competencia.jugador_inscripcion jugador
            INNER JOIN competencia.inscripcion inscripcion
                ON inscripcion.id_inscripcion =
                   jugador.id_inscripcion
            INNER JOIN competencia.torneo torneo
                ON torneo.id_torneo =
                   inscripcion.id_torneo
            INNER JOIN catalogo.estado_torneo estado
                ON estado.id_estado_torneo =
                   torneo.id_estado_torneo
            WHERE jugador.id_jugador =
                  v_id_jugador
              AND inscripcion.id_equipo =
                  v_id_equipo_actual
              AND jugador.fecha_baja IS NULL
              AND estado.codigo IN (
                  'INSCRIPCIONES_CERRADAS',
                  'PROGRAMADO',
                  'EN_CURSO'
              )
        ) THEN
            RAISE EXCEPTION
                'No se puede eliminar la membresia: el jugador participa en un torneo vigente';
        END IF;

        RETURN OLD;
    END IF;

    IF TG_OP = 'INSERT'
       AND NEW.fecha_fin IS NULL THEN

        IF EXISTS (
            SELECT 1
            FROM competencia.jugador_inscripcion jugador
            INNER JOIN competencia.inscripcion inscripcion
                ON inscripcion.id_inscripcion =
                   jugador.id_inscripcion
            INNER JOIN competencia.torneo torneo
                ON torneo.id_torneo =
                   inscripcion.id_torneo
            INNER JOIN catalogo.estado_torneo estado
                ON estado.id_estado_torneo =
                   torneo.id_estado_torneo
            WHERE jugador.id_jugador =
                  NEW.id_jugador
              AND inscripcion.id_equipo <>
                  NEW.id_equipo
              AND jugador.fecha_baja IS NULL
              AND estado.codigo IN (
                  'INSCRIPCIONES_CERRADAS',
                  'PROGRAMADO',
                  'EN_CURSO'
              )
        ) THEN
            RAISE EXCEPTION
                'El jugador no puede cambiar de equipo durante un torneo vigente';
        END IF;
    END IF;

    IF TG_OP = 'UPDATE' THEN
        IF (
            OLD.fecha_fin IS NULL
            AND NEW.fecha_fin IS NOT NULL
        )
        OR NEW.id_equipo <> OLD.id_equipo THEN

            IF EXISTS (
                SELECT 1
                FROM competencia.jugador_inscripcion jugador
                INNER JOIN competencia.inscripcion inscripcion
                    ON inscripcion.id_inscripcion =
                       jugador.id_inscripcion
                INNER JOIN competencia.torneo torneo
                    ON torneo.id_torneo =
                       inscripcion.id_torneo
                INNER JOIN catalogo.estado_torneo estado
                    ON estado.id_estado_torneo =
                       torneo.id_estado_torneo
                WHERE jugador.id_jugador =
                      OLD.id_jugador
                  AND inscripcion.id_equipo =
                      OLD.id_equipo
                  AND jugador.fecha_baja IS NULL
                  AND estado.codigo IN (
                      'INSCRIPCIONES_CERRADAS',
                      'PROGRAMADO',
                      'EN_CURSO'
                  )
            ) THEN
                RAISE EXCEPTION
                    'El jugador no puede abandonar el equipo durante un torneo vigente';
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;


--
-- Name: fn_estadistica_inscripcion_torneo(bigint, bigint); Type: FUNCTION; Schema: reportes; Owner: -
--

CREATE FUNCTION reportes.fn_estadistica_inscripcion_torneo(p_id_torneo bigint, p_id_inscripcion bigint) RETURNS TABLE(partidos_jugados bigint, partidos_ganados bigint, partidos_empatados bigint, partidos_perdidos bigint, marcador_favor bigint, marcador_contra bigint, diferencia_marcador bigint, puntos bigint)
    LANGUAGE sql STABLE
    AS $$
    SELECT
        COUNT(partido_equipo.id_partido_equipo)::BIGINT
            AS partidos_jugados,

        COUNT(*) FILTER (
            WHERE resultado.codigo = 'GANADOR'
        )::BIGINT AS partidos_ganados,

        COUNT(*) FILTER (
            WHERE resultado.codigo = 'EMPATE'
        )::BIGINT AS partidos_empatados,

        COUNT(*) FILTER (
            WHERE resultado.codigo = 'PERDEDOR'
        )::BIGINT AS partidos_perdidos,

        COALESCE(
            SUM(partido_equipo.marcador),
            0
        )::BIGINT AS marcador_favor,

        COALESCE(
            SUM(rival.marcador),
            0
        )::BIGINT AS marcador_contra,

        (
            COALESCE(
                SUM(partido_equipo.marcador),
                0
            )
            -
            COALESCE(
                SUM(rival.marcador),
                0
            )
        )::BIGINT AS diferencia_marcador,

        COALESCE(
            SUM(partido_equipo.puntos_tabla),
            0
        )::BIGINT AS puntos

    FROM competencia.partido_equipo partido_equipo

    INNER JOIN competencia.partido partido
        ON partido.id_partido =
           partido_equipo.id_partido

    INNER JOIN catalogo.estado_partido estado_partido
        ON estado_partido.id_estado_partido =
           partido.id_estado_partido
       AND estado_partido.codigo = 'FINALIZADO'

    INNER JOIN catalogo.resultado_equipo_partido resultado
        ON resultado.id_resultado_equipo_partido =
           partido_equipo.id_resultado_equipo_partido

    LEFT JOIN competencia.partido_equipo rival
        ON rival.id_partido =
           partido_equipo.id_partido
       AND rival.id_inscripcion <>
           partido_equipo.id_inscripcion

    WHERE partido_equipo.id_inscripcion =
          p_id_inscripcion

      AND EXISTS (
          SELECT 1
          FROM competencia.inscripcion inscripcion
          WHERE inscripcion.id_inscripcion =
                partido_equipo.id_inscripcion
            AND inscripcion.id_torneo =
                p_id_torneo
      );
$$;


--
-- Name: fn_finanzas_torneo(bigint); Type: FUNCTION; Schema: reportes; Owner: -
--

CREATE FUNCTION reportes.fn_finanzas_torneo(p_id_torneo bigint) RETURNS TABLE(id_torneo bigint, torneo character varying, inscripciones bigint, monto_total_requerido numeric, total_pagado numeric, saldo_pendiente numeric, pagos_confirmados bigint, pagos_pendientes bigint, pagos_rechazados bigint)
    LANGUAGE sql STABLE
    AS $$
    WITH resumen_inscripciones AS (
        SELECT
            inscripcion.id_torneo,

            COUNT(*) AS inscripciones,

            COALESCE(
                SUM(inscripcion.monto_requerido),
                0
            ) AS monto_total_requerido

        FROM competencia.inscripcion inscripcion

        WHERE inscripcion.id_torneo =
              p_id_torneo

        GROUP BY inscripcion.id_torneo
    ),

    resumen_pagos AS (
        SELECT
            inscripcion.id_torneo,

            COALESCE(
                SUM(pago.monto) FILTER (
                    WHERE estado_pago.codigo =
                          'CONFIRMADO'
                ),
                0
            ) AS total_pagado,

            COUNT(pago.id_pago) FILTER (
                WHERE estado_pago.codigo =
                      'CONFIRMADO'
            ) AS pagos_confirmados,

            COUNT(pago.id_pago) FILTER (
                WHERE estado_pago.codigo =
                      'PENDIENTE'
            ) AS pagos_pendientes,

            COUNT(pago.id_pago) FILTER (
                WHERE estado_pago.codigo =
                      'RECHAZADO'
            ) AS pagos_rechazados

        FROM competencia.inscripcion inscripcion

        LEFT JOIN finanzas.pago pago
            ON pago.id_inscripcion =
               inscripcion.id_inscripcion

        LEFT JOIN catalogo.estado_pago estado_pago
            ON estado_pago.id_estado_pago =
               pago.id_estado_pago

        WHERE inscripcion.id_torneo =
              p_id_torneo

        GROUP BY inscripcion.id_torneo
    )

    SELECT
        torneo.id_torneo,
        torneo.nombre::VARCHAR,

        COALESCE(
            inscripciones.inscripciones,
            0
        ),

        COALESCE(
            inscripciones.monto_total_requerido,
            0
        ),

        COALESCE(
            pagos.total_pagado,
            0
        ),

        GREATEST(
            COALESCE(
                inscripciones.monto_total_requerido,
                0
            )
            -
            COALESCE(
                pagos.total_pagado,
                0
            ),
            0
        ),

        COALESCE(
            pagos.pagos_confirmados,
            0
        ),

        COALESCE(
            pagos.pagos_pendientes,
            0
        ),

        COALESCE(
            pagos.pagos_rechazados,
            0
        )

    FROM competencia.torneo torneo

    LEFT JOIN resumen_inscripciones inscripciones
        ON inscripciones.id_torneo =
           torneo.id_torneo

    LEFT JOIN resumen_pagos pagos
        ON pagos.id_torneo =
           torneo.id_torneo

    WHERE torneo.id_torneo =
          p_id_torneo;
$$;


--
-- Name: fn_historial_equipo(bigint); Type: FUNCTION; Schema: reportes; Owner: -
--

CREATE FUNCTION reportes.fn_historial_equipo(p_id_equipo bigint) RETURNS TABLE(id_torneo bigint, torneo character varying, estado_torneo character varying, estado_inscripcion character varying, posicion_final smallint, partidos_jugados smallint, partidos_ganados smallint, partidos_empatados smallint, partidos_perdidos smallint, puntos integer)
    LANGUAGE sql STABLE
    AS $$
    SELECT
        torneo.id_torneo,
        torneo.nombre::VARCHAR,
        estado_torneo.codigo::VARCHAR,
        estado_inscripcion.codigo::VARCHAR,

        resultado.posicion_final,
        resultado.partidos_jugados,
        resultado.partidos_ganados,
        resultado.partidos_empatados,
        resultado.partidos_perdidos,
        resultado.puntos

    FROM competencia.inscripcion inscripcion

    INNER JOIN competencia.torneo torneo
        ON torneo.id_torneo =
           inscripcion.id_torneo

    INNER JOIN catalogo.estado_torneo estado_torneo
        ON estado_torneo.id_estado_torneo =
           torneo.id_estado_torneo

    INNER JOIN catalogo.estado_inscripcion estado_inscripcion
        ON estado_inscripcion.id_estado_inscripcion =
           inscripcion.id_estado_inscripcion

    LEFT JOIN competencia.resultado_torneo resultado
        ON resultado.id_inscripcion =
           inscripcion.id_inscripcion

    WHERE inscripcion.id_equipo =
          p_id_equipo

    ORDER BY
        torneo.fecha_inicio_torneo DESC;
$$;


--
-- Name: fn_rendimiento_jugador(bigint); Type: FUNCTION; Schema: reportes; Owner: -
--

CREATE FUNCTION reportes.fn_rendimiento_jugador(p_id_jugador bigint) RETURNS TABLE(id_torneo bigint, torneo character varying, equipo character varying, partidos_registrados bigint, veces_convocado bigint, asistencias bigint, titularidades bigint, porcentaje_asistencia numeric, minutos_jugados bigint, puntos_anotados bigint, faltas bigint, amonestaciones bigint, expulsiones bigint, lesiones bigint, calificacion_promedio numeric)
    LANGUAGE sql STABLE
    AS $$
    SELECT
        estadistica.id_torneo,
        estadistica.torneo::VARCHAR,
        estadistica.equipo::VARCHAR,
        estadistica.partidos_registrados,
        estadistica.veces_convocado,
        estadistica.asistencias,
        estadistica.titularidades,
        estadistica.porcentaje_asistencia,
        estadistica.minutos_jugados,
        estadistica.puntos_anotados,
        estadistica.faltas,
        estadistica.amonestaciones,
        estadistica.expulsiones,
        estadistica.lesiones,
        estadistica.calificacion_promedio

    FROM reportes.vw_estadisticas_jugadores_torneo estadistica

    WHERE estadistica.id_jugador =
          p_id_jugador

    ORDER BY estadistica.id_torneo;
$$;


--
-- Name: fn_resumen_torneo(bigint); Type: FUNCTION; Schema: reportes; Owner: -
--

CREATE FUNCTION reportes.fn_resumen_torneo(p_id_torneo bigint) RETURNS TABLE(id_torneo bigint, codigo character varying, torneo character varying, deporte character varying, formato character varying, estado character varying, total_inscripciones bigint, inscripciones_habilitadas bigint, total_fases bigint, total_partidos bigint, partidos_finalizados bigint, total_recaudado numeric)
    LANGUAGE sql STABLE
    AS $$
    SELECT
        resumen.id_torneo,
        resumen.codigo::VARCHAR,
        resumen.nombre::VARCHAR,
        resumen.deporte::VARCHAR,
        resumen.formato::VARCHAR,
        resumen.estado_torneo::VARCHAR,
        resumen.total_inscripciones,
        resumen.inscripciones_habilitadas,
        resumen.total_fases,
        resumen.total_partidos,
        resumen.partidos_finalizados,
        resumen.total_recaudado
    FROM reportes.vw_torneos_resumen resumen
    WHERE resumen.id_torneo =
          p_id_torneo;
$$;


--
-- Name: fn_tabla_posiciones_grupo(bigint); Type: FUNCTION; Schema: reportes; Owner: -
--

CREATE FUNCTION reportes.fn_tabla_posiciones_grupo(p_id_grupo_torneo bigint) RETURNS TABLE(posicion bigint, id_inscripcion bigint, id_equipo bigint, equipo character varying, partidos_jugados bigint, partidos_ganados bigint, partidos_empatados bigint, partidos_perdidos bigint, marcador_favor bigint, marcador_contra bigint, diferencia_marcador bigint, puntos bigint)
    LANGUAGE sql STABLE
    AS $$
    WITH partidos_finalizados AS (
        SELECT partido.id_partido
        FROM competencia.partido partido
        INNER JOIN catalogo.estado_partido estado
            ON estado.id_estado_partido =
               partido.id_estado_partido
        WHERE partido.id_grupo_torneo =
              p_id_grupo_torneo
          AND estado.codigo = 'FINALIZADO'
    ),
    estadisticas AS (
        SELECT
            equipo_grupo.id_inscripcion,
            equipo.id_equipo,
            equipo.nombre::VARCHAR AS equipo,

            COUNT(
                partido_equipo.id_partido_equipo
            )::BIGINT AS partidos_jugados,

            COUNT(*) FILTER (
                WHERE resultado.codigo = 'GANADOR'
            )::BIGINT AS partidos_ganados,

            COUNT(*) FILTER (
                WHERE resultado.codigo = 'EMPATE'
            )::BIGINT AS partidos_empatados,

            COUNT(*) FILTER (
                WHERE resultado.codigo = 'PERDEDOR'
            )::BIGINT AS partidos_perdidos,

            COALESCE(
                SUM(partido_equipo.marcador),
                0
            )::BIGINT AS marcador_favor,

            COALESCE(
                SUM(rival.marcador),
                0
            )::BIGINT AS marcador_contra,

            (
                COALESCE(
                    SUM(partido_equipo.marcador),
                    0
                )
                -
                COALESCE(
                    SUM(rival.marcador),
                    0
                )
            )::BIGINT AS diferencia_marcador,

            COALESCE(
                SUM(partido_equipo.puntos_tabla),
                0
            )::BIGINT AS puntos

        FROM competencia.equipo_grupo equipo_grupo

        INNER JOIN competencia.inscripcion inscripcion
            ON inscripcion.id_inscripcion =
               equipo_grupo.id_inscripcion

        INNER JOIN participantes.equipo equipo
            ON equipo.id_equipo =
               inscripcion.id_equipo

        LEFT JOIN partidos_finalizados partido
            ON TRUE

        LEFT JOIN competencia.partido_equipo partido_equipo
            ON partido_equipo.id_partido =
               partido.id_partido
           AND partido_equipo.id_inscripcion =
               equipo_grupo.id_inscripcion

        LEFT JOIN catalogo.resultado_equipo_partido resultado
            ON resultado.id_resultado_equipo_partido =
               partido_equipo.id_resultado_equipo_partido

        LEFT JOIN competencia.partido_equipo rival
            ON rival.id_partido =
               partido_equipo.id_partido
           AND rival.id_inscripcion <>
               partido_equipo.id_inscripcion

        WHERE equipo_grupo.id_grupo_torneo =
              p_id_grupo_torneo

        GROUP BY
            equipo_grupo.id_inscripcion,
            equipo.id_equipo,
            equipo.nombre
    )
    SELECT
        ROW_NUMBER() OVER (
            ORDER BY
                estadisticas.puntos DESC,
                estadisticas.diferencia_marcador DESC,
                estadisticas.marcador_favor DESC,
                estadisticas.equipo ASC
        )::BIGINT AS posicion,

        estadisticas.id_inscripcion,
        estadisticas.id_equipo,
        estadisticas.equipo,

        estadisticas.partidos_jugados,
        estadisticas.partidos_ganados,
        estadisticas.partidos_empatados,
        estadisticas.partidos_perdidos,

        estadisticas.marcador_favor,
        estadisticas.marcador_contra,
        estadisticas.diferencia_marcador,
        estadisticas.puntos

    FROM estadisticas

    ORDER BY posicion;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: auditoria_dml; Type: TABLE; Schema: auditoria; Owner: -
--

CREATE TABLE auditoria.auditoria_dml (
    id_auditoria bigint NOT NULL,
    esquema name NOT NULL,
    tabla name NOT NULL,
    operacion character varying(10) NOT NULL,
    identificador_registro jsonb NOT NULL,
    datos_anteriores jsonb,
    datos_nuevos jsonb,
    cambios jsonb,
    columnas_modificadas text[] DEFAULT ARRAY[]::text[] NOT NULL,
    usuario_aplicacion bigint,
    usuario_postgresql name DEFAULT CURRENT_USER NOT NULL,
    usuario_sesion name DEFAULT SESSION_USER NOT NULL,
    aplicacion character varying(150),
    ip_cliente character varying(64),
    id_solicitud character varying(120),
    id_transaccion bigint DEFAULT txid_current() NOT NULL,
    pid_backend integer DEFAULT pg_backend_pid() NOT NULL,
    fecha_evento timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT ck_auditoria_dml_datos_anteriores CHECK (((datos_anteriores IS NULL) OR (jsonb_typeof(datos_anteriores) = 'object'::text))),
    CONSTRAINT ck_auditoria_dml_datos_nuevos CHECK (((datos_nuevos IS NULL) OR (jsonb_typeof(datos_nuevos) = 'object'::text))),
    CONSTRAINT ck_auditoria_dml_identificador CHECK ((jsonb_typeof(identificador_registro) = 'object'::text)),
    CONSTRAINT ck_auditoria_dml_operacion CHECK (((operacion)::text = ANY ((ARRAY['INSERT'::character varying, 'UPDATE'::character varying, 'DELETE'::character varying])::text[])))
);


--
-- Name: TABLE auditoria_dml; Type: COMMENT; Schema: auditoria; Owner: -
--

COMMENT ON TABLE auditoria.auditoria_dml IS 'Almacena los cambios INSERT, UPDATE y DELETE realizados sobre las tablas configuradas.';


--
-- Name: COLUMN auditoria_dml.identificador_registro; Type: COMMENT; Schema: auditoria; Owner: -
--

COMMENT ON COLUMN auditoria.auditoria_dml.identificador_registro IS 'Clave primaria del registro afectado almacenada como JSONB.';


--
-- Name: COLUMN auditoria_dml.cambios; Type: COMMENT; Schema: auditoria; Owner: -
--

COMMENT ON COLUMN auditoria.auditoria_dml.cambios IS 'Valores anteriores y nuevos de las columnas modificadas.';


--
-- Name: COLUMN auditoria_dml.id_solicitud; Type: COMMENT; Schema: auditoria; Owner: -
--

COMMENT ON COLUMN auditoria.auditoria_dml.id_solicitud IS 'Identificador de correlacion enviado por FastAPI para rastrear una solicitud completa.';


--
-- Name: auditoria_dml_id_auditoria_seq; Type: SEQUENCE; Schema: auditoria; Owner: -
--

ALTER TABLE auditoria.auditoria_dml ALTER COLUMN id_auditoria ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME auditoria.auditoria_dml_id_auditoria_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: configuracion_auditoria; Type: TABLE; Schema: auditoria; Owner: -
--

CREATE TABLE auditoria.configuracion_auditoria (
    id_configuracion bigint NOT NULL,
    esquema name NOT NULL,
    tabla name NOT NULL,
    columnas_pk text[] NOT NULL,
    columnas_excluidas text[] DEFAULT ARRAY[]::text[] NOT NULL,
    auditar_insert boolean DEFAULT true NOT NULL,
    auditar_update boolean DEFAULT true NOT NULL,
    auditar_delete boolean DEFAULT true NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    descripcion character varying(300),
    fecha_registro timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT ck_configuracion_auditoria_pk CHECK ((cardinality(columnas_pk) > 0))
);


--
-- Name: TABLE configuracion_auditoria; Type: COMMENT; Schema: auditoria; Owner: -
--

COMMENT ON TABLE auditoria.configuracion_auditoria IS 'Define que tablas son auditadas y que columnas deben excluirse.';


--
-- Name: configuracion_auditoria_id_configuracion_seq; Type: SEQUENCE; Schema: auditoria; Owner: -
--

ALTER TABLE auditoria.configuracion_auditoria ALTER COLUMN id_configuracion ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME auditoria.configuracion_auditoria_id_configuracion_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: historial_entrega_premio; Type: TABLE; Schema: auditoria; Owner: -
--

CREATE TABLE auditoria.historial_entrega_premio (
    id_historial_entrega bigint NOT NULL,
    id_entrega_premio bigint NOT NULL,
    id_estado_anterior smallint,
    id_estado_nuevo smallint NOT NULL,
    operacion character varying(20) NOT NULL,
    usuario_aplicacion bigint,
    usuario_postgresql name DEFAULT CURRENT_USER NOT NULL,
    fecha_cambio timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    detalle jsonb,
    CONSTRAINT ck_historial_entrega_operacion CHECK (((operacion)::text = ANY ((ARRAY['INSERT'::character varying, 'UPDATE'::character varying])::text[])))
);


--
-- Name: historial_entrega_premio_id_historial_entrega_seq; Type: SEQUENCE; Schema: auditoria; Owner: -
--

ALTER TABLE auditoria.historial_entrega_premio ALTER COLUMN id_historial_entrega ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME auditoria.historial_entrega_premio_id_historial_entrega_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: historial_estado_inscripcion; Type: TABLE; Schema: auditoria; Owner: -
--

CREATE TABLE auditoria.historial_estado_inscripcion (
    id_historial_inscripcion bigint NOT NULL,
    id_inscripcion bigint NOT NULL,
    id_estado_anterior smallint,
    id_estado_nuevo smallint NOT NULL,
    operacion character varying(20) NOT NULL,
    usuario_aplicacion bigint,
    usuario_postgresql name DEFAULT CURRENT_USER NOT NULL,
    fecha_cambio timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    detalle jsonb,
    CONSTRAINT ck_historial_inscripcion_operacion CHECK (((operacion)::text = ANY ((ARRAY['INSERT'::character varying, 'UPDATE'::character varying])::text[])))
);


--
-- Name: historial_estado_inscripcion_id_historial_inscripcion_seq; Type: SEQUENCE; Schema: auditoria; Owner: -
--

ALTER TABLE auditoria.historial_estado_inscripcion ALTER COLUMN id_historial_inscripcion ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME auditoria.historial_estado_inscripcion_id_historial_inscripcion_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: historial_estado_pago; Type: TABLE; Schema: auditoria; Owner: -
--

CREATE TABLE auditoria.historial_estado_pago (
    id_historial_pago bigint NOT NULL,
    id_pago bigint NOT NULL,
    id_estado_anterior smallint,
    id_estado_nuevo smallint NOT NULL,
    operacion character varying(20) NOT NULL,
    usuario_aplicacion bigint,
    usuario_postgresql name DEFAULT CURRENT_USER NOT NULL,
    fecha_cambio timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    detalle jsonb,
    CONSTRAINT ck_historial_pago_operacion CHECK (((operacion)::text = ANY ((ARRAY['INSERT'::character varying, 'UPDATE'::character varying])::text[])))
);


--
-- Name: historial_estado_pago_id_historial_pago_seq; Type: SEQUENCE; Schema: auditoria; Owner: -
--

ALTER TABLE auditoria.historial_estado_pago ALTER COLUMN id_historial_pago ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME auditoria.historial_estado_pago_id_historial_pago_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: historial_estado_partido; Type: TABLE; Schema: auditoria; Owner: -
--

CREATE TABLE auditoria.historial_estado_partido (
    id_historial_partido bigint NOT NULL,
    id_partido bigint NOT NULL,
    id_estado_anterior smallint,
    id_estado_nuevo smallint NOT NULL,
    operacion character varying(20) NOT NULL,
    usuario_aplicacion bigint,
    usuario_postgresql name DEFAULT CURRENT_USER NOT NULL,
    fecha_cambio timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    detalle jsonb,
    CONSTRAINT ck_historial_partido_operacion CHECK (((operacion)::text = ANY ((ARRAY['INSERT'::character varying, 'UPDATE'::character varying])::text[])))
);


--
-- Name: historial_estado_partido_id_historial_partido_seq; Type: SEQUENCE; Schema: auditoria; Owner: -
--

ALTER TABLE auditoria.historial_estado_partido ALTER COLUMN id_historial_partido ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME auditoria.historial_estado_partido_id_historial_partido_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: condicion_equipo_partido; Type: TABLE; Schema: catalogo; Owner: -
--

CREATE TABLE catalogo.condicion_equipo_partido (
    id_condicion_equipo smallint NOT NULL,
    codigo character varying(30) NOT NULL,
    nombre character varying(80) NOT NULL,
    descripcion character varying(200),
    activo boolean DEFAULT true NOT NULL,
    CONSTRAINT ck_condicion_equipo_partido_codigo CHECK (((codigo)::text = upper((codigo)::text)))
);


--
-- Name: condicion_equipo_partido_id_condicion_equipo_seq; Type: SEQUENCE; Schema: catalogo; Owner: -
--

ALTER TABLE catalogo.condicion_equipo_partido ALTER COLUMN id_condicion_equipo ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME catalogo.condicion_equipo_partido_id_condicion_equipo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: conflicto_rol_torneo; Type: TABLE; Schema: catalogo; Owner: -
--

CREATE TABLE catalogo.conflicto_rol_torneo (
    id_conflicto bigint NOT NULL,
    id_rol_torneo_a smallint NOT NULL,
    id_rol_torneo_b smallint NOT NULL,
    motivo character varying(300) NOT NULL,
    CONSTRAINT ck_conflicto_roles_diferentes CHECK ((id_rol_torneo_a <> id_rol_torneo_b)),
    CONSTRAINT ck_conflicto_roles_orden CHECK ((id_rol_torneo_a < id_rol_torneo_b))
);


--
-- Name: conflicto_rol_torneo_id_conflicto_seq; Type: SEQUENCE; Schema: catalogo; Owner: -
--

ALTER TABLE catalogo.conflicto_rol_torneo ALTER COLUMN id_conflicto ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME catalogo.conflicto_rol_torneo_id_conflicto_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: estado_deporte; Type: TABLE; Schema: catalogo; Owner: -
--

CREATE TABLE catalogo.estado_deporte (
    id_estado_deporte smallint NOT NULL,
    codigo character varying(30) NOT NULL,
    nombre character varying(80) NOT NULL,
    descripcion character varying(200),
    activo boolean DEFAULT true NOT NULL,
    CONSTRAINT ck_estado_deporte_codigo CHECK (((codigo)::text = upper((codigo)::text)))
);


--
-- Name: estado_deporte_id_estado_deporte_seq; Type: SEQUENCE; Schema: catalogo; Owner: -
--

ALTER TABLE catalogo.estado_deporte ALTER COLUMN id_estado_deporte ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME catalogo.estado_deporte_id_estado_deporte_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: estado_entrega_premio; Type: TABLE; Schema: catalogo; Owner: -
--

CREATE TABLE catalogo.estado_entrega_premio (
    id_estado_entrega_premio smallint NOT NULL,
    codigo character varying(40) NOT NULL,
    nombre character varying(100) NOT NULL,
    descripcion character varying(250),
    activo boolean DEFAULT true NOT NULL,
    CONSTRAINT ck_estado_entrega_premio_codigo CHECK (((codigo)::text = upper((codigo)::text)))
);


--
-- Name: estado_entrega_premio_id_estado_entrega_premio_seq; Type: SEQUENCE; Schema: catalogo; Owner: -
--

ALTER TABLE catalogo.estado_entrega_premio ALTER COLUMN id_estado_entrega_premio ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME catalogo.estado_entrega_premio_id_estado_entrega_premio_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: estado_equipo; Type: TABLE; Schema: catalogo; Owner: -
--

CREATE TABLE catalogo.estado_equipo (
    id_estado_equipo smallint NOT NULL,
    codigo character varying(30) NOT NULL,
    nombre character varying(80) NOT NULL,
    descripcion character varying(200),
    activo boolean DEFAULT true NOT NULL,
    CONSTRAINT ck_estado_equipo_codigo CHECK (((codigo)::text = upper((codigo)::text)))
);


--
-- Name: TABLE estado_equipo; Type: COMMENT; Schema: catalogo; Owner: -
--

COMMENT ON TABLE catalogo.estado_equipo IS 'Estados permitidos para los equipos deportivos.';


--
-- Name: estado_equipo_id_estado_equipo_seq; Type: SEQUENCE; Schema: catalogo; Owner: -
--

ALTER TABLE catalogo.estado_equipo ALTER COLUMN id_estado_equipo ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME catalogo.estado_equipo_id_estado_equipo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: estado_fase; Type: TABLE; Schema: catalogo; Owner: -
--

CREATE TABLE catalogo.estado_fase (
    id_estado_fase smallint NOT NULL,
    codigo character varying(40) NOT NULL,
    nombre character varying(100) NOT NULL,
    descripcion character varying(250),
    activo boolean DEFAULT true NOT NULL,
    CONSTRAINT ck_estado_fase_codigo CHECK (((codigo)::text = upper((codigo)::text)))
);


--
-- Name: estado_fase_id_estado_fase_seq; Type: SEQUENCE; Schema: catalogo; Owner: -
--

ALTER TABLE catalogo.estado_fase ALTER COLUMN id_estado_fase ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME catalogo.estado_fase_id_estado_fase_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: estado_inscripcion; Type: TABLE; Schema: catalogo; Owner: -
--

CREATE TABLE catalogo.estado_inscripcion (
    id_estado_inscripcion smallint NOT NULL,
    codigo character varying(40) NOT NULL,
    nombre character varying(100) NOT NULL,
    descripcion character varying(250),
    activo boolean DEFAULT true NOT NULL,
    CONSTRAINT ck_estado_inscripcion_codigo CHECK (((codigo)::text = upper((codigo)::text)))
);


--
-- Name: estado_inscripcion_id_estado_inscripcion_seq; Type: SEQUENCE; Schema: catalogo; Owner: -
--

ALTER TABLE catalogo.estado_inscripcion ALTER COLUMN id_estado_inscripcion ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME catalogo.estado_inscripcion_id_estado_inscripcion_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: estado_jornada; Type: TABLE; Schema: catalogo; Owner: -
--

CREATE TABLE catalogo.estado_jornada (
    id_estado_jornada smallint NOT NULL,
    codigo character varying(40) NOT NULL,
    nombre character varying(100) NOT NULL,
    descripcion character varying(250),
    activo boolean DEFAULT true NOT NULL,
    CONSTRAINT ck_estado_jornada_codigo CHECK (((codigo)::text = upper((codigo)::text)))
);


--
-- Name: estado_jornada_id_estado_jornada_seq; Type: SEQUENCE; Schema: catalogo; Owner: -
--

ALTER TABLE catalogo.estado_jornada ALTER COLUMN id_estado_jornada ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME catalogo.estado_jornada_id_estado_jornada_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: estado_jugador_inscripcion; Type: TABLE; Schema: catalogo; Owner: -
--

CREATE TABLE catalogo.estado_jugador_inscripcion (
    id_estado_jugador_inscripcion smallint NOT NULL,
    codigo character varying(40) NOT NULL,
    nombre character varying(100) NOT NULL,
    descripcion character varying(250),
    activo boolean DEFAULT true NOT NULL,
    CONSTRAINT ck_estado_jugador_inscripcion_codigo CHECK (((codigo)::text = upper((codigo)::text)))
);


--
-- Name: estado_jugador_inscripcion_id_estado_jugador_inscripcion_seq; Type: SEQUENCE; Schema: catalogo; Owner: -
--

ALTER TABLE catalogo.estado_jugador_inscripcion ALTER COLUMN id_estado_jugador_inscripcion ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME catalogo.estado_jugador_inscripcion_id_estado_jugador_inscripcion_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: estado_membresia; Type: TABLE; Schema: catalogo; Owner: -
--

CREATE TABLE catalogo.estado_membresia (
    id_estado_membresia smallint NOT NULL,
    codigo character varying(30) NOT NULL,
    nombre character varying(80) NOT NULL,
    descripcion character varying(200),
    activo boolean DEFAULT true NOT NULL,
    CONSTRAINT ck_estado_membresia_codigo CHECK (((codigo)::text = upper((codigo)::text)))
);


--
-- Name: TABLE estado_membresia; Type: COMMENT; Schema: catalogo; Owner: -
--

COMMENT ON TABLE catalogo.estado_membresia IS 'Estados del historial de pertenencia de un jugador a un equipo.';


--
-- Name: estado_membresia_id_estado_membresia_seq; Type: SEQUENCE; Schema: catalogo; Owner: -
--

ALTER TABLE catalogo.estado_membresia ALTER COLUMN id_estado_membresia ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME catalogo.estado_membresia_id_estado_membresia_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: estado_pago; Type: TABLE; Schema: catalogo; Owner: -
--

CREATE TABLE catalogo.estado_pago (
    id_estado_pago smallint NOT NULL,
    codigo character varying(40) NOT NULL,
    nombre character varying(100) NOT NULL,
    descripcion character varying(250),
    activo boolean DEFAULT true NOT NULL,
    CONSTRAINT ck_estado_pago_codigo CHECK (((codigo)::text = upper((codigo)::text)))
);


--
-- Name: estado_pago_id_estado_pago_seq; Type: SEQUENCE; Schema: catalogo; Owner: -
--

ALTER TABLE catalogo.estado_pago ALTER COLUMN id_estado_pago ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME catalogo.estado_pago_id_estado_pago_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: estado_partido; Type: TABLE; Schema: catalogo; Owner: -
--

CREATE TABLE catalogo.estado_partido (
    id_estado_partido smallint NOT NULL,
    codigo character varying(40) NOT NULL,
    nombre character varying(100) NOT NULL,
    descripcion character varying(250),
    activo boolean DEFAULT true NOT NULL,
    CONSTRAINT ck_estado_partido_codigo CHECK (((codigo)::text = upper((codigo)::text)))
);


--
-- Name: estado_partido_id_estado_partido_seq; Type: SEQUENCE; Schema: catalogo; Owner: -
--

ALTER TABLE catalogo.estado_partido ALTER COLUMN id_estado_partido ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME catalogo.estado_partido_id_estado_partido_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: estado_perfil_deportivo; Type: TABLE; Schema: catalogo; Owner: -
--

CREATE TABLE catalogo.estado_perfil_deportivo (
    id_estado_perfil smallint NOT NULL,
    codigo character varying(30) NOT NULL,
    nombre character varying(80) NOT NULL,
    descripcion character varying(200),
    activo boolean DEFAULT true NOT NULL,
    CONSTRAINT ck_estado_perfil_deportivo_codigo CHECK (((codigo)::text = upper((codigo)::text)))
);


--
-- Name: TABLE estado_perfil_deportivo; Type: COMMENT; Schema: catalogo; Owner: -
--

COMMENT ON TABLE catalogo.estado_perfil_deportivo IS 'Estados aplicables a jugadores, arbitros y organizadores.';


--
-- Name: estado_perfil_deportivo_id_estado_perfil_seq; Type: SEQUENCE; Schema: catalogo; Owner: -
--

ALTER TABLE catalogo.estado_perfil_deportivo ALTER COLUMN id_estado_perfil ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME catalogo.estado_perfil_deportivo_id_estado_perfil_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: estado_torneo; Type: TABLE; Schema: catalogo; Owner: -
--

CREATE TABLE catalogo.estado_torneo (
    id_estado_torneo smallint NOT NULL,
    codigo character varying(40) NOT NULL,
    nombre character varying(100) NOT NULL,
    descripcion character varying(250),
    activo boolean DEFAULT true NOT NULL,
    CONSTRAINT ck_estado_torneo_codigo CHECK (((codigo)::text = upper((codigo)::text)))
);


--
-- Name: estado_torneo_id_estado_torneo_seq; Type: SEQUENCE; Schema: catalogo; Owner: -
--

ALTER TABLE catalogo.estado_torneo ALTER COLUMN id_estado_torneo ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME catalogo.estado_torneo_id_estado_torneo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: estado_usuario; Type: TABLE; Schema: catalogo; Owner: -
--

CREATE TABLE catalogo.estado_usuario (
    id_estado_usuario smallint NOT NULL,
    codigo character varying(30) NOT NULL,
    nombre character varying(80) NOT NULL,
    descripcion character varying(200),
    activo boolean DEFAULT true NOT NULL,
    CONSTRAINT ck_estado_usuario_codigo CHECK (((codigo)::text = upper((codigo)::text)))
);


--
-- Name: TABLE estado_usuario; Type: COMMENT; Schema: catalogo; Owner: -
--

COMMENT ON TABLE catalogo.estado_usuario IS 'Estados permitidos para las cuentas de usuario.';


--
-- Name: estado_usuario_id_estado_usuario_seq; Type: SEQUENCE; Schema: catalogo; Owner: -
--

ALTER TABLE catalogo.estado_usuario ALTER COLUMN id_estado_usuario ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME catalogo.estado_usuario_id_estado_usuario_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: formato_torneo; Type: TABLE; Schema: catalogo; Owner: -
--

CREATE TABLE catalogo.formato_torneo (
    id_formato_torneo smallint NOT NULL,
    codigo character varying(40) NOT NULL,
    nombre character varying(100) NOT NULL,
    descripcion character varying(250),
    activo boolean DEFAULT true NOT NULL,
    CONSTRAINT ck_formato_torneo_codigo CHECK (((codigo)::text = upper((codigo)::text)))
);


--
-- Name: formato_torneo_id_formato_torneo_seq; Type: SEQUENCE; Schema: catalogo; Owner: -
--

ALTER TABLE catalogo.formato_torneo ALTER COLUMN id_formato_torneo ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME catalogo.formato_torneo_id_formato_torneo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: metodo_pago; Type: TABLE; Schema: catalogo; Owner: -
--

CREATE TABLE catalogo.metodo_pago (
    id_metodo_pago smallint NOT NULL,
    codigo character varying(40) NOT NULL,
    nombre character varying(100) NOT NULL,
    descripcion character varying(250),
    activo boolean DEFAULT true NOT NULL,
    CONSTRAINT ck_metodo_pago_codigo CHECK (((codigo)::text = upper((codigo)::text)))
);


--
-- Name: metodo_pago_id_metodo_pago_seq; Type: SEQUENCE; Schema: catalogo; Owner: -
--

ALTER TABLE catalogo.metodo_pago ALTER COLUMN id_metodo_pago ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME catalogo.metodo_pago_id_metodo_pago_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: resultado_equipo_partido; Type: TABLE; Schema: catalogo; Owner: -
--

CREATE TABLE catalogo.resultado_equipo_partido (
    id_resultado_equipo_partido smallint NOT NULL,
    codigo character varying(30) NOT NULL,
    nombre character varying(80) NOT NULL,
    descripcion character varying(200),
    activo boolean DEFAULT true NOT NULL,
    CONSTRAINT ck_resultado_equipo_partido_codigo CHECK (((codigo)::text = upper((codigo)::text)))
);


--
-- Name: resultado_equipo_partido_id_resultado_equipo_partido_seq; Type: SEQUENCE; Schema: catalogo; Owner: -
--

ALTER TABLE catalogo.resultado_equipo_partido ALTER COLUMN id_resultado_equipo_partido ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME catalogo.resultado_equipo_partido_id_resultado_equipo_partido_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: rol_torneo; Type: TABLE; Schema: catalogo; Owner: -
--

CREATE TABLE catalogo.rol_torneo (
    id_rol_torneo smallint NOT NULL,
    codigo character varying(40) NOT NULL,
    nombre character varying(100) NOT NULL,
    descripcion character varying(250),
    activo boolean DEFAULT true NOT NULL,
    CONSTRAINT ck_rol_torneo_codigo CHECK (((codigo)::text = upper((codigo)::text)))
);


--
-- Name: rol_torneo_id_rol_torneo_seq; Type: SEQUENCE; Schema: catalogo; Owner: -
--

ALTER TABLE catalogo.rol_torneo ALTER COLUMN id_rol_torneo ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME catalogo.rol_torneo_id_rol_torneo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tipo_arbitro_partido; Type: TABLE; Schema: catalogo; Owner: -
--

CREATE TABLE catalogo.tipo_arbitro_partido (
    id_tipo_arbitro_partido smallint NOT NULL,
    codigo character varying(40) NOT NULL,
    nombre character varying(100) NOT NULL,
    descripcion character varying(250),
    activo boolean DEFAULT true NOT NULL,
    CONSTRAINT ck_tipo_arbitro_partido_codigo CHECK (((codigo)::text = upper((codigo)::text)))
);


--
-- Name: tipo_arbitro_partido_id_tipo_arbitro_partido_seq; Type: SEQUENCE; Schema: catalogo; Owner: -
--

ALTER TABLE catalogo.tipo_arbitro_partido ALTER COLUMN id_tipo_arbitro_partido ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME catalogo.tipo_arbitro_partido_id_tipo_arbitro_partido_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tipo_documento; Type: TABLE; Schema: catalogo; Owner: -
--

CREATE TABLE catalogo.tipo_documento (
    id_tipo_documento smallint NOT NULL,
    codigo character varying(30) NOT NULL,
    nombre character varying(80) NOT NULL,
    descripcion character varying(200),
    activo boolean DEFAULT true NOT NULL,
    CONSTRAINT ck_tipo_documento_codigo CHECK (((codigo)::text = upper((codigo)::text))),
    CONSTRAINT ck_tipo_documento_nombre CHECK ((length(btrim((nombre)::text)) >= 2))
);


--
-- Name: TABLE tipo_documento; Type: COMMENT; Schema: catalogo; Owner: -
--

COMMENT ON TABLE catalogo.tipo_documento IS 'Tipos de documento de identificacion admitidos por el sistema.';


--
-- Name: tipo_documento_id_tipo_documento_seq; Type: SEQUENCE; Schema: catalogo; Owner: -
--

ALTER TABLE catalogo.tipo_documento ALTER COLUMN id_tipo_documento ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME catalogo.tipo_documento_id_tipo_documento_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tipo_fase; Type: TABLE; Schema: catalogo; Owner: -
--

CREATE TABLE catalogo.tipo_fase (
    id_tipo_fase smallint NOT NULL,
    codigo character varying(40) NOT NULL,
    nombre character varying(100) NOT NULL,
    descripcion character varying(250),
    activo boolean DEFAULT true NOT NULL,
    CONSTRAINT ck_tipo_fase_codigo CHECK (((codigo)::text = upper((codigo)::text)))
);


--
-- Name: tipo_fase_id_tipo_fase_seq; Type: SEQUENCE; Schema: catalogo; Owner: -
--

ALTER TABLE catalogo.tipo_fase ALTER COLUMN id_tipo_fase ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME catalogo.tipo_fase_id_tipo_fase_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: tipo_premio; Type: TABLE; Schema: catalogo; Owner: -
--

CREATE TABLE catalogo.tipo_premio (
    id_tipo_premio smallint NOT NULL,
    codigo character varying(40) NOT NULL,
    nombre character varying(100) NOT NULL,
    descripcion character varying(250),
    activo boolean DEFAULT true NOT NULL,
    CONSTRAINT ck_tipo_premio_codigo CHECK (((codigo)::text = upper((codigo)::text)))
);


--
-- Name: tipo_premio_id_tipo_premio_seq; Type: SEQUENCE; Schema: catalogo; Owner: -
--

ALTER TABLE catalogo.tipo_premio ALTER COLUMN id_tipo_premio ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME catalogo.tipo_premio_id_tipo_premio_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: arbitro_partido; Type: TABLE; Schema: competencia; Owner: -
--

CREATE TABLE competencia.arbitro_partido (
    id_arbitro_partido bigint NOT NULL,
    id_partido bigint NOT NULL,
    id_arbitro bigint NOT NULL,
    id_tipo_arbitro_partido smallint NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    asignado_por bigint NOT NULL,
    fecha_asignacion timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    fecha_fin timestamp with time zone,
    observaciones character varying(500),
    CONSTRAINT ck_arbitro_partido_activo CHECK (((activo = false) OR (fecha_fin IS NULL))),
    CONSTRAINT ck_arbitro_partido_fechas CHECK (((fecha_fin IS NULL) OR (fecha_fin >= fecha_asignacion)))
);


--
-- Name: arbitro_partido_id_arbitro_partido_seq; Type: SEQUENCE; Schema: competencia; Owner: -
--

ALTER TABLE competencia.arbitro_partido ALTER COLUMN id_arbitro_partido ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME competencia.arbitro_partido_id_arbitro_partido_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: deporte; Type: TABLE; Schema: competencia; Owner: -
--

CREATE TABLE competencia.deporte (
    id_deporte bigint NOT NULL,
    codigo character varying(40) NOT NULL,
    nombre character varying(100) NOT NULL,
    descripcion character varying(500),
    cantidad_minima_jugadores smallint NOT NULL,
    cantidad_maxima_jugadores smallint NOT NULL,
    cantidad_titulares smallint NOT NULL,
    tipo_marcador character varying(30) NOT NULL,
    permite_empate boolean DEFAULT false NOT NULL,
    puntos_victoria smallint DEFAULT 3 NOT NULL,
    puntos_empate smallint DEFAULT 1 NOT NULL,
    puntos_derrota smallint DEFAULT 0 NOT NULL,
    id_estado_deporte smallint NOT NULL,
    fecha_registro timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT ck_deporte_cantidad_jugadores CHECK (((cantidad_minima_jugadores > 0) AND (cantidad_maxima_jugadores >= cantidad_minima_jugadores) AND (cantidad_titulares >= cantidad_minima_jugadores) AND (cantidad_titulares <= cantidad_maxima_jugadores))),
    CONSTRAINT ck_deporte_codigo CHECK (((codigo)::text = upper((codigo)::text))),
    CONSTRAINT ck_deporte_nombre CHECK ((length(btrim((nombre)::text)) >= 3)),
    CONSTRAINT ck_deporte_puntos CHECK (((puntos_victoria >= 0) AND (puntos_empate >= 0) AND (puntos_derrota >= 0))),
    CONSTRAINT ck_deporte_tipo_marcador CHECK (((tipo_marcador)::text = upper((tipo_marcador)::text)))
);


--
-- Name: deporte_id_deporte_seq; Type: SEQUENCE; Schema: competencia; Owner: -
--

ALTER TABLE competencia.deporte ALTER COLUMN id_deporte ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME competencia.deporte_id_deporte_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: deporte_regla; Type: TABLE; Schema: competencia; Owner: -
--

CREATE TABLE competencia.deporte_regla (
    id_deporte_regla bigint NOT NULL,
    id_deporte bigint NOT NULL,
    id_regla bigint NOT NULL,
    valor_configurado character varying(300),
    obligatorio boolean DEFAULT true NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    fecha_inicio date DEFAULT CURRENT_DATE NOT NULL,
    fecha_fin date,
    CONSTRAINT ck_deporte_regla_fechas CHECK (((fecha_fin IS NULL) OR (fecha_fin >= fecha_inicio)))
);


--
-- Name: deporte_regla_id_deporte_regla_seq; Type: SEQUENCE; Schema: competencia; Owner: -
--

ALTER TABLE competencia.deporte_regla ALTER COLUMN id_deporte_regla ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME competencia.deporte_regla_id_deporte_regla_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: equipo_grupo; Type: TABLE; Schema: competencia; Owner: -
--

CREATE TABLE competencia.equipo_grupo (
    id_equipo_grupo bigint NOT NULL,
    id_fase_torneo bigint NOT NULL,
    id_grupo_torneo bigint NOT NULL,
    id_inscripcion bigint NOT NULL,
    posicion_sorteo smallint,
    asignado_por bigint NOT NULL,
    fecha_asignacion timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    observaciones character varying(500),
    CONSTRAINT ck_equipo_grupo_posicion CHECK (((posicion_sorteo IS NULL) OR (posicion_sorteo > 0)))
);


--
-- Name: equipo_grupo_id_equipo_grupo_seq; Type: SEQUENCE; Schema: competencia; Owner: -
--

ALTER TABLE competencia.equipo_grupo ALTER COLUMN id_equipo_grupo ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME competencia.equipo_grupo_id_equipo_grupo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: fase_torneo; Type: TABLE; Schema: competencia; Owner: -
--

CREATE TABLE competencia.fase_torneo (
    id_fase_torneo bigint NOT NULL,
    id_torneo bigint NOT NULL,
    id_tipo_fase smallint NOT NULL,
    id_estado_fase smallint NOT NULL,
    nombre character varying(120) NOT NULL,
    numero_orden smallint NOT NULL,
    cantidad_clasificados smallint,
    fecha_inicio date,
    fecha_fin date,
    descripcion character varying(500),
    CONSTRAINT ck_fase_torneo_clasificados CHECK (((cantidad_clasificados IS NULL) OR (cantidad_clasificados > 0))),
    CONSTRAINT ck_fase_torneo_fechas CHECK (((fecha_inicio IS NULL) OR (fecha_fin IS NULL) OR (fecha_fin >= fecha_inicio))),
    CONSTRAINT ck_fase_torneo_orden CHECK ((numero_orden > 0))
);


--
-- Name: fase_torneo_id_fase_torneo_seq; Type: SEQUENCE; Schema: competencia; Owner: -
--

ALTER TABLE competencia.fase_torneo ALTER COLUMN id_fase_torneo ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME competencia.fase_torneo_id_fase_torneo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: grupo_torneo; Type: TABLE; Schema: competencia; Owner: -
--

CREATE TABLE competencia.grupo_torneo (
    id_grupo_torneo bigint NOT NULL,
    id_fase_torneo bigint NOT NULL,
    codigo character varying(20) NOT NULL,
    nombre character varying(100) NOT NULL,
    cantidad_maxima_equipos smallint NOT NULL,
    cantidad_clasificados smallint NOT NULL,
    CONSTRAINT ck_grupo_torneo_cantidades CHECK (((cantidad_maxima_equipos >= 2) AND (cantidad_clasificados > 0) AND (cantidad_clasificados <= cantidad_maxima_equipos))),
    CONSTRAINT ck_grupo_torneo_codigo CHECK (((codigo)::text = upper((codigo)::text)))
);


--
-- Name: grupo_torneo_id_grupo_torneo_seq; Type: SEQUENCE; Schema: competencia; Owner: -
--

ALTER TABLE competencia.grupo_torneo ALTER COLUMN id_grupo_torneo ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME competencia.grupo_torneo_id_grupo_torneo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: inscripcion; Type: TABLE; Schema: competencia; Owner: -
--

CREATE TABLE competencia.inscripcion (
    id_inscripcion bigint NOT NULL,
    id_torneo bigint NOT NULL,
    id_equipo bigint NOT NULL,
    id_estado_inscripcion smallint NOT NULL,
    monto_requerido numeric(12,2) NOT NULL,
    moneda character(3) NOT NULL,
    fecha_inscripcion timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    fecha_actualizacion timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    registrado_por bigint NOT NULL,
    observaciones character varying(500),
    CONSTRAINT ck_inscripcion_moneda CHECK ((((moneda)::text = upper((moneda)::text)) AND (length(moneda) = 3))),
    CONSTRAINT ck_inscripcion_monto CHECK ((monto_requerido >= (0)::numeric))
);


--
-- Name: inscripcion_id_inscripcion_seq; Type: SEQUENCE; Schema: competencia; Owner: -
--

ALTER TABLE competencia.inscripcion ALTER COLUMN id_inscripcion ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME competencia.inscripcion_id_inscripcion_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: jornada; Type: TABLE; Schema: competencia; Owner: -
--

CREATE TABLE competencia.jornada (
    id_jornada bigint NOT NULL,
    id_fase_torneo bigint NOT NULL,
    id_estado_jornada smallint NOT NULL,
    numero_jornada smallint NOT NULL,
    nombre character varying(120),
    fecha_inicio timestamp with time zone,
    fecha_fin timestamp with time zone,
    observaciones character varying(500),
    CONSTRAINT ck_jornada_fechas CHECK (((fecha_inicio IS NULL) OR (fecha_fin IS NULL) OR (fecha_fin >= fecha_inicio))),
    CONSTRAINT ck_jornada_numero CHECK ((numero_jornada > 0))
);


--
-- Name: jornada_id_jornada_seq; Type: SEQUENCE; Schema: competencia; Owner: -
--

ALTER TABLE competencia.jornada ALTER COLUMN id_jornada ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME competencia.jornada_id_jornada_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: jugador_inscripcion; Type: TABLE; Schema: competencia; Owner: -
--

CREATE TABLE competencia.jugador_inscripcion (
    id_jugador_inscripcion bigint NOT NULL,
    id_inscripcion bigint NOT NULL,
    id_jugador bigint NOT NULL,
    id_jugador_equipo bigint NOT NULL,
    id_estado_jugador_inscripcion smallint NOT NULL,
    numero_camiseta smallint,
    es_capitan boolean DEFAULT false NOT NULL,
    es_delegado boolean DEFAULT false NOT NULL,
    fecha_registro timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    fecha_baja timestamp with time zone,
    registrado_por bigint NOT NULL,
    observaciones character varying(500),
    CONSTRAINT ck_jugador_inscripcion_camiseta CHECK (((numero_camiseta IS NULL) OR ((numero_camiseta >= 0) AND (numero_camiseta <= 999)))),
    CONSTRAINT ck_jugador_inscripcion_fecha_baja CHECK (((fecha_baja IS NULL) OR (fecha_baja >= fecha_registro)))
);


--
-- Name: jugador_inscripcion_id_jugador_inscripcion_seq; Type: SEQUENCE; Schema: competencia; Owner: -
--

ALTER TABLE competencia.jugador_inscripcion ALTER COLUMN id_jugador_inscripcion ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME competencia.jugador_inscripcion_id_jugador_inscripcion_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: jugador_partido; Type: TABLE; Schema: competencia; Owner: -
--

CREATE TABLE competencia.jugador_partido (
    id_jugador_partido bigint NOT NULL,
    id_partido bigint NOT NULL,
    id_partido_equipo bigint NOT NULL,
    id_jugador_inscripcion bigint NOT NULL,
    convocado boolean DEFAULT true NOT NULL,
    asistio boolean DEFAULT false NOT NULL,
    titular boolean DEFAULT false NOT NULL,
    minutos_jugados smallint DEFAULT 0 NOT NULL,
    puntos_anotados integer DEFAULT 0 NOT NULL,
    faltas smallint DEFAULT 0 NOT NULL,
    amonestaciones smallint DEFAULT 0 NOT NULL,
    expulsado boolean DEFAULT false NOT NULL,
    lesionado boolean DEFAULT false NOT NULL,
    calificacion numeric(4,2),
    estadisticas jsonb DEFAULT '{}'::jsonb NOT NULL,
    registrado_por bigint NOT NULL,
    fecha_registro timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    fecha_actualizacion timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    observaciones character varying(500),
    CONSTRAINT ck_jugador_partido_amonestaciones CHECK ((amonestaciones >= 0)),
    CONSTRAINT ck_jugador_partido_asistencia CHECK (((asistio = false) OR (convocado = true))),
    CONSTRAINT ck_jugador_partido_calificacion CHECK (((calificacion IS NULL) OR ((calificacion >= (0)::numeric) AND (calificacion <= (10)::numeric)))),
    CONSTRAINT ck_jugador_partido_estadisticas CHECK ((jsonb_typeof(estadisticas) = 'object'::text)),
    CONSTRAINT ck_jugador_partido_faltas CHECK ((faltas >= 0)),
    CONSTRAINT ck_jugador_partido_minutos CHECK ((minutos_jugados >= 0)),
    CONSTRAINT ck_jugador_partido_puntos CHECK ((puntos_anotados >= 0)),
    CONSTRAINT ck_jugador_partido_sin_asistencia CHECK (((asistio = true) OR ((titular = false) AND (minutos_jugados = 0) AND (puntos_anotados = 0) AND (faltas = 0) AND (amonestaciones = 0) AND (expulsado = false) AND (lesionado = false)))),
    CONSTRAINT ck_jugador_partido_titular CHECK (((titular = false) OR ((convocado = true) AND (asistio = true))))
);


--
-- Name: jugador_partido_id_jugador_partido_seq; Type: SEQUENCE; Schema: competencia; Owner: -
--

ALTER TABLE competencia.jugador_partido ALTER COLUMN id_jugador_partido ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME competencia.jugador_partido_id_jugador_partido_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: lugar; Type: TABLE; Schema: competencia; Owner: -
--

CREATE TABLE competencia.lugar (
    id_lugar bigint NOT NULL,
    nombre character varying(150) NOT NULL,
    direccion character varying(250) NOT NULL,
    zona character varying(100),
    ciudad character varying(100) DEFAULT 'La Paz'::character varying NOT NULL,
    capacidad integer,
    tipo_superficie character varying(100),
    activo boolean DEFAULT true NOT NULL,
    fecha_registro timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT ck_lugar_capacidad CHECK (((capacidad IS NULL) OR (capacidad >= 0))),
    CONSTRAINT ck_lugar_direccion CHECK ((length(btrim((direccion)::text)) >= 5)),
    CONSTRAINT ck_lugar_nombre CHECK ((length(btrim((nombre)::text)) >= 3))
);


--
-- Name: lugar_id_lugar_seq; Type: SEQUENCE; Schema: competencia; Owner: -
--

ALTER TABLE competencia.lugar ALTER COLUMN id_lugar ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME competencia.lugar_id_lugar_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: partido; Type: TABLE; Schema: competencia; Owner: -
--

CREATE TABLE competencia.partido (
    id_partido bigint NOT NULL,
    id_jornada bigint NOT NULL,
    id_grupo_torneo bigint,
    id_lugar bigint,
    id_estado_partido smallint NOT NULL,
    codigo character varying(50) NOT NULL,
    numero_partido smallint NOT NULL,
    nombre_ronda character varying(80),
    fecha_hora_inicio timestamp with time zone,
    fecha_hora_fin timestamp with time zone,
    id_partido_siguiente bigint,
    creado_por bigint NOT NULL,
    actualizado_por bigint,
    observaciones character varying(500),
    fecha_registro timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    fecha_actualizacion timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT ck_partido_codigo CHECK (((codigo)::text = upper((codigo)::text))),
    CONSTRAINT ck_partido_fechas CHECK (((fecha_hora_inicio IS NULL) OR (fecha_hora_fin IS NULL) OR (fecha_hora_fin > fecha_hora_inicio))),
    CONSTRAINT ck_partido_numero CHECK ((numero_partido > 0)),
    CONSTRAINT ck_partido_siguiente CHECK (((id_partido_siguiente IS NULL) OR (id_partido_siguiente <> id_partido)))
);


--
-- Name: partido_equipo; Type: TABLE; Schema: competencia; Owner: -
--

CREATE TABLE competencia.partido_equipo (
    id_partido_equipo bigint NOT NULL,
    id_partido bigint NOT NULL,
    id_inscripcion bigint NOT NULL,
    id_condicion_equipo smallint NOT NULL,
    id_resultado_equipo_partido smallint NOT NULL,
    marcador integer,
    marcador_desempate integer,
    puntos_tabla smallint DEFAULT 0 NOT NULL,
    clasificado boolean DEFAULT false NOT NULL,
    observaciones character varying(500),
    CONSTRAINT ck_partido_equipo_desempate CHECK (((marcador_desempate IS NULL) OR (marcador_desempate >= 0))),
    CONSTRAINT ck_partido_equipo_marcador CHECK (((marcador IS NULL) OR (marcador >= 0))),
    CONSTRAINT ck_partido_equipo_puntos CHECK ((puntos_tabla >= 0))
);


--
-- Name: partido_equipo_id_partido_equipo_seq; Type: SEQUENCE; Schema: competencia; Owner: -
--

ALTER TABLE competencia.partido_equipo ALTER COLUMN id_partido_equipo ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME competencia.partido_equipo_id_partido_equipo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: partido_id_partido_seq; Type: SEQUENCE; Schema: competencia; Owner: -
--

ALTER TABLE competencia.partido ALTER COLUMN id_partido ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME competencia.partido_id_partido_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: regla; Type: TABLE; Schema: competencia; Owner: -
--

CREATE TABLE competencia.regla (
    id_regla bigint NOT NULL,
    codigo character varying(50) NOT NULL,
    nombre character varying(150) NOT NULL,
    descripcion text NOT NULL,
    categoria character varying(30) NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    fecha_registro timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT ck_regla_categoria CHECK (((categoria)::text = ANY ((ARRAY['GENERAL'::character varying, 'INSCRIPCION'::character varying, 'DISCIPLINA'::character varying, 'PUNTUACION'::character varying, 'SEGURIDAD'::character varying, 'PARTIDO'::character varying])::text[]))),
    CONSTRAINT ck_regla_codigo CHECK (((codigo)::text = upper((codigo)::text))),
    CONSTRAINT ck_regla_nombre CHECK ((length(btrim((nombre)::text)) >= 3))
);


--
-- Name: regla_id_regla_seq; Type: SEQUENCE; Schema: competencia; Owner: -
--

ALTER TABLE competencia.regla ALTER COLUMN id_regla ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME competencia.regla_id_regla_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: resultado_torneo; Type: TABLE; Schema: competencia; Owner: -
--

CREATE TABLE competencia.resultado_torneo (
    id_resultado_torneo bigint NOT NULL,
    id_torneo bigint NOT NULL,
    id_inscripcion bigint NOT NULL,
    posicion_final smallint NOT NULL,
    partidos_jugados smallint DEFAULT 0 NOT NULL,
    partidos_ganados smallint DEFAULT 0 NOT NULL,
    partidos_empatados smallint DEFAULT 0 NOT NULL,
    partidos_perdidos smallint DEFAULT 0 NOT NULL,
    marcador_favor integer DEFAULT 0 NOT NULL,
    marcador_contra integer DEFAULT 0 NOT NULL,
    diferencia_marcador integer DEFAULT 0 NOT NULL,
    puntos integer DEFAULT 0 NOT NULL,
    generado_por bigint NOT NULL,
    fecha_generacion timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    observaciones character varying(500),
    CONSTRAINT ck_resultado_torneo_marcadores CHECK (((marcador_favor >= 0) AND (marcador_contra >= 0))),
    CONSTRAINT ck_resultado_torneo_partidos CHECK (((partidos_jugados >= 0) AND (partidos_ganados >= 0) AND (partidos_empatados >= 0) AND (partidos_perdidos >= 0) AND (partidos_jugados = ((partidos_ganados + partidos_empatados) + partidos_perdidos)))),
    CONSTRAINT ck_resultado_torneo_posicion CHECK ((posicion_final > 0)),
    CONSTRAINT ck_resultado_torneo_puntos CHECK ((puntos >= 0))
);


--
-- Name: resultado_torneo_id_resultado_torneo_seq; Type: SEQUENCE; Schema: competencia; Owner: -
--

ALTER TABLE competencia.resultado_torneo ALTER COLUMN id_resultado_torneo ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME competencia.resultado_torneo_id_resultado_torneo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: torneo; Type: TABLE; Schema: competencia; Owner: -
--

CREATE TABLE competencia.torneo (
    id_torneo bigint NOT NULL,
    id_deporte bigint NOT NULL,
    id_formato_torneo smallint NOT NULL,
    id_estado_torneo smallint NOT NULL,
    codigo character varying(40) NOT NULL,
    nombre character varying(150) NOT NULL,
    edicion character varying(50),
    categoria character varying(100),
    rama character varying(20) DEFAULT 'ABIERTO'::character varying NOT NULL,
    fecha_inicio_inscripcion date NOT NULL,
    fecha_fin_inscripcion date NOT NULL,
    fecha_inicio_torneo date NOT NULL,
    fecha_fin_torneo date NOT NULL,
    cantidad_maxima_equipos smallint NOT NULL,
    cantidad_minima_jugadores smallint NOT NULL,
    cantidad_maxima_jugadores smallint NOT NULL,
    costo_inscripcion numeric(12,2) DEFAULT 0 NOT NULL,
    moneda character(3) DEFAULT 'BOB'::bpchar NOT NULL,
    permite_empate boolean DEFAULT false NOT NULL,
    descripcion text,
    creado_por bigint NOT NULL,
    fecha_registro timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    fecha_actualizacion timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT ck_torneo_cantidad_equipos CHECK ((cantidad_maxima_equipos >= 2)),
    CONSTRAINT ck_torneo_cantidad_jugadores CHECK (((cantidad_minima_jugadores > 0) AND (cantidad_maxima_jugadores >= cantidad_minima_jugadores))),
    CONSTRAINT ck_torneo_codigo CHECK (((codigo)::text = upper((codigo)::text))),
    CONSTRAINT ck_torneo_costo CHECK ((costo_inscripcion >= (0)::numeric)),
    CONSTRAINT ck_torneo_fechas CHECK (((fecha_inicio_inscripcion <= fecha_fin_inscripcion) AND (fecha_fin_inscripcion <= fecha_inicio_torneo) AND (fecha_inicio_torneo <= fecha_fin_torneo))),
    CONSTRAINT ck_torneo_moneda CHECK (((moneda)::text = upper((moneda)::text))),
    CONSTRAINT ck_torneo_nombre CHECK ((length(btrim((nombre)::text)) >= 4)),
    CONSTRAINT ck_torneo_rama CHECK (((rama)::text = ANY ((ARRAY['MASCULINO'::character varying, 'FEMENINO'::character varying, 'MIXTO'::character varying, 'ABIERTO'::character varying])::text[])))
);


--
-- Name: torneo_id_torneo_seq; Type: SEQUENCE; Schema: competencia; Owner: -
--

ALTER TABLE competencia.torneo ALTER COLUMN id_torneo ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME competencia.torneo_id_torneo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: torneo_regla; Type: TABLE; Schema: competencia; Owner: -
--

CREATE TABLE competencia.torneo_regla (
    id_torneo_regla bigint NOT NULL,
    id_torneo bigint NOT NULL,
    id_regla bigint NOT NULL,
    valor_configurado character varying(300),
    obligatorio boolean DEFAULT true NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    fecha_registro timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: torneo_regla_id_torneo_regla_seq; Type: SEQUENCE; Schema: competencia; Owner: -
--

ALTER TABLE competencia.torneo_regla ALTER COLUMN id_torneo_regla ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME competencia.torneo_regla_id_torneo_regla_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: usuario_torneo_rol; Type: TABLE; Schema: competencia; Owner: -
--

CREATE TABLE competencia.usuario_torneo_rol (
    id_usuario_torneo_rol bigint NOT NULL,
    id_torneo bigint NOT NULL,
    id_usuario bigint NOT NULL,
    id_rol_torneo smallint NOT NULL,
    fecha_asignacion timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    fecha_fin timestamp with time zone,
    activo boolean DEFAULT true NOT NULL,
    asignado_por bigint,
    CONSTRAINT ck_usuario_torneo_rol_activo CHECK (((activo = false) OR (fecha_fin IS NULL))),
    CONSTRAINT ck_usuario_torneo_rol_fechas CHECK (((fecha_fin IS NULL) OR (fecha_fin >= fecha_asignacion)))
);


--
-- Name: usuario_torneo_rol_id_usuario_torneo_rol_seq; Type: SEQUENCE; Schema: competencia; Owner: -
--

ALTER TABLE competencia.usuario_torneo_rol ALTER COLUMN id_usuario_torneo_rol ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME competencia.usuario_torneo_rol_id_usuario_torneo_rol_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: entrega_premio; Type: TABLE; Schema: finanzas; Owner: -
--

CREATE TABLE finanzas.entrega_premio (
    id_entrega_premio bigint NOT NULL,
    id_torneo_premio bigint NOT NULL,
    id_resultado_torneo bigint NOT NULL,
    id_estado_entrega_premio smallint NOT NULL,
    autorizado_por bigint,
    entregado_por bigint,
    fecha_autorizacion timestamp with time zone,
    fecha_entrega timestamp with time zone,
    fecha_registro timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    fecha_actualizacion timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    observaciones character varying(500),
    CONSTRAINT ck_entrega_premio_autorizacion CHECK ((((autorizado_por IS NULL) AND (fecha_autorizacion IS NULL)) OR ((autorizado_por IS NOT NULL) AND (fecha_autorizacion IS NOT NULL)))),
    CONSTRAINT ck_entrega_premio_entrega CHECK ((((entregado_por IS NULL) AND (fecha_entrega IS NULL)) OR ((entregado_por IS NOT NULL) AND (fecha_entrega IS NOT NULL))))
);


--
-- Name: entrega_premio_id_entrega_premio_seq; Type: SEQUENCE; Schema: finanzas; Owner: -
--

ALTER TABLE finanzas.entrega_premio ALTER COLUMN id_entrega_premio ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME finanzas.entrega_premio_id_entrega_premio_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: pago; Type: TABLE; Schema: finanzas; Owner: -
--

CREATE TABLE finanzas.pago (
    id_pago bigint NOT NULL,
    id_inscripcion bigint NOT NULL,
    id_metodo_pago smallint NOT NULL,
    id_estado_pago smallint NOT NULL,
    monto numeric(12,2) NOT NULL,
    moneda character(3) NOT NULL,
    referencia character varying(120),
    comprobante_url character varying(500),
    fecha_pago timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    fecha_verificacion timestamp with time zone,
    registrado_por bigint NOT NULL,
    verificado_por bigint,
    observaciones character varying(500),
    fecha_registro timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    fecha_actualizacion timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT ck_pago_moneda CHECK ((((moneda)::text = upper((moneda)::text)) AND (length(moneda) = 3))),
    CONSTRAINT ck_pago_monto CHECK ((monto > (0)::numeric)),
    CONSTRAINT ck_pago_verificacion CHECK ((((verificado_por IS NULL) AND (fecha_verificacion IS NULL)) OR ((verificado_por IS NOT NULL) AND (fecha_verificacion IS NOT NULL))))
);


--
-- Name: pago_id_pago_seq; Type: SEQUENCE; Schema: finanzas; Owner: -
--

ALTER TABLE finanzas.pago ALTER COLUMN id_pago ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME finanzas.pago_id_pago_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: premio; Type: TABLE; Schema: finanzas; Owner: -
--

CREATE TABLE finanzas.premio (
    id_premio bigint NOT NULL,
    id_tipo_premio smallint NOT NULL,
    codigo character varying(50) NOT NULL,
    nombre character varying(150) NOT NULL,
    descripcion character varying(500),
    activo boolean DEFAULT true NOT NULL,
    fecha_registro timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT ck_premio_codigo CHECK (((codigo)::text = upper((codigo)::text))),
    CONSTRAINT ck_premio_nombre CHECK ((length(btrim((nombre)::text)) >= 3))
);


--
-- Name: premio_id_premio_seq; Type: SEQUENCE; Schema: finanzas; Owner: -
--

ALTER TABLE finanzas.premio ALTER COLUMN id_premio ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME finanzas.premio_id_premio_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: torneo_premio; Type: TABLE; Schema: finanzas; Owner: -
--

CREATE TABLE finanzas.torneo_premio (
    id_torneo_premio bigint NOT NULL,
    id_torneo bigint NOT NULL,
    id_premio bigint NOT NULL,
    posicion_objetivo smallint NOT NULL,
    valor_economico numeric(12,2) DEFAULT 0 NOT NULL,
    moneda character(3) DEFAULT 'BOB'::bpchar NOT NULL,
    descripcion_entrega character varying(500),
    registrado_por bigint NOT NULL,
    fecha_registro timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT ck_torneo_premio_moneda CHECK ((((moneda)::text = upper((moneda)::text)) AND (length(moneda) = 3))),
    CONSTRAINT ck_torneo_premio_posicion CHECK ((posicion_objetivo > 0)),
    CONSTRAINT ck_torneo_premio_valor CHECK ((valor_economico >= (0)::numeric))
);


--
-- Name: torneo_premio_id_torneo_premio_seq; Type: SEQUENCE; Schema: finanzas; Owner: -
--

ALTER TABLE finanzas.torneo_premio ALTER COLUMN id_torneo_premio ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME finanzas.torneo_premio_id_torneo_premio_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: arbitro; Type: TABLE; Schema: participantes; Owner: -
--

CREATE TABLE participantes.arbitro (
    id_usuario bigint NOT NULL,
    numero_licencia character varying(50),
    nivel character varying(50),
    anios_experiencia smallint DEFAULT 0 NOT NULL,
    id_estado_perfil smallint NOT NULL,
    fecha_registro timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    observaciones character varying(500),
    CONSTRAINT ck_arbitro_anios_experiencia CHECK ((anios_experiencia >= 0))
);


--
-- Name: TABLE arbitro; Type: COMMENT; Schema: participantes; Owner: -
--

COMMENT ON TABLE participantes.arbitro IS 'Perfil de los usuarios habilitados para actuar como arbitros.';


--
-- Name: equipo; Type: TABLE; Schema: participantes; Owner: -
--

CREATE TABLE participantes.equipo (
    id_equipo bigint NOT NULL,
    nombre character varying(120) NOT NULL,
    sigla character varying(15),
    fecha_fundacion date,
    descripcion character varying(500),
    logo_url character varying(500),
    id_estado_equipo smallint NOT NULL,
    creado_por bigint,
    fecha_registro timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    fecha_actualizacion timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT ck_equipo_fecha_fundacion CHECK (((fecha_fundacion IS NULL) OR (fecha_fundacion >= '1900-01-01'::date))),
    CONSTRAINT ck_equipo_nombre CHECK ((length(btrim((nombre)::text)) >= 3)),
    CONSTRAINT ck_equipo_sigla CHECK (((sigla IS NULL) OR (((length(btrim((sigla)::text)) >= 2) AND (length(btrim((sigla)::text)) <= 15)) AND ((sigla)::text = upper((sigla)::text)))))
);


--
-- Name: TABLE equipo; Type: COMMENT; Schema: participantes; Owner: -
--

COMMENT ON TABLE participantes.equipo IS 'Equipos deportivos registrados en el sistema.';


--
-- Name: equipo_id_equipo_seq; Type: SEQUENCE; Schema: participantes; Owner: -
--

ALTER TABLE participantes.equipo ALTER COLUMN id_equipo ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME participantes.equipo_id_equipo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: jugador; Type: TABLE; Schema: participantes; Owner: -
--

CREATE TABLE participantes.jugador (
    id_usuario bigint NOT NULL,
    alias_deportivo character varying(80),
    id_estado_perfil smallint NOT NULL,
    fecha_registro timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    observaciones character varying(500),
    CONSTRAINT ck_jugador_alias CHECK (((alias_deportivo IS NULL) OR (length(btrim((alias_deportivo)::text)) >= 2)))
);


--
-- Name: TABLE jugador; Type: COMMENT; Schema: participantes; Owner: -
--

COMMENT ON TABLE participantes.jugador IS 'Perfil deportivo de los usuarios que pueden participar como jugadores.';


--
-- Name: jugador_equipo; Type: TABLE; Schema: participantes; Owner: -
--

CREATE TABLE participantes.jugador_equipo (
    id_jugador_equipo bigint NOT NULL,
    id_jugador bigint NOT NULL,
    id_equipo bigint NOT NULL,
    fecha_inicio date DEFAULT CURRENT_DATE NOT NULL,
    fecha_fin date,
    numero_camiseta smallint,
    posicion character varying(80),
    es_delegado boolean DEFAULT false NOT NULL,
    id_estado_membresia smallint NOT NULL,
    registrado_por bigint,
    fecha_registro timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    observaciones character varying(500),
    CONSTRAINT ck_jugador_equipo_camiseta CHECK (((numero_camiseta IS NULL) OR ((numero_camiseta >= 0) AND (numero_camiseta <= 999)))),
    CONSTRAINT ck_jugador_equipo_fechas CHECK (((fecha_fin IS NULL) OR (fecha_fin >= fecha_inicio)))
);


--
-- Name: TABLE jugador_equipo; Type: COMMENT; Schema: participantes; Owner: -
--

COMMENT ON TABLE participantes.jugador_equipo IS 'Historial de pertenencia de los jugadores a los equipos.';


--
-- Name: COLUMN jugador_equipo.fecha_fin; Type: COMMENT; Schema: participantes; Owner: -
--

COMMENT ON COLUMN participantes.jugador_equipo.fecha_fin IS 'Cuando es nula, la membresia se considera vigente.';


--
-- Name: COLUMN jugador_equipo.es_delegado; Type: COMMENT; Schema: participantes; Owner: -
--

COMMENT ON COLUMN participantes.jugador_equipo.es_delegado IS 'Indica si el jugador actua como delegado actual del equipo.';


--
-- Name: jugador_equipo_id_jugador_equipo_seq; Type: SEQUENCE; Schema: participantes; Owner: -
--

ALTER TABLE participantes.jugador_equipo ALTER COLUMN id_jugador_equipo ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME participantes.jugador_equipo_id_jugador_equipo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: organizador; Type: TABLE; Schema: participantes; Owner: -
--

CREATE TABLE participantes.organizador (
    id_usuario bigint NOT NULL,
    institucion character varying(150),
    cargo character varying(100),
    anios_experiencia smallint DEFAULT 0 NOT NULL,
    id_estado_perfil smallint NOT NULL,
    fecha_registro timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    observaciones character varying(500),
    CONSTRAINT ck_organizador_anios_experiencia CHECK ((anios_experiencia >= 0))
);


--
-- Name: TABLE organizador; Type: COMMENT; Schema: participantes; Owner: -
--

COMMENT ON TABLE participantes.organizador IS 'Perfil de los usuarios que pueden organizar torneos.';


--
-- Name: usuario; Type: TABLE; Schema: seguridad; Owner: -
--

CREATE TABLE seguridad.usuario (
    id_usuario bigint NOT NULL,
    id_tipo_documento smallint NOT NULL,
    numero_documento character varying(30) NOT NULL,
    nombres character varying(100) NOT NULL,
    apellido_paterno character varying(80),
    apellido_materno character varying(80),
    fecha_nacimiento date NOT NULL,
    sexo character(1),
    correo character varying(150) NOT NULL,
    telefono character varying(20),
    direccion character varying(200),
    zona character varying(100),
    contrasenia_hash character varying(255) NOT NULL,
    id_estado_usuario smallint NOT NULL,
    intentos_fallidos smallint DEFAULT 0 NOT NULL,
    ultimo_acceso timestamp with time zone,
    fecha_registro timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    fecha_actualizacion timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT ck_usuario_contrasenia_hash CHECK ((length(btrim((contrasenia_hash)::text)) >= 20)),
    CONSTRAINT ck_usuario_correo CHECK (((correo)::text ~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$'::text)),
    CONSTRAINT ck_usuario_fecha_nacimiento CHECK ((fecha_nacimiento >= '1900-01-01'::date)),
    CONSTRAINT ck_usuario_intentos_fallidos CHECK ((intentos_fallidos >= 0)),
    CONSTRAINT ck_usuario_nombres CHECK ((length(btrim((nombres)::text)) >= 2)),
    CONSTRAINT ck_usuario_numero_documento CHECK ((length(btrim((numero_documento)::text)) >= 4)),
    CONSTRAINT ck_usuario_sexo CHECK (((sexo IS NULL) OR (sexo = ANY (ARRAY['M'::bpchar, 'F'::bpchar, 'O'::bpchar, 'N'::bpchar])))),
    CONSTRAINT ck_usuario_telefono CHECK (((telefono IS NULL) OR ((telefono)::text ~ '^\+?[0-9]{7,15}$'::text)))
);


--
-- Name: TABLE usuario; Type: COMMENT; Schema: seguridad; Owner: -
--

COMMENT ON TABLE seguridad.usuario IS 'Datos personales y credenciales de las personas registradas en el sistema.';


--
-- Name: COLUMN usuario.contrasenia_hash; Type: COMMENT; Schema: seguridad; Owner: -
--

COMMENT ON COLUMN seguridad.usuario.contrasenia_hash IS 'Hash de la contrasenia. Nunca debe almacenarse la contrasenia en texto plano.';


--
-- Name: vw_asistencia_jugadores; Type: VIEW; Schema: reportes; Owner: -
--

CREATE VIEW reportes.vw_asistencia_jugadores AS
 SELECT participacion.id_jugador_partido,
    torneo.id_torneo,
    torneo.nombre AS torneo,
    partido.id_partido,
    partido.codigo AS partido,
    equipo.id_equipo,
    equipo.nombre AS equipo,
    usuario.id_usuario AS id_jugador,
    usuario.numero_documento,
    usuario.nombres,
    usuario.apellido_paterno,
    usuario.apellido_materno,
    participacion.convocado,
    participacion.asistio,
    participacion.titular,
    participacion.minutos_jugados,
    participacion.puntos_anotados,
    participacion.faltas,
    participacion.amonestaciones,
    participacion.expulsado,
    participacion.lesionado,
    participacion.calificacion,
    participacion.estadisticas,
    participacion.fecha_actualizacion
   FROM (((((((competencia.jugador_partido participacion
     JOIN competencia.jugador_inscripcion jugador_nomina ON ((jugador_nomina.id_jugador_inscripcion = participacion.id_jugador_inscripcion)))
     JOIN seguridad.usuario usuario ON ((usuario.id_usuario = jugador_nomina.id_jugador)))
     JOIN competencia.partido partido ON ((partido.id_partido = participacion.id_partido)))
     JOIN competencia.partido_equipo partido_equipo ON ((partido_equipo.id_partido_equipo = participacion.id_partido_equipo)))
     JOIN competencia.inscripcion inscripcion ON ((inscripcion.id_inscripcion = partido_equipo.id_inscripcion)))
     JOIN participantes.equipo equipo ON ((equipo.id_equipo = inscripcion.id_equipo)))
     JOIN competencia.torneo torneo ON ((torneo.id_torneo = inscripcion.id_torneo)));


--
-- Name: vw_auditoria_dml_detalle; Type: VIEW; Schema: reportes; Owner: -
--

CREATE VIEW reportes.vw_auditoria_dml_detalle AS
 SELECT auditoria.id_auditoria,
    auditoria.fecha_evento,
    auditoria.esquema,
    auditoria.tabla,
    auditoria.operacion,
    auditoria.identificador_registro,
    auditoria.columnas_modificadas,
    auditoria.datos_anteriores,
    auditoria.datos_nuevos,
    auditoria.cambios,
    auditoria.usuario_aplicacion,
    concat_ws(' '::text, usuario.nombres, usuario.apellido_paterno, usuario.apellido_materno) AS usuario_aplicacion_nombre,
    auditoria.usuario_postgresql,
    auditoria.usuario_sesion,
    auditoria.ip_cliente,
    auditoria.id_solicitud,
    auditoria.id_transaccion,
    auditoria.aplicacion
   FROM (auditoria.auditoria_dml auditoria
     LEFT JOIN seguridad.usuario usuario ON ((usuario.id_usuario = auditoria.usuario_aplicacion)));


--
-- Name: vw_deportes_configuracion; Type: VIEW; Schema: reportes; Owner: -
--

CREATE VIEW reportes.vw_deportes_configuracion AS
 SELECT deporte.id_deporte,
    deporte.codigo,
    deporte.nombre,
    deporte.cantidad_minima_jugadores,
    deporte.cantidad_maxima_jugadores,
    deporte.cantidad_titulares,
    deporte.tipo_marcador,
    deporte.permite_empate,
    deporte.puntos_victoria,
    deporte.puntos_empate,
    deporte.puntos_derrota,
    estado.codigo AS estado_deporte,
    count(deporte_regla.id_deporte_regla) FILTER (WHERE ((deporte_regla.activo = true) AND (deporte_regla.fecha_fin IS NULL))) AS reglas_activas,
    count(deporte_regla.id_deporte_regla) FILTER (WHERE ((deporte_regla.obligatorio = true) AND (deporte_regla.activo = true) AND (deporte_regla.fecha_fin IS NULL))) AS reglas_obligatorias
   FROM ((competencia.deporte deporte
     JOIN catalogo.estado_deporte estado ON ((estado.id_estado_deporte = deporte.id_estado_deporte)))
     LEFT JOIN competencia.deporte_regla deporte_regla ON ((deporte_regla.id_deporte = deporte.id_deporte)))
  GROUP BY deporte.id_deporte, deporte.codigo, deporte.nombre, deporte.cantidad_minima_jugadores, deporte.cantidad_maxima_jugadores, deporte.cantidad_titulares, deporte.tipo_marcador, deporte.permite_empate, deporte.puntos_victoria, deporte.puntos_empate, deporte.puntos_derrota, estado.codigo;


--
-- Name: vw_estadisticas_jugadores_torneo; Type: VIEW; Schema: reportes; Owner: -
--

CREATE VIEW reportes.vw_estadisticas_jugadores_torneo AS
 SELECT torneo.id_torneo,
    torneo.nombre AS torneo,
    usuario.id_usuario AS id_jugador,
    usuario.numero_documento,
    usuario.nombres,
    usuario.apellido_paterno,
    usuario.apellido_materno,
    equipo.id_equipo,
    equipo.nombre AS equipo,
    count(DISTINCT participacion.id_partido) AS partidos_registrados,
    count(*) FILTER (WHERE (participacion.convocado = true)) AS veces_convocado,
    count(*) FILTER (WHERE (participacion.asistio = true)) AS asistencias,
    count(*) FILTER (WHERE (participacion.titular = true)) AS titularidades,
    round((((count(*) FILTER (WHERE (participacion.asistio = true)))::numeric / (NULLIF(count(*) FILTER (WHERE (participacion.convocado = true)), 0))::numeric) * (100)::numeric), 2) AS porcentaje_asistencia,
    sum(participacion.minutos_jugados) AS minutos_jugados,
    sum(participacion.puntos_anotados) AS puntos_anotados,
    sum(participacion.faltas) AS faltas,
    sum(participacion.amonestaciones) AS amonestaciones,
    count(*) FILTER (WHERE (participacion.expulsado = true)) AS expulsiones,
    count(*) FILTER (WHERE (participacion.lesionado = true)) AS lesiones,
    round(avg(participacion.calificacion), 2) AS calificacion_promedio
   FROM (((((competencia.jugador_partido participacion
     JOIN competencia.jugador_inscripcion jugador_nomina ON ((jugador_nomina.id_jugador_inscripcion = participacion.id_jugador_inscripcion)))
     JOIN seguridad.usuario usuario ON ((usuario.id_usuario = jugador_nomina.id_jugador)))
     JOIN competencia.inscripcion inscripcion ON ((inscripcion.id_inscripcion = jugador_nomina.id_inscripcion)))
     JOIN participantes.equipo equipo ON ((equipo.id_equipo = inscripcion.id_equipo)))
     JOIN competencia.torneo torneo ON ((torneo.id_torneo = inscripcion.id_torneo)))
  GROUP BY torneo.id_torneo, torneo.nombre, usuario.id_usuario, usuario.numero_documento, usuario.nombres, usuario.apellido_paterno, usuario.apellido_materno, equipo.id_equipo, equipo.nombre;


--
-- Name: vw_historial_jugador_equipo; Type: VIEW; Schema: reportes; Owner: -
--

CREATE VIEW reportes.vw_historial_jugador_equipo AS
 SELECT membresia.id_jugador_equipo,
    usuario.id_usuario AS id_jugador,
    usuario.numero_documento,
    usuario.nombres,
    usuario.apellido_paterno,
    usuario.apellido_materno,
    equipo.id_equipo,
    equipo.nombre AS equipo,
    equipo.sigla,
    membresia.fecha_inicio,
    membresia.fecha_fin,
        CASE
            WHEN (membresia.fecha_fin IS NULL) THEN 'VIGENTE'::text
            ELSE 'FINALIZADA'::text
        END AS vigencia,
    membresia.numero_camiseta,
    membresia.posicion,
    membresia.es_delegado,
    estado.codigo AS estado_membresia,
    membresia.observaciones
   FROM (((participantes.jugador_equipo membresia
     JOIN seguridad.usuario usuario ON ((usuario.id_usuario = membresia.id_jugador)))
     JOIN participantes.equipo equipo ON ((equipo.id_equipo = membresia.id_equipo)))
     JOIN catalogo.estado_membresia estado ON ((estado.id_estado_membresia = membresia.id_estado_membresia)));


--
-- Name: vw_inscripciones_resumen; Type: VIEW; Schema: reportes; Owner: -
--

CREATE VIEW reportes.vw_inscripciones_resumen AS
 SELECT inscripcion.id_inscripcion,
    torneo.id_torneo,
    torneo.codigo AS codigo_torneo,
    torneo.nombre AS torneo,
    equipo.id_equipo,
    equipo.nombre AS equipo,
    equipo.sigla,
    estado.codigo AS estado_inscripcion,
    inscripcion.monto_requerido,
    inscripcion.moneda,
    finanzas.fn_total_pagado_inscripcion(inscripcion.id_inscripcion) AS total_pagado,
    finanzas.fn_saldo_inscripcion(inscripcion.id_inscripcion) AS saldo_pendiente,
    ( SELECT count(*) AS count
           FROM competencia.jugador_inscripcion jugador
          WHERE ((jugador.id_inscripcion = inscripcion.id_inscripcion) AND (jugador.fecha_baja IS NULL))) AS jugadores_nomina,
    ( SELECT count(*) AS count
           FROM (competencia.jugador_inscripcion jugador
             JOIN catalogo.estado_jugador_inscripcion estado_jugador ON ((estado_jugador.id_estado_jugador_inscripcion = jugador.id_estado_jugador_inscripcion)))
          WHERE ((jugador.id_inscripcion = inscripcion.id_inscripcion) AND (jugador.fecha_baja IS NULL) AND ((estado_jugador.codigo)::text = 'HABILITADO'::text))) AS jugadores_habilitados,
    inscripcion.fecha_inscripcion,
    inscripcion.fecha_actualizacion
   FROM (((competencia.inscripcion inscripcion
     JOIN competencia.torneo torneo ON ((torneo.id_torneo = inscripcion.id_torneo)))
     JOIN participantes.equipo equipo ON ((equipo.id_equipo = inscripcion.id_equipo)))
     JOIN catalogo.estado_inscripcion estado ON ((estado.id_estado_inscripcion = inscripcion.id_estado_inscripcion)));


--
-- Name: vw_jugadores_equipo_actual; Type: VIEW; Schema: reportes; Owner: -
--

CREATE VIEW reportes.vw_jugadores_equipo_actual AS
 SELECT jugador.id_usuario AS id_jugador,
    usuario.numero_documento,
    usuario.nombres,
    usuario.apellido_paterno,
    usuario.apellido_materno,
    jugador.alias_deportivo,
    membresia.id_jugador_equipo,
    equipo.id_equipo,
    equipo.nombre AS equipo,
    equipo.sigla,
    membresia.numero_camiseta,
    membresia.posicion,
    membresia.es_delegado,
    membresia.fecha_inicio,
    estado_membresia.codigo AS estado_membresia,
    estado_equipo.codigo AS estado_equipo
   FROM (((((participantes.jugador jugador
     JOIN seguridad.usuario usuario ON ((usuario.id_usuario = jugador.id_usuario)))
     LEFT JOIN participantes.jugador_equipo membresia ON (((membresia.id_jugador = jugador.id_usuario) AND (membresia.fecha_fin IS NULL))))
     LEFT JOIN catalogo.estado_membresia estado_membresia ON ((estado_membresia.id_estado_membresia = membresia.id_estado_membresia)))
     LEFT JOIN participantes.equipo equipo ON ((equipo.id_equipo = membresia.id_equipo)))
     LEFT JOIN catalogo.estado_equipo estado_equipo ON ((estado_equipo.id_estado_equipo = equipo.id_estado_equipo)));


--
-- Name: vw_lugares_programacion; Type: VIEW; Schema: reportes; Owner: -
--

CREATE VIEW reportes.vw_lugares_programacion AS
 SELECT lugar.id_lugar,
    lugar.nombre,
    lugar.direccion,
    lugar.zona,
    lugar.ciudad,
    lugar.capacidad,
    lugar.tipo_superficie,
    lugar.activo,
    count(partido.id_partido) AS total_partidos,
    count(partido.id_partido) FILTER (WHERE ((estado_partido.codigo)::text = 'FINALIZADO'::text)) AS partidos_finalizados,
    count(partido.id_partido) FILTER (WHERE ((estado_partido.codigo)::text = 'PROGRAMADO'::text)) AS partidos_programados,
    min(partido.fecha_hora_inicio) FILTER (WHERE ((partido.fecha_hora_inicio >= CURRENT_TIMESTAMP) AND ((estado_partido.codigo)::text = ANY ((ARRAY['PROGRAMADO'::character varying, 'SUSPENDIDO'::character varying])::text[])))) AS proximo_partido
   FROM ((competencia.lugar lugar
     LEFT JOIN competencia.partido partido ON ((partido.id_lugar = lugar.id_lugar)))
     LEFT JOIN catalogo.estado_partido estado_partido ON ((estado_partido.id_estado_partido = partido.id_estado_partido)))
  GROUP BY lugar.id_lugar, lugar.nombre, lugar.direccion, lugar.zona, lugar.ciudad, lugar.capacidad, lugar.tipo_superficie, lugar.activo;


--
-- Name: vw_pagos_resumen; Type: VIEW; Schema: reportes; Owner: -
--

CREATE VIEW reportes.vw_pagos_resumen AS
 SELECT pago.id_pago,
    inscripcion.id_inscripcion,
    torneo.id_torneo,
    torneo.nombre AS torneo,
    equipo.id_equipo,
    equipo.nombre AS equipo,
    metodo.codigo AS metodo_pago,
    estado.codigo AS estado_pago,
    pago.monto,
    pago.moneda,
    pago.referencia,
    pago.fecha_pago,
    pago.fecha_verificacion,
    usuario_registro.id_usuario AS id_usuario_registro,
    concat_ws(' '::text, usuario_registro.nombres, usuario_registro.apellido_paterno, usuario_registro.apellido_materno) AS registrado_por,
    usuario_verificacion.id_usuario AS id_usuario_verificacion,
    concat_ws(' '::text, usuario_verificacion.nombres, usuario_verificacion.apellido_paterno, usuario_verificacion.apellido_materno) AS verificado_por,
    pago.observaciones
   FROM (((((((finanzas.pago pago
     JOIN competencia.inscripcion inscripcion ON ((inscripcion.id_inscripcion = pago.id_inscripcion)))
     JOIN competencia.torneo torneo ON ((torneo.id_torneo = inscripcion.id_torneo)))
     JOIN participantes.equipo equipo ON ((equipo.id_equipo = inscripcion.id_equipo)))
     JOIN catalogo.metodo_pago metodo ON ((metodo.id_metodo_pago = pago.id_metodo_pago)))
     JOIN catalogo.estado_pago estado ON ((estado.id_estado_pago = pago.id_estado_pago)))
     JOIN seguridad.usuario usuario_registro ON ((usuario_registro.id_usuario = pago.registrado_por)))
     LEFT JOIN seguridad.usuario usuario_verificacion ON ((usuario_verificacion.id_usuario = pago.verificado_por)));


--
-- Name: vw_partidos_detalle; Type: VIEW; Schema: reportes; Owner: -
--

CREATE VIEW reportes.vw_partidos_detalle AS
 SELECT partido.id_partido,
    partido.codigo,
    partido.numero_partido,
    partido.nombre_ronda,
    torneo.id_torneo,
    torneo.nombre AS torneo,
    fase.nombre AS fase,
    jornada.numero_jornada,
    jornada.nombre AS jornada,
    grupo.codigo AS grupo,
    lugar.nombre AS lugar,
    lugar.direccion AS direccion_lugar,
    partido.fecha_hora_inicio,
    partido.fecha_hora_fin,
    estado_partido.codigo AS estado_partido,
    max((equipo.nombre)::text) FILTER (WHERE ((condicion.codigo)::text = 'LOCAL'::text)) AS equipo_local,
    max(partido_equipo.marcador) FILTER (WHERE ((condicion.codigo)::text = 'LOCAL'::text)) AS marcador_local,
    max(partido_equipo.marcador_desempate) FILTER (WHERE ((condicion.codigo)::text = 'LOCAL'::text)) AS desempate_local,
    max((resultado.codigo)::text) FILTER (WHERE ((condicion.codigo)::text = 'LOCAL'::text)) AS resultado_local,
    max((equipo.nombre)::text) FILTER (WHERE ((condicion.codigo)::text = 'VISITANTE'::text)) AS equipo_visitante,
    max(partido_equipo.marcador) FILTER (WHERE ((condicion.codigo)::text = 'VISITANTE'::text)) AS marcador_visitante,
    max(partido_equipo.marcador_desempate) FILTER (WHERE ((condicion.codigo)::text = 'VISITANTE'::text)) AS desempate_visitante,
    max((resultado.codigo)::text) FILTER (WHERE ((condicion.codigo)::text = 'VISITANTE'::text)) AS resultado_visitante,
    partido.observaciones
   FROM (((((((((((competencia.partido partido
     JOIN competencia.jornada jornada ON ((jornada.id_jornada = partido.id_jornada)))
     JOIN competencia.fase_torneo fase ON ((fase.id_fase_torneo = jornada.id_fase_torneo)))
     JOIN competencia.torneo torneo ON ((torneo.id_torneo = fase.id_torneo)))
     JOIN catalogo.estado_partido estado_partido ON ((estado_partido.id_estado_partido = partido.id_estado_partido)))
     LEFT JOIN competencia.grupo_torneo grupo ON ((grupo.id_grupo_torneo = partido.id_grupo_torneo)))
     LEFT JOIN competencia.lugar lugar ON ((lugar.id_lugar = partido.id_lugar)))
     LEFT JOIN competencia.partido_equipo partido_equipo ON ((partido_equipo.id_partido = partido.id_partido)))
     LEFT JOIN competencia.inscripcion inscripcion ON ((inscripcion.id_inscripcion = partido_equipo.id_inscripcion)))
     LEFT JOIN participantes.equipo equipo ON ((equipo.id_equipo = inscripcion.id_equipo)))
     LEFT JOIN catalogo.condicion_equipo_partido condicion ON ((condicion.id_condicion_equipo = partido_equipo.id_condicion_equipo)))
     LEFT JOIN catalogo.resultado_equipo_partido resultado ON ((resultado.id_resultado_equipo_partido = partido_equipo.id_resultado_equipo_partido)))
  GROUP BY partido.id_partido, partido.codigo, partido.numero_partido, partido.nombre_ronda, torneo.id_torneo, torneo.nombre, fase.nombre, jornada.numero_jornada, jornada.nombre, grupo.codigo, lugar.nombre, lugar.direccion, partido.fecha_hora_inicio, partido.fecha_hora_fin, estado_partido.codigo, partido.observaciones;


--
-- Name: vw_premios_entregas; Type: VIEW; Schema: reportes; Owner: -
--

CREATE VIEW reportes.vw_premios_entregas AS
 SELECT torneo_premio.id_torneo_premio,
    torneo.id_torneo,
    torneo.nombre AS torneo,
    torneo_premio.posicion_objetivo,
    premio.id_premio,
    premio.nombre AS premio,
    tipo.codigo AS tipo_premio,
    torneo_premio.valor_economico,
    torneo_premio.moneda,
    resultado.id_resultado_torneo,
    resultado.posicion_final,
    equipo.id_equipo,
    equipo.nombre AS equipo_ganador,
    entrega.id_entrega_premio,
    estado_entrega.codigo AS estado_entrega,
    entrega.fecha_autorizacion,
    entrega.fecha_entrega,
    entrega.autorizado_por,
    entrega.entregado_por,
    entrega.observaciones
   FROM ((((((((finanzas.torneo_premio torneo_premio
     JOIN competencia.torneo torneo ON ((torneo.id_torneo = torneo_premio.id_torneo)))
     JOIN finanzas.premio premio ON ((premio.id_premio = torneo_premio.id_premio)))
     JOIN catalogo.tipo_premio tipo ON ((tipo.id_tipo_premio = premio.id_tipo_premio)))
     LEFT JOIN competencia.resultado_torneo resultado ON (((resultado.id_torneo = torneo_premio.id_torneo) AND (resultado.posicion_final = torneo_premio.posicion_objetivo))))
     LEFT JOIN competencia.inscripcion inscripcion ON ((inscripcion.id_inscripcion = resultado.id_inscripcion)))
     LEFT JOIN participantes.equipo equipo ON ((equipo.id_equipo = inscripcion.id_equipo)))
     LEFT JOIN finanzas.entrega_premio entrega ON ((entrega.id_torneo_premio = torneo_premio.id_torneo_premio)))
     LEFT JOIN catalogo.estado_entrega_premio estado_entrega ON ((estado_entrega.id_estado_entrega_premio = entrega.id_estado_entrega_premio)));


--
-- Name: vw_resultados_torneo; Type: VIEW; Schema: reportes; Owner: -
--

CREATE VIEW reportes.vw_resultados_torneo AS
 SELECT resultado.id_resultado_torneo,
    torneo.id_torneo,
    torneo.codigo AS codigo_torneo,
    torneo.nombre AS torneo,
    deporte.nombre AS deporte,
    resultado.posicion_final,
    equipo.id_equipo,
    equipo.nombre AS equipo,
    equipo.sigla,
    resultado.partidos_jugados,
    resultado.partidos_ganados,
    resultado.partidos_empatados,
    resultado.partidos_perdidos,
    resultado.marcador_favor,
    resultado.marcador_contra,
    resultado.diferencia_marcador,
    resultado.puntos,
    resultado.fecha_generacion,
    resultado.observaciones
   FROM ((((competencia.resultado_torneo resultado
     JOIN competencia.torneo torneo ON ((torneo.id_torneo = resultado.id_torneo)))
     JOIN competencia.deporte deporte ON ((deporte.id_deporte = torneo.id_deporte)))
     JOIN competencia.inscripcion inscripcion ON ((inscripcion.id_inscripcion = resultado.id_inscripcion)))
     JOIN participantes.equipo equipo ON ((equipo.id_equipo = inscripcion.id_equipo)));


--
-- Name: vw_resumen_usuarios_estado; Type: VIEW; Schema: reportes; Owner: -
--

CREATE VIEW reportes.vw_resumen_usuarios_estado AS
 SELECT estado.id_estado_usuario,
    estado.codigo AS estado_usuario,
    estado.nombre,
    count(usuario.id_usuario) AS cantidad_usuarios,
    count(*) FILTER (WHERE (usuario.ultimo_acceso IS NOT NULL)) AS usuarios_con_acceso,
    count(*) FILTER (WHERE (usuario.ultimo_acceso IS NULL)) AS usuarios_sin_acceso,
    max(usuario.fecha_registro) AS ultimo_usuario_registrado
   FROM (catalogo.estado_usuario estado
     LEFT JOIN seguridad.usuario usuario ON ((usuario.id_estado_usuario = estado.id_estado_usuario)))
  GROUP BY estado.id_estado_usuario, estado.codigo, estado.nombre;


--
-- Name: vw_torneos_resumen; Type: VIEW; Schema: reportes; Owner: -
--

CREATE VIEW reportes.vw_torneos_resumen AS
 SELECT torneo.id_torneo,
    torneo.codigo,
    torneo.nombre,
    torneo.edicion,
    torneo.categoria,
    torneo.rama,
    deporte.nombre AS deporte,
    formato.codigo AS formato,
    estado.codigo AS estado_torneo,
    torneo.fecha_inicio_inscripcion,
    torneo.fecha_fin_inscripcion,
    torneo.fecha_inicio_torneo,
    torneo.fecha_fin_torneo,
    torneo.cantidad_maxima_equipos,
    torneo.cantidad_minima_jugadores,
    torneo.cantidad_maxima_jugadores,
    torneo.costo_inscripcion,
    torneo.moneda,
    ( SELECT count(*) AS count
           FROM competencia.inscripcion inscripcion
          WHERE (inscripcion.id_torneo = torneo.id_torneo)) AS total_inscripciones,
    ( SELECT count(*) AS count
           FROM (competencia.inscripcion inscripcion
             JOIN catalogo.estado_inscripcion estado_inscripcion ON ((estado_inscripcion.id_estado_inscripcion = inscripcion.id_estado_inscripcion)))
          WHERE ((inscripcion.id_torneo = torneo.id_torneo) AND ((estado_inscripcion.codigo)::text = 'HABILITADA'::text))) AS inscripciones_habilitadas,
    ( SELECT count(*) AS count
           FROM competencia.fase_torneo fase
          WHERE (fase.id_torneo = torneo.id_torneo)) AS total_fases,
    ( SELECT count(*) AS count
           FROM ((competencia.partido partido
             JOIN competencia.jornada jornada ON ((jornada.id_jornada = partido.id_jornada)))
             JOIN competencia.fase_torneo fase ON ((fase.id_fase_torneo = jornada.id_fase_torneo)))
          WHERE (fase.id_torneo = torneo.id_torneo)) AS total_partidos,
    ( SELECT count(*) AS count
           FROM (((competencia.partido partido
             JOIN catalogo.estado_partido estado_partido ON ((estado_partido.id_estado_partido = partido.id_estado_partido)))
             JOIN competencia.jornada jornada ON ((jornada.id_jornada = partido.id_jornada)))
             JOIN competencia.fase_torneo fase ON ((fase.id_fase_torneo = jornada.id_fase_torneo)))
          WHERE ((fase.id_torneo = torneo.id_torneo) AND ((estado_partido.codigo)::text = 'FINALIZADO'::text))) AS partidos_finalizados,
    ( SELECT COALESCE(sum(pago.monto), (0)::numeric) AS "coalesce"
           FROM ((finanzas.pago pago
             JOIN catalogo.estado_pago estado_pago ON ((estado_pago.id_estado_pago = pago.id_estado_pago)))
             JOIN competencia.inscripcion inscripcion ON ((inscripcion.id_inscripcion = pago.id_inscripcion)))
          WHERE ((inscripcion.id_torneo = torneo.id_torneo) AND ((estado_pago.codigo)::text = 'CONFIRMADO'::text))) AS total_recaudado
   FROM (((competencia.torneo torneo
     JOIN competencia.deporte deporte ON ((deporte.id_deporte = torneo.id_deporte)))
     JOIN catalogo.formato_torneo formato ON ((formato.id_formato_torneo = torneo.id_formato_torneo)))
     JOIN catalogo.estado_torneo estado ON ((estado.id_estado_torneo = torneo.id_estado_torneo)));


--
-- Name: rol; Type: TABLE; Schema: seguridad; Owner: -
--

CREATE TABLE seguridad.rol (
    id_rol smallint NOT NULL,
    codigo character varying(40) NOT NULL,
    nombre character varying(80) NOT NULL,
    descripcion character varying(250),
    activo boolean DEFAULT true NOT NULL,
    CONSTRAINT ck_rol_codigo CHECK (((codigo)::text = upper((codigo)::text))),
    CONSTRAINT ck_rol_nombre CHECK ((length(btrim((nombre)::text)) >= 2))
);


--
-- Name: TABLE rol; Type: COMMENT; Schema: seguridad; Owner: -
--

COMMENT ON TABLE seguridad.rol IS 'Roles generales que una persona puede desempeñar dentro del sistema.';


--
-- Name: usuario_rol; Type: TABLE; Schema: seguridad; Owner: -
--

CREATE TABLE seguridad.usuario_rol (
    id_usuario_rol bigint NOT NULL,
    id_usuario bigint NOT NULL,
    id_rol smallint NOT NULL,
    fecha_inicio date DEFAULT CURRENT_DATE NOT NULL,
    fecha_fin date,
    activo boolean DEFAULT true NOT NULL,
    asignado_por bigint,
    fecha_asignacion timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT ck_usuario_rol_activo_fechas CHECK (((activo = false) OR (fecha_fin IS NULL))),
    CONSTRAINT ck_usuario_rol_fechas CHECK (((fecha_fin IS NULL) OR (fecha_fin >= fecha_inicio)))
);


--
-- Name: TABLE usuario_rol; Type: COMMENT; Schema: seguridad; Owner: -
--

COMMENT ON TABLE seguridad.usuario_rol IS 'Historial de roles generales asignados a cada usuario.';


--
-- Name: vw_usuarios_roles; Type: VIEW; Schema: reportes; Owner: -
--

CREATE VIEW reportes.vw_usuarios_roles AS
 SELECT usuario.id_usuario,
    usuario.numero_documento,
    usuario.nombres,
    usuario.apellido_paterno,
    usuario.apellido_materno,
    usuario.correo,
    usuario.telefono,
    estado.codigo AS estado_usuario,
    COALESCE(string_agg(DISTINCT (rol.codigo)::text, ', '::text ORDER BY (rol.codigo)::text) FILTER (WHERE ((usuario_rol.activo = true) AND (usuario_rol.fecha_fin IS NULL))), 'SIN_ROL'::text) AS roles_activos,
    usuario.ultimo_acceso,
    usuario.fecha_registro
   FROM (((seguridad.usuario usuario
     JOIN catalogo.estado_usuario estado ON ((estado.id_estado_usuario = usuario.id_estado_usuario)))
     LEFT JOIN seguridad.usuario_rol usuario_rol ON ((usuario_rol.id_usuario = usuario.id_usuario)))
     LEFT JOIN seguridad.rol rol ON ((rol.id_rol = usuario_rol.id_rol)))
  GROUP BY usuario.id_usuario, usuario.numero_documento, usuario.nombres, usuario.apellido_paterno, usuario.apellido_materno, usuario.correo, usuario.telefono, estado.codigo, usuario.ultimo_acceso, usuario.fecha_registro;


--
-- Name: rol_id_rol_seq; Type: SEQUENCE; Schema: seguridad; Owner: -
--

ALTER TABLE seguridad.rol ALTER COLUMN id_rol ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME seguridad.rol_id_rol_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: usuario_id_usuario_seq; Type: SEQUENCE; Schema: seguridad; Owner: -
--

ALTER TABLE seguridad.usuario ALTER COLUMN id_usuario ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME seguridad.usuario_id_usuario_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: usuario_rol_id_usuario_rol_seq; Type: SEQUENCE; Schema: seguridad; Owner: -
--

ALTER TABLE seguridad.usuario_rol ALTER COLUMN id_usuario_rol ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME seguridad.usuario_rol_id_usuario_rol_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Data for Name: auditoria_dml; Type: TABLE DATA; Schema: auditoria; Owner: -
--

COPY auditoria.auditoria_dml (id_auditoria, esquema, tabla, operacion, identificador_registro, datos_anteriores, datos_nuevos, cambios, columnas_modificadas, usuario_aplicacion, usuario_postgresql, usuario_sesion, aplicacion, ip_cliente, id_solicitud, id_transaccion, pid_backend, fecha_evento) FROM stdin;
1	competencia	regla	INSERT	{"id_regla": 1}	\N	{"activo": true, "codigo": "AUDITORIA_PRUEBA_001", "nombre": "Regla de prueba de auditoria", "id_regla": 1, "categoria": "GENERAL", "descripcion": "Registro creado para comprobar el trigger general", "fecha_registro": "2026-07-22T05:13:57.563784+00:00"}	{"activo": {"nuevo": true, "anterior": null}, "codigo": {"nuevo": "AUDITORIA_PRUEBA_001", "anterior": null}, "nombre": {"nuevo": "Regla de prueba de auditoria", "anterior": null}, "id_regla": {"nuevo": 1, "anterior": null}, "categoria": {"nuevo": "GENERAL", "anterior": null}, "descripcion": {"nuevo": "Registro creado para comprobar el trigger general", "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T05:13:57.563784+00:00", "anterior": null}}	{activo,categoria,codigo,descripcion,fecha_registro,id_regla,nombre}	1	postgres	postgres	DataGrip 2026.1.3	127.0.0.1	PRUEBA-AUDITORIA-001	3577	13170	2026-07-22 01:13:57.563784-04
2	competencia	regla	UPDATE	{"id_regla": 1}	{"activo": true, "codigo": "AUDITORIA_PRUEBA_001", "nombre": "Regla de prueba de auditoria", "id_regla": 1, "categoria": "GENERAL", "descripcion": "Registro creado para comprobar el trigger general", "fecha_registro": "2026-07-22T05:13:57.563784+00:00"}	{"activo": true, "codigo": "AUDITORIA_PRUEBA_001", "nombre": "Regla de auditoria modificada", "id_regla": 1, "categoria": "GENERAL", "descripcion": "La descripcion fue modificada", "fecha_registro": "2026-07-22T05:13:57.563784+00:00"}	{"nombre": {"nuevo": "Regla de auditoria modificada", "anterior": "Regla de prueba de auditoria"}, "descripcion": {"nuevo": "La descripcion fue modificada", "anterior": "Registro creado para comprobar el trigger general"}}	{descripcion,nombre}	1	postgres	postgres	DataGrip 2026.1.3	127.0.0.1	PRUEBA-AUDITORIA-001	3577	13170	2026-07-22 01:13:57.563784-04
3	competencia	regla	DELETE	{"id_regla": 1}	{"activo": true, "codigo": "AUDITORIA_PRUEBA_001", "nombre": "Regla de auditoria modificada", "id_regla": 1, "categoria": "GENERAL", "descripcion": "La descripcion fue modificada", "fecha_registro": "2026-07-22T05:13:57.563784+00:00"}	\N	{"activo": {"nuevo": null, "anterior": true}, "codigo": {"nuevo": null, "anterior": "AUDITORIA_PRUEBA_001"}, "nombre": {"nuevo": null, "anterior": "Regla de auditoria modificada"}, "id_regla": {"nuevo": null, "anterior": 1}, "categoria": {"nuevo": null, "anterior": "GENERAL"}, "descripcion": {"nuevo": null, "anterior": "La descripcion fue modificada"}, "fecha_registro": {"nuevo": null, "anterior": "2026-07-22T05:13:57.563784+00:00"}}	{activo,categoria,codigo,descripcion,fecha_registro,id_regla,nombre}	1	postgres	postgres	DataGrip 2026.1.3	127.0.0.1	PRUEBA-AUDITORIA-001	3577	13170	2026-07-22 01:13:57.563784-04
4	seguridad	usuario	INSERT	{"id_usuario": 1}	\N	{"sexo": "F", "zona": "Centro", "correo": "admin.demo@torneos.test", "nombres": "Andrea", "telefono": "76500001", "direccion": "Calle Demo 101", "id_usuario": 1, "ultimo_acceso": null, "fecha_registro": "2026-07-22T01:33:28.562517-04:00", "apellido_materno": "Mamani", "apellido_paterno": "Rojas", "fecha_nacimiento": "1995-03-10", "numero_documento": "7000001", "id_estado_usuario": 1, "id_tipo_documento": 1, "intentos_fallidos": 0, "fecha_actualizacion": "2026-07-22T01:33:28.562517-04:00"}	{"sexo": {"nuevo": "F", "anterior": null}, "zona": {"nuevo": "Centro", "anterior": null}, "correo": {"nuevo": "admin.demo@torneos.test", "anterior": null}, "nombres": {"nuevo": "Andrea", "anterior": null}, "telefono": {"nuevo": "76500001", "anterior": null}, "direccion": {"nuevo": "Calle Demo 101", "anterior": null}, "id_usuario": {"nuevo": 1, "anterior": null}, "ultimo_acceso": {"nuevo": null, "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}, "apellido_materno": {"nuevo": "Mamani", "anterior": null}, "apellido_paterno": {"nuevo": "Rojas", "anterior": null}, "fecha_nacimiento": {"nuevo": "1995-03-10", "anterior": null}, "numero_documento": {"nuevo": "7000001", "anterior": null}, "id_estado_usuario": {"nuevo": 1, "anterior": null}, "id_tipo_documento": {"nuevo": 1, "anterior": null}, "intentos_fallidos": {"nuevo": 0, "anterior": null}, "fecha_actualizacion": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}}	{apellido_materno,apellido_paterno,correo,direccion,fecha_actualizacion,fecha_nacimiento,fecha_registro,id_estado_usuario,id_tipo_documento,id_usuario,intentos_fallidos,nombres,numero_documento,sexo,telefono,ultimo_acceso,zona}	\N	postgres	postgres	psql	127.0.0.1	CARGA-DATOS-DEMO-BASE-001	3584	17476	2026-07-22 01:33:28.562517-04
5	seguridad	usuario	INSERT	{"id_usuario": 2}	\N	{"sexo": "M", "zona": "Sopocachi", "correo": "organizador.demo@torneos.test", "nombres": "Marcos", "telefono": "76500002", "direccion": "Calle Demo 102", "id_usuario": 2, "ultimo_acceso": null, "fecha_registro": "2026-07-22T01:33:28.562517-04:00", "apellido_materno": "Flores", "apellido_paterno": "Quispe", "fecha_nacimiento": "1992-05-15", "numero_documento": "7000002", "id_estado_usuario": 1, "id_tipo_documento": 1, "intentos_fallidos": 0, "fecha_actualizacion": "2026-07-22T01:33:28.562517-04:00"}	{"sexo": {"nuevo": "M", "anterior": null}, "zona": {"nuevo": "Sopocachi", "anterior": null}, "correo": {"nuevo": "organizador.demo@torneos.test", "anterior": null}, "nombres": {"nuevo": "Marcos", "anterior": null}, "telefono": {"nuevo": "76500002", "anterior": null}, "direccion": {"nuevo": "Calle Demo 102", "anterior": null}, "id_usuario": {"nuevo": 2, "anterior": null}, "ultimo_acceso": {"nuevo": null, "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}, "apellido_materno": {"nuevo": "Flores", "anterior": null}, "apellido_paterno": {"nuevo": "Quispe", "anterior": null}, "fecha_nacimiento": {"nuevo": "1992-05-15", "anterior": null}, "numero_documento": {"nuevo": "7000002", "anterior": null}, "id_estado_usuario": {"nuevo": 1, "anterior": null}, "id_tipo_documento": {"nuevo": 1, "anterior": null}, "intentos_fallidos": {"nuevo": 0, "anterior": null}, "fecha_actualizacion": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}}	{apellido_materno,apellido_paterno,correo,direccion,fecha_actualizacion,fecha_nacimiento,fecha_registro,id_estado_usuario,id_tipo_documento,id_usuario,intentos_fallidos,nombres,numero_documento,sexo,telefono,ultimo_acceso,zona}	\N	postgres	postgres	psql	127.0.0.1	CARGA-DATOS-DEMO-BASE-001	3584	17476	2026-07-22 01:33:28.562517-04
6	seguridad	usuario	INSERT	{"id_usuario": 3}	\N	{"sexo": "M", "zona": "Miraflores", "correo": "arbitro.demo@torneos.test", "nombres": "Luis", "telefono": "76500003", "direccion": "Calle Demo 103", "id_usuario": 3, "ultimo_acceso": null, "fecha_registro": "2026-07-22T01:33:28.562517-04:00", "apellido_materno": "Condori", "apellido_paterno": "Flores", "fecha_nacimiento": "1990-08-21", "numero_documento": "7000003", "id_estado_usuario": 1, "id_tipo_documento": 1, "intentos_fallidos": 0, "fecha_actualizacion": "2026-07-22T01:33:28.562517-04:00"}	{"sexo": {"nuevo": "M", "anterior": null}, "zona": {"nuevo": "Miraflores", "anterior": null}, "correo": {"nuevo": "arbitro.demo@torneos.test", "anterior": null}, "nombres": {"nuevo": "Luis", "anterior": null}, "telefono": {"nuevo": "76500003", "anterior": null}, "direccion": {"nuevo": "Calle Demo 103", "anterior": null}, "id_usuario": {"nuevo": 3, "anterior": null}, "ultimo_acceso": {"nuevo": null, "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}, "apellido_materno": {"nuevo": "Condori", "anterior": null}, "apellido_paterno": {"nuevo": "Flores", "anterior": null}, "fecha_nacimiento": {"nuevo": "1990-08-21", "anterior": null}, "numero_documento": {"nuevo": "7000003", "anterior": null}, "id_estado_usuario": {"nuevo": 1, "anterior": null}, "id_tipo_documento": {"nuevo": 1, "anterior": null}, "intentos_fallidos": {"nuevo": 0, "anterior": null}, "fecha_actualizacion": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}}	{apellido_materno,apellido_paterno,correo,direccion,fecha_actualizacion,fecha_nacimiento,fecha_registro,id_estado_usuario,id_tipo_documento,id_usuario,intentos_fallidos,nombres,numero_documento,sexo,telefono,ultimo_acceso,zona}	\N	postgres	postgres	psql	127.0.0.1	CARGA-DATOS-DEMO-BASE-001	3584	17476	2026-07-22 01:33:28.562517-04
7	seguridad	usuario	INSERT	{"id_usuario": 4}	\N	{"sexo": "M", "zona": "Zona Norte", "correo": "titanes1@torneos.test", "nombres": "Carlos", "telefono": "76500101", "direccion": "Zona Norte 1", "id_usuario": 4, "ultimo_acceso": null, "fecha_registro": "2026-07-22T01:33:28.562517-04:00", "apellido_materno": "Rojas", "apellido_paterno": "Mendoza", "fecha_nacimiento": "2001-01-12", "numero_documento": "7100001", "id_estado_usuario": 1, "id_tipo_documento": 1, "intentos_fallidos": 0, "fecha_actualizacion": "2026-07-22T01:33:28.562517-04:00"}	{"sexo": {"nuevo": "M", "anterior": null}, "zona": {"nuevo": "Zona Norte", "anterior": null}, "correo": {"nuevo": "titanes1@torneos.test", "anterior": null}, "nombres": {"nuevo": "Carlos", "anterior": null}, "telefono": {"nuevo": "76500101", "anterior": null}, "direccion": {"nuevo": "Zona Norte 1", "anterior": null}, "id_usuario": {"nuevo": 4, "anterior": null}, "ultimo_acceso": {"nuevo": null, "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}, "apellido_materno": {"nuevo": "Rojas", "anterior": null}, "apellido_paterno": {"nuevo": "Mendoza", "anterior": null}, "fecha_nacimiento": {"nuevo": "2001-01-12", "anterior": null}, "numero_documento": {"nuevo": "7100001", "anterior": null}, "id_estado_usuario": {"nuevo": 1, "anterior": null}, "id_tipo_documento": {"nuevo": 1, "anterior": null}, "intentos_fallidos": {"nuevo": 0, "anterior": null}, "fecha_actualizacion": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}}	{apellido_materno,apellido_paterno,correo,direccion,fecha_actualizacion,fecha_nacimiento,fecha_registro,id_estado_usuario,id_tipo_documento,id_usuario,intentos_fallidos,nombres,numero_documento,sexo,telefono,ultimo_acceso,zona}	\N	postgres	postgres	psql	127.0.0.1	CARGA-DATOS-DEMO-BASE-001	3584	17476	2026-07-22 01:33:28.562517-04
8	seguridad	usuario	INSERT	{"id_usuario": 5}	\N	{"sexo": "M", "zona": "Zona Norte", "correo": "titanes2@torneos.test", "nombres": "Jorge", "telefono": "76500102", "direccion": "Zona Norte 2", "id_usuario": 5, "ultimo_acceso": null, "fecha_registro": "2026-07-22T01:33:28.562517-04:00", "apellido_materno": "Mamani", "apellido_paterno": "Paredes", "fecha_nacimiento": "2000-02-14", "numero_documento": "7100002", "id_estado_usuario": 1, "id_tipo_documento": 1, "intentos_fallidos": 0, "fecha_actualizacion": "2026-07-22T01:33:28.562517-04:00"}	{"sexo": {"nuevo": "M", "anterior": null}, "zona": {"nuevo": "Zona Norte", "anterior": null}, "correo": {"nuevo": "titanes2@torneos.test", "anterior": null}, "nombres": {"nuevo": "Jorge", "anterior": null}, "telefono": {"nuevo": "76500102", "anterior": null}, "direccion": {"nuevo": "Zona Norte 2", "anterior": null}, "id_usuario": {"nuevo": 5, "anterior": null}, "ultimo_acceso": {"nuevo": null, "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}, "apellido_materno": {"nuevo": "Mamani", "anterior": null}, "apellido_paterno": {"nuevo": "Paredes", "anterior": null}, "fecha_nacimiento": {"nuevo": "2000-02-14", "anterior": null}, "numero_documento": {"nuevo": "7100002", "anterior": null}, "id_estado_usuario": {"nuevo": 1, "anterior": null}, "id_tipo_documento": {"nuevo": 1, "anterior": null}, "intentos_fallidos": {"nuevo": 0, "anterior": null}, "fecha_actualizacion": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}}	{apellido_materno,apellido_paterno,correo,direccion,fecha_actualizacion,fecha_nacimiento,fecha_registro,id_estado_usuario,id_tipo_documento,id_usuario,intentos_fallidos,nombres,numero_documento,sexo,telefono,ultimo_acceso,zona}	\N	postgres	postgres	psql	127.0.0.1	CARGA-DATOS-DEMO-BASE-001	3584	17476	2026-07-22 01:33:28.562517-04
9	seguridad	usuario	INSERT	{"id_usuario": 6}	\N	{"sexo": "M", "zona": "Zona Norte", "correo": "titanes3@torneos.test", "nombres": "Miguel", "telefono": "76500103", "direccion": "Zona Norte 3", "id_usuario": 6, "ultimo_acceso": null, "fecha_registro": "2026-07-22T01:33:28.562517-04:00", "apellido_materno": "Choque", "apellido_paterno": "Lopez", "fecha_nacimiento": "2002-03-16", "numero_documento": "7100003", "id_estado_usuario": 1, "id_tipo_documento": 1, "intentos_fallidos": 0, "fecha_actualizacion": "2026-07-22T01:33:28.562517-04:00"}	{"sexo": {"nuevo": "M", "anterior": null}, "zona": {"nuevo": "Zona Norte", "anterior": null}, "correo": {"nuevo": "titanes3@torneos.test", "anterior": null}, "nombres": {"nuevo": "Miguel", "anterior": null}, "telefono": {"nuevo": "76500103", "anterior": null}, "direccion": {"nuevo": "Zona Norte 3", "anterior": null}, "id_usuario": {"nuevo": 6, "anterior": null}, "ultimo_acceso": {"nuevo": null, "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}, "apellido_materno": {"nuevo": "Choque", "anterior": null}, "apellido_paterno": {"nuevo": "Lopez", "anterior": null}, "fecha_nacimiento": {"nuevo": "2002-03-16", "anterior": null}, "numero_documento": {"nuevo": "7100003", "anterior": null}, "id_estado_usuario": {"nuevo": 1, "anterior": null}, "id_tipo_documento": {"nuevo": 1, "anterior": null}, "intentos_fallidos": {"nuevo": 0, "anterior": null}, "fecha_actualizacion": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}}	{apellido_materno,apellido_paterno,correo,direccion,fecha_actualizacion,fecha_nacimiento,fecha_registro,id_estado_usuario,id_tipo_documento,id_usuario,intentos_fallidos,nombres,numero_documento,sexo,telefono,ultimo_acceso,zona}	\N	postgres	postgres	psql	127.0.0.1	CARGA-DATOS-DEMO-BASE-001	3584	17476	2026-07-22 01:33:28.562517-04
10	seguridad	usuario	INSERT	{"id_usuario": 7}	\N	{"sexo": "M", "zona": "Zona Norte", "correo": "titanes4@torneos.test", "nombres": "Daniel", "telefono": "76500104", "direccion": "Zona Norte 4", "id_usuario": 7, "ultimo_acceso": null, "fecha_registro": "2026-07-22T01:33:28.562517-04:00", "apellido_materno": "Cruz", "apellido_paterno": "Vargas", "fecha_nacimiento": "2001-04-18", "numero_documento": "7100004", "id_estado_usuario": 1, "id_tipo_documento": 1, "intentos_fallidos": 0, "fecha_actualizacion": "2026-07-22T01:33:28.562517-04:00"}	{"sexo": {"nuevo": "M", "anterior": null}, "zona": {"nuevo": "Zona Norte", "anterior": null}, "correo": {"nuevo": "titanes4@torneos.test", "anterior": null}, "nombres": {"nuevo": "Daniel", "anterior": null}, "telefono": {"nuevo": "76500104", "anterior": null}, "direccion": {"nuevo": "Zona Norte 4", "anterior": null}, "id_usuario": {"nuevo": 7, "anterior": null}, "ultimo_acceso": {"nuevo": null, "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}, "apellido_materno": {"nuevo": "Cruz", "anterior": null}, "apellido_paterno": {"nuevo": "Vargas", "anterior": null}, "fecha_nacimiento": {"nuevo": "2001-04-18", "anterior": null}, "numero_documento": {"nuevo": "7100004", "anterior": null}, "id_estado_usuario": {"nuevo": 1, "anterior": null}, "id_tipo_documento": {"nuevo": 1, "anterior": null}, "intentos_fallidos": {"nuevo": 0, "anterior": null}, "fecha_actualizacion": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}}	{apellido_materno,apellido_paterno,correo,direccion,fecha_actualizacion,fecha_nacimiento,fecha_registro,id_estado_usuario,id_tipo_documento,id_usuario,intentos_fallidos,nombres,numero_documento,sexo,telefono,ultimo_acceso,zona}	\N	postgres	postgres	psql	127.0.0.1	CARGA-DATOS-DEMO-BASE-001	3584	17476	2026-07-22 01:33:28.562517-04
11	seguridad	usuario	INSERT	{"id_usuario": 8}	\N	{"sexo": "M", "zona": "Zona Norte", "correo": "titanes5@torneos.test", "nombres": "Pedro", "telefono": "76500105", "direccion": "Zona Norte 5", "id_usuario": 8, "ultimo_acceso": null, "fecha_registro": "2026-07-22T01:33:28.562517-04:00", "apellido_materno": "Luna", "apellido_paterno": "Salazar", "fecha_nacimiento": "2000-05-20", "numero_documento": "7100005", "id_estado_usuario": 1, "id_tipo_documento": 1, "intentos_fallidos": 0, "fecha_actualizacion": "2026-07-22T01:33:28.562517-04:00"}	{"sexo": {"nuevo": "M", "anterior": null}, "zona": {"nuevo": "Zona Norte", "anterior": null}, "correo": {"nuevo": "titanes5@torneos.test", "anterior": null}, "nombres": {"nuevo": "Pedro", "anterior": null}, "telefono": {"nuevo": "76500105", "anterior": null}, "direccion": {"nuevo": "Zona Norte 5", "anterior": null}, "id_usuario": {"nuevo": 8, "anterior": null}, "ultimo_acceso": {"nuevo": null, "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}, "apellido_materno": {"nuevo": "Luna", "anterior": null}, "apellido_paterno": {"nuevo": "Salazar", "anterior": null}, "fecha_nacimiento": {"nuevo": "2000-05-20", "anterior": null}, "numero_documento": {"nuevo": "7100005", "anterior": null}, "id_estado_usuario": {"nuevo": 1, "anterior": null}, "id_tipo_documento": {"nuevo": 1, "anterior": null}, "intentos_fallidos": {"nuevo": 0, "anterior": null}, "fecha_actualizacion": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}}	{apellido_materno,apellido_paterno,correo,direccion,fecha_actualizacion,fecha_nacimiento,fecha_registro,id_estado_usuario,id_tipo_documento,id_usuario,intentos_fallidos,nombres,numero_documento,sexo,telefono,ultimo_acceso,zona}	\N	postgres	postgres	psql	127.0.0.1	CARGA-DATOS-DEMO-BASE-001	3584	17476	2026-07-22 01:33:28.562517-04
12	seguridad	usuario	INSERT	{"id_usuario": 9}	\N	{"sexo": "M", "zona": "Zona Sur", "correo": "halcones1@torneos.test", "nombres": "Alejandro", "telefono": "76500201", "direccion": "Zona Sur 1", "id_usuario": 9, "ultimo_acceso": null, "fecha_registro": "2026-07-22T01:33:28.562517-04:00", "apellido_materno": "Ramos", "apellido_paterno": "Torrez", "fecha_nacimiento": "2001-06-22", "numero_documento": "7200001", "id_estado_usuario": 1, "id_tipo_documento": 1, "intentos_fallidos": 0, "fecha_actualizacion": "2026-07-22T01:33:28.562517-04:00"}	{"sexo": {"nuevo": "M", "anterior": null}, "zona": {"nuevo": "Zona Sur", "anterior": null}, "correo": {"nuevo": "halcones1@torneos.test", "anterior": null}, "nombres": {"nuevo": "Alejandro", "anterior": null}, "telefono": {"nuevo": "76500201", "anterior": null}, "direccion": {"nuevo": "Zona Sur 1", "anterior": null}, "id_usuario": {"nuevo": 9, "anterior": null}, "ultimo_acceso": {"nuevo": null, "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}, "apellido_materno": {"nuevo": "Ramos", "anterior": null}, "apellido_paterno": {"nuevo": "Torrez", "anterior": null}, "fecha_nacimiento": {"nuevo": "2001-06-22", "anterior": null}, "numero_documento": {"nuevo": "7200001", "anterior": null}, "id_estado_usuario": {"nuevo": 1, "anterior": null}, "id_tipo_documento": {"nuevo": 1, "anterior": null}, "intentos_fallidos": {"nuevo": 0, "anterior": null}, "fecha_actualizacion": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}}	{apellido_materno,apellido_paterno,correo,direccion,fecha_actualizacion,fecha_nacimiento,fecha_registro,id_estado_usuario,id_tipo_documento,id_usuario,intentos_fallidos,nombres,numero_documento,sexo,telefono,ultimo_acceso,zona}	\N	postgres	postgres	psql	127.0.0.1	CARGA-DATOS-DEMO-BASE-001	3584	17476	2026-07-22 01:33:28.562517-04
13	seguridad	usuario	INSERT	{"id_usuario": 10}	\N	{"sexo": "M", "zona": "Zona Sur", "correo": "halcones2@torneos.test", "nombres": "Rodrigo", "telefono": "76500202", "direccion": "Zona Sur 2", "id_usuario": 10, "ultimo_acceso": null, "fecha_registro": "2026-07-22T01:33:28.562517-04:00", "apellido_materno": "Poma", "apellido_paterno": "Gutierrez", "fecha_nacimiento": "2002-07-24", "numero_documento": "7200002", "id_estado_usuario": 1, "id_tipo_documento": 1, "intentos_fallidos": 0, "fecha_actualizacion": "2026-07-22T01:33:28.562517-04:00"}	{"sexo": {"nuevo": "M", "anterior": null}, "zona": {"nuevo": "Zona Sur", "anterior": null}, "correo": {"nuevo": "halcones2@torneos.test", "anterior": null}, "nombres": {"nuevo": "Rodrigo", "anterior": null}, "telefono": {"nuevo": "76500202", "anterior": null}, "direccion": {"nuevo": "Zona Sur 2", "anterior": null}, "id_usuario": {"nuevo": 10, "anterior": null}, "ultimo_acceso": {"nuevo": null, "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}, "apellido_materno": {"nuevo": "Poma", "anterior": null}, "apellido_paterno": {"nuevo": "Gutierrez", "anterior": null}, "fecha_nacimiento": {"nuevo": "2002-07-24", "anterior": null}, "numero_documento": {"nuevo": "7200002", "anterior": null}, "id_estado_usuario": {"nuevo": 1, "anterior": null}, "id_tipo_documento": {"nuevo": 1, "anterior": null}, "intentos_fallidos": {"nuevo": 0, "anterior": null}, "fecha_actualizacion": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}}	{apellido_materno,apellido_paterno,correo,direccion,fecha_actualizacion,fecha_nacimiento,fecha_registro,id_estado_usuario,id_tipo_documento,id_usuario,intentos_fallidos,nombres,numero_documento,sexo,telefono,ultimo_acceso,zona}	\N	postgres	postgres	psql	127.0.0.1	CARGA-DATOS-DEMO-BASE-001	3584	17476	2026-07-22 01:33:28.562517-04
14	seguridad	usuario	INSERT	{"id_usuario": 11}	\N	{"sexo": "M", "zona": "Zona Sur", "correo": "halcones3@torneos.test", "nombres": "Fernando", "telefono": "76500203", "direccion": "Zona Sur 3", "id_usuario": 11, "ultimo_acceso": null, "fecha_registro": "2026-07-22T01:33:28.562517-04:00", "apellido_materno": "Mendoza", "apellido_paterno": "Castro", "fecha_nacimiento": "2000-08-26", "numero_documento": "7200003", "id_estado_usuario": 1, "id_tipo_documento": 1, "intentos_fallidos": 0, "fecha_actualizacion": "2026-07-22T01:33:28.562517-04:00"}	{"sexo": {"nuevo": "M", "anterior": null}, "zona": {"nuevo": "Zona Sur", "anterior": null}, "correo": {"nuevo": "halcones3@torneos.test", "anterior": null}, "nombres": {"nuevo": "Fernando", "anterior": null}, "telefono": {"nuevo": "76500203", "anterior": null}, "direccion": {"nuevo": "Zona Sur 3", "anterior": null}, "id_usuario": {"nuevo": 11, "anterior": null}, "ultimo_acceso": {"nuevo": null, "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}, "apellido_materno": {"nuevo": "Mendoza", "anterior": null}, "apellido_paterno": {"nuevo": "Castro", "anterior": null}, "fecha_nacimiento": {"nuevo": "2000-08-26", "anterior": null}, "numero_documento": {"nuevo": "7200003", "anterior": null}, "id_estado_usuario": {"nuevo": 1, "anterior": null}, "id_tipo_documento": {"nuevo": 1, "anterior": null}, "intentos_fallidos": {"nuevo": 0, "anterior": null}, "fecha_actualizacion": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}}	{apellido_materno,apellido_paterno,correo,direccion,fecha_actualizacion,fecha_nacimiento,fecha_registro,id_estado_usuario,id_tipo_documento,id_usuario,intentos_fallidos,nombres,numero_documento,sexo,telefono,ultimo_acceso,zona}	\N	postgres	postgres	psql	127.0.0.1	CARGA-DATOS-DEMO-BASE-001	3584	17476	2026-07-22 01:33:28.562517-04
15	seguridad	usuario	INSERT	{"id_usuario": 12}	\N	{"sexo": "M", "zona": "Zona Sur", "correo": "halcones4@torneos.test", "nombres": "Ricardo", "telefono": "76500204", "direccion": "Zona Sur 4", "id_usuario": 12, "ultimo_acceso": null, "fecha_registro": "2026-07-22T01:33:28.562517-04:00", "apellido_materno": "Quisbert", "apellido_paterno": "Soria", "fecha_nacimiento": "2001-09-28", "numero_documento": "7200004", "id_estado_usuario": 1, "id_tipo_documento": 1, "intentos_fallidos": 0, "fecha_actualizacion": "2026-07-22T01:33:28.562517-04:00"}	{"sexo": {"nuevo": "M", "anterior": null}, "zona": {"nuevo": "Zona Sur", "anterior": null}, "correo": {"nuevo": "halcones4@torneos.test", "anterior": null}, "nombres": {"nuevo": "Ricardo", "anterior": null}, "telefono": {"nuevo": "76500204", "anterior": null}, "direccion": {"nuevo": "Zona Sur 4", "anterior": null}, "id_usuario": {"nuevo": 12, "anterior": null}, "ultimo_acceso": {"nuevo": null, "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}, "apellido_materno": {"nuevo": "Quisbert", "anterior": null}, "apellido_paterno": {"nuevo": "Soria", "anterior": null}, "fecha_nacimiento": {"nuevo": "2001-09-28", "anterior": null}, "numero_documento": {"nuevo": "7200004", "anterior": null}, "id_estado_usuario": {"nuevo": 1, "anterior": null}, "id_tipo_documento": {"nuevo": 1, "anterior": null}, "intentos_fallidos": {"nuevo": 0, "anterior": null}, "fecha_actualizacion": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}}	{apellido_materno,apellido_paterno,correo,direccion,fecha_actualizacion,fecha_nacimiento,fecha_registro,id_estado_usuario,id_tipo_documento,id_usuario,intentos_fallidos,nombres,numero_documento,sexo,telefono,ultimo_acceso,zona}	\N	postgres	postgres	psql	127.0.0.1	CARGA-DATOS-DEMO-BASE-001	3584	17476	2026-07-22 01:33:28.562517-04
16	seguridad	usuario	INSERT	{"id_usuario": 13}	\N	{"sexo": "M", "zona": "Zona Sur", "correo": "halcones5@torneos.test", "nombres": "Gabriel", "telefono": "76500205", "direccion": "Zona Sur 5", "id_usuario": 13, "ultimo_acceso": null, "fecha_registro": "2026-07-22T01:33:28.562517-04:00", "apellido_materno": "Flores", "apellido_paterno": "Nina", "fecha_nacimiento": "2002-10-30", "numero_documento": "7200005", "id_estado_usuario": 1, "id_tipo_documento": 1, "intentos_fallidos": 0, "fecha_actualizacion": "2026-07-22T01:33:28.562517-04:00"}	{"sexo": {"nuevo": "M", "anterior": null}, "zona": {"nuevo": "Zona Sur", "anterior": null}, "correo": {"nuevo": "halcones5@torneos.test", "anterior": null}, "nombres": {"nuevo": "Gabriel", "anterior": null}, "telefono": {"nuevo": "76500205", "anterior": null}, "direccion": {"nuevo": "Zona Sur 5", "anterior": null}, "id_usuario": {"nuevo": 13, "anterior": null}, "ultimo_acceso": {"nuevo": null, "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}, "apellido_materno": {"nuevo": "Flores", "anterior": null}, "apellido_paterno": {"nuevo": "Nina", "anterior": null}, "fecha_nacimiento": {"nuevo": "2002-10-30", "anterior": null}, "numero_documento": {"nuevo": "7200005", "anterior": null}, "id_estado_usuario": {"nuevo": 1, "anterior": null}, "id_tipo_documento": {"nuevo": 1, "anterior": null}, "intentos_fallidos": {"nuevo": 0, "anterior": null}, "fecha_actualizacion": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}}	{apellido_materno,apellido_paterno,correo,direccion,fecha_actualizacion,fecha_nacimiento,fecha_registro,id_estado_usuario,id_tipo_documento,id_usuario,intentos_fallidos,nombres,numero_documento,sexo,telefono,ultimo_acceso,zona}	\N	postgres	postgres	psql	127.0.0.1	CARGA-DATOS-DEMO-BASE-001	3584	17476	2026-07-22 01:33:28.562517-04
17	seguridad	usuario_rol	INSERT	{"id_usuario_rol": 1}	\N	{"activo": true, "id_rol": 1, "fecha_fin": null, "id_usuario": 1, "asignado_por": 1, "fecha_inicio": "2026-07-22", "id_usuario_rol": 1, "fecha_asignacion": "2026-07-22T01:33:28.562517-04:00"}	{"activo": {"nuevo": true, "anterior": null}, "id_rol": {"nuevo": 1, "anterior": null}, "fecha_fin": {"nuevo": null, "anterior": null}, "id_usuario": {"nuevo": 1, "anterior": null}, "asignado_por": {"nuevo": 1, "anterior": null}, "fecha_inicio": {"nuevo": "2026-07-22", "anterior": null}, "id_usuario_rol": {"nuevo": 1, "anterior": null}, "fecha_asignacion": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}}	{activo,asignado_por,fecha_asignacion,fecha_fin,fecha_inicio,id_rol,id_usuario,id_usuario_rol}	1	postgres	postgres	psql	127.0.0.1	CARGA-DATOS-DEMO-BASE-001	3584	17476	2026-07-22 01:33:28.562517-04
18	seguridad	usuario_rol	INSERT	{"id_usuario_rol": 2}	\N	{"activo": true, "id_rol": 2, "fecha_fin": null, "id_usuario": 2, "asignado_por": 1, "fecha_inicio": "2026-07-22", "id_usuario_rol": 2, "fecha_asignacion": "2026-07-22T01:33:28.562517-04:00"}	{"activo": {"nuevo": true, "anterior": null}, "id_rol": {"nuevo": 2, "anterior": null}, "fecha_fin": {"nuevo": null, "anterior": null}, "id_usuario": {"nuevo": 2, "anterior": null}, "asignado_por": {"nuevo": 1, "anterior": null}, "fecha_inicio": {"nuevo": "2026-07-22", "anterior": null}, "id_usuario_rol": {"nuevo": 2, "anterior": null}, "fecha_asignacion": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}}	{activo,asignado_por,fecha_asignacion,fecha_fin,fecha_inicio,id_rol,id_usuario,id_usuario_rol}	1	postgres	postgres	psql	127.0.0.1	CARGA-DATOS-DEMO-BASE-001	3584	17476	2026-07-22 01:33:28.562517-04
19	seguridad	usuario_rol	INSERT	{"id_usuario_rol": 3}	\N	{"activo": true, "id_rol": 3, "fecha_fin": null, "id_usuario": 3, "asignado_por": 1, "fecha_inicio": "2026-07-22", "id_usuario_rol": 3, "fecha_asignacion": "2026-07-22T01:33:28.562517-04:00"}	{"activo": {"nuevo": true, "anterior": null}, "id_rol": {"nuevo": 3, "anterior": null}, "fecha_fin": {"nuevo": null, "anterior": null}, "id_usuario": {"nuevo": 3, "anterior": null}, "asignado_por": {"nuevo": 1, "anterior": null}, "fecha_inicio": {"nuevo": "2026-07-22", "anterior": null}, "id_usuario_rol": {"nuevo": 3, "anterior": null}, "fecha_asignacion": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}}	{activo,asignado_por,fecha_asignacion,fecha_fin,fecha_inicio,id_rol,id_usuario,id_usuario_rol}	1	postgres	postgres	psql	127.0.0.1	CARGA-DATOS-DEMO-BASE-001	3584	17476	2026-07-22 01:33:28.562517-04
20	seguridad	usuario_rol	INSERT	{"id_usuario_rol": 4}	\N	{"activo": true, "id_rol": 4, "fecha_fin": null, "id_usuario": 13, "asignado_por": 1, "fecha_inicio": "2026-07-22", "id_usuario_rol": 4, "fecha_asignacion": "2026-07-22T01:33:28.562517-04:00"}	{"activo": {"nuevo": true, "anterior": null}, "id_rol": {"nuevo": 4, "anterior": null}, "fecha_fin": {"nuevo": null, "anterior": null}, "id_usuario": {"nuevo": 13, "anterior": null}, "asignado_por": {"nuevo": 1, "anterior": null}, "fecha_inicio": {"nuevo": "2026-07-22", "anterior": null}, "id_usuario_rol": {"nuevo": 4, "anterior": null}, "fecha_asignacion": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}}	{activo,asignado_por,fecha_asignacion,fecha_fin,fecha_inicio,id_rol,id_usuario,id_usuario_rol}	1	postgres	postgres	psql	127.0.0.1	CARGA-DATOS-DEMO-BASE-001	3584	17476	2026-07-22 01:33:28.562517-04
21	seguridad	usuario_rol	INSERT	{"id_usuario_rol": 5}	\N	{"activo": true, "id_rol": 4, "fecha_fin": null, "id_usuario": 12, "asignado_por": 1, "fecha_inicio": "2026-07-22", "id_usuario_rol": 5, "fecha_asignacion": "2026-07-22T01:33:28.562517-04:00"}	{"activo": {"nuevo": true, "anterior": null}, "id_rol": {"nuevo": 4, "anterior": null}, "fecha_fin": {"nuevo": null, "anterior": null}, "id_usuario": {"nuevo": 12, "anterior": null}, "asignado_por": {"nuevo": 1, "anterior": null}, "fecha_inicio": {"nuevo": "2026-07-22", "anterior": null}, "id_usuario_rol": {"nuevo": 5, "anterior": null}, "fecha_asignacion": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}}	{activo,asignado_por,fecha_asignacion,fecha_fin,fecha_inicio,id_rol,id_usuario,id_usuario_rol}	1	postgres	postgres	psql	127.0.0.1	CARGA-DATOS-DEMO-BASE-001	3584	17476	2026-07-22 01:33:28.562517-04
22	seguridad	usuario_rol	INSERT	{"id_usuario_rol": 6}	\N	{"activo": true, "id_rol": 4, "fecha_fin": null, "id_usuario": 11, "asignado_por": 1, "fecha_inicio": "2026-07-22", "id_usuario_rol": 6, "fecha_asignacion": "2026-07-22T01:33:28.562517-04:00"}	{"activo": {"nuevo": true, "anterior": null}, "id_rol": {"nuevo": 4, "anterior": null}, "fecha_fin": {"nuevo": null, "anterior": null}, "id_usuario": {"nuevo": 11, "anterior": null}, "asignado_por": {"nuevo": 1, "anterior": null}, "fecha_inicio": {"nuevo": "2026-07-22", "anterior": null}, "id_usuario_rol": {"nuevo": 6, "anterior": null}, "fecha_asignacion": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}}	{activo,asignado_por,fecha_asignacion,fecha_fin,fecha_inicio,id_rol,id_usuario,id_usuario_rol}	1	postgres	postgres	psql	127.0.0.1	CARGA-DATOS-DEMO-BASE-001	3584	17476	2026-07-22 01:33:28.562517-04
23	seguridad	usuario_rol	INSERT	{"id_usuario_rol": 7}	\N	{"activo": true, "id_rol": 4, "fecha_fin": null, "id_usuario": 10, "asignado_por": 1, "fecha_inicio": "2026-07-22", "id_usuario_rol": 7, "fecha_asignacion": "2026-07-22T01:33:28.562517-04:00"}	{"activo": {"nuevo": true, "anterior": null}, "id_rol": {"nuevo": 4, "anterior": null}, "fecha_fin": {"nuevo": null, "anterior": null}, "id_usuario": {"nuevo": 10, "anterior": null}, "asignado_por": {"nuevo": 1, "anterior": null}, "fecha_inicio": {"nuevo": "2026-07-22", "anterior": null}, "id_usuario_rol": {"nuevo": 7, "anterior": null}, "fecha_asignacion": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}}	{activo,asignado_por,fecha_asignacion,fecha_fin,fecha_inicio,id_rol,id_usuario,id_usuario_rol}	1	postgres	postgres	psql	127.0.0.1	CARGA-DATOS-DEMO-BASE-001	3584	17476	2026-07-22 01:33:28.562517-04
24	seguridad	usuario_rol	INSERT	{"id_usuario_rol": 8}	\N	{"activo": true, "id_rol": 4, "fecha_fin": null, "id_usuario": 9, "asignado_por": 1, "fecha_inicio": "2026-07-22", "id_usuario_rol": 8, "fecha_asignacion": "2026-07-22T01:33:28.562517-04:00"}	{"activo": {"nuevo": true, "anterior": null}, "id_rol": {"nuevo": 4, "anterior": null}, "fecha_fin": {"nuevo": null, "anterior": null}, "id_usuario": {"nuevo": 9, "anterior": null}, "asignado_por": {"nuevo": 1, "anterior": null}, "fecha_inicio": {"nuevo": "2026-07-22", "anterior": null}, "id_usuario_rol": {"nuevo": 8, "anterior": null}, "fecha_asignacion": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}}	{activo,asignado_por,fecha_asignacion,fecha_fin,fecha_inicio,id_rol,id_usuario,id_usuario_rol}	1	postgres	postgres	psql	127.0.0.1	CARGA-DATOS-DEMO-BASE-001	3584	17476	2026-07-22 01:33:28.562517-04
25	seguridad	usuario_rol	INSERT	{"id_usuario_rol": 9}	\N	{"activo": true, "id_rol": 4, "fecha_fin": null, "id_usuario": 8, "asignado_por": 1, "fecha_inicio": "2026-07-22", "id_usuario_rol": 9, "fecha_asignacion": "2026-07-22T01:33:28.562517-04:00"}	{"activo": {"nuevo": true, "anterior": null}, "id_rol": {"nuevo": 4, "anterior": null}, "fecha_fin": {"nuevo": null, "anterior": null}, "id_usuario": {"nuevo": 8, "anterior": null}, "asignado_por": {"nuevo": 1, "anterior": null}, "fecha_inicio": {"nuevo": "2026-07-22", "anterior": null}, "id_usuario_rol": {"nuevo": 9, "anterior": null}, "fecha_asignacion": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}}	{activo,asignado_por,fecha_asignacion,fecha_fin,fecha_inicio,id_rol,id_usuario,id_usuario_rol}	1	postgres	postgres	psql	127.0.0.1	CARGA-DATOS-DEMO-BASE-001	3584	17476	2026-07-22 01:33:28.562517-04
26	seguridad	usuario_rol	INSERT	{"id_usuario_rol": 10}	\N	{"activo": true, "id_rol": 4, "fecha_fin": null, "id_usuario": 7, "asignado_por": 1, "fecha_inicio": "2026-07-22", "id_usuario_rol": 10, "fecha_asignacion": "2026-07-22T01:33:28.562517-04:00"}	{"activo": {"nuevo": true, "anterior": null}, "id_rol": {"nuevo": 4, "anterior": null}, "fecha_fin": {"nuevo": null, "anterior": null}, "id_usuario": {"nuevo": 7, "anterior": null}, "asignado_por": {"nuevo": 1, "anterior": null}, "fecha_inicio": {"nuevo": "2026-07-22", "anterior": null}, "id_usuario_rol": {"nuevo": 10, "anterior": null}, "fecha_asignacion": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}}	{activo,asignado_por,fecha_asignacion,fecha_fin,fecha_inicio,id_rol,id_usuario,id_usuario_rol}	1	postgres	postgres	psql	127.0.0.1	CARGA-DATOS-DEMO-BASE-001	3584	17476	2026-07-22 01:33:28.562517-04
27	seguridad	usuario_rol	INSERT	{"id_usuario_rol": 11}	\N	{"activo": true, "id_rol": 4, "fecha_fin": null, "id_usuario": 6, "asignado_por": 1, "fecha_inicio": "2026-07-22", "id_usuario_rol": 11, "fecha_asignacion": "2026-07-22T01:33:28.562517-04:00"}	{"activo": {"nuevo": true, "anterior": null}, "id_rol": {"nuevo": 4, "anterior": null}, "fecha_fin": {"nuevo": null, "anterior": null}, "id_usuario": {"nuevo": 6, "anterior": null}, "asignado_por": {"nuevo": 1, "anterior": null}, "fecha_inicio": {"nuevo": "2026-07-22", "anterior": null}, "id_usuario_rol": {"nuevo": 11, "anterior": null}, "fecha_asignacion": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}}	{activo,asignado_por,fecha_asignacion,fecha_fin,fecha_inicio,id_rol,id_usuario,id_usuario_rol}	1	postgres	postgres	psql	127.0.0.1	CARGA-DATOS-DEMO-BASE-001	3584	17476	2026-07-22 01:33:28.562517-04
28	seguridad	usuario_rol	INSERT	{"id_usuario_rol": 12}	\N	{"activo": true, "id_rol": 4, "fecha_fin": null, "id_usuario": 5, "asignado_por": 1, "fecha_inicio": "2026-07-22", "id_usuario_rol": 12, "fecha_asignacion": "2026-07-22T01:33:28.562517-04:00"}	{"activo": {"nuevo": true, "anterior": null}, "id_rol": {"nuevo": 4, "anterior": null}, "fecha_fin": {"nuevo": null, "anterior": null}, "id_usuario": {"nuevo": 5, "anterior": null}, "asignado_por": {"nuevo": 1, "anterior": null}, "fecha_inicio": {"nuevo": "2026-07-22", "anterior": null}, "id_usuario_rol": {"nuevo": 12, "anterior": null}, "fecha_asignacion": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}}	{activo,asignado_por,fecha_asignacion,fecha_fin,fecha_inicio,id_rol,id_usuario,id_usuario_rol}	1	postgres	postgres	psql	127.0.0.1	CARGA-DATOS-DEMO-BASE-001	3584	17476	2026-07-22 01:33:28.562517-04
29	seguridad	usuario_rol	INSERT	{"id_usuario_rol": 13}	\N	{"activo": true, "id_rol": 4, "fecha_fin": null, "id_usuario": 4, "asignado_por": 1, "fecha_inicio": "2026-07-22", "id_usuario_rol": 13, "fecha_asignacion": "2026-07-22T01:33:28.562517-04:00"}	{"activo": {"nuevo": true, "anterior": null}, "id_rol": {"nuevo": 4, "anterior": null}, "fecha_fin": {"nuevo": null, "anterior": null}, "id_usuario": {"nuevo": 4, "anterior": null}, "asignado_por": {"nuevo": 1, "anterior": null}, "fecha_inicio": {"nuevo": "2026-07-22", "anterior": null}, "id_usuario_rol": {"nuevo": 13, "anterior": null}, "fecha_asignacion": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}}	{activo,asignado_por,fecha_asignacion,fecha_fin,fecha_inicio,id_rol,id_usuario,id_usuario_rol}	1	postgres	postgres	psql	127.0.0.1	CARGA-DATOS-DEMO-BASE-001	3584	17476	2026-07-22 01:33:28.562517-04
30	participantes	organizador	INSERT	{"id_usuario": 2}	\N	{"cargo": "Coordinador deportivo", "id_usuario": 2, "institucion": "Universidad Demo", "observaciones": "Organizador utilizado para las pruebas", "fecha_registro": "2026-07-22T01:33:28.562517-04:00", "id_estado_perfil": 1, "anios_experiencia": 5}	{"cargo": {"nuevo": "Coordinador deportivo", "anterior": null}, "id_usuario": {"nuevo": 2, "anterior": null}, "institucion": {"nuevo": "Universidad Demo", "anterior": null}, "observaciones": {"nuevo": "Organizador utilizado para las pruebas", "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}, "id_estado_perfil": {"nuevo": 1, "anterior": null}, "anios_experiencia": {"nuevo": 5, "anterior": null}}	{anios_experiencia,cargo,fecha_registro,id_estado_perfil,id_usuario,institucion,observaciones}	1	postgres	postgres	psql	127.0.0.1	CARGA-DATOS-DEMO-BASE-001	3584	17476	2026-07-22 01:33:28.562517-04
31	participantes	arbitro	INSERT	{"id_usuario": 3}	\N	{"nivel": "Departamental", "id_usuario": 3, "observaciones": "Arbitro utilizado para las pruebas", "fecha_registro": "2026-07-22T01:33:28.562517-04:00", "numero_licencia": "ARB-DEMO-001", "id_estado_perfil": 1, "anios_experiencia": 6}	{"nivel": {"nuevo": "Departamental", "anterior": null}, "id_usuario": {"nuevo": 3, "anterior": null}, "observaciones": {"nuevo": "Arbitro utilizado para las pruebas", "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}, "numero_licencia": {"nuevo": "ARB-DEMO-001", "anterior": null}, "id_estado_perfil": {"nuevo": 1, "anterior": null}, "anios_experiencia": {"nuevo": 6, "anterior": null}}	{anios_experiencia,fecha_registro,id_estado_perfil,id_usuario,nivel,numero_licencia,observaciones}	1	postgres	postgres	psql	127.0.0.1	CARGA-DATOS-DEMO-BASE-001	3584	17476	2026-07-22 01:33:28.562517-04
32	participantes	jugador	INSERT	{"id_usuario": 4}	\N	{"id_usuario": 4, "observaciones": "Jugador utilizado para las pruebas", "fecha_registro": "2026-07-22T01:33:28.562517-04:00", "alias_deportivo": "Jugador 7100001", "id_estado_perfil": 1}	{"id_usuario": {"nuevo": 4, "anterior": null}, "observaciones": {"nuevo": "Jugador utilizado para las pruebas", "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}, "alias_deportivo": {"nuevo": "Jugador 7100001", "anterior": null}, "id_estado_perfil": {"nuevo": 1, "anterior": null}}	{alias_deportivo,fecha_registro,id_estado_perfil,id_usuario,observaciones}	1	postgres	postgres	psql	127.0.0.1	CARGA-DATOS-DEMO-BASE-001	3584	17476	2026-07-22 01:33:28.562517-04
33	participantes	jugador	INSERT	{"id_usuario": 5}	\N	{"id_usuario": 5, "observaciones": "Jugador utilizado para las pruebas", "fecha_registro": "2026-07-22T01:33:28.562517-04:00", "alias_deportivo": "Jugador 7100002", "id_estado_perfil": 1}	{"id_usuario": {"nuevo": 5, "anterior": null}, "observaciones": {"nuevo": "Jugador utilizado para las pruebas", "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}, "alias_deportivo": {"nuevo": "Jugador 7100002", "anterior": null}, "id_estado_perfil": {"nuevo": 1, "anterior": null}}	{alias_deportivo,fecha_registro,id_estado_perfil,id_usuario,observaciones}	1	postgres	postgres	psql	127.0.0.1	CARGA-DATOS-DEMO-BASE-001	3584	17476	2026-07-22 01:33:28.562517-04
34	participantes	jugador	INSERT	{"id_usuario": 6}	\N	{"id_usuario": 6, "observaciones": "Jugador utilizado para las pruebas", "fecha_registro": "2026-07-22T01:33:28.562517-04:00", "alias_deportivo": "Jugador 7100003", "id_estado_perfil": 1}	{"id_usuario": {"nuevo": 6, "anterior": null}, "observaciones": {"nuevo": "Jugador utilizado para las pruebas", "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}, "alias_deportivo": {"nuevo": "Jugador 7100003", "anterior": null}, "id_estado_perfil": {"nuevo": 1, "anterior": null}}	{alias_deportivo,fecha_registro,id_estado_perfil,id_usuario,observaciones}	1	postgres	postgres	psql	127.0.0.1	CARGA-DATOS-DEMO-BASE-001	3584	17476	2026-07-22 01:33:28.562517-04
35	participantes	jugador	INSERT	{"id_usuario": 7}	\N	{"id_usuario": 7, "observaciones": "Jugador utilizado para las pruebas", "fecha_registro": "2026-07-22T01:33:28.562517-04:00", "alias_deportivo": "Jugador 7100004", "id_estado_perfil": 1}	{"id_usuario": {"nuevo": 7, "anterior": null}, "observaciones": {"nuevo": "Jugador utilizado para las pruebas", "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}, "alias_deportivo": {"nuevo": "Jugador 7100004", "anterior": null}, "id_estado_perfil": {"nuevo": 1, "anterior": null}}	{alias_deportivo,fecha_registro,id_estado_perfil,id_usuario,observaciones}	1	postgres	postgres	psql	127.0.0.1	CARGA-DATOS-DEMO-BASE-001	3584	17476	2026-07-22 01:33:28.562517-04
36	participantes	jugador	INSERT	{"id_usuario": 8}	\N	{"id_usuario": 8, "observaciones": "Jugador utilizado para las pruebas", "fecha_registro": "2026-07-22T01:33:28.562517-04:00", "alias_deportivo": "Jugador 7100005", "id_estado_perfil": 1}	{"id_usuario": {"nuevo": 8, "anterior": null}, "observaciones": {"nuevo": "Jugador utilizado para las pruebas", "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}, "alias_deportivo": {"nuevo": "Jugador 7100005", "anterior": null}, "id_estado_perfil": {"nuevo": 1, "anterior": null}}	{alias_deportivo,fecha_registro,id_estado_perfil,id_usuario,observaciones}	1	postgres	postgres	psql	127.0.0.1	CARGA-DATOS-DEMO-BASE-001	3584	17476	2026-07-22 01:33:28.562517-04
37	participantes	jugador	INSERT	{"id_usuario": 9}	\N	{"id_usuario": 9, "observaciones": "Jugador utilizado para las pruebas", "fecha_registro": "2026-07-22T01:33:28.562517-04:00", "alias_deportivo": "Jugador 7200001", "id_estado_perfil": 1}	{"id_usuario": {"nuevo": 9, "anterior": null}, "observaciones": {"nuevo": "Jugador utilizado para las pruebas", "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}, "alias_deportivo": {"nuevo": "Jugador 7200001", "anterior": null}, "id_estado_perfil": {"nuevo": 1, "anterior": null}}	{alias_deportivo,fecha_registro,id_estado_perfil,id_usuario,observaciones}	1	postgres	postgres	psql	127.0.0.1	CARGA-DATOS-DEMO-BASE-001	3584	17476	2026-07-22 01:33:28.562517-04
38	participantes	jugador	INSERT	{"id_usuario": 10}	\N	{"id_usuario": 10, "observaciones": "Jugador utilizado para las pruebas", "fecha_registro": "2026-07-22T01:33:28.562517-04:00", "alias_deportivo": "Jugador 7200002", "id_estado_perfil": 1}	{"id_usuario": {"nuevo": 10, "anterior": null}, "observaciones": {"nuevo": "Jugador utilizado para las pruebas", "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}, "alias_deportivo": {"nuevo": "Jugador 7200002", "anterior": null}, "id_estado_perfil": {"nuevo": 1, "anterior": null}}	{alias_deportivo,fecha_registro,id_estado_perfil,id_usuario,observaciones}	1	postgres	postgres	psql	127.0.0.1	CARGA-DATOS-DEMO-BASE-001	3584	17476	2026-07-22 01:33:28.562517-04
39	participantes	jugador	INSERT	{"id_usuario": 11}	\N	{"id_usuario": 11, "observaciones": "Jugador utilizado para las pruebas", "fecha_registro": "2026-07-22T01:33:28.562517-04:00", "alias_deportivo": "Jugador 7200003", "id_estado_perfil": 1}	{"id_usuario": {"nuevo": 11, "anterior": null}, "observaciones": {"nuevo": "Jugador utilizado para las pruebas", "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}, "alias_deportivo": {"nuevo": "Jugador 7200003", "anterior": null}, "id_estado_perfil": {"nuevo": 1, "anterior": null}}	{alias_deportivo,fecha_registro,id_estado_perfil,id_usuario,observaciones}	1	postgres	postgres	psql	127.0.0.1	CARGA-DATOS-DEMO-BASE-001	3584	17476	2026-07-22 01:33:28.562517-04
40	participantes	jugador	INSERT	{"id_usuario": 12}	\N	{"id_usuario": 12, "observaciones": "Jugador utilizado para las pruebas", "fecha_registro": "2026-07-22T01:33:28.562517-04:00", "alias_deportivo": "Jugador 7200004", "id_estado_perfil": 1}	{"id_usuario": {"nuevo": 12, "anterior": null}, "observaciones": {"nuevo": "Jugador utilizado para las pruebas", "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}, "alias_deportivo": {"nuevo": "Jugador 7200004", "anterior": null}, "id_estado_perfil": {"nuevo": 1, "anterior": null}}	{alias_deportivo,fecha_registro,id_estado_perfil,id_usuario,observaciones}	1	postgres	postgres	psql	127.0.0.1	CARGA-DATOS-DEMO-BASE-001	3584	17476	2026-07-22 01:33:28.562517-04
41	participantes	jugador	INSERT	{"id_usuario": 13}	\N	{"id_usuario": 13, "observaciones": "Jugador utilizado para las pruebas", "fecha_registro": "2026-07-22T01:33:28.562517-04:00", "alias_deportivo": "Jugador 7200005", "id_estado_perfil": 1}	{"id_usuario": {"nuevo": 13, "anterior": null}, "observaciones": {"nuevo": "Jugador utilizado para las pruebas", "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}, "alias_deportivo": {"nuevo": "Jugador 7200005", "anterior": null}, "id_estado_perfil": {"nuevo": 1, "anterior": null}}	{alias_deportivo,fecha_registro,id_estado_perfil,id_usuario,observaciones}	1	postgres	postgres	psql	127.0.0.1	CARGA-DATOS-DEMO-BASE-001	3584	17476	2026-07-22 01:33:28.562517-04
42	participantes	equipo	INSERT	{"id_equipo": 1}	\N	{"sigla": "TIT", "nombre": "Titanes Futsal", "logo_url": null, "id_equipo": 1, "creado_por": 1, "descripcion": "Equipo de prueba Titanes", "fecha_registro": "2026-07-22T01:33:28.562517-04:00", "fecha_fundacion": "2020-01-10", "id_estado_equipo": 1, "fecha_actualizacion": "2026-07-22T01:33:28.562517-04:00"}	{"sigla": {"nuevo": "TIT", "anterior": null}, "nombre": {"nuevo": "Titanes Futsal", "anterior": null}, "logo_url": {"nuevo": null, "anterior": null}, "id_equipo": {"nuevo": 1, "anterior": null}, "creado_por": {"nuevo": 1, "anterior": null}, "descripcion": {"nuevo": "Equipo de prueba Titanes", "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}, "fecha_fundacion": {"nuevo": "2020-01-10", "anterior": null}, "id_estado_equipo": {"nuevo": 1, "anterior": null}, "fecha_actualizacion": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}}	{creado_por,descripcion,fecha_actualizacion,fecha_fundacion,fecha_registro,id_equipo,id_estado_equipo,logo_url,nombre,sigla}	1	postgres	postgres	psql	127.0.0.1	CARGA-DATOS-DEMO-BASE-001	3584	17476	2026-07-22 01:33:28.562517-04
43	participantes	equipo	INSERT	{"id_equipo": 2}	\N	{"sigla": "HAL", "nombre": "Halcones Futsal", "logo_url": null, "id_equipo": 2, "creado_por": 1, "descripcion": "Equipo de prueba Halcones", "fecha_registro": "2026-07-22T01:33:28.562517-04:00", "fecha_fundacion": "2021-02-15", "id_estado_equipo": 1, "fecha_actualizacion": "2026-07-22T01:33:28.562517-04:00"}	{"sigla": {"nuevo": "HAL", "anterior": null}, "nombre": {"nuevo": "Halcones Futsal", "anterior": null}, "logo_url": {"nuevo": null, "anterior": null}, "id_equipo": {"nuevo": 2, "anterior": null}, "creado_por": {"nuevo": 1, "anterior": null}, "descripcion": {"nuevo": "Equipo de prueba Halcones", "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}, "fecha_fundacion": {"nuevo": "2021-02-15", "anterior": null}, "id_estado_equipo": {"nuevo": 1, "anterior": null}, "fecha_actualizacion": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}}	{creado_por,descripcion,fecha_actualizacion,fecha_fundacion,fecha_registro,id_equipo,id_estado_equipo,logo_url,nombre,sigla}	1	postgres	postgres	psql	127.0.0.1	CARGA-DATOS-DEMO-BASE-001	3584	17476	2026-07-22 01:33:28.562517-04
44	participantes	jugador_equipo	INSERT	{"id_jugador_equipo": 1}	\N	{"posicion": "Ala", "fecha_fin": null, "id_equipo": 1, "id_jugador": 8, "es_delegado": false, "fecha_inicio": "2026-01-01", "observaciones": "Membresia inicial de prueba", "fecha_registro": "2026-07-22T01:33:28.562517-04:00", "registrado_por": 1, "numero_camiseta": 10, "id_jugador_equipo": 1, "id_estado_membresia": 1}	{"posicion": {"nuevo": "Ala", "anterior": null}, "fecha_fin": {"nuevo": null, "anterior": null}, "id_equipo": {"nuevo": 1, "anterior": null}, "id_jugador": {"nuevo": 8, "anterior": null}, "es_delegado": {"nuevo": false, "anterior": null}, "fecha_inicio": {"nuevo": "2026-01-01", "anterior": null}, "observaciones": {"nuevo": "Membresia inicial de prueba", "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}, "registrado_por": {"nuevo": 1, "anterior": null}, "numero_camiseta": {"nuevo": 10, "anterior": null}, "id_jugador_equipo": {"nuevo": 1, "anterior": null}, "id_estado_membresia": {"nuevo": 1, "anterior": null}}	{es_delegado,fecha_fin,fecha_inicio,fecha_registro,id_equipo,id_estado_membresia,id_jugador,id_jugador_equipo,numero_camiseta,observaciones,posicion,registrado_por}	1	postgres	postgres	psql	127.0.0.1	CARGA-DATOS-DEMO-BASE-001	3584	17476	2026-07-22 01:33:28.562517-04
45	participantes	jugador_equipo	INSERT	{"id_jugador_equipo": 2}	\N	{"posicion": "Pivot", "fecha_fin": null, "id_equipo": 1, "id_jugador": 7, "es_delegado": false, "fecha_inicio": "2026-01-01", "observaciones": "Membresia inicial de prueba", "fecha_registro": "2026-07-22T01:33:28.562517-04:00", "registrado_por": 1, "numero_camiseta": 9, "id_jugador_equipo": 2, "id_estado_membresia": 1}	{"posicion": {"nuevo": "Pivot", "anterior": null}, "fecha_fin": {"nuevo": null, "anterior": null}, "id_equipo": {"nuevo": 1, "anterior": null}, "id_jugador": {"nuevo": 7, "anterior": null}, "es_delegado": {"nuevo": false, "anterior": null}, "fecha_inicio": {"nuevo": "2026-01-01", "anterior": null}, "observaciones": {"nuevo": "Membresia inicial de prueba", "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}, "registrado_por": {"nuevo": 1, "anterior": null}, "numero_camiseta": {"nuevo": 9, "anterior": null}, "id_jugador_equipo": {"nuevo": 2, "anterior": null}, "id_estado_membresia": {"nuevo": 1, "anterior": null}}	{es_delegado,fecha_fin,fecha_inicio,fecha_registro,id_equipo,id_estado_membresia,id_jugador,id_jugador_equipo,numero_camiseta,observaciones,posicion,registrado_por}	1	postgres	postgres	psql	127.0.0.1	CARGA-DATOS-DEMO-BASE-001	3584	17476	2026-07-22 01:33:28.562517-04
46	participantes	jugador_equipo	INSERT	{"id_jugador_equipo": 3}	\N	{"posicion": "Ala", "fecha_fin": null, "id_equipo": 1, "id_jugador": 6, "es_delegado": false, "fecha_inicio": "2026-01-01", "observaciones": "Membresia inicial de prueba", "fecha_registro": "2026-07-22T01:33:28.562517-04:00", "registrado_por": 1, "numero_camiseta": 7, "id_jugador_equipo": 3, "id_estado_membresia": 1}	{"posicion": {"nuevo": "Ala", "anterior": null}, "fecha_fin": {"nuevo": null, "anterior": null}, "id_equipo": {"nuevo": 1, "anterior": null}, "id_jugador": {"nuevo": 6, "anterior": null}, "es_delegado": {"nuevo": false, "anterior": null}, "fecha_inicio": {"nuevo": "2026-01-01", "anterior": null}, "observaciones": {"nuevo": "Membresia inicial de prueba", "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}, "registrado_por": {"nuevo": 1, "anterior": null}, "numero_camiseta": {"nuevo": 7, "anterior": null}, "id_jugador_equipo": {"nuevo": 3, "anterior": null}, "id_estado_membresia": {"nuevo": 1, "anterior": null}}	{es_delegado,fecha_fin,fecha_inicio,fecha_registro,id_equipo,id_estado_membresia,id_jugador,id_jugador_equipo,numero_camiseta,observaciones,posicion,registrado_por}	1	postgres	postgres	psql	127.0.0.1	CARGA-DATOS-DEMO-BASE-001	3584	17476	2026-07-22 01:33:28.562517-04
47	participantes	jugador_equipo	INSERT	{"id_jugador_equipo": 4}	\N	{"posicion": "Cierre", "fecha_fin": null, "id_equipo": 1, "id_jugador": 5, "es_delegado": false, "fecha_inicio": "2026-01-01", "observaciones": "Membresia inicial de prueba", "fecha_registro": "2026-07-22T01:33:28.562517-04:00", "registrado_por": 1, "numero_camiseta": 4, "id_jugador_equipo": 4, "id_estado_membresia": 1}	{"posicion": {"nuevo": "Cierre", "anterior": null}, "fecha_fin": {"nuevo": null, "anterior": null}, "id_equipo": {"nuevo": 1, "anterior": null}, "id_jugador": {"nuevo": 5, "anterior": null}, "es_delegado": {"nuevo": false, "anterior": null}, "fecha_inicio": {"nuevo": "2026-01-01", "anterior": null}, "observaciones": {"nuevo": "Membresia inicial de prueba", "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}, "registrado_por": {"nuevo": 1, "anterior": null}, "numero_camiseta": {"nuevo": 4, "anterior": null}, "id_jugador_equipo": {"nuevo": 4, "anterior": null}, "id_estado_membresia": {"nuevo": 1, "anterior": null}}	{es_delegado,fecha_fin,fecha_inicio,fecha_registro,id_equipo,id_estado_membresia,id_jugador,id_jugador_equipo,numero_camiseta,observaciones,posicion,registrado_por}	1	postgres	postgres	psql	127.0.0.1	CARGA-DATOS-DEMO-BASE-001	3584	17476	2026-07-22 01:33:28.562517-04
48	participantes	jugador_equipo	INSERT	{"id_jugador_equipo": 5}	\N	{"posicion": "Arquero", "fecha_fin": null, "id_equipo": 1, "id_jugador": 4, "es_delegado": true, "fecha_inicio": "2026-01-01", "observaciones": "Membresia inicial de prueba", "fecha_registro": "2026-07-22T01:33:28.562517-04:00", "registrado_por": 1, "numero_camiseta": 1, "id_jugador_equipo": 5, "id_estado_membresia": 1}	{"posicion": {"nuevo": "Arquero", "anterior": null}, "fecha_fin": {"nuevo": null, "anterior": null}, "id_equipo": {"nuevo": 1, "anterior": null}, "id_jugador": {"nuevo": 4, "anterior": null}, "es_delegado": {"nuevo": true, "anterior": null}, "fecha_inicio": {"nuevo": "2026-01-01", "anterior": null}, "observaciones": {"nuevo": "Membresia inicial de prueba", "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}, "registrado_por": {"nuevo": 1, "anterior": null}, "numero_camiseta": {"nuevo": 1, "anterior": null}, "id_jugador_equipo": {"nuevo": 5, "anterior": null}, "id_estado_membresia": {"nuevo": 1, "anterior": null}}	{es_delegado,fecha_fin,fecha_inicio,fecha_registro,id_equipo,id_estado_membresia,id_jugador,id_jugador_equipo,numero_camiseta,observaciones,posicion,registrado_por}	1	postgres	postgres	psql	127.0.0.1	CARGA-DATOS-DEMO-BASE-001	3584	17476	2026-07-22 01:33:28.562517-04
49	participantes	jugador_equipo	INSERT	{"id_jugador_equipo": 6}	\N	{"posicion": "Ala", "fecha_fin": null, "id_equipo": 2, "id_jugador": 13, "es_delegado": false, "fecha_inicio": "2026-01-01", "observaciones": "Membresia inicial de prueba", "fecha_registro": "2026-07-22T01:33:28.562517-04:00", "registrado_por": 1, "numero_camiseta": 11, "id_jugador_equipo": 6, "id_estado_membresia": 1}	{"posicion": {"nuevo": "Ala", "anterior": null}, "fecha_fin": {"nuevo": null, "anterior": null}, "id_equipo": {"nuevo": 2, "anterior": null}, "id_jugador": {"nuevo": 13, "anterior": null}, "es_delegado": {"nuevo": false, "anterior": null}, "fecha_inicio": {"nuevo": "2026-01-01", "anterior": null}, "observaciones": {"nuevo": "Membresia inicial de prueba", "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}, "registrado_por": {"nuevo": 1, "anterior": null}, "numero_camiseta": {"nuevo": 11, "anterior": null}, "id_jugador_equipo": {"nuevo": 6, "anterior": null}, "id_estado_membresia": {"nuevo": 1, "anterior": null}}	{es_delegado,fecha_fin,fecha_inicio,fecha_registro,id_equipo,id_estado_membresia,id_jugador,id_jugador_equipo,numero_camiseta,observaciones,posicion,registrado_por}	1	postgres	postgres	psql	127.0.0.1	CARGA-DATOS-DEMO-BASE-001	3584	17476	2026-07-22 01:33:28.562517-04
50	participantes	jugador_equipo	INSERT	{"id_jugador_equipo": 7}	\N	{"posicion": "Pivot", "fecha_fin": null, "id_equipo": 2, "id_jugador": 12, "es_delegado": false, "fecha_inicio": "2026-01-01", "observaciones": "Membresia inicial de prueba", "fecha_registro": "2026-07-22T01:33:28.562517-04:00", "registrado_por": 1, "numero_camiseta": 8, "id_jugador_equipo": 7, "id_estado_membresia": 1}	{"posicion": {"nuevo": "Pivot", "anterior": null}, "fecha_fin": {"nuevo": null, "anterior": null}, "id_equipo": {"nuevo": 2, "anterior": null}, "id_jugador": {"nuevo": 12, "anterior": null}, "es_delegado": {"nuevo": false, "anterior": null}, "fecha_inicio": {"nuevo": "2026-01-01", "anterior": null}, "observaciones": {"nuevo": "Membresia inicial de prueba", "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}, "registrado_por": {"nuevo": 1, "anterior": null}, "numero_camiseta": {"nuevo": 8, "anterior": null}, "id_jugador_equipo": {"nuevo": 7, "anterior": null}, "id_estado_membresia": {"nuevo": 1, "anterior": null}}	{es_delegado,fecha_fin,fecha_inicio,fecha_registro,id_equipo,id_estado_membresia,id_jugador,id_jugador_equipo,numero_camiseta,observaciones,posicion,registrado_por}	1	postgres	postgres	psql	127.0.0.1	CARGA-DATOS-DEMO-BASE-001	3584	17476	2026-07-22 01:33:28.562517-04
51	participantes	jugador_equipo	INSERT	{"id_jugador_equipo": 8}	\N	{"posicion": "Ala", "fecha_fin": null, "id_equipo": 2, "id_jugador": 11, "es_delegado": false, "fecha_inicio": "2026-01-01", "observaciones": "Membresia inicial de prueba", "fecha_registro": "2026-07-22T01:33:28.562517-04:00", "registrado_por": 1, "numero_camiseta": 6, "id_jugador_equipo": 8, "id_estado_membresia": 1}	{"posicion": {"nuevo": "Ala", "anterior": null}, "fecha_fin": {"nuevo": null, "anterior": null}, "id_equipo": {"nuevo": 2, "anterior": null}, "id_jugador": {"nuevo": 11, "anterior": null}, "es_delegado": {"nuevo": false, "anterior": null}, "fecha_inicio": {"nuevo": "2026-01-01", "anterior": null}, "observaciones": {"nuevo": "Membresia inicial de prueba", "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}, "registrado_por": {"nuevo": 1, "anterior": null}, "numero_camiseta": {"nuevo": 6, "anterior": null}, "id_jugador_equipo": {"nuevo": 8, "anterior": null}, "id_estado_membresia": {"nuevo": 1, "anterior": null}}	{es_delegado,fecha_fin,fecha_inicio,fecha_registro,id_equipo,id_estado_membresia,id_jugador,id_jugador_equipo,numero_camiseta,observaciones,posicion,registrado_por}	1	postgres	postgres	psql	127.0.0.1	CARGA-DATOS-DEMO-BASE-001	3584	17476	2026-07-22 01:33:28.562517-04
52	participantes	jugador_equipo	INSERT	{"id_jugador_equipo": 9}	\N	{"posicion": "Cierre", "fecha_fin": null, "id_equipo": 2, "id_jugador": 10, "es_delegado": false, "fecha_inicio": "2026-01-01", "observaciones": "Membresia inicial de prueba", "fecha_registro": "2026-07-22T01:33:28.562517-04:00", "registrado_por": 1, "numero_camiseta": 3, "id_jugador_equipo": 9, "id_estado_membresia": 1}	{"posicion": {"nuevo": "Cierre", "anterior": null}, "fecha_fin": {"nuevo": null, "anterior": null}, "id_equipo": {"nuevo": 2, "anterior": null}, "id_jugador": {"nuevo": 10, "anterior": null}, "es_delegado": {"nuevo": false, "anterior": null}, "fecha_inicio": {"nuevo": "2026-01-01", "anterior": null}, "observaciones": {"nuevo": "Membresia inicial de prueba", "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}, "registrado_por": {"nuevo": 1, "anterior": null}, "numero_camiseta": {"nuevo": 3, "anterior": null}, "id_jugador_equipo": {"nuevo": 9, "anterior": null}, "id_estado_membresia": {"nuevo": 1, "anterior": null}}	{es_delegado,fecha_fin,fecha_inicio,fecha_registro,id_equipo,id_estado_membresia,id_jugador,id_jugador_equipo,numero_camiseta,observaciones,posicion,registrado_por}	1	postgres	postgres	psql	127.0.0.1	CARGA-DATOS-DEMO-BASE-001	3584	17476	2026-07-22 01:33:28.562517-04
53	participantes	jugador_equipo	INSERT	{"id_jugador_equipo": 10}	\N	{"posicion": "Arquero", "fecha_fin": null, "id_equipo": 2, "id_jugador": 9, "es_delegado": true, "fecha_inicio": "2026-01-01", "observaciones": "Membresia inicial de prueba", "fecha_registro": "2026-07-22T01:33:28.562517-04:00", "registrado_por": 1, "numero_camiseta": 1, "id_jugador_equipo": 10, "id_estado_membresia": 1}	{"posicion": {"nuevo": "Arquero", "anterior": null}, "fecha_fin": {"nuevo": null, "anterior": null}, "id_equipo": {"nuevo": 2, "anterior": null}, "id_jugador": {"nuevo": 9, "anterior": null}, "es_delegado": {"nuevo": true, "anterior": null}, "fecha_inicio": {"nuevo": "2026-01-01", "anterior": null}, "observaciones": {"nuevo": "Membresia inicial de prueba", "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}, "registrado_por": {"nuevo": 1, "anterior": null}, "numero_camiseta": {"nuevo": 1, "anterior": null}, "id_jugador_equipo": {"nuevo": 10, "anterior": null}, "id_estado_membresia": {"nuevo": 1, "anterior": null}}	{es_delegado,fecha_fin,fecha_inicio,fecha_registro,id_equipo,id_estado_membresia,id_jugador,id_jugador_equipo,numero_camiseta,observaciones,posicion,registrado_por}	1	postgres	postgres	psql	127.0.0.1	CARGA-DATOS-DEMO-BASE-001	3584	17476	2026-07-22 01:33:28.562517-04
54	competencia	lugar	INSERT	{"id_lugar": 1}	\N	{"zona": "Centro", "activo": true, "ciudad": "La Paz", "nombre": "Coliseo Demo Central", "id_lugar": 1, "capacidad": 800, "direccion": "Avenida Deportiva 500", "fecha_registro": "2026-07-22T01:33:28.562517-04:00", "tipo_superficie": "Parquet"}	{"zona": {"nuevo": "Centro", "anterior": null}, "activo": {"nuevo": true, "anterior": null}, "ciudad": {"nuevo": "La Paz", "anterior": null}, "nombre": {"nuevo": "Coliseo Demo Central", "anterior": null}, "id_lugar": {"nuevo": 1, "anterior": null}, "capacidad": {"nuevo": 800, "anterior": null}, "direccion": {"nuevo": "Avenida Deportiva 500", "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}, "tipo_superficie": {"nuevo": "Parquet", "anterior": null}}	{activo,capacidad,ciudad,direccion,fecha_registro,id_lugar,nombre,tipo_superficie,zona}	1	postgres	postgres	psql	127.0.0.1	CARGA-DATOS-DEMO-BASE-001	3584	17476	2026-07-22 01:33:28.562517-04
55	finanzas	premio	INSERT	{"id_premio": 1}	\N	{"activo": true, "codigo": "PREMIO_CAMPEON_DEMO", "nombre": "Premio economico al campeon demo", "id_premio": 1, "descripcion": "Premio de prueba para el equipo campeon", "fecha_registro": "2026-07-22T01:33:28.562517-04:00", "id_tipo_premio": 1}	{"activo": {"nuevo": true, "anterior": null}, "codigo": {"nuevo": "PREMIO_CAMPEON_DEMO", "anterior": null}, "nombre": {"nuevo": "Premio economico al campeon demo", "anterior": null}, "id_premio": {"nuevo": 1, "anterior": null}, "descripcion": {"nuevo": "Premio de prueba para el equipo campeon", "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:33:28.562517-04:00", "anterior": null}, "id_tipo_premio": {"nuevo": 1, "anterior": null}}	{activo,codigo,descripcion,fecha_registro,id_premio,id_tipo_premio,nombre}	1	postgres	postgres	psql	127.0.0.1	CARGA-DATOS-DEMO-BASE-001	3584	17476	2026-07-22 01:33:28.562517-04
64	competencia	usuario_torneo_rol	INSERT	{"id_usuario_torneo_rol": 2}	\N	{"activo": true, "fecha_fin": null, "id_torneo": 3, "id_usuario": 3, "asignado_por": 1, "id_rol_torneo": 2, "fecha_asignacion": "2026-07-22T01:40:15.937449-04:00", "id_usuario_torneo_rol": 2}	{"activo": {"nuevo": true, "anterior": null}, "fecha_fin": {"nuevo": null, "anterior": null}, "id_torneo": {"nuevo": 3, "anterior": null}, "id_usuario": {"nuevo": 3, "anterior": null}, "asignado_por": {"nuevo": 1, "anterior": null}, "id_rol_torneo": {"nuevo": 2, "anterior": null}, "fecha_asignacion": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "id_usuario_torneo_rol": {"nuevo": 2, "anterior": null}}	{activo,asignado_por,fecha_asignacion,fecha_fin,id_rol_torneo,id_torneo,id_usuario,id_usuario_torneo_rol}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
59	competencia	torneo	INSERT	{"id_torneo": 3}	\N	{"rama": "MASCULINO", "codigo": "FTS-DEMO-2026-01", "moneda": "BOB", "nombre": "Copa Demo de Futsal 2026", "edicion": "2026", "categoria": "Libre", "id_torneo": 3, "creado_por": 1, "id_deporte": 2, "descripcion": "Torneo de demostracion para probar el flujo completo", "fecha_registro": "2026-07-22T01:40:15.937449-04:00", "permite_empate": false, "fecha_fin_torneo": "2026-08-20", "id_estado_torneo": 1, "costo_inscripcion": 200.00, "id_formato_torneo": 1, "fecha_actualizacion": "2026-07-22T01:40:15.937449-04:00", "fecha_inicio_torneo": "2026-08-20", "fecha_fin_inscripcion": "2026-08-10", "cantidad_maxima_equipos": 2, "fecha_inicio_inscripcion": "2026-08-01", "cantidad_maxima_jugadores": 7, "cantidad_minima_jugadores": 5}	{"rama": {"nuevo": "MASCULINO", "anterior": null}, "codigo": {"nuevo": "FTS-DEMO-2026-01", "anterior": null}, "moneda": {"nuevo": "BOB", "anterior": null}, "nombre": {"nuevo": "Copa Demo de Futsal 2026", "anterior": null}, "edicion": {"nuevo": "2026", "anterior": null}, "categoria": {"nuevo": "Libre", "anterior": null}, "id_torneo": {"nuevo": 3, "anterior": null}, "creado_por": {"nuevo": 1, "anterior": null}, "id_deporte": {"nuevo": 2, "anterior": null}, "descripcion": {"nuevo": "Torneo de demostracion para probar el flujo completo", "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "permite_empate": {"nuevo": false, "anterior": null}, "fecha_fin_torneo": {"nuevo": "2026-08-20", "anterior": null}, "id_estado_torneo": {"nuevo": 1, "anterior": null}, "costo_inscripcion": {"nuevo": 200.00, "anterior": null}, "id_formato_torneo": {"nuevo": 1, "anterior": null}, "fecha_actualizacion": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "fecha_inicio_torneo": {"nuevo": "2026-08-20", "anterior": null}, "fecha_fin_inscripcion": {"nuevo": "2026-08-10", "anterior": null}, "cantidad_maxima_equipos": {"nuevo": 2, "anterior": null}, "fecha_inicio_inscripcion": {"nuevo": "2026-08-01", "anterior": null}, "cantidad_maxima_jugadores": {"nuevo": 7, "anterior": null}, "cantidad_minima_jugadores": {"nuevo": 5, "anterior": null}}	{cantidad_maxima_equipos,cantidad_maxima_jugadores,cantidad_minima_jugadores,categoria,codigo,costo_inscripcion,creado_por,descripcion,edicion,fecha_actualizacion,fecha_fin_inscripcion,fecha_fin_torneo,fecha_inicio_inscripcion,fecha_inicio_torneo,fecha_registro,id_deporte,id_estado_torneo,id_formato_torneo,id_torneo,moneda,nombre,permite_empate,rama}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
60	competencia	fase_torneo	INSERT	{"id_fase_torneo": 2}	\N	{"nombre": "Final unica", "fecha_fin": "2026-08-20", "id_torneo": 3, "descripcion": "Fase compuesta por un solo partido", "fecha_inicio": "2026-08-20", "id_tipo_fase": 1, "numero_orden": 1, "id_estado_fase": 1, "id_fase_torneo": 2, "cantidad_clasificados": 1}	{"nombre": {"nuevo": "Final unica", "anterior": null}, "fecha_fin": {"nuevo": "2026-08-20", "anterior": null}, "id_torneo": {"nuevo": 3, "anterior": null}, "descripcion": {"nuevo": "Fase compuesta por un solo partido", "anterior": null}, "fecha_inicio": {"nuevo": "2026-08-20", "anterior": null}, "id_tipo_fase": {"nuevo": 1, "anterior": null}, "numero_orden": {"nuevo": 1, "anterior": null}, "id_estado_fase": {"nuevo": 1, "anterior": null}, "id_fase_torneo": {"nuevo": 2, "anterior": null}, "cantidad_clasificados": {"nuevo": 1, "anterior": null}}	{cantidad_clasificados,descripcion,fecha_fin,fecha_inicio,id_estado_fase,id_fase_torneo,id_tipo_fase,id_torneo,nombre,numero_orden}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
61	competencia	jornada	INSERT	{"id_jornada": 2}	\N	{"nombre": "Jornada final", "fecha_fin": "2026-08-20T18:00:00-04:00", "id_jornada": 2, "fecha_inicio": "2026-08-20T14:00:00-04:00", "observaciones": "Jornada del partido unico", "id_fase_torneo": 2, "numero_jornada": 1, "id_estado_jornada": 1}	{"nombre": {"nuevo": "Jornada final", "anterior": null}, "fecha_fin": {"nuevo": "2026-08-20T18:00:00-04:00", "anterior": null}, "id_jornada": {"nuevo": 2, "anterior": null}, "fecha_inicio": {"nuevo": "2026-08-20T14:00:00-04:00", "anterior": null}, "observaciones": {"nuevo": "Jornada del partido unico", "anterior": null}, "id_fase_torneo": {"nuevo": 2, "anterior": null}, "numero_jornada": {"nuevo": 1, "anterior": null}, "id_estado_jornada": {"nuevo": 1, "anterior": null}}	{fecha_fin,fecha_inicio,id_estado_jornada,id_fase_torneo,id_jornada,nombre,numero_jornada,observaciones}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
62	finanzas	torneo_premio	INSERT	{"id_torneo_premio": 1}	\N	{"moneda": "BOB", "id_premio": 1, "id_torneo": 3, "fecha_registro": "2026-07-22T01:40:15.937449-04:00", "registrado_por": 1, "valor_economico": 1000.00, "id_torneo_premio": 1, "posicion_objetivo": 1, "descripcion_entrega": "Premio economico para el campeon"}	{"moneda": {"nuevo": "BOB", "anterior": null}, "id_premio": {"nuevo": 1, "anterior": null}, "id_torneo": {"nuevo": 3, "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "registrado_por": {"nuevo": 1, "anterior": null}, "valor_economico": {"nuevo": 1000.00, "anterior": null}, "id_torneo_premio": {"nuevo": 1, "anterior": null}, "posicion_objetivo": {"nuevo": 1, "anterior": null}, "descripcion_entrega": {"nuevo": "Premio economico para el campeon", "anterior": null}}	{descripcion_entrega,fecha_registro,id_premio,id_torneo,id_torneo_premio,moneda,posicion_objetivo,registrado_por,valor_economico}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
63	competencia	usuario_torneo_rol	INSERT	{"id_usuario_torneo_rol": 1}	\N	{"activo": true, "fecha_fin": null, "id_torneo": 3, "id_usuario": 2, "asignado_por": 1, "id_rol_torneo": 3, "fecha_asignacion": "2026-07-22T01:40:15.937449-04:00", "id_usuario_torneo_rol": 1}	{"activo": {"nuevo": true, "anterior": null}, "fecha_fin": {"nuevo": null, "anterior": null}, "id_torneo": {"nuevo": 3, "anterior": null}, "id_usuario": {"nuevo": 2, "anterior": null}, "asignado_por": {"nuevo": 1, "anterior": null}, "id_rol_torneo": {"nuevo": 3, "anterior": null}, "fecha_asignacion": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "id_usuario_torneo_rol": {"nuevo": 1, "anterior": null}}	{activo,asignado_por,fecha_asignacion,fecha_fin,id_rol_torneo,id_torneo,id_usuario,id_usuario_torneo_rol}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
65	competencia	usuario_torneo_rol	INSERT	{"id_usuario_torneo_rol": 3}	\N	{"activo": true, "fecha_fin": null, "id_torneo": 3, "id_usuario": 4, "asignado_por": 1, "id_rol_torneo": 1, "fecha_asignacion": "2026-07-22T01:40:15.937449-04:00", "id_usuario_torneo_rol": 3}	{"activo": {"nuevo": true, "anterior": null}, "fecha_fin": {"nuevo": null, "anterior": null}, "id_torneo": {"nuevo": 3, "anterior": null}, "id_usuario": {"nuevo": 4, "anterior": null}, "asignado_por": {"nuevo": 1, "anterior": null}, "id_rol_torneo": {"nuevo": 1, "anterior": null}, "fecha_asignacion": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "id_usuario_torneo_rol": {"nuevo": 3, "anterior": null}}	{activo,asignado_por,fecha_asignacion,fecha_fin,id_rol_torneo,id_torneo,id_usuario,id_usuario_torneo_rol}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
66	competencia	usuario_torneo_rol	INSERT	{"id_usuario_torneo_rol": 4}	\N	{"activo": true, "fecha_fin": null, "id_torneo": 3, "id_usuario": 5, "asignado_por": 1, "id_rol_torneo": 1, "fecha_asignacion": "2026-07-22T01:40:15.937449-04:00", "id_usuario_torneo_rol": 4}	{"activo": {"nuevo": true, "anterior": null}, "fecha_fin": {"nuevo": null, "anterior": null}, "id_torneo": {"nuevo": 3, "anterior": null}, "id_usuario": {"nuevo": 5, "anterior": null}, "asignado_por": {"nuevo": 1, "anterior": null}, "id_rol_torneo": {"nuevo": 1, "anterior": null}, "fecha_asignacion": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "id_usuario_torneo_rol": {"nuevo": 4, "anterior": null}}	{activo,asignado_por,fecha_asignacion,fecha_fin,id_rol_torneo,id_torneo,id_usuario,id_usuario_torneo_rol}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
67	competencia	usuario_torneo_rol	INSERT	{"id_usuario_torneo_rol": 5}	\N	{"activo": true, "fecha_fin": null, "id_torneo": 3, "id_usuario": 6, "asignado_por": 1, "id_rol_torneo": 1, "fecha_asignacion": "2026-07-22T01:40:15.937449-04:00", "id_usuario_torneo_rol": 5}	{"activo": {"nuevo": true, "anterior": null}, "fecha_fin": {"nuevo": null, "anterior": null}, "id_torneo": {"nuevo": 3, "anterior": null}, "id_usuario": {"nuevo": 6, "anterior": null}, "asignado_por": {"nuevo": 1, "anterior": null}, "id_rol_torneo": {"nuevo": 1, "anterior": null}, "fecha_asignacion": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "id_usuario_torneo_rol": {"nuevo": 5, "anterior": null}}	{activo,asignado_por,fecha_asignacion,fecha_fin,id_rol_torneo,id_torneo,id_usuario,id_usuario_torneo_rol}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
68	competencia	usuario_torneo_rol	INSERT	{"id_usuario_torneo_rol": 6}	\N	{"activo": true, "fecha_fin": null, "id_torneo": 3, "id_usuario": 7, "asignado_por": 1, "id_rol_torneo": 1, "fecha_asignacion": "2026-07-22T01:40:15.937449-04:00", "id_usuario_torneo_rol": 6}	{"activo": {"nuevo": true, "anterior": null}, "fecha_fin": {"nuevo": null, "anterior": null}, "id_torneo": {"nuevo": 3, "anterior": null}, "id_usuario": {"nuevo": 7, "anterior": null}, "asignado_por": {"nuevo": 1, "anterior": null}, "id_rol_torneo": {"nuevo": 1, "anterior": null}, "fecha_asignacion": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "id_usuario_torneo_rol": {"nuevo": 6, "anterior": null}}	{activo,asignado_por,fecha_asignacion,fecha_fin,id_rol_torneo,id_torneo,id_usuario,id_usuario_torneo_rol}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
69	competencia	usuario_torneo_rol	INSERT	{"id_usuario_torneo_rol": 7}	\N	{"activo": true, "fecha_fin": null, "id_torneo": 3, "id_usuario": 8, "asignado_por": 1, "id_rol_torneo": 1, "fecha_asignacion": "2026-07-22T01:40:15.937449-04:00", "id_usuario_torneo_rol": 7}	{"activo": {"nuevo": true, "anterior": null}, "fecha_fin": {"nuevo": null, "anterior": null}, "id_torneo": {"nuevo": 3, "anterior": null}, "id_usuario": {"nuevo": 8, "anterior": null}, "asignado_por": {"nuevo": 1, "anterior": null}, "id_rol_torneo": {"nuevo": 1, "anterior": null}, "fecha_asignacion": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "id_usuario_torneo_rol": {"nuevo": 7, "anterior": null}}	{activo,asignado_por,fecha_asignacion,fecha_fin,id_rol_torneo,id_torneo,id_usuario,id_usuario_torneo_rol}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
70	competencia	usuario_torneo_rol	INSERT	{"id_usuario_torneo_rol": 8}	\N	{"activo": true, "fecha_fin": null, "id_torneo": 3, "id_usuario": 9, "asignado_por": 1, "id_rol_torneo": 1, "fecha_asignacion": "2026-07-22T01:40:15.937449-04:00", "id_usuario_torneo_rol": 8}	{"activo": {"nuevo": true, "anterior": null}, "fecha_fin": {"nuevo": null, "anterior": null}, "id_torneo": {"nuevo": 3, "anterior": null}, "id_usuario": {"nuevo": 9, "anterior": null}, "asignado_por": {"nuevo": 1, "anterior": null}, "id_rol_torneo": {"nuevo": 1, "anterior": null}, "fecha_asignacion": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "id_usuario_torneo_rol": {"nuevo": 8, "anterior": null}}	{activo,asignado_por,fecha_asignacion,fecha_fin,id_rol_torneo,id_torneo,id_usuario,id_usuario_torneo_rol}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
71	competencia	usuario_torneo_rol	INSERT	{"id_usuario_torneo_rol": 9}	\N	{"activo": true, "fecha_fin": null, "id_torneo": 3, "id_usuario": 10, "asignado_por": 1, "id_rol_torneo": 1, "fecha_asignacion": "2026-07-22T01:40:15.937449-04:00", "id_usuario_torneo_rol": 9}	{"activo": {"nuevo": true, "anterior": null}, "fecha_fin": {"nuevo": null, "anterior": null}, "id_torneo": {"nuevo": 3, "anterior": null}, "id_usuario": {"nuevo": 10, "anterior": null}, "asignado_por": {"nuevo": 1, "anterior": null}, "id_rol_torneo": {"nuevo": 1, "anterior": null}, "fecha_asignacion": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "id_usuario_torneo_rol": {"nuevo": 9, "anterior": null}}	{activo,asignado_por,fecha_asignacion,fecha_fin,id_rol_torneo,id_torneo,id_usuario,id_usuario_torneo_rol}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
72	competencia	usuario_torneo_rol	INSERT	{"id_usuario_torneo_rol": 10}	\N	{"activo": true, "fecha_fin": null, "id_torneo": 3, "id_usuario": 11, "asignado_por": 1, "id_rol_torneo": 1, "fecha_asignacion": "2026-07-22T01:40:15.937449-04:00", "id_usuario_torneo_rol": 10}	{"activo": {"nuevo": true, "anterior": null}, "fecha_fin": {"nuevo": null, "anterior": null}, "id_torneo": {"nuevo": 3, "anterior": null}, "id_usuario": {"nuevo": 11, "anterior": null}, "asignado_por": {"nuevo": 1, "anterior": null}, "id_rol_torneo": {"nuevo": 1, "anterior": null}, "fecha_asignacion": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "id_usuario_torneo_rol": {"nuevo": 10, "anterior": null}}	{activo,asignado_por,fecha_asignacion,fecha_fin,id_rol_torneo,id_torneo,id_usuario,id_usuario_torneo_rol}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
73	competencia	usuario_torneo_rol	INSERT	{"id_usuario_torneo_rol": 11}	\N	{"activo": true, "fecha_fin": null, "id_torneo": 3, "id_usuario": 12, "asignado_por": 1, "id_rol_torneo": 1, "fecha_asignacion": "2026-07-22T01:40:15.937449-04:00", "id_usuario_torneo_rol": 11}	{"activo": {"nuevo": true, "anterior": null}, "fecha_fin": {"nuevo": null, "anterior": null}, "id_torneo": {"nuevo": 3, "anterior": null}, "id_usuario": {"nuevo": 12, "anterior": null}, "asignado_por": {"nuevo": 1, "anterior": null}, "id_rol_torneo": {"nuevo": 1, "anterior": null}, "fecha_asignacion": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "id_usuario_torneo_rol": {"nuevo": 11, "anterior": null}}	{activo,asignado_por,fecha_asignacion,fecha_fin,id_rol_torneo,id_torneo,id_usuario,id_usuario_torneo_rol}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
74	competencia	usuario_torneo_rol	INSERT	{"id_usuario_torneo_rol": 12}	\N	{"activo": true, "fecha_fin": null, "id_torneo": 3, "id_usuario": 13, "asignado_por": 1, "id_rol_torneo": 1, "fecha_asignacion": "2026-07-22T01:40:15.937449-04:00", "id_usuario_torneo_rol": 12}	{"activo": {"nuevo": true, "anterior": null}, "fecha_fin": {"nuevo": null, "anterior": null}, "id_torneo": {"nuevo": 3, "anterior": null}, "id_usuario": {"nuevo": 13, "anterior": null}, "asignado_por": {"nuevo": 1, "anterior": null}, "id_rol_torneo": {"nuevo": 1, "anterior": null}, "fecha_asignacion": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "id_usuario_torneo_rol": {"nuevo": 12, "anterior": null}}	{activo,asignado_por,fecha_asignacion,fecha_fin,id_rol_torneo,id_torneo,id_usuario,id_usuario_torneo_rol}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
75	competencia	torneo	UPDATE	{"id_torneo": 3}	{"rama": "MASCULINO", "codigo": "FTS-DEMO-2026-01", "moneda": "BOB", "nombre": "Copa Demo de Futsal 2026", "edicion": "2026", "categoria": "Libre", "id_torneo": 3, "creado_por": 1, "id_deporte": 2, "descripcion": "Torneo de demostracion para probar el flujo completo", "fecha_registro": "2026-07-22T01:40:15.937449-04:00", "permite_empate": false, "fecha_fin_torneo": "2026-08-20", "id_estado_torneo": 1, "costo_inscripcion": 200.00, "id_formato_torneo": 1, "fecha_actualizacion": "2026-07-22T01:40:15.937449-04:00", "fecha_inicio_torneo": "2026-08-20", "fecha_fin_inscripcion": "2026-08-10", "cantidad_maxima_equipos": 2, "fecha_inicio_inscripcion": "2026-08-01", "cantidad_maxima_jugadores": 7, "cantidad_minima_jugadores": 5}	{"rama": "MASCULINO", "codigo": "FTS-DEMO-2026-01", "moneda": "BOB", "nombre": "Copa Demo de Futsal 2026", "edicion": "2026", "categoria": "Libre", "id_torneo": 3, "creado_por": 1, "id_deporte": 2, "descripcion": "Torneo de demostracion para probar el flujo completo", "fecha_registro": "2026-07-22T01:40:15.937449-04:00", "permite_empate": false, "fecha_fin_torneo": "2026-08-20", "id_estado_torneo": 2, "costo_inscripcion": 200.00, "id_formato_torneo": 1, "fecha_actualizacion": "2026-07-22T01:40:15.937449-04:00", "fecha_inicio_torneo": "2026-08-20", "fecha_fin_inscripcion": "2026-08-10", "cantidad_maxima_equipos": 2, "fecha_inicio_inscripcion": "2026-08-01", "cantidad_maxima_jugadores": 7, "cantidad_minima_jugadores": 5}	{"id_estado_torneo": {"nuevo": 2, "anterior": 1}}	{id_estado_torneo}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
76	competencia	inscripcion	INSERT	{"id_inscripcion": 1}	\N	{"moneda": "BOB", "id_equipo": 1, "id_torneo": 3, "observaciones": "Inscripcion de Titanes Futsal", "id_inscripcion": 1, "registrado_por": 1, "monto_requerido": 200.00, "fecha_inscripcion": "2026-07-22T01:40:15.937449-04:00", "fecha_actualizacion": "2026-07-22T01:40:15.937449-04:00", "id_estado_inscripcion": 1}	{"moneda": {"nuevo": "BOB", "anterior": null}, "id_equipo": {"nuevo": 1, "anterior": null}, "id_torneo": {"nuevo": 3, "anterior": null}, "observaciones": {"nuevo": "Inscripcion de Titanes Futsal", "anterior": null}, "id_inscripcion": {"nuevo": 1, "anterior": null}, "registrado_por": {"nuevo": 1, "anterior": null}, "monto_requerido": {"nuevo": 200.00, "anterior": null}, "fecha_inscripcion": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "fecha_actualizacion": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "id_estado_inscripcion": {"nuevo": 1, "anterior": null}}	{fecha_actualizacion,fecha_inscripcion,id_equipo,id_estado_inscripcion,id_inscripcion,id_torneo,moneda,monto_requerido,observaciones,registrado_por}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
77	competencia	inscripcion	INSERT	{"id_inscripcion": 2}	\N	{"moneda": "BOB", "id_equipo": 2, "id_torneo": 3, "observaciones": "Inscripcion de Halcones Futsal", "id_inscripcion": 2, "registrado_por": 1, "monto_requerido": 200.00, "fecha_inscripcion": "2026-07-22T01:40:15.937449-04:00", "fecha_actualizacion": "2026-07-22T01:40:15.937449-04:00", "id_estado_inscripcion": 1}	{"moneda": {"nuevo": "BOB", "anterior": null}, "id_equipo": {"nuevo": 2, "anterior": null}, "id_torneo": {"nuevo": 3, "anterior": null}, "observaciones": {"nuevo": "Inscripcion de Halcones Futsal", "anterior": null}, "id_inscripcion": {"nuevo": 2, "anterior": null}, "registrado_por": {"nuevo": 1, "anterior": null}, "monto_requerido": {"nuevo": 200.00, "anterior": null}, "fecha_inscripcion": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "fecha_actualizacion": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "id_estado_inscripcion": {"nuevo": 1, "anterior": null}}	{fecha_actualizacion,fecha_inscripcion,id_equipo,id_estado_inscripcion,id_inscripcion,id_torneo,moneda,monto_requerido,observaciones,registrado_por}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
78	competencia	jugador_inscripcion	INSERT	{"id_jugador_inscripcion": 1}	\N	{"es_capitan": true, "fecha_baja": null, "id_jugador": 4, "es_delegado": true, "observaciones": "Jugador titular de Titanes", "fecha_registro": "2026-07-22T01:40:15.937449-04:00", "id_inscripcion": 1, "registrado_por": 1, "numero_camiseta": 1, "id_jugador_equipo": 5, "id_jugador_inscripcion": 1, "id_estado_jugador_inscripcion": 1}	{"es_capitan": {"nuevo": true, "anterior": null}, "fecha_baja": {"nuevo": null, "anterior": null}, "id_jugador": {"nuevo": 4, "anterior": null}, "es_delegado": {"nuevo": true, "anterior": null}, "observaciones": {"nuevo": "Jugador titular de Titanes", "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "id_inscripcion": {"nuevo": 1, "anterior": null}, "registrado_por": {"nuevo": 1, "anterior": null}, "numero_camiseta": {"nuevo": 1, "anterior": null}, "id_jugador_equipo": {"nuevo": 5, "anterior": null}, "id_jugador_inscripcion": {"nuevo": 1, "anterior": null}, "id_estado_jugador_inscripcion": {"nuevo": 1, "anterior": null}}	{es_capitan,es_delegado,fecha_baja,fecha_registro,id_estado_jugador_inscripcion,id_inscripcion,id_jugador,id_jugador_equipo,id_jugador_inscripcion,numero_camiseta,observaciones,registrado_por}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
79	competencia	jugador_inscripcion	INSERT	{"id_jugador_inscripcion": 2}	\N	{"es_capitan": false, "fecha_baja": null, "id_jugador": 5, "es_delegado": false, "observaciones": "Jugador titular de Titanes", "fecha_registro": "2026-07-22T01:40:15.937449-04:00", "id_inscripcion": 1, "registrado_por": 1, "numero_camiseta": 4, "id_jugador_equipo": 4, "id_jugador_inscripcion": 2, "id_estado_jugador_inscripcion": 1}	{"es_capitan": {"nuevo": false, "anterior": null}, "fecha_baja": {"nuevo": null, "anterior": null}, "id_jugador": {"nuevo": 5, "anterior": null}, "es_delegado": {"nuevo": false, "anterior": null}, "observaciones": {"nuevo": "Jugador titular de Titanes", "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "id_inscripcion": {"nuevo": 1, "anterior": null}, "registrado_por": {"nuevo": 1, "anterior": null}, "numero_camiseta": {"nuevo": 4, "anterior": null}, "id_jugador_equipo": {"nuevo": 4, "anterior": null}, "id_jugador_inscripcion": {"nuevo": 2, "anterior": null}, "id_estado_jugador_inscripcion": {"nuevo": 1, "anterior": null}}	{es_capitan,es_delegado,fecha_baja,fecha_registro,id_estado_jugador_inscripcion,id_inscripcion,id_jugador,id_jugador_equipo,id_jugador_inscripcion,numero_camiseta,observaciones,registrado_por}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
80	competencia	jugador_inscripcion	INSERT	{"id_jugador_inscripcion": 3}	\N	{"es_capitan": false, "fecha_baja": null, "id_jugador": 6, "es_delegado": false, "observaciones": "Jugador titular de Titanes", "fecha_registro": "2026-07-22T01:40:15.937449-04:00", "id_inscripcion": 1, "registrado_por": 1, "numero_camiseta": 7, "id_jugador_equipo": 3, "id_jugador_inscripcion": 3, "id_estado_jugador_inscripcion": 1}	{"es_capitan": {"nuevo": false, "anterior": null}, "fecha_baja": {"nuevo": null, "anterior": null}, "id_jugador": {"nuevo": 6, "anterior": null}, "es_delegado": {"nuevo": false, "anterior": null}, "observaciones": {"nuevo": "Jugador titular de Titanes", "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "id_inscripcion": {"nuevo": 1, "anterior": null}, "registrado_por": {"nuevo": 1, "anterior": null}, "numero_camiseta": {"nuevo": 7, "anterior": null}, "id_jugador_equipo": {"nuevo": 3, "anterior": null}, "id_jugador_inscripcion": {"nuevo": 3, "anterior": null}, "id_estado_jugador_inscripcion": {"nuevo": 1, "anterior": null}}	{es_capitan,es_delegado,fecha_baja,fecha_registro,id_estado_jugador_inscripcion,id_inscripcion,id_jugador,id_jugador_equipo,id_jugador_inscripcion,numero_camiseta,observaciones,registrado_por}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
81	competencia	jugador_inscripcion	INSERT	{"id_jugador_inscripcion": 4}	\N	{"es_capitan": false, "fecha_baja": null, "id_jugador": 7, "es_delegado": false, "observaciones": "Jugador titular de Titanes", "fecha_registro": "2026-07-22T01:40:15.937449-04:00", "id_inscripcion": 1, "registrado_por": 1, "numero_camiseta": 9, "id_jugador_equipo": 2, "id_jugador_inscripcion": 4, "id_estado_jugador_inscripcion": 1}	{"es_capitan": {"nuevo": false, "anterior": null}, "fecha_baja": {"nuevo": null, "anterior": null}, "id_jugador": {"nuevo": 7, "anterior": null}, "es_delegado": {"nuevo": false, "anterior": null}, "observaciones": {"nuevo": "Jugador titular de Titanes", "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "id_inscripcion": {"nuevo": 1, "anterior": null}, "registrado_por": {"nuevo": 1, "anterior": null}, "numero_camiseta": {"nuevo": 9, "anterior": null}, "id_jugador_equipo": {"nuevo": 2, "anterior": null}, "id_jugador_inscripcion": {"nuevo": 4, "anterior": null}, "id_estado_jugador_inscripcion": {"nuevo": 1, "anterior": null}}	{es_capitan,es_delegado,fecha_baja,fecha_registro,id_estado_jugador_inscripcion,id_inscripcion,id_jugador,id_jugador_equipo,id_jugador_inscripcion,numero_camiseta,observaciones,registrado_por}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
82	competencia	jugador_inscripcion	INSERT	{"id_jugador_inscripcion": 5}	\N	{"es_capitan": false, "fecha_baja": null, "id_jugador": 8, "es_delegado": false, "observaciones": "Jugador titular de Titanes", "fecha_registro": "2026-07-22T01:40:15.937449-04:00", "id_inscripcion": 1, "registrado_por": 1, "numero_camiseta": 10, "id_jugador_equipo": 1, "id_jugador_inscripcion": 5, "id_estado_jugador_inscripcion": 1}	{"es_capitan": {"nuevo": false, "anterior": null}, "fecha_baja": {"nuevo": null, "anterior": null}, "id_jugador": {"nuevo": 8, "anterior": null}, "es_delegado": {"nuevo": false, "anterior": null}, "observaciones": {"nuevo": "Jugador titular de Titanes", "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "id_inscripcion": {"nuevo": 1, "anterior": null}, "registrado_por": {"nuevo": 1, "anterior": null}, "numero_camiseta": {"nuevo": 10, "anterior": null}, "id_jugador_equipo": {"nuevo": 1, "anterior": null}, "id_jugador_inscripcion": {"nuevo": 5, "anterior": null}, "id_estado_jugador_inscripcion": {"nuevo": 1, "anterior": null}}	{es_capitan,es_delegado,fecha_baja,fecha_registro,id_estado_jugador_inscripcion,id_inscripcion,id_jugador,id_jugador_equipo,id_jugador_inscripcion,numero_camiseta,observaciones,registrado_por}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
83	competencia	jugador_inscripcion	INSERT	{"id_jugador_inscripcion": 6}	\N	{"es_capitan": true, "fecha_baja": null, "id_jugador": 9, "es_delegado": true, "observaciones": "Jugador titular de Halcones", "fecha_registro": "2026-07-22T01:40:15.937449-04:00", "id_inscripcion": 2, "registrado_por": 1, "numero_camiseta": 1, "id_jugador_equipo": 10, "id_jugador_inscripcion": 6, "id_estado_jugador_inscripcion": 1}	{"es_capitan": {"nuevo": true, "anterior": null}, "fecha_baja": {"nuevo": null, "anterior": null}, "id_jugador": {"nuevo": 9, "anterior": null}, "es_delegado": {"nuevo": true, "anterior": null}, "observaciones": {"nuevo": "Jugador titular de Halcones", "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "id_inscripcion": {"nuevo": 2, "anterior": null}, "registrado_por": {"nuevo": 1, "anterior": null}, "numero_camiseta": {"nuevo": 1, "anterior": null}, "id_jugador_equipo": {"nuevo": 10, "anterior": null}, "id_jugador_inscripcion": {"nuevo": 6, "anterior": null}, "id_estado_jugador_inscripcion": {"nuevo": 1, "anterior": null}}	{es_capitan,es_delegado,fecha_baja,fecha_registro,id_estado_jugador_inscripcion,id_inscripcion,id_jugador,id_jugador_equipo,id_jugador_inscripcion,numero_camiseta,observaciones,registrado_por}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
84	competencia	jugador_inscripcion	INSERT	{"id_jugador_inscripcion": 7}	\N	{"es_capitan": false, "fecha_baja": null, "id_jugador": 10, "es_delegado": false, "observaciones": "Jugador titular de Halcones", "fecha_registro": "2026-07-22T01:40:15.937449-04:00", "id_inscripcion": 2, "registrado_por": 1, "numero_camiseta": 3, "id_jugador_equipo": 9, "id_jugador_inscripcion": 7, "id_estado_jugador_inscripcion": 1}	{"es_capitan": {"nuevo": false, "anterior": null}, "fecha_baja": {"nuevo": null, "anterior": null}, "id_jugador": {"nuevo": 10, "anterior": null}, "es_delegado": {"nuevo": false, "anterior": null}, "observaciones": {"nuevo": "Jugador titular de Halcones", "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "id_inscripcion": {"nuevo": 2, "anterior": null}, "registrado_por": {"nuevo": 1, "anterior": null}, "numero_camiseta": {"nuevo": 3, "anterior": null}, "id_jugador_equipo": {"nuevo": 9, "anterior": null}, "id_jugador_inscripcion": {"nuevo": 7, "anterior": null}, "id_estado_jugador_inscripcion": {"nuevo": 1, "anterior": null}}	{es_capitan,es_delegado,fecha_baja,fecha_registro,id_estado_jugador_inscripcion,id_inscripcion,id_jugador,id_jugador_equipo,id_jugador_inscripcion,numero_camiseta,observaciones,registrado_por}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
85	competencia	jugador_inscripcion	INSERT	{"id_jugador_inscripcion": 8}	\N	{"es_capitan": false, "fecha_baja": null, "id_jugador": 11, "es_delegado": false, "observaciones": "Jugador titular de Halcones", "fecha_registro": "2026-07-22T01:40:15.937449-04:00", "id_inscripcion": 2, "registrado_por": 1, "numero_camiseta": 6, "id_jugador_equipo": 8, "id_jugador_inscripcion": 8, "id_estado_jugador_inscripcion": 1}	{"es_capitan": {"nuevo": false, "anterior": null}, "fecha_baja": {"nuevo": null, "anterior": null}, "id_jugador": {"nuevo": 11, "anterior": null}, "es_delegado": {"nuevo": false, "anterior": null}, "observaciones": {"nuevo": "Jugador titular de Halcones", "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "id_inscripcion": {"nuevo": 2, "anterior": null}, "registrado_por": {"nuevo": 1, "anterior": null}, "numero_camiseta": {"nuevo": 6, "anterior": null}, "id_jugador_equipo": {"nuevo": 8, "anterior": null}, "id_jugador_inscripcion": {"nuevo": 8, "anterior": null}, "id_estado_jugador_inscripcion": {"nuevo": 1, "anterior": null}}	{es_capitan,es_delegado,fecha_baja,fecha_registro,id_estado_jugador_inscripcion,id_inscripcion,id_jugador,id_jugador_equipo,id_jugador_inscripcion,numero_camiseta,observaciones,registrado_por}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
86	competencia	jugador_inscripcion	INSERT	{"id_jugador_inscripcion": 9}	\N	{"es_capitan": false, "fecha_baja": null, "id_jugador": 12, "es_delegado": false, "observaciones": "Jugador titular de Halcones", "fecha_registro": "2026-07-22T01:40:15.937449-04:00", "id_inscripcion": 2, "registrado_por": 1, "numero_camiseta": 8, "id_jugador_equipo": 7, "id_jugador_inscripcion": 9, "id_estado_jugador_inscripcion": 1}	{"es_capitan": {"nuevo": false, "anterior": null}, "fecha_baja": {"nuevo": null, "anterior": null}, "id_jugador": {"nuevo": 12, "anterior": null}, "es_delegado": {"nuevo": false, "anterior": null}, "observaciones": {"nuevo": "Jugador titular de Halcones", "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "id_inscripcion": {"nuevo": 2, "anterior": null}, "registrado_por": {"nuevo": 1, "anterior": null}, "numero_camiseta": {"nuevo": 8, "anterior": null}, "id_jugador_equipo": {"nuevo": 7, "anterior": null}, "id_jugador_inscripcion": {"nuevo": 9, "anterior": null}, "id_estado_jugador_inscripcion": {"nuevo": 1, "anterior": null}}	{es_capitan,es_delegado,fecha_baja,fecha_registro,id_estado_jugador_inscripcion,id_inscripcion,id_jugador,id_jugador_equipo,id_jugador_inscripcion,numero_camiseta,observaciones,registrado_por}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
87	competencia	jugador_inscripcion	INSERT	{"id_jugador_inscripcion": 10}	\N	{"es_capitan": false, "fecha_baja": null, "id_jugador": 13, "es_delegado": false, "observaciones": "Jugador titular de Halcones", "fecha_registro": "2026-07-22T01:40:15.937449-04:00", "id_inscripcion": 2, "registrado_por": 1, "numero_camiseta": 11, "id_jugador_equipo": 6, "id_jugador_inscripcion": 10, "id_estado_jugador_inscripcion": 1}	{"es_capitan": {"nuevo": false, "anterior": null}, "fecha_baja": {"nuevo": null, "anterior": null}, "id_jugador": {"nuevo": 13, "anterior": null}, "es_delegado": {"nuevo": false, "anterior": null}, "observaciones": {"nuevo": "Jugador titular de Halcones", "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "id_inscripcion": {"nuevo": 2, "anterior": null}, "registrado_por": {"nuevo": 1, "anterior": null}, "numero_camiseta": {"nuevo": 11, "anterior": null}, "id_jugador_equipo": {"nuevo": 6, "anterior": null}, "id_jugador_inscripcion": {"nuevo": 10, "anterior": null}, "id_estado_jugador_inscripcion": {"nuevo": 1, "anterior": null}}	{es_capitan,es_delegado,fecha_baja,fecha_registro,id_estado_jugador_inscripcion,id_inscripcion,id_jugador,id_jugador_equipo,id_jugador_inscripcion,numero_camiseta,observaciones,registrado_por}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
88	competencia	inscripcion	UPDATE	{"id_inscripcion": 1}	{"moneda": "BOB", "id_equipo": 1, "id_torneo": 3, "observaciones": "Inscripcion de Titanes Futsal", "id_inscripcion": 1, "registrado_por": 1, "monto_requerido": 200.00, "fecha_inscripcion": "2026-07-22T01:40:15.937449-04:00", "fecha_actualizacion": "2026-07-22T01:40:15.937449-04:00", "id_estado_inscripcion": 1}	{"moneda": "BOB", "id_equipo": 1, "id_torneo": 3, "observaciones": "Inscripcion de Titanes Futsal", "id_inscripcion": 1, "registrado_por": 1, "monto_requerido": 200.00, "fecha_inscripcion": "2026-07-22T01:40:15.937449-04:00", "fecha_actualizacion": "2026-07-22T01:40:15.937449-04:00", "id_estado_inscripcion": 2}	{"id_estado_inscripcion": {"nuevo": 2, "anterior": 1}}	{id_estado_inscripcion}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
89	finanzas	pago	INSERT	{"id_pago": 1}	\N	{"monto": 100.00, "moneda": "BOB", "id_pago": 1, "fecha_pago": "2026-07-22T01:40:15.937449-04:00", "referencia": "DEMO-TIT-001", "observaciones": "Primer pago parcial de Titanes", "fecha_registro": "2026-07-22T01:40:15.937449-04:00", "id_estado_pago": 2, "id_inscripcion": 1, "id_metodo_pago": 3, "registrado_por": 1, "verificado_por": 1, "comprobante_url": null, "fecha_verificacion": "2026-07-22T01:40:15.937449-04:00", "fecha_actualizacion": "2026-07-22T01:40:15.937449-04:00"}	{"monto": {"nuevo": 100.00, "anterior": null}, "moneda": {"nuevo": "BOB", "anterior": null}, "id_pago": {"nuevo": 1, "anterior": null}, "fecha_pago": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "referencia": {"nuevo": "DEMO-TIT-001", "anterior": null}, "observaciones": {"nuevo": "Primer pago parcial de Titanes", "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "id_estado_pago": {"nuevo": 2, "anterior": null}, "id_inscripcion": {"nuevo": 1, "anterior": null}, "id_metodo_pago": {"nuevo": 3, "anterior": null}, "registrado_por": {"nuevo": 1, "anterior": null}, "verificado_por": {"nuevo": 1, "anterior": null}, "comprobante_url": {"nuevo": null, "anterior": null}, "fecha_verificacion": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "fecha_actualizacion": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}}	{comprobante_url,fecha_actualizacion,fecha_pago,fecha_registro,fecha_verificacion,id_estado_pago,id_inscripcion,id_metodo_pago,id_pago,moneda,monto,observaciones,referencia,registrado_por,verificado_por}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
90	competencia	inscripcion	UPDATE	{"id_inscripcion": 1}	{"moneda": "BOB", "id_equipo": 1, "id_torneo": 3, "observaciones": "Inscripcion de Titanes Futsal", "id_inscripcion": 1, "registrado_por": 1, "monto_requerido": 200.00, "fecha_inscripcion": "2026-07-22T01:40:15.937449-04:00", "fecha_actualizacion": "2026-07-22T01:40:15.937449-04:00", "id_estado_inscripcion": 2}	{"moneda": "BOB", "id_equipo": 1, "id_torneo": 3, "observaciones": "Inscripcion de Titanes Futsal", "id_inscripcion": 1, "registrado_por": 1, "monto_requerido": 200.00, "fecha_inscripcion": "2026-07-22T01:40:15.937449-04:00", "fecha_actualizacion": "2026-07-22T01:40:15.937449-04:00", "id_estado_inscripcion": 3}	{"id_estado_inscripcion": {"nuevo": 3, "anterior": 2}}	{id_estado_inscripcion}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
91	finanzas	pago	INSERT	{"id_pago": 2}	\N	{"monto": 100.00, "moneda": "BOB", "id_pago": 2, "fecha_pago": "2026-07-22T01:40:15.937449-04:00", "referencia": "DEMO-TIT-002", "observaciones": "Segundo pago de Titanes", "fecha_registro": "2026-07-22T01:40:15.937449-04:00", "id_estado_pago": 2, "id_inscripcion": 1, "id_metodo_pago": 2, "registrado_por": 1, "verificado_por": 1, "comprobante_url": null, "fecha_verificacion": "2026-07-22T01:40:15.937449-04:00", "fecha_actualizacion": "2026-07-22T01:40:15.937449-04:00"}	{"monto": {"nuevo": 100.00, "anterior": null}, "moneda": {"nuevo": "BOB", "anterior": null}, "id_pago": {"nuevo": 2, "anterior": null}, "fecha_pago": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "referencia": {"nuevo": "DEMO-TIT-002", "anterior": null}, "observaciones": {"nuevo": "Segundo pago de Titanes", "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "id_estado_pago": {"nuevo": 2, "anterior": null}, "id_inscripcion": {"nuevo": 1, "anterior": null}, "id_metodo_pago": {"nuevo": 2, "anterior": null}, "registrado_por": {"nuevo": 1, "anterior": null}, "verificado_por": {"nuevo": 1, "anterior": null}, "comprobante_url": {"nuevo": null, "anterior": null}, "fecha_verificacion": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "fecha_actualizacion": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}}	{comprobante_url,fecha_actualizacion,fecha_pago,fecha_registro,fecha_verificacion,id_estado_pago,id_inscripcion,id_metodo_pago,id_pago,moneda,monto,observaciones,referencia,registrado_por,verificado_por}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
92	competencia	inscripcion	UPDATE	{"id_inscripcion": 2}	{"moneda": "BOB", "id_equipo": 2, "id_torneo": 3, "observaciones": "Inscripcion de Halcones Futsal", "id_inscripcion": 2, "registrado_por": 1, "monto_requerido": 200.00, "fecha_inscripcion": "2026-07-22T01:40:15.937449-04:00", "fecha_actualizacion": "2026-07-22T01:40:15.937449-04:00", "id_estado_inscripcion": 1}	{"moneda": "BOB", "id_equipo": 2, "id_torneo": 3, "observaciones": "Inscripcion de Halcones Futsal", "id_inscripcion": 2, "registrado_por": 1, "monto_requerido": 200.00, "fecha_inscripcion": "2026-07-22T01:40:15.937449-04:00", "fecha_actualizacion": "2026-07-22T01:40:15.937449-04:00", "id_estado_inscripcion": 3}	{"id_estado_inscripcion": {"nuevo": 3, "anterior": 1}}	{id_estado_inscripcion}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
93	finanzas	pago	INSERT	{"id_pago": 3}	\N	{"monto": 200.00, "moneda": "BOB", "id_pago": 3, "fecha_pago": "2026-07-22T01:40:15.937449-04:00", "referencia": "DEMO-HAL-001", "observaciones": "Pago completo de Halcones", "fecha_registro": "2026-07-22T01:40:15.937449-04:00", "id_estado_pago": 2, "id_inscripcion": 2, "id_metodo_pago": 4, "registrado_por": 1, "verificado_por": 1, "comprobante_url": null, "fecha_verificacion": "2026-07-22T01:40:15.937449-04:00", "fecha_actualizacion": "2026-07-22T01:40:15.937449-04:00"}	{"monto": {"nuevo": 200.00, "anterior": null}, "moneda": {"nuevo": "BOB", "anterior": null}, "id_pago": {"nuevo": 3, "anterior": null}, "fecha_pago": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "referencia": {"nuevo": "DEMO-HAL-001", "anterior": null}, "observaciones": {"nuevo": "Pago completo de Halcones", "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "id_estado_pago": {"nuevo": 2, "anterior": null}, "id_inscripcion": {"nuevo": 2, "anterior": null}, "id_metodo_pago": {"nuevo": 4, "anterior": null}, "registrado_por": {"nuevo": 1, "anterior": null}, "verificado_por": {"nuevo": 1, "anterior": null}, "comprobante_url": {"nuevo": null, "anterior": null}, "fecha_verificacion": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "fecha_actualizacion": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}}	{comprobante_url,fecha_actualizacion,fecha_pago,fecha_registro,fecha_verificacion,id_estado_pago,id_inscripcion,id_metodo_pago,id_pago,moneda,monto,observaciones,referencia,registrado_por,verificado_por}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
94	competencia	torneo	UPDATE	{"id_torneo": 3}	{"rama": "MASCULINO", "codigo": "FTS-DEMO-2026-01", "moneda": "BOB", "nombre": "Copa Demo de Futsal 2026", "edicion": "2026", "categoria": "Libre", "id_torneo": 3, "creado_por": 1, "id_deporte": 2, "descripcion": "Torneo de demostracion para probar el flujo completo", "fecha_registro": "2026-07-22T01:40:15.937449-04:00", "permite_empate": false, "fecha_fin_torneo": "2026-08-20", "id_estado_torneo": 2, "costo_inscripcion": 200.00, "id_formato_torneo": 1, "fecha_actualizacion": "2026-07-22T01:40:15.937449-04:00", "fecha_inicio_torneo": "2026-08-20", "fecha_fin_inscripcion": "2026-08-10", "cantidad_maxima_equipos": 2, "fecha_inicio_inscripcion": "2026-08-01", "cantidad_maxima_jugadores": 7, "cantidad_minima_jugadores": 5}	{"rama": "MASCULINO", "codigo": "FTS-DEMO-2026-01", "moneda": "BOB", "nombre": "Copa Demo de Futsal 2026", "edicion": "2026", "categoria": "Libre", "id_torneo": 3, "creado_por": 1, "id_deporte": 2, "descripcion": "Torneo de demostracion para probar el flujo completo", "fecha_registro": "2026-07-22T01:40:15.937449-04:00", "permite_empate": false, "fecha_fin_torneo": "2026-08-20", "id_estado_torneo": 3, "costo_inscripcion": 200.00, "id_formato_torneo": 1, "fecha_actualizacion": "2026-07-22T01:40:15.937449-04:00", "fecha_inicio_torneo": "2026-08-20", "fecha_fin_inscripcion": "2026-08-10", "cantidad_maxima_equipos": 2, "fecha_inicio_inscripcion": "2026-08-01", "cantidad_maxima_jugadores": 7, "cantidad_minima_jugadores": 5}	{"id_estado_torneo": {"nuevo": 3, "anterior": 2}}	{id_estado_torneo}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
95	competencia	partido	INSERT	{"id_partido": 1}	\N	{"codigo": "FTS-DEMO-P001", "id_lugar": 1, "creado_por": 1, "id_jornada": 2, "id_partido": 1, "nombre_ronda": "Final", "observaciones": "Partido unico de la Copa Demo", "fecha_hora_fin": "2026-08-20T16:30:00-04:00", "fecha_registro": "2026-07-22T01:40:15.937449-04:00", "numero_partido": 1, "actualizado_por": null, "id_grupo_torneo": null, "fecha_hora_inicio": "2026-08-20T15:00:00-04:00", "id_estado_partido": 1, "fecha_actualizacion": "2026-07-22T01:40:15.937449-04:00", "id_partido_siguiente": null}	{"codigo": {"nuevo": "FTS-DEMO-P001", "anterior": null}, "id_lugar": {"nuevo": 1, "anterior": null}, "creado_por": {"nuevo": 1, "anterior": null}, "id_jornada": {"nuevo": 2, "anterior": null}, "id_partido": {"nuevo": 1, "anterior": null}, "nombre_ronda": {"nuevo": "Final", "anterior": null}, "observaciones": {"nuevo": "Partido unico de la Copa Demo", "anterior": null}, "fecha_hora_fin": {"nuevo": "2026-08-20T16:30:00-04:00", "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "numero_partido": {"nuevo": 1, "anterior": null}, "actualizado_por": {"nuevo": null, "anterior": null}, "id_grupo_torneo": {"nuevo": null, "anterior": null}, "fecha_hora_inicio": {"nuevo": "2026-08-20T15:00:00-04:00", "anterior": null}, "id_estado_partido": {"nuevo": 1, "anterior": null}, "fecha_actualizacion": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "id_partido_siguiente": {"nuevo": null, "anterior": null}}	{actualizado_por,codigo,creado_por,fecha_actualizacion,fecha_hora_fin,fecha_hora_inicio,fecha_registro,id_estado_partido,id_grupo_torneo,id_jornada,id_lugar,id_partido,id_partido_siguiente,nombre_ronda,numero_partido,observaciones}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
96	competencia	partido_equipo	INSERT	{"id_partido_equipo": 1}	\N	{"marcador": null, "id_partido": 1, "clasificado": false, "puntos_tabla": 0, "observaciones": null, "id_inscripcion": 1, "id_partido_equipo": 1, "marcador_desempate": null, "id_condicion_equipo": 1, "id_resultado_equipo_partido": 1}	{"marcador": {"nuevo": null, "anterior": null}, "id_partido": {"nuevo": 1, "anterior": null}, "clasificado": {"nuevo": false, "anterior": null}, "puntos_tabla": {"nuevo": 0, "anterior": null}, "observaciones": {"nuevo": null, "anterior": null}, "id_inscripcion": {"nuevo": 1, "anterior": null}, "id_partido_equipo": {"nuevo": 1, "anterior": null}, "marcador_desempate": {"nuevo": null, "anterior": null}, "id_condicion_equipo": {"nuevo": 1, "anterior": null}, "id_resultado_equipo_partido": {"nuevo": 1, "anterior": null}}	{clasificado,id_condicion_equipo,id_inscripcion,id_partido,id_partido_equipo,id_resultado_equipo_partido,marcador,marcador_desempate,observaciones,puntos_tabla}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
97	competencia	partido_equipo	INSERT	{"id_partido_equipo": 2}	\N	{"marcador": null, "id_partido": 1, "clasificado": false, "puntos_tabla": 0, "observaciones": null, "id_inscripcion": 2, "id_partido_equipo": 2, "marcador_desempate": null, "id_condicion_equipo": 2, "id_resultado_equipo_partido": 1}	{"marcador": {"nuevo": null, "anterior": null}, "id_partido": {"nuevo": 1, "anterior": null}, "clasificado": {"nuevo": false, "anterior": null}, "puntos_tabla": {"nuevo": 0, "anterior": null}, "observaciones": {"nuevo": null, "anterior": null}, "id_inscripcion": {"nuevo": 2, "anterior": null}, "id_partido_equipo": {"nuevo": 2, "anterior": null}, "marcador_desempate": {"nuevo": null, "anterior": null}, "id_condicion_equipo": {"nuevo": 2, "anterior": null}, "id_resultado_equipo_partido": {"nuevo": 1, "anterior": null}}	{clasificado,id_condicion_equipo,id_inscripcion,id_partido,id_partido_equipo,id_resultado_equipo_partido,marcador,marcador_desempate,observaciones,puntos_tabla}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
98	competencia	partido	UPDATE	{"id_partido": 1}	{"codigo": "FTS-DEMO-P001", "id_lugar": 1, "creado_por": 1, "id_jornada": 2, "id_partido": 1, "nombre_ronda": "Final", "observaciones": "Partido unico de la Copa Demo", "fecha_hora_fin": "2026-08-20T16:30:00-04:00", "fecha_registro": "2026-07-22T01:40:15.937449-04:00", "numero_partido": 1, "actualizado_por": null, "id_grupo_torneo": null, "fecha_hora_inicio": "2026-08-20T15:00:00-04:00", "id_estado_partido": 1, "fecha_actualizacion": "2026-07-22T01:40:15.937449-04:00", "id_partido_siguiente": null}	{"codigo": "FTS-DEMO-P001", "id_lugar": 1, "creado_por": 1, "id_jornada": 2, "id_partido": 1, "nombre_ronda": "Final", "observaciones": "Partido unico de la Copa Demo", "fecha_hora_fin": "2026-08-20T16:30:00-04:00", "fecha_registro": "2026-07-22T01:40:15.937449-04:00", "numero_partido": 1, "actualizado_por": 1, "id_grupo_torneo": null, "fecha_hora_inicio": "2026-08-20T15:00:00-04:00", "id_estado_partido": 2, "fecha_actualizacion": "2026-07-22T01:40:15.937449-04:00", "id_partido_siguiente": null}	{"actualizado_por": {"nuevo": 1, "anterior": null}, "id_estado_partido": {"nuevo": 2, "anterior": 1}}	{actualizado_por,id_estado_partido}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
99	competencia	arbitro_partido	INSERT	{"id_arbitro_partido": 1}	\N	{"activo": true, "fecha_fin": null, "id_arbitro": 3, "id_partido": 1, "asignado_por": 1, "observaciones": "Arbitro principal del partido demo", "fecha_asignacion": "2026-07-22T01:40:15.937449-04:00", "id_arbitro_partido": 1, "id_tipo_arbitro_partido": 1}	{"activo": {"nuevo": true, "anterior": null}, "fecha_fin": {"nuevo": null, "anterior": null}, "id_arbitro": {"nuevo": 3, "anterior": null}, "id_partido": {"nuevo": 1, "anterior": null}, "asignado_por": {"nuevo": 1, "anterior": null}, "observaciones": {"nuevo": "Arbitro principal del partido demo", "anterior": null}, "fecha_asignacion": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "id_arbitro_partido": {"nuevo": 1, "anterior": null}, "id_tipo_arbitro_partido": {"nuevo": 1, "anterior": null}}	{activo,asignado_por,fecha_asignacion,fecha_fin,id_arbitro,id_arbitro_partido,id_partido,id_tipo_arbitro_partido,observaciones}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
100	competencia	torneo	UPDATE	{"id_torneo": 3}	{"rama": "MASCULINO", "codigo": "FTS-DEMO-2026-01", "moneda": "BOB", "nombre": "Copa Demo de Futsal 2026", "edicion": "2026", "categoria": "Libre", "id_torneo": 3, "creado_por": 1, "id_deporte": 2, "descripcion": "Torneo de demostracion para probar el flujo completo", "fecha_registro": "2026-07-22T01:40:15.937449-04:00", "permite_empate": false, "fecha_fin_torneo": "2026-08-20", "id_estado_torneo": 3, "costo_inscripcion": 200.00, "id_formato_torneo": 1, "fecha_actualizacion": "2026-07-22T01:40:15.937449-04:00", "fecha_inicio_torneo": "2026-08-20", "fecha_fin_inscripcion": "2026-08-10", "cantidad_maxima_equipos": 2, "fecha_inicio_inscripcion": "2026-08-01", "cantidad_maxima_jugadores": 7, "cantidad_minima_jugadores": 5}	{"rama": "MASCULINO", "codigo": "FTS-DEMO-2026-01", "moneda": "BOB", "nombre": "Copa Demo de Futsal 2026", "edicion": "2026", "categoria": "Libre", "id_torneo": 3, "creado_por": 1, "id_deporte": 2, "descripcion": "Torneo de demostracion para probar el flujo completo", "fecha_registro": "2026-07-22T01:40:15.937449-04:00", "permite_empate": false, "fecha_fin_torneo": "2026-08-20", "id_estado_torneo": 4, "costo_inscripcion": 200.00, "id_formato_torneo": 1, "fecha_actualizacion": "2026-07-22T01:40:15.937449-04:00", "fecha_inicio_torneo": "2026-08-20", "fecha_fin_inscripcion": "2026-08-10", "cantidad_maxima_equipos": 2, "fecha_inicio_inscripcion": "2026-08-01", "cantidad_maxima_jugadores": 7, "cantidad_minima_jugadores": 5}	{"id_estado_torneo": {"nuevo": 4, "anterior": 3}}	{id_estado_torneo}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
101	competencia	torneo	UPDATE	{"id_torneo": 3}	{"rama": "MASCULINO", "codigo": "FTS-DEMO-2026-01", "moneda": "BOB", "nombre": "Copa Demo de Futsal 2026", "edicion": "2026", "categoria": "Libre", "id_torneo": 3, "creado_por": 1, "id_deporte": 2, "descripcion": "Torneo de demostracion para probar el flujo completo", "fecha_registro": "2026-07-22T01:40:15.937449-04:00", "permite_empate": false, "fecha_fin_torneo": "2026-08-20", "id_estado_torneo": 4, "costo_inscripcion": 200.00, "id_formato_torneo": 1, "fecha_actualizacion": "2026-07-22T01:40:15.937449-04:00", "fecha_inicio_torneo": "2026-08-20", "fecha_fin_inscripcion": "2026-08-10", "cantidad_maxima_equipos": 2, "fecha_inicio_inscripcion": "2026-08-01", "cantidad_maxima_jugadores": 7, "cantidad_minima_jugadores": 5}	{"rama": "MASCULINO", "codigo": "FTS-DEMO-2026-01", "moneda": "BOB", "nombre": "Copa Demo de Futsal 2026", "edicion": "2026", "categoria": "Libre", "id_torneo": 3, "creado_por": 1, "id_deporte": 2, "descripcion": "Torneo de demostracion para probar el flujo completo", "fecha_registro": "2026-07-22T01:40:15.937449-04:00", "permite_empate": false, "fecha_fin_torneo": "2026-08-20", "id_estado_torneo": 5, "costo_inscripcion": 200.00, "id_formato_torneo": 1, "fecha_actualizacion": "2026-07-22T01:40:15.937449-04:00", "fecha_inicio_torneo": "2026-08-20", "fecha_fin_inscripcion": "2026-08-10", "cantidad_maxima_equipos": 2, "fecha_inicio_inscripcion": "2026-08-01", "cantidad_maxima_jugadores": 7, "cantidad_minima_jugadores": 5}	{"id_estado_torneo": {"nuevo": 5, "anterior": 4}}	{id_estado_torneo}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
102	competencia	fase_torneo	UPDATE	{"id_fase_torneo": 2}	{"nombre": "Final unica", "fecha_fin": "2026-08-20", "id_torneo": 3, "descripcion": "Fase compuesta por un solo partido", "fecha_inicio": "2026-08-20", "id_tipo_fase": 1, "numero_orden": 1, "id_estado_fase": 1, "id_fase_torneo": 2, "cantidad_clasificados": 1}	{"nombre": "Final unica", "fecha_fin": "2026-08-20", "id_torneo": 3, "descripcion": "Fase compuesta por un solo partido", "fecha_inicio": "2026-08-20", "id_tipo_fase": 1, "numero_orden": 1, "id_estado_fase": 2, "id_fase_torneo": 2, "cantidad_clasificados": 1}	{"id_estado_fase": {"nuevo": 2, "anterior": 1}}	{id_estado_fase}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
103	competencia	jornada	UPDATE	{"id_jornada": 2}	{"nombre": "Jornada final", "fecha_fin": "2026-08-20T18:00:00-04:00", "id_jornada": 2, "fecha_inicio": "2026-08-20T14:00:00-04:00", "observaciones": "Jornada del partido unico", "id_fase_torneo": 2, "numero_jornada": 1, "id_estado_jornada": 1}	{"nombre": "Jornada final", "fecha_fin": "2026-08-20T18:00:00-04:00", "id_jornada": 2, "fecha_inicio": "2026-08-20T14:00:00-04:00", "observaciones": "Jornada del partido unico", "id_fase_torneo": 2, "numero_jornada": 1, "id_estado_jornada": 2}	{"id_estado_jornada": {"nuevo": 2, "anterior": 1}}	{id_estado_jornada}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
104	competencia	partido	UPDATE	{"id_partido": 1}	{"codigo": "FTS-DEMO-P001", "id_lugar": 1, "creado_por": 1, "id_jornada": 2, "id_partido": 1, "nombre_ronda": "Final", "observaciones": "Partido unico de la Copa Demo", "fecha_hora_fin": "2026-08-20T16:30:00-04:00", "fecha_registro": "2026-07-22T01:40:15.937449-04:00", "numero_partido": 1, "actualizado_por": 1, "id_grupo_torneo": null, "fecha_hora_inicio": "2026-08-20T15:00:00-04:00", "id_estado_partido": 2, "fecha_actualizacion": "2026-07-22T01:40:15.937449-04:00", "id_partido_siguiente": null}	{"codigo": "FTS-DEMO-P001", "id_lugar": 1, "creado_por": 1, "id_jornada": 2, "id_partido": 1, "nombre_ronda": "Final", "observaciones": "Partido unico de la Copa Demo", "fecha_hora_fin": "2026-08-20T16:30:00-04:00", "fecha_registro": "2026-07-22T01:40:15.937449-04:00", "numero_partido": 1, "actualizado_por": 1, "id_grupo_torneo": null, "fecha_hora_inicio": "2026-08-20T15:00:00-04:00", "id_estado_partido": 3, "fecha_actualizacion": "2026-07-22T01:40:15.937449-04:00", "id_partido_siguiente": null}	{"id_estado_partido": {"nuevo": 3, "anterior": 2}}	{id_estado_partido}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
105	competencia	jugador_partido	INSERT	{"id_jugador_partido": 1}	\N	{"faltas": 0, "asistio": true, "titular": true, "convocado": true, "expulsado": false, "lesionado": false, "id_partido": 1, "calificacion": 9.00, "estadisticas": {"goles": 2, "atajadas": 5, "asistencias": 1}, "observaciones": "Participacion registrada en el flujo demo", "amonestaciones": 0, "fecha_registro": "2026-07-22T01:40:15.937449-04:00", "registrado_por": 1, "minutos_jugados": 40, "puntos_anotados": 2, "id_partido_equipo": 2, "id_jugador_partido": 1, "fecha_actualizacion": "2026-07-22T01:40:15.937449-04:00", "id_jugador_inscripcion": 6}	{"faltas": {"nuevo": 0, "anterior": null}, "asistio": {"nuevo": true, "anterior": null}, "titular": {"nuevo": true, "anterior": null}, "convocado": {"nuevo": true, "anterior": null}, "expulsado": {"nuevo": false, "anterior": null}, "lesionado": {"nuevo": false, "anterior": null}, "id_partido": {"nuevo": 1, "anterior": null}, "calificacion": {"nuevo": 9.00, "anterior": null}, "estadisticas": {"nuevo": {"goles": 2, "atajadas": 5, "asistencias": 1}, "anterior": null}, "observaciones": {"nuevo": "Participacion registrada en el flujo demo", "anterior": null}, "amonestaciones": {"nuevo": 0, "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "registrado_por": {"nuevo": 1, "anterior": null}, "minutos_jugados": {"nuevo": 40, "anterior": null}, "puntos_anotados": {"nuevo": 2, "anterior": null}, "id_partido_equipo": {"nuevo": 2, "anterior": null}, "id_jugador_partido": {"nuevo": 1, "anterior": null}, "fecha_actualizacion": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "id_jugador_inscripcion": {"nuevo": 6, "anterior": null}}	{amonestaciones,asistio,calificacion,convocado,estadisticas,expulsado,faltas,fecha_actualizacion,fecha_registro,id_jugador_inscripcion,id_jugador_partido,id_partido,id_partido_equipo,lesionado,minutos_jugados,observaciones,puntos_anotados,registrado_por,titular}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
106	competencia	jugador_partido	INSERT	{"id_jugador_partido": 2}	\N	{"faltas": 0, "asistio": true, "titular": true, "convocado": true, "expulsado": false, "lesionado": false, "id_partido": 1, "calificacion": 8.00, "estadisticas": {"goles": 1, "atajadas": 0, "asistencias": 1}, "observaciones": "Participacion registrada en el flujo demo", "amonestaciones": 0, "fecha_registro": "2026-07-22T01:40:15.937449-04:00", "registrado_por": 1, "minutos_jugados": 40, "puntos_anotados": 1, "id_partido_equipo": 2, "id_jugador_partido": 2, "fecha_actualizacion": "2026-07-22T01:40:15.937449-04:00", "id_jugador_inscripcion": 7}	{"faltas": {"nuevo": 0, "anterior": null}, "asistio": {"nuevo": true, "anterior": null}, "titular": {"nuevo": true, "anterior": null}, "convocado": {"nuevo": true, "anterior": null}, "expulsado": {"nuevo": false, "anterior": null}, "lesionado": {"nuevo": false, "anterior": null}, "id_partido": {"nuevo": 1, "anterior": null}, "calificacion": {"nuevo": 8.00, "anterior": null}, "estadisticas": {"nuevo": {"goles": 1, "atajadas": 0, "asistencias": 1}, "anterior": null}, "observaciones": {"nuevo": "Participacion registrada en el flujo demo", "anterior": null}, "amonestaciones": {"nuevo": 0, "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "registrado_por": {"nuevo": 1, "anterior": null}, "minutos_jugados": {"nuevo": 40, "anterior": null}, "puntos_anotados": {"nuevo": 1, "anterior": null}, "id_partido_equipo": {"nuevo": 2, "anterior": null}, "id_jugador_partido": {"nuevo": 2, "anterior": null}, "fecha_actualizacion": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "id_jugador_inscripcion": {"nuevo": 7, "anterior": null}}	{amonestaciones,asistio,calificacion,convocado,estadisticas,expulsado,faltas,fecha_actualizacion,fecha_registro,id_jugador_inscripcion,id_jugador_partido,id_partido,id_partido_equipo,lesionado,minutos_jugados,observaciones,puntos_anotados,registrado_por,titular}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
107	competencia	jugador_partido	INSERT	{"id_jugador_partido": 3}	\N	{"faltas": 0, "asistio": true, "titular": true, "convocado": true, "expulsado": false, "lesionado": false, "id_partido": 1, "calificacion": 7.00, "estadisticas": {"goles": 0, "atajadas": 0, "asistencias": 0}, "observaciones": "Participacion registrada en el flujo demo", "amonestaciones": 0, "fecha_registro": "2026-07-22T01:40:15.937449-04:00", "registrado_por": 1, "minutos_jugados": 40, "puntos_anotados": 0, "id_partido_equipo": 2, "id_jugador_partido": 3, "fecha_actualizacion": "2026-07-22T01:40:15.937449-04:00", "id_jugador_inscripcion": 8}	{"faltas": {"nuevo": 0, "anterior": null}, "asistio": {"nuevo": true, "anterior": null}, "titular": {"nuevo": true, "anterior": null}, "convocado": {"nuevo": true, "anterior": null}, "expulsado": {"nuevo": false, "anterior": null}, "lesionado": {"nuevo": false, "anterior": null}, "id_partido": {"nuevo": 1, "anterior": null}, "calificacion": {"nuevo": 7.00, "anterior": null}, "estadisticas": {"nuevo": {"goles": 0, "atajadas": 0, "asistencias": 0}, "anterior": null}, "observaciones": {"nuevo": "Participacion registrada en el flujo demo", "anterior": null}, "amonestaciones": {"nuevo": 0, "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "registrado_por": {"nuevo": 1, "anterior": null}, "minutos_jugados": {"nuevo": 40, "anterior": null}, "puntos_anotados": {"nuevo": 0, "anterior": null}, "id_partido_equipo": {"nuevo": 2, "anterior": null}, "id_jugador_partido": {"nuevo": 3, "anterior": null}, "fecha_actualizacion": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "id_jugador_inscripcion": {"nuevo": 8, "anterior": null}}	{amonestaciones,asistio,calificacion,convocado,estadisticas,expulsado,faltas,fecha_actualizacion,fecha_registro,id_jugador_inscripcion,id_jugador_partido,id_partido,id_partido_equipo,lesionado,minutos_jugados,observaciones,puntos_anotados,registrado_por,titular}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
108	competencia	jugador_partido	INSERT	{"id_jugador_partido": 4}	\N	{"faltas": 1, "asistio": true, "titular": true, "convocado": true, "expulsado": false, "lesionado": false, "id_partido": 1, "calificacion": 7.00, "estadisticas": {"goles": 0, "atajadas": 0, "asistencias": 0}, "observaciones": "Participacion registrada en el flujo demo", "amonestaciones": 0, "fecha_registro": "2026-07-22T01:40:15.937449-04:00", "registrado_por": 1, "minutos_jugados": 40, "puntos_anotados": 0, "id_partido_equipo": 2, "id_jugador_partido": 4, "fecha_actualizacion": "2026-07-22T01:40:15.937449-04:00", "id_jugador_inscripcion": 9}	{"faltas": {"nuevo": 1, "anterior": null}, "asistio": {"nuevo": true, "anterior": null}, "titular": {"nuevo": true, "anterior": null}, "convocado": {"nuevo": true, "anterior": null}, "expulsado": {"nuevo": false, "anterior": null}, "lesionado": {"nuevo": false, "anterior": null}, "id_partido": {"nuevo": 1, "anterior": null}, "calificacion": {"nuevo": 7.00, "anterior": null}, "estadisticas": {"nuevo": {"goles": 0, "atajadas": 0, "asistencias": 0}, "anterior": null}, "observaciones": {"nuevo": "Participacion registrada en el flujo demo", "anterior": null}, "amonestaciones": {"nuevo": 0, "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "registrado_por": {"nuevo": 1, "anterior": null}, "minutos_jugados": {"nuevo": 40, "anterior": null}, "puntos_anotados": {"nuevo": 0, "anterior": null}, "id_partido_equipo": {"nuevo": 2, "anterior": null}, "id_jugador_partido": {"nuevo": 4, "anterior": null}, "fecha_actualizacion": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "id_jugador_inscripcion": {"nuevo": 9, "anterior": null}}	{amonestaciones,asistio,calificacion,convocado,estadisticas,expulsado,faltas,fecha_actualizacion,fecha_registro,id_jugador_inscripcion,id_jugador_partido,id_partido,id_partido_equipo,lesionado,minutos_jugados,observaciones,puntos_anotados,registrado_por,titular}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
109	competencia	jugador_partido	INSERT	{"id_jugador_partido": 5}	\N	{"faltas": 0, "asistio": true, "titular": true, "convocado": true, "expulsado": false, "lesionado": false, "id_partido": 1, "calificacion": 7.00, "estadisticas": {"goles": 0, "atajadas": 0, "asistencias": 0}, "observaciones": "Participacion registrada en el flujo demo", "amonestaciones": 0, "fecha_registro": "2026-07-22T01:40:15.937449-04:00", "registrado_por": 1, "minutos_jugados": 40, "puntos_anotados": 0, "id_partido_equipo": 2, "id_jugador_partido": 5, "fecha_actualizacion": "2026-07-22T01:40:15.937449-04:00", "id_jugador_inscripcion": 10}	{"faltas": {"nuevo": 0, "anterior": null}, "asistio": {"nuevo": true, "anterior": null}, "titular": {"nuevo": true, "anterior": null}, "convocado": {"nuevo": true, "anterior": null}, "expulsado": {"nuevo": false, "anterior": null}, "lesionado": {"nuevo": false, "anterior": null}, "id_partido": {"nuevo": 1, "anterior": null}, "calificacion": {"nuevo": 7.00, "anterior": null}, "estadisticas": {"nuevo": {"goles": 0, "atajadas": 0, "asistencias": 0}, "anterior": null}, "observaciones": {"nuevo": "Participacion registrada en el flujo demo", "anterior": null}, "amonestaciones": {"nuevo": 0, "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "registrado_por": {"nuevo": 1, "anterior": null}, "minutos_jugados": {"nuevo": 40, "anterior": null}, "puntos_anotados": {"nuevo": 0, "anterior": null}, "id_partido_equipo": {"nuevo": 2, "anterior": null}, "id_jugador_partido": {"nuevo": 5, "anterior": null}, "fecha_actualizacion": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "id_jugador_inscripcion": {"nuevo": 10, "anterior": null}}	{amonestaciones,asistio,calificacion,convocado,estadisticas,expulsado,faltas,fecha_actualizacion,fecha_registro,id_jugador_inscripcion,id_jugador_partido,id_partido,id_partido_equipo,lesionado,minutos_jugados,observaciones,puntos_anotados,registrado_por,titular}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
110	competencia	jugador_partido	INSERT	{"id_jugador_partido": 6}	\N	{"faltas": 0, "asistio": true, "titular": true, "convocado": true, "expulsado": false, "lesionado": false, "id_partido": 1, "calificacion": 9.00, "estadisticas": {"goles": 2, "atajadas": 5, "asistencias": 1}, "observaciones": "Participacion registrada en el flujo demo", "amonestaciones": 0, "fecha_registro": "2026-07-22T01:40:15.937449-04:00", "registrado_por": 1, "minutos_jugados": 40, "puntos_anotados": 2, "id_partido_equipo": 1, "id_jugador_partido": 6, "fecha_actualizacion": "2026-07-22T01:40:15.937449-04:00", "id_jugador_inscripcion": 1}	{"faltas": {"nuevo": 0, "anterior": null}, "asistio": {"nuevo": true, "anterior": null}, "titular": {"nuevo": true, "anterior": null}, "convocado": {"nuevo": true, "anterior": null}, "expulsado": {"nuevo": false, "anterior": null}, "lesionado": {"nuevo": false, "anterior": null}, "id_partido": {"nuevo": 1, "anterior": null}, "calificacion": {"nuevo": 9.00, "anterior": null}, "estadisticas": {"nuevo": {"goles": 2, "atajadas": 5, "asistencias": 1}, "anterior": null}, "observaciones": {"nuevo": "Participacion registrada en el flujo demo", "anterior": null}, "amonestaciones": {"nuevo": 0, "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "registrado_por": {"nuevo": 1, "anterior": null}, "minutos_jugados": {"nuevo": 40, "anterior": null}, "puntos_anotados": {"nuevo": 2, "anterior": null}, "id_partido_equipo": {"nuevo": 1, "anterior": null}, "id_jugador_partido": {"nuevo": 6, "anterior": null}, "fecha_actualizacion": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "id_jugador_inscripcion": {"nuevo": 1, "anterior": null}}	{amonestaciones,asistio,calificacion,convocado,estadisticas,expulsado,faltas,fecha_actualizacion,fecha_registro,id_jugador_inscripcion,id_jugador_partido,id_partido,id_partido_equipo,lesionado,minutos_jugados,observaciones,puntos_anotados,registrado_por,titular}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
111	competencia	jugador_partido	INSERT	{"id_jugador_partido": 7}	\N	{"faltas": 0, "asistio": true, "titular": true, "convocado": true, "expulsado": false, "lesionado": false, "id_partido": 1, "calificacion": 8.00, "estadisticas": {"goles": 1, "atajadas": 0, "asistencias": 1}, "observaciones": "Participacion registrada en el flujo demo", "amonestaciones": 0, "fecha_registro": "2026-07-22T01:40:15.937449-04:00", "registrado_por": 1, "minutos_jugados": 40, "puntos_anotados": 1, "id_partido_equipo": 1, "id_jugador_partido": 7, "fecha_actualizacion": "2026-07-22T01:40:15.937449-04:00", "id_jugador_inscripcion": 2}	{"faltas": {"nuevo": 0, "anterior": null}, "asistio": {"nuevo": true, "anterior": null}, "titular": {"nuevo": true, "anterior": null}, "convocado": {"nuevo": true, "anterior": null}, "expulsado": {"nuevo": false, "anterior": null}, "lesionado": {"nuevo": false, "anterior": null}, "id_partido": {"nuevo": 1, "anterior": null}, "calificacion": {"nuevo": 8.00, "anterior": null}, "estadisticas": {"nuevo": {"goles": 1, "atajadas": 0, "asistencias": 1}, "anterior": null}, "observaciones": {"nuevo": "Participacion registrada en el flujo demo", "anterior": null}, "amonestaciones": {"nuevo": 0, "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "registrado_por": {"nuevo": 1, "anterior": null}, "minutos_jugados": {"nuevo": 40, "anterior": null}, "puntos_anotados": {"nuevo": 1, "anterior": null}, "id_partido_equipo": {"nuevo": 1, "anterior": null}, "id_jugador_partido": {"nuevo": 7, "anterior": null}, "fecha_actualizacion": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "id_jugador_inscripcion": {"nuevo": 2, "anterior": null}}	{amonestaciones,asistio,calificacion,convocado,estadisticas,expulsado,faltas,fecha_actualizacion,fecha_registro,id_jugador_inscripcion,id_jugador_partido,id_partido,id_partido_equipo,lesionado,minutos_jugados,observaciones,puntos_anotados,registrado_por,titular}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
112	competencia	jugador_partido	INSERT	{"id_jugador_partido": 8}	\N	{"faltas": 0, "asistio": true, "titular": true, "convocado": true, "expulsado": false, "lesionado": false, "id_partido": 1, "calificacion": 8.00, "estadisticas": {"goles": 1, "atajadas": 0, "asistencias": 0}, "observaciones": "Participacion registrada en el flujo demo", "amonestaciones": 0, "fecha_registro": "2026-07-22T01:40:15.937449-04:00", "registrado_por": 1, "minutos_jugados": 40, "puntos_anotados": 1, "id_partido_equipo": 1, "id_jugador_partido": 8, "fecha_actualizacion": "2026-07-22T01:40:15.937449-04:00", "id_jugador_inscripcion": 3}	{"faltas": {"nuevo": 0, "anterior": null}, "asistio": {"nuevo": true, "anterior": null}, "titular": {"nuevo": true, "anterior": null}, "convocado": {"nuevo": true, "anterior": null}, "expulsado": {"nuevo": false, "anterior": null}, "lesionado": {"nuevo": false, "anterior": null}, "id_partido": {"nuevo": 1, "anterior": null}, "calificacion": {"nuevo": 8.00, "anterior": null}, "estadisticas": {"nuevo": {"goles": 1, "atajadas": 0, "asistencias": 0}, "anterior": null}, "observaciones": {"nuevo": "Participacion registrada en el flujo demo", "anterior": null}, "amonestaciones": {"nuevo": 0, "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "registrado_por": {"nuevo": 1, "anterior": null}, "minutos_jugados": {"nuevo": 40, "anterior": null}, "puntos_anotados": {"nuevo": 1, "anterior": null}, "id_partido_equipo": {"nuevo": 1, "anterior": null}, "id_jugador_partido": {"nuevo": 8, "anterior": null}, "fecha_actualizacion": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "id_jugador_inscripcion": {"nuevo": 3, "anterior": null}}	{amonestaciones,asistio,calificacion,convocado,estadisticas,expulsado,faltas,fecha_actualizacion,fecha_registro,id_jugador_inscripcion,id_jugador_partido,id_partido,id_partido_equipo,lesionado,minutos_jugados,observaciones,puntos_anotados,registrado_por,titular}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
113	competencia	jugador_partido	INSERT	{"id_jugador_partido": 9}	\N	{"faltas": 1, "asistio": true, "titular": true, "convocado": true, "expulsado": false, "lesionado": false, "id_partido": 1, "calificacion": 7.00, "estadisticas": {"goles": 0, "atajadas": 0, "asistencias": 0}, "observaciones": "Participacion registrada en el flujo demo", "amonestaciones": 0, "fecha_registro": "2026-07-22T01:40:15.937449-04:00", "registrado_por": 1, "minutos_jugados": 40, "puntos_anotados": 0, "id_partido_equipo": 1, "id_jugador_partido": 9, "fecha_actualizacion": "2026-07-22T01:40:15.937449-04:00", "id_jugador_inscripcion": 4}	{"faltas": {"nuevo": 1, "anterior": null}, "asistio": {"nuevo": true, "anterior": null}, "titular": {"nuevo": true, "anterior": null}, "convocado": {"nuevo": true, "anterior": null}, "expulsado": {"nuevo": false, "anterior": null}, "lesionado": {"nuevo": false, "anterior": null}, "id_partido": {"nuevo": 1, "anterior": null}, "calificacion": {"nuevo": 7.00, "anterior": null}, "estadisticas": {"nuevo": {"goles": 0, "atajadas": 0, "asistencias": 0}, "anterior": null}, "observaciones": {"nuevo": "Participacion registrada en el flujo demo", "anterior": null}, "amonestaciones": {"nuevo": 0, "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "registrado_por": {"nuevo": 1, "anterior": null}, "minutos_jugados": {"nuevo": 40, "anterior": null}, "puntos_anotados": {"nuevo": 0, "anterior": null}, "id_partido_equipo": {"nuevo": 1, "anterior": null}, "id_jugador_partido": {"nuevo": 9, "anterior": null}, "fecha_actualizacion": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "id_jugador_inscripcion": {"nuevo": 4, "anterior": null}}	{amonestaciones,asistio,calificacion,convocado,estadisticas,expulsado,faltas,fecha_actualizacion,fecha_registro,id_jugador_inscripcion,id_jugador_partido,id_partido,id_partido_equipo,lesionado,minutos_jugados,observaciones,puntos_anotados,registrado_por,titular}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
114	competencia	jugador_partido	INSERT	{"id_jugador_partido": 10}	\N	{"faltas": 0, "asistio": true, "titular": true, "convocado": true, "expulsado": false, "lesionado": false, "id_partido": 1, "calificacion": 7.00, "estadisticas": {"goles": 0, "atajadas": 0, "asistencias": 0}, "observaciones": "Participacion registrada en el flujo demo", "amonestaciones": 0, "fecha_registro": "2026-07-22T01:40:15.937449-04:00", "registrado_por": 1, "minutos_jugados": 40, "puntos_anotados": 0, "id_partido_equipo": 1, "id_jugador_partido": 10, "fecha_actualizacion": "2026-07-22T01:40:15.937449-04:00", "id_jugador_inscripcion": 5}	{"faltas": {"nuevo": 0, "anterior": null}, "asistio": {"nuevo": true, "anterior": null}, "titular": {"nuevo": true, "anterior": null}, "convocado": {"nuevo": true, "anterior": null}, "expulsado": {"nuevo": false, "anterior": null}, "lesionado": {"nuevo": false, "anterior": null}, "id_partido": {"nuevo": 1, "anterior": null}, "calificacion": {"nuevo": 7.00, "anterior": null}, "estadisticas": {"nuevo": {"goles": 0, "atajadas": 0, "asistencias": 0}, "anterior": null}, "observaciones": {"nuevo": "Participacion registrada en el flujo demo", "anterior": null}, "amonestaciones": {"nuevo": 0, "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "registrado_por": {"nuevo": 1, "anterior": null}, "minutos_jugados": {"nuevo": 40, "anterior": null}, "puntos_anotados": {"nuevo": 0, "anterior": null}, "id_partido_equipo": {"nuevo": 1, "anterior": null}, "id_jugador_partido": {"nuevo": 10, "anterior": null}, "fecha_actualizacion": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "id_jugador_inscripcion": {"nuevo": 5, "anterior": null}}	{amonestaciones,asistio,calificacion,convocado,estadisticas,expulsado,faltas,fecha_actualizacion,fecha_registro,id_jugador_inscripcion,id_jugador_partido,id_partido,id_partido_equipo,lesionado,minutos_jugados,observaciones,puntos_anotados,registrado_por,titular}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
115	competencia	partido_equipo	UPDATE	{"id_partido_equipo": 1}	{"marcador": null, "id_partido": 1, "clasificado": false, "puntos_tabla": 0, "observaciones": null, "id_inscripcion": 1, "id_partido_equipo": 1, "marcador_desempate": null, "id_condicion_equipo": 1, "id_resultado_equipo_partido": 1}	{"marcador": 4, "id_partido": 1, "clasificado": false, "puntos_tabla": 0, "observaciones": null, "id_inscripcion": 1, "id_partido_equipo": 1, "marcador_desempate": null, "id_condicion_equipo": 1, "id_resultado_equipo_partido": 1}	{"marcador": {"nuevo": 4, "anterior": null}}	{marcador}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
116	competencia	partido_equipo	UPDATE	{"id_partido_equipo": 2}	{"marcador": null, "id_partido": 1, "clasificado": false, "puntos_tabla": 0, "observaciones": null, "id_inscripcion": 2, "id_partido_equipo": 2, "marcador_desempate": null, "id_condicion_equipo": 2, "id_resultado_equipo_partido": 1}	{"marcador": 3, "id_partido": 1, "clasificado": false, "puntos_tabla": 0, "observaciones": null, "id_inscripcion": 2, "id_partido_equipo": 2, "marcador_desempate": null, "id_condicion_equipo": 2, "id_resultado_equipo_partido": 1}	{"marcador": {"nuevo": 3, "anterior": null}}	{marcador}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
117	competencia	partido_equipo	UPDATE	{"id_partido_equipo": 1}	{"marcador": 4, "id_partido": 1, "clasificado": false, "puntos_tabla": 0, "observaciones": null, "id_inscripcion": 1, "id_partido_equipo": 1, "marcador_desempate": null, "id_condicion_equipo": 1, "id_resultado_equipo_partido": 1}	{"marcador": 4, "id_partido": 1, "clasificado": true, "puntos_tabla": 3, "observaciones": null, "id_inscripcion": 1, "id_partido_equipo": 1, "marcador_desempate": null, "id_condicion_equipo": 1, "id_resultado_equipo_partido": 2}	{"clasificado": {"nuevo": true, "anterior": false}, "puntos_tabla": {"nuevo": 3, "anterior": 0}, "id_resultado_equipo_partido": {"nuevo": 2, "anterior": 1}}	{clasificado,id_resultado_equipo_partido,puntos_tabla}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
118	competencia	partido_equipo	UPDATE	{"id_partido_equipo": 2}	{"marcador": 3, "id_partido": 1, "clasificado": false, "puntos_tabla": 0, "observaciones": null, "id_inscripcion": 2, "id_partido_equipo": 2, "marcador_desempate": null, "id_condicion_equipo": 2, "id_resultado_equipo_partido": 1}	{"marcador": 3, "id_partido": 1, "clasificado": false, "puntos_tabla": 0, "observaciones": null, "id_inscripcion": 2, "id_partido_equipo": 2, "marcador_desempate": null, "id_condicion_equipo": 2, "id_resultado_equipo_partido": 3}	{"id_resultado_equipo_partido": {"nuevo": 3, "anterior": 1}}	{id_resultado_equipo_partido}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
119	competencia	partido	UPDATE	{"id_partido": 1}	{"codigo": "FTS-DEMO-P001", "id_lugar": 1, "creado_por": 1, "id_jornada": 2, "id_partido": 1, "nombre_ronda": "Final", "observaciones": "Partido unico de la Copa Demo", "fecha_hora_fin": "2026-08-20T16:30:00-04:00", "fecha_registro": "2026-07-22T01:40:15.937449-04:00", "numero_partido": 1, "actualizado_por": 1, "id_grupo_torneo": null, "fecha_hora_inicio": "2026-08-20T15:00:00-04:00", "id_estado_partido": 3, "fecha_actualizacion": "2026-07-22T01:40:15.937449-04:00", "id_partido_siguiente": null}	{"codigo": "FTS-DEMO-P001", "id_lugar": 1, "creado_por": 1, "id_jornada": 2, "id_partido": 1, "nombre_ronda": "Final", "observaciones": "Titanes gana por cuatro goles contra tres", "fecha_hora_fin": "2026-08-20T16:30:00-04:00", "fecha_registro": "2026-07-22T01:40:15.937449-04:00", "numero_partido": 1, "actualizado_por": 1, "id_grupo_torneo": null, "fecha_hora_inicio": "2026-08-20T15:00:00-04:00", "id_estado_partido": 4, "fecha_actualizacion": "2026-07-22T01:40:15.937449-04:00", "id_partido_siguiente": null}	{"observaciones": {"nuevo": "Titanes gana por cuatro goles contra tres", "anterior": "Partido unico de la Copa Demo"}, "id_estado_partido": {"nuevo": 4, "anterior": 3}}	{id_estado_partido,observaciones}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
120	competencia	jornada	UPDATE	{"id_jornada": 2}	{"nombre": "Jornada final", "fecha_fin": "2026-08-20T18:00:00-04:00", "id_jornada": 2, "fecha_inicio": "2026-08-20T14:00:00-04:00", "observaciones": "Jornada del partido unico", "id_fase_torneo": 2, "numero_jornada": 1, "id_estado_jornada": 2}	{"nombre": "Jornada final", "fecha_fin": "2026-08-20T18:00:00-04:00", "id_jornada": 2, "fecha_inicio": "2026-08-20T14:00:00-04:00", "observaciones": "Jornada del partido unico", "id_fase_torneo": 2, "numero_jornada": 1, "id_estado_jornada": 3}	{"id_estado_jornada": {"nuevo": 3, "anterior": 2}}	{id_estado_jornada}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
121	competencia	fase_torneo	UPDATE	{"id_fase_torneo": 2}	{"nombre": "Final unica", "fecha_fin": "2026-08-20", "id_torneo": 3, "descripcion": "Fase compuesta por un solo partido", "fecha_inicio": "2026-08-20", "id_tipo_fase": 1, "numero_orden": 1, "id_estado_fase": 2, "id_fase_torneo": 2, "cantidad_clasificados": 1}	{"nombre": "Final unica", "fecha_fin": "2026-08-20", "id_torneo": 3, "descripcion": "Fase compuesta por un solo partido", "fecha_inicio": "2026-08-20", "id_tipo_fase": 1, "numero_orden": 1, "id_estado_fase": 3, "id_fase_torneo": 2, "cantidad_clasificados": 1}	{"id_estado_fase": {"nuevo": 3, "anterior": 2}}	{id_estado_fase}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
122	competencia	resultado_torneo	INSERT	{"id_resultado_torneo": 1}	\N	{"puntos": 3, "id_torneo": 3, "generado_por": 1, "observaciones": null, "id_inscripcion": 1, "marcador_favor": 4, "posicion_final": 1, "marcador_contra": 3, "fecha_generacion": "2026-07-22T01:40:15.937449-04:00", "partidos_ganados": 1, "partidos_jugados": 1, "partidos_perdidos": 0, "partidos_empatados": 0, "diferencia_marcador": 1, "id_resultado_torneo": 1}	{"puntos": {"nuevo": 3, "anterior": null}, "id_torneo": {"nuevo": 3, "anterior": null}, "generado_por": {"nuevo": 1, "anterior": null}, "observaciones": {"nuevo": null, "anterior": null}, "id_inscripcion": {"nuevo": 1, "anterior": null}, "marcador_favor": {"nuevo": 4, "anterior": null}, "posicion_final": {"nuevo": 1, "anterior": null}, "marcador_contra": {"nuevo": 3, "anterior": null}, "fecha_generacion": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "partidos_ganados": {"nuevo": 1, "anterior": null}, "partidos_jugados": {"nuevo": 1, "anterior": null}, "partidos_perdidos": {"nuevo": 0, "anterior": null}, "partidos_empatados": {"nuevo": 0, "anterior": null}, "diferencia_marcador": {"nuevo": 1, "anterior": null}, "id_resultado_torneo": {"nuevo": 1, "anterior": null}}	{diferencia_marcador,fecha_generacion,generado_por,id_inscripcion,id_resultado_torneo,id_torneo,marcador_contra,marcador_favor,observaciones,partidos_empatados,partidos_ganados,partidos_jugados,partidos_perdidos,posicion_final,puntos}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
123	competencia	resultado_torneo	INSERT	{"id_resultado_torneo": 2}	\N	{"puntos": 0, "id_torneo": 3, "generado_por": 1, "observaciones": null, "id_inscripcion": 2, "marcador_favor": 3, "posicion_final": 2, "marcador_contra": 4, "fecha_generacion": "2026-07-22T01:40:15.937449-04:00", "partidos_ganados": 0, "partidos_jugados": 1, "partidos_perdidos": 1, "partidos_empatados": 0, "diferencia_marcador": -1, "id_resultado_torneo": 2}	{"puntos": {"nuevo": 0, "anterior": null}, "id_torneo": {"nuevo": 3, "anterior": null}, "generado_por": {"nuevo": 1, "anterior": null}, "observaciones": {"nuevo": null, "anterior": null}, "id_inscripcion": {"nuevo": 2, "anterior": null}, "marcador_favor": {"nuevo": 3, "anterior": null}, "posicion_final": {"nuevo": 2, "anterior": null}, "marcador_contra": {"nuevo": 4, "anterior": null}, "fecha_generacion": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "partidos_ganados": {"nuevo": 0, "anterior": null}, "partidos_jugados": {"nuevo": 1, "anterior": null}, "partidos_perdidos": {"nuevo": 1, "anterior": null}, "partidos_empatados": {"nuevo": 0, "anterior": null}, "diferencia_marcador": {"nuevo": -1, "anterior": null}, "id_resultado_torneo": {"nuevo": 2, "anterior": null}}	{diferencia_marcador,fecha_generacion,generado_por,id_inscripcion,id_resultado_torneo,id_torneo,marcador_contra,marcador_favor,observaciones,partidos_empatados,partidos_ganados,partidos_jugados,partidos_perdidos,posicion_final,puntos}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
124	competencia	torneo	UPDATE	{"id_torneo": 3}	{"rama": "MASCULINO", "codigo": "FTS-DEMO-2026-01", "moneda": "BOB", "nombre": "Copa Demo de Futsal 2026", "edicion": "2026", "categoria": "Libre", "id_torneo": 3, "creado_por": 1, "id_deporte": 2, "descripcion": "Torneo de demostracion para probar el flujo completo", "fecha_registro": "2026-07-22T01:40:15.937449-04:00", "permite_empate": false, "fecha_fin_torneo": "2026-08-20", "id_estado_torneo": 5, "costo_inscripcion": 200.00, "id_formato_torneo": 1, "fecha_actualizacion": "2026-07-22T01:40:15.937449-04:00", "fecha_inicio_torneo": "2026-08-20", "fecha_fin_inscripcion": "2026-08-10", "cantidad_maxima_equipos": 2, "fecha_inicio_inscripcion": "2026-08-01", "cantidad_maxima_jugadores": 7, "cantidad_minima_jugadores": 5}	{"rama": "MASCULINO", "codigo": "FTS-DEMO-2026-01", "moneda": "BOB", "nombre": "Copa Demo de Futsal 2026", "edicion": "2026", "categoria": "Libre", "id_torneo": 3, "creado_por": 1, "id_deporte": 2, "descripcion": "Torneo de demostracion para probar el flujo completo", "fecha_registro": "2026-07-22T01:40:15.937449-04:00", "permite_empate": false, "fecha_fin_torneo": "2026-08-20", "id_estado_torneo": 6, "costo_inscripcion": 200.00, "id_formato_torneo": 1, "fecha_actualizacion": "2026-07-22T01:40:15.937449-04:00", "fecha_inicio_torneo": "2026-08-20", "fecha_fin_inscripcion": "2026-08-10", "cantidad_maxima_equipos": 2, "fecha_inicio_inscripcion": "2026-08-01", "cantidad_maxima_jugadores": 7, "cantidad_minima_jugadores": 5}	{"id_estado_torneo": {"nuevo": 6, "anterior": 5}}	{id_estado_torneo}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
125	finanzas	entrega_premio	INSERT	{"id_entrega_premio": 1}	\N	{"entregado_por": null, "fecha_entrega": null, "observaciones": "Entrega generada automaticamente", "autorizado_por": null, "fecha_registro": "2026-07-22T01:40:15.937449-04:00", "id_torneo_premio": 1, "id_entrega_premio": 1, "fecha_autorizacion": null, "fecha_actualizacion": "2026-07-22T01:40:15.937449-04:00", "id_resultado_torneo": 1, "id_estado_entrega_premio": 1}	{"entregado_por": {"nuevo": null, "anterior": null}, "fecha_entrega": {"nuevo": null, "anterior": null}, "observaciones": {"nuevo": "Entrega generada automaticamente", "anterior": null}, "autorizado_por": {"nuevo": null, "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "id_torneo_premio": {"nuevo": 1, "anterior": null}, "id_entrega_premio": {"nuevo": 1, "anterior": null}, "fecha_autorizacion": {"nuevo": null, "anterior": null}, "fecha_actualizacion": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "id_resultado_torneo": {"nuevo": 1, "anterior": null}, "id_estado_entrega_premio": {"nuevo": 1, "anterior": null}}	{autorizado_por,entregado_por,fecha_actualizacion,fecha_autorizacion,fecha_entrega,fecha_registro,id_entrega_premio,id_estado_entrega_premio,id_resultado_torneo,id_torneo_premio,observaciones}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
126	finanzas	entrega_premio	UPDATE	{"id_entrega_premio": 1}	{"entregado_por": null, "fecha_entrega": null, "observaciones": "Entrega generada automaticamente", "autorizado_por": null, "fecha_registro": "2026-07-22T01:40:15.937449-04:00", "id_torneo_premio": 1, "id_entrega_premio": 1, "fecha_autorizacion": null, "fecha_actualizacion": "2026-07-22T01:40:15.937449-04:00", "id_resultado_torneo": 1, "id_estado_entrega_premio": 1}	{"entregado_por": null, "fecha_entrega": null, "observaciones": "Premio autorizado en la demostracion", "autorizado_por": 1, "fecha_registro": "2026-07-22T01:40:15.937449-04:00", "id_torneo_premio": 1, "id_entrega_premio": 1, "fecha_autorizacion": "2026-07-22T01:40:15.937449-04:00", "fecha_actualizacion": "2026-07-22T01:40:15.937449-04:00", "id_resultado_torneo": 1, "id_estado_entrega_premio": 2}	{"observaciones": {"nuevo": "Premio autorizado en la demostracion", "anterior": "Entrega generada automaticamente"}, "autorizado_por": {"nuevo": 1, "anterior": null}, "fecha_autorizacion": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "id_estado_entrega_premio": {"nuevo": 2, "anterior": 1}}	{autorizado_por,fecha_autorizacion,id_estado_entrega_premio,observaciones}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
127	finanzas	entrega_premio	UPDATE	{"id_entrega_premio": 1}	{"entregado_por": null, "fecha_entrega": null, "observaciones": "Premio autorizado en la demostracion", "autorizado_por": 1, "fecha_registro": "2026-07-22T01:40:15.937449-04:00", "id_torneo_premio": 1, "id_entrega_premio": 1, "fecha_autorizacion": "2026-07-22T01:40:15.937449-04:00", "fecha_actualizacion": "2026-07-22T01:40:15.937449-04:00", "id_resultado_torneo": 1, "id_estado_entrega_premio": 2}	{"entregado_por": 1, "fecha_entrega": "2026-07-22T01:40:15.937449-04:00", "observaciones": "Premio entregado al delegado de Titanes", "autorizado_por": 1, "fecha_registro": "2026-07-22T01:40:15.937449-04:00", "id_torneo_premio": 1, "id_entrega_premio": 1, "fecha_autorizacion": "2026-07-22T01:40:15.937449-04:00", "fecha_actualizacion": "2026-07-22T01:40:15.937449-04:00", "id_resultado_torneo": 1, "id_estado_entrega_premio": 3}	{"entregado_por": {"nuevo": 1, "anterior": null}, "fecha_entrega": {"nuevo": "2026-07-22T01:40:15.937449-04:00", "anterior": null}, "observaciones": {"nuevo": "Premio entregado al delegado de Titanes", "anterior": "Premio autorizado en la demostracion"}, "id_estado_entrega_premio": {"nuevo": 3, "anterior": 2}}	{entregado_por,fecha_entrega,id_estado_entrega_premio,observaciones}	1	postgres	postgres	psql	127.0.0.1/32	\N	3587	17609	2026-07-22 01:40:15.937449-04
175	participantes	equipo	UPDATE	{"id_equipo": 6}	{"sigla": "CON", "nombre": "Condors Deportivos", "logo_url": null, "id_equipo": 6, "creado_por": 1, "descripcion": "Equipo actualizado mediante FastAPI", "fecha_registro": "2026-07-22T23:21:28.973548-04:00", "fecha_fundacion": "2024-03-15", "id_estado_equipo": 2, "fecha_actualizacion": "2026-07-22T23:21:28.973548-04:00"}	{"sigla": "CON", "nombre": "Condors Deportivos", "logo_url": null, "id_equipo": 6, "creado_por": 1, "descripcion": "Equipo actualizado mediante FastAPI", "fecha_registro": "2026-07-22T23:21:28.973548-04:00", "fecha_fundacion": "2024-03-15", "id_estado_equipo": 1, "fecha_actualizacion": "2026-07-22T23:21:28.973548-04:00"}	{"id_estado_equipo": {"nuevo": 1, "anterior": 2}}	{id_estado_equipo}	1	postgres	postgres	backend_torneos_fastapi	127.0.0.1	REACTIVAR-EQUIPO-DEMO-001	3618	7706	2026-07-22 23:24:56.576863-04
169	competencia	deporte	INSERT	{"id_deporte": 6}	\N	{"codigo": "BALONMANO_DEMO", "nombre": "Balonmano demo", "id_deporte": 6, "descripcion": "Deporte creado mediante FastAPI", "puntos_empate": 1, "tipo_marcador": "GOL", "fecha_registro": "2026-07-22T20:40:41.558204-04:00", "permite_empate": true, "puntos_derrota": 0, "puntos_victoria": 3, "id_estado_deporte": 1, "cantidad_titulares": 7, "cantidad_maxima_jugadores": 16, "cantidad_minima_jugadores": 7}	{"codigo": {"nuevo": "BALONMANO_DEMO", "anterior": null}, "nombre": {"nuevo": "Balonmano demo", "anterior": null}, "id_deporte": {"nuevo": 6, "anterior": null}, "descripcion": {"nuevo": "Deporte creado mediante FastAPI", "anterior": null}, "puntos_empate": {"nuevo": 1, "anterior": null}, "tipo_marcador": {"nuevo": "GOL", "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T20:40:41.558204-04:00", "anterior": null}, "permite_empate": {"nuevo": true, "anterior": null}, "puntos_derrota": {"nuevo": 0, "anterior": null}, "puntos_victoria": {"nuevo": 3, "anterior": null}, "id_estado_deporte": {"nuevo": 1, "anterior": null}, "cantidad_titulares": {"nuevo": 7, "anterior": null}, "cantidad_maxima_jugadores": {"nuevo": 16, "anterior": null}, "cantidad_minima_jugadores": {"nuevo": 7, "anterior": null}}	{cantidad_maxima_jugadores,cantidad_minima_jugadores,cantidad_titulares,codigo,descripcion,fecha_registro,id_deporte,id_estado_deporte,nombre,permite_empate,puntos_derrota,puntos_empate,puntos_victoria,tipo_marcador}	\N	postgres	postgres	backend_torneos_fastapi	127.0.0.1	CREAR-DEPORTE-DEMO-001	3607	5355	2026-07-22 20:40:41.558204-04
170	competencia	deporte	UPDATE	{"id_deporte": 6}	{"codigo": "BALONMANO_DEMO", "nombre": "Balonmano demo", "id_deporte": 6, "descripcion": "Deporte creado mediante FastAPI", "puntos_empate": 1, "tipo_marcador": "GOL", "fecha_registro": "2026-07-22T20:40:41.558204-04:00", "permite_empate": true, "puntos_derrota": 0, "puntos_victoria": 3, "id_estado_deporte": 1, "cantidad_titulares": 7, "cantidad_maxima_jugadores": 16, "cantidad_minima_jugadores": 7}	{"codigo": "BALONMANO_DEMO", "nombre": "Balonmano demo", "id_deporte": 6, "descripcion": "Deporte creado mediante FastAPI", "puntos_empate": 1, "tipo_marcador": "GOL", "fecha_registro": "2026-07-22T20:40:41.558204-04:00", "permite_empate": true, "puntos_derrota": 0, "puntos_victoria": 3, "id_estado_deporte": 2, "cantidad_titulares": 7, "cantidad_maxima_jugadores": 16, "cantidad_minima_jugadores": 7}	{"id_estado_deporte": {"nuevo": 2, "anterior": 1}}	{id_estado_deporte}	\N	postgres	postgres	backend_torneos_fastapi	127.0.0.1	DESACTIVAR-DEPORTE-DEMO-001	3612	6007	2026-07-22 20:48:29.41099-04
171	competencia	deporte	UPDATE	{"id_deporte": 6}	{"codigo": "BALONMANO_DEMO", "nombre": "Balonmano demo", "id_deporte": 6, "descripcion": "Deporte creado mediante FastAPI", "puntos_empate": 1, "tipo_marcador": "GOL", "fecha_registro": "2026-07-22T20:40:41.558204-04:00", "permite_empate": true, "puntos_derrota": 0, "puntos_victoria": 3, "id_estado_deporte": 2, "cantidad_titulares": 7, "cantidad_maxima_jugadores": 16, "cantidad_minima_jugadores": 7}	{"codigo": "BALONMANO_DEMO", "nombre": "Balonmano demo", "id_deporte": 6, "descripcion": "Deporte creado mediante FastAPI", "puntos_empate": 1, "tipo_marcador": "GOL", "fecha_registro": "2026-07-22T20:40:41.558204-04:00", "permite_empate": true, "puntos_derrota": 0, "puntos_victoria": 3, "id_estado_deporte": 1, "cantidad_titulares": 7, "cantidad_maxima_jugadores": 16, "cantidad_minima_jugadores": 7}	{"id_estado_deporte": {"nuevo": 1, "anterior": 2}}	{id_estado_deporte}	\N	postgres	postgres	backend_torneos_fastapi	127.0.0.1	8e883f46-0cb6-4c93-ab96-24413803d13c	3613	6007	2026-07-22 20:49:27.577416-04
172	participantes	equipo	INSERT	{"id_equipo": 6}	\N	{"sigla": "CON", "nombre": "Condors Universitarios", "logo_url": null, "id_equipo": 6, "creado_por": 1, "descripcion": "Equipo creado mediante FastAPI", "fecha_registro": "2026-07-22T23:21:28.973548-04:00", "fecha_fundacion": "2024-03-15", "id_estado_equipo": 1, "fecha_actualizacion": "2026-07-22T23:21:28.973548-04:00"}	{"sigla": {"nuevo": "CON", "anterior": null}, "nombre": {"nuevo": "Condors Universitarios", "anterior": null}, "logo_url": {"nuevo": null, "anterior": null}, "id_equipo": {"nuevo": 6, "anterior": null}, "creado_por": {"nuevo": 1, "anterior": null}, "descripcion": {"nuevo": "Equipo creado mediante FastAPI", "anterior": null}, "fecha_registro": {"nuevo": "2026-07-22T23:21:28.973548-04:00", "anterior": null}, "fecha_fundacion": {"nuevo": "2024-03-15", "anterior": null}, "id_estado_equipo": {"nuevo": 1, "anterior": null}, "fecha_actualizacion": {"nuevo": "2026-07-22T23:21:28.973548-04:00", "anterior": null}}	{creado_por,descripcion,fecha_actualizacion,fecha_fundacion,fecha_registro,id_equipo,id_estado_equipo,logo_url,nombre,sigla}	1	postgres	postgres	backend_torneos_fastapi	127.0.0.1	CREAR-EQUIPO-DEMO-001	3614	7706	2026-07-22 23:21:28.973548-04
173	participantes	equipo	UPDATE	{"id_equipo": 6}	{"sigla": "CON", "nombre": "Condors Universitarios", "logo_url": null, "id_equipo": 6, "creado_por": 1, "descripcion": "Equipo creado mediante FastAPI", "fecha_registro": "2026-07-22T23:21:28.973548-04:00", "fecha_fundacion": "2024-03-15", "id_estado_equipo": 1, "fecha_actualizacion": "2026-07-22T23:21:28.973548-04:00"}	{"sigla": "CON", "nombre": "Condors Deportivos", "logo_url": null, "id_equipo": 6, "creado_por": 1, "descripcion": "Equipo actualizado mediante FastAPI", "fecha_registro": "2026-07-22T23:21:28.973548-04:00", "fecha_fundacion": "2024-03-15", "id_estado_equipo": 1, "fecha_actualizacion": "2026-07-22T23:21:28.973548-04:00"}	{"nombre": {"nuevo": "Condors Deportivos", "anterior": "Condors Universitarios"}, "descripcion": {"nuevo": "Equipo actualizado mediante FastAPI", "anterior": "Equipo creado mediante FastAPI"}}	{descripcion,nombre}	1	postgres	postgres	backend_torneos_fastapi	127.0.0.1	ACTUALIZAR-EQUIPO-DEMO-001	3616	7706	2026-07-22 23:23:31.965595-04
174	participantes	equipo	UPDATE	{"id_equipo": 6}	{"sigla": "CON", "nombre": "Condors Deportivos", "logo_url": null, "id_equipo": 6, "creado_por": 1, "descripcion": "Equipo actualizado mediante FastAPI", "fecha_registro": "2026-07-22T23:21:28.973548-04:00", "fecha_fundacion": "2024-03-15", "id_estado_equipo": 1, "fecha_actualizacion": "2026-07-22T23:21:28.973548-04:00"}	{"sigla": "CON", "nombre": "Condors Deportivos", "logo_url": null, "id_equipo": 6, "creado_por": 1, "descripcion": "Equipo actualizado mediante FastAPI", "fecha_registro": "2026-07-22T23:21:28.973548-04:00", "fecha_fundacion": "2024-03-15", "id_estado_equipo": 2, "fecha_actualizacion": "2026-07-22T23:21:28.973548-04:00"}	{"id_estado_equipo": {"nuevo": 2, "anterior": 1}}	{id_estado_equipo}	1	postgres	postgres	backend_torneos_fastapi	127.0.0.1	DESACTIVAR-EQUIPO-DEMO-001	3617	7706	2026-07-22 23:24:36.793579-04
176	seguridad	usuario	UPDATE	{"id_usuario": 1}	{"sexo": "F", "zona": "Centro", "correo": "admin.demo@torneos.test", "nombres": "Andrea", "telefono": "76500001", "direccion": "Calle Demo 101", "id_usuario": 1, "ultimo_acceso": null, "fecha_registro": "2026-07-22T01:33:28.562517-04:00", "apellido_materno": "Mamani", "apellido_paterno": "Rojas", "fecha_nacimiento": "1995-03-10", "numero_documento": "7000001", "id_estado_usuario": 1, "id_tipo_documento": 1, "intentos_fallidos": 0, "fecha_actualizacion": "2026-07-22T01:33:28.562517-04:00"}	{"sexo": "F", "zona": "Centro", "correo": "admin.demo@torneos.test", "nombres": "Andrea", "telefono": "76500001", "direccion": "Calle Demo 101", "id_usuario": 1, "ultimo_acceso": "2026-07-23T00:53:52.357061-04:00", "fecha_registro": "2026-07-22T01:33:28.562517-04:00", "apellido_materno": "Mamani", "apellido_paterno": "Rojas", "fecha_nacimiento": "1995-03-10", "numero_documento": "7000001", "id_estado_usuario": 1, "id_tipo_documento": 1, "intentos_fallidos": 0, "fecha_actualizacion": "2026-07-22T01:33:28.562517-04:00"}	{"ultimo_acceso": {"nuevo": "2026-07-23T00:53:52.357061-04:00", "anterior": null}}	{ultimo_acceso}	1	postgres	postgres	backend_torneos_fastapi	127.0.0.1	9f3ed467-3aaa-4ff9-a0c5-719a686f0fc1	3620	24897	2026-07-23 00:53:52.357061-04
177	seguridad	usuario	UPDATE	{"id_usuario": 2}	{"sexo": "M", "zona": "Sopocachi", "correo": "organizador.demo@torneos.test", "nombres": "Marcos", "telefono": "76500002", "direccion": "Calle Demo 102", "id_usuario": 2, "ultimo_acceso": null, "fecha_registro": "2026-07-22T01:33:28.562517-04:00", "apellido_materno": "Flores", "apellido_paterno": "Quispe", "fecha_nacimiento": "1992-05-15", "numero_documento": "7000002", "id_estado_usuario": 1, "id_tipo_documento": 1, "intentos_fallidos": 0, "fecha_actualizacion": "2026-07-22T01:33:28.562517-04:00"}	{"sexo": "M", "zona": "Sopocachi", "correo": "organizador.demo@torneos.test", "nombres": "Marcos", "telefono": "76500002", "direccion": "Calle Demo 102", "id_usuario": 2, "ultimo_acceso": "2026-07-23T00:59:10.383698-04:00", "fecha_registro": "2026-07-22T01:33:28.562517-04:00", "apellido_materno": "Flores", "apellido_paterno": "Quispe", "fecha_nacimiento": "1992-05-15", "numero_documento": "7000002", "id_estado_usuario": 1, "id_tipo_documento": 1, "intentos_fallidos": 0, "fecha_actualizacion": "2026-07-22T01:33:28.562517-04:00"}	{"ultimo_acceso": {"nuevo": "2026-07-23T00:59:10.383698-04:00", "anterior": null}}	{ultimo_acceso}	2	postgres	postgres	backend_torneos_fastapi	127.0.0.1	8b8bfe02-d78e-479d-bcb5-465e64e0138b	3621	24897	2026-07-23 00:59:10.383698-04
\.


--
-- Data for Name: configuracion_auditoria; Type: TABLE DATA; Schema: auditoria; Owner: -
--

COPY auditoria.configuracion_auditoria (id_configuracion, esquema, tabla, columnas_pk, columnas_excluidas, auditar_insert, auditar_update, auditar_delete, activo, descripcion, fecha_registro) FROM stdin;
1	seguridad	usuario	{id_usuario}	{contrasenia_hash}	t	t	t	t	Auditoria de usuarios sin almacenar el hash de contrasenia	2026-07-22 01:12:37.539631-04
2	seguridad	rol	{id_rol}	{}	t	t	t	t	Auditoria de roles generales	2026-07-22 01:12:37.539631-04
3	seguridad	usuario_rol	{id_usuario_rol}	{}	t	t	t	t	Auditoria de roles asignados a usuarios	2026-07-22 01:12:37.539631-04
4	participantes	jugador	{id_usuario}	{}	t	t	t	t	Auditoria de perfiles de jugadores	2026-07-22 01:12:37.539631-04
5	participantes	arbitro	{id_usuario}	{}	t	t	t	t	Auditoria de perfiles de arbitros	2026-07-22 01:12:37.539631-04
6	participantes	organizador	{id_usuario}	{}	t	t	t	t	Auditoria de perfiles de organizadores	2026-07-22 01:12:37.539631-04
7	participantes	equipo	{id_equipo}	{}	t	t	t	t	Auditoria de equipos	2026-07-22 01:12:37.539631-04
8	participantes	jugador_equipo	{id_jugador_equipo}	{}	t	t	t	t	Auditoria del historial de jugadores en equipos	2026-07-22 01:12:37.539631-04
9	competencia	deporte	{id_deporte}	{}	t	t	t	t	Auditoria de deportes	2026-07-22 01:12:37.539631-04
10	competencia	regla	{id_regla}	{}	t	t	t	t	Auditoria de reglas	2026-07-22 01:12:37.539631-04
11	competencia	deporte_regla	{id_deporte_regla}	{}	t	t	t	t	Auditoria de reglas por deporte	2026-07-22 01:12:37.539631-04
12	competencia	lugar	{id_lugar}	{}	t	t	t	t	Auditoria de lugares	2026-07-22 01:12:37.539631-04
13	competencia	torneo	{id_torneo}	{}	t	t	t	t	Auditoria de torneos	2026-07-22 01:12:37.539631-04
14	competencia	torneo_regla	{id_torneo_regla}	{}	t	t	t	t	Auditoria de reglas de torneos	2026-07-22 01:12:37.539631-04
15	competencia	fase_torneo	{id_fase_torneo}	{}	t	t	t	t	Auditoria de fases	2026-07-22 01:12:37.539631-04
16	competencia	grupo_torneo	{id_grupo_torneo}	{}	t	t	t	t	Auditoria de grupos	2026-07-22 01:12:37.539631-04
17	competencia	jornada	{id_jornada}	{}	t	t	t	t	Auditoria de jornadas	2026-07-22 01:12:37.539631-04
18	competencia	usuario_torneo_rol	{id_usuario_torneo_rol}	{}	t	t	t	t	Auditoria de roles por torneo	2026-07-22 01:12:37.539631-04
19	competencia	inscripcion	{id_inscripcion}	{}	t	t	t	t	Auditoria de inscripciones	2026-07-22 01:12:37.539631-04
20	competencia	jugador_inscripcion	{id_jugador_inscripcion}	{}	t	t	t	t	Auditoria de nominas	2026-07-22 01:12:37.539631-04
21	competencia	equipo_grupo	{id_equipo_grupo}	{}	t	t	t	t	Auditoria de equipos asignados a grupos	2026-07-22 01:12:37.539631-04
22	competencia	partido	{id_partido}	{}	t	t	t	t	Auditoria de partidos	2026-07-22 01:12:37.539631-04
23	competencia	partido_equipo	{id_partido_equipo}	{}	t	t	t	t	Auditoria de equipos de partidos	2026-07-22 01:12:37.539631-04
24	competencia	arbitro_partido	{id_arbitro_partido}	{}	t	t	t	t	Auditoria de arbitros asignados	2026-07-22 01:12:37.539631-04
25	competencia	jugador_partido	{id_jugador_partido}	{}	t	t	t	t	Auditoria de asistencia y estadisticas	2026-07-22 01:12:37.539631-04
26	competencia	resultado_torneo	{id_resultado_torneo}	{}	t	t	t	t	Auditoria de resultados finales	2026-07-22 01:12:37.539631-04
27	finanzas	pago	{id_pago}	{}	t	t	t	t	Auditoria de pagos	2026-07-22 01:12:37.539631-04
28	finanzas	premio	{id_premio}	{}	t	t	t	t	Auditoria de premios	2026-07-22 01:12:37.539631-04
29	finanzas	torneo_premio	{id_torneo_premio}	{}	t	t	t	t	Auditoria de premios configurados por torneo	2026-07-22 01:12:37.539631-04
30	finanzas	entrega_premio	{id_entrega_premio}	{}	t	t	t	t	Auditoria de entregas de premios	2026-07-22 01:12:37.539631-04
\.


--
-- Data for Name: historial_entrega_premio; Type: TABLE DATA; Schema: auditoria; Owner: -
--

COPY auditoria.historial_entrega_premio (id_historial_entrega, id_entrega_premio, id_estado_anterior, id_estado_nuevo, operacion, usuario_aplicacion, usuario_postgresql, fecha_cambio, detalle) FROM stdin;
1	1	\N	1	INSERT	1	postgres	2026-07-22 01:40:15.937449-04	{"id_torneo_premio": 1, "id_resultado_torneo": 1}
2	1	1	2	UPDATE	1	postgres	2026-07-22 01:40:15.937449-04	{"fecha_entrega": null, "fecha_autorizacion": "2026-07-22T01:40:15.937449-04:00"}
3	1	2	3	UPDATE	1	postgres	2026-07-22 01:40:15.937449-04	{"fecha_entrega": "2026-07-22T01:40:15.937449-04:00", "fecha_autorizacion": "2026-07-22T01:40:15.937449-04:00"}
\.


--
-- Data for Name: historial_estado_inscripcion; Type: TABLE DATA; Schema: auditoria; Owner: -
--

COPY auditoria.historial_estado_inscripcion (id_historial_inscripcion, id_inscripcion, id_estado_anterior, id_estado_nuevo, operacion, usuario_aplicacion, usuario_postgresql, fecha_cambio, detalle) FROM stdin;
1	1	\N	1	INSERT	1	postgres	2026-07-22 01:40:15.937449-04	{"moneda": "BOB", "monto_requerido": 200.00}
2	2	\N	1	INSERT	1	postgres	2026-07-22 01:40:15.937449-04	{"moneda": "BOB", "monto_requerido": 200.00}
3	1	1	2	UPDATE	1	postgres	2026-07-22 01:40:15.937449-04	{"fecha_actualizacion": "2026-07-22T01:40:15.937449-04:00"}
4	1	2	3	UPDATE	1	postgres	2026-07-22 01:40:15.937449-04	{"fecha_actualizacion": "2026-07-22T01:40:15.937449-04:00"}
5	2	1	3	UPDATE	1	postgres	2026-07-22 01:40:15.937449-04	{"fecha_actualizacion": "2026-07-22T01:40:15.937449-04:00"}
\.


--
-- Data for Name: historial_estado_pago; Type: TABLE DATA; Schema: auditoria; Owner: -
--

COPY auditoria.historial_estado_pago (id_historial_pago, id_pago, id_estado_anterior, id_estado_nuevo, operacion, usuario_aplicacion, usuario_postgresql, fecha_cambio, detalle) FROM stdin;
1	1	\N	2	INSERT	1	postgres	2026-07-22 01:40:15.937449-04	{"monto": 100.00, "moneda": "BOB", "referencia": "DEMO-TIT-001"}
2	2	\N	2	INSERT	1	postgres	2026-07-22 01:40:15.937449-04	{"monto": 100.00, "moneda": "BOB", "referencia": "DEMO-TIT-002"}
3	3	\N	2	INSERT	1	postgres	2026-07-22 01:40:15.937449-04	{"monto": 200.00, "moneda": "BOB", "referencia": "DEMO-HAL-001"}
\.


--
-- Data for Name: historial_estado_partido; Type: TABLE DATA; Schema: auditoria; Owner: -
--

COPY auditoria.historial_estado_partido (id_historial_partido, id_partido, id_estado_anterior, id_estado_nuevo, operacion, usuario_aplicacion, usuario_postgresql, fecha_cambio, detalle) FROM stdin;
1	1	\N	1	INSERT	1	postgres	2026-07-22 01:40:15.937449-04	{"codigo": "FTS-DEMO-P001", "equipos": [], "fecha_hora_fin": "2026-08-20T16:30:00-04:00", "fecha_hora_inicio": "2026-08-20T15:00:00-04:00"}
2	1	1	2	UPDATE	1	postgres	2026-07-22 01:40:15.937449-04	{"equipos": [{"marcador": null, "clasificado": false, "puntos_tabla": 0, "id_inscripcion": 1, "id_partido_equipo": 1, "marcador_desempate": null}, {"marcador": null, "clasificado": false, "puntos_tabla": 0, "id_inscripcion": 2, "id_partido_equipo": 2, "marcador_desempate": null}], "fecha_hora_fin": "2026-08-20T16:30:00-04:00", "fecha_hora_inicio": "2026-08-20T15:00:00-04:00"}
3	1	2	3	UPDATE	1	postgres	2026-07-22 01:40:15.937449-04	{"equipos": [{"marcador": null, "clasificado": false, "puntos_tabla": 0, "id_inscripcion": 1, "id_partido_equipo": 1, "marcador_desempate": null}, {"marcador": null, "clasificado": false, "puntos_tabla": 0, "id_inscripcion": 2, "id_partido_equipo": 2, "marcador_desempate": null}], "fecha_hora_fin": "2026-08-20T16:30:00-04:00", "fecha_hora_inicio": "2026-08-20T15:00:00-04:00"}
4	1	3	4	UPDATE	1	postgres	2026-07-22 01:40:15.937449-04	{"equipos": [{"marcador": 4, "clasificado": true, "puntos_tabla": 3, "id_inscripcion": 1, "id_partido_equipo": 1, "marcador_desempate": null}, {"marcador": 3, "clasificado": false, "puntos_tabla": 0, "id_inscripcion": 2, "id_partido_equipo": 2, "marcador_desempate": null}], "fecha_hora_fin": "2026-08-20T16:30:00-04:00", "fecha_hora_inicio": "2026-08-20T15:00:00-04:00"}
\.


--
-- Data for Name: condicion_equipo_partido; Type: TABLE DATA; Schema: catalogo; Owner: -
--

COPY catalogo.condicion_equipo_partido (id_condicion_equipo, codigo, nombre, descripcion, activo) FROM stdin;
1	LOCAL	Local	Equipo registrado como local para el enfrentamiento	t
2	VISITANTE	Visitante	Equipo registrado como visitante para el enfrentamiento	t
\.


--
-- Data for Name: conflicto_rol_torneo; Type: TABLE DATA; Schema: catalogo; Owner: -
--

COPY catalogo.conflicto_rol_torneo (id_conflicto, id_rol_torneo_a, id_rol_torneo_b, motivo) FROM stdin;
1	1	2	Un jugador no puede arbitrar el mismo torneo
2	2	3	Un arbitro debe ser ajeno a la organizacion del torneo
3	1	3	Un jugador no puede organizar el mismo torneo
\.


--
-- Data for Name: estado_deporte; Type: TABLE DATA; Schema: catalogo; Owner: -
--

COPY catalogo.estado_deporte (id_estado_deporte, codigo, nombre, descripcion, activo) FROM stdin;
1	ACTIVO	Activo	El deporte esta disponible para crear torneos	t
2	INACTIVO	Inactivo	El deporte no esta disponible temporalmente	t
\.


--
-- Data for Name: estado_entrega_premio; Type: TABLE DATA; Schema: catalogo; Owner: -
--

COPY catalogo.estado_entrega_premio (id_estado_entrega_premio, codigo, nombre, descripcion, activo) FROM stdin;
1	PENDIENTE	Pendiente	La entrega fue generada pero todavia no fue autorizada	t
2	AUTORIZADO	Autorizado	La entrega fue aprobada por un usuario responsable	t
3	ENTREGADO	Entregado	El premio fue entregado al equipo correspondiente	t
4	ANULADO	Anulado	La entrega fue anulada	t
\.


--
-- Data for Name: estado_equipo; Type: TABLE DATA; Schema: catalogo; Owner: -
--

COPY catalogo.estado_equipo (id_estado_equipo, codigo, nombre, descripcion, activo) FROM stdin;
1	ACTIVO	Activo	El equipo se encuentra habilitado	t
2	INACTIVO	Inactivo	El equipo no se encuentra participando	t
3	SUSPENDIDO	Suspendido	El equipo fue suspendido temporalmente	t
\.


--
-- Data for Name: estado_fase; Type: TABLE DATA; Schema: catalogo; Owner: -
--

COPY catalogo.estado_fase (id_estado_fase, codigo, nombre, descripcion, activo) FROM stdin;
1	PENDIENTE	Pendiente	La fase todavia no inicio	t
2	EN_CURSO	En curso	La fase se encuentra en desarrollo	t
3	FINALIZADA	Finalizada	La fase concluyo	t
4	CANCELADA	Cancelada	La fase fue cancelada	t
\.


--
-- Data for Name: estado_inscripcion; Type: TABLE DATA; Schema: catalogo; Owner: -
--

COPY catalogo.estado_inscripcion (id_estado_inscripcion, codigo, nombre, descripcion, activo) FROM stdin;
1	PENDIENTE	Pendiente	La inscripcion fue registrada pero aun no tiene pagos confirmados	t
2	PAGO_PENDIENTE	Pago pendiente	La inscripcion tiene un pago parcial confirmado	t
3	HABILITADA	Habilitada	La inscripcion completo el pago requerido	t
4	RECHAZADA	Rechazada	La inscripcion fue rechazada por la organizacion	t
5	RETIRADA	Retirada	El equipo retiro voluntariamente su inscripcion	t
\.


--
-- Data for Name: estado_jornada; Type: TABLE DATA; Schema: catalogo; Owner: -
--

COPY catalogo.estado_jornada (id_estado_jornada, codigo, nombre, descripcion, activo) FROM stdin;
1	PROGRAMADA	Programada	La jornada se encuentra programada	t
2	EN_CURSO	En curso	La jornada se encuentra en desarrollo	t
3	FINALIZADA	Finalizada	La jornada concluyo	t
4	SUSPENDIDA	Suspendida	La jornada fue suspendida	t
5	CANCELADA	Cancelada	La jornada fue cancelada	t
\.


--
-- Data for Name: estado_jugador_inscripcion; Type: TABLE DATA; Schema: catalogo; Owner: -
--

COPY catalogo.estado_jugador_inscripcion (id_estado_jugador_inscripcion, codigo, nombre, descripcion, activo) FROM stdin;
1	HABILITADO	Habilitado	El jugador puede participar en el torneo	t
2	SUSPENDIDO	Suspendido	El jugador se encuentra suspendido temporalmente	t
3	RETIRADO	Retirado	El jugador fue retirado de la nomina	t
\.


--
-- Data for Name: estado_membresia; Type: TABLE DATA; Schema: catalogo; Owner: -
--

COPY catalogo.estado_membresia (id_estado_membresia, codigo, nombre, descripcion, activo) FROM stdin;
1	ACTIVA	Activa	El jugador pertenece actualmente al equipo	t
2	FINALIZADA	Finalizada	La pertenencia del jugador al equipo termino	t
3	SUSPENDIDA	Suspendida	La membresia fue suspendida temporalmente	t
\.


--
-- Data for Name: estado_pago; Type: TABLE DATA; Schema: catalogo; Owner: -
--

COPY catalogo.estado_pago (id_estado_pago, codigo, nombre, descripcion, activo) FROM stdin;
1	PENDIENTE	Pendiente	El pago fue registrado pero aun no fue verificado	t
2	CONFIRMADO	Confirmado	El pago fue verificado correctamente	t
3	RECHAZADO	Rechazado	El pago no fue aceptado	t
4	ANULADO	Anulado	El pago fue anulado antes de su confirmacion	t
\.


--
-- Data for Name: estado_partido; Type: TABLE DATA; Schema: catalogo; Owner: -
--

COPY catalogo.estado_partido (id_estado_partido, codigo, nombre, descripcion, activo) FROM stdin;
1	BORRADOR	Borrador	El partido se encuentra en configuracion	t
2	PROGRAMADO	Programado	El partido tiene equipos, fecha y lugar definidos	t
3	EN_CURSO	En curso	El partido se encuentra en desarrollo	t
4	FINALIZADO	Finalizado	El partido concluyo y tiene resultado definitivo	t
5	SUSPENDIDO	Suspendido	El partido fue suspendido temporalmente	t
6	CANCELADO	Cancelado	El partido fue cancelado	t
\.


--
-- Data for Name: estado_perfil_deportivo; Type: TABLE DATA; Schema: catalogo; Owner: -
--

COPY catalogo.estado_perfil_deportivo (id_estado_perfil, codigo, nombre, descripcion, activo) FROM stdin;
1	ACTIVO	Activo	El perfil deportivo se encuentra habilitado	t
2	INACTIVO	Inactivo	El perfil deportivo no se encuentra habilitado	t
3	SUSPENDIDO	Suspendido	El perfil fue suspendido temporalmente	t
\.


--
-- Data for Name: estado_torneo; Type: TABLE DATA; Schema: catalogo; Owner: -
--

COPY catalogo.estado_torneo (id_estado_torneo, codigo, nombre, descripcion, activo) FROM stdin;
1	BORRADOR	Borrador	El torneo se encuentra en configuracion	t
2	INSCRIPCIONES_ABIERTAS	Inscripciones abiertas	Los equipos pueden solicitar su inscripcion	t
3	INSCRIPCIONES_CERRADAS	Inscripciones cerradas	Ya no se reciben nuevas inscripciones	t
4	PROGRAMADO	Programado	El torneo esta preparado para iniciar	t
5	EN_CURSO	En curso	El torneo se encuentra en desarrollo	t
6	FINALIZADO	Finalizado	El torneo concluyo correctamente	t
7	CANCELADO	Cancelado	El torneo fue cancelado	t
\.


--
-- Data for Name: estado_usuario; Type: TABLE DATA; Schema: catalogo; Owner: -
--

COPY catalogo.estado_usuario (id_estado_usuario, codigo, nombre, descripcion, activo) FROM stdin;
1	ACTIVO	Activo	El usuario puede ingresar y utilizar el sistema	t
2	INACTIVO	Inactivo	La cuenta fue desactivada de manera administrativa	t
3	BLOQUEADO	Bloqueado	La cuenta fue bloqueada por seguridad	t
\.


--
-- Data for Name: formato_torneo; Type: TABLE DATA; Schema: catalogo; Owner: -
--

COPY catalogo.formato_torneo (id_formato_torneo, codigo, nombre, descripcion, activo) FROM stdin;
1	PARTIDO_UNICO	Partido unico	Torneo compuesto por un solo enfrentamiento	t
2	FASE_GRUPOS	Fase de grupos	Torneo compuesto solamente por grupos	t
3	ELIMINACION_DIRECTA	Eliminacion directa	Torneo desarrollado mediante llaves eliminatorias	t
4	GRUPOS_Y_LLAVES	Grupos y llaves	Torneo con fase de grupos y eliminacion directa	t
\.


--
-- Data for Name: metodo_pago; Type: TABLE DATA; Schema: catalogo; Owner: -
--

COPY catalogo.metodo_pago (id_metodo_pago, codigo, nombre, descripcion, activo) FROM stdin;
1	EFECTIVO	Efectivo	Pago registrado en efectivo	t
2	TRANSFERENCIA	Transferencia bancaria	Pago mediante transferencia bancaria	t
3	QR	Pago QR	Pago realizado mediante codigo QR	t
4	DEPOSITO	Deposito bancario	Pago realizado mediante deposito	t
5	OTRO	Otro metodo	Metodo diferente a los registrados	t
\.


--
-- Data for Name: resultado_equipo_partido; Type: TABLE DATA; Schema: catalogo; Owner: -
--

COPY catalogo.resultado_equipo_partido (id_resultado_equipo_partido, codigo, nombre, descripcion, activo) FROM stdin;
1	PENDIENTE	Pendiente	El partido todavia no tiene un resultado definitivo	t
2	GANADOR	Ganador	El equipo gano el partido	t
3	PERDEDOR	Perdedor	El equipo perdio el partido	t
4	EMPATE	Empate	El equipo empato el partido	t
\.


--
-- Data for Name: rol_torneo; Type: TABLE DATA; Schema: catalogo; Owner: -
--

COPY catalogo.rol_torneo (id_rol_torneo, codigo, nombre, descripcion, activo) FROM stdin;
1	JUGADOR	Jugador	Participa como jugador dentro del torneo	t
2	ARBITRO	Arbitro	Puede dirigir partidos del torneo	t
3	ORGANIZADOR	Organizador	Administra la organizacion del torneo	t
\.


--
-- Data for Name: tipo_arbitro_partido; Type: TABLE DATA; Schema: catalogo; Owner: -
--

COPY catalogo.tipo_arbitro_partido (id_tipo_arbitro_partido, codigo, nombre, descripcion, activo) FROM stdin;
1	PRINCIPAL	Arbitro principal	Responsable principal de dirigir el partido	t
2	ASISTENTE_1	Primer asistente	Primer arbitro asistente	t
3	ASISTENTE_2	Segundo asistente	Segundo arbitro asistente	t
4	MESA	Arbitro de mesa	Responsable del control de mesa o planilla	t
\.


--
-- Data for Name: tipo_documento; Type: TABLE DATA; Schema: catalogo; Owner: -
--

COPY catalogo.tipo_documento (id_tipo_documento, codigo, nombre, descripcion, activo) FROM stdin;
1	CI	Cedula de identidad	Documento de identidad nacional	t
2	PASAPORTE	Pasaporte	Documento internacional de identificacion	t
3	OTRO	Otro documento	Documento diferente a CI o pasaporte	t
\.


--
-- Data for Name: tipo_fase; Type: TABLE DATA; Schema: catalogo; Owner: -
--

COPY catalogo.tipo_fase (id_tipo_fase, codigo, nombre, descripcion, activo) FROM stdin;
1	PARTIDO_UNICO	Partido unico	Fase con un unico enfrentamiento	t
2	GRUPOS	Grupos	Fase de competencia organizada por grupos	t
3	ELIMINACION	Eliminacion	Fase compuesta por llaves eliminatorias	t
4	FINAL	Final	Fase final del torneo	t
\.


--
-- Data for Name: tipo_premio; Type: TABLE DATA; Schema: catalogo; Owner: -
--

COPY catalogo.tipo_premio (id_tipo_premio, codigo, nombre, descripcion, activo) FROM stdin;
1	ECONOMICO	Premio economico	Premio representado por una cantidad monetaria	t
2	TROFEO	Trofeo	Trofeo fisico entregado al equipo ganador	t
3	MEDALLA	Medalla	Medallas entregadas a los integrantes del equipo	t
4	RECONOCIMIENTO	Reconocimiento	Diploma, certificado u otro reconocimiento	t
5	OTRO	Otro premio	Premio diferente a los tipos registrados	t
\.


--
-- Data for Name: arbitro_partido; Type: TABLE DATA; Schema: competencia; Owner: -
--

COPY competencia.arbitro_partido (id_arbitro_partido, id_partido, id_arbitro, id_tipo_arbitro_partido, activo, asignado_por, fecha_asignacion, fecha_fin, observaciones) FROM stdin;
1	1	3	1	t	1	2026-07-22 01:40:15.937449-04	\N	Arbitro principal del partido demo
\.


--
-- Data for Name: deporte; Type: TABLE DATA; Schema: competencia; Owner: -
--

COPY competencia.deporte (id_deporte, codigo, nombre, descripcion, cantidad_minima_jugadores, cantidad_maxima_jugadores, cantidad_titulares, tipo_marcador, permite_empate, puntos_victoria, puntos_empate, puntos_derrota, id_estado_deporte, fecha_registro) FROM stdin;
1	FUTBOL	Futbol	Competencia de futbol por equipos	11	25	11	GOL	t	3	1	0	1	2026-07-22 00:23:31.972681-04
2	FUTSAL	Futsal	Competencia de futsal por equipos	5	14	5	GOL	t	3	1	0	1	2026-07-22 00:23:31.972681-04
3	BALONCESTO	Baloncesto	Competencia de baloncesto por equipos	5	15	5	PUNTO	f	2	0	1	1	2026-07-22 00:23:31.972681-04
4	VOLEIBOL	Voleibol	Competencia de voleibol por equipos	6	14	6	SET	f	3	0	0	1	2026-07-22 00:23:31.972681-04
5	TENIS_EQUIPOS	Tenis por equipos	Competencia de tenis organizada mediante equipos	2	10	2	PARTIDO	f	1	0	0	1	2026-07-22 00:23:31.972681-04
6	BALONMANO_DEMO	Balonmano demo	Deporte creado mediante FastAPI	7	16	7	GOL	t	3	1	0	1	2026-07-22 20:40:41.558204-04
\.


--
-- Data for Name: deporte_regla; Type: TABLE DATA; Schema: competencia; Owner: -
--

COPY competencia.deporte_regla (id_deporte_regla, id_deporte, id_regla, valor_configurado, obligatorio, activo, fecha_inicio, fecha_fin) FROM stdin;
\.


--
-- Data for Name: equipo_grupo; Type: TABLE DATA; Schema: competencia; Owner: -
--

COPY competencia.equipo_grupo (id_equipo_grupo, id_fase_torneo, id_grupo_torneo, id_inscripcion, posicion_sorteo, asignado_por, fecha_asignacion, observaciones) FROM stdin;
\.


--
-- Data for Name: fase_torneo; Type: TABLE DATA; Schema: competencia; Owner: -
--

COPY competencia.fase_torneo (id_fase_torneo, id_torneo, id_tipo_fase, id_estado_fase, nombre, numero_orden, cantidad_clasificados, fecha_inicio, fecha_fin, descripcion) FROM stdin;
2	3	1	3	Final unica	1	1	2026-08-20	2026-08-20	Fase compuesta por un solo partido
\.


--
-- Data for Name: grupo_torneo; Type: TABLE DATA; Schema: competencia; Owner: -
--

COPY competencia.grupo_torneo (id_grupo_torneo, id_fase_torneo, codigo, nombre, cantidad_maxima_equipos, cantidad_clasificados) FROM stdin;
\.


--
-- Data for Name: inscripcion; Type: TABLE DATA; Schema: competencia; Owner: -
--

COPY competencia.inscripcion (id_inscripcion, id_torneo, id_equipo, id_estado_inscripcion, monto_requerido, moneda, fecha_inscripcion, fecha_actualizacion, registrado_por, observaciones) FROM stdin;
1	3	1	3	200.00	BOB	2026-07-22 01:40:15.937449-04	2026-07-22 01:40:15.937449-04	1	Inscripcion de Titanes Futsal
2	3	2	3	200.00	BOB	2026-07-22 01:40:15.937449-04	2026-07-22 01:40:15.937449-04	1	Inscripcion de Halcones Futsal
\.


--
-- Data for Name: jornada; Type: TABLE DATA; Schema: competencia; Owner: -
--

COPY competencia.jornada (id_jornada, id_fase_torneo, id_estado_jornada, numero_jornada, nombre, fecha_inicio, fecha_fin, observaciones) FROM stdin;
2	2	3	1	Jornada final	2026-08-20 14:00:00-04	2026-08-20 18:00:00-04	Jornada del partido unico
\.


--
-- Data for Name: jugador_inscripcion; Type: TABLE DATA; Schema: competencia; Owner: -
--

COPY competencia.jugador_inscripcion (id_jugador_inscripcion, id_inscripcion, id_jugador, id_jugador_equipo, id_estado_jugador_inscripcion, numero_camiseta, es_capitan, es_delegado, fecha_registro, fecha_baja, registrado_por, observaciones) FROM stdin;
1	1	4	5	1	1	t	t	2026-07-22 01:40:15.937449-04	\N	1	Jugador titular de Titanes
2	1	5	4	1	4	f	f	2026-07-22 01:40:15.937449-04	\N	1	Jugador titular de Titanes
3	1	6	3	1	7	f	f	2026-07-22 01:40:15.937449-04	\N	1	Jugador titular de Titanes
4	1	7	2	1	9	f	f	2026-07-22 01:40:15.937449-04	\N	1	Jugador titular de Titanes
5	1	8	1	1	10	f	f	2026-07-22 01:40:15.937449-04	\N	1	Jugador titular de Titanes
6	2	9	10	1	1	t	t	2026-07-22 01:40:15.937449-04	\N	1	Jugador titular de Halcones
7	2	10	9	1	3	f	f	2026-07-22 01:40:15.937449-04	\N	1	Jugador titular de Halcones
8	2	11	8	1	6	f	f	2026-07-22 01:40:15.937449-04	\N	1	Jugador titular de Halcones
9	2	12	7	1	8	f	f	2026-07-22 01:40:15.937449-04	\N	1	Jugador titular de Halcones
10	2	13	6	1	11	f	f	2026-07-22 01:40:15.937449-04	\N	1	Jugador titular de Halcones
\.


--
-- Data for Name: jugador_partido; Type: TABLE DATA; Schema: competencia; Owner: -
--

COPY competencia.jugador_partido (id_jugador_partido, id_partido, id_partido_equipo, id_jugador_inscripcion, convocado, asistio, titular, minutos_jugados, puntos_anotados, faltas, amonestaciones, expulsado, lesionado, calificacion, estadisticas, registrado_por, fecha_registro, fecha_actualizacion, observaciones) FROM stdin;
1	1	2	6	t	t	t	40	2	0	0	f	f	9.00	{"goles": 2, "atajadas": 5, "asistencias": 1}	1	2026-07-22 01:40:15.937449-04	2026-07-22 01:40:15.937449-04	Participacion registrada en el flujo demo
2	1	2	7	t	t	t	40	1	0	0	f	f	8.00	{"goles": 1, "atajadas": 0, "asistencias": 1}	1	2026-07-22 01:40:15.937449-04	2026-07-22 01:40:15.937449-04	Participacion registrada en el flujo demo
3	1	2	8	t	t	t	40	0	0	0	f	f	7.00	{"goles": 0, "atajadas": 0, "asistencias": 0}	1	2026-07-22 01:40:15.937449-04	2026-07-22 01:40:15.937449-04	Participacion registrada en el flujo demo
4	1	2	9	t	t	t	40	0	1	0	f	f	7.00	{"goles": 0, "atajadas": 0, "asistencias": 0}	1	2026-07-22 01:40:15.937449-04	2026-07-22 01:40:15.937449-04	Participacion registrada en el flujo demo
5	1	2	10	t	t	t	40	0	0	0	f	f	7.00	{"goles": 0, "atajadas": 0, "asistencias": 0}	1	2026-07-22 01:40:15.937449-04	2026-07-22 01:40:15.937449-04	Participacion registrada en el flujo demo
6	1	1	1	t	t	t	40	2	0	0	f	f	9.00	{"goles": 2, "atajadas": 5, "asistencias": 1}	1	2026-07-22 01:40:15.937449-04	2026-07-22 01:40:15.937449-04	Participacion registrada en el flujo demo
7	1	1	2	t	t	t	40	1	0	0	f	f	8.00	{"goles": 1, "atajadas": 0, "asistencias": 1}	1	2026-07-22 01:40:15.937449-04	2026-07-22 01:40:15.937449-04	Participacion registrada en el flujo demo
8	1	1	3	t	t	t	40	1	0	0	f	f	8.00	{"goles": 1, "atajadas": 0, "asistencias": 0}	1	2026-07-22 01:40:15.937449-04	2026-07-22 01:40:15.937449-04	Participacion registrada en el flujo demo
9	1	1	4	t	t	t	40	0	1	0	f	f	7.00	{"goles": 0, "atajadas": 0, "asistencias": 0}	1	2026-07-22 01:40:15.937449-04	2026-07-22 01:40:15.937449-04	Participacion registrada en el flujo demo
10	1	1	5	t	t	t	40	0	0	0	f	f	7.00	{"goles": 0, "atajadas": 0, "asistencias": 0}	1	2026-07-22 01:40:15.937449-04	2026-07-22 01:40:15.937449-04	Participacion registrada en el flujo demo
\.


--
-- Data for Name: lugar; Type: TABLE DATA; Schema: competencia; Owner: -
--

COPY competencia.lugar (id_lugar, nombre, direccion, zona, ciudad, capacidad, tipo_superficie, activo, fecha_registro) FROM stdin;
1	Coliseo Demo Central	Avenida Deportiva 500	Centro	La Paz	800	Parquet	t	2026-07-22 01:33:28.562517-04
\.


--
-- Data for Name: partido; Type: TABLE DATA; Schema: competencia; Owner: -
--

COPY competencia.partido (id_partido, id_jornada, id_grupo_torneo, id_lugar, id_estado_partido, codigo, numero_partido, nombre_ronda, fecha_hora_inicio, fecha_hora_fin, id_partido_siguiente, creado_por, actualizado_por, observaciones, fecha_registro, fecha_actualizacion) FROM stdin;
1	2	\N	1	4	FTS-DEMO-P001	1	Final	2026-08-20 15:00:00-04	2026-08-20 16:30:00-04	\N	1	1	Titanes gana por cuatro goles contra tres	2026-07-22 01:40:15.937449-04	2026-07-22 01:40:15.937449-04
\.


--
-- Data for Name: partido_equipo; Type: TABLE DATA; Schema: competencia; Owner: -
--

COPY competencia.partido_equipo (id_partido_equipo, id_partido, id_inscripcion, id_condicion_equipo, id_resultado_equipo_partido, marcador, marcador_desempate, puntos_tabla, clasificado, observaciones) FROM stdin;
1	1	1	1	2	4	\N	3	t	\N
2	1	2	2	3	3	\N	0	f	\N
\.


--
-- Data for Name: regla; Type: TABLE DATA; Schema: competencia; Owner: -
--

COPY competencia.regla (id_regla, codigo, nombre, descripcion, categoria, activo, fecha_registro) FROM stdin;
\.


--
-- Data for Name: resultado_torneo; Type: TABLE DATA; Schema: competencia; Owner: -
--

COPY competencia.resultado_torneo (id_resultado_torneo, id_torneo, id_inscripcion, posicion_final, partidos_jugados, partidos_ganados, partidos_empatados, partidos_perdidos, marcador_favor, marcador_contra, diferencia_marcador, puntos, generado_por, fecha_generacion, observaciones) FROM stdin;
1	3	1	1	1	1	0	0	4	3	1	3	1	2026-07-22 01:40:15.937449-04	\N
2	3	2	2	1	0	0	1	3	4	-1	0	1	2026-07-22 01:40:15.937449-04	\N
\.


--
-- Data for Name: torneo; Type: TABLE DATA; Schema: competencia; Owner: -
--

COPY competencia.torneo (id_torneo, id_deporte, id_formato_torneo, id_estado_torneo, codigo, nombre, edicion, categoria, rama, fecha_inicio_inscripcion, fecha_fin_inscripcion, fecha_inicio_torneo, fecha_fin_torneo, cantidad_maxima_equipos, cantidad_minima_jugadores, cantidad_maxima_jugadores, costo_inscripcion, moneda, permite_empate, descripcion, creado_por, fecha_registro, fecha_actualizacion) FROM stdin;
3	2	1	6	FTS-DEMO-2026-01	Copa Demo de Futsal 2026	2026	Libre	MASCULINO	2026-08-01	2026-08-10	2026-08-20	2026-08-20	2	5	7	200.00	BOB	f	Torneo de demostracion para probar el flujo completo	1	2026-07-22 01:40:15.937449-04	2026-07-22 01:40:15.937449-04
\.


--
-- Data for Name: torneo_regla; Type: TABLE DATA; Schema: competencia; Owner: -
--

COPY competencia.torneo_regla (id_torneo_regla, id_torneo, id_regla, valor_configurado, obligatorio, activo, fecha_registro) FROM stdin;
\.


--
-- Data for Name: usuario_torneo_rol; Type: TABLE DATA; Schema: competencia; Owner: -
--

COPY competencia.usuario_torneo_rol (id_usuario_torneo_rol, id_torneo, id_usuario, id_rol_torneo, fecha_asignacion, fecha_fin, activo, asignado_por) FROM stdin;
1	3	2	3	2026-07-22 01:40:15.937449-04	\N	t	1
2	3	3	2	2026-07-22 01:40:15.937449-04	\N	t	1
3	3	4	1	2026-07-22 01:40:15.937449-04	\N	t	1
4	3	5	1	2026-07-22 01:40:15.937449-04	\N	t	1
5	3	6	1	2026-07-22 01:40:15.937449-04	\N	t	1
6	3	7	1	2026-07-22 01:40:15.937449-04	\N	t	1
7	3	8	1	2026-07-22 01:40:15.937449-04	\N	t	1
8	3	9	1	2026-07-22 01:40:15.937449-04	\N	t	1
9	3	10	1	2026-07-22 01:40:15.937449-04	\N	t	1
10	3	11	1	2026-07-22 01:40:15.937449-04	\N	t	1
11	3	12	1	2026-07-22 01:40:15.937449-04	\N	t	1
12	3	13	1	2026-07-22 01:40:15.937449-04	\N	t	1
\.


--
-- Data for Name: entrega_premio; Type: TABLE DATA; Schema: finanzas; Owner: -
--

COPY finanzas.entrega_premio (id_entrega_premio, id_torneo_premio, id_resultado_torneo, id_estado_entrega_premio, autorizado_por, entregado_por, fecha_autorizacion, fecha_entrega, fecha_registro, fecha_actualizacion, observaciones) FROM stdin;
1	1	1	3	1	1	2026-07-22 01:40:15.937449-04	2026-07-22 01:40:15.937449-04	2026-07-22 01:40:15.937449-04	2026-07-22 01:40:15.937449-04	Premio entregado al delegado de Titanes
\.


--
-- Data for Name: pago; Type: TABLE DATA; Schema: finanzas; Owner: -
--

COPY finanzas.pago (id_pago, id_inscripcion, id_metodo_pago, id_estado_pago, monto, moneda, referencia, comprobante_url, fecha_pago, fecha_verificacion, registrado_por, verificado_por, observaciones, fecha_registro, fecha_actualizacion) FROM stdin;
1	1	3	2	100.00	BOB	DEMO-TIT-001	\N	2026-07-22 01:40:15.937449-04	2026-07-22 01:40:15.937449-04	1	1	Primer pago parcial de Titanes	2026-07-22 01:40:15.937449-04	2026-07-22 01:40:15.937449-04
2	1	2	2	100.00	BOB	DEMO-TIT-002	\N	2026-07-22 01:40:15.937449-04	2026-07-22 01:40:15.937449-04	1	1	Segundo pago de Titanes	2026-07-22 01:40:15.937449-04	2026-07-22 01:40:15.937449-04
3	2	4	2	200.00	BOB	DEMO-HAL-001	\N	2026-07-22 01:40:15.937449-04	2026-07-22 01:40:15.937449-04	1	1	Pago completo de Halcones	2026-07-22 01:40:15.937449-04	2026-07-22 01:40:15.937449-04
\.


--
-- Data for Name: premio; Type: TABLE DATA; Schema: finanzas; Owner: -
--

COPY finanzas.premio (id_premio, id_tipo_premio, codigo, nombre, descripcion, activo, fecha_registro) FROM stdin;
1	1	PREMIO_CAMPEON_DEMO	Premio economico al campeon demo	Premio de prueba para el equipo campeon	t	2026-07-22 01:33:28.562517-04
\.


--
-- Data for Name: torneo_premio; Type: TABLE DATA; Schema: finanzas; Owner: -
--

COPY finanzas.torneo_premio (id_torneo_premio, id_torneo, id_premio, posicion_objetivo, valor_economico, moneda, descripcion_entrega, registrado_por, fecha_registro) FROM stdin;
1	3	1	1	1000.00	BOB	Premio economico para el campeon	1	2026-07-22 01:40:15.937449-04
\.


--
-- Data for Name: arbitro; Type: TABLE DATA; Schema: participantes; Owner: -
--

COPY participantes.arbitro (id_usuario, numero_licencia, nivel, anios_experiencia, id_estado_perfil, fecha_registro, observaciones) FROM stdin;
3	ARB-DEMO-001	Departamental	6	1	2026-07-22 01:33:28.562517-04	Arbitro utilizado para las pruebas
\.


--
-- Data for Name: equipo; Type: TABLE DATA; Schema: participantes; Owner: -
--

COPY participantes.equipo (id_equipo, nombre, sigla, fecha_fundacion, descripcion, logo_url, id_estado_equipo, creado_por, fecha_registro, fecha_actualizacion) FROM stdin;
1	Titanes Futsal	TIT	2020-01-10	Equipo de prueba Titanes	\N	1	1	2026-07-22 01:33:28.562517-04	2026-07-22 01:33:28.562517-04
2	Halcones Futsal	HAL	2021-02-15	Equipo de prueba Halcones	\N	1	1	2026-07-22 01:33:28.562517-04	2026-07-22 01:33:28.562517-04
6	Condors Deportivos	CON	2024-03-15	Equipo actualizado mediante FastAPI	\N	1	1	2026-07-22 23:21:28.973548-04	2026-07-22 23:21:28.973548-04
\.


--
-- Data for Name: jugador; Type: TABLE DATA; Schema: participantes; Owner: -
--

COPY participantes.jugador (id_usuario, alias_deportivo, id_estado_perfil, fecha_registro, observaciones) FROM stdin;
4	Jugador 7100001	1	2026-07-22 01:33:28.562517-04	Jugador utilizado para las pruebas
5	Jugador 7100002	1	2026-07-22 01:33:28.562517-04	Jugador utilizado para las pruebas
6	Jugador 7100003	1	2026-07-22 01:33:28.562517-04	Jugador utilizado para las pruebas
7	Jugador 7100004	1	2026-07-22 01:33:28.562517-04	Jugador utilizado para las pruebas
8	Jugador 7100005	1	2026-07-22 01:33:28.562517-04	Jugador utilizado para las pruebas
9	Jugador 7200001	1	2026-07-22 01:33:28.562517-04	Jugador utilizado para las pruebas
10	Jugador 7200002	1	2026-07-22 01:33:28.562517-04	Jugador utilizado para las pruebas
11	Jugador 7200003	1	2026-07-22 01:33:28.562517-04	Jugador utilizado para las pruebas
12	Jugador 7200004	1	2026-07-22 01:33:28.562517-04	Jugador utilizado para las pruebas
13	Jugador 7200005	1	2026-07-22 01:33:28.562517-04	Jugador utilizado para las pruebas
\.


--
-- Data for Name: jugador_equipo; Type: TABLE DATA; Schema: participantes; Owner: -
--

COPY participantes.jugador_equipo (id_jugador_equipo, id_jugador, id_equipo, fecha_inicio, fecha_fin, numero_camiseta, posicion, es_delegado, id_estado_membresia, registrado_por, fecha_registro, observaciones) FROM stdin;
1	8	1	2026-01-01	\N	10	Ala	f	1	1	2026-07-22 01:33:28.562517-04	Membresia inicial de prueba
2	7	1	2026-01-01	\N	9	Pivot	f	1	1	2026-07-22 01:33:28.562517-04	Membresia inicial de prueba
3	6	1	2026-01-01	\N	7	Ala	f	1	1	2026-07-22 01:33:28.562517-04	Membresia inicial de prueba
4	5	1	2026-01-01	\N	4	Cierre	f	1	1	2026-07-22 01:33:28.562517-04	Membresia inicial de prueba
5	4	1	2026-01-01	\N	1	Arquero	t	1	1	2026-07-22 01:33:28.562517-04	Membresia inicial de prueba
6	13	2	2026-01-01	\N	11	Ala	f	1	1	2026-07-22 01:33:28.562517-04	Membresia inicial de prueba
7	12	2	2026-01-01	\N	8	Pivot	f	1	1	2026-07-22 01:33:28.562517-04	Membresia inicial de prueba
8	11	2	2026-01-01	\N	6	Ala	f	1	1	2026-07-22 01:33:28.562517-04	Membresia inicial de prueba
9	10	2	2026-01-01	\N	3	Cierre	f	1	1	2026-07-22 01:33:28.562517-04	Membresia inicial de prueba
10	9	2	2026-01-01	\N	1	Arquero	t	1	1	2026-07-22 01:33:28.562517-04	Membresia inicial de prueba
\.


--
-- Data for Name: organizador; Type: TABLE DATA; Schema: participantes; Owner: -
--

COPY participantes.organizador (id_usuario, institucion, cargo, anios_experiencia, id_estado_perfil, fecha_registro, observaciones) FROM stdin;
2	Universidad Demo	Coordinador deportivo	5	1	2026-07-22 01:33:28.562517-04	Organizador utilizado para las pruebas
\.


--
-- Data for Name: rol; Type: TABLE DATA; Schema: seguridad; Owner: -
--

COPY seguridad.rol (id_rol, codigo, nombre, descripcion, activo) FROM stdin;
1	ADMINISTRADOR	Administrador	Gestiona la configuracion general del sistema	t
2	ORGANIZADOR	Organizador	Gestiona torneos, inscripciones y programacion	t
3	ARBITRO	Arbitro	Dirige y registra resultados de partidos asignados	t
4	JUGADOR	Jugador	Participa como integrante de un equipo	t
5	CONSULTA	Usuario de consulta	Puede visualizar informacion publica y reportes permitidos	t
\.


--
-- Data for Name: usuario; Type: TABLE DATA; Schema: seguridad; Owner: -
--

COPY seguridad.usuario (id_usuario, id_tipo_documento, numero_documento, nombres, apellido_paterno, apellido_materno, fecha_nacimiento, sexo, correo, telefono, direccion, zona, contrasenia_hash, id_estado_usuario, intentos_fallidos, ultimo_acceso, fecha_registro, fecha_actualizacion) FROM stdin;
3	1	7000003	Luis	Flores	Condori	1990-08-21	M	arbitro.demo@torneos.test	76500003	Calle Demo 103	Miraflores	$argon2id$v=19$m=65536,t=3,p=4$4Bbkf7zpvmQO/FDZFdWOzA$scDgWq0M9y2AerSQ6wadbIvU/loL+rXdJasVv/1NXwQ	1	0	\N	2026-07-22 01:33:28.562517-04	2026-07-22 01:33:28.562517-04
4	1	7100001	Carlos	Mendoza	Rojas	2001-01-12	M	titanes1@torneos.test	76500101	Zona Norte 1	Zona Norte	$argon2id$v=19$m=65536,t=3,p=4$HL/wKRRDQCMEdl5iNfNRKw$F3WzME/kNm2z9d7O1bxOUDZBUIzthtxhG0GXfFXvyfI	1	0	\N	2026-07-22 01:33:28.562517-04	2026-07-22 01:33:28.562517-04
5	1	7100002	Jorge	Paredes	Mamani	2000-02-14	M	titanes2@torneos.test	76500102	Zona Norte 2	Zona Norte	$argon2id$v=19$m=65536,t=3,p=4$UMf2fsfkrQVnfP5W1F0mBA$SLeofkqyZhLt09w5wx3b7uXHYezvpY/NexZh8ZwAvRc	1	0	\N	2026-07-22 01:33:28.562517-04	2026-07-22 01:33:28.562517-04
6	1	7100003	Miguel	Lopez	Choque	2002-03-16	M	titanes3@torneos.test	76500103	Zona Norte 3	Zona Norte	$argon2id$v=19$m=65536,t=3,p=4$HjEpcyqiBb71KsjtjjLJNw$q4cF8Mv09qUB5nHVhHPwd3oKJDhYxUBs33t31VBZaMg	1	0	\N	2026-07-22 01:33:28.562517-04	2026-07-22 01:33:28.562517-04
7	1	7100004	Daniel	Vargas	Cruz	2001-04-18	M	titanes4@torneos.test	76500104	Zona Norte 4	Zona Norte	$argon2id$v=19$m=65536,t=3,p=4$9ATkRDjaGg0Pv9/59Ov8fw$LXK0nKpKOmj4gqSHmONPCSFu3rH1ID4igzD6FEpkb28	1	0	\N	2026-07-22 01:33:28.562517-04	2026-07-22 01:33:28.562517-04
8	1	7100005	Pedro	Salazar	Luna	2000-05-20	M	titanes5@torneos.test	76500105	Zona Norte 5	Zona Norte	$argon2id$v=19$m=65536,t=3,p=4$uaGN7SeFiA9qyyj7PJrIwA$sdCt8Yj3zJRqABhs2TzTjrgQUDOL00IGEzSUyPZYf7k	1	0	\N	2026-07-22 01:33:28.562517-04	2026-07-22 01:33:28.562517-04
9	1	7200001	Alejandro	Torrez	Ramos	2001-06-22	M	halcones1@torneos.test	76500201	Zona Sur 1	Zona Sur	$argon2id$v=19$m=65536,t=3,p=4$+RnIBMmCmqzP4DToSSLcIA$Ja8u08gefYYL6wGAAXnJwb+u+zxYIBa19vwwwuumsgE	1	0	\N	2026-07-22 01:33:28.562517-04	2026-07-22 01:33:28.562517-04
10	1	7200002	Rodrigo	Gutierrez	Poma	2002-07-24	M	halcones2@torneos.test	76500202	Zona Sur 2	Zona Sur	$argon2id$v=19$m=65536,t=3,p=4$jMoGJBlMkRSb0L2lANbq4g$I5b6jMwbaJKArIMfVDPeskvbQIodhYzkwwJM0naUS5c	1	0	\N	2026-07-22 01:33:28.562517-04	2026-07-22 01:33:28.562517-04
11	1	7200003	Fernando	Castro	Mendoza	2000-08-26	M	halcones3@torneos.test	76500203	Zona Sur 3	Zona Sur	$argon2id$v=19$m=65536,t=3,p=4$MTXB9jp7y57owUz8PE9MVA$4SUaLbWATOX0kKWJ5WaHaiMRg5uA0mzTKs4GI+MwcGM	1	0	\N	2026-07-22 01:33:28.562517-04	2026-07-22 01:33:28.562517-04
12	1	7200004	Ricardo	Soria	Quisbert	2001-09-28	M	halcones4@torneos.test	76500204	Zona Sur 4	Zona Sur	$argon2id$v=19$m=65536,t=3,p=4$9gWJJ09/09QD5xtT1/TXDg$qxrFArE01q6kKLT+C99W5m3anjk3T5sl7E5j2XXtO9k	1	0	\N	2026-07-22 01:33:28.562517-04	2026-07-22 01:33:28.562517-04
13	1	7200005	Gabriel	Nina	Flores	2002-10-30	M	halcones5@torneos.test	76500205	Zona Sur 5	Zona Sur	$argon2id$v=19$m=65536,t=3,p=4$SyA5PmKy2nMesVzMyCzJmQ$RaH6Squ8d0AkswsTe1fr5wHBnRO072jIllvWMjRYIwM	1	0	\N	2026-07-22 01:33:28.562517-04	2026-07-22 01:33:28.562517-04
1	1	7000001	Andrea	Rojas	Mamani	1995-03-10	F	admin.demo@torneos.test	76500001	Calle Demo 101	Centro	$argon2id$v=19$m=65536,t=3,p=4$bQlDDnECEqk0w4Ag+gzcTQ$Cwhj6mLZpgSg63a/XTPI4COfh97/7wShuggvSdT/hpI	1	0	2026-07-23 00:53:52.357061-04	2026-07-22 01:33:28.562517-04	2026-07-22 01:33:28.562517-04
2	1	7000002	Marcos	Quispe	Flores	1992-05-15	M	organizador.demo@torneos.test	76500002	Calle Demo 102	Sopocachi	$argon2id$v=19$m=65536,t=3,p=4$cY36CWFUkuyyf+qtY2DnwA$3f2l0q1MBD11UJFNLhSvYiZPp7nRVDUb2WOmrUrQpe4	1	0	2026-07-23 00:59:10.383698-04	2026-07-22 01:33:28.562517-04	2026-07-22 01:33:28.562517-04
\.


--
-- Data for Name: usuario_rol; Type: TABLE DATA; Schema: seguridad; Owner: -
--

COPY seguridad.usuario_rol (id_usuario_rol, id_usuario, id_rol, fecha_inicio, fecha_fin, activo, asignado_por, fecha_asignacion) FROM stdin;
1	1	1	2026-07-22	\N	t	1	2026-07-22 01:33:28.562517-04
2	2	2	2026-07-22	\N	t	1	2026-07-22 01:33:28.562517-04
3	3	3	2026-07-22	\N	t	1	2026-07-22 01:33:28.562517-04
4	13	4	2026-07-22	\N	t	1	2026-07-22 01:33:28.562517-04
5	12	4	2026-07-22	\N	t	1	2026-07-22 01:33:28.562517-04
6	11	4	2026-07-22	\N	t	1	2026-07-22 01:33:28.562517-04
7	10	4	2026-07-22	\N	t	1	2026-07-22 01:33:28.562517-04
8	9	4	2026-07-22	\N	t	1	2026-07-22 01:33:28.562517-04
9	8	4	2026-07-22	\N	t	1	2026-07-22 01:33:28.562517-04
10	7	4	2026-07-22	\N	t	1	2026-07-22 01:33:28.562517-04
11	6	4	2026-07-22	\N	t	1	2026-07-22 01:33:28.562517-04
12	5	4	2026-07-22	\N	t	1	2026-07-22 01:33:28.562517-04
13	4	4	2026-07-22	\N	t	1	2026-07-22 01:33:28.562517-04
\.


--
-- Name: auditoria_dml_id_auditoria_seq; Type: SEQUENCE SET; Schema: auditoria; Owner: -
--

SELECT pg_catalog.setval('auditoria.auditoria_dml_id_auditoria_seq', 177, true);


--
-- Name: configuracion_auditoria_id_configuracion_seq; Type: SEQUENCE SET; Schema: auditoria; Owner: -
--

SELECT pg_catalog.setval('auditoria.configuracion_auditoria_id_configuracion_seq', 30, true);


--
-- Name: historial_entrega_premio_id_historial_entrega_seq; Type: SEQUENCE SET; Schema: auditoria; Owner: -
--

SELECT pg_catalog.setval('auditoria.historial_entrega_premio_id_historial_entrega_seq', 3, true);


--
-- Name: historial_estado_inscripcion_id_historial_inscripcion_seq; Type: SEQUENCE SET; Schema: auditoria; Owner: -
--

SELECT pg_catalog.setval('auditoria.historial_estado_inscripcion_id_historial_inscripcion_seq', 13, true);


--
-- Name: historial_estado_pago_id_historial_pago_seq; Type: SEQUENCE SET; Schema: auditoria; Owner: -
--

SELECT pg_catalog.setval('auditoria.historial_estado_pago_id_historial_pago_seq', 7, true);


--
-- Name: historial_estado_partido_id_historial_partido_seq; Type: SEQUENCE SET; Schema: auditoria; Owner: -
--

SELECT pg_catalog.setval('auditoria.historial_estado_partido_id_historial_partido_seq', 9, true);


--
-- Name: condicion_equipo_partido_id_condicion_equipo_seq; Type: SEQUENCE SET; Schema: catalogo; Owner: -
--

SELECT pg_catalog.setval('catalogo.condicion_equipo_partido_id_condicion_equipo_seq', 2, true);


--
-- Name: conflicto_rol_torneo_id_conflicto_seq; Type: SEQUENCE SET; Schema: catalogo; Owner: -
--

SELECT pg_catalog.setval('catalogo.conflicto_rol_torneo_id_conflicto_seq', 3, true);


--
-- Name: estado_deporte_id_estado_deporte_seq; Type: SEQUENCE SET; Schema: catalogo; Owner: -
--

SELECT pg_catalog.setval('catalogo.estado_deporte_id_estado_deporte_seq', 2, true);


--
-- Name: estado_entrega_premio_id_estado_entrega_premio_seq; Type: SEQUENCE SET; Schema: catalogo; Owner: -
--

SELECT pg_catalog.setval('catalogo.estado_entrega_premio_id_estado_entrega_premio_seq', 4, true);


--
-- Name: estado_equipo_id_estado_equipo_seq; Type: SEQUENCE SET; Schema: catalogo; Owner: -
--

SELECT pg_catalog.setval('catalogo.estado_equipo_id_estado_equipo_seq', 3, true);


--
-- Name: estado_fase_id_estado_fase_seq; Type: SEQUENCE SET; Schema: catalogo; Owner: -
--

SELECT pg_catalog.setval('catalogo.estado_fase_id_estado_fase_seq', 4, true);


--
-- Name: estado_inscripcion_id_estado_inscripcion_seq; Type: SEQUENCE SET; Schema: catalogo; Owner: -
--

SELECT pg_catalog.setval('catalogo.estado_inscripcion_id_estado_inscripcion_seq', 5, true);


--
-- Name: estado_jornada_id_estado_jornada_seq; Type: SEQUENCE SET; Schema: catalogo; Owner: -
--

SELECT pg_catalog.setval('catalogo.estado_jornada_id_estado_jornada_seq', 5, true);


--
-- Name: estado_jugador_inscripcion_id_estado_jugador_inscripcion_seq; Type: SEQUENCE SET; Schema: catalogo; Owner: -
--

SELECT pg_catalog.setval('catalogo.estado_jugador_inscripcion_id_estado_jugador_inscripcion_seq', 3, true);


--
-- Name: estado_membresia_id_estado_membresia_seq; Type: SEQUENCE SET; Schema: catalogo; Owner: -
--

SELECT pg_catalog.setval('catalogo.estado_membresia_id_estado_membresia_seq', 3, true);


--
-- Name: estado_pago_id_estado_pago_seq; Type: SEQUENCE SET; Schema: catalogo; Owner: -
--

SELECT pg_catalog.setval('catalogo.estado_pago_id_estado_pago_seq', 4, true);


--
-- Name: estado_partido_id_estado_partido_seq; Type: SEQUENCE SET; Schema: catalogo; Owner: -
--

SELECT pg_catalog.setval('catalogo.estado_partido_id_estado_partido_seq', 6, true);


--
-- Name: estado_perfil_deportivo_id_estado_perfil_seq; Type: SEQUENCE SET; Schema: catalogo; Owner: -
--

SELECT pg_catalog.setval('catalogo.estado_perfil_deportivo_id_estado_perfil_seq', 3, true);


--
-- Name: estado_torneo_id_estado_torneo_seq; Type: SEQUENCE SET; Schema: catalogo; Owner: -
--

SELECT pg_catalog.setval('catalogo.estado_torneo_id_estado_torneo_seq', 7, true);


--
-- Name: estado_usuario_id_estado_usuario_seq; Type: SEQUENCE SET; Schema: catalogo; Owner: -
--

SELECT pg_catalog.setval('catalogo.estado_usuario_id_estado_usuario_seq', 3, true);


--
-- Name: formato_torneo_id_formato_torneo_seq; Type: SEQUENCE SET; Schema: catalogo; Owner: -
--

SELECT pg_catalog.setval('catalogo.formato_torneo_id_formato_torneo_seq', 4, true);


--
-- Name: metodo_pago_id_metodo_pago_seq; Type: SEQUENCE SET; Schema: catalogo; Owner: -
--

SELECT pg_catalog.setval('catalogo.metodo_pago_id_metodo_pago_seq', 5, true);


--
-- Name: resultado_equipo_partido_id_resultado_equipo_partido_seq; Type: SEQUENCE SET; Schema: catalogo; Owner: -
--

SELECT pg_catalog.setval('catalogo.resultado_equipo_partido_id_resultado_equipo_partido_seq', 4, true);


--
-- Name: rol_torneo_id_rol_torneo_seq; Type: SEQUENCE SET; Schema: catalogo; Owner: -
--

SELECT pg_catalog.setval('catalogo.rol_torneo_id_rol_torneo_seq', 3, true);


--
-- Name: tipo_arbitro_partido_id_tipo_arbitro_partido_seq; Type: SEQUENCE SET; Schema: catalogo; Owner: -
--

SELECT pg_catalog.setval('catalogo.tipo_arbitro_partido_id_tipo_arbitro_partido_seq', 4, true);


--
-- Name: tipo_documento_id_tipo_documento_seq; Type: SEQUENCE SET; Schema: catalogo; Owner: -
--

SELECT pg_catalog.setval('catalogo.tipo_documento_id_tipo_documento_seq', 3, true);


--
-- Name: tipo_fase_id_tipo_fase_seq; Type: SEQUENCE SET; Schema: catalogo; Owner: -
--

SELECT pg_catalog.setval('catalogo.tipo_fase_id_tipo_fase_seq', 4, true);


--
-- Name: tipo_premio_id_tipo_premio_seq; Type: SEQUENCE SET; Schema: catalogo; Owner: -
--

SELECT pg_catalog.setval('catalogo.tipo_premio_id_tipo_premio_seq', 5, true);


--
-- Name: arbitro_partido_id_arbitro_partido_seq; Type: SEQUENCE SET; Schema: competencia; Owner: -
--

SELECT pg_catalog.setval('competencia.arbitro_partido_id_arbitro_partido_seq', 3, true);


--
-- Name: deporte_id_deporte_seq; Type: SEQUENCE SET; Schema: competencia; Owner: -
--

SELECT pg_catalog.setval('competencia.deporte_id_deporte_seq', 8, true);


--
-- Name: deporte_regla_id_deporte_regla_seq; Type: SEQUENCE SET; Schema: competencia; Owner: -
--

SELECT pg_catalog.setval('competencia.deporte_regla_id_deporte_regla_seq', 1, false);


--
-- Name: equipo_grupo_id_equipo_grupo_seq; Type: SEQUENCE SET; Schema: competencia; Owner: -
--

SELECT pg_catalog.setval('competencia.equipo_grupo_id_equipo_grupo_seq', 1, false);


--
-- Name: fase_torneo_id_fase_torneo_seq; Type: SEQUENCE SET; Schema: competencia; Owner: -
--

SELECT pg_catalog.setval('competencia.fase_torneo_id_fase_torneo_seq', 3, true);


--
-- Name: grupo_torneo_id_grupo_torneo_seq; Type: SEQUENCE SET; Schema: competencia; Owner: -
--

SELECT pg_catalog.setval('competencia.grupo_torneo_id_grupo_torneo_seq', 1, false);


--
-- Name: inscripcion_id_inscripcion_seq; Type: SEQUENCE SET; Schema: competencia; Owner: -
--

SELECT pg_catalog.setval('competencia.inscripcion_id_inscripcion_seq', 7, true);


--
-- Name: jornada_id_jornada_seq; Type: SEQUENCE SET; Schema: competencia; Owner: -
--

SELECT pg_catalog.setval('competencia.jornada_id_jornada_seq', 3, true);


--
-- Name: jugador_inscripcion_id_jugador_inscripcion_seq; Type: SEQUENCE SET; Schema: competencia; Owner: -
--

SELECT pg_catalog.setval('competencia.jugador_inscripcion_id_jugador_inscripcion_seq', 12, true);


--
-- Name: jugador_partido_id_jugador_partido_seq; Type: SEQUENCE SET; Schema: competencia; Owner: -
--

SELECT pg_catalog.setval('competencia.jugador_partido_id_jugador_partido_seq', 11, true);


--
-- Name: lugar_id_lugar_seq; Type: SEQUENCE SET; Schema: competencia; Owner: -
--

SELECT pg_catalog.setval('competencia.lugar_id_lugar_seq', 3, true);


--
-- Name: partido_equipo_id_partido_equipo_seq; Type: SEQUENCE SET; Schema: competencia; Owner: -
--

SELECT pg_catalog.setval('competencia.partido_equipo_id_partido_equipo_seq', 6, true);


--
-- Name: partido_id_partido_seq; Type: SEQUENCE SET; Schema: competencia; Owner: -
--

SELECT pg_catalog.setval('competencia.partido_id_partido_seq', 4, true);


--
-- Name: regla_id_regla_seq; Type: SEQUENCE SET; Schema: competencia; Owner: -
--

SELECT pg_catalog.setval('competencia.regla_id_regla_seq', 2, true);


--
-- Name: resultado_torneo_id_resultado_torneo_seq; Type: SEQUENCE SET; Schema: competencia; Owner: -
--

SELECT pg_catalog.setval('competencia.resultado_torneo_id_resultado_torneo_seq', 2, true);


--
-- Name: torneo_id_torneo_seq; Type: SEQUENCE SET; Schema: competencia; Owner: -
--

SELECT pg_catalog.setval('competencia.torneo_id_torneo_seq', 4, true);


--
-- Name: torneo_regla_id_torneo_regla_seq; Type: SEQUENCE SET; Schema: competencia; Owner: -
--

SELECT pg_catalog.setval('competencia.torneo_regla_id_torneo_regla_seq', 1, false);


--
-- Name: usuario_torneo_rol_id_usuario_torneo_rol_seq; Type: SEQUENCE SET; Schema: competencia; Owner: -
--

SELECT pg_catalog.setval('competencia.usuario_torneo_rol_id_usuario_torneo_rol_seq', 14, true);


--
-- Name: entrega_premio_id_entrega_premio_seq; Type: SEQUENCE SET; Schema: finanzas; Owner: -
--

SELECT pg_catalog.setval('finanzas.entrega_premio_id_entrega_premio_seq', 1, true);


--
-- Name: pago_id_pago_seq; Type: SEQUENCE SET; Schema: finanzas; Owner: -
--

SELECT pg_catalog.setval('finanzas.pago_id_pago_seq', 8, true);


--
-- Name: premio_id_premio_seq; Type: SEQUENCE SET; Schema: finanzas; Owner: -
--

SELECT pg_catalog.setval('finanzas.premio_id_premio_seq', 1, true);


--
-- Name: torneo_premio_id_torneo_premio_seq; Type: SEQUENCE SET; Schema: finanzas; Owner: -
--

SELECT pg_catalog.setval('finanzas.torneo_premio_id_torneo_premio_seq', 1, true);


--
-- Name: equipo_id_equipo_seq; Type: SEQUENCE SET; Schema: participantes; Owner: -
--

SELECT pg_catalog.setval('participantes.equipo_id_equipo_seq', 7, true);


--
-- Name: jugador_equipo_id_jugador_equipo_seq; Type: SEQUENCE SET; Schema: participantes; Owner: -
--

SELECT pg_catalog.setval('participantes.jugador_equipo_id_jugador_equipo_seq', 12, true);


--
-- Name: rol_id_rol_seq; Type: SEQUENCE SET; Schema: seguridad; Owner: -
--

SELECT pg_catalog.setval('seguridad.rol_id_rol_seq', 5, true);


--
-- Name: usuario_id_usuario_seq; Type: SEQUENCE SET; Schema: seguridad; Owner: -
--

SELECT pg_catalog.setval('seguridad.usuario_id_usuario_seq', 14, true);


--
-- Name: usuario_rol_id_usuario_rol_seq; Type: SEQUENCE SET; Schema: seguridad; Owner: -
--

SELECT pg_catalog.setval('seguridad.usuario_rol_id_usuario_rol_seq', 14, true);


--
-- Name: auditoria_dml pk_auditoria_dml; Type: CONSTRAINT; Schema: auditoria; Owner: -
--

ALTER TABLE ONLY auditoria.auditoria_dml
    ADD CONSTRAINT pk_auditoria_dml PRIMARY KEY (id_auditoria);


--
-- Name: configuracion_auditoria pk_configuracion_auditoria; Type: CONSTRAINT; Schema: auditoria; Owner: -
--

ALTER TABLE ONLY auditoria.configuracion_auditoria
    ADD CONSTRAINT pk_configuracion_auditoria PRIMARY KEY (id_configuracion);


--
-- Name: historial_entrega_premio pk_historial_entrega_premio; Type: CONSTRAINT; Schema: auditoria; Owner: -
--

ALTER TABLE ONLY auditoria.historial_entrega_premio
    ADD CONSTRAINT pk_historial_entrega_premio PRIMARY KEY (id_historial_entrega);


--
-- Name: historial_estado_inscripcion pk_historial_estado_inscripcion; Type: CONSTRAINT; Schema: auditoria; Owner: -
--

ALTER TABLE ONLY auditoria.historial_estado_inscripcion
    ADD CONSTRAINT pk_historial_estado_inscripcion PRIMARY KEY (id_historial_inscripcion);


--
-- Name: historial_estado_pago pk_historial_estado_pago; Type: CONSTRAINT; Schema: auditoria; Owner: -
--

ALTER TABLE ONLY auditoria.historial_estado_pago
    ADD CONSTRAINT pk_historial_estado_pago PRIMARY KEY (id_historial_pago);


--
-- Name: historial_estado_partido pk_historial_estado_partido; Type: CONSTRAINT; Schema: auditoria; Owner: -
--

ALTER TABLE ONLY auditoria.historial_estado_partido
    ADD CONSTRAINT pk_historial_estado_partido PRIMARY KEY (id_historial_partido);


--
-- Name: configuracion_auditoria uq_configuracion_auditoria_tabla; Type: CONSTRAINT; Schema: auditoria; Owner: -
--

ALTER TABLE ONLY auditoria.configuracion_auditoria
    ADD CONSTRAINT uq_configuracion_auditoria_tabla UNIQUE (esquema, tabla);


--
-- Name: condicion_equipo_partido pk_condicion_equipo_partido; Type: CONSTRAINT; Schema: catalogo; Owner: -
--

ALTER TABLE ONLY catalogo.condicion_equipo_partido
    ADD CONSTRAINT pk_condicion_equipo_partido PRIMARY KEY (id_condicion_equipo);


--
-- Name: conflicto_rol_torneo pk_conflicto_rol_torneo; Type: CONSTRAINT; Schema: catalogo; Owner: -
--

ALTER TABLE ONLY catalogo.conflicto_rol_torneo
    ADD CONSTRAINT pk_conflicto_rol_torneo PRIMARY KEY (id_conflicto);


--
-- Name: estado_deporte pk_estado_deporte; Type: CONSTRAINT; Schema: catalogo; Owner: -
--

ALTER TABLE ONLY catalogo.estado_deporte
    ADD CONSTRAINT pk_estado_deporte PRIMARY KEY (id_estado_deporte);


--
-- Name: estado_entrega_premio pk_estado_entrega_premio; Type: CONSTRAINT; Schema: catalogo; Owner: -
--

ALTER TABLE ONLY catalogo.estado_entrega_premio
    ADD CONSTRAINT pk_estado_entrega_premio PRIMARY KEY (id_estado_entrega_premio);


--
-- Name: estado_equipo pk_estado_equipo; Type: CONSTRAINT; Schema: catalogo; Owner: -
--

ALTER TABLE ONLY catalogo.estado_equipo
    ADD CONSTRAINT pk_estado_equipo PRIMARY KEY (id_estado_equipo);


--
-- Name: estado_fase pk_estado_fase; Type: CONSTRAINT; Schema: catalogo; Owner: -
--

ALTER TABLE ONLY catalogo.estado_fase
    ADD CONSTRAINT pk_estado_fase PRIMARY KEY (id_estado_fase);


--
-- Name: estado_inscripcion pk_estado_inscripcion; Type: CONSTRAINT; Schema: catalogo; Owner: -
--

ALTER TABLE ONLY catalogo.estado_inscripcion
    ADD CONSTRAINT pk_estado_inscripcion PRIMARY KEY (id_estado_inscripcion);


--
-- Name: estado_jornada pk_estado_jornada; Type: CONSTRAINT; Schema: catalogo; Owner: -
--

ALTER TABLE ONLY catalogo.estado_jornada
    ADD CONSTRAINT pk_estado_jornada PRIMARY KEY (id_estado_jornada);


--
-- Name: estado_jugador_inscripcion pk_estado_jugador_inscripcion; Type: CONSTRAINT; Schema: catalogo; Owner: -
--

ALTER TABLE ONLY catalogo.estado_jugador_inscripcion
    ADD CONSTRAINT pk_estado_jugador_inscripcion PRIMARY KEY (id_estado_jugador_inscripcion);


--
-- Name: estado_membresia pk_estado_membresia; Type: CONSTRAINT; Schema: catalogo; Owner: -
--

ALTER TABLE ONLY catalogo.estado_membresia
    ADD CONSTRAINT pk_estado_membresia PRIMARY KEY (id_estado_membresia);


--
-- Name: estado_pago pk_estado_pago; Type: CONSTRAINT; Schema: catalogo; Owner: -
--

ALTER TABLE ONLY catalogo.estado_pago
    ADD CONSTRAINT pk_estado_pago PRIMARY KEY (id_estado_pago);


--
-- Name: estado_partido pk_estado_partido; Type: CONSTRAINT; Schema: catalogo; Owner: -
--

ALTER TABLE ONLY catalogo.estado_partido
    ADD CONSTRAINT pk_estado_partido PRIMARY KEY (id_estado_partido);


--
-- Name: estado_perfil_deportivo pk_estado_perfil_deportivo; Type: CONSTRAINT; Schema: catalogo; Owner: -
--

ALTER TABLE ONLY catalogo.estado_perfil_deportivo
    ADD CONSTRAINT pk_estado_perfil_deportivo PRIMARY KEY (id_estado_perfil);


--
-- Name: estado_torneo pk_estado_torneo; Type: CONSTRAINT; Schema: catalogo; Owner: -
--

ALTER TABLE ONLY catalogo.estado_torneo
    ADD CONSTRAINT pk_estado_torneo PRIMARY KEY (id_estado_torneo);


--
-- Name: estado_usuario pk_estado_usuario; Type: CONSTRAINT; Schema: catalogo; Owner: -
--

ALTER TABLE ONLY catalogo.estado_usuario
    ADD CONSTRAINT pk_estado_usuario PRIMARY KEY (id_estado_usuario);


--
-- Name: formato_torneo pk_formato_torneo; Type: CONSTRAINT; Schema: catalogo; Owner: -
--

ALTER TABLE ONLY catalogo.formato_torneo
    ADD CONSTRAINT pk_formato_torneo PRIMARY KEY (id_formato_torneo);


--
-- Name: metodo_pago pk_metodo_pago; Type: CONSTRAINT; Schema: catalogo; Owner: -
--

ALTER TABLE ONLY catalogo.metodo_pago
    ADD CONSTRAINT pk_metodo_pago PRIMARY KEY (id_metodo_pago);


--
-- Name: resultado_equipo_partido pk_resultado_equipo_partido; Type: CONSTRAINT; Schema: catalogo; Owner: -
--

ALTER TABLE ONLY catalogo.resultado_equipo_partido
    ADD CONSTRAINT pk_resultado_equipo_partido PRIMARY KEY (id_resultado_equipo_partido);


--
-- Name: rol_torneo pk_rol_torneo; Type: CONSTRAINT; Schema: catalogo; Owner: -
--

ALTER TABLE ONLY catalogo.rol_torneo
    ADD CONSTRAINT pk_rol_torneo PRIMARY KEY (id_rol_torneo);


--
-- Name: tipo_arbitro_partido pk_tipo_arbitro_partido; Type: CONSTRAINT; Schema: catalogo; Owner: -
--

ALTER TABLE ONLY catalogo.tipo_arbitro_partido
    ADD CONSTRAINT pk_tipo_arbitro_partido PRIMARY KEY (id_tipo_arbitro_partido);


--
-- Name: tipo_documento pk_tipo_documento; Type: CONSTRAINT; Schema: catalogo; Owner: -
--

ALTER TABLE ONLY catalogo.tipo_documento
    ADD CONSTRAINT pk_tipo_documento PRIMARY KEY (id_tipo_documento);


--
-- Name: tipo_fase pk_tipo_fase; Type: CONSTRAINT; Schema: catalogo; Owner: -
--

ALTER TABLE ONLY catalogo.tipo_fase
    ADD CONSTRAINT pk_tipo_fase PRIMARY KEY (id_tipo_fase);


--
-- Name: tipo_premio pk_tipo_premio; Type: CONSTRAINT; Schema: catalogo; Owner: -
--

ALTER TABLE ONLY catalogo.tipo_premio
    ADD CONSTRAINT pk_tipo_premio PRIMARY KEY (id_tipo_premio);


--
-- Name: condicion_equipo_partido uq_condicion_equipo_partido_codigo; Type: CONSTRAINT; Schema: catalogo; Owner: -
--

ALTER TABLE ONLY catalogo.condicion_equipo_partido
    ADD CONSTRAINT uq_condicion_equipo_partido_codigo UNIQUE (codigo);


--
-- Name: conflicto_rol_torneo uq_conflicto_rol_torneo; Type: CONSTRAINT; Schema: catalogo; Owner: -
--

ALTER TABLE ONLY catalogo.conflicto_rol_torneo
    ADD CONSTRAINT uq_conflicto_rol_torneo UNIQUE (id_rol_torneo_a, id_rol_torneo_b);


--
-- Name: estado_deporte uq_estado_deporte_codigo; Type: CONSTRAINT; Schema: catalogo; Owner: -
--

ALTER TABLE ONLY catalogo.estado_deporte
    ADD CONSTRAINT uq_estado_deporte_codigo UNIQUE (codigo);


--
-- Name: estado_entrega_premio uq_estado_entrega_premio_codigo; Type: CONSTRAINT; Schema: catalogo; Owner: -
--

ALTER TABLE ONLY catalogo.estado_entrega_premio
    ADD CONSTRAINT uq_estado_entrega_premio_codigo UNIQUE (codigo);


--
-- Name: estado_equipo uq_estado_equipo_codigo; Type: CONSTRAINT; Schema: catalogo; Owner: -
--

ALTER TABLE ONLY catalogo.estado_equipo
    ADD CONSTRAINT uq_estado_equipo_codigo UNIQUE (codigo);


--
-- Name: estado_fase uq_estado_fase_codigo; Type: CONSTRAINT; Schema: catalogo; Owner: -
--

ALTER TABLE ONLY catalogo.estado_fase
    ADD CONSTRAINT uq_estado_fase_codigo UNIQUE (codigo);


--
-- Name: estado_inscripcion uq_estado_inscripcion_codigo; Type: CONSTRAINT; Schema: catalogo; Owner: -
--

ALTER TABLE ONLY catalogo.estado_inscripcion
    ADD CONSTRAINT uq_estado_inscripcion_codigo UNIQUE (codigo);


--
-- Name: estado_jornada uq_estado_jornada_codigo; Type: CONSTRAINT; Schema: catalogo; Owner: -
--

ALTER TABLE ONLY catalogo.estado_jornada
    ADD CONSTRAINT uq_estado_jornada_codigo UNIQUE (codigo);


--
-- Name: estado_jugador_inscripcion uq_estado_jugador_inscripcion_codigo; Type: CONSTRAINT; Schema: catalogo; Owner: -
--

ALTER TABLE ONLY catalogo.estado_jugador_inscripcion
    ADD CONSTRAINT uq_estado_jugador_inscripcion_codigo UNIQUE (codigo);


--
-- Name: estado_membresia uq_estado_membresia_codigo; Type: CONSTRAINT; Schema: catalogo; Owner: -
--

ALTER TABLE ONLY catalogo.estado_membresia
    ADD CONSTRAINT uq_estado_membresia_codigo UNIQUE (codigo);


--
-- Name: estado_pago uq_estado_pago_codigo; Type: CONSTRAINT; Schema: catalogo; Owner: -
--

ALTER TABLE ONLY catalogo.estado_pago
    ADD CONSTRAINT uq_estado_pago_codigo UNIQUE (codigo);


--
-- Name: estado_partido uq_estado_partido_codigo; Type: CONSTRAINT; Schema: catalogo; Owner: -
--

ALTER TABLE ONLY catalogo.estado_partido
    ADD CONSTRAINT uq_estado_partido_codigo UNIQUE (codigo);


--
-- Name: estado_perfil_deportivo uq_estado_perfil_deportivo_codigo; Type: CONSTRAINT; Schema: catalogo; Owner: -
--

ALTER TABLE ONLY catalogo.estado_perfil_deportivo
    ADD CONSTRAINT uq_estado_perfil_deportivo_codigo UNIQUE (codigo);


--
-- Name: estado_torneo uq_estado_torneo_codigo; Type: CONSTRAINT; Schema: catalogo; Owner: -
--

ALTER TABLE ONLY catalogo.estado_torneo
    ADD CONSTRAINT uq_estado_torneo_codigo UNIQUE (codigo);


--
-- Name: estado_usuario uq_estado_usuario_codigo; Type: CONSTRAINT; Schema: catalogo; Owner: -
--

ALTER TABLE ONLY catalogo.estado_usuario
    ADD CONSTRAINT uq_estado_usuario_codigo UNIQUE (codigo);


--
-- Name: formato_torneo uq_formato_torneo_codigo; Type: CONSTRAINT; Schema: catalogo; Owner: -
--

ALTER TABLE ONLY catalogo.formato_torneo
    ADD CONSTRAINT uq_formato_torneo_codigo UNIQUE (codigo);


--
-- Name: metodo_pago uq_metodo_pago_codigo; Type: CONSTRAINT; Schema: catalogo; Owner: -
--

ALTER TABLE ONLY catalogo.metodo_pago
    ADD CONSTRAINT uq_metodo_pago_codigo UNIQUE (codigo);


--
-- Name: resultado_equipo_partido uq_resultado_equipo_partido_codigo; Type: CONSTRAINT; Schema: catalogo; Owner: -
--

ALTER TABLE ONLY catalogo.resultado_equipo_partido
    ADD CONSTRAINT uq_resultado_equipo_partido_codigo UNIQUE (codigo);


--
-- Name: rol_torneo uq_rol_torneo_codigo; Type: CONSTRAINT; Schema: catalogo; Owner: -
--

ALTER TABLE ONLY catalogo.rol_torneo
    ADD CONSTRAINT uq_rol_torneo_codigo UNIQUE (codigo);


--
-- Name: tipo_arbitro_partido uq_tipo_arbitro_partido_codigo; Type: CONSTRAINT; Schema: catalogo; Owner: -
--

ALTER TABLE ONLY catalogo.tipo_arbitro_partido
    ADD CONSTRAINT uq_tipo_arbitro_partido_codigo UNIQUE (codigo);


--
-- Name: tipo_documento uq_tipo_documento_codigo; Type: CONSTRAINT; Schema: catalogo; Owner: -
--

ALTER TABLE ONLY catalogo.tipo_documento
    ADD CONSTRAINT uq_tipo_documento_codigo UNIQUE (codigo);


--
-- Name: tipo_fase uq_tipo_fase_codigo; Type: CONSTRAINT; Schema: catalogo; Owner: -
--

ALTER TABLE ONLY catalogo.tipo_fase
    ADD CONSTRAINT uq_tipo_fase_codigo UNIQUE (codigo);


--
-- Name: tipo_premio uq_tipo_premio_codigo; Type: CONSTRAINT; Schema: catalogo; Owner: -
--

ALTER TABLE ONLY catalogo.tipo_premio
    ADD CONSTRAINT uq_tipo_premio_codigo UNIQUE (codigo);


--
-- Name: arbitro_partido pk_arbitro_partido; Type: CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.arbitro_partido
    ADD CONSTRAINT pk_arbitro_partido PRIMARY KEY (id_arbitro_partido);


--
-- Name: deporte pk_deporte; Type: CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.deporte
    ADD CONSTRAINT pk_deporte PRIMARY KEY (id_deporte);


--
-- Name: deporte_regla pk_deporte_regla; Type: CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.deporte_regla
    ADD CONSTRAINT pk_deporte_regla PRIMARY KEY (id_deporte_regla);


--
-- Name: equipo_grupo pk_equipo_grupo; Type: CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.equipo_grupo
    ADD CONSTRAINT pk_equipo_grupo PRIMARY KEY (id_equipo_grupo);


--
-- Name: fase_torneo pk_fase_torneo; Type: CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.fase_torneo
    ADD CONSTRAINT pk_fase_torneo PRIMARY KEY (id_fase_torneo);


--
-- Name: grupo_torneo pk_grupo_torneo; Type: CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.grupo_torneo
    ADD CONSTRAINT pk_grupo_torneo PRIMARY KEY (id_grupo_torneo);


--
-- Name: inscripcion pk_inscripcion; Type: CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.inscripcion
    ADD CONSTRAINT pk_inscripcion PRIMARY KEY (id_inscripcion);


--
-- Name: jornada pk_jornada; Type: CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.jornada
    ADD CONSTRAINT pk_jornada PRIMARY KEY (id_jornada);


--
-- Name: jugador_inscripcion pk_jugador_inscripcion; Type: CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.jugador_inscripcion
    ADD CONSTRAINT pk_jugador_inscripcion PRIMARY KEY (id_jugador_inscripcion);


--
-- Name: jugador_partido pk_jugador_partido; Type: CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.jugador_partido
    ADD CONSTRAINT pk_jugador_partido PRIMARY KEY (id_jugador_partido);


--
-- Name: lugar pk_lugar; Type: CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.lugar
    ADD CONSTRAINT pk_lugar PRIMARY KEY (id_lugar);


--
-- Name: partido pk_partido; Type: CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.partido
    ADD CONSTRAINT pk_partido PRIMARY KEY (id_partido);


--
-- Name: partido_equipo pk_partido_equipo; Type: CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.partido_equipo
    ADD CONSTRAINT pk_partido_equipo PRIMARY KEY (id_partido_equipo);


--
-- Name: regla pk_regla; Type: CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.regla
    ADD CONSTRAINT pk_regla PRIMARY KEY (id_regla);


--
-- Name: resultado_torneo pk_resultado_torneo; Type: CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.resultado_torneo
    ADD CONSTRAINT pk_resultado_torneo PRIMARY KEY (id_resultado_torneo);


--
-- Name: torneo pk_torneo; Type: CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.torneo
    ADD CONSTRAINT pk_torneo PRIMARY KEY (id_torneo);


--
-- Name: torneo_regla pk_torneo_regla; Type: CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.torneo_regla
    ADD CONSTRAINT pk_torneo_regla PRIMARY KEY (id_torneo_regla);


--
-- Name: usuario_torneo_rol pk_usuario_torneo_rol; Type: CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.usuario_torneo_rol
    ADD CONSTRAINT pk_usuario_torneo_rol PRIMARY KEY (id_usuario_torneo_rol);


--
-- Name: deporte uq_deporte_codigo; Type: CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.deporte
    ADD CONSTRAINT uq_deporte_codigo UNIQUE (codigo);


--
-- Name: equipo_grupo uq_equipo_grupo_fase_inscripcion; Type: CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.equipo_grupo
    ADD CONSTRAINT uq_equipo_grupo_fase_inscripcion UNIQUE (id_fase_torneo, id_inscripcion);


--
-- Name: equipo_grupo uq_equipo_grupo_grupo_inscripcion; Type: CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.equipo_grupo
    ADD CONSTRAINT uq_equipo_grupo_grupo_inscripcion UNIQUE (id_grupo_torneo, id_inscripcion);


--
-- Name: fase_torneo uq_fase_torneo_nombre; Type: CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.fase_torneo
    ADD CONSTRAINT uq_fase_torneo_nombre UNIQUE (id_torneo, nombre);


--
-- Name: fase_torneo uq_fase_torneo_orden; Type: CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.fase_torneo
    ADD CONSTRAINT uq_fase_torneo_orden UNIQUE (id_torneo, numero_orden);


--
-- Name: grupo_torneo uq_grupo_torneo_codigo; Type: CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.grupo_torneo
    ADD CONSTRAINT uq_grupo_torneo_codigo UNIQUE (id_fase_torneo, codigo);


--
-- Name: grupo_torneo uq_grupo_torneo_nombre; Type: CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.grupo_torneo
    ADD CONSTRAINT uq_grupo_torneo_nombre UNIQUE (id_fase_torneo, nombre);


--
-- Name: inscripcion uq_inscripcion_torneo_equipo; Type: CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.inscripcion
    ADD CONSTRAINT uq_inscripcion_torneo_equipo UNIQUE (id_torneo, id_equipo);


--
-- Name: jornada uq_jornada_numero; Type: CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.jornada
    ADD CONSTRAINT uq_jornada_numero UNIQUE (id_fase_torneo, numero_jornada);


--
-- Name: jugador_inscripcion uq_jugador_inscripcion; Type: CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.jugador_inscripcion
    ADD CONSTRAINT uq_jugador_inscripcion UNIQUE (id_inscripcion, id_jugador);


--
-- Name: jugador_partido uq_jugador_partido; Type: CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.jugador_partido
    ADD CONSTRAINT uq_jugador_partido UNIQUE (id_partido, id_jugador_inscripcion);


--
-- Name: partido uq_partido_codigo; Type: CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.partido
    ADD CONSTRAINT uq_partido_codigo UNIQUE (codigo);


--
-- Name: partido_equipo uq_partido_condicion; Type: CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.partido_equipo
    ADD CONSTRAINT uq_partido_condicion UNIQUE (id_partido, id_condicion_equipo);


--
-- Name: partido_equipo uq_partido_equipo; Type: CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.partido_equipo
    ADD CONSTRAINT uq_partido_equipo UNIQUE (id_partido, id_inscripcion);


--
-- Name: partido uq_partido_jornada_numero; Type: CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.partido
    ADD CONSTRAINT uq_partido_jornada_numero UNIQUE (id_jornada, numero_partido);


--
-- Name: regla uq_regla_codigo; Type: CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.regla
    ADD CONSTRAINT uq_regla_codigo UNIQUE (codigo);


--
-- Name: resultado_torneo uq_resultado_torneo_inscripcion; Type: CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.resultado_torneo
    ADD CONSTRAINT uq_resultado_torneo_inscripcion UNIQUE (id_torneo, id_inscripcion);


--
-- Name: resultado_torneo uq_resultado_torneo_posicion; Type: CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.resultado_torneo
    ADD CONSTRAINT uq_resultado_torneo_posicion UNIQUE (id_torneo, posicion_final);


--
-- Name: torneo uq_torneo_codigo; Type: CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.torneo
    ADD CONSTRAINT uq_torneo_codigo UNIQUE (codigo);


--
-- Name: torneo_regla uq_torneo_regla; Type: CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.torneo_regla
    ADD CONSTRAINT uq_torneo_regla UNIQUE (id_torneo, id_regla);


--
-- Name: entrega_premio pk_entrega_premio; Type: CONSTRAINT; Schema: finanzas; Owner: -
--

ALTER TABLE ONLY finanzas.entrega_premio
    ADD CONSTRAINT pk_entrega_premio PRIMARY KEY (id_entrega_premio);


--
-- Name: pago pk_pago; Type: CONSTRAINT; Schema: finanzas; Owner: -
--

ALTER TABLE ONLY finanzas.pago
    ADD CONSTRAINT pk_pago PRIMARY KEY (id_pago);


--
-- Name: premio pk_premio; Type: CONSTRAINT; Schema: finanzas; Owner: -
--

ALTER TABLE ONLY finanzas.premio
    ADD CONSTRAINT pk_premio PRIMARY KEY (id_premio);


--
-- Name: torneo_premio pk_torneo_premio; Type: CONSTRAINT; Schema: finanzas; Owner: -
--

ALTER TABLE ONLY finanzas.torneo_premio
    ADD CONSTRAINT pk_torneo_premio PRIMARY KEY (id_torneo_premio);


--
-- Name: entrega_premio uq_entrega_premio_torneo_premio; Type: CONSTRAINT; Schema: finanzas; Owner: -
--

ALTER TABLE ONLY finanzas.entrega_premio
    ADD CONSTRAINT uq_entrega_premio_torneo_premio UNIQUE (id_torneo_premio);


--
-- Name: premio uq_premio_codigo; Type: CONSTRAINT; Schema: finanzas; Owner: -
--

ALTER TABLE ONLY finanzas.premio
    ADD CONSTRAINT uq_premio_codigo UNIQUE (codigo);


--
-- Name: torneo_premio uq_torneo_premio; Type: CONSTRAINT; Schema: finanzas; Owner: -
--

ALTER TABLE ONLY finanzas.torneo_premio
    ADD CONSTRAINT uq_torneo_premio UNIQUE (id_torneo, id_premio, posicion_objetivo);


--
-- Name: arbitro pk_arbitro; Type: CONSTRAINT; Schema: participantes; Owner: -
--

ALTER TABLE ONLY participantes.arbitro
    ADD CONSTRAINT pk_arbitro PRIMARY KEY (id_usuario);


--
-- Name: equipo pk_equipo; Type: CONSTRAINT; Schema: participantes; Owner: -
--

ALTER TABLE ONLY participantes.equipo
    ADD CONSTRAINT pk_equipo PRIMARY KEY (id_equipo);


--
-- Name: jugador pk_jugador; Type: CONSTRAINT; Schema: participantes; Owner: -
--

ALTER TABLE ONLY participantes.jugador
    ADD CONSTRAINT pk_jugador PRIMARY KEY (id_usuario);


--
-- Name: jugador_equipo pk_jugador_equipo; Type: CONSTRAINT; Schema: participantes; Owner: -
--

ALTER TABLE ONLY participantes.jugador_equipo
    ADD CONSTRAINT pk_jugador_equipo PRIMARY KEY (id_jugador_equipo);


--
-- Name: organizador pk_organizador; Type: CONSTRAINT; Schema: participantes; Owner: -
--

ALTER TABLE ONLY participantes.organizador
    ADD CONSTRAINT pk_organizador PRIMARY KEY (id_usuario);


--
-- Name: arbitro uq_arbitro_numero_licencia; Type: CONSTRAINT; Schema: participantes; Owner: -
--

ALTER TABLE ONLY participantes.arbitro
    ADD CONSTRAINT uq_arbitro_numero_licencia UNIQUE (numero_licencia);


--
-- Name: equipo uq_equipo_nombre; Type: CONSTRAINT; Schema: participantes; Owner: -
--

ALTER TABLE ONLY participantes.equipo
    ADD CONSTRAINT uq_equipo_nombre UNIQUE (nombre);


--
-- Name: equipo uq_equipo_sigla; Type: CONSTRAINT; Schema: participantes; Owner: -
--

ALTER TABLE ONLY participantes.equipo
    ADD CONSTRAINT uq_equipo_sigla UNIQUE (sigla);


--
-- Name: rol pk_rol; Type: CONSTRAINT; Schema: seguridad; Owner: -
--

ALTER TABLE ONLY seguridad.rol
    ADD CONSTRAINT pk_rol PRIMARY KEY (id_rol);


--
-- Name: usuario pk_usuario; Type: CONSTRAINT; Schema: seguridad; Owner: -
--

ALTER TABLE ONLY seguridad.usuario
    ADD CONSTRAINT pk_usuario PRIMARY KEY (id_usuario);


--
-- Name: usuario_rol pk_usuario_rol; Type: CONSTRAINT; Schema: seguridad; Owner: -
--

ALTER TABLE ONLY seguridad.usuario_rol
    ADD CONSTRAINT pk_usuario_rol PRIMARY KEY (id_usuario_rol);


--
-- Name: rol uq_rol_codigo; Type: CONSTRAINT; Schema: seguridad; Owner: -
--

ALTER TABLE ONLY seguridad.rol
    ADD CONSTRAINT uq_rol_codigo UNIQUE (codigo);


--
-- Name: usuario uq_usuario_documento; Type: CONSTRAINT; Schema: seguridad; Owner: -
--

ALTER TABLE ONLY seguridad.usuario
    ADD CONSTRAINT uq_usuario_documento UNIQUE (id_tipo_documento, numero_documento);


--
-- Name: ix_auditoria_dml_identificador_gin; Type: INDEX; Schema: auditoria; Owner: -
--

CREATE INDEX ix_auditoria_dml_identificador_gin ON auditoria.auditoria_dml USING gin (identificador_registro);


--
-- Name: ix_auditoria_dml_operacion; Type: INDEX; Schema: auditoria; Owner: -
--

CREATE INDEX ix_auditoria_dml_operacion ON auditoria.auditoria_dml USING btree (operacion, fecha_evento DESC);


--
-- Name: ix_auditoria_dml_solicitud; Type: INDEX; Schema: auditoria; Owner: -
--

CREATE INDEX ix_auditoria_dml_solicitud ON auditoria.auditoria_dml USING btree (id_solicitud) WHERE (id_solicitud IS NOT NULL);


--
-- Name: ix_auditoria_dml_tabla; Type: INDEX; Schema: auditoria; Owner: -
--

CREATE INDEX ix_auditoria_dml_tabla ON auditoria.auditoria_dml USING btree (esquema, tabla, fecha_evento DESC);


--
-- Name: ix_auditoria_dml_transaccion; Type: INDEX; Schema: auditoria; Owner: -
--

CREATE INDEX ix_auditoria_dml_transaccion ON auditoria.auditoria_dml USING btree (id_transaccion);


--
-- Name: ix_auditoria_dml_usuario; Type: INDEX; Schema: auditoria; Owner: -
--

CREATE INDEX ix_auditoria_dml_usuario ON auditoria.auditoria_dml USING btree (usuario_aplicacion, fecha_evento DESC);


--
-- Name: ix_historial_entrega_premio; Type: INDEX; Schema: auditoria; Owner: -
--

CREATE INDEX ix_historial_entrega_premio ON auditoria.historial_entrega_premio USING btree (id_entrega_premio, fecha_cambio);


--
-- Name: ix_historial_inscripcion; Type: INDEX; Schema: auditoria; Owner: -
--

CREATE INDEX ix_historial_inscripcion ON auditoria.historial_estado_inscripcion USING btree (id_inscripcion, fecha_cambio);


--
-- Name: ix_historial_pago; Type: INDEX; Schema: auditoria; Owner: -
--

CREATE INDEX ix_historial_pago ON auditoria.historial_estado_pago USING btree (id_pago, fecha_cambio);


--
-- Name: ix_historial_partido; Type: INDEX; Schema: auditoria; Owner: -
--

CREATE INDEX ix_historial_partido ON auditoria.historial_estado_partido USING btree (id_partido, fecha_cambio);


--
-- Name: ix_arbitro_partido_arbitro; Type: INDEX; Schema: competencia; Owner: -
--

CREATE INDEX ix_arbitro_partido_arbitro ON competencia.arbitro_partido USING btree (id_arbitro);


--
-- Name: ix_equipo_grupo_grupo; Type: INDEX; Schema: competencia; Owner: -
--

CREATE INDEX ix_equipo_grupo_grupo ON competencia.equipo_grupo USING btree (id_grupo_torneo);


--
-- Name: ix_fase_torneo_torneo; Type: INDEX; Schema: competencia; Owner: -
--

CREATE INDEX ix_fase_torneo_torneo ON competencia.fase_torneo USING btree (id_torneo);


--
-- Name: ix_grupo_torneo_fase; Type: INDEX; Schema: competencia; Owner: -
--

CREATE INDEX ix_grupo_torneo_fase ON competencia.grupo_torneo USING btree (id_fase_torneo);


--
-- Name: ix_inscripcion_equipo; Type: INDEX; Schema: competencia; Owner: -
--

CREATE INDEX ix_inscripcion_equipo ON competencia.inscripcion USING btree (id_equipo);


--
-- Name: ix_inscripcion_torneo; Type: INDEX; Schema: competencia; Owner: -
--

CREATE INDEX ix_inscripcion_torneo ON competencia.inscripcion USING btree (id_torneo);


--
-- Name: ix_jornada_fase; Type: INDEX; Schema: competencia; Owner: -
--

CREATE INDEX ix_jornada_fase ON competencia.jornada USING btree (id_fase_torneo);


--
-- Name: ix_jugador_inscripcion_jugador; Type: INDEX; Schema: competencia; Owner: -
--

CREATE INDEX ix_jugador_inscripcion_jugador ON competencia.jugador_inscripcion USING btree (id_jugador);


--
-- Name: ix_jugador_partido_partido; Type: INDEX; Schema: competencia; Owner: -
--

CREATE INDEX ix_jugador_partido_partido ON competencia.jugador_partido USING btree (id_partido);


--
-- Name: ix_partido_equipo_inscripcion; Type: INDEX; Schema: competencia; Owner: -
--

CREATE INDEX ix_partido_equipo_inscripcion ON competencia.partido_equipo USING btree (id_inscripcion);


--
-- Name: ix_partido_equipo_partido; Type: INDEX; Schema: competencia; Owner: -
--

CREATE INDEX ix_partido_equipo_partido ON competencia.partido_equipo USING btree (id_partido);


--
-- Name: ix_partido_jornada; Type: INDEX; Schema: competencia; Owner: -
--

CREATE INDEX ix_partido_jornada ON competencia.partido USING btree (id_jornada);


--
-- Name: ix_partido_lugar; Type: INDEX; Schema: competencia; Owner: -
--

CREATE INDEX ix_partido_lugar ON competencia.partido USING btree (id_lugar);


--
-- Name: ix_resultado_torneo_torneo; Type: INDEX; Schema: competencia; Owner: -
--

CREATE INDEX ix_resultado_torneo_torneo ON competencia.resultado_torneo USING btree (id_torneo);


--
-- Name: ix_torneo_deporte; Type: INDEX; Schema: competencia; Owner: -
--

CREATE INDEX ix_torneo_deporte ON competencia.torneo USING btree (id_deporte);


--
-- Name: ix_usuario_torneo_rol_usuario; Type: INDEX; Schema: competencia; Owner: -
--

CREATE INDEX ix_usuario_torneo_rol_usuario ON competencia.usuario_torneo_rol USING btree (id_usuario);


--
-- Name: uq_arbitro_partido_arbitro_activo; Type: INDEX; Schema: competencia; Owner: -
--

CREATE UNIQUE INDEX uq_arbitro_partido_arbitro_activo ON competencia.arbitro_partido USING btree (id_partido, id_arbitro) WHERE ((activo = true) AND (fecha_fin IS NULL));


--
-- Name: uq_arbitro_partido_tipo_activo; Type: INDEX; Schema: competencia; Owner: -
--

CREATE UNIQUE INDEX uq_arbitro_partido_tipo_activo ON competencia.arbitro_partido USING btree (id_partido, id_tipo_arbitro_partido) WHERE ((activo = true) AND (fecha_fin IS NULL));


--
-- Name: uq_deporte_nombre_minuscula; Type: INDEX; Schema: competencia; Owner: -
--

CREATE UNIQUE INDEX uq_deporte_nombre_minuscula ON competencia.deporte USING btree (lower((nombre)::text));


--
-- Name: uq_deporte_regla_activa; Type: INDEX; Schema: competencia; Owner: -
--

CREATE UNIQUE INDEX uq_deporte_regla_activa ON competencia.deporte_regla USING btree (id_deporte, id_regla) WHERE ((activo = true) AND (fecha_fin IS NULL));


--
-- Name: uq_equipo_grupo_posicion_sorteo; Type: INDEX; Schema: competencia; Owner: -
--

CREATE UNIQUE INDEX uq_equipo_grupo_posicion_sorteo ON competencia.equipo_grupo USING btree (id_grupo_torneo, posicion_sorteo) WHERE (posicion_sorteo IS NOT NULL);


--
-- Name: uq_jugador_inscripcion_camiseta_activa; Type: INDEX; Schema: competencia; Owner: -
--

CREATE UNIQUE INDEX uq_jugador_inscripcion_camiseta_activa ON competencia.jugador_inscripcion USING btree (id_inscripcion, numero_camiseta) WHERE ((fecha_baja IS NULL) AND (numero_camiseta IS NOT NULL));


--
-- Name: uq_jugador_inscripcion_capitan_activo; Type: INDEX; Schema: competencia; Owner: -
--

CREATE UNIQUE INDEX uq_jugador_inscripcion_capitan_activo ON competencia.jugador_inscripcion USING btree (id_inscripcion) WHERE ((es_capitan = true) AND (fecha_baja IS NULL));


--
-- Name: uq_jugador_inscripcion_delegado_activo; Type: INDEX; Schema: competencia; Owner: -
--

CREATE UNIQUE INDEX uq_jugador_inscripcion_delegado_activo ON competencia.jugador_inscripcion USING btree (id_inscripcion) WHERE ((es_delegado = true) AND (fecha_baja IS NULL));


--
-- Name: uq_lugar_nombre_direccion; Type: INDEX; Schema: competencia; Owner: -
--

CREATE UNIQUE INDEX uq_lugar_nombre_direccion ON competencia.lugar USING btree (lower((nombre)::text), lower((direccion)::text));


--
-- Name: uq_usuario_torneo_rol_activo; Type: INDEX; Schema: competencia; Owner: -
--

CREATE UNIQUE INDEX uq_usuario_torneo_rol_activo ON competencia.usuario_torneo_rol USING btree (id_torneo, id_usuario, id_rol_torneo) WHERE ((activo = true) AND (fecha_fin IS NULL));


--
-- Name: ix_entrega_premio_resultado; Type: INDEX; Schema: finanzas; Owner: -
--

CREATE INDEX ix_entrega_premio_resultado ON finanzas.entrega_premio USING btree (id_resultado_torneo);


--
-- Name: ix_pago_inscripcion; Type: INDEX; Schema: finanzas; Owner: -
--

CREATE INDEX ix_pago_inscripcion ON finanzas.pago USING btree (id_inscripcion);


--
-- Name: ix_torneo_premio_torneo; Type: INDEX; Schema: finanzas; Owner: -
--

CREATE INDEX ix_torneo_premio_torneo ON finanzas.torneo_premio USING btree (id_torneo);


--
-- Name: uq_pago_referencia; Type: INDEX; Schema: finanzas; Owner: -
--

CREATE UNIQUE INDEX uq_pago_referencia ON finanzas.pago USING btree (referencia) WHERE (referencia IS NOT NULL);


--
-- Name: ix_jugador_equipo_equipo; Type: INDEX; Schema: participantes; Owner: -
--

CREATE INDEX ix_jugador_equipo_equipo ON participantes.jugador_equipo USING btree (id_equipo);


--
-- Name: ix_jugador_equipo_jugador; Type: INDEX; Schema: participantes; Owner: -
--

CREATE INDEX ix_jugador_equipo_jugador ON participantes.jugador_equipo USING btree (id_jugador);


--
-- Name: uq_equipo_delegado_activo; Type: INDEX; Schema: participantes; Owner: -
--

CREATE UNIQUE INDEX uq_equipo_delegado_activo ON participantes.jugador_equipo USING btree (id_equipo) WHERE ((es_delegado = true) AND (fecha_fin IS NULL));


--
-- Name: uq_jugador_equipo_membresia_activa; Type: INDEX; Schema: participantes; Owner: -
--

CREATE UNIQUE INDEX uq_jugador_equipo_membresia_activa ON participantes.jugador_equipo USING btree (id_jugador, id_equipo) WHERE (fecha_fin IS NULL);


--
-- Name: uq_usuario_correo_minuscula; Type: INDEX; Schema: seguridad; Owner: -
--

CREATE UNIQUE INDEX uq_usuario_correo_minuscula ON seguridad.usuario USING btree (lower((correo)::text));


--
-- Name: uq_usuario_rol_activo; Type: INDEX; Schema: seguridad; Owner: -
--

CREATE UNIQUE INDEX uq_usuario_rol_activo ON seguridad.usuario_rol USING btree (id_usuario, id_rol) WHERE ((activo = true) AND (fecha_fin IS NULL));


--
-- Name: auditoria_dml trg_proteger_auditoria_dml; Type: TRIGGER; Schema: auditoria; Owner: -
--

CREATE TRIGGER trg_proteger_auditoria_dml BEFORE DELETE OR UPDATE ON auditoria.auditoria_dml FOR EACH ROW EXECUTE FUNCTION auditoria.fn_proteger_auditoria_dml();


--
-- Name: inscripcion trg_01_validar_inscripcion; Type: TRIGGER; Schema: competencia; Owner: -
--

CREATE TRIGGER trg_01_validar_inscripcion BEFORE INSERT OR UPDATE ON competencia.inscripcion FOR EACH ROW EXECUTE FUNCTION competencia.fn_validar_inscripcion();


--
-- Name: partido trg_01_validar_partido; Type: TRIGGER; Schema: competencia; Owner: -
--

CREATE TRIGGER trg_01_validar_partido BEFORE INSERT OR UPDATE ON competencia.partido FOR EACH ROW EXECUTE FUNCTION competencia.fn_validar_partido();


--
-- Name: torneo trg_01_validar_torneo; Type: TRIGGER; Schema: competencia; Owner: -
--

CREATE TRIGGER trg_01_validar_torneo BEFORE INSERT OR UPDATE ON competencia.torneo FOR EACH ROW EXECUTE FUNCTION competencia.fn_validar_torneo();


--
-- Name: inscripcion trg_02_validar_transicion_inscripcion; Type: TRIGGER; Schema: competencia; Owner: -
--

CREATE TRIGGER trg_02_validar_transicion_inscripcion BEFORE UPDATE OF id_estado_inscripcion ON competencia.inscripcion FOR EACH ROW EXECUTE FUNCTION competencia.fn_validar_transicion_inscripcion();


--
-- Name: partido trg_02_validar_transicion_partido; Type: TRIGGER; Schema: competencia; Owner: -
--

CREATE TRIGGER trg_02_validar_transicion_partido BEFORE UPDATE OF id_estado_partido ON competencia.partido FOR EACH ROW EXECUTE FUNCTION competencia.fn_validar_transicion_partido();


--
-- Name: torneo trg_02_validar_transicion_torneo; Type: TRIGGER; Schema: competencia; Owner: -
--

CREATE TRIGGER trg_02_validar_transicion_torneo BEFORE UPDATE OF id_estado_torneo ON competencia.torneo FOR EACH ROW EXECUTE FUNCTION competencia.fn_validar_transicion_torneo();


--
-- Name: partido trg_03_calcular_resultado_partido; Type: TRIGGER; Schema: competencia; Owner: -
--

CREATE TRIGGER trg_03_calcular_resultado_partido BEFORE UPDATE OF id_estado_partido ON competencia.partido FOR EACH ROW EXECUTE FUNCTION competencia.fn_calcular_resultado_partido();


--
-- Name: inscripcion trg_03_historial_inscripcion; Type: TRIGGER; Schema: competencia; Owner: -
--

CREATE TRIGGER trg_03_historial_inscripcion AFTER INSERT OR UPDATE OF id_estado_inscripcion ON competencia.inscripcion FOR EACH ROW EXECUTE FUNCTION auditoria.fn_historial_inscripcion();


--
-- Name: partido trg_04_historial_partido; Type: TRIGGER; Schema: competencia; Owner: -
--

CREATE TRIGGER trg_04_historial_partido AFTER INSERT OR UPDATE OF id_estado_partido ON competencia.partido FOR EACH ROW EXECUTE FUNCTION auditoria.fn_historial_partido();


--
-- Name: arbitro_partido trg_auditoria_dml; Type: TRIGGER; Schema: competencia; Owner: -
--

CREATE TRIGGER trg_auditoria_dml AFTER INSERT OR DELETE OR UPDATE ON competencia.arbitro_partido FOR EACH ROW EXECUTE FUNCTION auditoria.fn_registrar_auditoria_dml();


--
-- Name: deporte trg_auditoria_dml; Type: TRIGGER; Schema: competencia; Owner: -
--

CREATE TRIGGER trg_auditoria_dml AFTER INSERT OR DELETE OR UPDATE ON competencia.deporte FOR EACH ROW EXECUTE FUNCTION auditoria.fn_registrar_auditoria_dml();


--
-- Name: deporte_regla trg_auditoria_dml; Type: TRIGGER; Schema: competencia; Owner: -
--

CREATE TRIGGER trg_auditoria_dml AFTER INSERT OR DELETE OR UPDATE ON competencia.deporte_regla FOR EACH ROW EXECUTE FUNCTION auditoria.fn_registrar_auditoria_dml();


--
-- Name: equipo_grupo trg_auditoria_dml; Type: TRIGGER; Schema: competencia; Owner: -
--

CREATE TRIGGER trg_auditoria_dml AFTER INSERT OR DELETE OR UPDATE ON competencia.equipo_grupo FOR EACH ROW EXECUTE FUNCTION auditoria.fn_registrar_auditoria_dml();


--
-- Name: fase_torneo trg_auditoria_dml; Type: TRIGGER; Schema: competencia; Owner: -
--

CREATE TRIGGER trg_auditoria_dml AFTER INSERT OR DELETE OR UPDATE ON competencia.fase_torneo FOR EACH ROW EXECUTE FUNCTION auditoria.fn_registrar_auditoria_dml();


--
-- Name: grupo_torneo trg_auditoria_dml; Type: TRIGGER; Schema: competencia; Owner: -
--

CREATE TRIGGER trg_auditoria_dml AFTER INSERT OR DELETE OR UPDATE ON competencia.grupo_torneo FOR EACH ROW EXECUTE FUNCTION auditoria.fn_registrar_auditoria_dml();


--
-- Name: inscripcion trg_auditoria_dml; Type: TRIGGER; Schema: competencia; Owner: -
--

CREATE TRIGGER trg_auditoria_dml AFTER INSERT OR DELETE OR UPDATE ON competencia.inscripcion FOR EACH ROW EXECUTE FUNCTION auditoria.fn_registrar_auditoria_dml();


--
-- Name: jornada trg_auditoria_dml; Type: TRIGGER; Schema: competencia; Owner: -
--

CREATE TRIGGER trg_auditoria_dml AFTER INSERT OR DELETE OR UPDATE ON competencia.jornada FOR EACH ROW EXECUTE FUNCTION auditoria.fn_registrar_auditoria_dml();


--
-- Name: jugador_inscripcion trg_auditoria_dml; Type: TRIGGER; Schema: competencia; Owner: -
--

CREATE TRIGGER trg_auditoria_dml AFTER INSERT OR DELETE OR UPDATE ON competencia.jugador_inscripcion FOR EACH ROW EXECUTE FUNCTION auditoria.fn_registrar_auditoria_dml();


--
-- Name: jugador_partido trg_auditoria_dml; Type: TRIGGER; Schema: competencia; Owner: -
--

CREATE TRIGGER trg_auditoria_dml AFTER INSERT OR DELETE OR UPDATE ON competencia.jugador_partido FOR EACH ROW EXECUTE FUNCTION auditoria.fn_registrar_auditoria_dml();


--
-- Name: lugar trg_auditoria_dml; Type: TRIGGER; Schema: competencia; Owner: -
--

CREATE TRIGGER trg_auditoria_dml AFTER INSERT OR DELETE OR UPDATE ON competencia.lugar FOR EACH ROW EXECUTE FUNCTION auditoria.fn_registrar_auditoria_dml();


--
-- Name: partido trg_auditoria_dml; Type: TRIGGER; Schema: competencia; Owner: -
--

CREATE TRIGGER trg_auditoria_dml AFTER INSERT OR DELETE OR UPDATE ON competencia.partido FOR EACH ROW EXECUTE FUNCTION auditoria.fn_registrar_auditoria_dml();


--
-- Name: partido_equipo trg_auditoria_dml; Type: TRIGGER; Schema: competencia; Owner: -
--

CREATE TRIGGER trg_auditoria_dml AFTER INSERT OR DELETE OR UPDATE ON competencia.partido_equipo FOR EACH ROW EXECUTE FUNCTION auditoria.fn_registrar_auditoria_dml();


--
-- Name: regla trg_auditoria_dml; Type: TRIGGER; Schema: competencia; Owner: -
--

CREATE TRIGGER trg_auditoria_dml AFTER INSERT OR DELETE OR UPDATE ON competencia.regla FOR EACH ROW EXECUTE FUNCTION auditoria.fn_registrar_auditoria_dml();


--
-- Name: resultado_torneo trg_auditoria_dml; Type: TRIGGER; Schema: competencia; Owner: -
--

CREATE TRIGGER trg_auditoria_dml AFTER INSERT OR DELETE OR UPDATE ON competencia.resultado_torneo FOR EACH ROW EXECUTE FUNCTION auditoria.fn_registrar_auditoria_dml();


--
-- Name: torneo trg_auditoria_dml; Type: TRIGGER; Schema: competencia; Owner: -
--

CREATE TRIGGER trg_auditoria_dml AFTER INSERT OR DELETE OR UPDATE ON competencia.torneo FOR EACH ROW EXECUTE FUNCTION auditoria.fn_registrar_auditoria_dml();


--
-- Name: torneo_regla trg_auditoria_dml; Type: TRIGGER; Schema: competencia; Owner: -
--

CREATE TRIGGER trg_auditoria_dml AFTER INSERT OR DELETE OR UPDATE ON competencia.torneo_regla FOR EACH ROW EXECUTE FUNCTION auditoria.fn_registrar_auditoria_dml();


--
-- Name: usuario_torneo_rol trg_auditoria_dml; Type: TRIGGER; Schema: competencia; Owner: -
--

CREATE TRIGGER trg_auditoria_dml AFTER INSERT OR DELETE OR UPDATE ON competencia.usuario_torneo_rol FOR EACH ROW EXECUTE FUNCTION auditoria.fn_registrar_auditoria_dml();


--
-- Name: arbitro_partido trg_validar_arbitro_partido; Type: TRIGGER; Schema: competencia; Owner: -
--

CREATE TRIGGER trg_validar_arbitro_partido BEFORE INSERT OR UPDATE ON competencia.arbitro_partido FOR EACH ROW EXECUTE FUNCTION competencia.fn_validar_arbitro_partido();


--
-- Name: equipo_grupo trg_validar_equipo_grupo; Type: TRIGGER; Schema: competencia; Owner: -
--

CREATE TRIGGER trg_validar_equipo_grupo BEFORE INSERT OR UPDATE ON competencia.equipo_grupo FOR EACH ROW EXECUTE FUNCTION competencia.fn_validar_equipo_grupo();


--
-- Name: fase_torneo trg_validar_fase_torneo; Type: TRIGGER; Schema: competencia; Owner: -
--

CREATE TRIGGER trg_validar_fase_torneo BEFORE INSERT OR UPDATE ON competencia.fase_torneo FOR EACH ROW EXECUTE FUNCTION competencia.fn_validar_fase_torneo();


--
-- Name: grupo_torneo trg_validar_grupo_torneo; Type: TRIGGER; Schema: competencia; Owner: -
--

CREATE TRIGGER trg_validar_grupo_torneo BEFORE INSERT OR UPDATE ON competencia.grupo_torneo FOR EACH ROW EXECUTE FUNCTION competencia.fn_validar_grupo_torneo();


--
-- Name: jornada trg_validar_jornada; Type: TRIGGER; Schema: competencia; Owner: -
--

CREATE TRIGGER trg_validar_jornada BEFORE INSERT OR UPDATE ON competencia.jornada FOR EACH ROW EXECUTE FUNCTION competencia.fn_validar_jornada();


--
-- Name: jugador_inscripcion trg_validar_jugador_inscripcion; Type: TRIGGER; Schema: competencia; Owner: -
--

CREATE TRIGGER trg_validar_jugador_inscripcion BEFORE INSERT OR UPDATE ON competencia.jugador_inscripcion FOR EACH ROW EXECUTE FUNCTION competencia.fn_validar_jugador_inscripcion();


--
-- Name: jugador_partido trg_validar_jugador_partido; Type: TRIGGER; Schema: competencia; Owner: -
--

CREATE TRIGGER trg_validar_jugador_partido BEFORE INSERT OR UPDATE ON competencia.jugador_partido FOR EACH ROW EXECUTE FUNCTION competencia.fn_validar_jugador_partido();


--
-- Name: partido_equipo trg_validar_partido_equipo; Type: TRIGGER; Schema: competencia; Owner: -
--

CREATE TRIGGER trg_validar_partido_equipo BEFORE INSERT OR UPDATE ON competencia.partido_equipo FOR EACH ROW EXECUTE FUNCTION competencia.fn_validar_partido_equipo();


--
-- Name: resultado_torneo trg_validar_resultado_torneo; Type: TRIGGER; Schema: competencia; Owner: -
--

CREATE TRIGGER trg_validar_resultado_torneo BEFORE INSERT OR UPDATE ON competencia.resultado_torneo FOR EACH ROW EXECUTE FUNCTION competencia.fn_validar_resultado_torneo();


--
-- Name: usuario_torneo_rol trg_validar_rol_torneo; Type: TRIGGER; Schema: competencia; Owner: -
--

CREATE TRIGGER trg_validar_rol_torneo BEFORE INSERT OR UPDATE ON competencia.usuario_torneo_rol FOR EACH ROW EXECUTE FUNCTION competencia.fn_validar_rol_torneo();


--
-- Name: entrega_premio trg_01_validar_entrega_premio; Type: TRIGGER; Schema: finanzas; Owner: -
--

CREATE TRIGGER trg_01_validar_entrega_premio BEFORE INSERT OR DELETE OR UPDATE ON finanzas.entrega_premio FOR EACH ROW EXECUTE FUNCTION finanzas.fn_validar_entrega_premio();


--
-- Name: pago trg_01_validar_pago; Type: TRIGGER; Schema: finanzas; Owner: -
--

CREATE TRIGGER trg_01_validar_pago BEFORE INSERT OR DELETE OR UPDATE ON finanzas.pago FOR EACH ROW EXECUTE FUNCTION finanzas.fn_validar_pago();


--
-- Name: pago trg_02_actualizar_inscripcion_por_pago; Type: TRIGGER; Schema: finanzas; Owner: -
--

CREATE TRIGGER trg_02_actualizar_inscripcion_por_pago AFTER INSERT OR UPDATE OF id_estado_pago ON finanzas.pago FOR EACH ROW EXECUTE FUNCTION finanzas.fn_actualizar_inscripcion_por_pago();


--
-- Name: entrega_premio trg_02_historial_entrega_premio; Type: TRIGGER; Schema: finanzas; Owner: -
--

CREATE TRIGGER trg_02_historial_entrega_premio AFTER INSERT OR UPDATE OF id_estado_entrega_premio ON finanzas.entrega_premio FOR EACH ROW EXECUTE FUNCTION auditoria.fn_historial_entrega_premio();


--
-- Name: pago trg_03_historial_pago; Type: TRIGGER; Schema: finanzas; Owner: -
--

CREATE TRIGGER trg_03_historial_pago AFTER INSERT OR UPDATE OF id_estado_pago ON finanzas.pago FOR EACH ROW EXECUTE FUNCTION auditoria.fn_historial_pago();


--
-- Name: entrega_premio trg_auditoria_dml; Type: TRIGGER; Schema: finanzas; Owner: -
--

CREATE TRIGGER trg_auditoria_dml AFTER INSERT OR DELETE OR UPDATE ON finanzas.entrega_premio FOR EACH ROW EXECUTE FUNCTION auditoria.fn_registrar_auditoria_dml();


--
-- Name: pago trg_auditoria_dml; Type: TRIGGER; Schema: finanzas; Owner: -
--

CREATE TRIGGER trg_auditoria_dml AFTER INSERT OR DELETE OR UPDATE ON finanzas.pago FOR EACH ROW EXECUTE FUNCTION auditoria.fn_registrar_auditoria_dml();


--
-- Name: premio trg_auditoria_dml; Type: TRIGGER; Schema: finanzas; Owner: -
--

CREATE TRIGGER trg_auditoria_dml AFTER INSERT OR DELETE OR UPDATE ON finanzas.premio FOR EACH ROW EXECUTE FUNCTION auditoria.fn_registrar_auditoria_dml();


--
-- Name: torneo_premio trg_auditoria_dml; Type: TRIGGER; Schema: finanzas; Owner: -
--

CREATE TRIGGER trg_auditoria_dml AFTER INSERT OR DELETE OR UPDATE ON finanzas.torneo_premio FOR EACH ROW EXECUTE FUNCTION auditoria.fn_registrar_auditoria_dml();


--
-- Name: torneo_premio trg_validar_torneo_premio; Type: TRIGGER; Schema: finanzas; Owner: -
--

CREATE TRIGGER trg_validar_torneo_premio BEFORE INSERT OR UPDATE ON finanzas.torneo_premio FOR EACH ROW EXECUTE FUNCTION finanzas.fn_validar_torneo_premio();


--
-- Name: arbitro trg_auditoria_dml; Type: TRIGGER; Schema: participantes; Owner: -
--

CREATE TRIGGER trg_auditoria_dml AFTER INSERT OR DELETE OR UPDATE ON participantes.arbitro FOR EACH ROW EXECUTE FUNCTION auditoria.fn_registrar_auditoria_dml();


--
-- Name: equipo trg_auditoria_dml; Type: TRIGGER; Schema: participantes; Owner: -
--

CREATE TRIGGER trg_auditoria_dml AFTER INSERT OR DELETE OR UPDATE ON participantes.equipo FOR EACH ROW EXECUTE FUNCTION auditoria.fn_registrar_auditoria_dml();


--
-- Name: jugador trg_auditoria_dml; Type: TRIGGER; Schema: participantes; Owner: -
--

CREATE TRIGGER trg_auditoria_dml AFTER INSERT OR DELETE OR UPDATE ON participantes.jugador FOR EACH ROW EXECUTE FUNCTION auditoria.fn_registrar_auditoria_dml();


--
-- Name: jugador_equipo trg_auditoria_dml; Type: TRIGGER; Schema: participantes; Owner: -
--

CREATE TRIGGER trg_auditoria_dml AFTER INSERT OR DELETE OR UPDATE ON participantes.jugador_equipo FOR EACH ROW EXECUTE FUNCTION auditoria.fn_registrar_auditoria_dml();


--
-- Name: organizador trg_auditoria_dml; Type: TRIGGER; Schema: participantes; Owner: -
--

CREATE TRIGGER trg_auditoria_dml AFTER INSERT OR DELETE OR UPDATE ON participantes.organizador FOR EACH ROW EXECUTE FUNCTION auditoria.fn_registrar_auditoria_dml();


--
-- Name: jugador_equipo trg_validar_cambio_jugador_equipo; Type: TRIGGER; Schema: participantes; Owner: -
--

CREATE TRIGGER trg_validar_cambio_jugador_equipo BEFORE INSERT OR DELETE OR UPDATE ON participantes.jugador_equipo FOR EACH ROW EXECUTE FUNCTION participantes.fn_validar_cambio_jugador_equipo();


--
-- Name: rol trg_auditoria_dml; Type: TRIGGER; Schema: seguridad; Owner: -
--

CREATE TRIGGER trg_auditoria_dml AFTER INSERT OR DELETE OR UPDATE ON seguridad.rol FOR EACH ROW EXECUTE FUNCTION auditoria.fn_registrar_auditoria_dml();


--
-- Name: usuario trg_auditoria_dml; Type: TRIGGER; Schema: seguridad; Owner: -
--

CREATE TRIGGER trg_auditoria_dml AFTER INSERT OR DELETE OR UPDATE ON seguridad.usuario FOR EACH ROW EXECUTE FUNCTION auditoria.fn_registrar_auditoria_dml();


--
-- Name: usuario_rol trg_auditoria_dml; Type: TRIGGER; Schema: seguridad; Owner: -
--

CREATE TRIGGER trg_auditoria_dml AFTER INSERT OR DELETE OR UPDATE ON seguridad.usuario_rol FOR EACH ROW EXECUTE FUNCTION auditoria.fn_registrar_auditoria_dml();


--
-- Name: historial_entrega_premio fk_historial_entrega; Type: FK CONSTRAINT; Schema: auditoria; Owner: -
--

ALTER TABLE ONLY auditoria.historial_entrega_premio
    ADD CONSTRAINT fk_historial_entrega FOREIGN KEY (id_entrega_premio) REFERENCES finanzas.entrega_premio(id_entrega_premio);


--
-- Name: historial_entrega_premio fk_historial_entrega_estado_anterior; Type: FK CONSTRAINT; Schema: auditoria; Owner: -
--

ALTER TABLE ONLY auditoria.historial_entrega_premio
    ADD CONSTRAINT fk_historial_entrega_estado_anterior FOREIGN KEY (id_estado_anterior) REFERENCES catalogo.estado_entrega_premio(id_estado_entrega_premio);


--
-- Name: historial_entrega_premio fk_historial_entrega_estado_nuevo; Type: FK CONSTRAINT; Schema: auditoria; Owner: -
--

ALTER TABLE ONLY auditoria.historial_entrega_premio
    ADD CONSTRAINT fk_historial_entrega_estado_nuevo FOREIGN KEY (id_estado_nuevo) REFERENCES catalogo.estado_entrega_premio(id_estado_entrega_premio);


--
-- Name: historial_entrega_premio fk_historial_entrega_usuario; Type: FK CONSTRAINT; Schema: auditoria; Owner: -
--

ALTER TABLE ONLY auditoria.historial_entrega_premio
    ADD CONSTRAINT fk_historial_entrega_usuario FOREIGN KEY (usuario_aplicacion) REFERENCES seguridad.usuario(id_usuario);


--
-- Name: historial_estado_inscripcion fk_historial_inscripcion; Type: FK CONSTRAINT; Schema: auditoria; Owner: -
--

ALTER TABLE ONLY auditoria.historial_estado_inscripcion
    ADD CONSTRAINT fk_historial_inscripcion FOREIGN KEY (id_inscripcion) REFERENCES competencia.inscripcion(id_inscripcion);


--
-- Name: historial_estado_inscripcion fk_historial_inscripcion_estado_anterior; Type: FK CONSTRAINT; Schema: auditoria; Owner: -
--

ALTER TABLE ONLY auditoria.historial_estado_inscripcion
    ADD CONSTRAINT fk_historial_inscripcion_estado_anterior FOREIGN KEY (id_estado_anterior) REFERENCES catalogo.estado_inscripcion(id_estado_inscripcion);


--
-- Name: historial_estado_inscripcion fk_historial_inscripcion_estado_nuevo; Type: FK CONSTRAINT; Schema: auditoria; Owner: -
--

ALTER TABLE ONLY auditoria.historial_estado_inscripcion
    ADD CONSTRAINT fk_historial_inscripcion_estado_nuevo FOREIGN KEY (id_estado_nuevo) REFERENCES catalogo.estado_inscripcion(id_estado_inscripcion);


--
-- Name: historial_estado_inscripcion fk_historial_inscripcion_usuario; Type: FK CONSTRAINT; Schema: auditoria; Owner: -
--

ALTER TABLE ONLY auditoria.historial_estado_inscripcion
    ADD CONSTRAINT fk_historial_inscripcion_usuario FOREIGN KEY (usuario_aplicacion) REFERENCES seguridad.usuario(id_usuario);


--
-- Name: historial_estado_pago fk_historial_pago; Type: FK CONSTRAINT; Schema: auditoria; Owner: -
--

ALTER TABLE ONLY auditoria.historial_estado_pago
    ADD CONSTRAINT fk_historial_pago FOREIGN KEY (id_pago) REFERENCES finanzas.pago(id_pago);


--
-- Name: historial_estado_pago fk_historial_pago_estado_anterior; Type: FK CONSTRAINT; Schema: auditoria; Owner: -
--

ALTER TABLE ONLY auditoria.historial_estado_pago
    ADD CONSTRAINT fk_historial_pago_estado_anterior FOREIGN KEY (id_estado_anterior) REFERENCES catalogo.estado_pago(id_estado_pago);


--
-- Name: historial_estado_pago fk_historial_pago_estado_nuevo; Type: FK CONSTRAINT; Schema: auditoria; Owner: -
--

ALTER TABLE ONLY auditoria.historial_estado_pago
    ADD CONSTRAINT fk_historial_pago_estado_nuevo FOREIGN KEY (id_estado_nuevo) REFERENCES catalogo.estado_pago(id_estado_pago);


--
-- Name: historial_estado_pago fk_historial_pago_usuario; Type: FK CONSTRAINT; Schema: auditoria; Owner: -
--

ALTER TABLE ONLY auditoria.historial_estado_pago
    ADD CONSTRAINT fk_historial_pago_usuario FOREIGN KEY (usuario_aplicacion) REFERENCES seguridad.usuario(id_usuario);


--
-- Name: historial_estado_partido fk_historial_partido; Type: FK CONSTRAINT; Schema: auditoria; Owner: -
--

ALTER TABLE ONLY auditoria.historial_estado_partido
    ADD CONSTRAINT fk_historial_partido FOREIGN KEY (id_partido) REFERENCES competencia.partido(id_partido);


--
-- Name: historial_estado_partido fk_historial_partido_estado_anterior; Type: FK CONSTRAINT; Schema: auditoria; Owner: -
--

ALTER TABLE ONLY auditoria.historial_estado_partido
    ADD CONSTRAINT fk_historial_partido_estado_anterior FOREIGN KEY (id_estado_anterior) REFERENCES catalogo.estado_partido(id_estado_partido);


--
-- Name: historial_estado_partido fk_historial_partido_estado_nuevo; Type: FK CONSTRAINT; Schema: auditoria; Owner: -
--

ALTER TABLE ONLY auditoria.historial_estado_partido
    ADD CONSTRAINT fk_historial_partido_estado_nuevo FOREIGN KEY (id_estado_nuevo) REFERENCES catalogo.estado_partido(id_estado_partido);


--
-- Name: historial_estado_partido fk_historial_partido_usuario; Type: FK CONSTRAINT; Schema: auditoria; Owner: -
--

ALTER TABLE ONLY auditoria.historial_estado_partido
    ADD CONSTRAINT fk_historial_partido_usuario FOREIGN KEY (usuario_aplicacion) REFERENCES seguridad.usuario(id_usuario);


--
-- Name: conflicto_rol_torneo fk_conflicto_rol_a; Type: FK CONSTRAINT; Schema: catalogo; Owner: -
--

ALTER TABLE ONLY catalogo.conflicto_rol_torneo
    ADD CONSTRAINT fk_conflicto_rol_a FOREIGN KEY (id_rol_torneo_a) REFERENCES catalogo.rol_torneo(id_rol_torneo);


--
-- Name: conflicto_rol_torneo fk_conflicto_rol_b; Type: FK CONSTRAINT; Schema: catalogo; Owner: -
--

ALTER TABLE ONLY catalogo.conflicto_rol_torneo
    ADD CONSTRAINT fk_conflicto_rol_b FOREIGN KEY (id_rol_torneo_b) REFERENCES catalogo.rol_torneo(id_rol_torneo);


--
-- Name: arbitro_partido fk_arbitro_partido_arbitro; Type: FK CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.arbitro_partido
    ADD CONSTRAINT fk_arbitro_partido_arbitro FOREIGN KEY (id_arbitro) REFERENCES participantes.arbitro(id_usuario);


--
-- Name: arbitro_partido fk_arbitro_partido_asignado_por; Type: FK CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.arbitro_partido
    ADD CONSTRAINT fk_arbitro_partido_asignado_por FOREIGN KEY (asignado_por) REFERENCES seguridad.usuario(id_usuario);


--
-- Name: arbitro_partido fk_arbitro_partido_partido; Type: FK CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.arbitro_partido
    ADD CONSTRAINT fk_arbitro_partido_partido FOREIGN KEY (id_partido) REFERENCES competencia.partido(id_partido);


--
-- Name: arbitro_partido fk_arbitro_partido_tipo; Type: FK CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.arbitro_partido
    ADD CONSTRAINT fk_arbitro_partido_tipo FOREIGN KEY (id_tipo_arbitro_partido) REFERENCES catalogo.tipo_arbitro_partido(id_tipo_arbitro_partido);


--
-- Name: deporte fk_deporte_estado; Type: FK CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.deporte
    ADD CONSTRAINT fk_deporte_estado FOREIGN KEY (id_estado_deporte) REFERENCES catalogo.estado_deporte(id_estado_deporte);


--
-- Name: deporte_regla fk_deporte_regla_deporte; Type: FK CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.deporte_regla
    ADD CONSTRAINT fk_deporte_regla_deporte FOREIGN KEY (id_deporte) REFERENCES competencia.deporte(id_deporte);


--
-- Name: deporte_regla fk_deporte_regla_regla; Type: FK CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.deporte_regla
    ADD CONSTRAINT fk_deporte_regla_regla FOREIGN KEY (id_regla) REFERENCES competencia.regla(id_regla);


--
-- Name: equipo_grupo fk_equipo_grupo_asignado_por; Type: FK CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.equipo_grupo
    ADD CONSTRAINT fk_equipo_grupo_asignado_por FOREIGN KEY (asignado_por) REFERENCES seguridad.usuario(id_usuario);


--
-- Name: equipo_grupo fk_equipo_grupo_fase; Type: FK CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.equipo_grupo
    ADD CONSTRAINT fk_equipo_grupo_fase FOREIGN KEY (id_fase_torneo) REFERENCES competencia.fase_torneo(id_fase_torneo);


--
-- Name: equipo_grupo fk_equipo_grupo_grupo; Type: FK CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.equipo_grupo
    ADD CONSTRAINT fk_equipo_grupo_grupo FOREIGN KEY (id_grupo_torneo) REFERENCES competencia.grupo_torneo(id_grupo_torneo);


--
-- Name: equipo_grupo fk_equipo_grupo_inscripcion; Type: FK CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.equipo_grupo
    ADD CONSTRAINT fk_equipo_grupo_inscripcion FOREIGN KEY (id_inscripcion) REFERENCES competencia.inscripcion(id_inscripcion);


--
-- Name: fase_torneo fk_fase_torneo_estado; Type: FK CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.fase_torneo
    ADD CONSTRAINT fk_fase_torneo_estado FOREIGN KEY (id_estado_fase) REFERENCES catalogo.estado_fase(id_estado_fase);


--
-- Name: fase_torneo fk_fase_torneo_tipo; Type: FK CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.fase_torneo
    ADD CONSTRAINT fk_fase_torneo_tipo FOREIGN KEY (id_tipo_fase) REFERENCES catalogo.tipo_fase(id_tipo_fase);


--
-- Name: fase_torneo fk_fase_torneo_torneo; Type: FK CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.fase_torneo
    ADD CONSTRAINT fk_fase_torneo_torneo FOREIGN KEY (id_torneo) REFERENCES competencia.torneo(id_torneo);


--
-- Name: grupo_torneo fk_grupo_torneo_fase; Type: FK CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.grupo_torneo
    ADD CONSTRAINT fk_grupo_torneo_fase FOREIGN KEY (id_fase_torneo) REFERENCES competencia.fase_torneo(id_fase_torneo);


--
-- Name: inscripcion fk_inscripcion_equipo; Type: FK CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.inscripcion
    ADD CONSTRAINT fk_inscripcion_equipo FOREIGN KEY (id_equipo) REFERENCES participantes.equipo(id_equipo);


--
-- Name: inscripcion fk_inscripcion_estado; Type: FK CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.inscripcion
    ADD CONSTRAINT fk_inscripcion_estado FOREIGN KEY (id_estado_inscripcion) REFERENCES catalogo.estado_inscripcion(id_estado_inscripcion);


--
-- Name: inscripcion fk_inscripcion_registrado_por; Type: FK CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.inscripcion
    ADD CONSTRAINT fk_inscripcion_registrado_por FOREIGN KEY (registrado_por) REFERENCES seguridad.usuario(id_usuario);


--
-- Name: inscripcion fk_inscripcion_torneo; Type: FK CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.inscripcion
    ADD CONSTRAINT fk_inscripcion_torneo FOREIGN KEY (id_torneo) REFERENCES competencia.torneo(id_torneo);


--
-- Name: jornada fk_jornada_estado; Type: FK CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.jornada
    ADD CONSTRAINT fk_jornada_estado FOREIGN KEY (id_estado_jornada) REFERENCES catalogo.estado_jornada(id_estado_jornada);


--
-- Name: jornada fk_jornada_fase; Type: FK CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.jornada
    ADD CONSTRAINT fk_jornada_fase FOREIGN KEY (id_fase_torneo) REFERENCES competencia.fase_torneo(id_fase_torneo);


--
-- Name: jugador_inscripcion fk_jugador_inscripcion_estado; Type: FK CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.jugador_inscripcion
    ADD CONSTRAINT fk_jugador_inscripcion_estado FOREIGN KEY (id_estado_jugador_inscripcion) REFERENCES catalogo.estado_jugador_inscripcion(id_estado_jugador_inscripcion);


--
-- Name: jugador_inscripcion fk_jugador_inscripcion_inscripcion; Type: FK CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.jugador_inscripcion
    ADD CONSTRAINT fk_jugador_inscripcion_inscripcion FOREIGN KEY (id_inscripcion) REFERENCES competencia.inscripcion(id_inscripcion);


--
-- Name: jugador_inscripcion fk_jugador_inscripcion_jugador; Type: FK CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.jugador_inscripcion
    ADD CONSTRAINT fk_jugador_inscripcion_jugador FOREIGN KEY (id_jugador) REFERENCES participantes.jugador(id_usuario);


--
-- Name: jugador_inscripcion fk_jugador_inscripcion_membresia; Type: FK CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.jugador_inscripcion
    ADD CONSTRAINT fk_jugador_inscripcion_membresia FOREIGN KEY (id_jugador_equipo) REFERENCES participantes.jugador_equipo(id_jugador_equipo);


--
-- Name: jugador_inscripcion fk_jugador_inscripcion_registrado_por; Type: FK CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.jugador_inscripcion
    ADD CONSTRAINT fk_jugador_inscripcion_registrado_por FOREIGN KEY (registrado_por) REFERENCES seguridad.usuario(id_usuario);


--
-- Name: jugador_partido fk_jugador_partido_equipo; Type: FK CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.jugador_partido
    ADD CONSTRAINT fk_jugador_partido_equipo FOREIGN KEY (id_partido_equipo) REFERENCES competencia.partido_equipo(id_partido_equipo);


--
-- Name: jugador_partido fk_jugador_partido_inscripcion; Type: FK CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.jugador_partido
    ADD CONSTRAINT fk_jugador_partido_inscripcion FOREIGN KEY (id_jugador_inscripcion) REFERENCES competencia.jugador_inscripcion(id_jugador_inscripcion);


--
-- Name: jugador_partido fk_jugador_partido_partido; Type: FK CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.jugador_partido
    ADD CONSTRAINT fk_jugador_partido_partido FOREIGN KEY (id_partido) REFERENCES competencia.partido(id_partido);


--
-- Name: jugador_partido fk_jugador_partido_registrado_por; Type: FK CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.jugador_partido
    ADD CONSTRAINT fk_jugador_partido_registrado_por FOREIGN KEY (registrado_por) REFERENCES seguridad.usuario(id_usuario);


--
-- Name: partido fk_partido_actualizado_por; Type: FK CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.partido
    ADD CONSTRAINT fk_partido_actualizado_por FOREIGN KEY (actualizado_por) REFERENCES seguridad.usuario(id_usuario);


--
-- Name: partido fk_partido_creado_por; Type: FK CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.partido
    ADD CONSTRAINT fk_partido_creado_por FOREIGN KEY (creado_por) REFERENCES seguridad.usuario(id_usuario);


--
-- Name: partido_equipo fk_partido_equipo_condicion; Type: FK CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.partido_equipo
    ADD CONSTRAINT fk_partido_equipo_condicion FOREIGN KEY (id_condicion_equipo) REFERENCES catalogo.condicion_equipo_partido(id_condicion_equipo);


--
-- Name: partido_equipo fk_partido_equipo_inscripcion; Type: FK CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.partido_equipo
    ADD CONSTRAINT fk_partido_equipo_inscripcion FOREIGN KEY (id_inscripcion) REFERENCES competencia.inscripcion(id_inscripcion);


--
-- Name: partido_equipo fk_partido_equipo_partido; Type: FK CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.partido_equipo
    ADD CONSTRAINT fk_partido_equipo_partido FOREIGN KEY (id_partido) REFERENCES competencia.partido(id_partido);


--
-- Name: partido_equipo fk_partido_equipo_resultado; Type: FK CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.partido_equipo
    ADD CONSTRAINT fk_partido_equipo_resultado FOREIGN KEY (id_resultado_equipo_partido) REFERENCES catalogo.resultado_equipo_partido(id_resultado_equipo_partido);


--
-- Name: partido fk_partido_estado; Type: FK CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.partido
    ADD CONSTRAINT fk_partido_estado FOREIGN KEY (id_estado_partido) REFERENCES catalogo.estado_partido(id_estado_partido);


--
-- Name: partido fk_partido_grupo; Type: FK CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.partido
    ADD CONSTRAINT fk_partido_grupo FOREIGN KEY (id_grupo_torneo) REFERENCES competencia.grupo_torneo(id_grupo_torneo);


--
-- Name: partido fk_partido_jornada; Type: FK CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.partido
    ADD CONSTRAINT fk_partido_jornada FOREIGN KEY (id_jornada) REFERENCES competencia.jornada(id_jornada);


--
-- Name: partido fk_partido_lugar; Type: FK CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.partido
    ADD CONSTRAINT fk_partido_lugar FOREIGN KEY (id_lugar) REFERENCES competencia.lugar(id_lugar);


--
-- Name: partido fk_partido_siguiente; Type: FK CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.partido
    ADD CONSTRAINT fk_partido_siguiente FOREIGN KEY (id_partido_siguiente) REFERENCES competencia.partido(id_partido) ON DELETE SET NULL;


--
-- Name: resultado_torneo fk_resultado_torneo_generado_por; Type: FK CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.resultado_torneo
    ADD CONSTRAINT fk_resultado_torneo_generado_por FOREIGN KEY (generado_por) REFERENCES seguridad.usuario(id_usuario);


--
-- Name: resultado_torneo fk_resultado_torneo_inscripcion; Type: FK CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.resultado_torneo
    ADD CONSTRAINT fk_resultado_torneo_inscripcion FOREIGN KEY (id_inscripcion) REFERENCES competencia.inscripcion(id_inscripcion);


--
-- Name: resultado_torneo fk_resultado_torneo_torneo; Type: FK CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.resultado_torneo
    ADD CONSTRAINT fk_resultado_torneo_torneo FOREIGN KEY (id_torneo) REFERENCES competencia.torneo(id_torneo);


--
-- Name: torneo fk_torneo_creado_por; Type: FK CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.torneo
    ADD CONSTRAINT fk_torneo_creado_por FOREIGN KEY (creado_por) REFERENCES seguridad.usuario(id_usuario);


--
-- Name: torneo fk_torneo_deporte; Type: FK CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.torneo
    ADD CONSTRAINT fk_torneo_deporte FOREIGN KEY (id_deporte) REFERENCES competencia.deporte(id_deporte);


--
-- Name: torneo fk_torneo_estado; Type: FK CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.torneo
    ADD CONSTRAINT fk_torneo_estado FOREIGN KEY (id_estado_torneo) REFERENCES catalogo.estado_torneo(id_estado_torneo);


--
-- Name: torneo fk_torneo_formato; Type: FK CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.torneo
    ADD CONSTRAINT fk_torneo_formato FOREIGN KEY (id_formato_torneo) REFERENCES catalogo.formato_torneo(id_formato_torneo);


--
-- Name: torneo_regla fk_torneo_regla_regla; Type: FK CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.torneo_regla
    ADD CONSTRAINT fk_torneo_regla_regla FOREIGN KEY (id_regla) REFERENCES competencia.regla(id_regla);


--
-- Name: torneo_regla fk_torneo_regla_torneo; Type: FK CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.torneo_regla
    ADD CONSTRAINT fk_torneo_regla_torneo FOREIGN KEY (id_torneo) REFERENCES competencia.torneo(id_torneo);


--
-- Name: usuario_torneo_rol fk_usuario_torneo_rol_asignado_por; Type: FK CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.usuario_torneo_rol
    ADD CONSTRAINT fk_usuario_torneo_rol_asignado_por FOREIGN KEY (asignado_por) REFERENCES seguridad.usuario(id_usuario);


--
-- Name: usuario_torneo_rol fk_usuario_torneo_rol_rol; Type: FK CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.usuario_torneo_rol
    ADD CONSTRAINT fk_usuario_torneo_rol_rol FOREIGN KEY (id_rol_torneo) REFERENCES catalogo.rol_torneo(id_rol_torneo);


--
-- Name: usuario_torneo_rol fk_usuario_torneo_rol_torneo; Type: FK CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.usuario_torneo_rol
    ADD CONSTRAINT fk_usuario_torneo_rol_torneo FOREIGN KEY (id_torneo) REFERENCES competencia.torneo(id_torneo);


--
-- Name: usuario_torneo_rol fk_usuario_torneo_rol_usuario; Type: FK CONSTRAINT; Schema: competencia; Owner: -
--

ALTER TABLE ONLY competencia.usuario_torneo_rol
    ADD CONSTRAINT fk_usuario_torneo_rol_usuario FOREIGN KEY (id_usuario) REFERENCES seguridad.usuario(id_usuario);


--
-- Name: entrega_premio fk_entrega_premio_autorizado_por; Type: FK CONSTRAINT; Schema: finanzas; Owner: -
--

ALTER TABLE ONLY finanzas.entrega_premio
    ADD CONSTRAINT fk_entrega_premio_autorizado_por FOREIGN KEY (autorizado_por) REFERENCES seguridad.usuario(id_usuario);


--
-- Name: entrega_premio fk_entrega_premio_entregado_por; Type: FK CONSTRAINT; Schema: finanzas; Owner: -
--

ALTER TABLE ONLY finanzas.entrega_premio
    ADD CONSTRAINT fk_entrega_premio_entregado_por FOREIGN KEY (entregado_por) REFERENCES seguridad.usuario(id_usuario);


--
-- Name: entrega_premio fk_entrega_premio_estado; Type: FK CONSTRAINT; Schema: finanzas; Owner: -
--

ALTER TABLE ONLY finanzas.entrega_premio
    ADD CONSTRAINT fk_entrega_premio_estado FOREIGN KEY (id_estado_entrega_premio) REFERENCES catalogo.estado_entrega_premio(id_estado_entrega_premio);


--
-- Name: entrega_premio fk_entrega_premio_resultado; Type: FK CONSTRAINT; Schema: finanzas; Owner: -
--

ALTER TABLE ONLY finanzas.entrega_premio
    ADD CONSTRAINT fk_entrega_premio_resultado FOREIGN KEY (id_resultado_torneo) REFERENCES competencia.resultado_torneo(id_resultado_torneo);


--
-- Name: entrega_premio fk_entrega_premio_torneo_premio; Type: FK CONSTRAINT; Schema: finanzas; Owner: -
--

ALTER TABLE ONLY finanzas.entrega_premio
    ADD CONSTRAINT fk_entrega_premio_torneo_premio FOREIGN KEY (id_torneo_premio) REFERENCES finanzas.torneo_premio(id_torneo_premio);


--
-- Name: pago fk_pago_estado; Type: FK CONSTRAINT; Schema: finanzas; Owner: -
--

ALTER TABLE ONLY finanzas.pago
    ADD CONSTRAINT fk_pago_estado FOREIGN KEY (id_estado_pago) REFERENCES catalogo.estado_pago(id_estado_pago);


--
-- Name: pago fk_pago_inscripcion; Type: FK CONSTRAINT; Schema: finanzas; Owner: -
--

ALTER TABLE ONLY finanzas.pago
    ADD CONSTRAINT fk_pago_inscripcion FOREIGN KEY (id_inscripcion) REFERENCES competencia.inscripcion(id_inscripcion);


--
-- Name: pago fk_pago_metodo; Type: FK CONSTRAINT; Schema: finanzas; Owner: -
--

ALTER TABLE ONLY finanzas.pago
    ADD CONSTRAINT fk_pago_metodo FOREIGN KEY (id_metodo_pago) REFERENCES catalogo.metodo_pago(id_metodo_pago);


--
-- Name: pago fk_pago_registrado_por; Type: FK CONSTRAINT; Schema: finanzas; Owner: -
--

ALTER TABLE ONLY finanzas.pago
    ADD CONSTRAINT fk_pago_registrado_por FOREIGN KEY (registrado_por) REFERENCES seguridad.usuario(id_usuario);


--
-- Name: pago fk_pago_verificado_por; Type: FK CONSTRAINT; Schema: finanzas; Owner: -
--

ALTER TABLE ONLY finanzas.pago
    ADD CONSTRAINT fk_pago_verificado_por FOREIGN KEY (verificado_por) REFERENCES seguridad.usuario(id_usuario);


--
-- Name: premio fk_premio_tipo; Type: FK CONSTRAINT; Schema: finanzas; Owner: -
--

ALTER TABLE ONLY finanzas.premio
    ADD CONSTRAINT fk_premio_tipo FOREIGN KEY (id_tipo_premio) REFERENCES catalogo.tipo_premio(id_tipo_premio);


--
-- Name: torneo_premio fk_torneo_premio_premio; Type: FK CONSTRAINT; Schema: finanzas; Owner: -
--

ALTER TABLE ONLY finanzas.torneo_premio
    ADD CONSTRAINT fk_torneo_premio_premio FOREIGN KEY (id_premio) REFERENCES finanzas.premio(id_premio);


--
-- Name: torneo_premio fk_torneo_premio_registrado_por; Type: FK CONSTRAINT; Schema: finanzas; Owner: -
--

ALTER TABLE ONLY finanzas.torneo_premio
    ADD CONSTRAINT fk_torneo_premio_registrado_por FOREIGN KEY (registrado_por) REFERENCES seguridad.usuario(id_usuario);


--
-- Name: torneo_premio fk_torneo_premio_torneo; Type: FK CONSTRAINT; Schema: finanzas; Owner: -
--

ALTER TABLE ONLY finanzas.torneo_premio
    ADD CONSTRAINT fk_torneo_premio_torneo FOREIGN KEY (id_torneo) REFERENCES competencia.torneo(id_torneo);


--
-- Name: arbitro fk_arbitro_estado_perfil; Type: FK CONSTRAINT; Schema: participantes; Owner: -
--

ALTER TABLE ONLY participantes.arbitro
    ADD CONSTRAINT fk_arbitro_estado_perfil FOREIGN KEY (id_estado_perfil) REFERENCES catalogo.estado_perfil_deportivo(id_estado_perfil);


--
-- Name: arbitro fk_arbitro_usuario; Type: FK CONSTRAINT; Schema: participantes; Owner: -
--

ALTER TABLE ONLY participantes.arbitro
    ADD CONSTRAINT fk_arbitro_usuario FOREIGN KEY (id_usuario) REFERENCES seguridad.usuario(id_usuario);


--
-- Name: equipo fk_equipo_creado_por; Type: FK CONSTRAINT; Schema: participantes; Owner: -
--

ALTER TABLE ONLY participantes.equipo
    ADD CONSTRAINT fk_equipo_creado_por FOREIGN KEY (creado_por) REFERENCES seguridad.usuario(id_usuario);


--
-- Name: equipo fk_equipo_estado; Type: FK CONSTRAINT; Schema: participantes; Owner: -
--

ALTER TABLE ONLY participantes.equipo
    ADD CONSTRAINT fk_equipo_estado FOREIGN KEY (id_estado_equipo) REFERENCES catalogo.estado_equipo(id_estado_equipo);


--
-- Name: jugador_equipo fk_jugador_equipo_equipo; Type: FK CONSTRAINT; Schema: participantes; Owner: -
--

ALTER TABLE ONLY participantes.jugador_equipo
    ADD CONSTRAINT fk_jugador_equipo_equipo FOREIGN KEY (id_equipo) REFERENCES participantes.equipo(id_equipo);


--
-- Name: jugador_equipo fk_jugador_equipo_estado; Type: FK CONSTRAINT; Schema: participantes; Owner: -
--

ALTER TABLE ONLY participantes.jugador_equipo
    ADD CONSTRAINT fk_jugador_equipo_estado FOREIGN KEY (id_estado_membresia) REFERENCES catalogo.estado_membresia(id_estado_membresia);


--
-- Name: jugador_equipo fk_jugador_equipo_jugador; Type: FK CONSTRAINT; Schema: participantes; Owner: -
--

ALTER TABLE ONLY participantes.jugador_equipo
    ADD CONSTRAINT fk_jugador_equipo_jugador FOREIGN KEY (id_jugador) REFERENCES participantes.jugador(id_usuario);


--
-- Name: jugador_equipo fk_jugador_equipo_registrado_por; Type: FK CONSTRAINT; Schema: participantes; Owner: -
--

ALTER TABLE ONLY participantes.jugador_equipo
    ADD CONSTRAINT fk_jugador_equipo_registrado_por FOREIGN KEY (registrado_por) REFERENCES seguridad.usuario(id_usuario);


--
-- Name: jugador fk_jugador_estado_perfil; Type: FK CONSTRAINT; Schema: participantes; Owner: -
--

ALTER TABLE ONLY participantes.jugador
    ADD CONSTRAINT fk_jugador_estado_perfil FOREIGN KEY (id_estado_perfil) REFERENCES catalogo.estado_perfil_deportivo(id_estado_perfil);


--
-- Name: jugador fk_jugador_usuario; Type: FK CONSTRAINT; Schema: participantes; Owner: -
--

ALTER TABLE ONLY participantes.jugador
    ADD CONSTRAINT fk_jugador_usuario FOREIGN KEY (id_usuario) REFERENCES seguridad.usuario(id_usuario);


--
-- Name: organizador fk_organizador_estado_perfil; Type: FK CONSTRAINT; Schema: participantes; Owner: -
--

ALTER TABLE ONLY participantes.organizador
    ADD CONSTRAINT fk_organizador_estado_perfil FOREIGN KEY (id_estado_perfil) REFERENCES catalogo.estado_perfil_deportivo(id_estado_perfil);


--
-- Name: organizador fk_organizador_usuario; Type: FK CONSTRAINT; Schema: participantes; Owner: -
--

ALTER TABLE ONLY participantes.organizador
    ADD CONSTRAINT fk_organizador_usuario FOREIGN KEY (id_usuario) REFERENCES seguridad.usuario(id_usuario);


--
-- Name: usuario fk_usuario_estado; Type: FK CONSTRAINT; Schema: seguridad; Owner: -
--

ALTER TABLE ONLY seguridad.usuario
    ADD CONSTRAINT fk_usuario_estado FOREIGN KEY (id_estado_usuario) REFERENCES catalogo.estado_usuario(id_estado_usuario);


--
-- Name: usuario_rol fk_usuario_rol_asignado_por; Type: FK CONSTRAINT; Schema: seguridad; Owner: -
--

ALTER TABLE ONLY seguridad.usuario_rol
    ADD CONSTRAINT fk_usuario_rol_asignado_por FOREIGN KEY (asignado_por) REFERENCES seguridad.usuario(id_usuario);


--
-- Name: usuario_rol fk_usuario_rol_rol; Type: FK CONSTRAINT; Schema: seguridad; Owner: -
--

ALTER TABLE ONLY seguridad.usuario_rol
    ADD CONSTRAINT fk_usuario_rol_rol FOREIGN KEY (id_rol) REFERENCES seguridad.rol(id_rol);


--
-- Name: usuario_rol fk_usuario_rol_usuario; Type: FK CONSTRAINT; Schema: seguridad; Owner: -
--

ALTER TABLE ONLY seguridad.usuario_rol
    ADD CONSTRAINT fk_usuario_rol_usuario FOREIGN KEY (id_usuario) REFERENCES seguridad.usuario(id_usuario);


--
-- Name: usuario fk_usuario_tipo_documento; Type: FK CONSTRAINT; Schema: seguridad; Owner: -
--

ALTER TABLE ONLY seguridad.usuario
    ADD CONSTRAINT fk_usuario_tipo_documento FOREIGN KEY (id_tipo_documento) REFERENCES catalogo.tipo_documento(id_tipo_documento);


--
-- PostgreSQL database dump complete
--

\unrestrict VaKjxPAfIgMj01fxTFF27XpzMsaikr0Qe9wuqTOs9pHIh1dxW6YOXcz0htDcAoa

