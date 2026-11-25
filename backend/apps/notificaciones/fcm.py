import logging
import firebase_admin
from firebase_admin import credentials, messaging
from django.conf import settings
from apps.core import db

logger = logging.getLogger(__name__)

_app = None
def _init():
    global _app
    if _app is None and settings.FIREBASE_CREDENTIALS:
        _app = firebase_admin.initialize_app(credentials.Certificate(settings.FIREBASE_CREDENTIALS))
    return _app

# Sirve para enviar una notificación; si falla, solo se registra el error y la acción del usuario sigue
def enviar_a_varios(tokens: list[str], titulo: str, cuerpo: str, data: dict | None = None):
    if not tokens:
        return
    try:
        if not _init():
            logger.warning("Notificación no enviada: FIREBASE_CREDENTIALS no está configurado")
            return
        msg = messaging.MulticastMessage(
            tokens=tokens[:500],
            notification=messaging.Notification(title=titulo, body=cuerpo),
            data={k: str(v) for k, v in (data or {}).items()},
            android=messaging.AndroidConfig(priority="high"),
            apns=messaging.APNSConfig(payload=messaging.APNSPayload(aps=messaging.Aps(sound="default"))),
        )
        res = messaging.send_each_for_multicast(msg)
        if res.failure_count:
            errores = [str(r.exception) for r in res.responses if r.exception]
            logger.warning("Notificaciones fallidas: %s de %s (%s)", res.failure_count, len(tokens), "; ".join(errores[:3]))
    except Exception:
        logger.exception("No se pudo enviar la notificación «%s»", titulo)

def enviar_a_usuario(uid, titulo, cuerpo, data=None):
    row = db.fetchone("select fcm_token from perfiles where id = %s", [uid])
    if row and row["fcm_token"]:
        enviar_a_varios([row["fcm_token"]], titulo, cuerpo, {**(data or {}), "para": str(uid)})
