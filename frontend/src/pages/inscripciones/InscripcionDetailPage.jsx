import {
  ArrowLeft,
  CircleDollarSign,
  Plus,
} from "lucide-react";
import { useMemo, useState } from "react";
import { Link, useParams } from "react-router-dom";

import Badge from "../../components/common/Badge";
import {
  Checkbox,
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
import useAsyncData from "../../hooks/useAsyncData";
import { listarCatalogo } from "../../services/catalogoService";
import {
  agregarJugadorNomina,
  listarNomina,
  listarPagos,
  obtenerInscripcion,
  registrarPago,
} from "../../services/inscripcionService";
import { listarJugadores } from "../../services/jugadorService";
import { formatDateTime, formatMoney } from "../../utils/formatters";

export default function InscripcionDetailPage() {
  const { id } = useParams();
  const [tab, setTab] = useState("nomina");
  const [modal, setModal] = useState("");
  const [formulario, setFormulario] = useState({});
  const [ocupado, setOcupado] = useState(false);
  const [errorFormulario, setErrorFormulario] = useState("");
  const [toast, setToast] = useState("");

  const {
    data,
    loading,
    error,
    reload,
  } = useAsyncData(async () => {
    const [inscripcion, nomina, pagos, jugadores] = await Promise.all([
      obtenerInscripcion(id),
      listarNomina(id),
      listarPagos(id),
      listarJugadores({ estado: "ACTIVO", limite: 100 }),
    ]);
    return {
      inscripcion,
      nomina,
      pagos,
      jugadores: jugadores.resultados,
    };
  }, [id]);

  const { data: metodosPago } = useAsyncData(
    () => listarCatalogo("metodos-pago"),
    [],
  );
  const { data: estadosPago } = useAsyncData(
    () => listarCatalogo("estados-pago"),
    [],
  );

  const estadosPagoPermitidos = useMemo(
    () =>
      (estadosPago || []).filter((estado) =>
        ["PENDIENTE", "CONFIRMADO"].includes(estado.codigo),
      ),
    [estadosPago],
  );

  if (loading) return <LoadingBlock />;
  if (error) return <ErrorState message={error} onRetry={reload} />;

  const inscripcion = data.inscripcion;
  const jugadoresDisponibles = data.jugadores.filter(
    (jugador) =>
      jugador.id_equipo_actual === inscripcion.id_equipo &&
      !data.nomina.some(
        (integrante) => integrante.id_jugador === jugador.id_jugador,
      ),
  );

  function abrirNomina() {
    setFormulario({
      id_jugador: jugadoresDisponibles[0]
        ? String(jugadoresDisponibles[0].id_jugador)
        : "",
      numero_camiseta: "",
      es_delegado: false,
      es_capitan: false,
      observaciones: "",
    });
    setModal("nomina");
    setErrorFormulario("");
  }

  function abrirPago() {
    setFormulario({
      metodo_codigo: metodosPago?.[0]?.codigo || "QR",
      estado_codigo: "CONFIRMADO",
      monto: String(inscripcion.saldo_pendiente),
      referencia: "",
      observaciones: "",
    });
    setModal("pago");
    setErrorFormulario("");
  }

  async function guardar(evento) {
    evento.preventDefault();
    setOcupado(true);
    setErrorFormulario("");

    try {
      if (modal === "nomina") {
        if (!formulario.id_jugador) {
          setErrorFormulario("Selecciona un jugador disponible.");
          return;
        }
        await agregarJugadorNomina(id, {
          id_jugador: Number(formulario.id_jugador),
          numero_camiseta: formulario.numero_camiseta
            ? Number(formulario.numero_camiseta)
            : null,
          es_delegado: Boolean(formulario.es_delegado),
          es_capitan: Boolean(formulario.es_capitan),
          observaciones: formulario.observaciones.trim() || null,
        });
        setToast("Jugador añadido a la nómina");
      } else {
        const monto = Number(formulario.monto);
        const saldo = Number(inscripcion.saldo_pendiente);
        if (!Number.isFinite(monto) || monto <= 0) {
          setErrorFormulario("El monto debe ser mayor que cero.");
          return;
        }
        if (formulario.estado_codigo === "CONFIRMADO" && monto > saldo) {
          setErrorFormulario(
            "Un pago confirmado no puede superar el saldo pendiente.",
          );
          return;
        }
        await registrarPago(id, {
          metodo_codigo: formulario.metodo_codigo,
          estado_codigo: formulario.estado_codigo,
          monto,
          referencia: formulario.referencia.trim() || null,
          observaciones: formulario.observaciones.trim() || null,
        });
        setToast("Pago registrado correctamente");
      }
      setModal("");
      reload();
    } catch (errorGuardado) {
      setErrorFormulario(errorGuardado.message);
    } finally {
      setOcupado(false);
    }
  }

  return (
    <>
      <Link className="back-link" to="/inscripciones">
        <ArrowLeft size={16} /> Volver a inscripciones
      </Link>

      <section className="detail-hero detail-hero--registration">
        <div>
          <div className="badge-row">
            <Badge value={inscripcion.estado_inscripcion} />
            <span className="mono">{inscripcion.codigo_torneo}</span>
          </div>
          <h1>{inscripcion.equipo}</h1>
          <p>
            Inscripción en {inscripcion.torneo} · {formatDateTime(
              inscripcion.fecha_inscripcion,
            )}
          </p>
        </div>
      </section>

      <section className="metric-strip">
        <span>
          <small>Monto requerido</small>
          <strong>
            {formatMoney(inscripcion.monto_requerido, inscripcion.moneda)}
          </strong>
        </span>
        <span>
          <small>Total pagado</small>
          <strong>
            {formatMoney(inscripcion.total_pagado, inscripcion.moneda)}
          </strong>
        </span>
        <span>
          <small>Saldo pendiente</small>
          <strong>
            {formatMoney(inscripcion.saldo_pendiente, inscripcion.moneda)}
          </strong>
        </span>
        <span>
          <small>Nómina habilitada</small>
          <strong>
            {inscripcion.jugadores_habilitados}/{inscripcion.jugadores_nomina}
          </strong>
        </span>
      </section>

      <nav className="tabs">
        <button
          className={tab === "nomina" ? "active" : ""}
          type="button"
          onClick={() => setTab("nomina")}
        >
          Nómina
        </button>
        <button
          className={tab === "pagos" ? "active" : ""}
          type="button"
          onClick={() => setTab("pagos")}
        >
          Pagos
        </button>
      </nav>

      {tab === "nomina" && (
        <section>
          <div className="section-actions">
            <div>
              <p className="eyebrow">JUGADORES INSCRITOS</p>
              <h2>Nómina</h2>
            </div>
            <button
              className="button button--primary"
              type="button"
              onClick={abrirNomina}
            >
              <Plus size={16} /> Añadir jugador
            </button>
          </div>
          {data.nomina.length ? (
            <div className="table-wrap card">
              <table>
                <thead>
                  <tr>
                    <th>Jugador</th>
                    <th>Documento</th>
                    <th>Camiseta</th>
                    <th>Rol</th>
                    <th>Estado</th>
                  </tr>
                </thead>
                <tbody>
                  {data.nomina.map((integrante) => (
                    <tr key={integrante.id_jugador_inscripcion}>
                      <td>
                        {[integrante.nombres, integrante.apellido_paterno]
                          .filter(Boolean)
                          .join(" ")}
                      </td>
                      <td>{integrante.numero_documento}</td>
                      <td>#{integrante.numero_camiseta ?? "—"}</td>
                      <td>
                        {integrante.es_capitan
                          ? "Capitán"
                          : integrante.es_delegado
                            ? "Delegado"
                            : "Jugador"}
                      </td>
                      <td><Badge value={integrante.estado_codigo} /></td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : (
            <EmptyState
              title="La nómina está vacía"
              description="Añade jugadores activos que pertenezcan al equipo."
            />
          )}
        </section>
      )}

      {tab === "pagos" && (
        <section>
          <div className="section-actions">
            <div>
              <p className="eyebrow">MOVIMIENTOS</p>
              <h2>Pagos registrados</h2>
            </div>
            <button
              className="button button--primary"
              type="button"
              onClick={abrirPago}
              disabled={Number(inscripcion.saldo_pendiente) <= 0}
            >
              <Plus size={16} /> Registrar pago
            </button>
          </div>
          {data.pagos.length ? (
            <div className="payment-grid">
              {data.pagos.map((pago) => (
                <article className="card payment-card" key={pago.id_pago}>
                  <span className="payment-card__icon">
                    <CircleDollarSign />
                  </span>
                  <div>
                    <p className="eyebrow">
                      {pago.metodo_pago} · {pago.referencia || "SIN REFERENCIA"}
                    </p>
                    <h3>{formatMoney(pago.monto, pago.moneda)}</h3>
                    <p>
                      {pago.registrado_por} · {formatDateTime(pago.fecha_pago)}
                    </p>
                  </div>
                  <Badge value={pago.estado_pago} />
                </article>
              ))}
            </div>
          ) : (
            <EmptyState title="Todavía no hay pagos" />
          )}
        </section>
      )}

      <Modal
        open={Boolean(modal)}
        onClose={() => setModal("")}
        title={modal === "nomina" ? "Añadir jugador a nómina" : "Registrar pago"}
      >
        <form onSubmit={guardar}>
          <div className="form-grid">
            {modal === "nomina" ? (
              <>
                <Field label="Jugador" className="field--full">
                  <Select
                    value={formulario.id_jugador || ""}
                    onChange={(evento) =>
                      setFormulario({
                        ...formulario,
                        id_jugador: evento.target.value,
                      })
                    }
                    required
                  >
                    <option value="">Selecciona un jugador</option>
                    {jugadoresDisponibles.map((jugador) => (
                      <option key={jugador.id_jugador} value={jugador.id_jugador}>
                        {[jugador.nombres, jugador.apellido_paterno]
                          .filter(Boolean)
                          .join(" ")}
                      </option>
                    ))}
                  </Select>
                </Field>
                <Field label="Camiseta">
                  <Input
                    type="number"
                    min="0"
                    max="999"
                    value={formulario.numero_camiseta || ""}
                    onChange={(evento) =>
                      setFormulario({
                        ...formulario,
                        numero_camiseta: evento.target.value,
                      })
                    }
                  />
                </Field>
                <Checkbox
                  label="Es delegado"
                  checked={Boolean(formulario.es_delegado)}
                  onChange={(evento) =>
                    setFormulario({
                      ...formulario,
                      es_delegado: evento.target.checked,
                    })
                  }
                />
                <Checkbox
                  label="Es capitán"
                  checked={Boolean(formulario.es_capitan)}
                  onChange={(evento) =>
                    setFormulario({
                      ...formulario,
                      es_capitan: evento.target.checked,
                    })
                  }
                />
              </>
            ) : (
              <>
                <Field label="Método">
                  <Select
                    value={formulario.metodo_codigo || ""}
                    onChange={(evento) =>
                      setFormulario({
                        ...formulario,
                        metodo_codigo: evento.target.value,
                      })
                    }
                    required
                  >
                    {(metodosPago || []).map((metodo) => (
                      <option key={metodo.codigo} value={metodo.codigo}>
                        {metodo.nombre}
                      </option>
                    ))}
                  </Select>
                </Field>
                <Field label="Estado">
                  <Select
                    value={formulario.estado_codigo || ""}
                    onChange={(evento) =>
                      setFormulario({
                        ...formulario,
                        estado_codigo: evento.target.value,
                      })
                    }
                    required
                  >
                    {estadosPagoPermitidos.map((estado) => (
                      <option key={estado.codigo} value={estado.codigo}>
                        {estado.nombre}
                      </option>
                    ))}
                  </Select>
                </Field>
                <Field label="Monto">
                  <Input
                    type="number"
                    min="0.01"
                    max={
                      formulario.estado_codigo === "CONFIRMADO"
                        ? String(inscripcion.saldo_pendiente)
                        : undefined
                    }
                    step="0.01"
                    value={formulario.monto || ""}
                    onChange={(evento) =>
                      setFormulario({ ...formulario, monto: evento.target.value })
                    }
                    required
                  />
                </Field>
                <Field label="Referencia">
                  <Input
                    value={formulario.referencia || ""}
                    onChange={(evento) =>
                      setFormulario({
                        ...formulario,
                        referencia: evento.target.value,
                      })
                    }
                    maxLength={100}
                  />
                </Field>
              </>
            )}

            <Field label="Observaciones" className="field--full">
              <Textarea
                value={formulario.observaciones || ""}
                onChange={(evento) =>
                  setFormulario({
                    ...formulario,
                    observaciones: evento.target.value,
                  })
                }
                maxLength={500}
              />
            </Field>
          </div>

          {modal === "nomina" && jugadoresDisponibles.length === 0 && (
            <div className="form-alert">
              No existen jugadores disponibles del equipo para añadir.
            </div>
          )}
          {errorFormulario && <div className="form-alert">{errorFormulario}</div>}

          <div className="modal-actions">
            <button
              className="button button--secondary"
              type="button"
              onClick={() => setModal("")}
            >
              Cancelar
            </button>
            <button
              className="button button--primary"
              disabled={
                ocupado || (modal === "nomina" && jugadoresDisponibles.length === 0)
              }
            >
              {ocupado ? "Guardando..." : "Guardar"}
            </button>
          </div>
        </form>
      </Modal>

      <Toast message={toast} onClose={() => setToast("")} />
    </>
  );
}
