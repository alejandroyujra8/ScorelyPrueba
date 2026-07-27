import {
  KeyRound,
  Pencil,
  Plus,
  Power,
  RotateCcw,
  Search,
  ShieldCheck,
  UsersRound,
} from "lucide-react";
import { useState } from "react";

import Badge from "../../components/common/Badge";
import ConfirmDialog from "../../components/common/ConfirmDialog";
import {
  Checkbox,
  Field,
  Input,
  Select,
} from "../../components/common/FormFields";
import Modal from "../../components/common/Modal";
import PageHeader from "../../components/common/PageHeader";
import {
  EmptyState,
  ErrorState,
  LoadingBlock,
} from "../../components/common/StateViews";
import Toast from "../../components/common/Toast";
import { useAuth } from "../../contexts/AuthContext";
import useAsyncData from "../../hooks/useAsyncData";
import { listarCatalogo } from "../../services/catalogoService";
import {
  actualizarUsuario,
  crearUsuario,
  desactivarUsuario,
  listarUsuarios,
  restablecerContrasenia,
} from "../../services/usuarioService";
import { formatDateTime } from "../../utils/formatters";

const FORMULARIO_INICIAL = {
  tipo_documento_codigo: "CI",
  numero_documento: "",
  nombres: "",
  apellido_paterno: "",
  apellido_materno: "",
  fecha_nacimiento: "",
  sexo: "N",
  correo: "",
  telefono: "",
  direccion: "",
  zona: "",
  contrasenia: "",
  estado_codigo: "ACTIVO",
  roles: ["JUGADOR"],
};

function nombreCompleto(usuario) {
  return [
    usuario.nombres,
    usuario.apellido_paterno,
    usuario.apellido_materno,
  ]
    .filter(Boolean)
    .join(" ");
}

