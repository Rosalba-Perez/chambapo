from datetime import datetime, timedelta, timezone
from rest_framework.response import Response
from rest_framework.views import APIView
from apps.core.permissions import EsAdmin
from . import queries as q


def _rango(request):
    dias = int(request.query_params.get("dias", 30))
    hasta = datetime.now(timezone.utc)
    return hasta - timedelta(days=dias), hasta


class Resumen(APIView):
    permission_classes = [EsAdmin]
    def get(self, request):
        d, h = _rango(request)
        return Response({"resumen": q.resumen(d, h), "embudo": q.embudo(d, h), "serie": q.serie_diaria(d, h)})


class PorDimension(APIView):
    permission_classes = [EsAdmin]
    def get(self, request, dim):
        d, h = _rango(request)
        if dim == "tiempo_tomada":
            return Response(q.tiempo_hasta_tomada(d, h))
        if dim == "dia_franja":
            return Response(q.cruce_dia_franja(d, h))
        if dim not in ("categoria", "barrio", "dia_semana", "franja_horaria"):
            return Response({"detail": "Dimensión no válida"}, status=400)
        return Response(q.por_dimension(d, h, dim))


class MapaCalor(APIView):
    permission_classes = [EsAdmin]
    def get(self, request):
        d, h = _rango(request)
        return Response({"demanda": q.calor_demanda(d, h), "oferta": q.calor_oferta()})


class Predicciones(APIView):
    permission_classes = [EsAdmin]
    def get(self, request):
        return Response({"activas": q.predicciones_activas(), "desempeno": q.desempeno_modelo(),
                         "recorrido": q.recorrido()})
