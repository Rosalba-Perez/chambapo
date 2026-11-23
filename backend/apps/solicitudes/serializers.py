from rest_framework import serializers

class CrearSolicitudSerializer(serializers.Serializer):
    categoria_id = serializers.IntegerField()
    descripcion = serializers.CharField(min_length=10, max_length=1000)
    fotos = serializers.ListField(child=serializers.URLField(), min_length=1, max_length=4,
                                  error_messages={"min_length": "Agrega al menos una foto del problema",
                                                  "max_length": "Puedes agregar hasta 4 fotos"})
    tiene_materiales = serializers.BooleanField()
    materiales = serializers.CharField(min_length=2, max_length=500)
    presupuesto = serializers.IntegerField(min_value=0, required=False, allow_null=True)
    fecha_deseada = serializers.DateTimeField(required=False, allow_null=True)
    lat = serializers.FloatField(min_value=-90, max_value=90)
    lng = serializers.FloatField(min_value=-180, max_value=180)

class PostularSerializer(serializers.Serializer):
    precio = serializers.IntegerField(min_value=0)
    minutos_llegada = serializers.IntegerField(min_value=1, max_value=600)

class ElegirSerializer(serializers.Serializer):
    postulacion_id = serializers.UUIDField()

class CambiarEstadoSerializer(serializers.Serializer):
    estado = serializers.ChoiceField(choices=["en_camino", "cancelada"])
    motivo = serializers.CharField(required=False, allow_blank=True, max_length=300)

class RespuestaSerializer(serializers.Serializer):
    """Respuesta del cliente a «¿llegó el técnico?» / «¿terminó el trabajo?»."""
    si = serializers.BooleanField()

class CodigoSerializer(serializers.Serializer):
    codigo = serializers.RegexField(r"^\d{4}$", error_messages={"invalid": "El código tiene 4 números"})
