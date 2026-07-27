import {
  Edit3,
  Plus,
  Power,
  RotateCcw,
  Search,
} from "lucide-react";

import {
  useMemo,
  useState,
} from "react";

import Badge from "../../components/common/Badge";
import ConfirmDialog from "../../components/common/ConfirmDialog";

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

import {
  PERMISSIONS,
  hasPermission,
} from "../../config/permissions";

import {
  useAuth,
} from "../../contexts/AuthContext";

import useAsyncData from "../../hooks/useAsyncData";

import {
  actualizarDeporte,
  crearDeporte,
  desactivarDeporte,
  listarDeportes,
} from "../../services/deporteService";

const initialForm = {
  codigo: "",
  nombre: "",
  descripcion: "",
  cantidad_minima_jugadores: 5,
  cantidad_maxima_jugadores: 20,
  cantidad_titulares: 5,
  tipo_marcador: "GOL",
  permite_empate: true,
  puntos_victoria: 3,
  puntos_empate: 1,
  puntos_derrota: 0,
  estado_codigo: "ACTIVO",
};

export default function DeportesPage() {
  const {
    usuario,
  } = useAuth();

  const canEdit = hasPermission(
    usuario,
    PERMISSIONS.MANAGE_CATALOGS,
  );

  const [
    estado,
    setEstado,
  ] = useState("");

  const [
    query,
    setQuery,
  ] = useState("");

  const [
    modal,
    setModal,
  ] = useState(false);

  const [
    editing,
    setEditing,
  ] = useState(null);

  const [
    form,
    setForm,
  ] = useState(initialForm);

  const [
    busy,
    setBusy,
  ] = useState(false);

  const [
    formError,
    setFormError,
  ] = useState("");

  const [
    confirm,
    setConfirm,
  ] = useState(null);

  const [
    toast,
    setToast,
  ] = useState("");

  const {
    data,
    loading,
    error,
    reload,
  } = useAsyncData(
    () =>
      listarDeportes({
        estado,
        limite: 100,
      }),

    [estado],
  );

  const rows = useMemo(
    () =>
      (data?.resultados || []).filter(
        (item) =>
          `${item.nombre} ${item.codigo}`
            .toLowerCase()
            .includes(
              query.toLowerCase(),
            ),
      ),

    [
      data,
      query,
    ],
  );

  const openCreate = () => {
    setEditing(null);
    setForm(initialForm);
    setFormError("");
    setModal(true);
  };

  const openEdit = (item) => {
    setEditing(item);

    setForm({
      codigo: item.codigo,
      nombre: item.nombre,
      descripcion: item.descripcion || "",
      cantidad_minima_jugadores: item.cantidad_minima_jugadores,
      cantidad_maxima_jugadores: item.cantidad_maxima_jugadores,
      cantidad_titulares: item.cantidad_titulares,
      tipo_marcador: item.tipo_marcador,
      permite_empate: item.permite_empate,
      puntos_victoria: item.puntos_victoria,
      puntos_empate: item.puntos_empate,
      puntos_derrota: item.puntos_derrota,
      estado_codigo: item.estado_codigo,
    });

    setFormError("");
    setModal(true);
  };

  const handleChange = (event) => {
    const {
      name,
      value,
      type,
      checked,
    } = event.target;

    setForm((current) => ({
      ...current,

      [name]:
        type === "checkbox"
          ? checked
          : value,
    }));
  };

  const handleSubmit = async (
    event,
  ) => {
    event.preventDefault();

    setBusy(true);
    setFormError("");

    const payload = {
      codigo:
        form.codigo
          .trim()
          .toUpperCase(),

      nombre:
        form.nombre.trim(),

      descripcion:
        form.descripcion || null,

      cantidad_minima_jugadores:
        Number(
          form.cantidad_minima_jugadores,
        ),

      cantidad_maxima_jugadores:
        Number(
          form.cantidad_maxima_jugadores,
        ),

      cantidad_titulares:
        Number(
          form.cantidad_titulares,
        ),

      tipo_marcador:
        form.tipo_marcador
          .trim()
          .toUpperCase(),

      puntos_victoria:
        Number(
          form.puntos_victoria,
        ),

      puntos_empate:
        Number(
          form.puntos_empate,
        ),

      puntos_derrota:
        Number(
          form.puntos_derrota,
        ),

      permite_empate:
        Boolean(form.permite_empate),

      estado_codigo:
        form.estado_codigo,
    };

    if (
      payload.cantidad_maxima_jugadores <
      payload.cantidad_minima_jugadores
    ) {
      setFormError(
        "La cantidad máxima no puede ser menor que la mínima.",
      );
      setBusy(false);
      return;
    }

    if (
      payload.cantidad_titulares <
        payload.cantidad_minima_jugadores ||
      payload.cantidad_titulares >
        payload.cantidad_maxima_jugadores
    ) {
      setFormError(
        "Los titulares deben estar entre el mínimo y el máximo de jugadores.",
      );
      setBusy(false);
      return;
    }

    try {
      if (editing) {
        await actualizarDeporte(
          editing.id_deporte,
          payload,
        );
      } else {
        await crearDeporte(payload);
      }

      setModal(false);

      setToast(
        editing
          ? "Deporte actualizado correctamente"
          : "Deporte creado correctamente",
      );

      reload();
    } catch (err) {
      setFormError(err.message);
    } finally {
      setBusy(false);
    }
  };

  const toggleStatus = async () => {
    if (!confirm) {
      return;
    }

    setBusy(true);

    const estaActivo =
      confirm.estado_codigo ===
      "ACTIVO";

    try {
      if (estaActivo) {
        await desactivarDeporte(
          confirm.id_deporte,
        );
      } else {
        await actualizarDeporte(
          confirm.id_deporte,
          {
            estado_codigo: "ACTIVO",
          },
        );
      }

      setToast(
        estaActivo
          ? "El deporte fue desactivado. Su configuración continúa guardada."
          : "El deporte fue reactivado y vuelve a estar disponible.",
      );

      setConfirm(null);
      reload();
    } catch (err) {
      setToast(err.message);
    } finally {
      setBusy(false);
    }
  };

  const confirmIsActive =
    confirm?.estado_codigo ===
    "ACTIVO";

  return (
    <>
      <PageHeader
        title="Deportes"
        description="Reglas deportivas que utilizan torneos, equipos y partidos."
        actions={
          canEdit && (
            <button
              className="button button--primary"
              type="button"
              onClick={openCreate}
            >
              <Plus size={16} />

              Nuevo deporte
            </button>
          )
        }
      />

      <section className="toolbar card">
        <label className="search-control">
          <Search size={17} />

          <input
            value={query}
            onChange={(event) =>
              setQuery(
                event.target.value,
              )
            }
            placeholder="Buscar deporte"
          />
        </label>

        <select
          className="filter-select"
          value={estado}
          onChange={(event) =>
            setEstado(
              event.target.value,
            )
          }
        >
          <option value="">
            Todos los estados
          </option>

          <option value="ACTIVO">
            Activos
          </option>

          <option value="INACTIVO">
            Inactivos
          </option>
        </select>
      </section>

      {loading ? (
        <LoadingBlock />
      ) : error ? (
        <ErrorState
          message={error}
          onRetry={reload}
        />
      ) : rows.length === 0 ? (
        <EmptyState
          title="No encontramos deportes"
          description="Prueba con otro filtro o registra el primero."
        />
      ) : (
        <section className="sport-grid">
          {rows.map(
            (item) => (
              <article
                className="card sport-card"
                key={item.id_deporte}
              >
                <div className="card-title-row">
                  <span className="sport-card__mark">
                    {item.nombre
                      .slice(0, 2)
                      .toUpperCase()}
                  </span>

                  <Badge
                    value={
                      item.estado_codigo
                    }
                  />
                </div>

                <p className="eyebrow">
                  {item.codigo}
                </p>

                <h2>
                  {item.nombre}
                </h2>

                <p className="muted line-clamp">
                  {item.descripcion ||
                    "Sin descripción"}
                </p>

                <div className="sport-card__rules">
                  <span>
                    <small>
                      Plantel
                    </small>

                    <strong>
                      {
                        item.cantidad_minima_jugadores
                      }
                      –
                      {
                        item.cantidad_maxima_jugadores
                      }
                    </strong>
                  </span>

                  <span>
                    <small>
                      Titulares
                    </small>

                    <strong>
                      {
                        item.cantidad_titulares
                      }
                    </strong>
                  </span>

                  <span>
                    <small>
                      Marcador
                    </small>

                    <strong>
                      {
                        item.tipo_marcador
                      }
                    </strong>
                  </span>
                </div>

                {canEdit && (
                  <div className="sport-card__actions">
                    <button
                      className="button button--secondary"
                      type="button"
                      onClick={() =>
                        openEdit(item)
                      }
                    >
                      <Edit3 size={15} />

                      Editar deporte
                    </button>

                    <button
                      className={`button ${
                        item.estado_codigo ===
                        "ACTIVO"
                          ? "button--danger"
                          : "button--secondary"
                      }`}
                      type="button"
                      title={
                        item.estado_codigo ===
                        "ACTIVO"
                          ? "Deja el deporte inactivo sin eliminar su configuración"
                          : "Devuelve el deporte al estado activo"
                      }
                      onClick={() =>
                        setConfirm(item)
                      }
                    >
                      {item.estado_codigo ===
                      "ACTIVO" ? (
                        <Power
                          size={15}
                        />
                      ) : (
                        <RotateCcw
                          size={15}
                        />
                      )}

                      {item.estado_codigo ===
                      "ACTIVO"
                        ? "Desactivar deporte"
                        : "Reactivar deporte"}
                    </button>
                  </div>
                )}
              </article>
            ),
          )}
        </section>
      )}

      <Modal
        open={modal}
        onClose={() =>
          setModal(false)
        }
        title={
          editing
            ? "Editar deporte"
            : "Nuevo deporte"
        }
        description="Los nombres de propiedades respetan el contrato de FastAPI."
        wide
      >
        <form
          onSubmit={
            handleSubmit
          }
        >
          <div className="form-grid">
            <Field label="Código">
              <Input
                name="codigo"
                value={form.codigo}
                onChange={
                  handleChange
                }
                required
                minLength={2}
                maxLength={40}
                pattern="[A-Za-z0-9_]+"
              />
            </Field>

            <Field label="Nombre">
              <Input
                name="nombre"
                value={form.nombre}
                onChange={
                  handleChange
                }
                required
                minLength={3}
                maxLength={100}
              />
            </Field>

            <Field label="Jugadores mínimos">
              <Input
                type="number"
                min="1"
                max="100"
                name="cantidad_minima_jugadores"
                value={
                  form.cantidad_minima_jugadores
                }
                onChange={
                  handleChange
                }
                required
              />
            </Field>

            <Field label="Jugadores máximos">
              <Input
                type="number"
                min="1"
                max="100"
                name="cantidad_maxima_jugadores"
                value={
                  form.cantidad_maxima_jugadores
                }
                onChange={
                  handleChange
                }
                required
              />
            </Field>

            <Field label="Titulares">
              <Input
                type="number"
                min="1"
                max="100"
                name="cantidad_titulares"
                value={
                  form.cantidad_titulares
                }
                onChange={
                  handleChange
                }
                required
              />
            </Field>

            <Field label="Tipo de marcador">
              <Input
                name="tipo_marcador"
                value={
                  form.tipo_marcador
                }
                onChange={
                  handleChange
                }
                required
                minLength={2}
                maxLength={30}
                pattern="[A-Za-z0-9_]+"
              />
            </Field>

            <Field label="Puntos por victoria">
              <Input
                type="number"
                min="0"
                max="100"
                name="puntos_victoria"
                value={
                  form.puntos_victoria
                }
                onChange={
                  handleChange
                }
              />
            </Field>

            <Field label="Puntos por empate">
              <Input
                type="number"
                min="0"
                max="100"
                name="puntos_empate"
                value={
                  form.puntos_empate
                }
                onChange={
                  handleChange
                }
              />
            </Field>

            <Field label="Puntos por derrota">
              <Input
                type="number"
                min="0"
                max="100"
                name="puntos_derrota"
                value={
                  form.puntos_derrota
                }
                onChange={
                  handleChange
                }
              />
            </Field>

            <Field label="Estado">
              <Select
                name="estado_codigo"
                value={
                  form.estado_codigo
                }
                onChange={
                  handleChange
                }
              >
                <option value="ACTIVO">
                  ACTIVO
                </option>

                <option value="INACTIVO">
                  INACTIVO
                </option>
              </Select>
            </Field>

            <Field
              label="Descripción"
              className="field--full"
            >
              <Textarea
                name="descripcion"
                value={
                  form.descripcion
                }
                onChange={
                  handleChange
                }
                maxLength={500}
              />
            </Field>

            <Checkbox
              label="Permite empate"
              name="permite_empate"
              checked={
                form.permite_empate
              }
              onChange={
                handleChange
              }
            />
          </div>

          {formError && (
            <div className="form-alert">
              {formError}
            </div>
          )}

          <div className="modal-actions">
            <button
              className="button button--secondary"
              type="button"
              onClick={() =>
                setModal(false)
              }
            >
              Cancelar
            </button>

            <button
              className="button button--primary"
              disabled={busy}
            >
              {busy
                ? "Guardando..."
                : "Guardar deporte"}
            </button>
          </div>
        </form>
      </Modal>

      <ConfirmDialog
        open={Boolean(confirm)}
        onClose={() =>
          setConfirm(null)
        }
        onConfirm={
          toggleStatus
        }
        busy={busy}
        title={
          confirmIsActive
            ? "Desactivar deporte"
            : "Reactivar deporte"
        }
        message={
          confirmIsActive
            ? `Al desactivar ${confirm?.nombre || "este deporte"}, dejará de estar disponible para crear nuevas competencias. Su configuración y los registros existentes no serán eliminados.`
            : `Al reactivar ${confirm?.nombre || "este deporte"}, volverá a estar disponible para nuevas competencias.`
        }
        confirmLabel={
          confirmIsActive
            ? "Sí, desactivar"
            : "Sí, reactivar"
        }
        confirmVariant={
          confirmIsActive
            ? "danger"
            : "primary"
        }
      />

      <Toast
        message={toast}
        onClose={() =>
          setToast("")
        }
      />
    </>
  );
}