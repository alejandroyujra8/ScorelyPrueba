export default function PageHeader({ eyebrow = "GESTIÓN DEPORTIVA", title, description = "", actions = null }) {
  return <header className="page-header"><div><p className="eyebrow">{eyebrow}</p><h1>{title}</h1>{description && <p className="page-header__description">{description}</p>}</div>{actions && <div className="page-header__actions">{actions}</div>}</header>;
}
