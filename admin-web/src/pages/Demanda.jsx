import { useState } from "react";
import { estadisticas } from "../lib/api";
import { useDatos } from "../components/useDatos";
import Periodo from "../components/Periodo";
import CurvasTomada from "../components/CurvasTomada";
import { num, DIAS, FRANJAS, nombreCategoria } from "../lib/format";

const UMBRAL_TASA_BAJA = 45;
const UMBRAL_DESVIO = 10;
const ORDEN_FRANJAS = ["manana", "tarde", "noche", "madrugada"];
const AZUL_CLARO = [234, 242, 251];
const AZUL_INTENSO = [11, 61, 145];

function Panel({ titulo, subtitulo, cargando, vacio, children }) {
  return (
    <div className="panel">
      <h2>{titulo}</h2>
      {subtitulo && <p className="subtitulo">{subtitulo}</p>}
      {cargando && <div className="vacio">Cargando…</div>}
      {!cargando && vacio && <div className="vacio">Sin solicitudes en el periodo.</div>}
      {!cargando && !vacio && children}
    </div>
  );
}

// Muestra cuántas solicitudes se toman por categoría
function EmbudoCategorias({ datos }) {
  const filas = (datos || [])
    .map((d) => ({ ...d, tasa: d.publicadas ? (100 * d.tomadas) / d.publicadas : 0 }))
    .sort((a, b) => b.tasa - a.tasa);
  const max = Math.max(1, ...filas.map((f) => f.publicadas));
  return (
    <>
      <div className="embudo-cat">
        {filas.map((f) => (
          <div className="fila-cat" key={f.clave} title={`${num(f.tomadas)} tomadas de ${num(f.publicadas)} publicadas`}>
            <span className="nombre">{nombreCategoria(f.clave)}</span>
            <div className="pista">
              <div className="publicadas" style={{ width: `${(100 * f.publicadas) / max}%` }}>
                <div className={`tomadas ${f.tasa < UMBRAL_TASA_BAJA ? "baja" : ""}`}
                     style={{ width: `${f.publicadas ? (100 * f.tomadas) / f.publicadas : 0}%` }} />
              </div>
            </div>
            <span className="tasa">{num(f.tasa)} %</span>
          </div>
        ))}
      </div>
      <p className="nota">
        <i className="muestra clara" />publicadas · <i className="muestra solida" />tomadas por un técnico ·{" "}
        <i className="muestra naranja" />tasa menor al {UMBRAL_TASA_BAJA} %. La parte clara a la derecha es lo que se perdió.
      </p>
    </>
  );
}

// Muestra en qué días y horas hay más solicitudes
function colorAzul(t) {
  const c = AZUL_CLARO.map((v, i) => Math.round(v + (AZUL_INTENSO[i] - v) * t));
  return `rgb(${c.join(",")})`;
}

function MapaDiaFranja({ datos }) {
  const celdas = {};
  for (const d of datos || []) celdas[`${d.dia}-${d.franja}`] = d.n;
  const valor = (dia, fr) => celdas[`${dia}-${fr}`] || 0;
  const max = Math.max(1, ...Object.values(celdas));
  const totFila = DIAS.map((_, dia) => ORDEN_FRANJAS.reduce((s, fr) => s + valor(dia, fr), 0));
  const totCol = ORDEN_FRANJAS.map((fr) => DIAS.reduce((s, _, dia) => s + valor(dia, fr), 0));
  return (
    <>
      <table className="calor-grid">
        <thead>
          <tr><th />{ORDEN_FRANJAS.map((fr) => <th key={fr}>{FRANJAS[fr]}</th>)}<th className="total">Total</th></tr>
        </thead>
        <tbody>
          {DIAS.map((nombre, dia) => (
            <tr key={nombre}>
              <th>{nombre}</th>
              {ORDEN_FRANJAS.map((fr) => {
                const n = valor(dia, fr), t = n / max;
                return (
                  <td key={fr}>
                    <div className="celda" style={{ background: colorAzul(t), color: t > 0.5 ? "#fff" : "var(--tinta)" }}
                         title={`${nombre} · ${FRANJAS[fr]}: ${num(n)} solicitudes`}>{num(n)}</div>
                  </td>
                );
              })}
              <td className="total">{num(totFila[dia])}</td>
            </tr>
          ))}
          <tr className="totales">
            <th>Total</th>
            {totCol.map((n, i) => <td key={ORDEN_FRANJAS[i]} className="total">{num(n)}</td>)}
            <td className="total">{num(totFila.reduce((a, b) => a + b, 0))}</td>
          </tr>
        </tbody>
      </table>
      <div className="escala">
        <span>Menos</span>
        <div className="degradado" style={{ background: `linear-gradient(90deg, ${colorAzul(0)}, ${colorAzul(1)})` }} />
        <span>Más</span>
      </div>
    </>
  );
}

