import {
  ArrowLeft,
  Flag,
  Play,
  Plus,
  UserCheck,
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
import {
  PERMISSIONS,
  hasPermission,
} from "../../config/permissions";
import { useAuth } from "../../contexts/AuthContext";
import useAsyncData from "../../hooks/useAsyncData";
import { listarCatalogo } from "../../services/catalogoService";
import { listarNomina } from "../../services/inscripcionService";
import {
  asignarArbitro,
  finalizarPartido,
  iniciarPartido,
  listarArbitros,
  listarParticipaciones,
  obtenerPartido,
  registrarParticipacion,
} from "../../services/partidoService";
import {
  formatDateTime,
  initials,
} from "../../utils/formatters";

const participationInitialForm = {
  id_jugador_inscripcion: "",
  convocado: true,
  asistio: true,
  titular: false,
  minutos_jugados: 0,
  puntos_anotados: 0,
  faltas: 0,
  amonestaciones: 0,
  expulsado: false,
  lesionado: false,
  calificacion: "",
  observaciones: "",
};

function fullName(item) {
  return [
    item?.nombres,
    item?.apellido_paterno,
    item?.apellido_materno,
  ]
    .filter(Boolean)
    .join(" ");
}

export default function PartidoDetailPage() {
  const { id } = useParams();
  const { usuario } = useAuth();

  const canAssign = hasPermission(
    usuario,
    PERMISSIONS.ASSIGN_REFEREES,
  );
  const canOperate = hasPermission(
    usuario,
    PERMISSIONS.OPERATE_MATCHES,
  );

  const [modal, setModal] = useState("");
  const [form, setForm] = useState({});
  const [busy, setBusy] = useState(false);
  const [formError, setFormError] = useState("");
  const [toast, setToast] = useState("");

  const {
    data,
    loading,
    error,
    reload,
  } = useAsyncData(async () => {
    const match = await obtenerPartido(id);

    const participationPromise = listarParticipaciones(id);
    const refereePromise = canAssign
      ? listarArbitros()
      : Promise.resolve([]);
    const refereeTypesPromise = canAssign
      ? listarCatalogo("tipos-arbitro-partido")
      : Promise.resolve([]);

    const canOperateLoadedMatch =
      canOperate &&
      (canAssign || match.arbitro_actual_asignado);

    const rosterIds = [
      match.id_inscripcion_local,
      match.id_inscripcion_visitante,
    ].filter(Boolean);

    const rosterPromise = canOperateLoadedMatch
      ? Promise.all(rosterIds.map((value) => listarNomina(value)))
      : Promise.resolve([]);

    const [
      participations,
      referees,
      refereeTypes,
      rosterGroups,
    ] = await Promise.all([
      participationPromise,
      refereePromise,
      refereeTypesPromise,
      rosterPromise,
    ]);

    return {
      match,
      participations: participations || [],
      referees: referees || [],
      refereeTypes: refereeTypes || [],
      rosters: rosterGroups.flat(),
    };
  }, [id, canAssign, canOperate]);

  const registeredPlayerIds = useMemo(
    () =>
      new Set(
        (data?.participations || []).map(
          (item) => item.id_jugador,
        ),
      ),
    [data],
  );

  const availableRoster = useMemo(
    () =>
      (data?.rosters || []).filter(
        (item) => !registeredPlayerIds.has(item.id_jugador),
      ),
    [data, registeredPlayerIds],
  );

  if (loading) {
    return <LoadingBlock />;
  }

  if (error) {
    return <ErrorState message={error} onRetry={reload} />;
  }

  const match = data.match;
  const canOperateThisMatch =
    canOperate &&
    (canAssign || match.arbitro_actual_asignado);

  const openAssign = () => {
    setForm({
      id_arbitro: "",
      tipo_arbitro:
        data.refereeTypes[0]?.codigo || "PRINCIPAL",
      observaciones: "",
    });
    setModal("arbitro");
    setFormError("");
  };

  const openParticipation = () => {
    setForm(participationInitialForm);
    setModal("participacion");
    setFormError("");
  };

  const openFinish = () => {
    setForm({
      marcador_local: match.marcador_local ?? 0,
      marcador_visitante: match.marcador_visitante ?? 0,
      desempate_local: "",
      desempate_visitante: "",
      observaciones: match.observaciones || "",
    });
    setModal("finalizar");
    setFormError("");
  };

  const start = async () => {
    setBusy(true);
    setToast("");

    try {
      await iniciarPartido(id);
      setToast("Partido iniciado correctamente");
      reload();
    } catch (err) {
      setToast(err.message);
    } finally {
      setBusy(false);
    }
  };

  const validateParticipation = () => {
    if (form.titular && !form.asistio) {
      return "Un jugador titular debe haber asistido.";
    }

    if (form.asistio && !form.convocado) {
      return "Un jugador que asistió debe estar convocado.";
    }

    if (!form.asistio && Number(form.minutos_jugados) > 0) {
      return "Un jugador ausente no puede tener minutos jugados.";
    }

    return "";
  };

  const validateFinish = () => {
    const oneTieBreakerMissing =
      (form.desempate_local === "") !==
      (form.desempate_visitante === "");

    if (oneTieBreakerMissing) {
      return "Debes registrar ambos marcadores de desempate o dejar ambos vacíos.";
    }

    return "";
  };

  const submit = async (event) => {
    event.preventDefault();
    setFormError("");

    if (modal === "participacion") {
      const message = validateParticipation();
      if (message) {
        setFormError(message);
        return;
      }
    }

    if (modal === "finalizar") {
      const message = validateFinish();
      if (message) {
        setFormError(message);
        return;
      }
    }

    setBusy(true);

    try {
      if (modal === "arbitro") {
        await asignarArbitro(id, {
          id_arbitro: Number(form.id_arbitro),
          tipo_arbitro: form.tipo_arbitro,
          observaciones: form.observaciones.trim() || null,
        });
      }

      if (modal === "participacion") {
        await registrarParticipacion(id, {
          id_jugador_inscripcion: Number(
            form.id_jugador_inscripcion,
          ),
          convocado: Boolean(form.convocado),
          asistio: Boolean(form.asistio),
          titular: Boolean(form.titular),
          minutos_jugados: Number(form.minutos_jugados),
          puntos_anotados: Number(form.puntos_anotados),
          faltas: Number(form.faltas),
          amonestaciones: Number(form.amonestaciones),
          expulsado: Boolean(form.expulsado),
          lesionado: Boolean(form.lesionado),
          calificacion:
            form.calificacion === ""
              ? null
              : Number(form.calificacion),
          estadisticas: {},
          observaciones: form.observaciones.trim() || null,
        });
      }

      if (modal === "finalizar") {
        await finalizarPartido(id, {
          marcador_local: Number(form.marcador_local),
          marcador_visitante: Number(
            form.marcador_visitante,
          ),
          desempate_local:
            form.desempate_local === ""
              ? null
              : Number(form.desempate_local),
          desempate_visitante:
            form.desempate_visitante === ""
              ? null
              : Number(form.desempate_visitante),
          observaciones: form.observaciones.trim() || null,
        });
      }

      setModal("");
      setToast(
        modal === "arbitro"
          ? "Árbitro asignado correctamente"
          : modal === "participacion"
            ? "Participación registrada correctamente"
            : "Partido finalizado correctamente",
      );
      reload();
    } catch (err) {
      setFormError(err.message);
    } finally {
      setBusy(false);
    }
  };

  const setAttendance = (checked) => {
    setForm((current) => ({
      ...current,
      asistio: checked,
      convocado: checked ? true : current.convocado,
      titular: checked ? current.titular : false,
      minutos_jugados: checked ? current.minutos_jugados : 0,
    }));
  };

  const setCalled = (checked) => {
    setForm((current) => ({
      ...current,
      convocado: checked,
      asistio: checked ? current.asistio : false,
      titular: checked ? current.titular : false,
      minutos_jugados: checked ? current.minutos_jugados : 0,
    }));
  };

  return (
    <>
      <Link className="back-link" to="/partidos">
        <ArrowLeft size={16} /> Volver a partidos
      </Link>

      <section className="match-hero">
        <div className="match-hero__meta">
          <span className="mono">
            {match.codigo} · {match.jornada}
          </span>
          <Badge value={match.estado_partido} />
        </div>

        <p>
          {match.torneo} ·{" "}
          {formatDateTime(match.fecha_hora_inicio)} ·{" "}
          {match.lugar || "Lugar por confirmar"}
        </p>

        <div className="match-hero__score">
          <div>
            <span className="team-mark team-mark--hero">
              {initials(match.equipo_local || "Local")}
            </span>
            <strong>{match.equipo_local || "Por definir"}</strong>
            <small>LOCAL</small>
          </div>

          <b>
            {match.marcador_local ?? "—"}
            <i>:</i>
            {match.marcador_visitante ?? "—"}
          </b>

          <div>
            <span className="team-mark team-mark--hero">
              {initials(match.equipo_visitante || "Visitante")}
            </span>
            <strong>
              {match.equipo_visitante || "Por definir"}
            </strong>
            <small>VISITANTE</small>
          </div>
        </div>

        <div className="match-hero__actions">
          {match.estado_partido === "PROGRAMADO" &&
            canAssign && (
              <button
                className="button button--ghost-light"
                type="button"
                onClick={openAssign}
              >
                <UserCheck size={16} /> Asignar árbitro
              </button>
            )}

          {match.estado_partido === "PROGRAMADO" &&
            canOperateThisMatch && (
              <button
                className="button button--light"
                type="button"
                onClick={start}
                disabled={busy}
              >
                <Play size={16} />
                {busy ? "Iniciando..." : "Iniciar partido"}
              </button>
            )}

          {match.estado_partido === "EN_CURSO" &&
            canOperateThisMatch && (
              <>
                <button
                  className="button button--ghost-light"
                  type="button"
                  onClick={openParticipation}
                  disabled={!availableRoster.length}
                >
                  <Plus size={16} /> Registrar participación
                </button>
                <button
                  className="button button--light"
                  type="button"
                  onClick={openFinish}
                >
                  <Flag size={16} /> Finalizar partido
                </button>
              </>
            )}
        </div>
      </section>

      <section className="detail-grid">
        <article className="card detail-panel detail-panel--wide">
          <div className="card-title-row">
            <div>
              <p className="eyebrow">
                ASISTENCIA Y ESTADÍSTICAS
              </p>
              <h2>Participaciones</h2>
            </div>

            {match.estado_partido === "EN_CURSO" &&
              canOperateThisMatch &&
              availableRoster.length > 0 && (
                <button
                  className="button button--secondary"
                  type="button"
                  onClick={openParticipation}
                >
                  <Plus size={15} /> Añadir
                </button>
              )}
          </div>

          {data.participations.length ? (
            <div className="table-wrap table-wrap--flush">
              <table>
                <thead>
                  <tr>
                    <th>Jugador</th>
                    <th>Equipo</th>
                    <th>Asistió</th>
                    <th>Min.</th>
                    <th>Puntos</th>
                    <th>Faltas</th>
                    <th>Amon.</th>
                    <th>Calificación</th>
                  </tr>
                </thead>
                <tbody>
                  {data.participations.map((item) => (
                    <tr key={item.id_jugador_partido}>
                      <td>{fullName(item)}</td>
                      <td>{item.equipo}</td>
                      <td>{item.asistio ? "Sí" : "No"}</td>
                      <td>{item.minutos_jugados}</td>
                      <td>{item.puntos_anotados}</td>
                      <td>{item.faltas}</td>
                      <td>{item.amonestaciones}</td>
                      <td>{item.calificacion ?? "—"}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : (
            <EmptyState
              title="Sin participaciones registradas"
              description="Las asistencias y estadísticas se registran mientras el partido está en curso."
            />
          )}
        </article>
      </section>

      <Modal
        open={Boolean(modal)}
        onClose={() => setModal("")}
        title={
          modal === "arbitro"
            ? "Asignar árbitro"
            : modal === "finalizar"
              ? "Finalizar partido"
              : "Registrar participación"
        }
      >
        <form onSubmit={submit}>
          <div className="form-grid">
            {modal === "arbitro" && (
              <>
                <Field label="Árbitro" className="field--full">
                  <Select
                    value={form.id_arbitro || ""}
                    onChange={(event) =>
                      setForm({
                        ...form,
                        id_arbitro: event.target.value,
                      })
                    }
                    required
                  >
                    <option value="">Selecciona</option>
                    {data.referees.map((item) => (
                      <option
                        key={item.id_arbitro}
                        value={item.id_arbitro}
                      >
                        {item.nombre_completo} ·{" "}
                        {item.nivel || "Sin nivel"}
                      </option>
                    ))}
                  </Select>
                </Field>

                <Field label="Tipo">
                  <Select
                    value={form.tipo_arbitro || "PRINCIPAL"}
                    onChange={(event) =>
                      setForm({
                        ...form,
                        tipo_arbitro: event.target.value,
                      })
                    }
                    required
                  >
                    {data.refereeTypes.map((item) => (
                      <option key={item.codigo} value={item.codigo}>
                        {item.nombre}
                      </option>
                    ))}
                  </Select>
                </Field>
              </>
            )}

            {modal === "participacion" && (
              <>
                <Field
                  label="Jugador de nómina"
                  className="field--full"
                >
                  <Select
                    value={form.id_jugador_inscripcion || ""}
                    onChange={(event) =>
                      setForm({
                        ...form,
                        id_jugador_inscripcion:
                          event.target.value,
                      })
                    }
                    required
                  >
                    <option value="">Selecciona</option>
                    {availableRoster.map((item) => (
                      <option
                        key={item.id_jugador_inscripcion}
                        value={item.id_jugador_inscripcion}
                      >
                        {fullName(item)} · #
                        {item.numero_camiseta ?? "—"}
                      </option>
                    ))}
                  </Select>
                </Field>

                <Checkbox
                  label="Convocado"
                  checked={Boolean(form.convocado)}
                  onChange={(event) =>
                    setCalled(event.target.checked)
                  }
                />
                <Checkbox
                  label="Asistió"
                  checked={Boolean(form.asistio)}
                  onChange={(event) =>
                    setAttendance(event.target.checked)
                  }
                />
                <Checkbox
                  label="Titular"
                  checked={Boolean(form.titular)}
                  disabled={!form.asistio}
                  onChange={(event) =>
                    setForm({
                      ...form,
                      titular: event.target.checked,
                    })
                  }
                />

                <Field label="Minutos">
                  <Input
                    type="number"
                    min="0"
                    max="1000"
                    value={form.minutos_jugados ?? 0}
                    disabled={!form.asistio}
                    onChange={(event) =>
                      setForm({
                        ...form,
                        minutos_jugados: event.target.value,
                      })
                    }
                  />
                </Field>

                <Field label="Puntos">
                  <Input
                    type="number"
                    min="0"
                    value={form.puntos_anotados ?? 0}
                    onChange={(event) =>
                      setForm({
                        ...form,
                        puntos_anotados: event.target.value,
                      })
                    }
                  />
                </Field>

                <Field label="Faltas">
                  <Input
                    type="number"
                    min="0"
                    max="100"
                    value={form.faltas ?? 0}
                    onChange={(event) =>
                      setForm({
                        ...form,
                        faltas: event.target.value,
                      })
                    }
                  />
                </Field>

                <Field label="Amonestaciones">
                  <Input
                    type="number"
                    min="0"
                    max="100"
                    value={form.amonestaciones ?? 0}
                    onChange={(event) =>
                      setForm({
                        ...form,
                        amonestaciones: event.target.value,
                      })
                    }
                  />
                </Field>

                <Field label="Calificación">
                  <Input
                    type="number"
                    min="0"
                    max="10"
                    step="0.1"
                    value={form.calificacion ?? ""}
                    onChange={(event) =>
                      setForm({
                        ...form,
                        calificacion: event.target.value,
                      })
                    }
                  />
                </Field>

                <Checkbox
                  label="Expulsado"
                  checked={Boolean(form.expulsado)}
                  onChange={(event) =>
                    setForm({
                      ...form,
                      expulsado: event.target.checked,
                    })
                  }
                />
                <Checkbox
                  label="Lesionado"
                  checked={Boolean(form.lesionado)}
                  onChange={(event) =>
                    setForm({
                      ...form,
                      lesionado: event.target.checked,
                    })
                  }
                />
              </>
            )}

            {modal === "finalizar" && (
              <>
                <Field label="Marcador local">
                  <Input
                    type="number"
                    min="0"
                    value={form.marcador_local ?? 0}
                    onChange={(event) =>
                      setForm({
                        ...form,
                        marcador_local: event.target.value,
                      })
                    }
                    required
                  />
                </Field>
                <Field label="Marcador visitante">
                  <Input
                    type="number"
                    min="0"
                    value={form.marcador_visitante ?? 0}
                    onChange={(event) =>
                      setForm({
                        ...form,
                        marcador_visitante: event.target.value,
                      })
                    }
                    required
                  />
                </Field>
                <Field label="Desempate local">
                  <Input
                    type="number"
                    min="0"
                    value={form.desempate_local ?? ""}
                    onChange={(event) =>
                      setForm({
                        ...form,
                        desempate_local: event.target.value,
                      })
                    }
                  />
                </Field>
                <Field label="Desempate visitante">
                  <Input
                    type="number"
                    min="0"
                    value={form.desempate_visitante ?? ""}
                    onChange={(event) =>
                      setForm({
                        ...form,
                        desempate_visitante: event.target.value,
                      })
                    }
                  />
                </Field>
              </>
            )}

            {Boolean(modal) && (
              <Field
                label="Observaciones"
                className="field--full"
              >
                <Textarea
                  value={form.observaciones || ""}
                  maxLength={500}
                  onChange={(event) =>
                    setForm({
                      ...form,
                      observaciones: event.target.value,
                    })
                  }
                />
              </Field>
            )}
          </div>

          {modal === "arbitro" && !data.referees.length && (
            <div className="form-alert">
              No hay árbitros activos con el rol correspondiente.
            </div>
          )}

          {formError && (
            <div className="form-alert">{formError}</div>
          )}

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
                busy ||
                (modal === "arbitro" && !data.referees.length) ||
                (modal === "participacion" &&
                  !availableRoster.length)
              }
            >
              {busy ? "Guardando..." : "Confirmar"}
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
