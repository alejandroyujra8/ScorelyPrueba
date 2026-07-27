import {
  ArrowUpRight,
  CalendarDays,
  Edit3,
  Plus,
  Search,
  UsersRound,
} from "lucide-react";
import { useMemo, useState } from "react";
import { Link } from "react-router-dom";

import Badge from "../../components/common/Badge";
import {
  Checkbox,
  Field,
  Input,
  Select,
  Textarea,
} from "../../components/common/FormFields";
import Modal from "../../components/common/Modal";
import PageHeader from "../../components/common/PageHeader";
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
import { listarDeportes } from "../../services/deporteService";
import {
  actualizarTorneo,
  crearTorneo,
  listarTorneos,
} from "../../services/torneoService";
import { formatDate, formatMoney } from "../../utils/formatters";

function formularioInicial() {
  return {
    id_deporte: "",
    formato_codigo: "",
    codigo: "",
    nombre: "",
    edicion: String(new Date().getFullYear()),
    categoria: "Libre",
    rama: "ABIERTO",
    fecha_inicio_inscripcion: "",
    fecha_fin_inscripcion: "",
    fecha_inicio_torneo: "",
    fecha_fin_torneo: "",
    cantidad_maxima_equipos: 16,
    cantidad_minima_jugadores: 1,
    cantidad_maxima_jugadores: 20,
    costo_inscripcion: 0,
    moneda: "BOB",
    permite_empate: false,
    descripcion: "",
  };
}

function textoCodigo(codigo) {
  return String(codigo || "")
    .replaceAll("_", " ")
    .toLocaleLowerCase("es")
    .replace(/^./, (letra) => letra.toUpperCase());
}

