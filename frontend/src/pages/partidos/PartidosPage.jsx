import {
  ArrowUpRight,
  CalendarPlus,
  Search,
} from "lucide-react";
import { useMemo, useState } from "react";
import { Link } from "react-router-dom";

import Badge from "../../components/common/Badge";
import {
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
import {
  PERMISSIONS,
  hasPermission,
} from "../../config/permissions";
import { useAuth } from "../../contexts/AuthContext";
import useAsyncData from "../../hooks/useAsyncData";
import { listarCatalogo } from "../../services/catalogoService";
import { listarInscripciones } from "../../services/inscripcionService";
import {
  listarLugares,
  listarPartidos,
  programarPartido,
} from "../../services/partidoService";
import {
  listarTorneos,
  obtenerEstructura,
} from "../../services/torneoService";
import { formatDateTime } from "../../utils/formatters";

function fechaHoraLocal(valor) {
  return valor ? String(valor).slice(0, 16) : "";
}

const initialForm = {
  id_torneo: "",
  id_jornada: "",
  id_lugar: "",
  codigo: "",
  numero_partido: 1,
  fecha_hora_inicio: "",
  fecha_hora_fin: "",
  id_inscripcion_local: "",
  id_inscripcion_visitante: "",
  nombre_ronda: "",
  observaciones: "",
};

export default function PartidosPage() {
  const { usuario } = useAuth();
  const canSchedule = hasPermission(
    usuario,
    PERMISSIONS.SCHEDULE_MATCHES,
  );

  const [filters, setFilters] = useState({
    id_torneo: "",
    estado: "",
  });
  const [viewFilter, setViewFilter] = useState("TODOS");
  const [modal, setModal] = useState(false);
  const [form, setForm] = useState(initialForm);
  const [options, setOptions] = useState({
    jornadas: [],
    inscripciones: [],
  });
  const [loadingOptions, setLoadingOptions] = useState(false);
  const [busy, setBusy] = useState(false);
  const [formError, setFormError] = useState("");
  const [toast, setToast] = useState("");

  const {
    data,
    loading,
    error,
    reload,
  } = useAsyncData(
    () => listarPartidos(filters),
    [filters.id_torneo, filters.estado],
  );

  const { data: tournaments } = useAsyncData(
    () => listarTorneos(),
    [],
  );

  const { data: places } = useAsyncData(
    () => listarLugares(),
    [canSchedule],
    canSchedule,
  );

  const { data: matchStates } = useAsyncData(
    () => listarCatalogo("estados-partido"),
    [],
  );

  const jornadaSeleccionada = useMemo(
    () =>
      options.jornadas.find(
        (jornada) => String(jornada.id_jornada) === String(form.id_jornada),
      ) || null,
    [form.id_jornada, options.jornadas],
  );

  const schedulableTournaments = useMemo(
    () =>
      (tournaments?.resultados || []).filter(
        (item) =>
          !["FINALIZADO", "CANCELADO"].includes(
            item.estado_torneo,
          ),
      ),
    [tournaments],
  );

  const filtered = useMemo(
    () =>
      (data?.resultados || []).filter((item) => {
        if (viewFilter === "TODOS") {
          return true;
        }

        const date = new Date(item.fecha_hora_inicio);
        const now = new Date();

        if (viewFilter === "HOY") {
          return date.toDateString() === now.toDateString();
        }

        if (viewFilter === "SEMANA") {
          const end = new Date(
            now.getTime() + 7 * 24 * 60 * 60 * 1000,
          );
          return date >= now && date <= end;
        }

        return item.estado_partido === "FINALIZADO";
      }),
    [data, viewFilter],
  );

  const openCreate = () => {
    setForm(initialForm);
    setOptions({ jornadas: [], inscripciones: [] });
    setFormError("");
    setModal(true);
  };

  const tournamentChanged = async (id) => {
    setForm((current) => ({
      ...current,
      id_torneo: id,
      id_jornada: "",
      id_inscripcion_local: "",
      id_inscripcion_visitante: "",
    }));
    setOptions({ jornadas: [], inscripciones: [] });
    setFormError("");

    if (!id) {
      return;
    }

    setLoadingOptions(true);

    try {
      const [structure, registrations] = await Promise.all([
        obtenerEstructura(id),
        listarInscripciones({
          id_torneo: id,
          estado: "HABILITADA",
        }),
      ]);

      setOptions({
        jornadas: structure.jornadas || [],
        inscripciones: registrations.resultados || [],
      });
    } catch (err) {
      setFormError(err.message);
    } finally {
      setLoadingOptions(false);
    }
  };

  const jornadaChanged = (value) => {
    const jornada = options.jornadas.find(
      (item) => String(item.id_jornada) === String(value),
    );
    setForm((current) => ({
      ...current,
      id_jornada: value,
      fecha_hora_inicio: fechaHoraLocal(jornada?.fecha_inicio),
      fecha_hora_fin: fechaHoraLocal(jornada?.fecha_fin),
    }));
  };

  const changeLocalTeam = (value) => {
    setForm((current) => ({
      ...current,
      id_inscripcion_local: value,
      id_inscripcion_visitante:
        String(current.id_inscripcion_visitante) ===
        String(value)
          ? ""
          : current.id_inscripcion_visitante,
    }));
  };

  const submit = async (event) => {
    event.preventDefault();
    setFormError("");

    if (
      String(form.id_inscripcion_local) ===
      String(form.id_inscripcion_visitante)
    ) {
      setFormError(
        "El equipo local y el visitante deben ser diferentes.",
      );
      return;
    }

    const start = new Date(form.fecha_hora_inicio);
    const end = new Date(form.fecha_hora_fin);

    if (
      Number.isNaN(start.getTime()) ||
      Number.isNaN(end.getTime()) ||
      end <= start
    ) {
      setFormError(
        "La fecha y hora de finalización debe ser posterior al inicio.",
      );
      return;
    }

    setBusy(true);

    try {
      await programarPartido({
        id_jornada: Number(form.id_jornada),
        id_lugar: Number(form.id_lugar),
        codigo: form.codigo.trim().toUpperCase(),
        numero_partido: Number(form.numero_partido),
        fecha_hora_inicio: form.fecha_hora_inicio,
        fecha_hora_fin: form.fecha_hora_fin,
        id_inscripcion_local: Number(
          form.id_inscripcion_local,
        ),
        id_inscripcion_visitante: Number(
          form.id_inscripcion_visitante,
        ),
        id_grupo_torneo: null,
        nombre_ronda: form.nombre_ronda.trim() || null,
        observaciones: form.observaciones.trim() || null,
      });

      setModal(false);
      setToast("Partido programado correctamente");
      setForm(initialForm);
      setOptions({ jornadas: [], inscripciones: [] });
      reload();
    } catch (err) {
      setFormError(err.message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <>
      <PageHeader
        title="Partidos"
        description="Programación, operación y resultados de los encuentros."
        actions={
          canSchedule && (
            <button
              className="button button--primary"
              type="button"
              onClick={openCreate}
            >
              <CalendarPlus size={16} />
              Programar partido
            </button>
          )
        }
      />

      <section className="toolbar card">
        <label className="search-control">
          <Search size={17} />
          <span>Filtrar encuentros</span>
        </label>

        <select
          className="filter-select"
          value={filters.id_torneo}
          onChange={(event) =>
            setFilters({
              ...filters,
              id_torneo: event.target.value,
            })
          }
        >
          <option value="">Todos los torneos</option>
          {(tournaments?.resultados || []).map((item) => (
            <option
              key={item.id_torneo}
              value={item.id_torneo}
            >
              {item.nombre}
            </option>
          ))}
        </select>

        <select
          className="filter-select"
          value={filters.estado}
          onChange={(event) =>
            setFilters({
              ...filters,
              estado: event.target.value,
            })
          }
        >
          <option value="">Todos los estados</option>
          {(matchStates || []).map((item) => (
            <option key={item.codigo} value={item.codigo}>
              {item.nombre}
            </option>
          ))}
        </select>
      </section>

      <nav className="tabs tabs--compact">
        {[
          ["TODOS", "Todos"],
          ["HOY", "Hoy"],
          ["SEMANA", "Esta semana"],
          ["FINALIZADOS", "Finalizados"],
        ].map(([value, label]) => (
          <button
            type="button"
            className={viewFilter === value ? "active" : ""}
            key={value}
            onClick={() => setViewFilter(value)}
          >
            {label}
          </button>
        ))}
      </nav>

      {loading ? (
        <LoadingBlock />
      ) : error ? (
        <ErrorState message={error} onRetry={reload} />
      ) : !filtered.length ? (
        <EmptyState title="No hay partidos para este filtro" />
      ) : (
        <section className="match-list">
          {filtered.map((item) => (
            <article
              className={`match-card card ${
                item.estado_partido === "EN_CURSO"
                  ? "match-card--live"
                  : ""
              }`}
              key={item.id_partido}
            >
              <div className="match-card__meta">
                <span className="mono">
                  {item.jornada} ·{" "}
                  {formatDateTime(item.fecha_hora_inicio)}
                </span>
                <Badge value={item.estado_partido} />
              </div>

              <div className="match-card__score">
                <span>
                  <strong>
                    {item.equipo_local || "Por definir"}
                  </strong>
                  <small>LOCAL</small>
                </span>

                <b>
                  {item.marcador_local ?? "—"}
                  <i>:</i>
                  {item.marcador_visitante ?? "—"}
                </b>

                <span>
                  <strong>
                    {item.equipo_visitante || "Por definir"}
                  </strong>
                  <small>VISITANTE</small>
                </span>
              </div>

              <div className="match-card__footer">
                <span>
                  {item.torneo} ·{" "}
                  {item.lugar || "Lugar por confirmar"}
                </span>
                <Link
                  className="button button--secondary"
                  to={`/partidos/${item.id_partido}`}
                >
                  Ver partido <ArrowUpRight size={15} />
                </Link>
              </div>
            </article>
          ))}
        </section>
      )}

      <Modal
        open={modal}
        onClose={() => setModal(false)}
        title="Programar partido"
        description="Selecciona una jornada y dos equipos habilitados del mismo torneo."
        wide
      >
        <form onSubmit={submit}>
          <div className="form-grid">
            <Field label="Torneo">
              <Select
                value={form.id_torneo}
                onChange={(event) =>
                  tournamentChanged(event.target.value)
                }
                required
              >
                <option value="">Selecciona</option>
                {schedulableTournaments.map((item) => (
                  <option
                    key={item.id_torneo}
                    value={item.id_torneo}
                  >
                    {item.nombre}
                  </option>
                ))}
              </Select>
            </Field>

            <Field label="Jornada">
              <Select
                value={form.id_jornada}
                onChange={(event) =>
                  jornadaChanged(event.target.value)
                }
                disabled={!form.id_torneo || loadingOptions}
                required
              >
                <option value="">
                  {loadingOptions
                    ? "Cargando..."
                    : "Selecciona"}
                </option>
                {options.jornadas.map((item) => (
                  <option
                    key={item.id_jornada}
                    value={item.id_jornada}
                  >
                    {item.nombre}
                  </option>
                ))}
              </Select>
            </Field>

            <Field label="Lugar">
              <Select
                value={form.id_lugar}
                onChange={(event) =>
                  setForm({
                    ...form,
                    id_lugar: event.target.value,
                  })
                }
                required
              >
                <option value="">Selecciona</option>
                {(places || []).map((item) => (
                  <option
                    key={item.id_lugar}
                    value={item.id_lugar}
                  >
                    {item.nombre}
                  </option>
                ))}
              </Select>
            </Field>

            <Field label="Código">
              <Input
                value={form.codigo}
                minLength={3}
                maxLength={50}
                pattern="[A-Za-z0-9_-]+"
                onChange={(event) =>
                  setForm({
                    ...form,
                    codigo: event.target.value.toUpperCase(),
                  })
                }
                required
              />
            </Field>

            <Field label="Número de partido">
              <Input
                type="number"
                min="1"
                max="10000"
                value={form.numero_partido}
                onChange={(event) =>
                  setForm({
                    ...form,
                    numero_partido: event.target.value,
                  })
                }
                required
              />
            </Field>

            <Field label="Ronda">
              <Input
                value={form.nombre_ronda}
                maxLength={100}
                onChange={(event) =>
                  setForm({
                    ...form,
                    nombre_ronda: event.target.value,
                  })
                }
              />
            </Field>

            <Field label="Inicio">
              <Input
                type="datetime-local"
                min={fechaHoraLocal(jornadaSeleccionada?.fecha_inicio) || undefined}
                max={fechaHoraLocal(jornadaSeleccionada?.fecha_fin) || undefined}
                value={form.fecha_hora_inicio}
                onChange={(event) =>
                  setForm({
                    ...form,
                    fecha_hora_inicio: event.target.value,
                  })
                }
                required
              />
            </Field>

            <Field label="Fin">
              <Input
                type="datetime-local"
                min={form.fecha_hora_inicio || fechaHoraLocal(jornadaSeleccionada?.fecha_inicio) || undefined}
                max={fechaHoraLocal(jornadaSeleccionada?.fecha_fin) || undefined}
                value={form.fecha_hora_fin}
                onChange={(event) =>
                  setForm({
                    ...form,
                    fecha_hora_fin: event.target.value,
                  })
                }
                required
              />
            </Field>

            <Field label="Equipo local">
              <Select
                value={form.id_inscripcion_local}
                onChange={(event) =>
                  changeLocalTeam(event.target.value)
                }
                disabled={!form.id_torneo || loadingOptions}
                required
              >
                <option value="">Selecciona</option>
                {options.inscripciones.map((item) => (
                  <option
                    key={item.id_inscripcion}
                    value={item.id_inscripcion}
                  >
                    {item.equipo}
                  </option>
                ))}
              </Select>
            </Field>

            <Field label="Equipo visitante">
              <Select
                value={form.id_inscripcion_visitante}
                onChange={(event) =>
                  setForm({
                    ...form,
                    id_inscripcion_visitante:
                      event.target.value,
                  })
                }
                disabled={!form.id_inscripcion_local}
                required
              >
                <option value="">Selecciona</option>
                {options.inscripciones
                  .filter(
                    (item) =>
                      String(item.id_inscripcion) !==
                      String(form.id_inscripcion_local),
                  )
                  .map((item) => (
                    <option
                      key={item.id_inscripcion}
                      value={item.id_inscripcion}
                    >
                      {item.equipo}
                    </option>
                  ))}
              </Select>
            </Field>

            <Field
              label="Observaciones"
              className="field--full"
            >
              <Textarea
                value={form.observaciones}
                maxLength={500}
                onChange={(event) =>
                  setForm({
                    ...form,
                    observaciones: event.target.value,
                  })
                }
              />
            </Field>
          </div>

          {form.id_torneo &&
            !loadingOptions &&
            !options.jornadas.length && (
              <div className="form-alert">
                El torneo seleccionado todavía no tiene jornadas.
              </div>
            )}

          {form.id_torneo &&
            !loadingOptions &&
            options.inscripciones.length < 2 && (
              <div className="form-alert">
                Se necesitan al menos dos inscripciones habilitadas.
              </div>
            )}

          {formError && (
            <div className="form-alert">{formError}</div>
          )}

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
              disabled={
                busy ||
                loadingOptions ||
                !options.jornadas.length ||
                options.inscripciones.length < 2
              }
            >
              {busy ? "Programando..." : "Programar"}
            </button>
          </div>
        </form>
      </Modal>

      <Toast
        message={toast}
        onClose={() => setToast("")}
      />
    </>
  );
}
