export const num = (v, d = 0) => (v == null ? "—" : Number(v).toLocaleString("es-CO", { maximumFractionDigits: d }));
export const pct = (v) => (v == null ? "—" : `${Number(v).toLocaleString("es-CO", { maximumFractionDigits: 1 })} %`);
export const cop = (v) => (v == null ? "—" : `$ ${Number(v).toLocaleString("es-CO")}`);
export const fecha = (iso) => new Date(iso).toLocaleString("es-CO", { day: "2-digit", month: "short", hour: "2-digit", minute: "2-digit" });
export const DIAS = ["Lun", "Mar", "Mié", "Jue", "Vie", "Sáb", "Dom"];
export const FRANJAS = { madrugada: "Madrugada", manana: "Mañana", tarde: "Tarde", noche: "Noche" };
export const CATEGORIAS = {
  plomeria: "Plomería", electricidad: "Electricidad", aire_acondicionado: "Aire acondicionado",
  electrodomesticos: "Electrodomésticos", pintura: "Pintura", cerrajeria: "Cerrajería",
  carpinteria: "Carpintería", albanileria: "Albañilería", otros: "Otros arreglos",
};
export const nombreCategoria = (c) => CATEGORIAS[c] ?? c;
