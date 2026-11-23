import json, jwt
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives import serialization
from rest_framework.test import APIRequestFactory
from apps.core import authentication as auth

def test_es256_via_jwks(monkeypatch):
    priv = ec.generate_private_key(ec.SECP256R1())
    pub_jwk = json.loads(jwt.algorithms.ECAlgorithm.to_jwk(priv.public_key()))
    pub_jwk.update({"kid": "k1", "alg": "ES256", "use": "sig"})
    token = jwt.encode({"sub": "u1", "aud": "authenticated"}, priv, algorithm="ES256", headers={"kid": "k1"})

    class FakeJWKS:
        def get_signing_key_from_jwt(self, t):
            class K: key = priv.public_key()
            return K()
    monkeypatch.setattr(auth, "_jwks", lambda: FakeJWKS())
    assert auth.decode_supabase_token(token)["sub"] == "u1"
