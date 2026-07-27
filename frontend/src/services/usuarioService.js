import { usarMocks } from "../config/environment";
import { mockDb, nextId } from "../mocks/mockData";
import { filterText, mockError, mockResult } from "../mocks/mockUtils";
import {
  apiDelete,
  apiGet,
  apiPatch,
  apiPost,
  crearQueryString,
} from "./api";

function completarUsuarioMock(usuario) {
  return {
    tipo_documento_codigo: "CI",
    fecha_nacimiento: "2000-01-01",
    sexo: null,
    telefono: null,
    direccion: null,
    zona: null,
    intentos_fallidos: 0,
    ultimo_acceso: null,
    fecha_registro: new Date().toISOString(),
    fecha_actualizacion: new Date().toISOString(),
    ...usuario,
  };
}

export async function listarUsuarios({
  estado = "",
  busqueda = "",
  limite = 50,
  desplazamiento = 0,
} = {}) {
  if (!usarMocks()) {
    return apiGet(
      `/api/usuarios${crearQueryString({
        estado,
        busqueda,
        limite,
        desplazamiento,
      })}`,
    );
  }

  let resultados = mockDb.usuarios.map(completarUsuarioMock);
  if (estado) {
    resultados = resultados.filter(
      (usuario) => usuario.estado_codigo === estado,
    );
  }
  if (busqueda) {
    resultados = resultados.filter((usuario) =>
      filterText(
        `${usuario.numero_documento} ${usuario.nombres} ${usuario.apellido_paterno || ""} ${usuario.correo}`,
        busqueda,
      ),
    );
  }

  return mockResult({
    total: resultados.length,
    limite,
    desplazamiento,
    resultados: resultados.slice(
      desplazamiento,
      desplazamiento + limite,
    ),
  });
}

export async function obtenerUsuario(id) {
  if (!usarMocks()) return apiGet(`/api/usuarios/${id}`);
  const usuario = mockDb.usuarios.find(
    (item) => item.id_usuario === Number(id),
  );
  if (!usuario) mockError("Usuario no encontrado", 404);
  return mockResult(completarUsuarioMock(usuario));
}

export async function crearUsuario(datos) {
  if (!usarMocks()) return apiPost("/api/usuarios", datos);

  if (
    mockDb.usuarios.some(
      (usuario) =>
        usuario.correo.toLowerCase() === datos.correo.toLowerCase(),
    )
  ) {
    mockError("Ya existe un usuario con ese correo", 409);
  }

  const usuario = completarUsuarioMock({
    ...datos,
    id_usuario: nextId(mockDb.usuarios, "id_usuario"),
  });
  delete usuario.contrasenia;
  mockDb.usuarios.unshift(usuario);
  return mockResult(usuario);
}

export async function actualizarUsuario(id, datos) {
  if (!usarMocks()) return apiPatch(`/api/usuarios/${id}`, datos);
  const indice = mockDb.usuarios.findIndex(
    (usuario) => usuario.id_usuario === Number(id),
  );
  if (indice < 0) mockError("Usuario no encontrado", 404);

  mockDb.usuarios[indice] = completarUsuarioMock({
    ...mockDb.usuarios[indice],
    ...datos,
    fecha_actualizacion: new Date().toISOString(),
  });
  return mockResult(mockDb.usuarios[indice]);
}

export async function restablecerContrasenia(id, contrasenia) {
  if (!usarMocks()) {
    return apiPatch(`/api/usuarios/${id}/contrasenia`, {
      contrasenia,
    });
  }
  return obtenerUsuario(id);
}

export async function desactivarUsuario(id) {
  if (!usarMocks()) return apiDelete(`/api/usuarios/${id}`);
  return actualizarUsuario(id, { estado_codigo: "INACTIVO" });
}
