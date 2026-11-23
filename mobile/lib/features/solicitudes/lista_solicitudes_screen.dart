import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../auth/auth_provider.dart';
import 'solicitud.dart';
import 'solicitudes_repository.dart';

final misSolicitudesProvider = FutureProvider.autoDispose<List<Solicitud>>((ref) async {
  await ref.watch(sesionProvider.future);
  return SolicitudesRepository().misSolicitudes();
});
final abiertasProvider = FutureProvider.autoDispose<List<Solicitud>>((ref) async {
  await ref.watch(sesionProvider.future);
  return SolicitudesRepository().solicitudesAbiertas();
});
final trabajosProvider = FutureProvider.autoDispose<List<Solicitud>>((ref) async {
  await ref.watch(sesionProvider.future);
  return SolicitudesRepository().misTrabajos();
});


class ListaSolicitudesTab extends ConsumerWidget {
  final bool trabajos;
  const ListaSolicitudesTab({super.key, this.trabajos = false});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proveedor = trabajos ? trabajosProvider : misSolicitudesProvider;
    final lista = ref.watch(proveedor);
    return Scaffold(
      backgroundColor: CP.fondoApp,
      appBar: AppBar(backgroundColor: CP.fondoApp, title: Text(trabajos ? 'Mis trabajos' : 'Mis solicitudes')),
      body: lista.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorPantalla(mensajeError(e), reintentar: () => ref.invalidate(proveedor)),
        data: (items) => RefreshIndicator(
          onRefresh: () => ref.refresh(proveedor.future),
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
            if (items.isEmpty)
              trabajos
                  ? const Vacio(Icons.work_outline, 'Aún no tienes trabajos', 'Cuando un cliente elija tu oferta, el servicio aparecerá aquí.')
                  : const Vacio(Icons.receipt_long_outlined, 'Aún no has publicado solicitudes', 'Pide un servicio desde Inicio y aquí verás su avance.'),
            for (final s in items) Padding(padding: const EdgeInsets.only(bottom: 12), child: TarjetaSolicitud(s, verCliente: trabajos)),
          ]),
        ),
      ),
    );
  }
}

// Tarjeta de una solicitud en las listas
class TarjetaSolicitud extends StatelessWidget {
  final Solicitud s;
  final bool verCliente;
  const TarjetaSolicitud(this.s, {super.key, this.verCliente = false});
  @override
  Widget build(BuildContext context) {
    final (color, fondo) = colorCategoria(s.categoria);
    final detalle = [
      if (s.barrio != null) s.barrio!,
      if (verCliente && s.clienteNombre != null) 'cliente ${s.clienteNombre}',
      if (!verCliente && s.prestadorNombre != null) s.prestadorNombre!,
      if (s.activa && !verCliente) s.numPostulaciones == 1 ? '1 oferta' : '${s.numPostulaciones} ofertas',
    ].join(' · ');
    return Card(child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => context.push('/solicitud/${s.id}'),
      child: Padding(padding: const EdgeInsets.all(14), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 42, height: 42, decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(12)),
            child: Icon(iconoCategoria(s.categoria), color: color, size: 22)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(nombreCategoria(s.categoria), style: Theme.of(context).textTheme.titleSmall)),
            ChipEstado.deSolicitud(s.estado, enRevision: s.enRevision),
          ]),
          const SizedBox(height: 4),
          Text(s.descripcion, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium),
          if (detalle.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6),
              child: Text(detalle, style: Theme.of(context).textTheme.bodySmall)),
          if (verCliente && s.estado == 'finalizada' && s.conInconvenientes)
            const Padding(padding: EdgeInsets.only(top: 6), child: Row(children: [
              Icon(Icons.warning_amber_rounded, size: 16, color: CP.advertencia),
              SizedBox(width: 4),
              Expanded(child: Text('Realizado, pero tuviste inconvenientes',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: CP.advertencia))),
            ])),
        ])),
      ])),
    ));
  }
}
