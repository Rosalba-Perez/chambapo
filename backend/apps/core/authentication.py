"""Sirve para comprobar que el usuario inició sesión."""
import jwt
from jwt import PyJWKClient
from django.conf import settings
from django.db import connection
from rest_framework import authentication, exceptions

_jwks_client = None


def _jwks():
    global _jwks_client
    if _jwks_client is None:
        _jwks_client = PyJWKClient(f"{settings.SUPABASE_URL}/auth/v1/.well-known/jwks.json",
                                   cache_keys=True, lifespan=3600)
    return _jwks_client


def decode_supabase_token(token: str) -> dict:
    alg = jwt.get_unverified_header(token).get("alg", "")
    if alg == "HS256":
        if not settings.SUPABASE_JWT_SECRET:
            raise jwt.PyJWTError("Token HS256 pero SUPABASE_JWT_SECRET no está configurado")
        return jwt.decode(token, settings.SUPABASE_JWT_SECRET, algorithms=["HS256"], audience="authenticated", leeway=60)
    key = _jwks().get_signing_key_from_jwt(token).key
    return jwt.decode(token, key, algorithms=["ES256", "RS256"], audience="authenticated", leeway=60)

class SupabaseUser:
    is_authenticated = True

    def __init__(self, uid: str, rol: str):
        self.id = uid
        self.rol = rol

    def __str__(self):
        return f"{self.rol}:{self.id}"


class SupabaseJWTAuthentication(authentication.BaseAuthentication):
    def authenticate(self, request):
        header = request.headers.get("Authorization", "")
        if not header.startswith("Bearer "):
            return None
        token = header.split(" ", 1)[1]
        try:
            payload = decode_supabase_token(token)
        except jwt.PyJWTError as e:
            raise exceptions.AuthenticationFailed(f"Token inválido: {e}")
        uid = payload["sub"]
        with connection.cursor() as cur:
            cur.execute("select rol, suspendido from perfiles where id = %s", [uid])
            row = cur.fetchone()
        if row is None:
            raise exceptions.AuthenticationFailed("El usuario no tiene perfil")
        if row[1]:
            raise exceptions.AuthenticationFailed("Cuenta suspendida")
        return SupabaseUser(uid, row[0]), token
