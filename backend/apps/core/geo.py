"""Sirve para saber el barrio a partir de una ubicación."""
import requests
from django.conf import settings

def barrio_de(lat: float, lng: float) -> str | None:
    try:
        r = requests.get("https://nominatim.openstreetmap.org/reverse",
                         params={"lat": lat, "lon": lng, "format": "json", "zoom": 16},
                         headers={"User-Agent": settings.NOMINATIM_USER_AGENT}, timeout=5)
        a = r.json().get("address", {})
        return a.get("neighbourhood") or a.get("suburb") or a.get("quarter")
    except Exception:
        return None
