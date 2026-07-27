import { createContext, useCallback, useContext, useEffect, useMemo, useState } from "react";
import { EVENTO_SESION_EXPIRADA, obtenerToken } from "../services/api";
import { cerrarSesion, iniciarSesion, obtenerMiUsuario, obtenerUsuarioActual } from "../services/authService";

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [usuario, setUsuario] = useState(() => obtenerUsuarioActual());
  const [cargandoSesion, setCargandoSesion] = useState(Boolean(obtenerToken()));
  const [mensajeSesion, setMensajeSesion] = useState("");

  const verificarSesion = useCallback(async () => {
    if (!obtenerToken()) {
      setUsuario(null);
      setCargandoSesion(false);
      return;
    }
    try {
      const current = await obtenerMiUsuario();
      setUsuario(current);
    } catch {
      cerrarSesion();
      setUsuario(null);
    } finally {
      setCargandoSesion(false);
    }
  }, []);

  useEffect(() => { verificarSesion(); }, [verificarSesion]);

  useEffect(() => {
    const onExpired = (event) => {
      cerrarSesion();
      setUsuario(null);
      setCargandoSesion(false);

      setMensajeSesion(
        event.detail?.mensaje ||
        "Tu sesión expiró. Inicia sesión nuevamente.",
      );
    };
    window.addEventListener(EVENTO_SESION_EXPIRADA, onExpired);
    return () => window.removeEventListener(EVENTO_SESION_EXPIRADA, onExpired);
  }, []);

  const login = useCallback(async (identificador, contrasenia) => {
    const response = await iniciarSesion(identificador, contrasenia);
    setUsuario(response.usuario);
    setMensajeSesion("");
    return response.usuario;
  }, []);

  const logout = useCallback(() => {
    cerrarSesion();
    setUsuario(null);
  }, []);

  const value = useMemo(() => ({
    usuario, autenticado: Boolean(
      usuario && obtenerToken(),
    ), cargandoSesion, mensajeSesion, limpiarMensajeSesion: () => setMensajeSesion(""), login, logout, verificarSesion
  }), [usuario, cargandoSesion, mensajeSesion, login, logout, verificarSesion]);
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) throw new Error("useAuth debe utilizarse dentro de AuthProvider");
  return context;
}
