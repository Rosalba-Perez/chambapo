import csv
import random
import secrets
import unicodedata
from datetime import datetime, timedelta
from pathlib import Path
from zoneinfo import ZoneInfo

import os
import requests
from django.conf import settings
from django.core.management import call_command
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from apps.core import db

DOMINIO = "prueba.chambapo.co"
BOGOTA = ZoneInfo("America/Bogota")
CSV_POR_DEFECTO = settings.BASE_DIR.parent / "dataset-prueba-proyecto - Hoja 1.csv"

DIAS = {"lunes": 0, "martes": 1, "miercoles": 2, "jueves": 3, "viernes": 4, "sabado": 5, "domingo": 6}
FRANJAS = {"madrugada": (0, 5), "manana": (6, 11), "tarde": (12, 17), "noche": (18, 22)}
DURACION_H = {"plomeria": (1, 3), "electricidad": (1, 3), "aire_acondicionado": (1, 2.5), "electrodomesticos": (1, 2.5),
              "pintura": (3, 8), "cerrajeria": (.5, 1.5), "carpinteria": (2, 6), "albanileria": (3, 8), "otros": (1, 4)}
CATEGORIAS_EQUIVALENTES = {"limpieza": "otros", "jardineria": "otros"}

# Ubicación aproximada de cada barrio de Cartagena
BARRIOS = {
    "el pozon":          ("El Pozón",          10.41384, -75.46016, .0030),
    "olaya herrera":     ("Olaya Herrera",     10.40582, -75.48499, .0025),
    "manga":             ("Manga",             10.41145, -75.53523, .0012),
    "los alpes":         ("Los Alpes",         10.39750, -75.48224, .0020),
    "ternera":           ("Ternera",           10.38507, -75.46614, .0025),
    "bellavista":        ("Bellavista",        10.37143, -75.50466, .0018),
    "bocagrande":        ("Bocagrande",        10.40409, -75.55342, .0010),
    "fredonia":          ("Fredonia",          10.40799, -75.47430, .0020),
    "blas de lezo":      ("Blas de Lezo",      10.38657, -75.48598, .0018),
    "la boquilla":       ("La Boquilla",       10.47604, -75.49470, .0015),
    "centro historico":  ("Centro Histórico",  10.42397, -75.55119, .0010),
    "villa estrella":    ("Villa Estrella",    10.40341, -75.46312, .0015),
}

DESCRIPCIONES = {
    "plomeria": ["Se está saliendo el agua debajo del lavaplatos", "El sanitario no deja de correr agua", "Fuga en la llave de la ducha", "Tubería tapada en el patio"],
    "electricidad": ["Se va la luz en la cocina cuando prendo el microondas", "Toma corriente quemado en la sala", "Instalar una lámpara en el techo", "Revisar el breaker que se dispara"],
    "aire_acondicionado": ["El aire prende pero no enfría", "Mantenimiento de minisplit de 12.000 BTU", "El aire gotea agua dentro del cuarto", "Instalar aire acondicionado nuevo"],
    "electrodomesticos": ["La lavadora no centrifuga", "La nevera no está enfriando bien", "El horno microondas no calienta", "La estufa no prende un fogón"],
    "pintura": ["Pintar la reja de la casa", "Pintar dos habitaciones", "Pintar la fachada", "Retocar paredes con humedad"],
    "cerrajeria": ["Se me quedaron las llaves adentro", "Cambiar la guarda de la puerta principal", "La cerradura del portón está dañada", "Hacer copia de llaves e instalar cerrojo"],
    "carpinteria": ["Arreglar la puerta del closet", "Reparar bisagras de la cocina", "Armar un mueble", "La puerta del baño no cierra"],
    "albanileria": ["Resanar una pared agrietada", "Cambiar baldosas del baño", "Arreglar una filtración en la terraza"],
    "otros": ["Arreglo general en la casa", "Ayuda con una reparación pequeña"],
    "limpieza": ["Limpieza profunda del apartamento", "Limpieza después de una obra", "Lavar muebles y colchones"],
    "jardineria": ["Podar el jardín y cortar el césped", "Arreglar las plantas del patio", "Limpieza de jardín"],
}
NOMBRES = ["Ana", "Luis", "María", "Carlos", "Paola", "Jhon", "Diana", "Andrés", "Laura", "Jorge", "Camila", "Julián",
           "Valentina", "Mauricio", "Katherine", "Fabián", "Yuleidis", "Rafael", "Daniela", "Sebastián"]
