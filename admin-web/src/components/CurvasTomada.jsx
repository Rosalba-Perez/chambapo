import { LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer, ReferenceLine, CartesianGrid } from "recharts";
import { num, nombreCategoria } from "../lib/format";

const AZUL = "#1f5fae", NARANJA = "#e8662f", GRIS = "#9aa6a1";
const ALTO = 360, MARGEN = { top: 14, right: 128, bottom: 4, left: 0 }, ALTO_EJE_X = 30;
const PX_POR_PUNTO = (ALTO - MARGEN.top - MARGEN.bottom - ALTO_EJE_X) / 100;
const SEPARACION_MIN = 13 / PX_POR_PUNTO;
const MIN_PARA_DESTACAR = 5;
const CORTE_H = 2;

// Acomoda los nombres al final de las líneas para que no se encimen
function posicionesEtiquetas(series) {
  const orden = [...series].sort((a, b) => b.final - a.final);
  const pos = {};
  let anterior = Infinity;
  for (const s of orden) {
    const y = Math.min(s.final, anterior - SEPARACION_MIN);
    pos[s.clave] = y;
    anterior = y;
  }
  return pos;
}

export default function CurvasTomada({ datos }) {
  const series = (datos || []).map((d) => ({ clave: d.categoria, final: d.curva[d.curva.length - 1], ...d }));
  const elegibles = series.filter((s) => s.total >= MIN_PARA_DESTACAR);
  const mejor = elegibles[0]?.clave;
  const peor = elegibles.length > 1 ? elegibles[elegibles.length - 1].clave : null;
  const horas = series[0]?.horas || [];
  const ultimo = horas.length - 1;
  const filas = horas.map((h, i) => Object.fromEntries([["h", h], ...series.map((s) => [s.clave, s.curva[i]])]));
  const etiquetas = posicionesEtiquetas(series);

  let grises = 0;
  const estilo = (s) => {
    if (s.clave === mejor) return { color: AZUL, ancho: 3.5, guiones: undefined };
    if (s.clave === peor) return { color: NARANJA, ancho: 3.5, guiones: undefined };
    grises += 1;
    return { color: GRIS, ancho: 1.6, guiones: grises % 2 === 0 ? "5 4" : undefined };
  };
  const dibujo = [...series.filter((s) => s.clave !== mejor && s.clave !== peor), ...series.filter((s) => s.clave === peor || s.clave === mejor)]
    .map((s) => ({ s, ...estilo(s) }));

  return (
    <ResponsiveContainer width="100%" height={ALTO}>
      <LineChart data={filas} margin={MARGEN}>
        <CartesianGrid stroke="var(--linea)" strokeDasharray="2 4" vertical={false} />
        <XAxis dataKey="h" type="number" domain={[0, horas[ultimo] ?? 12]} ticks={[0, 2, 4, 6, 8, 10, 12]} height={ALTO_EJE_X}
               tickFormatter={(h) => `${h} h`} fontSize={12} />
        <YAxis domain={[0, 100]} ticks={[0, 25, 50, 75, 100]} tickFormatter={(v) => `${v} %`} fontSize={12} width={48} />
        <ReferenceLine x={CORTE_H} stroke="var(--apagado)" strokeDasharray="4 4"
                       label={{ value: `${CORTE_H} h`, position: "top", fontSize: 11, fill: "var(--apagado)" }} />
        <Tooltip labelFormatter={(h) => `${h < 1 ? `${Math.round(h * 60)} min` : `${num(h, 2)} h`} desde la publicación`} itemSorter={(i) => -i.value}
                 formatter={(v, k) => [`${num(v, 1)} %`, nombreCategoria(k)]} />
        {dibujo.map(({ s, color, ancho, guiones }) => (
          <Line key={s.clave} dataKey={s.clave} type="monotone" stroke={color} strokeWidth={ancho} strokeDasharray={guiones}
                isAnimationActive={false} activeDot={{ r: 4 }}
                dot={(p) => p.payload.h === CORTE_H
                  ? <circle key={`${s.clave}-corte`} cx={p.cx} cy={p.cy} r={4} fill={color} stroke="var(--superficie)" strokeWidth={1.5} />
                  : <g key={`${s.clave}-${p.index}`} />}
                label={(p) => p.index !== ultimo ? <g key={`${s.clave}-l${p.index}`} /> : (
                  <text key={`${s.clave}-l`} x={p.x + 8} y={p.y + (s.final - etiquetas[s.clave]) * PX_POR_PUNTO + 4}
                        fontSize={11} fontWeight={color === GRIS ? 500 : 700} fill={color === GRIS ? "var(--tinta-suave)" : color}>
                    {nombreCategoria(s.clave)} · {num(s.final)} %
                  </text>
                )} />
        ))}
      </LineChart>
    </ResponsiveContainer>
  );
}
