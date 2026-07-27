import { Navigate, Outlet } from "react-router-dom";
import { hasPermission, hasRole } from "../config/permissions";
import { useAuth } from "../contexts/AuthContext";

export default function RoleRoute({ roles = [], permission = null }) {
  const { usuario } = useAuth();
  const allowed = permission ? hasPermission(usuario, permission) : hasRole(usuario, roles);
  return allowed ? <Outlet /> : <Navigate to="/403" replace />;
}
