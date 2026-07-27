BEGIN;

CREATE OR REPLACE FUNCTION auditoria.fn_diferencias_jsonb(
    p_datos_anteriores JSONB,
    p_datos_nuevos JSONB
)
RETURNS JSONB
LANGUAGE sql
IMMUTABLE
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


CREATE OR REPLACE FUNCTION auditoria.fn_registrar_auditoria_dml()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, auditoria
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


CREATE OR REPLACE FUNCTION auditoria.fn_proteger_auditoria_dml()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION
        'Los registros de auditoria no pueden modificarse ni eliminarse'
        USING ERRCODE = '42501';
END;
$$;


COMMENT ON FUNCTION auditoria.fn_registrar_auditoria_dml() IS
'Funcion generica utilizada por los triggers de auditoria DML.';


COMMENT ON FUNCTION auditoria.fn_proteger_auditoria_dml() IS
'Impide modificaciones y eliminaciones directas sobre la auditoria.';

COMMIT;