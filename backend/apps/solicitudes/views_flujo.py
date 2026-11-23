"""Pasos del servicio: llegada del técnico, código de inicio y confirmación de fin."""
import secrets

from django.db import transaction
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.core import db
from apps.core.permissions import EsCliente, EsPrestador
from apps.notificaciones.fcm import enviar_a_usuario
from .serializers import CodigoSerializer, RespuestaSerializer

MAX_RECHAZOS = 2
MAX_INTENTOS_CODIGO = 5
BORRAR_CODIGO = "delete from codigos_inicio where solicitud_id = %s"
EN_REVISION = "Este servicio está en revisión. Un administrador revisará lo ocurrido y lo cerrará"
MARCAR_INCONVENIENTE = "update solicitudes set con_inconvenientes = true where id = %s"


def _solicitud(solicitud_id):
    return db.fetchone("""
        select s.id, s.cliente_id, s.prestador_id, s.estado, s.precio_acordado, s.llegada_reportada_en,
               s.llegada_confirmada_en, s.fin_reportado_en, s.rechazos_llegada, s.rechazos_fin, s.en_revision,
               c.nombre as cliente_nombre, p.nombre as prestador_nombre
        from solicitudes s join perfiles c on c.id = s.cliente_id left join perfiles p on p.id = s.prestador_id
        where s.id = %s for update of s""", [solicitud_id])


def _evento(solicitud_id, actor_id, tipo, detalle=None):
    db.execute("insert into eventos_servicio (solicitud_id, actor_id, tipo, detalle) values (%s, %s, %s, %s)",
               [solicitud_id, actor_id, tipo, detalle])


def _avisar(destino, titulo, cuerpo, solicitud_id):
    try:
        enviar_a_usuario(destino, titulo, cuerpo, {"tipo": "servicio", "id": str(solicitud_id)})
    except Exception:
        pass


def _pesos(valor):
    return f"${int(valor):,}".replace(",", ".") if valor is not None else "lo acordado"


def _no_permitido(mensaje):
    return Response({"detail": mensaje}, status=status.HTTP_409_CONFLICT)


def _a_revision(sol, uid, paso):
    """Pasa el servicio a revisión del administrador."""
    db.execute("update solicitudes set en_revision = true, con_inconvenientes = true where id = %s", [sol["id"]])
    db.execute(BORRAR_CODIGO, [sol["id"]])
    motivo = (f"Revisión automática: el cliente rechazó {MAX_RECHAZOS + 1} veces "
              f"{'la llegada del técnico' if paso == 'llegada' else 'que el trabajo estuviera terminado'}. "
              f"Cliente: {sol['cliente_nombre']}. Técnico: {sol['prestador_nombre']}.")
    db.execute("""insert into reportes (solicitud_id, autor_id, reportado_id, motivo)
                  values (%s, %s, %s, %s)""", [sol["id"], sol["cliente_id"], sol["prestador_id"], motivo])
    _evento(sol["id"], uid, "revision_solicitada", paso)
    for destino in (sol["cliente_id"], sol["prestador_id"]):
        _avisar(destino, "Servicio en revisión", "Un administrador revisará lo ocurrido con este servicio.", sol["id"])


class Llegue(APIView):
    """El técnico avisa que llegó al lugar del servicio."""
    permission_classes = [EsPrestador]

    @transaction.atomic
    def post(self, request, solicitud_id):
        sol = _solicitud(solicitud_id)
        if not sol or str(sol["prestador_id"]) != str(request.user.id):
            return Response(status=404)
        if sol["en_revision"]:
            return _no_permitido(EN_REVISION)
        if sol["estado"] != "en_camino":
            return _no_permitido("Primero marca que vas en camino")
        if sol["llegada_reportada_en"]:
            return _no_permitido("Ya avisaste que llegaste. Espera la confirmación del cliente")
        db.execute("update solicitudes set llegada_reportada_en = now(), llegada_confirmada_en = null where id = %s", [sol["id"]])
        db.execute(BORRAR_CODIGO, [sol["id"]])
        _evento(sol["id"], request.user.id, "llegada_reportada")
        _avisar(sol["cliente_id"], "Tu técnico llegó",
                f"Confirma en Chambapo que {sol['prestador_nombre']} está contigo.", sol["id"])
        return Response({"ok": True})


