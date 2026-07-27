import { AlertTriangle, Inbox, LoaderCircle, RefreshCw } from "lucide-react";

export function LoadingScreen({ label = "Cargando" }) {
  return <div className="state-view state-view--screen"><LoaderCircle className="spin" size={26} /><strong>{label}</strong></div>;
}

export function LoadingBlock({ label = "Cargando información" }) {
  return <div className="state-view"><div className="skeleton-stack"><span /><span /><span /></div><p>{label}</p></div>;
}

export function EmptyState({ title = "Todavía no hay información", description = "Los registros aparecerán aquí.", action = null }) {
  return <div className="state-view"><span className="state-view__icon"><Inbox size={22} /></span><h3>{title}</h3><p>{description}</p>{action}</div>;
}

export function ErrorState({ message = "No pudimos cargar la información", onRetry }) {
  return <div className="state-view state-view--error"><span className="state-view__icon"><AlertTriangle size={22} /></span><h3>Algo salió mal</h3><p>{message}</p>{onRetry && <button className="button button--secondary" type="button" onClick={onRetry}><RefreshCw size={16} /> Reintentar</button>}</div>;
}
