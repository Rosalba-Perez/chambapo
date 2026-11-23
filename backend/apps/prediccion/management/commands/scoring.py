from django.core.management.base import BaseCommand
from apps.core import db
from apps.prediccion.predictor import predictor


class Command(BaseCommand):
    help = ("Recalcula P(contratada) de las solicitudes activas con menos de 24 h (cron cada hora). "
            "Con --ids puntúa las solicitudes indicadas, en cualquier estado (p. ej. datos de demostración).")

    def add_arguments(self, parser):
        parser.add_argument("--ids", nargs="*", help="Solicitudes a puntuar (por defecto: activas de las últimas 24 h)")

    def handle(self, *args, **opts):
        ids = opts.get("ids")
        if not ids:
            ids = [str(r["id"]) for r in db.fetchall("""select id from solicitudes
                where estado in ('publicada','con_postulaciones') and creado_en > now() - interval '24 hours'""")]
        probs = {}
        for i in range(0, len(ids), 200):
            probs.update(predictor.predecir_lote(ids[i:i + 200]))
        for i, p in probs.items():
            db.execute("update solicitudes set prob_contratacion = %s where id = %s", [p, i])
        self.stdout.write(f"{len(probs)} solicitudes puntuadas")
