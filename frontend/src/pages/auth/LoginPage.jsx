import {useState} from "react";
import {Eye, EyeOff, LockKeyhole, ShieldCheck} from "lucide-react";
import {Navigate, useLocation, useNavigate} from "react-router-dom";
import ScorelyBrand from "../../components/brand/ScorelyBrand";
import {useAuth} from "../../contexts/AuthContext";

export default function LoginPage() {
    const {autenticado, login, mensajeSesion, limpiarMensajeSesion} = useAuth();
    const navigate = useNavigate();
    const location = useLocation();
    const [form, setForm] = useState({identificador: "", contrasenia: ""});
    const [showPassword, setShowPassword] = useState(false);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState("");

    if (autenticado) return <Navigate to="/dashboard" replace/>;

    const handleSubmit = async (event) => {
        event.preventDefault();
        setError("");
        limpiarMensajeSesion();
        setLoading(true);
        try {
            await login(form.identificador, form.contrasenia);
            navigate(location.state?.from?.pathname || "/dashboard", {replace: true});
        } catch (err) {
            setError(err.message || "No se pudo iniciar sesión");
        } finally {
            setLoading(false);
        }
    };

    return (
        <main className="login-page">
            <section className="login-visual" aria-label="Escena deportiva de Scorely">
                <div className="login-visual__top"><ScorelyBrand light to="/login"/><span
                    className="badge badge--warning">GESTIÓN DEPORTIVA</span></div>
                <div className="login-visual__content"><p className="eyebrow eyebrow--light">COMPITE. ORGANIZA.
                    CRECE.</p><h1>El juego empieza antes del silbato.</h1><p>Gestiona torneos, equipos y partidos desde
                    una experiencia clara, rápida y preparada para cada rol.</p></div>
            </section>
            <section className="login-form-panel">
                <div className="login-card">
                    <div className="login-card__icon"><ShieldCheck size={22}/></div>
                    <p className="eyebrow">BIENVENIDO A SCORELY</p>
                    <h2>Inicia sesión</h2>
                    <p className="login-card__intro">Ingresa con tu correo o número de documento.</p>
                    {(error || mensajeSesion) &&
                        <div className="form-alert" role="alert">{error || mensajeSesion}</div>}
                    <form onSubmit={handleSubmit}>
                        <label className="field"><span className="field__label">Correo o documento</span><input
                            className="input" autoComplete="username" value={form.identificador}
                            onChange={(e) => setForm({...form, identificador: e.target.value})}
                            placeholder="correo@ejemplo.com o documento" required minLength={3}/></label>
                        <label className="field"><span className="field__label">Contraseña</span><span
                            className="password-field"><LockKeyhole size={17}/><input className="input"
                                                                                      type={showPassword ? "text" : "password"}
                                                                                      autoComplete="current-password"
                                                                                      value={form.contrasenia}
                                                                                      onChange={(e) => setForm({
                                                                                          ...form,
                                                                                          contrasenia: e.target.value
                                                                                      })} placeholder="••••••••"
                                                                                      required minLength={6}/><button
                            type="button" onClick={() => setShowPassword((value) => !value)}
                            aria-label={showPassword ? "Ocultar contraseña" : "Mostrar contraseña"}>{showPassword ?
                            <EyeOff size={17}/> : <Eye size={17}/>}</button></span></label>
                        <button className="button button--primary button--full" type="submit"
                                disabled={loading}>{loading ? "Ingresando..." : "Entrar a Scorely"}</button>
                    </form>
                    <p className="login-card__foot">Acceso protegido con JWT · Scorely 2026</p>
                </div>
            </section>
        </main>
    );
}
