import os
from pathlib import Path
import dj_database_url
from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent.parent
# Carga las variables del archivo .env
load_dotenv(BASE_DIR.parent / ".env")
SECRET_KEY = os.environ["DJANGO_SECRET_KEY"]
DEBUG = os.environ.get("DJANGO_DEBUG") == "1"
ALLOWED_HOSTS = os.environ.get("DJANGO_ALLOWED_HOSTS", "localhost").split(",")

INSTALLED_APPS = [
    "django.contrib.contenttypes",
    "django.contrib.staticfiles",
    "rest_framework",
    "corsheaders",
    "drf_spectacular",
    "apps.core",
    "apps.solicitudes",
    "apps.notificaciones",
    "apps.estadisticas",
    "apps.prediccion",
]
MIDDLEWARE = [
    "corsheaders.middleware.CorsMiddleware",
    "django.middleware.security.SecurityMiddleware",
    "django.middleware.common.CommonMiddleware",
]
ROOT_URLCONF = "config.urls"
WSGI_APPLICATION = "config.wsgi.application"
TEMPLATES = [{
    "BACKEND": "django.template.backends.django.DjangoTemplates",
    "APP_DIRS": True,
    "OPTIONS": {},
}]
STATIC_URL = "static/"

# Conexión a la base de datos
DATABASES = {"default": dj_database_url.parse(os.environ["DATABASE_URL"], conn_max_age=60)}

REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": ["apps.core.authentication.SupabaseJWTAuthentication"],
    "DEFAULT_PERMISSION_CLASSES": ["rest_framework.permissions.IsAuthenticated"],
    "UNAUTHENTICATED_USER": None,
    "DEFAULT_SCHEMA_CLASS": "drf_spectacular.openapi.AutoSchema",
}
SPECTACULAR_SETTINGS = {"TITLE": "Chambapo API", "VERSION": "1.0.0"}
CORS_ALLOWED_ORIGINS = [o for o in os.environ.get("CORS_ALLOWED_ORIGINS", "http://localhost:5173").split(",") if o]
CORS_ALLOW_ALL_ORIGINS = os.environ.get("CORS_ALLOW_ALL", "0") == "1"

SUPABASE_URL = os.environ["SUPABASE_URL"]
SUPABASE_JWT_SECRET = os.environ.get("SUPABASE_JWT_SECRET", "")
FIREBASE_CREDENTIALS = os.environ.get("FIREBASE_CREDENTIALS")
NOMINATIM_USER_AGENT = os.environ.get("NOMINATIM_USER_AGENT", "chambapo")
MODELOS_DIR = BASE_DIR / "apps" / "prediccion" / "modelos"
TIME_ZONE = "America/Bogota"
USE_TZ = True
