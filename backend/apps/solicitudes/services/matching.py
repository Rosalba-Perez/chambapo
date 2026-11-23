"""Sirve para buscar técnicos cercanos a una solicitud."""
from apps.core import db
from apps.notificaciones.fcm import enviar_a_varios


def notificar_cercanos(solicitud_id: str, radio_km: float) -> int:
    cercanos = db.fetchall("select * from prestadores_cercanos(%s, %s)", [solicitud_id, radio_km])
    tokens = [c["fcm_token"] for c in cercanos if c["fcm_token"]]
    if tokens:
        sol = db.fetchone("select c.nombre categoria, s.barrio from solicitudes s "
                          "join categorias c on c.id = s.categoria_id where s.id = %s", [solicitud_id])
        enviar_a_varios(tokens, "Nueva solicitud cerca de ti",
                        f"{sol['categoria']} en {sol['barrio'] or 'tu zona'}",
                        {"tipo": "solicitud", "id": solicitud_id})
    return len(cercanos)


def ampliar_radio_pendientes() -> int:
    """Amplía la zona de búsqueda de las solicitudes que siguen sin ofertas."""
    inc = db.parametro("radio_incremento_km", 2)
    maximo = db.parametro("radio_maximo_km", 10)
    espera = db.parametro("tiempo_espera_min", 10)
    pendientes = db.fetchall("""
        select id, radio_actual_km from solicitudes
        where estado = 'publicada'
          and radio_actual_km < %s
          and now() - creado_en > make_interval(mins => %s::int) * ceil(radio_actual_km / %s)
          and not exists (select 1 from postulaciones p where p.solicitud_id = solicitudes.id)
    """, [maximo, espera, inc])
    for s in pendientes:
        nuevo = min(float(s["radio_actual_km"]) + inc, maximo)
        db.execute("update solicitudes set radio_actual_km = %s where id = %s", [nuevo, s["id"]])
        notificar_cercanos(s["id"], nuevo)
    return len(pendientes)