class ConfirmarLlegada(APIView):
    """El cliente responde si el técnico llegó. Si dice que sí, recibe el código de inicio."""
    permission_classes = [EsCliente]

    @transaction.atomic
    def post(self, request, solicitud_id):
        r = RespuestaSerializer(data=request.data)
        r.is_valid(raise_exception=True)
        sol = _solicitud(solicitud_id)
        if not sol or str(sol["cliente_id"]) != str(request.user.id):
            return Response(status=404)
        if sol["en_revision"]:
            return _no_permitido(EN_REVISION)
        if sol["estado"] != "en_camino" or not sol["llegada_reportada_en"] or sol["llegada_confirmada_en"]:
            return _no_permitido("No hay una llegada pendiente de confirmar")

        if r.validated_data["si"]:
            codigo = f"{secrets.randbelow(10000):04d}"
            db.execute("""insert into codigos_inicio (solicitud_id, codigo) values (%s, %s)
                          on conflict (solicitud_id) do update set codigo = excluded.codigo, intentos = 0, creado_en = now()""",
                       [sol["id"], codigo])
            db.execute("update solicitudes set llegada_confirmada_en = now() where id = %s", [sol["id"]])
            _evento(sol["id"], request.user.id, "llegada_confirmada")
            _avisar(sol["prestador_id"], "El cliente confirmó tu llegada",
                    "Pídele el código de 4 números para empezar el trabajo.", sol["id"])
            return Response({"ok": True, "codigo": codigo})

        db.execute("update solicitudes set llegada_reportada_en = null where id = %s", [sol["id"]])
        if sol["rechazos_llegada"] >= MAX_RECHAZOS:
            _a_revision(sol, request.user.id, "llegada")
            return Response({"ok": True, "revision": True})
        db.execute("update solicitudes set rechazos_llegada = rechazos_llegada + 1 where id = %s", [sol["id"]])
        db.execute(MARCAR_INCONVENIENTE, [sol["id"]])
        _evento(sol["id"], request.user.id, "llegada_rechazada")
        _avisar(sol["prestador_id"], "El cliente indica que aún no has llegado",
                "Cuando estés en el lugar, vuelve a pulsar «Llegué».", sol["id"])
        return Response({"ok": True, "revision": False})


class CodigoInicio(APIView):
    """El cliente vuelve a consultar su código (por ejemplo, si cerró la app)."""
    permission_classes = [EsCliente]

    def get(self, request, solicitud_id):
        row = db.fetchone("""select c.codigo from codigos_inicio c join solicitudes s on s.id = c.solicitud_id
                             where s.id = %s and s.cliente_id = %s and s.estado = 'en_camino'""",
                          [solicitud_id, request.user.id])
        if not row:
            return Response({"detail": "No hay un código activo"}, status=404)
        return Response({"codigo": row["codigo"]})


class Iniciar(APIView):
    """El técnico escribe el código que le dicta el cliente para iniciar el trabajo."""
    permission_classes = [EsPrestador]

    @transaction.atomic
    def post(self, request, solicitud_id):
        c = CodigoSerializer(data=request.data)
        c.is_valid(raise_exception=True)
        sol = _solicitud(solicitud_id)
        if not sol or str(sol["prestador_id"]) != str(request.user.id):
            return Response(status=404)
        if sol["en_revision"]:
            return _no_permitido(EN_REVISION)
        if sol["estado"] != "en_camino" or not sol["llegada_confirmada_en"]:
            return _no_permitido("El cliente aún no ha confirmado tu llegada")
        guardado = db.fetchone("select codigo, intentos from codigos_inicio where solicitud_id = %s for update", [sol["id"]])
        if not guardado:
            return _no_permitido("El código ya no es válido. El cliente debe confirmar tu llegada de nuevo")

        if secrets.compare_digest(guardado["codigo"], c.validated_data["codigo"]):
            db.execute(BORRAR_CODIGO, [sol["id"]])
            db.execute("update solicitudes set estado = 'en_curso', iniciado_en = now() where id = %s", [sol["id"]])
            _evento(sol["id"], request.user.id, "trabajo_iniciado")
            _avisar(sol["cliente_id"], "Comenzó el trabajo", f"{sol['prestador_nombre']} empezó el servicio.", sol["id"])
            return Response({"ok": True})

        intentos = guardado["intentos"] + 1
        if intentos >= MAX_INTENTOS_CODIGO:
            db.execute(BORRAR_CODIGO, [sol["id"]])
            db.execute("update solicitudes set llegada_confirmada_en = null where id = %s", [sol["id"]])
            db.execute(MARCAR_INCONVENIENTE, [sol["id"]])
            _evento(sol["id"], request.user.id, "codigo_bloqueado")
            _avisar(sol["cliente_id"], "Confirma de nuevo la llegada",
                    "Se ingresó un código incorrecto varias veces. Confirma la llegada para generar uno nuevo.", sol["id"])
            return Response({"detail": "Demasiados intentos. El cliente debe confirmar tu llegada de nuevo para darte otro código"},
                            status=status.HTTP_400_BAD_REQUEST)
        db.execute("update codigos_inicio set intentos = %s where solicitud_id = %s", [intentos, sol["id"]])
        _evento(sol["id"], request.user.id, "codigo_incorrecto")
        quedan = MAX_INTENTOS_CODIGO - intentos
        return Response({"detail": f"Código incorrecto. Te {'queda' if quedan == 1 else 'quedan'} {quedan} "
                                   f"{'intento' if quedan == 1 else 'intentos'}"}, status=status.HTTP_400_BAD_REQUEST)


