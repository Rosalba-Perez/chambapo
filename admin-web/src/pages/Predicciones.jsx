import { estadisticas } from "../lib/api";
import { useDatos } from "../components/useDatos";
import Kpi from "../components/Kpi";
import RecorridoSankey from "../components/RecorridoSankey";
import { num, cop, fecha } from "../lib/format";

function nivel(p) {
  if (p == null) return null;
  if (p >= 0.6) return "alta";
  return p >= 0.35 ? "media" : "baja";
}

function valorAciertos(suficientes, exactitud) {
  if (!suficientes) return "Datos insuficientes";
  return exactitud == null ? "—" : num(exactitud * 100) + " %";
}
function nombreModelo(m) {
  if (!m) return "Ningún modelo cargado";
  return m === "red_neuronal_mlp" ? "Red neuronal MLP" : m.replaceAll("_", " ");
}
const MINIMO_POR_CLASE = 30;

export default function Predicciones() {
  const { datos, error, cargando } = useDatos(() => estadisticas.predicciones(), []);
  const modelo = useDatos(() => estadisticas.modelo().catch(() => null), []);
  const d = datos?.desempeno || {};
  const m = modelo.datos?.metricas;
  const sintetico = modelo.datos?.datos_sinteticos;
  const positivos = d.positivos ?? 0, negativos = d.negativos ?? 0;
  const suficientes = positivos >= MINIMO_POR_CLASE && negativos >= MINIMO_POR_CLASE;
  const conDemo = (d.n_demo ?? 0) > 0;
  const subtituloAciertos = conDemo
    ? `Aciertos sobre dataset de prueba (n = ${num(d.n)} cerradas en 30 días)`
    : `Aciertos sobre solicitudes cerradas (n = ${num(d.n)} en 30 días)`;
  const sufijoDemo = conDemo ? " · dataset de prueba" : "";

  return (
    <>
      <div className="cabecera">
        <div><h1>Predicción de contratación</h1><p>Probabilidad de que cada solicitud activa termine contratada, calculada con lo que se sabe en sus primeras 24 horas</p></div>
      </div>
      {error && <div className="error">{error}</div>}

      <div className="kpis">
        <Kpi valor={modelo.datos?.version ? "Modelo predictivo" : "Sin modelo"}
             nombre={nombreModelo(m?.modelo)} />
        <Kpi valor={m?.auc_roc != null ? num(m.auc_roc, 3) : "—"}
             nombre={sintetico ? "AUC-ROC con datos sintéticos" : "AUC-ROC en la prueba del entrenamiento"} />
        <Kpi valor={valorAciertos(suficientes, d.exactitud)}
             pequeno={!suficientes}
             nombre={suficientes ? subtituloAciertos
               : `Aciertos: se necesitan ${MINIMO_POR_CLASE} contratadas y ${MINIMO_POR_CLASE} no contratadas cerradas (hoy ${positivos} y ${negativos})`}
             destacado />
        <Kpi valor={suficientes && d.prob_media != null ? `${num(d.prob_media * 100)} % / ${num(d.tasa_real * 100)} %` : "—"}
             nombre={suficientes ? `Prob. media predicha / tasa real${sufijoDemo}` : "Calibración: disponible con datos suficientes"} />
      </div>

      <div className="panel">
        <h2>Solicitudes activas, de menor a mayor probabilidad</h2>
        {cargando ? <div className="vacio">Cargando…</div> : !datos?.activas?.length ? <div className="vacio">No hay solicitudes activas en este momento.</div> : (
          <table className="tabla">
            <thead><tr><th>Riesgo</th><th>Categoría</th><th>Barrio</th><th style={{ textAlign: "right" }}>Presupuesto</th><th style={{ textAlign: "right" }}>Postulaciones</th><th>Publicada</th><th style={{ textAlign: "right" }}>P(contratada)</th></tr></thead>
            <tbody>
              {datos.activas.map((s) => (
                <tr key={s.id}>
                  <td><span className={`semaforo ${nivel(s.prob_contratacion) || ""}`} />{nivel(s.prob_contratacion) ?? "sin dato"}</td>
                  <td>{s.categoria}</td><td>{s.barrio || "—"}</td>
                  <td className="num">{cop(s.presupuesto)}</td><td className="num">{s.postulaciones}</td>
                  <td>{fecha(s.creado_en)}</td>
                  <td className="num">{s.prob_contratacion != null ? num(s.prob_contratacion * 100) + " %" : "—"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
        <p className="nota">Riesgo: <span className="semaforo alta" />alta ≥ 60 % · <span className="semaforo media" />media 35–60 % · <span className="semaforo baja" />baja &lt; 35 %. Se recalcula con cada oferta nueva y cada hora.</p>
      </div>

      <div className="panel">
        <h2>Recorrido de las solicitudes</h2>
        <p className="subtitulo">Publicada → vista por un técnico → recibe oferta → contratada, en los últimos 30 días</p>
        {cargando ? <div className="vacio">Cargando…</div> : <RecorridoSankey r={datos?.recorrido} />}
        <p className="nota">Una solicitud con oferta cuenta como vista aunque sea anterior al registro de vistas.
          «Contratadas» = el cliente eligió un técnico. Pasa el cursor por un tramo para ver cuántas siguen activas.</p>
      </div>
    </>
  );
}
