import { useEffect, useState } from "react";
import { Routes, Route, NavLink, Navigate } from "react-router-dom";
import { supabase } from "./lib/supabase";
import Login from "./pages/Login";
import Resumen from "./pages/Resumen";
import Demanda from "./pages/Demanda";
import MapaCalor from "./pages/MapaCalor";
import Predicciones from "./pages/Predicciones";
import Usuarios from "./pages/Usuarios";
import Llave from "./components/Llave";

export default function App() {
  const [sesion, setSesion] = useState(undefined);
  const [rol, setRol] = useState(null);

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => setSesion(data.session));
    const { data: sub } = supabase.auth.onAuthStateChange((_e, s) => setSesion(s));
    return () => sub.subscription.unsubscribe();
  }, []);

  useEffect(() => {
    if (!sesion) return setRol(null);
    supabase.from("perfiles").select("rol").eq("id", sesion.user.id).single().then(({ data }) => setRol(data?.rol));
  }, [sesion]);

  if (sesion === undefined) return null;
  if (!sesion) return <Login />;
  if (rol && rol !== "admin") return (
    <div className="login"><div className="mensaje">
      <p>Esta cuenta no tiene rol de administrador.</p>
      <button className="periodo" onClick={() => supabase.auth.signOut()}>Cerrar sesión</button>
    </div></div>
  );

  return (
    <div className="app">
      <nav className="nav">
        <div className="marca">
          <span className="logo"><Llave /></span>
          <span><span className="texto">chambapo</span><small>Panel de administración</small></span>
        </div>
        {[["/", "Resumen"], ["/demanda", "Demanda y conversión"], ["/mapa", "Mapas de calor"], ["/predicciones", "Predicciones"], ["/usuarios", "Usuarios"]].map(([to, t]) => (
          <NavLink key={to} to={to} end={to === "/"} className={({ isActive }) => (isActive ? "activo" : "")}>{t}</NavLink>
        ))}
        <div className="pie">{sesion.user.email}<br /><button onClick={() => supabase.auth.signOut()}>Cerrar sesión</button></div>
      </nav>
      <main className="main">
        <Routes>
          <Route path="/" element={<Resumen />} />
          <Route path="/demanda" element={<Demanda />} />
          <Route path="/mapa" element={<MapaCalor />} />
          <Route path="/predicciones" element={<Predicciones />} />
          <Route path="/usuarios" element={<Usuarios />} />
          <Route path="*" element={<Navigate to="/" />} />
        </Routes>
      </main>
    </div>
  );
}
