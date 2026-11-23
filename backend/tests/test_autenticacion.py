import pytest
from rest_framework.exceptions import AuthenticationFailed
from rest_framework.test import APIRequestFactory
from apps.core.authentication import SupabaseJWTAuthentication

UID = "11111111-1111-1111-1111-111111111111"

def _request(header):
    return APIRequestFactory().get("/api/x/", HTTP_AUTHORIZATION=header)

def test_sin_cabecera_devuelve_none():
    assert SupabaseJWTAuthentication().authenticate(_request("")) is None

def test_token_valido_carga_rol(fake_db, token, monkeypatch):
    class Cur:
        def __enter__(self): return self
        def __exit__(self, *a): pass
        def execute(self, sql, params): self.params = params
        def fetchone(self): return ("prestador", False)
    monkeypatch.setattr("apps.core.authentication.connection", type("C", (), {"cursor": lambda self: Cur()})())
    user, _ = SupabaseJWTAuthentication().authenticate(_request(f"Bearer {token(UID)}"))
    assert user.id == UID and user.rol == "prestador" and user.is_authenticated

def test_token_invalido_falla():
    with pytest.raises(AuthenticationFailed):
        SupabaseJWTAuthentication().authenticate(_request("Bearer no-es-un-jwt"))
