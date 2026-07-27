import { ArrowLeft, ShieldX } from "lucide-react";
import { Link } from "react-router-dom";

export default function ForbiddenPage() {
  return <section className="error-page"><span className="error-page__code">403</span><ShieldX size={38} /><h1>No tienes permisos para entrar aquí</h1><p>Tu sesión está activa, pero este módulo no está disponible para tus roles.</p><Link className="button button--primary" to="/dashboard"><ArrowLeft size={16} /> Volver al inicio</Link></section>;
}
