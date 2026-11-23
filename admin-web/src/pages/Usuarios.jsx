import { useState } from "react";
import { supabase } from "../lib/supabase";
import { useDatos } from "../components/useDatos";

export default function Usuarios() {
  const [tick, setTick] = useState(0);
  const pendientes = useDatos(async () => {
    const { data, error } = await supabase.from("prestadores")
      .select("id, oficios, zona_habitual, documento_url, documento_reverso_url, certificado_url, verificado, perfiles(nombre, telefono, suspendido, foto_url)")
      .eq("verificado", false);
    if (error) throw error; return data;
  }, [tick]);
  const reportes = useDatos(async () => {
    const { data, error } = await supabase.from("reportes")
      .select("id, motivo, creado_en, atendido, solicitud:solicitudes(id, estado, en_revision), autor:perfiles!reportes_autor_id_fkey(id, nombre, rol, suspendido), reportado:perfiles!reportes_reportado_id_fkey(id, nombre, rol, suspendido)")
      .eq("atendido", false).order("creado_en");
    if (error) throw error; return data;
  }, [tick]);
  // Cuentas suspendidas que el administrador puede reactivar
  const vetados = useDatos(async () => {
    const { data, error } = await supabase.from("perfiles")
      .select("id, nombre, rol, telefono, foto_url, creado_en")
      .eq("suspendido", true).neq("rol", "admin").order("nombre");
    if (error) throw error; return data;
  }, [tick]);
  const historial = useDatos(async () => {
    const { data, error } = await supabase.from("reportes")
      .select("id, motivo, creado_en, atendido, reportado_id, solicitud:solicitudes(id, estado, en_revision), autor:perfiles!reportes_autor_id_fkey(id, nombre), reportado:perfiles!reportes_reportado_id_fkey(id, nombre, rol, telefono, suspendido)")
      .order("creado_en", { ascending: false });
    if (error) throw error; return data;
  }, [tick]);

  // Junta los reportes de cada persona reportada
  const acusados = Object.values((historial.datos || []).reduce((acc, r) => {
    if (!r.reportado) return acc;
    const a = acc[r.reportado.id] ??= { ...r.reportado, total: 0, abiertos: 0, ultimo: r.creado_en, reportes: [] };
    a.total += 1;
    if (!r.atendido) a.abiertos += 1;
    a.reportes.push(r);
    return acc;
  }, {})).sort((x, y) => y.abiertos - x.abiertos || y.total - x.total);
  const reportesDe = (id) => (historial.datos || []).filter((r) => r.reportado_id === id);

  const verDocumento = async (ruta) => {
    if (/^https?:\/\//.test(ruta)) { window.open(ruta, "_blank", "noopener"); return; }
    const { data, error } = await supabase.storage.from("documentos").createSignedUrl(ruta, 300);
    if (error) { window.alert("No se pudo abrir el documento: " + error.message); return; }
    window.open(data.signedUrl, "_blank", "noopener");
  };
  const verificar = async (id) => { await supabase.from("prestadores").update({ verificado: true }).eq("id", id); setTick(tick + 1); };
  const suspender = async (id) => { await supabase.from("perfiles").update({ suspendido: true }).eq("id", id); setTick(tick + 1); };
  const vetar = async (p) => {
    if (!window.confirm(`¿Vetar a ${p.nombre}? No podrá volver a usar Chambapo hasta que se reactive su cuenta.`)) return;
    await suspender(p.id);
  };
  const desvetar = async (p) => {
    if (!window.confirm(`¿Desvetar a ${p.nombre}? Podrá volver a usar Chambapo de inmediato.`)) return;
    const { error } = await supabase.from("perfiles").update({ suspendido: false }).eq("id", p.id);
    if (error) { window.alert("No se pudo reactivar la cuenta: " + error.message); return; }
    setTick(tick + 1);
  };
  const etiquetaRol = (rol) => (rol === "prestador" ? "Técnico" : "Cliente");
  const fecha = (f) => new Date(f).toLocaleDateString("es-CO");
  const atender = async (id) => { await supabase.from("reportes").update({ atendido: true }).eq("id", id); setTick(tick + 1); };
  const enRevision = (r) => r.solicitud?.en_revision && !["cancelada", "finalizada"].includes(r.solicitud?.estado);
  const resolver = async (r) => {
    if (!window.confirm("¿Cerrar la revisión? El servicio quedará cancelado. Veta antes al técnico o al cliente si corresponde.")) return;
    const { error } = await supabase.from("solicitudes")
      .update({ estado: "cancelada", contratada: false, cerrado_en: new Date().toISOString(),
                motivo_cancelacion: "Cerrada por el administrador tras la revisión" })
      .eq("id", r.solicitud.id);
    if (error) { window.alert("No se pudo cerrar el servicio: " + error.message); return; }
    await atender(r.id);
  };

  return (
    <>
      <div className="cabecera"><div><h1>Usuarios</h1><p>Prestadores por verificar, reportes, usuarios vetados y con inconvenientes</p></div></div>
      <div className="panel">
        <h2>Prestadores pendientes de verificación</h2>
        {!pendientes.datos?.length ? <div className="vacio">Nadie en espera.</div> : (
          <table className="tabla">
            <thead><tr><th>Nombre</th><th>Oficios</th><th>Zona</th><th>Foto</th><th>Cédula</th><th>Certificado</th><th></th></tr></thead>
            <tbody>{pendientes.datos.map((p) => (
              <tr key={p.id}><td>{p.perfiles?.nombre}</td><td>{p.oficios.join(", ")}</td><td>{p.zona_habitual}</td>
                <td>{p.perfiles?.foto_url
                  ? <a href={p.perfiles.foto_url} target="_blank" rel="noreferrer"><img src={p.perfiles.foto_url} alt={`Foto de ${p.perfiles?.nombre}`} width="40" height="40" style={{ borderRadius: "50%", objectFit: "cover" }} /></a>
                  : "Sin foto"}</td>
                <td>{p.documento_url || p.documento_reverso_url
                  ? <>{p.documento_url && <button className="periodo" onClick={() => verDocumento(p.documento_url)}>Frente</button>}{" "}
                      {p.documento_reverso_url && <button className="periodo" onClick={() => verDocumento(p.documento_reverso_url)}>Reverso</button>}</>
                  : "Sin adjuntar"}</td>
                <td>{p.certificado_url ? <button className="periodo" onClick={() => verDocumento(p.certificado_url)}>Ver</button> : "—"}</td>
                <td><button className="periodo" onClick={() => verificar(p.id)}>Aprobar</button> <button className="periodo" onClick={() => suspender(p.id)}>Suspender</button></td></tr>
            ))}</tbody>
          </table>
        )}
      </div>
      <div className="panel">
        <h2>Reportes sin atender</h2>
        {!reportes.datos?.length ? <div className="vacio">No hay reportes abiertos.</div> : (
          <table className="tabla">
            <thead><tr><th>Reportado</th><th>Reportó</th><th>Motivo</th><th>Fecha</th><th></th></tr></thead>
            <tbody>{reportes.datos.map((r) => (
              <tr key={r.id}><td>{r.reportado?.nombre}</td><td>{r.autor?.nombre}</td><td>{enRevision(r) && <span className="etiqueta-revision">Servicio en revisión</span>}{r.motivo}</td><td>{new Date(r.creado_en).toLocaleDateString("es-CO")}</td>
                <td>
                  {[r.reportado, r.autor].filter(Boolean).map((p) => p.suspendido
                    ? <span key={p.id} className="periodo">{p.nombre} vetado </span>
                    : <button key={p.id} className="periodo" onClick={() => vetar(p)}>Vetar {p.rol === "prestador" ? "técnico" : "cliente"}</button>)}{" "}
                  {enRevision(r)
                    ? <button className="periodo" onClick={() => resolver(r)}>Cerrar revisión (cancelar servicio)</button>
                    : <button className="periodo" onClick={() => atender(r.id)}>Marcar atendido</button>}
                </td></tr>
            ))}</tbody>
          </table>
        )}
      </div>
      <div className="panel">
        <h2>Usuarios vetados</h2>
        <p className="subtitulo">Cuentas suspendidas. Al desvetarlas vuelven a tener acceso a la app.</p>
        {vetados.error ? <div className="vacio">Error: {vetados.error}</div>
          : !vetados.datos?.length ? <div className="vacio">No hay usuarios vetados.</div> : (
          <table className="tabla">
            <thead><tr><th>Nombre</th><th>Rol</th><th>Teléfono</th><th>Reportes recibidos</th><th>Último motivo</th><th></th></tr></thead>
            <tbody>{vetados.datos.map((p) => {
              const rs = reportesDe(p.id);
              return (
                <tr key={p.id}><td>{p.nombre}</td><td>{etiquetaRol(p.rol)}</td><td>{p.telefono || "—"}</td>
                  <td className="num">{rs.length}</td>
                  <td>{rs[0] ? <>{rs[0].motivo} <small style={{ color: "var(--apagado)" }}>({fecha(rs[0].creado_en)})</small></> : "Sin reportes"}</td>
                  <td><button className="periodo" onClick={() => desvetar(p)}>Desvetar</button></td></tr>
              );
            })}</tbody>
          </table>
        )}
      </div>
      <div className="panel">
        <h2>Usuarios acusados o con inconvenientes</h2>
        <p className="subtitulo">Personas que han recibido reportes (abiertos o ya atendidos), con su historial de motivos.</p>
        {historial.error ? <div className="vacio">Error: {historial.error}</div>
          : !acusados.length ? <div className="vacio">Nadie ha sido reportado.</div> : (
          <table className="tabla">
            <thead><tr><th>Nombre</th><th>Rol</th><th>Estado</th><th>Reportes</th><th>Abiertos</th><th>Último</th><th>Motivos</th><th></th></tr></thead>
            <tbody>{acusados.map((a) => (
              <tr key={a.id}><td>{a.nombre}</td><td>{etiquetaRol(a.rol)}</td>
                <td>{a.suspendido ? <span className="etiqueta-revision">Vetado</span> : "Activo"}</td>
                <td className="num">{a.total}</td><td className="num">{a.abiertos}</td><td>{fecha(a.ultimo)}</td>
                <td><details><summary>Ver {a.total === 1 ? "motivo" : `${a.total} motivos`}</summary>
                  <ul style={{ margin: "6px 0 0", paddingLeft: 18 }}>{a.reportes.map((r) => (
                    <li key={r.id}>{r.motivo} <small style={{ color: "var(--apagado)" }}>— {r.autor?.nombre || "?"}, {fecha(r.creado_en)}{r.atendido ? " · atendido" : " · abierto"}{r.solicitud?.en_revision ? " · servicio en revisión" : ""}</small></li>
                  ))}</ul></details></td>
                <td>{a.suspendido
                  ? <button className="periodo" onClick={() => desvetar(a)}>Desvetar</button>
                  : <button className="periodo" onClick={() => vetar(a)}>Vetar {a.rol === "prestador" ? "técnico" : "cliente"}</button>}</td></tr>
            ))}</tbody>
          </table>
        )}
      </div>
    </>
  );
}
