export default function Periodo({ dias, onChange }) {
  return (
    <div className="periodo">
      {[[1, "Hoy"], [7, "7 días"], [30, "30 días"], [90, "90 días"]].map(([d, t]) => (
        <button key={d} className={dias === d ? "activo" : ""} onClick={() => onChange(d)}>{t}</button>
      ))}
    </div>
  );
}
