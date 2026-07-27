import {
  ArrowRight,
  CalendarDays,
  CircleDollarSign,
  Plus,
  Trophy,
  UsersRound,
} from "lucide-react";
import { Link } from "react-router-dom";
import Badge from "../../components/common/Badge";
import {
  ErrorState,
  LoadingBlock,
} from "../../components/common/StateViews";
import {
  PERMISSIONS,
  hasPermission,
} from "../../config/permissions";
import { useAuth } from "../../contexts/AuthContext";
import useAsyncData from "../../hooks/useAsyncData";
import { listarPartidos } from "../../services/partidoService";
import { obtenerDashboard } from "../../services/reporteService";
import { listarTorneos } from "../../services/torneoService";
import {
  formatDate,
  formatDateTime,
  formatMoney,
} from "../../utils/formatters";

export default function DashboardPage() {
  const { usuario } = useAuth();

  const canCreateTournament = hasPermission(
    usuario,
    PERMISSIONS.MANAGE_TOURNAMENTS,
  );

  const canViewFinancials = hasPermission(
    usuario,
    PERMISSIONS.MANAGE_PAYMENTS,
  );

  const {
    data,
    loading,
    error,
    reload,
  } = useAsyncData(async () => {
    const [
      metrics,
      tournaments,
      matches,
    ] = await Promise.all([
      obtenerDashboard(),
      listarTorneos(),
      listarPartidos(),
    ]);

    return {
      metrics,
      tournaments: tournaments.resultados || [],
      matches: matches.resultados || [],
    };
  }, []);

  if (loading) {
    return (
      <LoadingBlock label="Preparando tu panel" />
    );
  }

  if (error) {
    return (
      <ErrorState
        message={error}
        onRetry={reload}
      />
    );
  }

  const liveMatch = data.matches.find(
    (item) =>
      item.estado_partido === "EN_CURSO",
  );

  const nextMatch = data.matches
    .filter(
      (item) =>
        item.estado_partido === "PROGRAMADO",
    )
    .sort(
      (first, second) =>
        new Date(
          first.fecha_hora_inicio,
        ).getTime() -
        new Date(
          second.fecha_hora_inicio,
        ).getTime(),
    )[0];

  const recentTournaments =
    data.tournaments.slice(0, 3);

  return (
    <div className="scorely-dashboard">
      <header className="scorely-dashboard__heading">
        <div>
          <p className="eyebrow scorely-dashboard__season">
            TEMPORADA 2026
          </p>

          <h1>
            Buen día, {usuario.nombres}.
          </h1>
        </div>

        {canCreateTournament && (
          <Link
            className="button button--primary scorely-dashboard__create"
            to="/torneos"
          >
            <Plus size={17} />
            Crear torneo
          </Link>
        )}
      </header>

      <section className="scorely-dashboard__top-grid">
        <article className="scorely-live-card">
          <div className="scorely-live-card__content">
            <div className="scorely-live-card__status">
              <Badge
                value={
                  liveMatch
                    ? "EN_CURSO"
                    : "PROGRAMADO"
                }
                tone="warning"
              />

              <span>
                {liveMatch?.jornada ||
                  "CENTRO DE COMPETICIÓN"}
              </span>
            </div>

            <div className="scorely-live-card__copy">
              <h2>
                La emoción está en juego.
              </h2>

              <p>
                {liveMatch
                  ? `Sigue el encuentro entre ${liveMatch.equipo_local} y ${liveMatch.equipo_visitante}.`
                  : "Los partidos activos aparecerán aquí cuando comience la jornada."}
              </p>
            </div>

            <Link
              to={
                liveMatch
                  ? `/partidos/${liveMatch.id_partido}`
                  : "/partidos"
              }
            >
              {liveMatch
                ? "Ver partido"
                : "Ver calendario"}

              <ArrowRight size={16} />
            </Link>
          </div>

          <div
            className="scorely-live-card__ring"
            aria-hidden="true"
          >
            <div>
              <small>
                {liveMatch
                  ? "MARCADOR"
                  : "ESTADO"}
              </small>

              <strong>
                {liveMatch
                  ? `${liveMatch.marcador_local ?? 0}–${liveMatch.marcador_visitante ?? 0}`
                  : "—"}
              </strong>
            </div>
          </div>
        </article>

        <article className="scorely-summary-card scorely-summary-card--light">
          <p>Torneos activos</p>

          <strong>
            {String(
              data.metrics.torneos_en_curso,
            ).padStart(2, "0")}
          </strong>

          <small>
            {data.metrics.total_torneos} registrados
          </small>
        </article>

        <article className="scorely-summary-card scorely-summary-card--dark">
          <p>Equipos inscritos</p>

          <strong>
            {data.metrics.total_equipos}
          </strong>

          <small>En el sistema</small>
        </article>

        {canViewFinancials && (
        <article className="scorely-revenue-card">
          <div>
            <p className="eyebrow">
              RECAUDACIÓN
            </p>

            <strong>
              {formatMoney(
                data.metrics.total_recaudado,
              )}
            </strong>

            <small>
              Total confirmado
            </small>
          </div>

          <div
            className="scorely-revenue-card__bars"
            aria-hidden="true"
          >
            {[
              28,
              44,
              34,
              62,
              48,
              68,
              57,
              82,
              66,
            ].map(
              (height, index) => (
                <span
                  key={`${height}-${index}`}
                  style={{
                    height: `${height}%`,
                  }}
                />
              ),
            )}
          </div>
        </article>
        )}
      </section>

      <section className="scorely-dashboard__bottom-grid">
        <article className="card scorely-recent-card">
          <header>
            <h2>Torneos recientes</h2>

            <Link to="/torneos">
              Ver todos
            </Link>
          </header>

          <div className="scorely-recent-list">
            {recentTournaments.map(
              (tournament, index) => (
                <Link
                  key={
                    tournament.id_torneo
                  }
                  to={`/torneos/${tournament.id_torneo}`}
                >
                  <span
                    className={`scorely-tournament-icon scorely-tournament-icon--${index + 1}`}
                  >
                    <Trophy size={18} />
                  </span>

                  <span className="scorely-recent-list__identity">
                    <strong>
                      {tournament.nombre}
                    </strong>

                    <small>
                      {tournament.deporte} ·{" "}
                      {tournament.formato}
                    </small>
                  </span>

                  <span className="scorely-recent-list__date">
                    <strong>
                      {formatDate(
                        tournament.fecha_inicio_torneo,
                      )}
                    </strong>

                    <small>
                      {tournament.total_inscripciones ||
                        0}{" "}
                      equipos
                    </small>
                  </span>

                  <Badge
                    value={
                      tournament.estado_torneo
                    }
                  />

                  <ArrowRight size={16} />
                </Link>
              ),
            )}
          </div>
        </article>

        <article className="scorely-next-card">
          <div className="scorely-next-card__header">
            <div>
              <p className="eyebrow">
                PRÓXIMO PARTIDO
              </p>

              <h2>
                {nextMatch
                  ? `${nextMatch.equipo_local} vs ${nextMatch.equipo_visitante}`
                  : "Sin partido programado"}
              </h2>
            </div>

            <span className="scorely-next-card__icon">
              <CalendarDays size={20} />
            </span>
          </div>

          {nextMatch ? (
            <>
              <p>
                {formatDateTime(
                  nextMatch.fecha_hora_inicio,
                )}{" "}
                ·{" "}
                {nextMatch.lugar ||
                  "Lugar por confirmar"}
              </p>

              <Link
                className="button button--primary"
                to={`/partidos/${nextMatch.id_partido}`}
              >
                Abrir centro de partido
              </Link>
            </>
          ) : (
            <>
              <p>
                Cuando se programe un encuentro
                aparecerá en este espacio.
              </p>

              <Link
                className="button button--primary"
                to="/partidos"
              >
                Ver partidos
              </Link>
            </>
          )}
        </article>
      </section>

      <section
        className="scorely-dashboard__mobile-metrics"
        aria-label="Resumen general"
      >
        <article className="card">
          <UsersRound size={18} />

          <small>Equipos</small>

          <strong>
            {data.metrics.total_equipos}
          </strong>
        </article>

        <article className="card">
          <Trophy size={18} />

          <small>Torneos</small>

          <strong>
            {data.metrics.total_torneos}
          </strong>
        </article>

        {canViewFinancials && (
          <article className="card">
            <CircleDollarSign size={18} />

            <small>Recaudación</small>

            <strong>
              {formatMoney(
                data.metrics.total_recaudado,
              )}
            </strong>
          </article>
        )}
      </section>
    </div>
  );
}