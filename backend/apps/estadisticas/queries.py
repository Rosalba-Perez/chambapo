"""Consultas que alimentan las estadísticas del panel."""
from apps.core import db

def resumen(desde, hasta):
    return db.fetchone("""
      select count(*) publicadas,
             count(*) filter (where estado = 'finalizada') finalizadas,
             round(100.0 * count(*) filter (where estado = 'finalizada') / nullif(count(*), 0), 1) tasa_contratacion,
             round(avg(np.n), 2) postulaciones_prom,
             round(percentile_cont(0.5) within group (order by pp.minutos)::numeric, 1) mediana_min_primera,
             round(avg(precio_acordado / nullif(presupuesto, 0))::numeric, 2) precio_relativo_prom,
             round(avg(prob_contratacion)::numeric, 3) prob_media
      from solicitudes s
      left join lateral (select count(*) n from postulaciones p where p.solicitud_id = s.id) np on true
      left join lateral (select extract(epoch from min(p.creado_en) - s.creado_en)/60 minutos
                         from postulaciones p where p.solicitud_id = s.id) pp on true
      where s.creado_en between %s and %s
    """, [desde, hasta])

def embudo(desde, hasta):
    return db.fetchone("""
      select count(*) publicadas,
             count(*) filter (where exists (select 1 from postulaciones p where p.solicitud_id = s.id)) con_postulaciones,
             count(*) filter (where prestador_id is not null) asignadas,
             count(*) filter (where estado = 'finalizada') finalizadas
      from solicitudes s where creado_en between %s and %s
    """, [desde, hasta])

def por_dimension(desde, hasta, dim):
    assert dim in ("categoria", "barrio", "dia_semana", "franja_horaria")
    expr = "c.nombre" if dim == "categoria" else f"s.{dim}::text"
    return db.fetchall(f"""
      select {expr} clave, count(*) publicadas,
             count(*) filter (where s.estado = 'finalizada') finalizadas,
             count(*) filter (where s.prestador_id is not null) tomadas,
             round(avg(s.prob_contratacion)::numeric, 3) prob_media,
             -- calibración: solo cerradas con predicción (tasa real vs probabilidad estimada sobre las mismas)
             count(*) filter (where s.contratada is not null and s.prob_contratacion is not null) cerradas,
             round(avg(s.contratada::int) filter (where s.contratada is not null and s.prob_contratacion is not null)::numeric, 3) tasa_real,
             round(avg(s.prob_contratacion) filter (where s.contratada is not null)::numeric, 3) prob_cerradas
      from solicitudes s join categorias c on c.id = s.categoria_id
      where s.creado_en between %s and %s
      group by 1 order by 2 desc
    """, [desde, hasta])

def cruce_dia_franja(desde, hasta):
    """Solicitudes por día y franja horaria, para el mapa de calor."""
    return db.fetchall("""
      select dia_semana dia, franja_horaria::text franja, count(*) n
      from solicitudes where creado_en between %s and %s and dia_semana is not null and franja_horaria is not null
      group by 1, 2
    """, [desde, hasta])

HORAS_CURVA = 12
PASOS_POR_HORA = 4

def tiempo_hasta_tomada(desde, hasta):
    filas = db.fetchall("""
      select c.nombre categoria, s.prestador_id is not null tomada,
             extract(epoch from (coalesce(s.asignado_en, p.creado_en) - s.creado_en)) / 3600 horas
      from solicitudes s join categorias c on c.id = s.categoria_id
      left join postulaciones p on p.solicitud_id = s.id and p.prestador_id = s.prestador_id
      where s.creado_en between %s and %s
    """, [desde, hasta])
    por_cat = {}
    for f in filas:
        d = por_cat.setdefault(f["categoria"], {"total": 0, "tomadas": 0, "horas": []})
        d["total"] += 1
        if f["tomada"]:
            d["tomadas"] += 1
            d["horas"].append(max(0.0, float(f["horas"] or 0)))
    pasos = [i / PASOS_POR_HORA for i in range(HORAS_CURVA * PASOS_POR_HORA + 1)]
    resultado = []
    for cat, d in por_cat.items():
        curva = [round(100 * sum(1 for x in d["horas"] if x <= h) / d["total"], 1) for h in pasos]
        resultado.append({"categoria": cat, "total": d["total"], "tomadas": d["tomadas"],
                          "tasa_final": round(100 * d["tomadas"] / d["total"], 1), "horas": pasos, "curva": curva})
    return sorted(resultado, key=lambda r: -r["tasa_final"])

def serie_diaria(desde, hasta):
    return db.fetchall("""
      select date(creado_en at time zone 'America/Bogota') dia, count(*) publicadas,
             count(*) filter (where estado = 'finalizada') finalizadas
      from solicitudes where creado_en between %s and %s group by 1 order by 1
    """, [desde, hasta])

def calor_demanda(desde, hasta):
    return db.fetchall("""
      select st_y(ubicacion::geometry) lat, st_x(ubicacion::geometry) lng
      from solicitudes where creado_en between %s and %s
    """, [desde, hasta])

def calor_oferta():
    return db.fetchall("""
      select st_y(ubicacion::geometry) lat, st_x(ubicacion::geometry) lng
      from prestadores where disponible and ubicacion is not null
    """)

def predicciones_activas():
    return db.fetchall("""
      select s.id, c.nombre categoria, s.barrio, s.presupuesto, s.prob_contratacion, s.creado_en,
             (select count(*) from postulaciones p where p.solicitud_id = s.id) postulaciones
      from solicitudes s join categorias c on c.id = s.categoria_id
      where s.estado in ('publicada', 'con_postulaciones')
      order by s.prob_contratacion nulls last
    """)

DOMINIO_DEMO = "%@prueba.chambapo.co"


def desempeno_modelo(dias=30):
    """Compara las predicciones con lo que pasó en realidad."""
    return db.fetchone("""
      select count(*) n,
             count(*) filter (where u.email like %s) n_demo,
             count(*) filter (where s.contratada) positivos,
             count(*) filter (where not s.contratada) negativos,
             round(avg(case when (s.prob_contratacion >= 0.5) = s.contratada then 1 else 0 end)::numeric, 3) exactitud,
             round(avg(s.prob_contratacion)::numeric, 3) prob_media,
             round(avg(s.contratada::int)::numeric, 3) tasa_real
      from solicitudes s
      left join auth.users u on u.id = s.cliente_id
      where s.contratada is not null and s.prob_contratacion is not null
        and s.cerrado_en > now() - make_interval(days => %s)
    """, [DOMINIO_DEMO, dias])


def recorrido(dias=30):
    return db.fetchone("""
      with base as (
        select s.prestador_id is not null contratada,
               exists (select 1 from postulaciones p where p.solicitud_id = s.id) oferta,
               exists (select 1 from vistas_solicitud v where v.solicitud_id = s.id) vista,
               s.estado in ('publicada', 'con_postulaciones') activa
        from solicitudes s where s.creado_en > now() - make_interval(days => %s))
      select count(*) publicadas,
             count(*) filter (where vista or oferta) vistas,
             count(*) filter (where oferta) ofertas,
             count(*) filter (where contratada) contratadas,
             count(*) filter (where not (vista or oferta) and activa) sin_vista_activas,
             count(*) filter (where (vista or oferta) and not oferta and activa) sin_oferta_activas,
             count(*) filter (where oferta and not contratada and activa) sin_contratar_activas
      from base
    """, [dias])
