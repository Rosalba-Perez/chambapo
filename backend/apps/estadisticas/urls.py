from django.urls import path
from . import views
urlpatterns = [
    path("resumen/", views.Resumen.as_view()),
    path("por/<str:dim>/", views.PorDimension.as_view()),
    path("mapa-calor/", views.MapaCalor.as_view()),
    path("predicciones/", views.Predicciones.as_view()),
]
