from django.core.management.base import BaseCommand
from apps.core import db

class Command(BaseCommand):
    help = "Marca como expiradas (contratada = false) las solicitudes sin asignar tras N horas"
    def handle(self, *args, **opts):
        horas = db.parametro("horas_expiracion", 24)
        n = db.execute("""update solicitudes set estado = 'expirada', contratada = false, cerrado_en = now()
                          where estado in ('publicada', 'con_postulaciones')
                          and creado_en < now() - make_interval(hours => %s::int)""", [horas])
        self.stdout.write(f"{n} solicitudes expiradas")