APELLIDOS = ["Herrera", "Julio", "Pérez", "Martínez", "Rodríguez", "Gómez", "Díaz", "Mendoza", "Castro", "Ortega",
             "Barrios", "Torres", "Ramírez", "Pájaro", "Marrugo", "Cassiani", "Puello", "Villadiego"]


def normalizar(texto: str) -> str:
    t = unicodedata.normalize("NFKD", str(texto)).encode("ascii", "ignore").decode()
    return " ".join(t.replace("_", " ").lower().split())


def numero(texto: str) -> float:
    return float(str(texto).strip().replace(",", "."))


class Supabase:
    """Esta clase crea y borra los usuarios de prueba."""

    def __init__(self):
        self.url = settings.SUPABASE_URL.rstrip("/")
        clave = os.environ.get("SUPABASE_SERVICE_KEY")
        if not clave:
            raise CommandError("Falta SUPABASE_SERVICE_KEY en .env: se necesita para crear los usuarios de prueba.")
        self.cabeceras = {"apikey": clave, "Authorization": f"Bearer {clave}", "Content-Type": "application/json"}

    def crear_usuario(self, email, metadatos):
        r = requests.post(f"{self.url}/auth/v1/admin/users", headers=self.cabeceras, timeout=20, json={
            "email": email, "password": secrets.token_urlsafe(18), "email_confirm": True, "user_metadata": metadatos})
        if r.status_code >= 300:
            raise CommandError(f"No se pudo crear {email}: {r.status_code} {r.text[:200]}")
        return r.json()["id"]

    def borrar_usuario(self, uid):
        r = requests.delete(f"{self.url}/auth/v1/admin/users/{uid}", headers=self.cabeceras, timeout=20)
        return r.status_code < 300


