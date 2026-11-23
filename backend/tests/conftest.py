import os
os.environ.setdefault("DJANGO_SECRET_KEY", "test")
os.environ.setdefault("DATABASE_URL", "postgresql://u:p@localhost:5432/test")
os.environ.setdefault("SUPABASE_URL", "https://test.supabase.co")
os.environ.setdefault("SUPABASE_JWT_SECRET", "secreto-de-prueba-muy-largo-para-hs256")

import pytest


class FakeDB:
    """Base de datos falsa para las pruebas."""
    def __init__(self):
        self.ejecutadas = []; self.respuestas = []
    def fetchone(self, sql, params=None):
        self.ejecutadas.append((sql, params)); return self.respuestas.pop(0) if self.respuestas else None
    def fetchall(self, sql, params=None):
        self.ejecutadas.append((sql, params)); return self.respuestas.pop(0) if self.respuestas else []
    def execute(self, sql, params=None):
        self.ejecutadas.append((sql, params)); return 1
    def parametro(self, clave, default):
        return default


@pytest.fixture
def fake_db(monkeypatch):
    db = FakeDB()
    import apps.core.db as real
    for attr in ("fetchone", "fetchall", "execute", "parametro"):
        monkeypatch.setattr(real, attr, getattr(db, attr))
    from django.db import transaction
    monkeypatch.setattr(transaction.Atomic, "__enter__", lambda self: None)
    monkeypatch.setattr(transaction.Atomic, "__exit__", lambda self, *a: None)
    return db


@pytest.fixture
def token(monkeypatch):
    """Crea un token de prueba."""
    import jwt
    from django.conf import settings
    secreto = "secreto-de-prueba-muy-largo-para-hs256"
    monkeypatch.setattr(settings, "SUPABASE_JWT_SECRET", secreto)
    def _make(uid="11111111-1111-1111-1111-111111111111"):
        return jwt.encode({"sub": uid, "aud": "authenticated", "role": "authenticated"}, secreto, algorithm="HS256")
    return _make
