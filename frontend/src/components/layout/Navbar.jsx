import { useMemo, useState } from "react";
import { NavLink, useNavigate } from "react-router-dom";
import { ChevronDown, LogOut, Menu, UserRound, X } from "lucide-react";
import { getNavigationForUser } from "../../config/permissions";
import { useAuth } from "../../contexts/AuthContext";
import { fullName, initials } from "../../utils/formatters";
import ScorelyBrand from "../brand/ScorelyBrand";

export default function Navbar() {
  const { usuario, logout } = useAuth();
  const navigate = useNavigate();
  const [menuOpen, setMenuOpen] = useState(false);
  const [profileOpen, setProfileOpen] = useState(false);
  const items = useMemo(() => getNavigationForUser(usuario), [usuario]);
  const main = items.slice(0, 5);
  const more = items.slice(5);

  const closeMenus = () => { setMenuOpen(false); setProfileOpen(false); };
  const handleLogout = () => { logout(); navigate("/login", { replace: true }); };

  return (
    <header className="navbar-shell">
      <nav className="navbar" aria-label="Navegación principal">
        <ScorelyBrand />
        <div className="navbar__links">
          {main.map((item) => <NavItem key={item.path} item={item} />)}
          {more.length > 0 && (
            <div className="navbar__dropdown">
              <button className="nav-pill" type="button" onClick={() => setMenuOpen((value) => !value)}>Más <ChevronDown size={14} /></button>
              {menuOpen && <div className="navbar__dropdown-panel">{more.map((item) => <NavLink key={item.path} to={item.path} onClick={closeMenus}>{item.label}</NavLink>)}</div>}
            </div>
          )}
        </div>
        <div className="navbar__profile">
          <button className="profile-button" type="button" onClick={() => setProfileOpen((value) => !value)} aria-expanded={profileOpen}>
            <span className="avatar">{initials(fullName(usuario))}</span>
            <span className="profile-button__text"><strong>{usuario?.nombres}</strong><small>{usuario?.roles?.join(" · ")}</small></span>
            <ChevronDown size={14} />
          </button>
          {profileOpen && <div className="profile-menu"><button type="button" onClick={() => { closeMenus(); navigate("/perfil"); }}><UserRound size={16} /> Mi perfil</button><button type="button" onClick={handleLogout}><LogOut size={16} /> Cerrar sesión</button></div>}
        </div>
        <button className="mobile-menu-button" type="button" onClick={() => setMenuOpen((value) => !value)} aria-label={menuOpen ? "Cerrar menú" : "Abrir menú"}>{menuOpen ? <X size={18} /> : <Menu size={18} />}</button>
      </nav>
      {menuOpen && <div className="mobile-menu">{items.map((item) => <NavLink key={item.path} to={item.path} onClick={closeMenus}>{item.label}</NavLink>)}<NavLink to="/perfil" onClick={closeMenus}>Perfil</NavLink><button type="button" onClick={handleLogout}>Cerrar sesión</button></div>}
    </header>
  );
}

function NavItem({ item }) {
  return <NavLink className={({ isActive }) => `nav-pill ${isActive ? "nav-pill--active" : ""}`} to={item.path}>{item.label}</NavLink>;
}
