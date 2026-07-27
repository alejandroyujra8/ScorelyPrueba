import { Outlet } from "react-router-dom";
import Navbar from "./Navbar";

export default function AppLayout() {
  return <div className="app-shell"><Navbar /><main className="page-container"><Outlet /></main><footer className="app-footer"><span>Scorely</span><span>MVP universitario · Gestión de torneos</span></footer></div>;
}
