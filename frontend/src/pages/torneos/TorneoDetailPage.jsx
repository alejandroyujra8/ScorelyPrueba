import {
  ArrowLeft,
  CalendarPlus,
  CircleDollarSign,
  Layers3,
  Plus,
  Trophy,
  UsersRound,
} from "lucide-react";
import { useMemo, useState } from "react";
import { Link, useParams } from "react-router-dom";

import Badge from "../../components/common/Badge";
import {
  Field,
  Input,
  Select,
  Textarea,
} from "../../components/common/FormFields";
import Modal from "../../components/common/Modal";
import {
  EmptyState,
  ErrorState,
  LoadingBlock,
} from "../../components/common/StateViews";
import Toast from "../../components/common/Toast";
import { PERMISSIONS, hasPermission } from "../../config/permissions";
import { useAuth } from "../../contexts/AuthContext";
import useAsyncData from "../../hooks/useAsyncData";
import { listarCatalogo } from "../../services/catalogoService";
import { listarInscripciones } from "../../services/inscripcionService";
import { listarPartidos } from "../../services/partidoService";
import {
  obtenerFinanzasTorneo,
  obtenerPremiosTorneo,
  obtenerResultadosTorneo,
} from "../../services/reporteService";
import {
  cambiarEstadoTorneo,
  crearFase,
  crearJornada,
  obtenerEstructura,
  obtenerTorneo,
} from "../../services/torneoService";
import {
  formatDate,
  formatDateTime,
  formatMoney,
} from "../../utils/formatters";


const TRANSICIONES_ESTADO = Object.freeze({
  BORRADOR: ["INSCRIPCIONES_ABIERTAS", "CANCELADO"],
  INSCRIPCIONES_ABIERTAS: ["INSCRIPCIONES_CERRADAS", "CANCELADO"],
  INSCRIPCIONES_CERRADAS: ["PROGRAMADO", "CANCELADO"],
  PROGRAMADO: ["EN_CURSO", "CANCELADO"],
  EN_CURSO: ["FINALIZADO", "CANCELADO"],
  FINALIZADO: [],
  CANCELADO: [],
});

const TIPOS_FASE_POR_FORMATO = Object.freeze({
  PARTIDO_UNICO: ["PARTIDO_UNICO"],
  FASE_GRUPOS: ["GRUPOS"],
  ELIMINACION_DIRECTA: ["ELIMINACION", "FINAL"],
  GRUPOS_Y_LLAVES: ["GRUPOS", "ELIMINACION", "FINAL"],
});

function limiteFechaHora(fecha, fin = false) {
  if (!fecha) return undefined;
  return `${fecha}T${fin ? "23:59" : "00:00"}`;
}

function textoCodigo(codigo) {
  return String(codigo || "")
    .replaceAll("_", " ")
    .toLocaleLowerCase("es")
    .replace(/^./, (letra) => letra.toUpperCase());
}

