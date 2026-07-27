import unittest
from datetime import date, datetime, timedelta

from pydantic import ValidationError

from app.schemas.deporte import DeporteCrear
from app.schemas.equipo import EquipoCrear
from app.schemas.partido import (
    ParticipacionJugadorCrear,
    PartidoCrear,
    PartidoFinalizar,
)
from app.schemas.torneo import TorneoCrear
from app.schemas.usuario import UsuarioActualizar, UsuarioCrear


class EsquemasScorelyTest(unittest.TestCase):
    def test_deporte_normaliza_y_valida_cantidades(self):
        deporte = DeporteCrear(
            codigo=" futbol ",
            nombre="Fútbol",
            cantidad_minima_jugadores=7,
            cantidad_maxima_jugadores=25,
            cantidad_titulares=11,
            tipo_marcador=" gol ",
            permite_empate=True,
            estado_codigo="activo",
        )
        self.assertEqual(deporte.codigo, "FUTBOL")
        self.assertEqual(deporte.tipo_marcador, "GOL")
        self.assertEqual(deporte.estado_codigo, "ACTIVO")

        with self.assertRaises(ValidationError):
            DeporteCrear(
                codigo="FUTBOL",
                nombre="Fútbol",
                cantidad_minima_jugadores=12,
                cantidad_maxima_jugadores=10,
                cantidad_titulares=11,
                tipo_marcador="GOL",
            )

    def test_equipo_rechaza_fecha_futura(self):
        with self.assertRaises(ValidationError):
            EquipoCrear(
                nombre="Equipo futuro",
                sigla="FUT",
                fecha_fundacion=date.today() + timedelta(days=1),
            )

    def datos_torneo(self, **cambios):
        datos = {
            "id_deporte": 1,
            "formato_codigo": "FASE_GRUPOS",
            "codigo": "LIGA-2026",
            "nombre": "Liga Universitaria",
            "edicion": "2026",
            "categoria": "Libre",
            "rama": "MASCULINO",
            "fecha_inicio_inscripcion": "2026-08-01",
            "fecha_fin_inscripcion": "2026-08-10",
            "fecha_inicio_torneo": "2026-08-11",
            "fecha_fin_torneo": "2026-12-20",
            "cantidad_maxima_equipos": 16,
            "cantidad_minima_jugadores": 7,
            "cantidad_maxima_jugadores": 25,
            "costo_inscripcion": "500.00",
            "moneda": "bob",
            "permite_empate": True,
        }
        datos.update(cambios)
        return datos

    def test_torneo_normaliza_y_valida(self):
        torneo = TorneoCrear(**self.datos_torneo())
        self.assertEqual(torneo.formato_codigo, "FASE_GRUPOS")
        self.assertEqual(torneo.moneda, "BOB")

        with self.assertRaises(ValidationError):
            TorneoCrear(
                **self.datos_torneo(
                    formato_codigo="PARTIDO_UNICO",
                    cantidad_maxima_equipos=4,
                )
            )

        with self.assertRaises(ValidationError):
            TorneoCrear(
                **self.datos_torneo(
                    fecha_fin_inscripcion="2026-08-20",
                    fecha_inicio_torneo="2026-08-15",
                )
            )

    def test_usuario_admite_cinco_roles_y_protege_activos(self):
        usuario = UsuarioCrear(
            numero_documento="7000999",
            nombres="Usuario de Prueba",
            fecha_nacimiento="2000-01-01",
            correo="prueba@scorely.test",
            contrasenia="Demo123*",
            roles=[
                "ADMINISTRADOR",
                "ORGANIZADOR",
                "ARBITRO",
                "JUGADOR",
                "CONSULTA",
            ],
        )
        self.assertEqual(len(usuario.roles), 5)

        with self.assertRaises(ValidationError):
            UsuarioCrear(
                numero_documento="7000998",
                nombres="Sin Rol",
                fecha_nacimiento="2000-01-01",
                correo="sinrol@scorely.test",
                contrasenia="Demo123*",
                roles=[],
                estado_codigo="ACTIVO",
            )

        actualizacion = UsuarioActualizar(roles=["consulta", "CONSULTA"])
        self.assertEqual(actualizacion.roles, ["CONSULTA"])

    def test_partido_y_participacion(self):
        inicio = datetime(2026, 8, 20, 15, 0)
        with self.assertRaises(ValidationError):
            PartidoCrear(
                id_jornada=1,
                id_lugar=1,
                codigo="P-001",
                numero_partido=1,
                fecha_hora_inicio=inicio,
                fecha_hora_fin=inicio,
                id_inscripcion_local=1,
                id_inscripcion_visitante=2,
            )

        with self.assertRaises(ValidationError):
            ParticipacionJugadorCrear(
                id_jugador_inscripcion=1,
                convocado=False,
                asistio=True,
            )

        with self.assertRaises(ValidationError):
            PartidoFinalizar(
                marcador_local=1,
                marcador_visitante=1,
                desempate_local=5,
                desempate_visitante=None,
            )


if __name__ == "__main__":
    unittest.main()
