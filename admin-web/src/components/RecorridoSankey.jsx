import { Sankey, Tooltip, ResponsiveContainer, Layer, Rectangle } from "recharts";
import { num } from "../lib/format";

const VERDE = "#0e5c5a", GRIS = "#b9c4bf", NARANJA = "#e8662f";

function Nodo({ x, y, width, height, payload, containerWidth }) {
  const alFinal = x + width + 6 > containerWidth - 140;
  return (
    <Layer>
      <Rectangle x={x} y={y} width={width} height={Math.max(height, 2)} fill={payload.color} radius={3} />
      <text x={alFinal ? x - 8 : x + width + 8} y={y + height / 2 - 2} textAnchor={alFinal ? "end" : "start"}
            fontSize={13} fontWeight={700} fill="var(--tinta)">{payload.name}</text>
      <text x={alFinal ? x - 8 : x + width + 8} y={y + height / 2 + 14} textAnchor={alFinal ? "end" : "start"}
            fontSize={12} fill="var(--apagado)">{num(payload.value)}{payload.pct != null ? ` · ${num(payload.pct)} %` : ""}</text>
    </Layer>
  );
}

function Enlace({ sourceX, targetX, sourceY, targetY, sourceControlX, targetControlX, linkWidth, payload }) {
  return (
    <path d={`M${sourceX},${sourceY} C${sourceControlX},${sourceY} ${targetControlX},${targetY} ${targetX},${targetY}`}
          fill="none" stroke={payload.target.color} strokeOpacity={0.28} strokeWidth={Math.max(linkWidth, 1)} />
  );
}

// Gráfica que muestra el camino de una solicitud hasta ser contratada
export default function RecorridoSankey({ r }) {
  if (!r?.publicadas) return <div className="vacio">Sin solicitudes en los últimos 30 días.</div>;
  const pct = (n) => (100 * n) / r.publicadas;
  const nodos = [
    { name: "Publicadas", color: VERDE },
    { name: "Vistas por un técnico", color: VERDE, pct: pct(r.vistas) },
    { name: "Sin vista", color: GRIS, activas: r.sin_vista_activas },
    { name: "Con oferta", color: VERDE, pct: pct(r.ofertas) },
    { name: "Vistas sin oferta", color: GRIS, activas: r.sin_oferta_activas },
    { name: "Contratadas", color: NARANJA, pct: pct(r.contratadas) },
    { name: "Ofertas sin contratar", color: GRIS, activas: r.sin_contratar_activas },
  ];
  const enlaces = [
    { source: 0, target: 1, value: r.vistas },
    { source: 0, target: 2, value: r.publicadas - r.vistas },
    { source: 1, target: 3, value: r.ofertas },
    { source: 1, target: 4, value: r.vistas - r.ofertas },
    { source: 3, target: 5, value: r.contratadas },
    { source: 3, target: 6, value: r.ofertas - r.contratadas },
  ].filter((l) => l.value > 0);

  return (
    <ResponsiveContainer width="100%" height={340}>
      <Sankey data={{ nodes: nodos, links: enlaces }} node={<Nodo />} link={<Enlace />} nodePadding={28} nodeWidth={12}
              margin={{ top: 16, right: 10, bottom: 16, left: 10 }} iterations={64}>
        <Tooltip formatter={(v, _n, item) => {
          const p = item?.payload?.payload;
          const activas = p?.activas ?? p?.target?.activas;
          return [`${num(v)} solicitudes${activas ? ` (${num(activas)} aún activas)` : ""}`, ""];
        }} />
      </Sankey>
    </ResponsiveContainer>
  );
}
