import { useEffect, useState } from "react";
// Sirve para cargar datos y saber si están cargando o si hubo un error
export function useDatos(fn, deps) {
  const [estado, setEstado] = useState({ datos: null, error: null, cargando: true });
  useEffect(() => {
    let vivo = true;
    setEstado((e) => ({ ...e, cargando: true, error: null }));
    fn().then((d) => vivo && setEstado({ datos: d, error: null, cargando: false }))
        .catch((err) => vivo && setEstado({ datos: null, error: err.message, cargando: false }));
    return () => { vivo = false; };
  }, deps); // eslint-disable-line
  return estado;
}
