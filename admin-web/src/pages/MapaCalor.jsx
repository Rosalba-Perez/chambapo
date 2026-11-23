import { useEffect, useState } from "react";
import { MapContainer, TileLayer, useMap } from "react-leaflet";
import L from "leaflet";
import "leaflet.heat";
import { estadisticas } from "../lib/api";
import { useDatos } from "../components/useDatos";
import Periodo from "../components/Periodo";

const CARTAGENA = [10.40, -75.50];

function CapaCalor({ puntos, color }) {
  const map = useMap();
  useEffect(() => {
    if (!puntos?.length) return;
    const capa = L.heatLayer(puntos.map((p) => [p.lat, p.lng, 1]), { radius: 28, blur: 22, maxZoom: 15, gradient: color }).addTo(map);
    return () => map.removeLayer(capa);
  }, [puntos, map, color]);
  return null;
}

export default function MapaCalor() {
  const [dias, setDias] = useState(30);
  const [capa, setCapa] = useState("demanda");
  const { datos, error } = useDatos(() => estadisticas.mapaCalor(dias), [dias]);
  const demanda = { 0.3: "#9fd3c7", 0.6: "#2e9c7e", 1: "#0e5c5a" };
  const oferta = { 0.3: "#fbd3b6", 0.6: "#f28b54", 1: "#c4471a" };

  return (
    <>
      <div className="cabecera">
        <div><h1>Mapas de calor</h1><p>Demanda (solicitudes) frente a oferta (prestadores activos). Donde hay verde sin naranja faltan prestadores.</p></div>
        <Periodo dias={dias} onChange={setDias} />
      </div>
      {error && <div className="error">{error}</div>}
      <div className="capas">
        {[["demanda", "Demanda"], ["oferta", "Oferta"], ["ambas", "Superponer"]].map(([k, t]) => (
          <button key={k} className={capa === k ? "activo" : ""} onClick={() => setCapa(k)}>{t}</button>
        ))}
      </div>
      <div className="panel">
        <MapContainer center={CARTAGENA} zoom={12} className="mapa">
          <TileLayer url="https://tile.openstreetmap.org/{z}/{x}/{y}.png" attribution="&copy; OpenStreetMap" />
          {(capa === "demanda" || capa === "ambas") && <CapaCalor puntos={datos?.demanda} color={demanda} />}
          {(capa === "oferta" || capa === "ambas") && <CapaCalor puntos={datos?.oferta} color={oferta} />}
        </MapContainer>
      </div>
    </>
  );
}
