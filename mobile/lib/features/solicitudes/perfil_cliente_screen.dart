import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'perfil_prestador_screen.dart' show TarjetaResena;
import 'solicitud.dart';
import 'solicitudes_repository.dart';

final _perfilClienteProvider = FutureProvider.autoDispose.family<PerfilCliente, String>(
    (ref, id) => SolicitudesRepository().perfilCliente(id));


class PerfilClienteScreen extends ConsumerWidget {
  final String clienteId;
  const PerfilClienteScreen({super.key, required this.clienteId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final data = ref.watch(_perfilClienteProvider(clienteId));
    return Scaffold(
      backgroundColor: CP.fondoApp,
      appBar: AppBar(backgroundColor: CP.fondoApp, title: const Text('Perfil del cliente')),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorPantalla(mensajeError(e), reintentar: () => ref.invalidate(_perfilClienteProvider(clienteId))),
        data: (c) {
          final meses = DateTime.now().difference(c.desde).inDays ~/ 30;
          final promedio = c.promedio;
          return ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
            Center(child: AvatarIniciales(c.nombre, tam: 76, color: CP.naranja, foto: c.foto)),
            const SizedBox(height: 10),
            Text(c.nombre, textAlign: TextAlign.center, style: tt.headlineSmall),
            const SizedBox(height: 16),
            Card(child: Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Row(children: [
              _Cifra(promedio == null ? '—' : promedio.toStringAsFixed(1).replaceAll('.', ','), 'calificación'),
              _Cifra('${c.finalizadas}', c.finalizadas == 1 ? 'servicio hecho' : 'servicios hechos'),
              _Cifra(meses < 1 ? 'Nuevo' : (meses < 12 ? '$meses m' : '${meses ~/ 12} a'), 'en Chambapo'),
            ]))),
            const SizedBox(height: 8),
            Text('${c.publicadas} ${c.publicadas == 1 ? 'solicitud publicada' : 'solicitudes publicadas'} en total',
                textAlign: TextAlign.center, style: tt.bodySmall),
            const EtiquetaSeccion('Lo que dicen otros técnicos'),
            if (c.resenas.isEmpty) Text('Todavía no tiene reseñas.', style: tt.bodyMedium),
            for (final r in c.resenas) TarjetaResena(r),
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
