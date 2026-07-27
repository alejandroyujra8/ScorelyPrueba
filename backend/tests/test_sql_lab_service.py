import unittest

from app.services.sql_lab_service import (
    SqlLabValidacionError,
    validar_script_sql,
)


class SqlLabValidacionTest(unittest.TestCase):
    def test_consultas_y_case_end_son_validos(self):
        validar_script_sql("SELECT 1;")
        validar_script_sql("SELECT CASE WHEN 1 = 1 THEN 'OK' ELSE 'NO' END;")
        validar_script_sql("SELECT 'COMMIT no es una instrucción';")
        validar_script_sql("-- DROP DATABASE demo\nSELECT current_database();")

    def test_operaciones_peligrosas_son_bloqueadas(self):
        bloqueados = [
            "COMMIT;",
            "CREATE DATABASE prueba;",
            "ALTER ROLE postgres SUPERUSER;",
            "SELECT nextval('secuencia');",
            "SELECT pg_advisory_lock(1);",
            "COPY tabla TO '/tmp/datos.csv';",
        ]
        for script in bloqueados:
            with self.subTest(script=script):
                with self.assertRaises(SqlLabValidacionError):
                    validar_script_sql(script)


if __name__ == "__main__":
    unittest.main()
