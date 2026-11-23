"""Pruebas de los cambios de estado de las solicitudes."""
import pytest
from rest_framework.test import APIRequestFactory, force_authenticate
from apps.core.authentication import SupabaseUser
from apps.solicitudes.serializers import CrearSolicitudSerializer
from apps.solicitudes import views

CLIENTE, PRESTADOR, OTRO = "c" * 36, "p" * 36, "o" * 36
SOL = "22222222-2222-2222-2222-222222222222"

def _post(view, data, user):
    req = APIRequestFactory().post("/", data, format="json")
    force_authenticate(req, user=user)
    return view.as_view()(req, solicitud_id=SOL)

@pytest.mark.parametrize("estado_actual,nuevo,quien,esperado", [
    ("asignada", "en_camino", "prestador", 200),
    ("en_camino", "en_curso", "prestador", 200),
    ("en_curso", "finalizada", "prestador", 200),
    ("asignada", "finalizada", "prestador", 400),
    ("asignada", "en_camino", "cliente", 400),
    ("en_curso", "cancelada", "cliente", 200),
    ("finalizada", "cancelada", "cliente", 400),
    ("asignada", "cancelada", "otro", 400),
])
def test_transiciones_de_estado(fake_db, monkeypatch, estado_actual, nuevo, quien, esperado):
    monkeypatch.setattr(views, "enviar_a_usuario", lambda *a, **k: None)
    fake_db.respuestas = [{"cliente_id": CLIENTE, "prestador_id": PRESTADOR, "estado": estado_actual}]
    uid, rol = {"cliente": (CLIENTE, "cliente"), "prestador": (PRESTADOR, "prestador"), "otro": (OTRO, "cliente")}[quien]
    r = _post(views.CambiarEstado, {"estado": nuevo}, SupabaseUser(uid, rol))
    assert r.status_code == esperado

def test_finalizar_marca_contratada(fake_db, monkeypatch):
    monkeypatch.setattr(views, "enviar_a_usuario", lambda *a, **k: None)
    fake_db.respuestas = [{"cliente_id": CLIENTE, "prestador_id": PRESTADOR, "estado": "en_curso"}]
    _post(views.CambiarEstado, {"estado": "finalizada"}, SupabaseUser(PRESTADOR, "prestador"))
    sql, params = fake_db.ejecutadas[-1]
    assert "update solicitudes" in sql and params[2] is True

def test_postular_rechaza_solicitud_cerrada(fake_db, monkeypatch):
    fake_db.respuestas = [{"cliente_id": CLIENTE, "estado": "asignada"}]
    r = _post(views.Postular, {"precio": 50000, "minutos_llegada": 20}, SupabaseUser(PRESTADOR, "prestador"))
    assert r.status_code == 400

def test_solo_prestador_puede_postular(fake_db):
    r = _post(views.Postular, {"precio": 50000, "minutos_llegada": 20}, SupabaseUser(CLIENTE, "cliente"))
    assert r.status_code == 403

def test_serializer_valida_coordenadas():
    s = CrearSolicitudSerializer(data={"categoria_id": 1, "descripcion": "Fuga", "lat": 95, "lng": -75.5})
    assert not s.is_valid() and "lat" in s.errors
    s = CrearSolicitudSerializer(data={"categoria_id": 1, "descripcion": "Fuga", "lat": 10.4, "lng": -75.5})
    assert s.is_valid()
