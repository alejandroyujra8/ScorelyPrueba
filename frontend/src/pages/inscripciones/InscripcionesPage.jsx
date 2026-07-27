import { ArrowUpRight, Plus, Search } from "lucide-react";
import { useMemo, useState } from "react";
import { Link } from "react-router-dom";

import Badge from "../../components/common/Badge";
import { Field, Select, Textarea } from "../../components/common/FormFields";
import Modal from "../../components/common/Modal";
import PageHeader from "../../components/common/PageHeader";
import {
  EmptyState,
  ErrorState,
  LoadingBlock,
} from "../../components/common/StateViews";
import Toast from "../../components/common/Toast";
import useAsyncData from "../../hooks/useAsyncData";
import { listarCatalogo } from "../../services/catalogoService";
import { listarEquipos } from "../../services/equipoService";
import {
  crearInscripcion,
  listarInscripciones,
} from "../../services/inscripcionService";
import { listarTorneos } from "../../services/torneoService";
import { formatDate, formatMoney } from "../../utils/formatters";

const FORMULARIO_INICIAL = {
  id_torneo: "",
  id_equipo: "",
  observaciones: "",
};

export default function InscripcionesPage() {
  const [filtros, setFiltros] = useState({
    id_torneo: "",
    estado: "",
    busqueda: "",
  });
  const [modal, setModal] = useState(false);
  const [formulario, setFormulario] = useState(FORMULARIO_INICIAL);
  const [ocupado, setOcupado] = useState(false);
  const [errorFormulario, setErrorFormulario] = useState("");
  const [toast, setToast] = useState("");

  const {
    data,
    loading,
    error,
    reload,
  } = useAsyncData(
    () => listarInscripciones(filtros),
    [filtros.id_torneo, filtros.estado, filtros.busqueda],
  );
  const { data: torneos } = useAsyncData(() => listarTorneos(), []);
  const { data: equipos } = useAsyncData(
    () => listarEquipos({ estado: "ACTIVO", limite: 100 }),
    [],
  );
  const { data: estados } = useAsyncData(
    () => listarCatalogo("estados-inscripcion"),
    [],
  );

  const torneosConInscripcionesAbiertas = useMemo(
    () =>
      (torneos?.resultados || []).filter(
        (torneo) => torneo.estado_torneo === "INSCRIPCIONES_ABIERTAS",
      ),
    [torneos],
  );

  function abrirCreacion() {
    setFormulario({
      ...FORMULARIO_INICIAL,
      id_torneo: torneosConInscripcionesAbiertas[0]
        ? String(torneosConInscripcionesAbiertas[0].id_torneo)
        : "",
      id_equipo: equipos?.resultados?.[0]
        ? String(equipos.resultados[0].id_equipo)
        : "",
    });
    setErrorFormulario("");
    setModal(true);
  }

  async function guardar(evento) {
    evento.preventDefault();
    setOcupado(true);
    setErrorFormulario("");
    try {
      await crearInscripcion({
        id_torneo: Number(formulario.id_torneo),
        id_equipo: Number(formulario.id_equipo),
        observaciones: formulario.observaciones.trim() || null,
      });
      setModal(false);
      setFormulario(FORMULARIO_INICIAL);
      setToast("Inscripción registrada correctamente");
      reload();
    } catch (errorGuardado) {
      setErrorFormulario(errorGuardado.message);
    } finally {
      setOcupado(false);
    }
  }

  return (
    <>
      <PageHeader
        title="Inscripciones"
        description="Equipos inscritos, nóminas y control de pagos."
        actions={
          <button
            className="button button--primary"
            type="button"
            onClick={abrirCreacion}
          >
            <Plus size={16} />
            Nueva inscripción
          </button>
        }
      />

      <section className="toolbar card">
        <label className="search-control">
          <Search size={17} />
          <input
            value={filtros.busqueda}
            onChange={(evento) =>
              setFiltros({ ...filtros, busqueda: evento.target.value })
            }
            placeholder="Buscar equipo o torneo"
          />
        </label>
        <select
          className="filter-select"
          value={filtros.id_torneo}
          onChange={(evento) =>
            setFiltros({ ...filtros, id_torneo: evento.target.value })
          }
        >
          <option value="">Todos los torneos</option>
          {torneos?.resultados?.map((torneo) => (
            <option key={torneo.id_torneo} value={torneo.id_torneo}>
              {torneo.nombre}
            </option>
          ))}
        </select>
        <select
          className="filter-select"
          value={filtros.estado}
          onChange={(evento) =>
            setFiltros({ ...filtros, estado: evento.target.value })
          }
        >
          <option value="">Todos los estados</option>
          {(estados || []).map((estado) => (
            <option key={estado.codigo} value={estado.codigo}>
              {estado.nombre}
            </option>
          ))}
        </select>
      </section>

      {loading ? (
        <LoadingBlock />
      ) : error ? (
        <ErrorState message={error} onRetry={reload} />
      ) : !data?.resultados?.length ? (
        <EmptyState title="No hay inscripciones para este filtro" />
      ) : (
        <div className="table-wrap card">
          <table>
            <thead>
              <tr>
                <th>Equipo</th>
                <th>Torneo</th>
                <th>Estado</th>
                <th>Nómina</th>
                <th>Pagado</th>
                <th>Saldo</th>
                <th>Fecha</th>
                <th aria-label="Acciones" />
              </tr>
            </thead>
            <tbody>
              {data.resultados.map((inscripcion) => (
                <tr key={inscripcion.id_inscripcion}>
                  <td>
                    <strong>{inscripcion.equipo}</strong>
                    <small>{inscripcion.sigla || "Sin sigla"}</small>
                  </td>
                  <td>{inscripcion.torneo}</td>
                  <td><Badge value={inscripcion.estado_inscripcion} /></td>
                  <td>
                    {inscripcion.jugadores_habilitados}/
                    {inscripcion.jugadores_nomina}
                  </td>
                  <td>
                    {formatMoney(inscripcion.total_pagado, inscripcion.moneda)}
                  </td>
                  <td>
                    {formatMoney(inscripcion.saldo_pendiente, inscripcion.moneda)}
                  </td>
                  <td>{formatDate(inscripcion.fecha_inscripcion)}</td>
                  <td>
                    <Link
                      className="icon-button"
                      to={`/inscripciones/${inscripcion.id_inscripcion}`}
                      aria-label={`Ver inscripción de ${inscripcion.equipo}`}
                    >
                      <ArrowUpRight size={16} />
                    </Link>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      <Modal
        open={modal}
        onClose={() => setModal(false)}
        title="Nueva inscripción"
        description="Solo se muestran torneos que actualmente aceptan inscripciones."
      >
        <form onSubmit={guardar}>
          <div className="form-grid">
            <Field label="Torneo" className="field--full">
              <Select
                value={formulario.id_torneo}
                onChange={(evento) =>
                  setFormulario({
                    ...formulario,
                    id_torneo: evento.target.value,
                  })
                }
                required
              >
                <option value="">Selecciona un torneo</option>
                {torneosConInscripcionesAbiertas.map((torneo) => (
                  <option key={torneo.id_torneo} value={torneo.id_torneo}>
                    {torneo.nombre}
                  </option>
                ))}
              </Select>
            </Field>
            <Field label="Equipo" className="field--full">
              <Select
                value={formulario.id_equipo}
                onChange={(evento) =>
                  setFormulario({
                    ...formulario,
                    id_equipo: evento.target.value,
                  })
                }
                required
              >
                <option value="">Selecciona un equipo</option>
                {equipos?.resultados?.map((equipo) => (
                  <option key={equipo.id_equipo} value={equipo.id_equipo}>
                    {equipo.nombre}
                  </option>
                ))}
              </Select>
            </Field>
            <Field label="Observaciones" className="field--full">
              <Textarea
                value={formulario.observaciones}
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

          {torneosConInscripcionesAbiertas.length === 0 && (
            <div className="form-alert">
              No existe ningún torneo con inscripciones abiertas.
            </div>
          )}
          {errorFormulario && <div className="form-alert">{errorFormulario}</div>}

          <div className="modal-actions">
            <button
              className="button button--secondary"
              type="button"
              onClick={() => setModal(false)}
            >
              Cancelar
            </button>
            <button
              className="button button--primary"
              disabled={ocupado || torneosConInscripcionesAbiertas.length === 0}
            >
              {ocupado ? "Registrando..." : "Registrar inscripción"}
            </button>
          </div>
        </form>
      </Modal>

      <Toast message={toast} onClose={() => setToast("")} />
    </>
  );
}