export default function TorneoDetailPage() {
  const { id } = useParams();
  const { usuario } = useAuth();
  const puedeEditar = hasPermission(
    usuario,
    PERMISSIONS.MANAGE_TOURNAMENTS,
  );
  const puedeVerFinanzas = hasPermission(
    usuario,
    PERMISSIONS.MANAGE_PAYMENTS,
  );
  const puedeGestionarInscripciones = hasPermission(
    usuario,
    PERMISSIONS.MANAGE_REGISTRATIONS,
  );

  const [tab, setTab] = useState("resumen");
  const [modal, setModal] = useState("");
  const [faseSeleccionada, setFaseSeleccionada] = useState(null);
  const [formulario, setFormulario] = useState({});
  const [ocupado, setOcupado] = useState(false);
  const [errorFormulario, setErrorFormulario] = useState("");
  const [toast, setToast] = useState("");

  const { data: estadosTorneo } = useAsyncData(
    () => listarCatalogo("estados-torneo"),
    [],
  );
  const { data: tiposFase } = useAsyncData(
    () => listarCatalogo("tipos-fase"),
    [],
  );

  const {
    data,
    loading,
    error,
    reload,
  } = useAsyncData(async () => {
    const solicitudes = [
      obtenerTorneo(id),
      obtenerEstructura(id),
      listarPartidos({ id_torneo: id }),
      obtenerResultadosTorneo(id),
      obtenerPremiosTorneo(id),
    ];

    if (puedeGestionarInscripciones) {
      solicitudes.push(listarInscripciones({ id_torneo: id }));
    }
    if (puedeVerFinanzas) {
      solicitudes.push(obtenerFinanzasTorneo(id));
    }

    const resultados = await Promise.all(solicitudes);
    let indice = 0;
    const torneo = resultados[indice++];
    const estructura = resultados[indice++];
    const partidos = resultados[indice++];
    const resultadosTorneo = resultados[indice++];
    const premios = resultados[indice++];
    const inscripciones = puedeGestionarInscripciones
      ? resultados[indice++]
      : null;
    const finanzas = puedeVerFinanzas
      ? resultados[indice++]
      : null;

    return {
      torneo,
      estructura,
      inscripciones: inscripciones?.resultados || [],
      partidos: partidos.resultados,
      resultados: resultadosTorneo.datos,
      premios: premios.datos,
      finanzas: finanzas?.datos || null,
    };
  }, [id, puedeGestionarInscripciones, puedeVerFinanzas]);

  const jornadasPorFase = useMemo(() => {
    const mapa = {};
    data?.estructura?.fases?.forEach((fase) => {
      mapa[fase.id_fase_torneo] = data.estructura.jornadas.filter(
        (jornada) => jornada.id_fase_torneo === fase.id_fase_torneo,
      );
    });
    return mapa;
  }, [data]);

  const estadosDisponibles = useMemo(() => {
    const actual = data?.torneo?.estado_torneo;
    if (!actual) return [];
    const permitidos = new Set([
      actual,
      ...(TRANSICIONES_ESTADO[actual] || []),
    ]);
    return (estadosTorneo || []).filter((estado) =>
      permitidos.has(estado.codigo),
    );
  }, [data?.torneo?.estado_torneo, estadosTorneo]);

  const tiposFaseDisponibles = useMemo(() => {
    const permitidos = new Set(
      TIPOS_FASE_POR_FORMATO[data?.torneo?.formato_codigo] || [],
    );
    return (tiposFase || []).filter((tipo) =>
      permitidos.has(tipo.codigo),
    );
  }, [data?.torneo?.formato_codigo, tiposFase]);

  const puedeModificarEstructura =
    puedeEditar &&
    data?.torneo?.estado_torneo === "BORRADOR";

  const puedeCrearFase =
    puedeModificarEstructura &&
    tiposFaseDisponibles.length > 0 &&
    !(
      data?.torneo?.formato_codigo === "PARTIDO_UNICO" &&
      data?.estructura?.fases?.length >= 1
    );

  const pestanias = useMemo(() => {
    const valores = [
      ["resumen", "Resumen"],
      ["estructura", "Estructura"],
      ["partidos", "Partidos"],
      ["resultados", "Resultados"],
      ["premios", "Premios"],
    ];
    if (puedeGestionarInscripciones) {
      valores.splice(2, 0, ["inscripciones", "Inscripciones"]);
    }
    if (puedeVerFinanzas) {
      valores.splice(valores.length - 1, 0, ["finanzas", "Finanzas"]);
    }
    return valores;
  }, [puedeGestionarInscripciones, puedeVerFinanzas]);

  if (loading) return <LoadingBlock />;
  if (error) return <ErrorState message={error} onRetry={reload} />;

  function abrirFase() {
    if (!puedeModificarEstructura) {
      setToast(
        "La estructura solamente puede modificarse cuando el torneo está en BORRADOR.",
      );
      return;
    }

    setFormulario({
      tipo_fase_codigo:
        tiposFaseDisponibles[0]?.codigo || "PARTIDO_UNICO",
      nombre: "",
      numero_orden: data.estructura.fases.length + 1,
      cantidad_clasificados: "",
      fecha_inicio: data.torneo.fecha_inicio_torneo,
      fecha_fin: data.torneo.fecha_fin_torneo,
      descripcion: "",
    });

    setModal("fase");
    setErrorFormulario("");
  }

  function abrirJornada(fase) {
    if (!puedeModificarEstructura) {
      setToast(
        "No se pueden crear jornadas porque el torneo ya no está en BORRADOR.",
      );
      return;
    }

    setFaseSeleccionada(fase);

    setFormulario({
      numero_jornada:
        (jornadasPorFase[fase.id_fase_torneo]?.length || 0) + 1,
      nombre: "",
      fecha_inicio: limiteFechaHora(fase.fecha_inicio),
      fecha_fin: limiteFechaHora(fase.fecha_fin, true),
      observaciones: "",
    });

    setModal("jornada");
    setErrorFormulario("");
  }

  async function guardarEstructura(evento) {
    evento.preventDefault();
    setOcupado(true);
    setErrorFormulario("");

    const fechasInvalidas =
      modal === "fase"
        ? formulario.fecha_fin < formulario.fecha_inicio
        : formulario.fecha_fin <= formulario.fecha_inicio;

    if (fechasInvalidas) {
      setErrorFormulario(
        modal === "fase"
          ? "La fecha final de la fase no puede ser anterior a la inicial."
          : "La fecha y hora final debe ser posterior a la inicial.",
      );
      setOcupado(false);
      return;
    }

    if (
      modal === "jornada" &&
      (formulario.fecha_inicio < limiteFechaHora(faseSeleccionada.fecha_inicio) ||
        formulario.fecha_fin > limiteFechaHora(faseSeleccionada.fecha_fin, true))
    ) {
      setErrorFormulario(
        "La jornada debe encontrarse dentro de las fechas de la fase seleccionada.",
      );
      setOcupado(false);
      return;
    }

    try {
      if (modal === "fase") {
        await crearFase(id, {
          ...formulario,
          numero_orden: Number(formulario.numero_orden),
          cantidad_clasificados: formulario.cantidad_clasificados
            ? Number(formulario.cantidad_clasificados)
            : null,
          descripcion: formulario.descripcion || null,
        });
      } else {
        await crearJornada(faseSeleccionada.id_fase_torneo, {
          ...formulario,
          numero_jornada: Number(formulario.numero_jornada),
          observaciones: formulario.observaciones || null,
        });
      }
      setModal("");
      setToast(modal === "fase" ? "Fase creada" : "Jornada creada");
      reload();
    } catch (errorGuardado) {
      setErrorFormulario(errorGuardado.message);
    } finally {
      setOcupado(false);
    }
  }

  async function cambiarEstado(evento) {
    const estado = evento.target.value;
    if (!estado || estado === data.torneo.estado_torneo) return;

    setOcupado(true);
    try {
      await cambiarEstadoTorneo(id, estado);
      setToast("Estado del torneo actualizado");
      reload();
    } catch (errorEstado) {
      setToast(errorEstado.message);
    } finally {
      setOcupado(false);
    }
  }

  return (
    <>
      <Link className="back-link" to="/torneos">
        <ArrowLeft size={16} /> Volver a torneos
      </Link>

      <section className="tournament-hero">
        <div className="tournament-hero__top">
          <div className="badge-row">
            <Badge value={data.torneo.estado_torneo} />
            <span className="mono">{data.torneo.codigo}</span>
          </div>
          {puedeModificarEstructura && (
            <button
              className="journey-add"
              type="button"
              onClick={() => abrirJornada(fase)}
            >
              <Plus size={15} /> Añadir jornada
            </button>
          )}
        </div>

        <p className="eyebrow eyebrow--light">
          {data.torneo.deporte} · {textoCodigo(data.torneo.formato)}
        </p>
        <h1>{data.torneo.nombre}</h1>
        <p>
          {data.torneo.categoria} · {textoCodigo(data.torneo.rama)} · {" "}
          {formatDate(data.torneo.fecha_inicio_torneo)} — {" "}
          {formatDate(data.torneo.fecha_fin_torneo)}
        </p>

        <div className="tournament-hero__metrics">
          <span><strong>{data.torneo.total_inscripciones}</strong><small>equipos</small></span>
          <span><strong>{data.torneo.total_partidos}</strong><small>partidos</small></span>
          <span><strong>{data.torneo.partidos_finalizados}</strong><small>finalizados</small></span>
          {puedeVerFinanzas && (
            <span>
              <strong>{formatMoney(data.torneo.total_recaudado, data.torneo.moneda)}</strong>
              <small>recaudado</small>
            </span>
          )}
        </div>
      </section>

      <nav className="tabs">
        {pestanias.map(([valor, etiqueta]) => (
          <button
            type="button"
            className={tab === valor ? "active" : ""}
            key={valor}
            onClick={() => setTab(valor)}
          >
            {etiqueta}
          </button>
        ))}
      </nav>

      {tab === "resumen" && (
        <section className="detail-grid">
          <article className="card detail-panel">
            <div className="card-title-row">
              <div><p className="eyebrow">INSCRIPCIONES</p><h2>Estado de equipos</h2></div>
              <UsersRound />
            </div>
            <div className="report-metrics">
              <span><small>Total</small><strong>{data.torneo.total_inscripciones}</strong></span>
              <span><small>Habilitadas</small><strong>{data.torneo.inscripciones_habilitadas}</strong></span>
              <span><small>Cupos</small><strong>{data.torneo.cantidad_maxima_equipos}</strong></span>
            </div>
          </article>

          <article className="card detail-panel">
            <div className="card-title-row">
              <div><p className="eyebrow">CALENDARIO</p><h2>Fechas clave</h2></div>
              <CalendarPlus />
            </div>
            <dl className="detail-list">
              <div>
                <dt>Inscripciones</dt>
                <dd>{formatDate(data.torneo.fecha_inicio_inscripcion)} — {formatDate(data.torneo.fecha_fin_inscripcion)}</dd>
              </div>
              <div>
                <dt>Torneo</dt>
                <dd>{formatDate(data.torneo.fecha_inicio_torneo)} — {formatDate(data.torneo.fecha_fin_torneo)}</dd>
              </div>
            </dl>
          </article>
        </section>
      )}

      {tab === "estructura" && (
        <section>
          <div className="section-actions">
            <div><p className="eyebrow">FASES Y JORNADAS</p><h2>Estructura del torneo</h2></div>
            {puedeCrearFase && (
              <button className="button button--primary" type="button" onClick={abrirFase}>
                <Plus size={16} /> Crear fase
              </button>
            )}
          </div>

          {data.estructura.fases.length ? (
            <div className="phase-list">
              {data.estructura.fases.map((fase) => (
                <article className="card phase-card" key={fase.id_fase_torneo}>
                  <header>
                    <span className="phase-number">{String(fase.numero_orden).padStart(2, "0")}</span>
                    <div>
                      <p className="eyebrow">{textoCodigo(fase.tipo_fase)}</p>
                      <h3>{fase.nombre}</h3>
                      <p>{formatDate(fase.fecha_inicio)} — {formatDate(fase.fecha_fin)}</p>
                    </div>
                    <Badge value={fase.estado_fase} />
                  </header>

                  <div className="journey-list">
                    {(jornadasPorFase[fase.id_fase_torneo] || []).map((jornada) => (
                      <div key={jornada.id_jornada}>
                        <span className="mono">JORNADA {String(jornada.numero_jornada).padStart(2, "0")}</span>
                        <strong>{jornada.nombre}</strong>
                        <small>{formatDateTime(jornada.fecha_inicio)}</small>
                        <Badge value={jornada.estado_jornada} />
                      </div>
                    ))}
                    {puedeEditar && (
                      <button className="journey-add" type="button" onClick={() => abrirJornada(fase)}>
                        <Plus size={15} /> Añadir jornada
                      </button>
                    )}
                  </div>
                </article>
              ))}
            </div>
          ) : (
            <EmptyState
              title="El torneo todavía no tiene fases"
              action={
                puedeCrearFase && (
                  <button className="button button--primary" type="button" onClick={abrirFase}>
                    Crear primera fase
                  </button>
                )
              }
            />
          )}
        </section>
      )}

      {tab === "inscripciones" && (
        <SimpleTable
          headers={["Equipo", "Estado", "Nómina", "Pagado", "Saldo"]}
          rows={data.inscripciones.map((inscripcion) => [
            <Link key={`equipo-${inscripcion.id_inscripcion}`} to={`/inscripciones/${inscripcion.id_inscripcion}`}>
              {inscripcion.equipo}
            </Link>,
            <Badge key={`estado-${inscripcion.id_inscripcion}`} value={inscripcion.estado_inscripcion} />,
            `${inscripcion.jugadores_habilitados}/${inscripcion.jugadores_nomina}`,
            formatMoney(inscripcion.total_pagado, inscripcion.moneda),
            formatMoney(inscripcion.saldo_pendiente, inscripcion.moneda),
          ])}
          empty="No hay equipos inscritos"
        />
      )}

      {tab === "partidos" && (
        <SimpleTable
          headers={["Código", "Encuentro", "Fecha", "Estado"]}
          rows={data.partidos.map((partido) => [
            <Link key={`partido-${partido.id_partido}`} to={`/partidos/${partido.id_partido}`}>
              {partido.codigo}
            </Link>,
            `${partido.equipo_local || "Por definir"} vs ${partido.equipo_visitante || "Por definir"}`,
            formatDateTime(partido.fecha_hora_inicio),
            <Badge key={`estado-${partido.id_partido}`} value={partido.estado_partido} />,
          ])}
          empty="No hay partidos programados"
        />
      )}

      {tab === "resultados" && (
        <SimpleTable
          headers={["Pos.", "Equipo", "PJ", "PG", "PE", "PP", "DIF", "Puntos"]}
          rows={data.resultados.map((resultado) => [
            resultado.posicion_final,
            resultado.equipo,
            resultado.partidos_jugados,
            resultado.partidos_ganados,
            resultado.partidos_empatados,
            resultado.partidos_perdidos,
            resultado.diferencia_marcador,
            resultado.puntos,
          ])}
          empty="Aún no hay resultados finales"
        />
      )}

      {tab === "finanzas" && puedeVerFinanzas && data.finanzas && (
        <section className="report-metrics report-metrics--large">
          <span>
            <CircleDollarSign />
            <small>Monto esperado</small>
            <strong>{formatMoney(data.finanzas.monto_total_requerido, data.torneo.moneda)}</strong>
          </span>
          <span>
            <Trophy />
            <small>Total recaudado</small>
            <strong>{formatMoney(data.finanzas.total_pagado, data.torneo.moneda)}</strong>
          </span>
          <span>
            <Layers3 />
            <small>Saldo pendiente</small>
            <strong>{formatMoney(data.finanzas.saldo_pendiente, data.torneo.moneda)}</strong>
          </span>
        </section>
      )}

      {tab === "premios" && (
        <SimpleTable
          headers={["Premio", "Tipo", "Ganador", "Estado", "Valor"]}
          rows={data.premios.map((premio) => [
            premio.premio,
            premio.tipo_premio,
            premio.equipo_ganador || "Por definir",
            <Badge key={`premio-${premio.id_torneo_premio}`} value={premio.estado_entrega || "PENDIENTE"} />,
            formatMoney(premio.valor_economico, premio.moneda),
          ])}
          empty="No hay premios configurados"
        />
      )}

      <Modal
        open={Boolean(modal)}
        onClose={() => setModal("")}
        title={modal === "fase" ? "Crear fase" : `Nueva jornada · ${faseSeleccionada?.nombre || ""}`}
      >
        <form onSubmit={guardarEstructura}>
          <div className="form-grid">
            {modal === "fase" ? (
              <>
                <Field label="Tipo">
                  <Select
                    value={formulario.tipo_fase_codigo || ""}
                    onChange={(evento) => setFormulario({ ...formulario, tipo_fase_codigo: evento.target.value })}
                    required
                  >
                    {tiposFaseDisponibles.map((tipo) => (
                      <option key={tipo.codigo} value={tipo.codigo}>{tipo.nombre}</option>
                    ))}
                  </Select>
                </Field>
                <Field label="Nombre">
                  <Input
                    value={formulario.nombre || ""}
                    onChange={(evento) => setFormulario({ ...formulario, nombre: evento.target.value })}
                    minLength={2}
                    maxLength={120}
                    required
                  />
                </Field>
                <Field label="Orden">
                  <Input
                    type="number"
                    min="1"
                    max="100"
                    value={formulario.numero_orden || ""}
                    onChange={(evento) => setFormulario({ ...formulario, numero_orden: evento.target.value })}
                    required
                  />
                </Field>
                <Field label="Clasificados">
                  <Input
                    type="number"
                    min="1"
                    max="128"
                    value={formulario.cantidad_clasificados || ""}
                    onChange={(evento) => setFormulario({ ...formulario, cantidad_clasificados: evento.target.value })}
                  />
                </Field>
                <Field label="Inicio">
                  <Input
                    type="date"
                    value={formulario.fecha_inicio || ""}
                    min={data.torneo.fecha_inicio_torneo}
                    max={data.torneo.fecha_fin_torneo}
                    onChange={(evento) => setFormulario({ ...formulario, fecha_inicio: evento.target.value })}
                    required
                  />
                </Field>
                <Field label="Fin">
                  <Input
                    type="date"
                    value={formulario.fecha_fin || ""}
                    min={formulario.fecha_inicio || data.torneo.fecha_inicio_torneo}
                    max={data.torneo.fecha_fin_torneo}
                    onChange={(evento) => setFormulario({ ...formulario, fecha_fin: evento.target.value })}
                    required
                  />
                </Field>
                <Field label="Descripción" className="field--full">
                  <Textarea
                    value={formulario.descripcion || ""}
                    onChange={(evento) => setFormulario({ ...formulario, descripcion: evento.target.value })}
                    maxLength={500}
                  />
                </Field>
              </>
            ) : (
              <>
                <Field label="Número">
                  <Input
                    type="number"
                    min="1"
                    max="1000"
                    value={formulario.numero_jornada || ""}
                    onChange={(evento) => setFormulario({ ...formulario, numero_jornada: evento.target.value })}
                    required
                  />
                </Field>
                <Field label="Nombre">
                  <Input
                    value={formulario.nombre || ""}
                    onChange={(evento) => setFormulario({ ...formulario, nombre: evento.target.value })}
                    minLength={2}
                    maxLength={120}
                    required
                  />
                </Field>
                <Field label="Inicio">
                  <Input
                    type="datetime-local"
                    value={formulario.fecha_inicio || ""}
                    min={limiteFechaHora(faseSeleccionada?.fecha_inicio)}
                    max={limiteFechaHora(faseSeleccionada?.fecha_fin, true)}
                    onChange={(evento) => setFormulario({ ...formulario, fecha_inicio: evento.target.value })}
                    required
                  />
                </Field>
                <Field label="Fin">
                  <Input
                    type="datetime-local"
                    value={formulario.fecha_fin || ""}
                    min={formulario.fecha_inicio || limiteFechaHora(faseSeleccionada?.fecha_inicio)}
                    max={limiteFechaHora(faseSeleccionada?.fecha_fin, true)}
                    onChange={(evento) => setFormulario({ ...formulario, fecha_fin: evento.target.value })}
                    required
                  />
                </Field>
                <Field label="Observaciones" className="field--full">
                  <Textarea
                    value={formulario.observaciones || ""}
                    onChange={(evento) => setFormulario({ ...formulario, observaciones: evento.target.value })}
                    maxLength={500}
                  />
                </Field>
              </>
            )}
          </div>

          {errorFormulario && <div className="form-alert">{errorFormulario}</div>}

          <div className="modal-actions">
            <button className="button button--secondary" type="button" onClick={() => setModal("")}>Cancelar</button>
            <button className="button button--primary" disabled={ocupado}>
              {ocupado ? "Guardando..." : "Guardar"}
            </button>
          </div>
        </form>
      </Modal>

      <Toast message={toast} onClose={() => setToast("")} />
    </>
  );
}

function SimpleTable({ headers, rows, empty }) {
  if (!rows.length) return <EmptyState title={empty} />;

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