// Compara por barrio lo que pasó con lo que se esperaba
function DumbbellBarrios({ datos }) {
  const filas = (datos || [])
    .filter((b) => b.clave && b.cerradas > 0 && b.tasa_real != null && b.prob_cerradas != null)
    .slice(0, 8)
    .map((b) => ({ ...b, real: b.tasa_real * 100, estimada: b.prob_cerradas * 100 }));
  if (!filas.length) return <div className="vacio">Aún no hay solicitudes cerradas por barrio en el periodo.</div>;

  const valores = filas.flatMap((f) => [f.real, f.estimada]);
  const min = Math.min(40, Math.floor(Math.min(...valores) / 10) * 10);
  const max = Math.max(70, Math.ceil(Math.max(...valores) / 10) * 10);
  const ticks = [];
  for (let v = min; v <= max; v += 10) ticks.push(v);

  const ANCHO = 640, IZQ = 150, DER = 80, ALTO_FILA = 46, ARRIBA = 26;
  const x = (v) => IZQ + ((v - min) / (max - min)) * (ANCHO - IZQ - DER);
  const alto = ARRIBA + filas.length * ALTO_FILA + 6;

  return (
    <>
      <svg className="dumbbell" viewBox={`0 0 ${ANCHO} ${alto}`} role="img" aria-label="Tasa real frente a probabilidad estimada por barrio">
        {ticks.map((t) => (
          <g key={t}>
            <line x1={x(t)} x2={x(t)} y1={ARRIBA - 6} y2={alto - 4} className="rejilla" />
            <text x={x(t)} y={ARRIBA - 12} className="eje" textAnchor="middle">{t} %</text>
          </g>
        ))}
        {filas.map((f, i) => {
          const y = ARRIBA + i * ALTO_FILA + ALTO_FILA / 2;
          const dif = f.estimada - f.real;
          const lejos = Math.abs(dif) >= UMBRAL_DESVIO;
          return (
            <g key={f.clave}>
              <title>{`${f.clave}: tasa real ${num(f.real)} % · estimada ${num(f.estimada)} % (${num(f.cerradas)} cerradas)`}</title>
              <text x={0} y={y - 3} className="barrio">{f.clave}</text>
              <text x={0} y={y + 13} className="publicadas">{num(f.publicadas)} publicadas</text>
              <line x1={x(f.real)} x2={x(f.estimada)} y1={y} y2={y} className={`union ${lejos ? "lejos" : ""}`} />
              <circle cx={x(f.real)} cy={y} r={7} className="punto-real" />
              <circle cx={x(f.estimada)} cy={y} r={7} className="punto-estimado" />
              <text x={ANCHO} y={y + 4} textAnchor="end" className={`dif ${lejos ? "lejos" : ""}`}>
                {dif >= 0 ? "+" : "−"}{num(Math.abs(dif))} pts
              </text>
            </g>
          );
        })}
      </svg>
      <p className="nota">
        <i className="muestra real" />tasa real de contratación · <i className="muestra estimada" />probabilidad media estimada por el modelo
        (sobre las mismas solicitudes cerradas). Diferencia = estimada − real: positiva, el modelo sobreestima;
        la línea se pinta naranja desde {UMBRAL_DESVIO} puntos.
      </p>
    </>
  );
}

export default function Demanda() {
  const [dias, setDias] = useState(30);
  const cat = useDatos(() => estadisticas.por("categoria", dias), [dias]);
  const bar = useDatos(() => estadisticas.por("barrio", dias), [dias]);
  const cruce = useDatos(() => estadisticas.por("dia_franja", dias), [dias]);
  const tiempo = useDatos(() => estadisticas.por("tiempo_tomada", dias), [dias]);
  const error = cat.error || bar.error || cruce.error || tiempo.error;

  return (
    <>
      <div className="cabecera">
        <div><h1>Demanda y conversión</h1><p>Qué se pide, dónde y cuándo; y cuánto de eso se concreta</p></div>
        <Periodo dias={dias} onChange={setDias} />
      </div>
      {error && <div className="error">{error}</div>}
      <div className="fila">
        <Panel titulo="Conversión por tipo de servicio" subtitulo="Porcentaje de solicitudes publicadas que toma un técnico, de mayor a menor."
               cargando={cat.cargando} vacio={!cat.datos?.length}>
          <EmbudoCategorias datos={cat.datos} />
        </Panel>
        <Panel titulo="Mapa de demanda semanal" subtitulo="Cuándo se publican más solicitudes: cuanto más intenso el azul, más demanda."
               cargando={cruce.cargando} vacio={!cruce.datos?.length}>
          <MapaDiaFranja datos={cruce.datos} />
        </Panel>
      </div>
      <div className="fila">
        <Panel titulo="Precisión del modelo por barrio" subtitulo="Tasa real de contratación frente a la probabilidad estimada: cuánto acierta el modelo en cada zona."
               cargando={bar.cargando} vacio={!bar.datos?.length}>
          <DumbbellBarrios datos={bar.datos} />
        </Panel>
        <Panel titulo="Velocidad de contratación por servicio" subtitulo="Porcentaje acumulado de solicitudes tomadas según las horas desde su publicación. La altura final es la tasa de conversión."
               cargando={tiempo.cargando} vacio={!tiempo.datos?.length}>
          <CurvasTomada datos={tiempo.datos} />
          <p className="nota">Azul: el servicio con mejor conversión · naranja: el peor (entre los que tienen al menos 5 solicitudes).
            Los puntos marcan el corte de 2 h. «Tomada» = el cliente eligió a un técnico.</p>
        </Panel>
      </div>
    </>
  );
}
