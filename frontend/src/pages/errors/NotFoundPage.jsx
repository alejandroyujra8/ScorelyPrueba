import { ArrowLeft, SearchX } from "lucide-react";
import { Link } from "react-router-dom";

export default function NotFoundPage() {
  return <section className="error-page"><span className="error-page__code">404</span><SearchX size={38} /><h1>Esta página no existe</h1><p>La dirección puede haber cambiado o el contenido ya no está disponible.</p><Link className="button button--primary" to="/dashboard"><ArrowLeft size={16} /> Volver al inicio</Link></section>;
}
