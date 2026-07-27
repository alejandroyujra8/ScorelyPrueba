import {
  ArrowUpRight,
  Edit3,
  Plus,
  Power,
  RotateCcw,
  Search,
} from "lucide-react";

import {
  useState,
} from "react";

import {
  Link,
} from "react-router-dom";

import Badge from "../../components/common/Badge";
import ConfirmDialog from "../../components/common/ConfirmDialog";

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

import {
  useAuth,
} from "../../contexts/AuthContext";

import useAsyncData from "../../hooks/useAsyncData";
import { listarCatalogo } from "../../services/catalogoService";

import {
  actualizarEquipo,
  crearEquipo,
  desactivarEquipo,
  listarEquipos,
} from "../../services/equipoService";

import {
  formatDate,
  initials,
} from "../../utils/formatters";

const initialForm = {
  nombre: "",
  sigla: "",
  fecha_fundacion: "",
  descripcion: "",
  estado_codigo: "ACTIVO",
};

export default function EquiposPage() {
  const {
    usuario,
  } = useAuth();

  const canEdit = hasPermission(
    usuario,
    PERMISSIONS.MANAGE_TEAMS,
  );

  const [
    filters,
    setFilters,
  ] = useState({
    estado: "",
    busqueda: "",
  });

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
      listarEquipos({
        ...filters,
        limite: 100,
      }),

    [
      filters.estado,
      filters.busqueda,
    ],
  );

  const {
    data: estadosEquipo,
  } = useAsyncData(
    () => listarCatalogo("estados-equipo"),
    [],
  );

  const openCreate = () => {
    setEditing(null);
    setForm(initialForm);
    setModal(true);
    setFormError("");
  };

  const openEdit = (item) => {
    setEditing(item);

    setForm({
      nombre: item.nombre,
      sigla: item.sigla || "",
      fecha_fundacion:
        item.fecha_fundacion || "",

      descripcion:
        item.descripcion || "",

      estado_codigo:
        item.estado_codigo,
    });

    setModal(true);
    setFormError("");
  };

  const change = (event) => {
    setForm({
      ...form,

      [event.target.name]:
        event.target.value,
    });
  };

  const submit = async (event) => {
    event.preventDefault();

    setBusy(true);
    setFormError("");

    const payload = {
      ...form,

      nombre:
        form.nombre.trim(),

      sigla:
        form.sigla
          .trim()
          .toUpperCase(),

      descripcion:
        form.descripcion || null,
    };

    try {
      if (editing) {
        await actualizarEquipo(
          editing.id_equipo,
          payload,
        );
      } else {
        await crearEquipo(payload);
      }

      setModal(false);

      setToast(
        editing
          ? "Equipo actualizado correctamente"
          : "Equipo creado correctamente",
      );

      reload();
    } catch (err) {
      setFormError(err.message);
    } finally {
      setBusy(false);
    }
  };

  const toggle = async () => {
    if (!confirm) {
      return;
    }

    setBusy(true);

    const estaActivo =
      confirm.estado_codigo ===
      "ACTIVO";

    try {
      if (estaActivo) {
        await desactivarEquipo(
          confirm.id_equipo,
        );
      } else {
        await actualizarEquipo(
          confirm.id_equipo,
          {
            estado_codigo: "ACTIVO",
          },
        );
      }

      setToast(
        estaActivo
          ? "El equipo fue desactivado. Su información e historial siguen guardados."
          : "El equipo fue reactivado y vuelve a estar disponible.",
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
        title="Equipos"
        description="Clubes y organizaciones que participan en las competencias."
        actions={
          canEdit && (
            <button
              className="button button--primary"
              type="button"
              onClick={openCreate}
            >
              <Plus size={16} />

              Nuevo equipo
            </button>
          )
        }
      />

      <section className="toolbar card">
        <label className="search-control">
          <Search size={17} />

          <input
            value={filters.busqueda}
            onChange={(event) =>
              setFilters({
                ...filters,

                busqueda:
                  event.target.value,
              })
            }
            placeholder="Buscar por nombre o sigla"
          />
        </label>

        <select
          className="filter-select"
          value={filters.estado}
          onChange={(event) =>
            setFilters({
              ...filters,

              estado:
                event.target.value,
            })
          }
        >
          <option value="">
            Todos los estados
          </option>

          {(estadosEquipo || []).map((item) => (
            <option
              key={item.codigo}
              value={item.codigo}
            >
              {item.nombre}
            </option>
          ))}
        </select>
      </section>

      {loading ? (
        <LoadingBlock />
      ) : error ? (
        <ErrorState
          message={error}
          onRetry={reload}
        />
      ) : !data?.resultados.length ? (
        <EmptyState title="No hay equipos" />
      ) : (
        <section className="team-grid">
          {data.resultados.map(
            (item) => (
              <article
                className="card team-card"
                key={item.id_equipo}
              >
                <div className="team-card__hero">
                  <span className="team-logo">
                    {initials(
                      item.sigla,
                    )}
                  </span>

                  <Badge
                    value={
                      item.estado_codigo
                    }
                  />
                </div>

                <p className="eyebrow">
                  {item.sigla}
                </p>

                <h2>
                  {item.nombre}
                </h2>

                <p className="muted line-clamp">
                  {item.descripcion ||
                    "Sin descripción"}
                </p>

                <p className="mono">
                  FUNDADO ·{" "}
                  {formatDate(
                    item.fecha_fundacion,
                  )}
                </p>

                <div className="team-card__actions">
                  <Link
                    className="button button--secondary team-card__view-button"
                    to={`/equipos/${item.id_equipo}`}
                  >
                    Ver equipo

                    <ArrowUpRight
                      size={15}
                    />
                  </Link>

                  {canEdit && (
                    <>
                      <button
                        className="button button--secondary"
                        type="button"
                        onClick={() =>
                          openEdit(item)
                        }
                      >
                        <Edit3 size={16} />

                        Editar equipo
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
                            ? "Deja al equipo inactivo sin eliminar su información"
                            : "Devuelve al equipo al estado activo"
                        }
                        onClick={() =>
                          setConfirm(item)
                        }
                      >
                        {item.estado_codigo ===
                        "ACTIVO" ? (
                          <Power
                            size={16}
                          />
                        ) : (
                          <RotateCcw
                            size={16}
                          />
                        )}

                        {item.estado_codigo ===
                        "ACTIVO"
                          ? "Desactivar equipo"
                          : "Reactivar equipo"}
                      </button>
                    </>
                  )}
                </div>
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
            ? "Editar equipo"
            : "Nuevo equipo"
        }
      >
        <form onSubmit={submit}>
          <div className="form-grid">
            <Field
              label="Nombre"
              className="field--full"
            >
              <Input
                name="nombre"
                value={form.nombre}
                onChange={change}
                required
                minLength={3}
                maxLength={120}
              />
            </Field>

            <Field label="Sigla">
              <Input
                name="sigla"
                value={form.sigla}
                onChange={change}
                required
                minLength={2}
                maxLength={15}
              />
            </Field>

            <Field label="Fecha de fundación">
              <Input
                type="date"
                max={new Date().toISOString().slice(0, 10)}
                name="fecha_fundacion"
                value={
                  form.fecha_fundacion
                }
                onChange={change}
                required
              />
            </Field>

            <Field label="Estado">
              <Select
                name="estado_codigo"
                value={
                  form.estado_codigo
                }
                onChange={change}
              >
                {(estadosEquipo || []).map((item) => (
                  <option
                    key={item.codigo}
                    value={item.codigo}
                  >
                    {item.nombre}
                  </option>
                ))}
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
                onChange={change}
                maxLength={500}
              />
            </Field>
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
                : "Guardar equipo"}
            </button>
          </div>
        </form>
      </Modal>

      <ConfirmDialog
        open={Boolean(confirm)}
        onClose={() =>
          setConfirm(null)
        }
        onConfirm={toggle}
        busy={busy}
        title={
          confirmIsActive
            ? "Desactivar equipo"
            : "Reactivar equipo"
        }
        message={
          confirmIsActive
            ? `Al desactivar a ${confirm?.nombre || "este equipo"}, dejará de aparecer como disponible para nuevas operaciones. Sus datos, partidos e historial no se eliminarán y podrás reactivarlo después.`
            : `Al reactivar a ${confirm?.nombre || "este equipo"}, volverá a aparecer como disponible dentro del sistema.`
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