class Command(BaseCommand):
    help = "Pobla Supabase con datos de demostración desde el CSV de prueba (usuarios @prueba.chambapo.co)."

    def add_arguments(self, parser):
        parser.add_argument("--archivo", default=str(CSV_POR_DEFECTO), help="Ruta del CSV")
        parser.add_argument("--limpiar", action="store_true", help="Solo borra los datos de prueba")
        parser.add_argument("--reemplazar", action="store_true", help="Borra los datos de prueba y vuelve a poblar")
        parser.add_argument("--clientes", type=int, default=40)
        parser.add_argument("--prestadores", type=int, default=12)
        parser.add_argument("--dias", type=int, default=60, help="Las solicitudes se reparten en los últimos N días")
        parser.add_argument("--semilla", type=int, default=42)
        parser.add_argument("--activas", type=int, default=15,
                            help="Solicitudes ACTIVAS de hoy para la tabla de predicciones (alta, media y baja)")
        parser.add_argument("--solo-vistas", action="store_true",
                            help="Solo genera las vistas simuladas de técnicos para las solicitudes de prueba que no tengan")
        parser.add_argument("--solo-activas", action="store_true",
                            help="Solo (re)crea las solicitudes activas de demo, sin tocar las del CSV")

    def _ids_prueba(self):
        return [str(r["id"]) for r in db.fetchall("select id from auth.users where email like %s", [f"%@{DOMINIO}"])]

    def _solicitudes_prueba(self, ids):
        if not ids:
            return 0
        return db.fetchone("select count(*) n from solicitudes where cliente_id = any(%s::uuid[])", [ids])["n"]

    def limpiar(self):
        ids = self._ids_prueba()
        if not ids:
            self.stdout.write("No hay datos de prueba que borrar.")
            return
        with transaction.atomic():
            sols = [str(r["id"]) for r in db.fetchall(
                "select id from solicitudes where cliente_id = any(%s::uuid[]) or prestador_id = any(%s::uuid[])", [ids, ids])]
            db.execute("delete from calificaciones where solicitud_id = any(%s::uuid[]) or autor_id = any(%s::uuid[]) "
                       "or receptor_id = any(%s::uuid[])", [sols, ids, ids])
            db.execute("delete from reportes where solicitud_id = any(%s::uuid[]) or autor_id = any(%s::uuid[]) "
                       "or reportado_id = any(%s::uuid[])", [sols, ids, ids])
            db.execute("delete from postulaciones where prestador_id = any(%s::uuid[])", [ids])
            n_sol = db.execute("delete from solicitudes where id = any(%s::uuid[])", [sols])
        api = Supabase()
        borrados = sum(api.borrar_usuario(u) for u in ids)
        if borrados < len(ids):
            db.execute("delete from auth.users where email like %s", [f"%@{DOMINIO}"])
        db.execute("""update prestadores p set servicios_completados =
                      (select count(*) from solicitudes s where s.prestador_id = p.id and s.estado = 'finalizada')""")
        self.stdout.write(self.style.SUCCESS(f"Borrados: {n_sol} solicitudes y {len(ids)} usuarios de prueba."))

    def usuarios(self, rng, n_clientes, n_prestadores, categorias):
        api = Supabase()
        existentes = {r["email"]: str(r["id"]) for r in db.fetchall(
            "select id, email from auth.users where email like %s", [f"%@{DOMINIO}"])}

        def nombre():
            return f"{rng.choice(NOMBRES)} {rng.choice(APELLIDOS)}"

        def obtener(email, rol, extra):
            if email in existentes:
                return existentes[email]
            meta = {"rol": rol, "nombre": nombre(), "telefono": f"30{rng.randint(10000000, 99999999)}", **extra}
            uid = api.crear_usuario(email, meta)
            db.execute("""insert into perfiles (id, rol, nombre, telefono) values (%s, %s, %s, %s)
                          on conflict (id) do nothing""", [uid, rol, meta["nombre"], meta["telefono"]])
            return uid

        clientes = [obtener(f"cliente{i:02d}@{DOMINIO}", "cliente", {}) for i in range(1, n_clientes + 1)]
        prestadores, oficios_de = [], {}
        barrios = list(BARRIOS.values())
        for i in range(1, n_prestadores + 1):
            oficios = rng.sample(categorias, k=min(3, len(categorias)))
            uid = obtener(f"tecnico{i:02d}@{DOMINIO}", "prestador", {"oficios": oficios})
            nombre_b, lat, lng, disp = barrios[(i - 1) % len(barrios)]
            lat, lng = lat + rng.gauss(0, disp), lng + rng.gauss(0, disp)
            db.execute("""insert into prestadores (id, oficios) values (%s, %s) on conflict (id) do nothing""", [uid, oficios])
            db.execute("""update prestadores set oficios = %s, verificado = true, disponible = true, zona_habitual = %s,
                          ubicacion = st_setsrid(st_makepoint(%s, %s), 4326)::geography, ubicacion_en = now()
                          where id = %s""", [oficios, nombre_b, lng, lat, uid])
            prestadores.append(uid)
            oficios_de[uid] = set(oficios)
        return clientes, prestadores, oficios_de

    def leer_csv(self, ruta):
        ruta = Path(ruta)
        if not ruta.exists():
            raise CommandError(f"No existe el archivo {ruta}")
        filas = list(csv.reader(ruta.open(encoding="utf-8-sig")))
        i_enc = next(i for i, f in enumerate(filas) if "categoria" in [c.strip() for c in f])
        enc = {c.strip(): j for j, c in enumerate(filas[i_enc]) if c.strip()}
        return [{k: f[j].strip() for k, j in enc.items()} for f in filas[i_enc + 1:] if any(c.strip() for c in f)]

    def creado_en(self, rng, dia, franja, dias, ahora):
        h_ini, h_fin = FRANJAS[franja]
        semanas = max(1, (dias - 3) // 7)
        hoy = ahora.astimezone(BOGOTA).date()
        for _ in range(50):
            fecha = hoy - timedelta(days=rng.randint(3, max(3, dias)))
            fecha -= timedelta(days=(fecha.weekday() - dia) % 7)
            momento = datetime(fecha.year, fecha.month, fecha.day, rng.randint(h_ini, h_fin), rng.randint(0, 59),
                               rng.randint(0, 59), tzinfo=BOGOTA)
            if momento < ahora - timedelta(days=3):
                return momento
        return momento - timedelta(weeks=semanas)

    def poblar(self, opts):
        rng = random.Random(opts["semilla"])
        filas = self.leer_csv(opts["archivo"])
        cat_ids = {r["nombre"]: r["id"] for r in db.fetchall("select id, nombre from categorias")}
        if "otros" not in cat_ids:
            raise CommandError("Falta la categoría «otros»: ejecuta la migración 005.")
        categorias_reales = [c for c in cat_ids if c != "otros"]
        clientes, prestadores, oficios_de = self.usuarios(rng, opts["clientes"], opts["prestadores"], categorias_reales)
        if max(int(f["num_postulaciones"]) for f in filas) > len(prestadores):
            raise CommandError("Hay filas con más postulaciones que técnicos de prueba: aumenta --prestadores.")

        ahora = datetime.now(BOGOTA)
        creadas, avisos = [], {"categoria_a_otros": 0, "precio_atipico": 0, "barrio_desconocido": 0}
        conteo_estados = {"finalizada": 0, "cancelada": 0, "expirada": 0}
        with transaction.atomic():
            for f in filas:
                cat_csv = normalizar(f["categoria"]).replace(" ", "_")
                cat = CATEGORIAS_EQUIVALENTES.get(cat_csv, cat_csv)
                if cat not in cat_ids:
                    cat = "otros"
                if cat != cat_csv:
                    avisos["categoria_a_otros"] += 1
                b = BARRIOS.get(normalizar(f["barrio"]))
                if b is None:
                    avisos["barrio_desconocido"] += 1
                    b = (f["barrio"].replace("_", " ").strip(), 10.40, -75.50, .01)
                barrio, blat, blng, disp = b
                lat, lng = blat + rng.gauss(0, disp), blng + rng.gauss(0, disp)

                dia = DIAS[normalizar(f["dia_semana"])]
                franja = normalizar(f["franja_horaria"])
                if franja not in FRANJAS:
                    raise CommandError(f"Franja desconocida: {f['franja_horaria']}")
                anticipacion = int(numero(f["dias_anticipacion"]))
                presupuesto = int(round(numero(f["presupuesto_estimado"])))
                n_post = int(numero(f["num_postulaciones"]))
                t_primera_h = numero(f["tiempo_primera_postulacion_h"])
                precio_rel = numero(f["precio_relativo"])
                contratada = normalizar(f["contratada"]) in ("si", "1", "true")
                if contratada and n_post == 0:
                    n_post = 1

                creado = self.creado_en(rng, dia, franja, opts["dias"], ahora)
                fecha_deseada = creado + timedelta(days=anticipacion) if anticipacion > 0 else None
                descripcion = rng.choice(DESCRIPCIONES.get(cat_csv) or DESCRIPCIONES[cat])
                cliente = rng.choice(clientes)

                ofertas = []
                if n_post:
                    afines = [p for p in prestadores if cat in oficios_de[p]]
                    candidatos = afines + [p for p in prestadores if p not in afines]
                    elegidos = (rng.sample(afines, n_post) if len(afines) >= n_post
                                else afines + rng.sample(candidatos[len(afines):], n_post - len(afines)))
                    if precio_rel < 0.3:
                        avisos["precio_atipico"] += 1
                        precio_rel = 1.0
                    precio_min = max(5000, int(round(precio_rel * presupuesto, -3)))
                    t1 = creado + timedelta(hours=t_primera_h)
                    elegido_en = t1 + timedelta(minutes=rng.randint(10, 60))
                    ventana = (elegido_en - t1).total_seconds() / 60
                    for k, p in enumerate(elegidos):
                        if k == 0:
                            momento, precio = t1, precio_min
                        else:
                            momento = t1 + timedelta(minutes=rng.uniform(1, ventana - 1))
                            precio = max(precio_min, int(round(precio_min * rng.uniform(1.0, 1.35), -3)))
                        ofertas.append((p, precio, rng.choice([15, 20, 25, 30, 40, 45, 60, 90]), momento))

                asignado_en = None
                if contratada:
                    estado = "finalizada"
                    asignado, precio_acordado = ofertas[0][0], ofertas[0][1]
                    asignado_en = elegido_en
                    dur_min, dur_max = DURACION_H.get(cat, DURACION_H["otros"])
                    duracion = timedelta(hours=rng.uniform(dur_min, dur_max))
                    if fecha_deseada and fecha_deseada + duracion + timedelta(hours=1) < ahora:
                        llegada = max(elegido_en + timedelta(minutes=20), fecha_deseada + timedelta(minutes=rng.randint(-20, 20)))
                    else:
                        llegada = elegido_en + timedelta(minutes=rng.randint(20, 60))
                    inicio = llegada + timedelta(minutes=rng.randint(3, 10))
                    fin = inicio + duracion
                    cerrado = fin + timedelta(minutes=rng.randint(5, 30))
                    tiempos = (llegada, llegada + timedelta(minutes=2), inicio, fin)
                else:
                    asignado, precio_acordado, tiempos = None, None, (None, None, None, None)
                    if ofertas:
                        estado = "cancelada"
                        cerrado = max(o[3] for o in ofertas) + timedelta(hours=rng.uniform(1, 4))
                    else:
                        estado = "expirada"
                        cerrado = creado + timedelta(hours=24)
                conteo_estados[estado] += 1

                sid = db.fetchone("""
                    insert into solicitudes (cliente_id, categoria_id, descripcion, presupuesto, fecha_deseada, ubicacion,
                        barrio, estado, prestador_id, precio_acordado, asignado_en, contratada, creado_en, cerrado_en,
                        llegada_reportada_en, llegada_confirmada_en, iniciado_en, fin_reportado_en,
                        tiene_materiales, materiales)
                    values (%s, %s, %s, %s, %s, st_setsrid(st_makepoint(%s, %s), 4326)::geography,
                            %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                    returning id""",
                    [cliente, cat_ids[cat], descripcion, presupuesto, fecha_deseada, lng, lat,
                     barrio, estado, asignado, precio_acordado, asignado_en, contratada, creado, cerrado, *tiempos,
                     rng.random() < .5, "Datos de demostración"])["id"]
                for p, precio, minutos, momento in ofertas:
                    db.execute("""insert into postulaciones (solicitud_id, prestador_id, precio, minutos_llegada, creado_en)
                                  values (%s, %s, %s, %s, %s)""", [sid, p, precio, minutos, momento])
                creadas.append(str(sid))

            db.execute("""update prestadores p set servicios_completados =
                          (select count(*) from solicitudes s where s.prestador_id = p.id and s.estado = 'finalizada')
                          where p.id = any(%s::uuid[])""", [prestadores])

        self.stdout.write(self.style.SUCCESS(
            f"Creadas {len(creadas)} solicitudes ({conteo_estados}) con "
            f"{db.fetchone('select count(*) n from postulaciones where solicitud_id = any(%s::uuid[])', [creadas])['n']} "
            f"postulaciones; {len(clientes)} clientes y {len(prestadores)} técnicos de prueba."))
        if any(avisos.values()):
            self.stdout.write(self.style.WARNING(
                f"Ajustes: {avisos['categoria_a_otros']} filas de Limpieza/Jardinería → «otros»; "
                f"{avisos['precio_atipico']} ofertas con precio_relativo 0,02 → precio = presupuesto; "
                f"{avisos['barrio_desconocido']} barrios sin coordenadas conocidas."))
        call_command("scoring", ids=creadas, stdout=self.stdout)
        if opts["activas"]:
            self.crear_activas(rng, opts["activas"])
        return creadas

    RECETAS = {
        "baja":  [dict(ofertas=0)] * 5,
        "media": [dict(ofertas=1, t_min=420, precio=2.0, ant=5), dict(ofertas=1, t_min=720, precio=1.8, ant=5),
                  dict(ofertas=1, t_min=480, precio=1.8, ant=5), dict(ofertas=1, t_min=600, precio=1.9, ant=5),
                  dict(ofertas=1, t_min=540, precio=2.0, ant=5)],
        "alta":  [dict(ofertas=2, t_min=15, precio=1.0), dict(ofertas=4, t_min=10, precio=0.95),
                  dict(ofertas=2, t_min=30, precio=1.05), dict(ofertas=4, t_min=20, precio=1.1),
                  dict(ofertas=2, t_min=12, precio=0.9)],
    }

    def crear_activas(self, rng, cantidad):
        """Crea solicitudes activas de hoy con clientes de prueba."""
        ids_prueba = self._ids_prueba()
        clientes = [str(r["id"]) for r in db.fetchall(
            "select p.id from perfiles p join auth.users u on u.id = p.id where u.email like %s and p.rol = 'cliente'", [f"%@{DOMINIO}"])]
        tecnicos = [str(r["id"]) for r in db.fetchall(
            "select p.id from perfiles p join auth.users u on u.id = p.id where u.email like %s and p.rol = 'prestador'", [f"%@{DOMINIO}"])]
        if not clientes or len(tecnicos) < 4:
            raise CommandError("No hay usuarios de prueba suficientes: ejecuta primero el poblado completo.")
        cat_ids = {r["nombre"]: r["id"] for r in db.fetchall("select id, nombre from categorias where nombre <> 'otros'")}

        ahora = datetime.now(BOGOTA)
        medianoche = ahora.replace(hour=0, minute=0, second=0, microsecond=0)
        minutos_hoy = int((ahora - medianoche).total_seconds() // 60)
        recetas = [(nivel, r) for nivel in ("baja", "media", "alta") for r in self.RECETAS[nivel]]
        recetas = [recetas[i % len(recetas)] for i in range(cantidad)]
        barrios = list(BARRIOS.values())
        creadas = []
        with transaction.atomic():
            db.execute("""delete from solicitudes where cliente_id = any(%s::uuid[])
                          and estado in ('publicada', 'con_postulaciones')""", [ids_prueba])
            for k, (nivel, r) in enumerate(recetas):
                t_min = min(r.get("t_min", 0), max(10, minutos_hoy - 40))
                atras = rng.randint(t_min + 15, max(t_min + 20, min(minutos_hoy - 5, t_min + 180)))
                creado = ahora - timedelta(minutes=min(atras, max(5, minutos_hoy - 1)))
                cat = rng.choice(list(cat_ids))
                barrio, blat, blng, disp = barrios[k % len(barrios)]
                presupuesto = int(round(rng.choice([60000, 80000, 95000, 120000, 150000, 220000, 300000]) * rng.uniform(.9, 1.1), -3))
                fecha_deseada = creado + timedelta(days=r["ant"]) if r.get("ant") else None
                estado = "con_postulaciones" if r["ofertas"] else "publicada"
                sid = str(db.fetchone("""
                    insert into solicitudes (cliente_id, categoria_id, descripcion, presupuesto, fecha_deseada, ubicacion,
                        barrio, estado, creado_en, tiene_materiales, materiales)
                    values (%s, %s, %s, %s, %s, st_setsrid(st_makepoint(%s, %s), 4326)::geography, %s, %s, %s, %s, %s)
                    returning id""",
                    [rng.choice(clientes), cat_ids[cat], rng.choice(DESCRIPCIONES.get(cat, DESCRIPCIONES["otros"])), presupuesto, fecha_deseada,
                     blng + rng.gauss(0, disp), blat + rng.gauss(0, disp), barrio, estado, creado,
                     rng.random() < .5, "Datos de demostración"])["id"])
                precio_min = max(5000, int(round(r.get("precio", 1) * presupuesto, -3)))
                for j, tec in enumerate(rng.sample(tecnicos, r["ofertas"])):
                    momento = creado + timedelta(minutes=t_min + j * rng.randint(3, 12))
                    precio = precio_min if j == 0 else int(round(precio_min * rng.uniform(1.02, 1.25), -3))
                    db.execute("""insert into postulaciones (solicitud_id, prestador_id, precio, minutos_llegada, creado_en)
                                  values (%s, %s, %s, %s, %s)""", [sid, tec, precio, rng.choice([15, 20, 30, 45]), min(momento, ahora)])
                creadas.append(sid)
        call_command("scoring", ids=creadas, stdout=self.stdout)
        filas = db.fetchall("select prob_contratacion p from solicitudes where id = any(%s::uuid[])", [creadas])
        niveles = {"alta": 0, "media": 0, "baja": 0}
        for f in filas:
            p = float(f["p"] or 0)
            niveles["alta" if p >= .6 else "media" if p >= .35 else "baja"] += 1
        self.stdout.write(self.style.SUCCESS(f"{len(creadas)} solicitudes activas de hoy · semáforo: {niveles}"))
        return creadas

    def crear_vistas(self, semilla):
        """Simula qué técnicos vieron cada solicitud."""
        pendientes = [str(r["id"]) for r in db.fetchall("""
            select s.id from solicitudes s join auth.users c on c.id = s.cliente_id
            where c.email like %s and not exists (select 1 from vistas_solicitud v where v.solicitud_id = s.id)""",
            [f"%@{DOMINIO}"])]
        if not pendientes:
            self.stdout.write("Todas las solicitudes de prueba ya tienen vistas.")
            return
        with transaction.atomic():
            db.execute("select setseed(%s)", [(semilla % 1000) / 1000])
            n1 = db.execute("""
              insert into vistas_solicitud (solicitud_id, prestador_id, creado_en)
              select p.solicitud_id, p.prestador_id,
                     greatest(s.creado_en, p.creado_en - make_interval(mins => (2 + floor(random() * 18))::int))
              from postulaciones p join solicitudes s on s.id = p.solicitud_id
              join prestadores t on t.id = p.prestador_id
              where s.id = any(%s::uuid[])
              on conflict do nothing""", [pendientes])
            n2 = db.execute("""
              with sol as (select s.id, s.creado_en, random() alcance from solicitudes s where s.id = any(%s::uuid[])),
                   tec as (select t.id from prestadores t join auth.users u on u.id = t.id and u.email like %s)
              insert into vistas_solicitud (solicitud_id, prestador_id, creado_en)
              select sol.id, tec.id, least(now(), sol.creado_en + make_interval(mins => (1 + floor(random() * 180))::int))
              from sol cross join tec
              where sol.alcance >= .15 and random() < .35
              on conflict do nothing""", [pendientes, f"%@{DOMINIO}"])
        self.stdout.write(self.style.SUCCESS(f"Vistas simuladas: {n1} de técnicos que ofertaron + {n2} sin oferta."))

    def handle(self, *args, **opts):
        if opts["limpiar"]:
            self.limpiar()
            return
        if opts["solo_vistas"]:
            self.crear_vistas(opts["semilla"])
            return
        if opts["solo_activas"]:
            self.crear_activas(random.Random(opts["semilla"]), opts["activas"] or 15)
            self.crear_vistas(opts["semilla"])
            return
        if opts["reemplazar"]:
            self.limpiar()
        elif self._solicitudes_prueba(self._ids_prueba()):
            raise CommandError("Ya hay datos de prueba. Usa --reemplazar para volver a crearlos, --solo-activas para "
                               "renovar las activas de hoy o --limpiar para borrarlos.")
        self.poblar(opts)
        self.crear_vistas(opts["semilla"])
