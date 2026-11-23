import { supabase } from "./supabase";
import { API_URL as BASE } from "./config";

async function token() {
  const { data } = await supabase.auth.getSession();
  return data.session?.access_token;
}

export async function api(path, opts = {}) {
  const res = await fetch(`${BASE}${path}`, {
    ...opts,
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${await token()}`, ...(opts.headers || {}) },
  });
  if (!res.ok) throw new Error((await res.json().catch(() => ({}))).detail || `Error ${res.status}`);
  return res.json();
}

export const estadisticas = {
  resumen: (dias) => api(`/api/estadisticas/resumen/?dias=${dias}`),
  por: (dim, dias) => api(`/api/estadisticas/por/${dim}/?dias=${dias}`),
  mapaCalor: (dias) => api(`/api/estadisticas/mapa-calor/?dias=${dias}`),
  predicciones: () => api(`/api/estadisticas/predicciones/`),
  modelo: () => api(`/api/ml/info/`),
};