class Termine(APIView):
    """El técnico avisa que terminó el trabajo."""
    permission_classes = [EsPrestador]

    @transaction.atomic
    def post(self, request, solicitud_id):
        sol = _solicitud(solicitud_id)
        if not sol or str(sol["prestador_id"]) != str(request.user.id):
            return Response(status=404)
        if sol["en_revision"]:
            return _no_permitido(EN_REVISION)
        if sol["estado"] != "en_curso":
            return _no_permitido("El trabajo no está en curso")
        if sol["fin_reportado_en"]:
            return _no_permitido("Ya avisaste que terminaste. Espera la confirmación del cliente")
        db.execute("update solicitudes set fin_reportado_en = now() where id = %s", [sol["id"]])
        _evento(sol["id"], request.user.id, "fin_reportado")
        _avisar(sol["cliente_id"], "¿Terminó el trabajo?",
                f"{sol['prestador_nombre']} indica que terminó. Confírmalo en Chambapo.", sol["id"])
        return Response({"ok": True})


class ConfirmarFin(APIView):
    """El cliente confirma si el trabajo quedó terminado. Si dice que sí, el servicio se finaliza."""
    permission_classes = [EsCliente]

    @transaction.atomic
    def post(self, request, solicitud_id):
        r = RespuestaSerializer(data=request.data)
        r.is_valid(raise_exception=True)
        sol = _solicitud(solicitud_id)
        if not sol or str(sol["cliente_id"]) != str(request.user.id):
            return Response(status=404)
        if sol["en_revision"]:
            return _no_permitido(EN_REVISION)
        if sol["estado"] != "en_curso" or not sol["fin_reportado_en"]:
            return _no_permitido("No hay un fin de trabajo pendiente de confirmar")

        if r.validated_data["si"]:
            db.execute("""update solicitudes set estado = 'finalizada', contratada = true, cerrado_en = now()
                          where id = %s""", [sol["id"]])
            _evento(sol["id"], request.user.id, "fin_confirmado")
            _avisar(sol["prestador_id"], "¡Felicidades! Has terminado el trabajo",
                    f"El cliente confirmó el trabajo. Ya puedes recibir tu pago de {_pesos(sol['precio_acordado'])}.", sol["id"])
            return Response({"ok": True})

        db.execute("update solicitudes set fin_reportado_en = null where id = %s", [sol["id"]])
        if sol["rechazos_fin"] >= MAX_RECHAZOS:
            _a_revision(sol, request.user.id, "fin")
            return Response({"ok": True, "revision": True})
        db.execute("update solicitudes set rechazos_fin = rechazos_fin + 1 where id = %s", [sol["id"]])
        db.execute(MARCAR_INCONVENIENTE, [sol["id"]])
        _evento(sol["id"], request.user.id, "fin_rechazado")
        _avisar(sol["prestador_id"], "El cliente indica que el trabajo no ha terminado",
                "Habla con el cliente y, cuando termines, vuelve a pulsar «Trabajo finalizado».", sol["id"])
        return Response({"ok": True, "revision": False})