export default function TorneosPage() {
  const { usuario } = useAuth();
  const puedeEditar = hasPermission(
    usuario,
    PERMISSIONS.MANAGE_TOURNAMENTS,
  );

  const [filtros, setFiltros] = useState({ estado: "", busqueda: "" });
  const [modal, setModal] = useState(false);
  const [editando, setEditando] = useState(null);
  const [formulario, setFormulario] = useState(formularioInicial());
  const [ocupado, setOcupado] = useState(false);
  const [errorFormulario, setErrorFormulario] = useState("");
  const [toast, setToast] = useState("");

  const {
    data,
    loading,
    error,
    reload,
  } = useAsyncData(
    () => listarTorneos(filtros),
    [filtros.estado, filtros.busqueda],
  );

  const { data: deportes } = useAsyncData(
    () => listarDeportes({ estado: "ACTIVO", limite: 100 }),
    [],
  );
  const { data: formatos } = useAsyncData(
    () => listarCatalogo("formatos-torneo"),
    [],
  );
  const { data: estados } = useAsyncData(
    () => listarCatalogo("estados-torneo"),
    [],
  );

  const nombresFormato = useMemo(
    () =>
      Object.fromEntries(
        (formatos || []).map((formato) => [formato.codigo, formato.nombre]),
      ),
    [formatos],
  );

  const deporteSeleccionado = useMemo(
    () =>
      deportes?.resultados?.find(
        (deporte) =>
          String(deporte.id_deporte) === String(formulario.id_deporte),
      ) || null,
    [deportes, formulario.id_deporte],
  );

  function abrirCreacion() {
    const primerDeporte = deportes?.resultados?.[0];
    const primerFormato = formatos?.[0];
    setEditando(null);
    setFormulario({
      ...formularioInicial(),
      id_deporte: primerDeporte ? String(primerDeporte.id_deporte) : "",
      formato_codigo: primerFormato?.codigo || "",
      cantidad_maxima_equipos:
        primerFormato?.codigo === "PARTIDO_UNICO" ? 2 : 16,
      cantidad_minima_jugadores:
        primerDeporte?.cantidad_minima_jugadores || 1,
      cantidad_maxima_jugadores:
        primerDeporte?.cantidad_maxima_jugadores || 20,
      permite_empate: Boolean(primerDeporte?.permite_empate),
    });
    setErrorFormulario("");
    setModal(true);
  }

  function abrirEdicion(torneo) {
    setEditando(torneo);
    setFormulario({
      id_deporte: String(torneo.id_deporte),
      formato_codigo: torneo.formato_codigo || torneo.formato,
      codigo: torneo.codigo,
      nombre: torneo.nombre,
      edicion: torneo.edicion || "",
      categoria: torneo.categoria,
      rama: torneo.rama,
      fecha_inicio_inscripcion: torneo.fecha_inicio_inscripcion,
      fecha_fin_inscripcion: torneo.fecha_fin_inscripcion,
      fecha_inicio_torneo: torneo.fecha_inicio_torneo,
      fecha_fin_torneo: torneo.fecha_fin_torneo,
      cantidad_maxima_equipos: torneo.cantidad_maxima_equipos,
      cantidad_minima_jugadores: torneo.cantidad_minima_jugadores,
      cantidad_maxima_jugadores: torneo.cantidad_maxima_jugadores,
      costo_inscripcion: torneo.costo_inscripcion,
      moneda: torneo.moneda,
      permite_empate: Boolean(torneo.permite_empate),
      descripcion: torneo.descripcion || "",
    });
    setErrorFormulario("");
    setModal(true);
  }

  function cambiarDeporte(idDeporte) {
    const deporte = deportes?.resultados?.find(
      (item) => String(item.id_deporte) === String(idDeporte),
    );
    setFormulario((actual) => ({
      ...actual,
      id_deporte: idDeporte,
      cantidad_minima_jugadores:
        deporte?.cantidad_minima_jugadores ?? actual.cantidad_minima_jugadores,
      cantidad_maxima_jugadores:
        deporte?.cantidad_maxima_jugadores ?? actual.cantidad_maxima_jugadores,
      permite_empate:
        deporte?.permite_empate ?? actual.permite_empate,
    }));
  }

  function cambiarFormato(formatoCodigo) {
    setFormulario((actual) => ({
      ...actual,
      formato_codigo: formatoCodigo,
      cantidad_maxima_equipos:
        formatoCodigo === "PARTIDO_UNICO"
          ? 2
          : actual.formato_codigo === "PARTIDO_UNICO"
            ? 16
            : actual.cantidad_maxima_equipos,
    }));
  }

  function cambiarCampo(evento) {
    const { name, value, type, checked } = evento.target;
    setFormulario((actual) => ({
      ...actual,
      [name]: type === "checkbox" ? checked : value,
    }));
  }

  async function guardar(evento) {
    evento.preventDefault();
    setOcupado(true);
    setErrorFormulario("");

    const datos = {
      id_deporte: Number(formulario.id_deporte),
      formato_codigo: formulario.formato_codigo,
      codigo: formulario.codigo.trim().toUpperCase(),
      nombre: formulario.nombre.trim(),
      edicion: formulario.edicion.trim() || null,
      categoria: formulario.categoria.trim(),
      rama: formulario.rama.trim().toUpperCase(),
      fecha_inicio_inscripcion: formulario.fecha_inicio_inscripcion,
      fecha_fin_inscripcion: formulario.fecha_fin_inscripcion,
      fecha_inicio_torneo: formulario.fecha_inicio_torneo,
      fecha_fin_torneo: formulario.fecha_fin_torneo,
      cantidad_maxima_equipos: Number(formulario.cantidad_maxima_equipos),
      cantidad_minima_jugadores: Number(
        formulario.cantidad_minima_jugadores,
      ),
      cantidad_maxima_jugadores: Number(
        formulario.cantidad_maxima_jugadores,
      ),
      costo_inscripcion: Number(formulario.costo_inscripcion),
      moneda: formulario.moneda.trim().toUpperCase(),
      permite_empate: Boolean(formulario.permite_empate),
      descripcion: formulario.descripcion.trim() || null,
    };

    if (!datos.id_deporte || !datos.formato_codigo) {
      setErrorFormulario("Selecciona un deporte y un formato válidos.");
      setOcupado(false);
      return;
    }

    if (
      datos.formato_codigo === "PARTIDO_UNICO" &&
      datos.cantidad_maxima_equipos !== 2
    ) {
      setErrorFormulario(
        "Un torneo de partido único debe permitir exactamente 2 equipos.",
      );
      setOcupado(false);
      return;
    }

    if (
      deporteSeleccionado &&
      datos.cantidad_minima_jugadores <
        deporteSeleccionado.cantidad_minima_jugadores
    ) {
      setErrorFormulario(
        `La cantidad mínima no puede ser menor que ${deporteSeleccionado.cantidad_minima_jugadores} para ${deporteSeleccionado.nombre}.`,
      );
      setOcupado(false);
      return;
    }

    if (
      deporteSeleccionado &&
      datos.cantidad_maxima_jugadores >
        deporteSeleccionado.cantidad_maxima_jugadores
    ) {
      setErrorFormulario(
        `La cantidad máxima no puede superar ${deporteSeleccionado.cantidad_maxima_jugadores} para ${deporteSeleccionado.nombre}.`,
      );
      setOcupado(false);
      return;
    }

    if (
      datos.cantidad_maxima_jugadores <
      datos.cantidad_minima_jugadores
    ) {
      setErrorFormulario(
        "La cantidad máxima de jugadores no puede ser menor que la mínima.",
      );
      setOcupado(false);
      return;
    }

    if (datos.fecha_fin_inscripcion < datos.fecha_inicio_inscripcion) {
      setErrorFormulario(
        "La fecha final de inscripción no puede ser anterior a la inicial.",
      );
      setOcupado(false);
      return;
    }

    if (datos.fecha_inicio_torneo < datos.fecha_fin_inscripcion) {
      setErrorFormulario(
        "El torneo no puede iniciar antes del cierre de inscripciones.",
      );
      setOcupado(false);
      return;
    }

    if (datos.fecha_fin_torneo < datos.fecha_inicio_torneo) {
      setErrorFormulario(
        "La fecha final del torneo no puede ser anterior a la inicial.",
      );
      setOcupado(false);
      return;
    }

    try {
      if (editando) {
        await actualizarTorneo(editando.id_torneo, datos);
        setToast("Torneo actualizado correctamente");
      } else {
        await crearTorneo(datos);
        setToast("Torneo creado en estado BORRADOR");
      }
      setModal(false);
      setEditando(null);
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
        title="Torneos"
        description="Competencias, inscripciones, estructura y seguimiento operativo."
        actions={
          puedeEditar && (
            <button
              className="button button--primary"
              type="button"
              onClick={abrirCreacion}
            >
              <Plus size={16} />
              Crear torneo
            </button>
          )
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
            placeholder="Buscar por nombre o código"
          />
        </label>
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
        <EmptyState title="No hay torneos" />
      ) : (
        <section className="tournament-grid">
          {data.resultados.map((torneo, indice) => (
            <article
              className={`tournament-card card tournament-card--${indice % 3}`}
              key={torneo.id_torneo}
            >
              <div className="tournament-card__head">
                <span className="mono">{torneo.codigo}</span>
                <Badge value={torneo.estado_torneo} />
              </div>
              <p className="eyebrow">
                {torneo.deporte} · {nombresFormato[torneo.formato_codigo] || textoCodigo(torneo.formato)}
              </p>
              <h2>{torneo.nombre}</h2>
              <p className="muted">
                {torneo.categoria} · {textoCodigo(torneo.rama)}
                {torneo.edicion ? ` · ${torneo.edicion}` : ""}
              </p>
              <div className="tournament-card__metrics">
                <span>
                  <UsersRound size={16} />
                  <strong>
                    {torneo.total_inscripciones}/{torneo.cantidad_maxima_equipos}
                  </strong>
                  <small>equipos</small>
                </span>
                <span>
                  <CalendarDays size={16} />
                  <strong>{torneo.total_partidos}</strong>
                  <small>partidos</small>
                </span>
              </div>
              <div className="tournament-card__dates">
                <span>{formatDate(torneo.fecha_inicio_torneo)}</span>
                <i />
                <span>{formatDate(torneo.fecha_fin_torneo)}</span>
              </div>
              <div className="card-title-row">
                <strong>
                  {formatMoney(torneo.costo_inscripcion, torneo.moneda)}
                </strong>
                <div className="card-actions">
                  {puedeEditar && torneo.estado_torneo === "BORRADOR" && (
                    <button
                      className="icon-button"
                      type="button"
                      onClick={() => abrirEdicion(torneo)}
                      title="Editar torneo"
                      aria-label={`Editar ${torneo.nombre}`}
                    >
                      <Edit3 size={15} />
                    </button>
                  )}
                  <Link
                    className="button button--secondary"
                    to={`/torneos/${torneo.id_torneo}`}
                  >
                    Ver detalle <ArrowUpRight size={15} />
                  </Link>
                </div>
              </div>
            </article>
          ))}
        </section>
      )}

      <Modal
        open={modal}
        onClose={() => setModal(false)}
        title={editando ? "Editar torneo" : "Crear torneo"}
        description={
          editando
            ? "La edición general está disponible mientras el torneo permanezca en BORRADOR."
            : "El torneo se registrará inicialmente en estado BORRADOR."
        }
        wide
      >
        <form onSubmit={guardar}>
          <div className="form-grid">
            <Field label="Deporte">
              <Select
                name="id_deporte"
                value={formulario.id_deporte}
                onChange={(evento) => cambiarDeporte(evento.target.value)}
                required
              >
                <option value="">Selecciona</option>
                {deportes?.resultados?.map((deporte) => (
                  <option key={deporte.id_deporte} value={deporte.id_deporte}>
                    {deporte.nombre}
                  </option>
                ))}
              </Select>
            </Field>

            <Field label="Formato">
              <Select
                name="formato_codigo"
                value={formulario.formato_codigo}
                onChange={(evento) => cambiarFormato(evento.target.value)}
                required
              >
                <option value="">Selecciona</option>
                {(formatos || []).map((formato) => (
                  <option key={formato.codigo} value={formato.codigo}>
                    {formato.nombre}
                  </option>
                ))}
              </Select>
            </Field>

            <Field label="Código">
              <Input
                name="codigo"
                value={formulario.codigo}
                onChange={cambiarCampo}
                pattern="[A-Za-z0-9_-]{3,40}"
                maxLength={40}
                required
              />
            </Field>

            <Field label="Nombre">
              <Input
                name="nombre"
                value={formulario.nombre}
                onChange={cambiarCampo}
                minLength={4}
                maxLength={150}
                required
              />
            </Field>

            <Field label="Edición">
              <Input
                name="edicion"
                value={formulario.edicion}
                onChange={cambiarCampo}
                maxLength={50}
              />
            </Field>

            <Field label="Categoría">
              <Input
                name="categoria"
                value={formulario.categoria}
                onChange={cambiarCampo}
                minLength={2}
                maxLength={100}
                required
              />
            </Field>

            <Field label="Rama">
              <Select name="rama" value={formulario.rama} onChange={cambiarCampo}>
                <option value="MASCULINO">Masculino</option>
                <option value="FEMENINO">Femenino</option>
                <option value="MIXTO">Mixto</option>
                <option value="ABIERTO">Abierto</option>
              </Select>
            </Field>

            <Field label="Máximo de equipos">
              <Input
                type="number"
                name="cantidad_maxima_equipos"
                min="2"
                max={formulario.formato_codigo === "PARTIDO_UNICO" ? 2 : 128}
                value={formulario.cantidad_maxima_equipos}
                onChange={cambiarCampo}
                disabled={formulario.formato_codigo === "PARTIDO_UNICO"}
                required
              />
            </Field>

            <Field label="Inicio inscripciones">
              <Input
                type="date"
                name="fecha_inicio_inscripcion"
                value={formulario.fecha_inicio_inscripcion}
                onChange={cambiarCampo}
                required
              />
            </Field>

            <Field label="Fin inscripciones">
              <Input
                type="date"
                name="fecha_fin_inscripcion"
                value={formulario.fecha_fin_inscripcion}
                onChange={cambiarCampo}
                min={formulario.fecha_inicio_inscripcion || undefined}
                required
              />
            </Field>

            <Field label="Inicio torneo">
              <Input
                type="date"
                name="fecha_inicio_torneo"
                value={formulario.fecha_inicio_torneo}
                onChange={cambiarCampo}
                min={formulario.fecha_fin_inscripcion || undefined}
                required
              />
            </Field>

            <Field label="Fin torneo">
              <Input
                type="date"
                name="fecha_fin_torneo"
                value={formulario.fecha_fin_torneo}
                onChange={cambiarCampo}
                min={formulario.fecha_inicio_torneo || undefined}
                required
              />
            </Field>

            <Field label="Jugadores mínimos">
              <Input
                type="number"
                name="cantidad_minima_jugadores"
                min={deporteSeleccionado?.cantidad_minima_jugadores || 1}
                max={deporteSeleccionado?.cantidad_maxima_jugadores || 100}
                value={formulario.cantidad_minima_jugadores}
                onChange={cambiarCampo}
                required
              />
            </Field>

            <Field label="Jugadores máximos">
              <Input
                type="number"
                name="cantidad_maxima_jugadores"
                min={formulario.cantidad_minima_jugadores || 1}
                max={deporteSeleccionado?.cantidad_maxima_jugadores || 100}
                value={formulario.cantidad_maxima_jugadores}
                onChange={cambiarCampo}
                required
              />
            </Field>

            <Field label="Costo de inscripción">
              <Input
                type="number"
                name="costo_inscripcion"
                min="0"
                step="0.01"
                value={formulario.costo_inscripcion}
                onChange={cambiarCampo}
                required
              />
            </Field>

            <Field label="Moneda">
              <Input
                name="moneda"
                value={formulario.moneda}
                onChange={cambiarCampo}
                pattern="[A-Za-z]{3}"
                minLength={3}
                maxLength={3}
                required
              />
            </Field>

            <Field label="Descripción" className="field--full">
              <Textarea
                name="descripcion"
                value={formulario.descripcion}
                onChange={cambiarCampo}
                maxLength={500}
              />
            </Field>

            <Checkbox
              label="Permite empate"
              name="permite_empate"
              checked={formulario.permite_empate}
              onChange={cambiarCampo}
            />
          </div>

          {errorFormulario && <div className="form-alert">{errorFormulario}</div>}

          <div className="modal-actions">
            <button
              className="button button--secondary"
              type="button"
              onClick={() => setModal(false)}
            >
              Cancelar
            </button>
            <button className="button button--primary" disabled={ocupado}>
              {ocupado
                ? "Guardando..."
                : editando
                  ? "Guardar cambios"
                  : "Crear torneo"}
            </button>
          </div>
        </form>
      </Modal>

      <Toast message={toast} onClose={() => setToast("")} />
    </>
  );
}
