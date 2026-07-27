import { Mail, ShieldCheck, UserRound } from "lucide-react";
import PageHeader from "../../components/common/PageHeader";
import Badge from "../../components/common/Badge";
import { useAuth } from "../../contexts/AuthContext";
import { fullName, initials } from "../../utils/formatters";

export default function ProfilePage() {
  const { usuario } = useAuth();
  return <><PageHeader eyebrow="CUENTA" title="Mi perfil" description="Información de la sesión autenticada." /><section className="profile-card card"><div className="profile-card__avatar">{initials(fullName(usuario))}</div><div><h2>{fullName(usuario)}</h2><p className="muted"><Mail size={15} /> {usuario.correo}</p><p className="muted"><UserRound size={15} /> Documento {usuario.numero_documento}</p><div className="badge-row">{usuario.roles.map((role) => <Badge key={role} value={role} tone="info" />)}<Badge value={usuario.estado_codigo} /></div></div><ShieldCheck className="profile-card__shield" size={42} /></section></>;
}
