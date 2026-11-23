import { useState } from "react";
import { LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer, PieChart, Pie, Cell } from "recharts";
import { estadisticas } from "../lib/api";
import { useDatos } from "../components/useDatos";
import Periodo from "../components/Periodo";
import Kpi from "../components/Kpi";
import { num, pct } from "../lib/format";

export default function Resumen() {
  const [dias, setDias] = useState(30);
  const { datos, error, cargando } = useDatos(() => estadisticas.resumen(dias), [dias]);
  const r = datos?.resumen || {};
  const e = datos?.embudo;
  const embudo = e ? [
    { etapa: "Sin postulaciones", n: e.publicadas - e.con_postulaciones, color: "#c9d3cf" },
    { etapa: "Con oferta, sin asignar", n: e.con_postulaciones - e.asignadas, color: "#f28b54" },
    { etapa: "Asignadas sin finalizar", n: e.asignadas - e.finalizadas, color: "#5f9e9b" },
    { etapa: "Finalizadas", n: e.finalizadas, color: "#0e5c5a" },
  ] : [];
  const total = e?.publicadas || 0;

  return (
    <>
      <div className="cabecera">
        <div><h1>Resumen de operación</h1><p>Qué está pasando con las solicitudes en Cartagena</p></div>
        <Periodo dias={dias} onChange={setDias} />
      </div>
      {error && <div className="error">{error}</div>}
      <div className="kpis">
        <Kpi valor={num(r.publicadas)} nombre="Solicitudes publicadas" />
        <Kpi valor={pct(r.tasa_contratacion)} nombre="Tasa de contratación" destacado />
        <Kpi valor={num(r.mediana_min_primera, 1)} nombre="Minutos hasta la primera postulación (mediana)" />
        <Kpi valor={num(r.postulaciones_prom, 2)} nombre="Postulaciones por solicitud" />
      </div>
      <div className="fila">
        <div className="panel">
          <h2>Solicitudes por día</h2>
          {cargando ? <div className="vacio">Cargando…</div> : (
            <ResponsiveContainer width="100%" height={260}>
              <LineChart data={datos?.serie || []}>
                <XAxis dataKey="dia" tickFormatter={(d) => d.slice(5)} fontSize={12} />
                <YAxis fontSize={12} allowDecimals={false} />
                <Tooltip />
                <Line type="monotone" dataKey="publicadas" stroke="#0e5c5a" strokeWidth={2} dot={false} name="Publicadas" />
                <Line type="monotone" dataKey="finalizadas" stroke="#e8662f" strokeWidth={2} dot={false} name="Finalizadas" />
              </LineChart>
            </ResponsiveContainer>
          )}
        </div>
        <div className="panel">
          <h2>Embudo de conversión</h2>
          {!total ? <div className="vacio">{cargando ? "Cargando…" : "Sin solicitudes en el periodo."}</div> : (
            <div className="donut">
              <div className="donut-grafica">
                <ResponsiveContainer width="100%" height={240}>
                  <PieChart>
                    <Pie data={embudo} dataKey="n" nameKey="etapa" innerRadius="62%" outerRadius="92%" startAngle={90} endAngle={-270}
                         paddingAngle={1} stroke="none" isAnimationActive={false}>
                      {embudo.map((t) => <Cell key={t.etapa} fill={t.color} />)}
                    </Pie>
                    <Tooltip formatter={(v) => [`${num(v)} (${num(100 * v / total, 1)} %)`, "Solicitudes"]} />
                  </PieChart>
                </ResponsiveContainer>
                <div className="donut-centro"><b>{num(total)}</b><span>publicadas</span></div>
              </div>
              <ul className="leyenda">
                {embudo.map((t) => (
                  <li key={t.etapa}><i style={{ background: t.color }} />{t.etapa}
                    <b>{num(t.n)}</b><span>{num(100 * t.n / total, 1)} %</span></li>
                ))}
              </ul>
            </div>
          )}
        </div>
      </div>
      <div className="kpis">
        <Kpi valor={num(r.precio_relativo_prom, 2)} nombre="Precio acordado / presupuesto" />
        <Kpi valor={r.prob_media != null ? num(r.prob_media * 100, 0) + " %" : "—"} nombre="Probabilidad media de contratación (modelo)" />
      </div>
    </>
  );
}
