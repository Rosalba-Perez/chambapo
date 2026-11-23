"""Sirve para calcular la probabilidad de que una solicitud sea contratada."""
import json
import unicodedata
import pandas as pd
import joblib
from django.conf import settings
from apps.core import db

COLUMNAS = ["categoria", "barrio", "presupuesto", "dia_semana", "franja_horaria", "dias_anticipacion",
            "num_postulaciones_24h", "tiempo_primera_postulacion", "precio_relativo"]

SQL_FEATURES = """
  select s.id, c.nombre categoria, coalesce(s.barrio, 'desconocido') barrio, s.presupuesto,
         s.dia_semana, s.franja_horaria::text franja_horaria, s.dias_anticipacion,
         (select count(*) from postulaciones p where p.solicitud_id = s.id
            and p.creado_en <= s.creado_en + interval '24 hours') num_postulaciones_24h,
         coalesce((select extract(epoch from min(p.creado_en) - s.creado_en)/60
                   from postulaciones p where p.solicitud_id = s.id), 1440) tiempo_primera_postulacion,
         (select min(p.precio) from postulaciones p where p.solicitud_id = s.id)
            / nullif(s.presupuesto, 0) precio_relativo
  from solicitudes s join categorias c on c.id = s.categoria_id
  where s.id = any(%s)
"""


NUMERICAS = ["presupuesto", "dias_anticipacion", "num_postulaciones_24h", "tiempo_primera_postulacion", "precio_relativo"]


def _normalizar(texto) -> str:
    t = unicodedata.normalize("NFKD", str(texto or "")).encode("ascii", "ignore").decode()
    return " ".join(t.replace("_", " ").lower().split())


class Predictor:
    def __init__(self):
        self.pipeline = None
        self.info = {"version": None, "metricas": None}
        self._barrios = {}

    def cargar(self):
        modelos = sorted(settings.MODELOS_DIR.glob("modelo_v*.joblib"))
        if not modelos:
            return
        ruta = modelos[-1]
        self.pipeline = joblib.load(ruta)
        meta = ruta.with_suffix(".json")
        metricas = json.loads(meta.read_text(encoding="utf-8")) if meta.exists() else None
        self.info = {"version": ruta.stem, "metricas": metricas,
                     "datos_sinteticos": bool(metricas and "sintetic" in str(metricas.get("fuente", "")).lower())}
        self._barrios = {_normalizar(b): b for b in self._categorias_aprendidas("barrio")}

    def _categorias_aprendidas(self, columna):
        try:
            cat = self.pipeline.named_steps["prep"].named_transformers_["cat"]
            columnas = list(self.pipeline.named_steps["prep"].transformers_[0][2])
            return [str(c) for c in cat.named_steps["oh"].categories_[columnas.index(columna)]]
        except (KeyError, ValueError, AttributeError, IndexError):
            return []

    def _features(self, ids):
        filas = db.fetchall(SQL_FEATURES, [list(ids)])
        if not filas:
            return None
        X = pd.DataFrame(filas).assign(id=lambda d: d["id"].astype(str)).set_index("id")[COLUMNAS]
        X["dia_semana"] = X["dia_semana"].astype(str)
        X[NUMERICAS] = X[NUMERICAS].apply(pd.to_numeric, errors="coerce").astype(float)
        if self._barrios:
            otros = self._barrios.get("otros")
            X["barrio"] = [self._barrios.get(_normalizar(b), otros or b) for b in X["barrio"]]
        return X

    def predecir_solicitud(self, solicitud_id) -> float | None:
        if self.pipeline is None:
            self.cargar()
        if self.pipeline is None:
            return None
        X = self._features([solicitud_id])
        return None if X is None else round(float(self.pipeline.predict_proba(X)[0, 1]), 3)

    def predecir_lote(self, ids) -> dict:
        if self.pipeline is None:
            self.cargar()
        if self.pipeline is None or not ids:
            return {}
        X = self._features(ids)
        if X is None:
            return {}
        probs = self.pipeline.predict_proba(X)[:, 1]
        return {i: round(float(p), 3) for i, p in zip(X.index, probs)}


predictor = Predictor()
