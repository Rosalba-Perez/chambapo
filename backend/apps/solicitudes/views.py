import logging

from django.conf import settings
from django.db import transaction
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.core import db, geo
from apps.core.permissions import EsCliente, EsPrestador
from apps.notificaciones.fcm import enviar_a_usuario
from apps.prediccion.predictor import predictor
from .serializers import (CrearSolicitudSerializer, PostularSerializer,
                          ElegirSerializer, CambiarEstadoSerializer)
from .services.matching import notificar_cercanos

logger = logging.getLogger(__name__)


class CrearSolicitud(APIView):
    permission_classes = [EsCliente]

    def post(self, request):
        s = CrearSolicitudSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        d = s.validated_data
        prefijo = f"{settings.SUPABASE_URL.rstrip('/')}/storage/v1/object/public/fotos/{request.user.id}/"
        if any(not f.startswith(prefijo) for f in d["fotos"]):
            return Response({"detail": "Las fotos deben subirse desde la app"}, status=status.HTTP_400_BAD_REQUEST)
        radio = db.parametro("radio_inicial_km", 2)
        row = db.fetchone("""
            insert into solicitudes (cliente_id, categoria_id, descripcion, fotos, presupuesto,
                                     fecha_deseada, ubicacion, barrio, radio_actual_km, tiene_materiales, materiales)
            values (%s, %s, %s, %s, %s, %s, st_setsrid(st_makepoint(%s, %s), 4326)::geography, %s, %s, %s, %s)
            returning id
        """, [request.user.id, d["categoria_id"], d["descripcion"], d["fotos"], d.get("presupuesto"),
              d.get("fecha_deseada"), d["lng"], d["lat"], geo.barrio_de(d["lat"], d["lng"]), radio,
              d["tiene_materiales"], d["materiales"].strip()])
        n = notificar_cercanos(str(row["id"]), radio)
        return Response({"id": row["id"], "prestadores_notificados": n}, status=status.HTTP_201_CREATED)


class Postular(APIView):
    permission_classes = [EsPrestador]

    @transaction.atomic
    def post(self, request, solicitud_id):
        s = PostularSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        sol = db.fetchone("select cliente_id, estado from solicitudes where id = %s", [solicitud_id])
        if not sol or sol["estado"] not in ("publicada", "con_postulaciones"):
            return Response({"detail": "La solicitud ya no recibe postulaciones"}, status=400)
        insertadas = db.execute("""insert into postulaciones (solicitud_id, prestador_id, precio, minutos_llegada)
                      values (%s, %s, %s, %s) on conflict do nothing""",
                   [solicitud_id, request.user.id, s.validated_data["precio"], s.validated_data["minutos_llegada"]])
        if insertadas == 0:
            return Response({"detail": "Ya te postulaste a esta solicitud"}, status=status.HTTP_409_CONFLICT)
        db.execute("update solicitudes set estado = 'con_postulaciones' where id = %s and estado = 'publicada'",
                   [solicitud_id])
        try:
            prob = predictor.predecir_solicitud(str(solicitud_id))
        except Exception:
            logger.exception("No se pudo calcular la probabilidad de contratación de %s", solicitud_id)
            prob = None
        if prob is not None:
            db.execute("update solicitudes set prob_contratacion = %s where id = %s", [prob, solicitud_id])
        enviar_a_usuario(sol["cliente_id"], "Tienes una nueva postulación",
                         "Un prestador se ofreció para tu solicitud", {"tipo": "postulacion", "id": str(solicitud_id)})
        return Response({"ok": True, "prob_contratacion": prob})


class Elegir(APIView):
    permission_classes = [EsCliente]

    @transaction.atomic
    def post(self, request, solicitud_id):
        s = ElegirSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        p = db.fetchone("""select prestador_id, precio from postulaciones
                           where id = %s and solicitud_id = %s""", [s.validated_data["postulacion_id"], solicitud_id])
        if not p:
            return Response({"detail": "Postulación no encontrada"}, status=404)
        n = db.execute("""update solicitudes set estado = 'asignada', prestador_id = %s, precio_acordado = %s, asignado_en = now()
                          where id = %s and cliente_id = %s and estado = 'con_postulaciones'""",
                       [p["prestador_id"], p["precio"], solicitud_id, request.user.id])
        if not n:
            return Response({"detail": "No se pudo asignar"}, status=400)
        enviar_a_usuario(p["prestador_id"], "Te eligieron", "El cliente aceptó tu postulación",
                         {"tipo": "asignada", "id": str(solicitud_id)})
        return Response({"ok": True})


class CambiarEstado(APIView):
    """Esta clase cambia el estado de una solicitud."""
    def post(self, request, solicitud_id):
        s = CambiarEstadoSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        nuevo = s.validated_data["estado"]
        sol = db.fetchone("select cliente_id, prestador_id, estado, en_revision from solicitudes where id = %s", [solicitud_id])
        if not sol:
            return Response(status=404)
        if sol["en_revision"]:
            return Response({"detail": "Este servicio está en revisión. Un administrador lo cerrará"}, status=409)
        uid = str(request.user.id)
        cliente_id, prestador_id = str(sol["cliente_id"]), str(sol["prestador_id"])
        permitido = {
            "en_camino": prestador_id == uid and sol["estado"] == "asignada",
            "cancelada": uid in (cliente_id, prestador_id) and sol["estado"] not in ("finalizada", "cancelada"),
        }[nuevo]
        if not permitido:
            return Response({"detail": "Transición no permitida"}, status=400)
        cierre = nuevo in ("finalizada", "cancelada")
        motivo = (s.validated_data.get("motivo") or "").strip() or None
        db.execute("""update solicitudes set estado = %s,
                      contratada = case when %s then %s else contratada end,
                      cerrado_en = case when %s then now() else cerrado_en end,
                      motivo_cancelacion = case when %s then %s else motivo_cancelacion end,
                      cancelada_por = case when %s then %s::uuid else cancelada_por end
                      where id = %s""", [nuevo, cierre, nuevo == "finalizada", cierre,
                                         nuevo == "cancelada", motivo, nuevo == "cancelada", uid, solicitud_id])
        destino = sol["cliente_id"] if uid == prestador_id else sol["prestador_id"]
        if destino:
            if nuevo == "cancelada":
                quien = "El técnico" if uid == prestador_id else "El cliente"
                titulo, cuerpo = "Servicio cancelado", f"{quien} canceló el servicio" + (f": {motivo}" if motivo else ".")
            else:
                titulo, cuerpo = "Tu técnico va en camino", "Puedes seguir su llegada en el mapa."
            try:
                enviar_a_usuario(destino, titulo, cuerpo, {"tipo": "estado", "id": str(solicitud_id), "estado": nuevo})
            except Exception:
                logger.exception("No se pudo enviar la notificación de cambio de estado")
        return Response({"ok": True})
