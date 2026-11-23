from django.urls import path
from . import views, views_flujo

urlpatterns = [
    path("", views.CrearSolicitud.as_view()),
    path("<uuid:solicitud_id>/postular/", views.Postular.as_view()),
    path("<uuid:solicitud_id>/elegir/", views.Elegir.as_view()),
    path("<uuid:solicitud_id>/estado/", views.CambiarEstado.as_view()),
    path("<uuid:solicitud_id>/llegue/", views_flujo.Llegue.as_view()),
    path("<uuid:solicitud_id>/confirmar-llegada/", views_flujo.ConfirmarLlegada.as_view()),
    path("<uuid:solicitud_id>/codigo/", views_flujo.CodigoInicio.as_view()),
    path("<uuid:solicitud_id>/iniciar/", views_flujo.Iniciar.as_view()),
    path("<uuid:solicitud_id>/termine/", views_flujo.Termine.as_view()),
    path("<uuid:solicitud_id>/confirmar-fin/", views_flujo.ConfirmarFin.as_view()),
]
