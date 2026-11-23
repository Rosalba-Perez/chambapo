import { useState } from "react";
import { supabase } from "../lib/supabase";
import Llave from "../components/Llave";

export default function Login() {
  const [email, setEmail] = useState(""); const [clave, setClave] = useState(""); const [error, setError] = useState(null);
  const [entrando, setEntrando] = useState(false);
  async function entrar(e) {
    e.preventDefault();
    setEntrando(true); setError(null);
    const { error } = await supabase.auth.signInWithPassword({ email, password: clave });
    if (error) setError("Correo o contraseña incorrectos.");
    setEntrando(false);
  }
  return (
    <div className="login">
      <form onSubmit={entrar}>
        <span className="logo"><Llave tam={26} /></span>
        <h1>chambapo</h1>
        <p className="sub">Panel de administración</p>
        {error && <div className="error">{error}</div>}
        <label htmlFor="correo">Correo</label>
        <input id="correo" type="email" autoComplete="email" value={email} onChange={(e) => setEmail(e.target.value)} required />
        <label htmlFor="clave">Contraseña</label>
        <input id="clave" type="password" autoComplete="current-password" value={clave} onChange={(e) => setClave(e.target.value)} required />
        <button type="submit" disabled={entrando}>{entrando ? "Entrando…" : "Entrar"}</button>
      </form>
    </div>
  );
}
