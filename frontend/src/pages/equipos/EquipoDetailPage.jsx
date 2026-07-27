import { ArrowLeft, CalendarDays, History, UsersRound } from "lucide-react";
import { Link, useParams } from "react-router-dom";
import Badge from "../../components/common/Badge";
import {
  EmptyState,
  ErrorState,
  LoadingBlock,
} from "../../components/common/StateViews";
import useAsyncData from "../../hooks/useAsyncData";
import { obtenerEquipo } from "../../services/equipoService";
import { listarJugadores } from "../../services/jugadorService";
import { obtenerHistorialEquipo } from "../../services/reporteService";
import { formatDate, initials } from "../../utils/formatters";

export default function EquipoDetailPage() {
  const { id } = useParams();
  const { data, loading, error, reload } = useAsyncData(async () => {
    const [equipo, jugadores, historial] = await Promise.all([
      obtenerEquipo(id),
      listarJugadores({ id_equipo: id, limite: 100 }),
      obtenerHistorialEquipo(id),
    ]);

    return {
      equipo,
      jugadores: jugadores.resultados,
      historial: historial.datos,
    };
  }, [id]);

  if (loading) return <LoadingBlock />;
  if (error) return <ErrorState message={error} onRetry={reload} />;

  const { equipo, jugadores, historial } = data;

  return (
    <>
      <Link className="back-link" to="/equipos">
        <ArrowLeft size={16} /> Volver a equipos
      </Link>

      <section className="detail-hero detail-hero--team">
        <div className="detail-hero__mark">{initials(equipo.sigla)}</div>
        <div>
          <div className="badge-row">
            <Badge value={equipo.estado_codigo} />
            <span className="mono">{equipo.sigla}</span>
          </div>
          <h1>{equipo.nombre}</h1>
          <p>{equipo.descripcion || "Equipo registrado en Scorely."}</p>
        </div>
      </section>

      <section className="detail-grid">
        <article className="card detail-panel">
          <div className="card-title-row">
            <div>
              <p className="eyebrow">PLANTEL ACTUAL</p>
              <h2>Jugadores</h2>
            </div>
            <UsersRound />
          </div>

          {jugadores.length ? (
            <div className="compact-list">
              {jugadores.map((jugador) => (
                <Link key={jugador.id_jugador} to={`/jugadores/${jugador.id_jugador}`}>
                  <span className="team-mark team-mark--light">
                    {jugador.numero_camiseta_actual || "—"}
                  </span>
                  <span>
                    <strong>
                      {jugador.nombres} {jugador.apellido_paterno}
                    </strong>
                    <small>
                      {jugador.posicion_actual || "Sin posición"} · {jugador.alias_deportivo || "Sin alias"}
                    </small>
                  </span>
                  <Badge value={jugador.estado_codigo} />
                </Link>
              ))}
            </div>
          ) : (
            <EmptyState title="Sin jugadores activos" />
          )}
        </article>

        <article className="card detail-panel">
          <div className="card-title-row">
            <div>
              <p className="eyebrow">INFORMACIÓN</p>
              <h2>Ficha del equipo</h2>
            </div>
            <CalendarDays />
          </div>

          <dl className="detail-list">
            <div>
              <dt>Fecha de fundación</dt>
              <dd>{formatDate(equipo.fecha_fundacion)}</dd>
            </div>
            <div>
              <dt>Sigla</dt>
              <dd>{equipo.sigla}</dd>
            </div>
            <div>
              <dt>Estado</dt>
              <dd><Badge value={equipo.estado_codigo} /></dd>
            </div>
          </dl>
        </article>

        <article className="card detail-panel detail-panel--wide">
          <div className="card-title-row">
            <div>
              <p className="eyebrow">COMPETENCIAS</p>
              <h2>Historial deportivo</h2>
            </div>
            <History />
          </div>

          {historial.length ? (
            <div className="table-wrap">
              <table>
                <thead>
                  <tr>
                    <th>Torneo</th>
                    <th>Estado</th>
                    <th>Inscripción</th>
                    <th>Posición</th>
                    <th>PJ</th>
                    <th>PG</th>
                    <th>PE</th>
                    <th>PP</th>
                    <th>Puntos</th>
                  </tr>
                </thead>
                <tbody>
                  {historial.map((item) => (
                    <tr key={item.id_torneo}>
                      <td>{item.torneo}</td>
                      <td><Badge value={item.estado_torneo} /></td>
                      <td><Badge value={item.estado_inscripcion} /></td>
                      <td>{item.posicion_final || "—"}</td>
                      <td>{item.partidos_jugados}</td>
                      <td>{item.partidos_ganados}</td>
                      <td>{item.partidos_empatados}</td>
                      <td>{item.partidos_perdidos}</td>
                      <td><strong>{item.puntos}</strong></td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : (
            <EmptyState title="Sin historial todavía" />
          )}
        </article>
      </section>
    </>
  );
}
