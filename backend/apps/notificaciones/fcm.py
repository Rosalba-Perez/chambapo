import firebase_admin
from firebase_admin import credentials, messaging
from django.conf import settings
from apps.core import db

_app = None
def _init():
    global _app
    if _app is None and settings.FIREBASE_CREDENTIALS:
        _app = firebase_admin.initialize_app(credentials.Certificate(settings.FIREBASE_CREDENTIALS))
    return _app

def enviar_a_varios(tokens: list[str], titulo: str, cuerpo: str, data: dict | None = None):
    if not _init() or not tokens:
        return
    msg = messaging.MulticastMessage(
        tokens=tokens[:500],
        notification=messaging.Notification(title=titulo, body=cuerpo),
        data={k: str(v) for k, v in (data or {}).items()},
        android=messaging.AndroidConfig(priority="high"),
        apns=messaging.APNSConfig(payload=messaging.APNSPayload(aps=messaging.Aps(sound="default"))),
    )
    messaging.send_each_for_multicast(msg)

def enviar_a_usuario(uid, titulo, cuerpo, data=None):
    row = db.fetchone("select fcm_token from perfiles where id = %s", [uid])
    if row and row["fcm_token"]:
        enviar_a_varios([row["fcm_token"]], titulo, cuerpo, {**(data or {}), "para": str(uid)})
