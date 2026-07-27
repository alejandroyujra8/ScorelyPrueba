import {
  BarChart3,
  CircleDollarSign,
  Medal,
  Trophy,
} from "lucide-react";
import { useMemo, useState } from "react";

import Badge from "../../components/common/Badge";
import PageHeader from "../../components/common/PageHeader";
import {
  EmptyState,
  ErrorState,
  LoadingBlock,
} from "../../components/common/StateViews";
import { PERMISSIONS, hasPermission } from "../../config/permissions";
import { useAuth } from "../../contexts/AuthContext";
import useAsyncData from "../../hooks/useAsyncData";
import {
  obtenerFinanzasTorneo,
  obtenerJugadoresTorneo,
  obtenerPremiosTorneo,
  obtenerResultadosTorneo,
  obtenerResumenTorneo,
} from "../../services/reporteService";
import { listarTorneos } from "../../services/torneoService";
import { formatMoney } from "../../utils/formatters";

export default function ReportesPage() {
  const { usuario } = useAuth();
  const puedeVerFinanzas = hasPermission(
    usuario,
    PERMISSIONS.MANAGE_PAYMENTS,
  );
  const [idTorneo, setIdTorneo] = useState("");
  const [tab, setTab] = useState("resumen");

  const { data: torneos } = useAsyncData(() => listarTorneos(), []);
  const torneoSeleccionado = torneos?.resultados?.find(
    (torneo) => String(torneo.id_torneo) === String(idTorneo),
  );
  const moneda = torneoSeleccionado?.moneda || "BOB";

  const {
    data,
    loading,
    error,
    reload,
  } = useAsyncData(
    async () => {
      if (!idTorneo) return null;

      const solicitudes = [
        obtenerResumenTorneo(idTorneo),
        obtenerResultadosTorneo(idTorneo),
        obtenerJugadoresTorneo(idTorneo),
        obtenerPremiosTorneo(idTorneo),
      ];
      if (puedeVerFinanzas) {
        solicitudes.push(obtenerFinanzasTorneo(idTorneo));
      }

      const [resumen, resultados, jugadores, premios, finanzas] =
        await Promise.all(solicitudes);

      return {
        resumen: resumen.datos,
        resultados: resultados.datos,
        jugadores: jugadores.datos,
        premios: premios.datos,
        finanzas: finanzas?.datos || null,
      };
    },
    [idTorneo, puedeVerFinanzas],
    Boolean(idTorneo),
  );

  const pestanias = useMemo(() => {
    const valores = [
      ["resumen", "Resumen"],
      ["resultados", "Resultados"],
      ["jugadores", "Jugadores"],
      ["premios", "Premios"],
    ];
    if (puedeVerFinanzas) valores.splice(1, 0, ["finanzas", "Finanzas"]);
    return valores;
  }, [puedeVerFinanzas]);

  function cambiarTorneo(evento) {
    setIdTorneo(evento.target.value);
    setTab("resumen");
  }

  return (
    <>
      <PageHeader
        title="Reportes"
        description="Indicadores y consultas respaldadas por la API actual."
      />

      <section className="report-selector card">
        <div>
          <p className="eyebrow">CENTRO DE REPORTES</p>
          <h2>Selecciona un torneo</h2>
        </div>
        <select
          className="filter-select"
          value={idTorneo}
          onChange={cambiarTorneo}
        >
          <option value="">Elige una competencia</option>
          {torneos?.resultados?.map((torneo) => (
            <option key={torneo.id_torneo} value={torneo.id_torneo}>
              {torneo.nombre}
            </option>
          ))}
        </select>
      </section>

      {!idTorneo ? (
        <EmptyState
          title="Selecciona un torneo"
          description={
            puedeVerFinanzas
              ? "Podrás consultar resumen, finanzas, resultados, jugadores y premios."
              : "Podrás consultar resumen, resultados, jugadores y premios."
          }
        />
      ) : loading ? (
        <LoadingBlock />
      ) : error ? (
        <ErrorState message={error} onRetry={reload} />
      ) : data ? (
        <>
          <section className="report-metrics report-metrics--large">
            <span>
              <Trophy />
              <small>Equipos inscritos</small>
              <strong>{data.resumen.total_inscripciones ?? 0}</strong>
            </span>
            {puedeVerFinanzas && data.finanzas && (
              <span>
                <CircleDollarSign />
                <small>Total recaudado</small>
                <strong>{formatMoney(data.finanzas.total_pagado, moneda)}</strong>
              </span>
            )}
            <span>
              <BarChart3 />
              <small>Partidos finalizados</small>
              <strong>
                {data.resumen.partidos_finalizados ?? data.resultados.length}
              </strong>
            </span>
            <span>
              <Medal />
              <small>Premios</small>
              <strong>{data.premios.length}</strong>
            </span>
          </section>

          <nav className="tabs">
            {pestanias.map(([valor, etiqueta]) => (
              <button
                type="button"
                key={valor}
                className={tab === valor ? "active" : ""}
                onClick={() => setTab(valor)}
              >
                {etiqueta}
              </button>
            ))}
          </nav>

          {tab === "resumen" && (
            <article className="card report-summary">
              <div>
                <p className="eyebrow">COMPETENCIA</p>
                <h2>{data.resumen.nombre || data.resumen.torneo}</h2>
                <p>{data.resumen.deporte} · {data.resumen.formato}</p>
              </div>
              <Badge value={data.resumen.estado_torneo || data.resumen.estado} />
            </article>
          )}

          {tab === "finanzas" && puedeVerFinanzas && data.finanzas && (
            <div className="report-metrics report-metrics--large">
              <span>
                <small>Monto esperado</small>
                <strong>{formatMoney(data.finanzas.monto_total_requerido, moneda)}</strong>
              </span>
              <span>
                <small>Recaudado</small>
                <strong>{formatMoney(data.finanzas.total_pagado, moneda)}</strong>
              </span>
              <span>
                <small>Pendiente</small>
                <strong>{formatMoney(data.finanzas.saldo_pendiente, moneda)}</strong>
              </span>
            </div>
          )}

          {tab === "resultados" && (
            <ReportTable
              headers={["Pos.", "Equipo", "PJ", "PG", "PE", "PP", "DIF", "Puntos"]}
              rows={data.resultados.map((item) => [
                item.posicion_final,
                item.equipo,
                item.partidos_jugados,
                item.partidos_ganados,
                item.partidos_empatados,
                item.partidos_perdidos,
                item.diferencia_marcador,
                item.puntos,
              ])}
            />
          )}

          {tab === "jugadores" && (
            <ReportTable
              headers={["Jugador", "Equipo", "Partidos", "Asistencias", "Minutos", "Puntos", "Calificación"]}
              rows={data.jugadores.map((item) => [
                `${item.nombres} ${item.apellido_paterno || ""}`.trim(),
                item.equipo,
                item.partidos_registrados,
                item.asistencias,
                item.minutos_jugados,
                item.puntos_anotados,
                item.calificacion_promedio ?? "—",
              ])}
            />
          )}

          {tab === "premios" && (
            <ReportTable
              headers={["Premio", "Tipo", "Ganador", "Estado", "Valor"]}
              rows={data.premios.map((item) => [
                item.premio,
                item.tipo_premio,
                item.equipo_ganador || "Por definir",
                <Badge
                  key={`estado-${item.id_torneo_premio}`}
                  value={item.estado_entrega || "PENDIENTE"}
                />,
                formatMoney(item.valor_economico, item.moneda),
              ])}
            />
          )}
        </>
      ) : null}
    </>
  );
}

function ReportTable({ headers, rows }) {
  if (!rows.length) return <EmptyState title="No hay datos para este reporte" />;

  return (
    <div className="table-wrap card">
      <table>
        <thead>
          <tr>{headers.map((header) => <th key={header}>{header}</th>)}</tr>
        </thead>
        <tbody>
          {rows.map((row, rowIndex) => (
            <tr key={`fila-${rowIndex}`}>
              {row.map((cell, cellIndex) => (
                <td key={`celda-${rowIndex}-${cellIndex}`}>{cell}</td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
