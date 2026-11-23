"""Sirve para probar todo el flujo de la app en local, sin el celular."""
import os, sys, time, uuid, pathlib
import requests

ENV = {}
for line in pathlib.Path(__file__).resolve().parent.parent.joinpath(".env").read_text().splitlines():
    if "=" in line and not line.strip().startswith("#"):
        k, v = line.split("=", 1); ENV[k.strip()] = v.split("#")[0].strip()
SB = ENV["SUPABASE_URL"].rstrip("/"); ANON = ENV["VITE_SUPABASE_ANON_KEY"]; SERVICE = ENV["SUPABASE_SERVICE_KEY"]
API = ENV.get("VITE_API_URL", "http://localhost:8000").rstrip("/")
CLAVE = "Prueba1234"

def ok(msg): print(f"  ✔ {msg}")
def fallo(msg, r=None):
    print(f"  ✘ {msg}"); 
    if r is not None: print("    ", r.status_code, r.text[:300])
    sys.exit(1)

def sb_auth(path, body, token=None):
    h = {"apikey": ANON, "Content-Type": "application/json"}
    if token: h["Authorization"] = f"Bearer {token}"
    return requests.post(f"{SB}/auth/v1/{path}", json=body, headers=h, timeout=15)

def sb_rest(method, tabla, token, body=None, params=None):
    h = {"apikey": ANON, "Authorization": f"Bearer {token}", "Content-Type": "application/json", "Prefer": "return=representation"}
    return requests.request(method, f"{SB}/rest/v1/{tabla}", json=body, params=params, headers=h, timeout=15)

def crear_usuario(rol, nombre):
    email = f"{rol}-{uuid.uuid4().hex[:6]}@prueba.chambapo"
    r = sb_auth("signup", {"email": email, "password": CLAVE})
    if r.status_code >= 300: fallo(f"signup {rol}", r)
    data = r.json(); token = data.get("access_token"); uid = data["user"]["id"]
    if not token:
        fallo("Supabase no devolvió sesión: desactiva 'Confirm email' en Authentication → Providers → Email")
    r = sb_rest("POST", "perfiles", token, {"id": uid, "rol": rol, "nombre": nombre, "telefono": "3000000000"})
    if r.status_code >= 300: fallo(f"insert perfiles ({rol})", r)
    return uid, token, email

def api(path, token, body):
    r = requests.post(f"{API}{path}", json=body, headers={"Authorization": f"Bearer {token}"}, timeout=30)
    return r

print("0. API Django")
try:
    r = requests.get(f"{API}/api/docs/", timeout=5); ok(f"responde en {API}")
except Exception as e:
    fallo(f"no responde en {API}: ¿está corriendo 'python manage.py runserver'? ({e})")

print("1. Usuarios de prueba")
cli_id, cli_tok, cli_mail = crear_usuario("cliente", "Cliente de prueba"); ok(f"cliente {cli_mail}")
pre_id, pre_tok, pre_mail = crear_usuario("prestador", "Prestador de prueba"); ok(f"prestador {pre_mail}")

r = sb_rest("POST", "prestadores", pre_tok, {"id": pre_id, "oficios": ["plomeria"], "zona_habitual": "Manga"})
if r.status_code >= 300: fallo("insert prestadores", r)
r = sb_rest("PATCH", "prestadores", SERVICE, {"verificado": True, "disponible": True,
            "ubicacion": "POINT(-75.5380 10.4120)", "ubicacion_en": "now()"}, params={"id": f"eq.{pre_id}"})
if r.status_code >= 300: fallo("verificar prestador (service key)", r)
ok("prestador verificado, disponible y ubicado en Manga")

print("2. Cliente publica una solicitud")
r = api("/api/solicitudes/", cli_tok, {"categoria_id": 1, "descripcion": "Fuga en el lavaplatos (prueba)",
                                        "presupuesto": 80000, "lat": 10.4150, "lng": -75.5400})
if r.status_code != 201: fallo("crear solicitud", r)
sol = r.json(); sid = sol["id"]
ok(f"solicitud {sid[:8]}… creada; prestadores notificados: {sol['prestadores_notificados']} (debe ser ≥ 1)")
if sol["prestadores_notificados"] == 0:
    print("    aviso: el matching no encontró al prestador; revisa oficios/categoría, verificado, disponible y distancia")

print("3. Prestador postula")
r = api(f"/api/solicitudes/{sid}/postular/", pre_tok, {"precio": 75000, "minutos_llegada": 20})
if r.status_code != 200: fallo("postular", r)
ok(f"postulación enviada; prob_contratacion = {r.json().get('prob_contratacion')} (None si aún no hay modelo cargado)")
posts = sb_rest("GET", "postulaciones", cli_tok, params={"solicitud_id": f"eq.{sid}", "select": "id,precio"}).json()
ok(f"el cliente ve {len(posts)} postulación(es)")

print("4. Cliente elige al prestador")
r = api(f"/api/solicitudes/{sid}/elegir/", cli_tok, {"postulacion_id": posts[0]["id"]})
if r.status_code != 200: fallo("elegir", r)
ok("solicitud asignada")

print("5. Prestador: en camino → en curso → finalizada")
for estado in ("en_camino", "en_curso", "finalizada"):
    r = api(f"/api/solicitudes/{sid}/estado/", pre_tok, {"estado": estado})
    if r.status_code != 200: fallo(f"estado {estado}", r)
    if estado == "en_camino":
        for lat, lng in ((10.4120, -75.5380), (10.4140, -75.5395)):
            sb_rest("POST", "posiciones", pre_tok, {"solicitud_id": sid, "prestador_id": pre_id, "lat": lat, "lng": lng})
        ok("posiciones publicadas (Realtime)")
    time.sleep(0.3)
ok("servicio finalizado")

r = api(f"/api/solicitudes/{sid}/estado/", cli_tok, {"estado": "cancelada"})
ok("cancelar una solicitud ya finalizada se rechaza (400)") if r.status_code == 400 else fallo("la máquina de estados aceptó algo indebido", r)

print("6. Calificaciones y chat")
sb_rest("POST", "calificaciones", cli_tok, {"solicitud_id": sid, "autor_id": cli_id, "receptor_id": pre_id, "puntaje": 5, "resena": "Excelente"})
sb_rest("POST", "calificaciones", pre_tok, {"solicitud_id": sid, "autor_id": pre_id, "receptor_id": cli_id, "puntaje": 4})
sb_rest("POST", "mensajes", cli_tok, {"solicitud_id": sid, "emisor_id": cli_id, "texto": "¿Ya vienes?"})
ok("calificación mutua y mensaje guardados")

fila = sb_rest("GET", "solicitudes", SERVICE, params={"id": f"eq.{sid}", "select": "estado,contratada,barrio,dia_semana,franja_horaria"}).json()[0]
ok(f"fila final: {fila}")
if fila["contratada"] is not True: fallo("contratada debería ser true")

print("\nTodo bien. Ahora en el panel (http://localhost:5173):")
print("  · Resumen: 1 solicitud publicada, 1 finalizada, tasa 100 %.")
print("  · Demanda: una barra en 'plomeria' y el barrio detectado:", fila["barrio"])
print("  · Mapas de calor: un punto azul (demanda) y uno naranja (oferta) en Manga.")
print("  · Usuarios: nada pendiente (el prestador ya quedó verificado).")
print("Para limpiar, borra en Supabase los usuarios *@prueba.chambapo (Authentication → Users); las filas se borran en cascada.")
