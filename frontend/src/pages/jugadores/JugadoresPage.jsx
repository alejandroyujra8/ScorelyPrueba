import {
  ArrowUpRight,
  Edit3,
  Plus,
  Power,
  RotateCcw,
  Search,
} from "lucide-react";
import { useState } from "react";
import { Link } from "react-router-dom";

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
import { PERMISSIONS, hasPermission } from "../../config/permissions";
import { useAuth } from "../../contexts/AuthContext";
import useAsyncData from "../../hooks/useAsyncData";
import { listarCatalogo } from "../../services/catalogoService";
import { listarEquipos } from "../../services/equipoService";
import {
  actualizarJugador,
  crearJugador,
  desactivarJugador,
  listarJugadores,
  listarUsuariosDisponiblesJugador,
} from "../../services/jugadorService";
import { initials } from "../../utils/formatters";

const FORMULARIO_INICIAL = {
  id_usuario: "",
  alias_deportivo: "",
  observaciones: "",
  estado_codigo: "ACTIVO",
};

function nombreJugador(jugador) {
  return [
    jugador.nombres,
    jugador.apellido_paterno,
    jugador.apellido_materno,
  ]
    .filter(Boolean)
    .join(" ");
}

export default function JugadoresPage() {
  const { usuario } = useAuth();
  const puedeEditar = hasPermission(usuario, PERMISSIONS.MANAGE_PLAYERS);

  const [filtros, setFiltros] = useState({
    estado: "",
    id_equipo: "",
    busqueda: "",
  });
  const [modal, setModal] = useState(false);
  const [editando, setEditando] = useState(null);
  const [formulario, setFormulario] = useState(FORMULARIO_INICIAL);
  const [ocupado, setOcupado] = useState(false);
  const [errorFormulario, setErrorFormulario] = useState("");
  const [confirmacion, setConfirmacion] = useState(null);
  const [toast, setToast] = useState("");

  const {
    data,
    loading,
    error,
    reload,
  } = useAsyncData(
    () => listarJugadores({ ...filtros, limite: 100 }),
    [filtros.estado, filtros.id_equipo, filtros.busqueda],
  );

  const { data: equipos } = useAsyncData(
    () => listarEquipos({ estado: "ACTIVO", limite: 100 }),
    [],
  );
  const { data: estadosPerfil } = useAsyncData(
    () => listarCatalogo("estados-perfil"),
    [],
  );
  const {
    data: usuariosDisponibles,
    reload: recargarUsuariosDisponibles,
  } = useAsyncData(
    listarUsuariosDisponiblesJugador,
    [],
  );

  function abrirCreacion() {
    setEditando(null);
    setFormulario({
      ...FORMULARIO_INICIAL,
      id_usuario: usuariosDisponibles?.[0]
        ? String(usuariosDisponibles[0].id_usuario)
        : "",
    });
    setErrorFormulario("");
    setModal(true);
  }

  function abrirEdicion(jugador) {
    setEditando(jugador);
    setFormulario({
      id_usuario: String(jugador.id_jugador),
      alias_deportivo: jugador.alias_deportivo || "",
      observaciones: jugador.observaciones || "",
      estado_codigo: jugador.estado_codigo,
    });
    setErrorFormulario("");
    setModal(true);
  }

  function cambiarCampo(evento) {
    const { name, value } = evento.target;
    setFormulario((actual) => ({ ...actual, [name]: value }));
  }

  async function guardar(evento) {
    evento.preventDefault();
    setOcupado(true);
    setErrorFormulario("");

    const datos = {
      alias_deportivo: formulario.alias_deportivo.trim() || null,
      observaciones: formulario.observaciones.trim() || null,
      estado_codigo: formulario.estado_codigo,
    };

    try {
      if (editando) {
        await actualizarJugador(editando.id_jugador, datos);
        setToast("Jugador actualizado correctamente");
      } else {
        if (!formulario.id_usuario) {
          setErrorFormulario(
            "Selecciona un usuario activo que todavía no tenga perfil de jugador.",
          );
          return;
        }
        await crearJugador({
          ...datos,
          id_usuario: Number(formulario.id_usuario),
        });
        setToast("Perfil de jugador creado correctamente");
      }
      setModal(false);
      setEditando(null);
      reload();
      recargarUsuariosDisponibles();
    } catch (errorGuardado) {
      setErrorFormulario(errorGuardado.message);
    } finally {
      setOcupado(false);
    }
  }

  async function cambiarEstado() {
    if (!confirmacion) return;
    setOcupado(true);
    try {
      if (confirmacion.estado_codigo === "ACTIVO") {
        await desactivarJugador(confirmacion.id_jugador);
        setToast("Jugador desactivado correctamente");
      } else {
        await actualizarJugador(confirmacion.id_jugador, {
          estado_codigo: "ACTIVO",
        });
        setToast("Jugador reactivado correctamente");
      }
      setConfirmacion(null);
      reload();
    } catch (errorEstado) {
      setToast(errorEstado.message);
    } finally {
      setOcupado(false);
    }
  }

  return (
    <>
      <PageHeader
        title="Jugadores"
        description="Perfiles deportivos, membresías y rendimiento."
        actions={
          puedeEditar && (
            <button
              className="button button--primary"
              type="button"
              onClick={abrirCreacion}
            >
              <Plus size={16} />
              Nuevo perfil
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
            placeholder="Documento, nombre o alias"
          />
        </label>

        <select
          className="filter-select"
          value={filtros.id_equipo}
          onChange={(evento) =>
            setFiltros({ ...filtros, id_equipo: evento.target.value })
          }
        >
          <option value="">Todos los equipos</option>
          {equipos?.resultados?.map((equipo) => (
            <option key={equipo.id_equipo} value={equipo.id_equipo}>
              {equipo.nombre}
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
          {(estadosPerfil || []).map((estado) => (
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
        <EmptyState title="No hay jugadores para este filtro" />
      ) : (
        <section className="player-grid">
          {data.resultados.map((jugador) => {
            const nombre = nombreJugador(jugador);
            return (
              <article className="card player-card" key={jugador.id_jugador}>
                <div className="player-card__top">
                  <span className="avatar avatar--large">
                    {initials(nombre)}
                  </span>
                  <Badge value={jugador.estado_codigo} />
                </div>
                <h2>{nombre}</h2>
                <p className="muted">
                  {jugador.alias_deportivo
                    ? `“${jugador.alias_deportivo}”`
                    : "Sin alias deportivo"}
                </p>
                <div className="player-meta">
                  <span>
                    <small>Equipo</small>
                    <strong>{jugador.equipo_actual || "Sin equipo"}</strong>
                  </span>
                  <span>
                    <small>Posición</small>
                    <strong>{jugador.posicion_actual || "—"}</strong>
                  </span>
                  <span>
                    <small>Camiseta</small>
                    <strong>{jugador.numero_camiseta_actual ?? "—"}</strong>
                  </span>
                </div>
                <div className="card-actions">
                  <Link
                    className="button button--secondary"
                    to={`/jugadores/${jugador.id_jugador}`}
                  >
                    Ver perfil <ArrowUpRight size={15} />
                  </Link>
                  {puedeEditar && (
                    <>
                      <button
                        className="icon-button"
                        type="button"
                        onClick={() => abrirEdicion(jugador)}
                        aria-label={`Editar ${nombre}`}
                      >
                        <Edit3 size={16} />
                      </button>
                      <button
                        className="icon-button"
                        type="button"
                        onClick={() => setConfirmacion(jugador)}
                        aria-label={`Cambiar estado de ${nombre}`}
                      >
                        {jugador.estado_codigo === "ACTIVO" ? (
                          <Power size={16} />
                        ) : (
                          <RotateCcw size={16} />
                        )}
                      </button>
                    </>
                  )}
                </div>
              </article>
            );
          })}
        </section>
      )}

      <Modal
        open={modal}
        onClose={() => setModal(false)}
        title={editando ? "Editar jugador" : "Nuevo perfil de jugador"}
        description={
          editando
            ? "Actualiza la información del perfil deportivo."
            : "Selecciona una cuenta activa que todavía no tenga perfil de jugador."
        }
      >
        <form onSubmit={guardar}>
          <div className="form-grid">
            {!editando && (
              <Field label="Usuario">
                <Select
                  name="id_usuario"
                  value={formulario.id_usuario}
                  onChange={cambiarCampo}
                  required
                >
                  <option value="">Selecciona una cuenta</option>
                  {(usuariosDisponibles || []).map((opcion) => (
                    <option key={opcion.id_usuario} value={opcion.id_usuario}>
                      {opcion.nombre_completo} · {opcion.numero_documento}
                    </option>
                  ))}
                </Select>
              </Field>
            )}

            <Field label="Alias deportivo">
              <Input
                name="alias_deportivo"
                value={formulario.alias_deportivo}
                onChange={cambiarCampo}
                minLength={2}
                maxLength={80}
              />
            </Field>

            <Field label="Estado">
              <Select
                name="estado_codigo"
                value={formulario.estado_codigo}
                onChange={cambiarCampo}
              >
                {(estadosPerfil || []).map((estado) => (
                  <option key={estado.codigo} value={estado.codigo}>
                    {estado.nombre}
                  </option>
                ))}
              </Select>
            </Field>

            <Field label="Observaciones" className="field--full">
              <Textarea
                name="observaciones"
                value={formulario.observaciones}
                onChange={cambiarCampo}
                maxLength={500}
              />
            </Field>
          </div>

          {!editando && usuariosDisponibles?.length === 0 && (
            <div className="form-alert">
              No hay cuentas disponibles. Crea o edita una cuenta desde Usuarios y
              asígnale el rol JUGADOR.
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
              disabled={ocupado || (!editando && usuariosDisponibles?.length === 0)}
            >
              {ocupado ? "Guardando..." : "Guardar jugador"}
            </button>
          </div>
        </form>
      </Modal>

      <ConfirmDialog
        open={Boolean(confirmacion)}
        onClose={() => setConfirmacion(null)}
        onConfirm={cambiarEstado}
        busy={ocupado}
        title={
          confirmacion?.estado_codigo === "ACTIVO"
            ? "Desactivar jugador"
            : "Reactivar jugador"
        }
        message={`¿Confirmas el cambio de estado de ${
          confirmacion ? nombreJugador(confirmacion) : "este jugador"
        }?`}
      />

      <Toast message={toast} onClose={() => setToast("")} />
    </>
  );
}
