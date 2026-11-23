from django.core.management.base import BaseCommand
from apps.solicitudes.services.matching import ampliar_radio_pendientes

class Command(BaseCommand):
    help = "Amplía el radio de las solicitudes sin postulaciones (cron cada minuto)"
    def handle(self, *args, **opts):
        n = ampliar_radio_pendientes()
        self.stdout.write(f"radio ampliado en {n} solicitudes")
