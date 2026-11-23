import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'solicitud.dart';
import 'solicitudes_repository.dart';

final _perfilPublicoProvider = FutureProvider.autoDispose.family<PerfilPublico, String>(
    (ref, id) => SolicitudesRepository().perfilPrestador(id));


class PerfilPrestadorScreen extends ConsumerWidget {
  final String solicitudId, prestadorId;
  const PerfilPrestadorScreen({super.key, required this.solicitudId, required this.prestadorId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final data = ref.watch(_perfilPublicoProvider(prestadorId));
    return Scaffold(
      backgroundColor: CP.fondoApp,
      appBar: AppBar(backgroundColor: CP.fondoApp, title: const Text('Perfil del prestador')),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorPantalla(mensajeError(e), reintentar: () => ref.invalidate(_perfilPublicoProvider(prestadorId))),
        data: (p) {
          final anios = DateTime.now().difference(p.desde).inDays ~/ 365;
          return ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
            Center(child: AvatarIniciales(p.nombre, tam: 76, foto: p.foto)),
            const SizedBox(height: 10),
            Text(p.nombre, textAlign: TextAlign.center, style: tt.headlineSmall),
            const SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(p.verificado ? Icons.verified_user_outlined : Icons.hourglass_top, size: 16,
                  color: p.verificado ? CP.exito : CP.advertencia),
              const SizedBox(width: 4),
              Text(p.verificado ? 'Identidad verificada' : 'Verificación pendiente',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.verificado ? CP.exito : CP.advertencia)),
            ]),
            const SizedBox(height: 16),
            Card(child: Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Row(children: [
              _Cifra(p.calificacion == 0 ? '—' : p.calificacion.toStringAsFixed(1).replaceAll('.', ','), 'calificación'),
              _Cifra('${p.servicios}', 'servicios'),
              _Cifra(anios < 1 ? 'Nuevo' : '$anios ${anios == 1 ? 'año' : 'años'}', 'en Chambapo'),
            ]))),
            if (p.descripcion != null || p.zona != null) ...[
              const SizedBox(height: 12),
              if (p.descripcion != null) Text(p.descripcion!, textAlign: TextAlign.center, style: tt.bodyMedium),
              if (p.zona != null) Padding(padding: const EdgeInsets.only(top: 4),
                  child: Text('Trabaja en: ${p.zona}', textAlign: TextAlign.center, style: tt.bodySmall)),
            ],
            const EtiquetaSeccion('Oficios'),
            Wrap(spacing: 6, runSpacing: 6, children: [for (final o in p.oficios) ChipEstado(nombreCategoria(o))]),
            const EtiquetaSeccion('Reseñas recientes'),
            if (p.resenas.isEmpty) Text('Todavía no tiene reseñas.', style: tt.bodyMedium),
            for (final r in p.resenas) TarjetaResena(r),
          ]);
        },
      ),
      bottomNavigationBar: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton(onPressed: () => context.pop(), child: const Text('Volver')))),
    );
  }
}

class _Cifra extends StatelessWidget {
  final String valor, etiqueta;
  const _Cifra(this.valor, this.etiqueta);
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(valor, style: estiloTitulo.copyWith(fontSize: 20)),
    const SizedBox(height: 2),
    Text(etiqueta, style: Theme.of(context).textTheme.bodySmall),
  ]));
}

// Tarjeta de una reseña
class TarjetaResena extends StatelessWidget {
  final Resena r;
  const TarjetaResena(this.r, {super.key});
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(padding: const EdgeInsets.only(bottom: 10), child: Card(child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(r.autor, style: tt.titleSmall)),
                  for (var i = 0; i < 5; i++) Icon(i < r.puntaje ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 16, color: CP.naranjaLogo),
                ]),
                if (r.categoria.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Row(children: [
                  Builder(builder: (_) {
                    final (color, fondo) = colorCategoria(r.categoria);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(999)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(iconoCategoria(r.categoria), size: 13, color: color), const SizedBox(width: 4),
                        Text(nombreCategoria(r.categoria), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
                      ]),
                    );
                  }),
                  const SizedBox(width: 8),
                  Text(hace(r.fecha), style: tt.bodySmall),
                ])),
                if (r.texto.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(r.texto, style: tt.bodyMedium)),
              ]),
            )));
  }
}
