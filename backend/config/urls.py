from django.urls import path, include
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView

urlpatterns = [
    path("api/solicitudes/", include("apps.solicitudes.urls")),
    path("api/estadisticas/", include("apps.estadisticas.urls")),
    path("api/ml/", include("apps.prediccion.urls")),
    path("api/schema/", SpectacularAPIView.as_view(), name="schema"),
    path("api/docs/", SpectacularSwaggerView.as_view(url_name="schema")),
]