export default function UsuariosPage() {
  const { usuario: usuarioActual } = useAuth();
  const [filtros, setFiltros] = useState({
    estado: "",
    busqueda: "",
  });
  const [modal, setModal] = useState("");
  const [editando, setEditando] = useState(null);
  const [formulario, setFormulario] = useState(FORMULARIO_INICIAL);
  const [contraseniaNueva, setContraseniaNueva] = useState("");
  const [confirmacion, setConfirmacion] = useState(null);
  const [ocupado, setOcupado] = useState(false);
  const [errorFormulario, setErrorFormulario] = useState("");
  const [toast, setToast] = useState("");

  const {
    data,
    loading,
    error,
    reload,
  } = useAsyncData(
    () => listarUsuarios({ ...filtros, limite: 100 }),
    [filtros.estado, filtros.busqueda],
  );

  const { data: tiposDocumento } = useAsyncData(
    () => listarCatalogo("tipos-documento"),
    [],
  );
  const { data: estadosUsuario } = useAsyncData(
    () => listarCatalogo("estados-usuario"),
    [],
  );
  const { data: rolesSistema } = useAsyncData(
    () => listarCatalogo("roles-sistema"),
    [],
  );

  function abrirCreacion() {
    setEditando(null);
    setFormulario(FORMULARIO_INICIAL);
    setErrorFormulario("");
    setModal("usuario");
  }

  function abrirEdicion(usuario) {
    setEditando(usuario);
    setFormulario({
      tipo_documento_codigo: usuario.tipo_documento_codigo,
      numero_documento: usuario.numero_documento,
      nombres: usuario.nombres,
      apellido_paterno: usuario.apellido_paterno || "",
      apellido_materno: usuario.apellido_materno || "",
      fecha_nacimiento: usuario.fecha_nacimiento,
      sexo: usuario.sexo || "N",
      correo: usuario.correo,
      telefono: usuario.telefono || "",
      direccion: usuario.direccion || "",
      zona: usuario.zona || "",
      contrasenia: "",
      estado_codigo: usuario.estado_codigo,
      roles: usuario.roles || [],
    });
    setErrorFormulario("");
    setModal("usuario");
  }

  function abrirContrasenia(usuario) {
    setEditando(usuario);
    setContraseniaNueva("");
    setErrorFormulario("");
    setModal("contrasenia");
  }

  function cambiarCampo(evento) {
    const { name, value } = evento.target;
    setFormulario((actual) => ({ ...actual, [name]: value }));
  }

  function alternarRol(codigo) {
    if (
      editando?.id_usuario === usuarioActual?.id_usuario &&
      codigo === "ADMINISTRADOR"
    ) {
      return;
    }

    setFormulario((actual) => ({
      ...actual,
      roles: actual.roles.includes(codigo)
        ? actual.roles.filter((rol) => rol !== codigo)
        : [...actual.roles, codigo],
    }));
  }

  async function guardarUsuario(evento) {
    evento.preventDefault();
    setOcupado(true);
    setErrorFormulario("");

    if (formulario.roles.length === 0 && formulario.estado_codigo === "ACTIVO") {
      setErrorFormulario("Un usuario activo debe tener al menos un rol.");
      setOcupado(false);
      return;
    }

    const datos = {
      tipo_documento_codigo: formulario.tipo_documento_codigo,
      numero_documento: formulario.numero_documento.trim(),
      nombres: formulario.nombres.trim(),
      apellido_paterno: formulario.apellido_paterno.trim() || null,
      apellido_materno: formulario.apellido_materno.trim() || null,
      fecha_nacimiento: formulario.fecha_nacimiento,
      sexo: formulario.sexo || null,
      correo: formulario.correo.trim().toLowerCase(),
      telefono: formulario.telefono.trim() || null,
      direccion: formulario.direccion.trim() || null,
      zona: formulario.zona.trim() || null,
      estado_codigo: formulario.estado_codigo,
      roles: formulario.roles,
    };

    try {
      if (editando) {
        await actualizarUsuario(editando.id_usuario, datos);
        setToast("Usuario actualizado correctamente");
      } else {
        await crearUsuario({
          ...datos,
          contrasenia: formulario.contrasenia,
        });
        setToast("Usuario creado correctamente");
      }
      setModal("");
      reload();
    } catch (errorGuardado) {
      setErrorFormulario(errorGuardado.message);
    } finally {
      setOcupado(false);
    }
  }

  async function guardarContrasenia(evento) {
    evento.preventDefault();
    setOcupado(true);
    setErrorFormulario("");
    try {
      await restablecerContrasenia(
        editando.id_usuario,
        contraseniaNueva,
      );
      setModal("");
      setToast("Contraseña restablecida correctamente");
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
        await desactivarUsuario(confirmacion.id_usuario);
        setToast("Usuario desactivado correctamente");
      } else {
        await actualizarUsuario(confirmacion.id_usuario, {
          estado_codigo: "ACTIVO",
        });
        setToast("Usuario reactivado correctamente");
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
        eyebrow="SEGURIDAD"
        title="Usuarios y roles"
        description="Administra cuentas, estados, contraseñas y permisos generales del sistema."
        actions={
          <button
            className="button button--primary"
            type="button"
            onClick={abrirCreacion}
          >
            <Plus size={16} />
            Nuevo usuario
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
            placeholder="Documento, nombre o correo"
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
          {(estadosUsuario || []).map((estado) => (
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
        <EmptyState
          title="No se encontraron usuarios"
          description="Registra una cuenta o modifica los filtros."
        />
      ) : (
        <section className="table-wrap card">
          <table>
            <thead>
              <tr>
                <th>Usuario</th>
                <th>Documento</th>
                <th>Roles</th>
                <th>Estado</th>
                <th>Último acceso</th>
                <th>Acciones</th>
              </tr>
            </thead>
            <tbody>
              {data.resultados.map((usuario) => (
                <tr key={usuario.id_usuario}>
                  <td>
                    <strong>{nombreCompleto(usuario)}</strong>
                    <small className="table-secondary">{usuario.correo}</small>
                  </td>
                  <td>
                    {usuario.tipo_documento_codigo} {usuario.numero_documento}
                  </td>
                  <td>
                    <div className="badge-row">
                      {usuario.roles.map((rol) => (
                        <Badge key={rol} value={rol} tone="info" />
                      ))}
                      {!usuario.roles.length && <Badge value="SIN_ROL" />}
                    </div>
                  </td>
                  <td><Badge value={usuario.estado_codigo} /></td>
                  <td>
                    {usuario.ultimo_acceso
                      ? formatDateTime(usuario.ultimo_acceso)
                      : "Sin acceso"}
                  </td>
                  <td>
                    <div className="table-actions">
                      <button
                        className="icon-button"
                        type="button"
                        onClick={() => abrirEdicion(usuario)}
                        aria-label={`Editar a ${nombreCompleto(usuario)}`}
                        title="Editar usuario"
                      >
                        <Pencil size={16} />
                      </button>
                      <button
                        className="icon-button"
                        type="button"
                        onClick={() => abrirContrasenia(usuario)}
                        aria-label={`Restablecer contraseña de ${nombreCompleto(usuario)}`}
                        title="Restablecer contraseña"
                      >
                        <KeyRound size={16} />
                      </button>
                      <button
                        className="icon-button"
                        type="button"
                        onClick={() => setConfirmacion(usuario)}
                        disabled={usuario.id_usuario === usuarioActual?.id_usuario}
                        aria-label={`Cambiar estado de ${nombreCompleto(usuario)}`}
                        title={
                          usuario.id_usuario === usuarioActual?.id_usuario
                            ? "No puede cambiar el estado de su propia cuenta"
                            : usuario.estado_codigo === "ACTIVO"
                              ? "Desactivar usuario"
                              : "Reactivar usuario"
                        }
                      >
                        {usuario.estado_codigo === "ACTIVO"
                          ? <Power size={16} />
                          : <RotateCcw size={16} />}
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      )}

      <Modal
        open={modal === "usuario"}
        onClose={() => setModal("")}
        title={editando ? "Editar usuario" : "Nuevo usuario"}
        description="Los roles controlan las opciones visibles y los permisos validados por FastAPI."
        wide
      >
        <form onSubmit={guardarUsuario}>
          <div className="form-grid">
            <Field label="Tipo de documento">
              <Select
                name="tipo_documento_codigo"
                value={formulario.tipo_documento_codigo}
                onChange={cambiarCampo}
                required
              >
                {(tiposDocumento || []).map((tipo) => (
                  <option key={tipo.codigo} value={tipo.codigo}>
                    {tipo.nombre}
                  </option>
                ))}
              </Select>
            </Field>

            <Field label="Número de documento">
              <Input
                name="numero_documento"
                value={formulario.numero_documento}
                onChange={cambiarCampo}
                minLength={4}
                maxLength={30}
                required
              />
            </Field>

            <Field label="Nombres">
              <Input
                name="nombres"
                value={formulario.nombres}
                onChange={cambiarCampo}
                minLength={2}
                maxLength={100}
                required
              />
            </Field>

            <Field label="Apellido paterno">
              <Input
                name="apellido_paterno"
                value={formulario.apellido_paterno}
                onChange={cambiarCampo}
                maxLength={80}
              />
            </Field>

            <Field label="Apellido materno">
              <Input
                name="apellido_materno"
                value={formulario.apellido_materno}
                onChange={cambiarCampo}
                maxLength={80}
              />
            </Field>

            <Field label="Fecha de nacimiento">
              <Input
                type="date"
                name="fecha_nacimiento"
                value={formulario.fecha_nacimiento}
                onChange={cambiarCampo}
                max={new Date().toISOString().slice(0, 10)}
                required
              />
            </Field>

            <Field label="Sexo">
              <Select name="sexo" value={formulario.sexo} onChange={cambiarCampo}>
                <option value="N">No especificado</option>
                <option value="M">Masculino</option>
                <option value="F">Femenino</option>
                <option value="O">Otro</option>
              </Select>
            </Field>

            <Field label="Correo electrónico">
              <Input
                type="email"
                name="correo"
                value={formulario.correo}
                onChange={cambiarCampo}
                maxLength={150}
                required
              />
            </Field>

            <Field label="Teléfono">
              <Input
                name="telefono"
                value={formulario.telefono}
                onChange={cambiarCampo}
                pattern="[+]?[0-9]{7,15}"
                maxLength={20}
              />
            </Field>

            <Field label="Zona">
              <Input
                name="zona"
                value={formulario.zona}
                onChange={cambiarCampo}
                maxLength={100}
              />
            </Field>

            <Field label="Dirección" className="field--full">
              <Input
                name="direccion"
                value={formulario.direccion}
                onChange={cambiarCampo}
                maxLength={200}
              />
            </Field>

            {!editando && (
              <Field label="Contraseña temporal">
                <Input
                  type="password"
                  name="contrasenia"
                  value={formulario.contrasenia}
                  onChange={cambiarCampo}
                  minLength={8}
                  maxLength={128}
                  required
                />
              </Field>
            )}

            <Field label="Estado">
              <Select
                name="estado_codigo"
                value={formulario.estado_codigo}
                onChange={cambiarCampo}
                disabled={editando?.id_usuario === usuarioActual?.id_usuario}
              >
                {(estadosUsuario || []).map((estado) => (
                  <option key={estado.codigo} value={estado.codigo}>
                    {estado.nombre}
                  </option>
                ))}
              </Select>
            </Field>

            <div className="field field--full">
              <span className="field__label">Roles del sistema</span>
              <div className="role-selector">
                {(rolesSistema || []).map((rol) => (
                  <Checkbox
                    key={rol.codigo}
                    label={rol.nombre}
                    checked={formulario.roles.includes(rol.codigo)}
                    onChange={() => alternarRol(rol.codigo)}
                    disabled={
                      editando?.id_usuario === usuarioActual?.id_usuario &&
                      rol.codigo === "ADMINISTRADOR"
                    }
                  />
                ))}
              </div>
              <small>
                <ShieldCheck size={14} /> Los permisos también se comprueban en el backend.
              </small>
            </div>
          </div>

          {errorFormulario && <div className="form-alert">{errorFormulario}</div>}

          <div className="modal-actions">
            <button
              className="button button--secondary"
              type="button"
              onClick={() => setModal("")}
            >
              Cancelar
            </button>
            <button className="button button--primary" disabled={ocupado}>
              <UsersRound size={16} />
              {ocupado ? "Guardando..." : "Guardar usuario"}
            </button>
          </div>
        </form>
      </Modal>

      <Modal
        open={modal === "contrasenia"}
        onClose={() => setModal("")}
        title="Restablecer contraseña"
        description={editando ? nombreCompleto(editando) : "Usuario"}
      >
        <form onSubmit={guardarContrasenia}>
          <Field label="Nueva contraseña">
            <Input
              type="password"
              value={contraseniaNueva}
              onChange={(evento) => setContraseniaNueva(evento.target.value)}
              minLength={8}
              maxLength={128}
              required
            />
          </Field>
          {errorFormulario && <div className="form-alert">{errorFormulario}</div>}
          <div className="modal-actions">
            <button
              className="button button--secondary"
              type="button"
              onClick={() => setModal("")}
            >
              Cancelar
            </button>
            <button className="button button--primary" disabled={ocupado}>
              <KeyRound size={16} />
              {ocupado ? "Guardando..." : "Actualizar contraseña"}
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
            ? "Desactivar usuario"
            : "Reactivar usuario"
        }
        message={
          confirmacion?.estado_codigo === "ACTIVO"
            ? `La cuenta de ${confirmacion ? nombreCompleto(confirmacion) : "este usuario"} ya no podrá iniciar sesión.`
            : `La cuenta de ${confirmacion ? nombreCompleto(confirmacion) : "este usuario"} volverá a estar habilitada.`
        }
      />

      <Toast message={toast} onClose={() => setToast("")} />
    </>
  );
}
