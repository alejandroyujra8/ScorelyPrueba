import {
  Navigate,
  Route,
  Routes,
} from "react-router-dom";

import AppLayout from "./components/layout/AppLayout";

import {
  ALL_ROLES,
  ROLES,
} from "./config/permissions";

import ProtectedRoute from "./guards/ProtectedRoute";
import RoleRoute from "./guards/RoleRoute";

import AuditoriaPage from "./pages/auditoria/AuditoriaPage";
import LoginPage from "./pages/auth/LoginPage";
import DashboardPage from "./pages/dashboard/DashboardPage";
import DeportesPage from "./pages/deportes/DeportesPage";
import EquipoDetailPage from "./pages/equipos/EquipoDetailPage";
import EquiposPage from "./pages/equipos/EquiposPage";
import ForbiddenPage from "./pages/errors/ForbiddenPage";
import NotFoundPage from "./pages/errors/NotFoundPage";
import InscripcionDetailPage from "./pages/inscripciones/InscripcionDetailPage";
import InscripcionesPage from "./pages/inscripciones/InscripcionesPage";
import JugadorDetailPage from "./pages/jugadores/JugadorDetailPage";
import JugadoresPage from "./pages/jugadores/JugadoresPage";
import PartidoDetailPage from "./pages/partidos/PartidoDetailPage";
import PartidosPage from "./pages/partidos/PartidosPage";
import ProfilePage from "./pages/perfil/ProfilePage";
import ReportesPage from "./pages/reportes/ReportesPage";
import SqlLabPage from "./pages/sql-lab/SqlLabPage";
import TorneoDetailPage from "./pages/torneos/TorneoDetailPage";
import TorneosPage from "./pages/torneos/TorneosPage";
import UsuariosPage from "./pages/usuarios/UsuariosPage";


export default function App() {
  return (
    <Routes>
      <Route
        path="/login"
        element={<LoginPage />}
      />

      <Route element={<ProtectedRoute />}>
        <Route element={<AppLayout />}>
          <Route
            index
            element={
              <Navigate
                to="/dashboard"
                replace
              />
            }
          />

          <Route
            path="dashboard"
            element={<DashboardPage />}
          />

          <Route
            path="torneos"
            element={<TorneosPage />}
          />

          <Route
            path="torneos/:id"
            element={<TorneoDetailPage />}
          />

          <Route
            path="partidos"
            element={<PartidosPage />}
          />

          <Route
            path="partidos/:id"
            element={<PartidoDetailPage />}
          />

          <Route
            path="reportes"
            element={<ReportesPage />}
          />

          <Route
            path="perfil"
            element={<ProfilePage />}
          />

          <Route
            path="403"
            element={<ForbiddenPage />}
          />

          <Route
            element={
              <RoleRoute
                roles={[
                  ROLES.ADMINISTRADOR,
                  ROLES.ORGANIZADOR,
                  ROLES.JUGADOR,
                ]}
              />
            }
          >
            <Route
              path="equipos"
              element={<EquiposPage />}
            />

            <Route
              path="equipos/:id"
              element={
                <EquipoDetailPage />
              }
            />
          </Route>

          <Route
            element={
              <RoleRoute
                roles={[
                  ROLES.ADMINISTRADOR,
                  ROLES.ORGANIZADOR,
                ]}
              />
            }
          >
            <Route
              path="deportes"
              element={<DeportesPage />}
            />

            <Route
              path="jugadores"
              element={<JugadoresPage />}
            />

            <Route
              path="jugadores/:id"
              element={
                <JugadorDetailPage />
              }
            />

            <Route
              path="inscripciones"
              element={
                <InscripcionesPage />
              }
            />

            <Route
              path="inscripciones/:id"
              element={
                <InscripcionDetailPage />
              }
            />

          </Route>

          <Route
            element={
              <RoleRoute
                roles={[
                  ROLES.ADMINISTRADOR,
                ]}
              />
            }
          >
            <Route
              path="usuarios"
              element={<UsuariosPage />}
            />

            <Route
              path="laboratorio-sql"
              element={<SqlLabPage />}
            />

            <Route
              path="auditoria"
              element={<AuditoriaPage />}
            />
          </Route>

          <Route
            element={
              <RoleRoute
                roles={ALL_ROLES}
              />
            }
          >
            <Route
              path="*"
              element={<NotFoundPage />}
            />
          </Route>
        </Route>
      </Route>

      <Route
        path="*"
        element={
          <Navigate
            to="/login"
            replace
          />
        }
      />
    </Routes>
  );
}