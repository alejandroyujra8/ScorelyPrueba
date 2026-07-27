BEGIN;

CREATE OR REPLACE PROCEDURE auditoria.sp_instalar_triggers_auditoria()
LANGUAGE plpgsql
SECURITY DEFINER
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


CREATE OR REPLACE PROCEDURE auditoria.sp_configurar_tabla_auditoria(
    IN p_esquema NAME,
    IN p_tabla NAME,
    IN p_activo BOOLEAN,
    IN p_auditar_insert BOOLEAN DEFAULT TRUE,
    IN p_auditar_update BOOLEAN DEFAULT TRUE,
    IN p_auditar_delete BOOLEAN DEFAULT TRUE
)
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

COMMIT;