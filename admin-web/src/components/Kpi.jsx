export default function Kpi({ valor, nombre, destacado, pequeno }) {
  return (
    <div className={`kpi ${destacado ? "destacado" : ""}`}>
      <div className={`valor ${pequeno ? "pequeno" : ""}`}>{valor}</div>
      <div className="nombre">{nombre}</div>
    </div>
  );
}
