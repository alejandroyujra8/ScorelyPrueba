import {
  usarMocks,
} from "../config/environment";

import {
  mockDb,
} from "../mocks/mockData";

import {
  mockError,
  mockResult,
} from "../mocks/mockUtils";

import {
  apiGet,
  apiPost,
  eliminarSesion,
  guardarSesion,
  guardarUsuario,
  obtenerToken,
  obtenerUsuarioGuardado,
} from "./api";

const DEMO_PASSWORD = "Demo123*";

function personalizarUsuarioMock(usuario) {
  return usuario
    ? { ...usuario }
    : null;
}

export async function iniciarSesion(
  identificador,
  contrasenia,
) {
  let respuesta;

  if (usarMocks()) {
    const identificadorNormalizado =
      String(identificador || "")
        .trim()
        .toLowerCase();

    const usuarioEncontrado =
      mockDb.usuarios.find(
        (item) =>
          item.correo.toLowerCase() ===
          identificadorNormalizado ||
          item.numero_documento ===
          String(identificador).trim(),
      );

    if (
      !usuarioEncontrado ||
      contrasenia !== DEMO_PASSWORD
    ) {
      mockError(
        "Credenciales incorrectas",
        401,
      );
    }

    const usuario =
      personalizarUsuarioMock(
        usuarioEncontrado,
      );

    respuesta = await mockResult({
      access_token:
        `mock-jwt-${usuario.id_usuario}-${Date.now()}`,

      token_type: "bearer",

      expires_in: 7200,

      usuario,
    });
  } else {
    respuesta = await apiPost(
      "/api/auth/login",
      {
        identificador,
        contrasenia,
      },
    );
  }

  guardarSesion(
    respuesta.access_token,
    respuesta.usuario,
  );

  return respuesta;
}

export async function obtenerMiUsuario() {
  if (!obtenerToken()) {
    return null;
  }

  if (usarMocks()) {
    const usuarioGuardado =
      obtenerUsuarioGuardado();

    const usuarioEncontrado =
      mockDb.usuarios.find(
        (item) =>
          item.id_usuario ===
          usuarioGuardado?.id_usuario,
      );

    if (!usuarioEncontrado) {
      mockError(
        "La sesión ya no es válida",
        401,
      );
    }

    const usuario =
      personalizarUsuarioMock(
        usuarioEncontrado,
      );

    guardarUsuario(usuario);

    return mockResult(usuario);
  }

  const usuario = await apiGet(
    "/api/auth/me",
  );

  guardarUsuario(usuario);

  return usuario;
}

export function cerrarSesion() {
  eliminarSesion();
}

export function obtenerUsuarioActual() {
  if (!obtenerToken()) {
    eliminarSesion();
    return null;
  }

  const usuario =
    obtenerUsuarioGuardado();

  if (!usuario) {
    eliminarSesion();
    return null;
  }

  if (
    usarMocks() &&
    usuario?.id_usuario === 1
  ) {
    return personalizarUsuarioMock(
      usuario,
    );
  }

  return usuario;
}