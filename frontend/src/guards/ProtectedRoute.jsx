import { Navigate, Outlet, useLocation } from "react-router-dom";
import { useAuth } from "../contexts/AuthContext";
import { LoadingScreen } from "../components/common/StateViews";

export default function ProtectedRoute() {
  const { autenticado, cargandoSesion } = useAuth();
  const location = useLocation();
  if (cargandoSesion) return <LoadingScreen label="Recuperando sesión" />;
  if (!autenticado) return <Navigate to="/login" replace state={{ from: location }} />;
  return <Outlet />;
}
