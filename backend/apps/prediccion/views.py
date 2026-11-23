from rest_framework.response import Response
from rest_framework.views import APIView
from apps.core.permissions import EsAdmin
from .predictor import predictor


class Predict(APIView):
    """Devuelve la probabilidad de contratación de una solicitud."""
    permission_classes = [EsAdmin]
    def post(self, request):
        prob = predictor.predecir_solicitud(request.data.get("solicitud_id"))
        if prob is None:
            return Response({"detail": "No hay modelo cargado o la solicitud no existe"}, status=503)
        return Response({"prob_contratacion": prob})


class Info(APIView):
    permission_classes = [EsAdmin]
    def get(self, request):
        if predictor.pipeline is None:
            predictor.cargar()
        return Response(predictor.info)
