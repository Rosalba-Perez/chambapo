import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../auth/auth_provider.dart';
import '../notificaciones/push_service.dart';
import '../solicitudes/perfil_prestador_screen.dart' show TarjetaResena;
import '../solicitudes/solicitud.dart';
import '../solicitudes/solicitudes_repository.dart';

// Pestaña del perfil con los datos de la cuenta
class PerfilTab extends ConsumerWidget {
  const PerfilTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(perfilProvider).value;
    if (p == null) return const SizedBox.shrink();
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: CP.fondoApp,
      appBar: AppBar(backgroundColor: CP.fondoApp, title: Text(p.esPrestador ? 'Mi perfil' : 'Perfil')),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
          AvatarIniciales(p.nombre, tam: 52, color: p.esPrestador ? CP.verde : CP.naranja, foto: p.fotoUrl),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.nombre, style: tt.titleMedium),
            const SizedBox(height: 2),
            Text([p.email, p.esPrestador ? 'prestador' : p.esAdmin ? 'administrador' : 'cliente'].where((x) => x.isNotEmpty).join(' · '), style: tt.bodySmall),
          ])),
        ]))),
        const SizedBox(height: 10),
        OutlinedButton.icon(onPressed: () => context.push('/perfil/editar'),
            icon: const Icon(Icons.edit_outlined, size: 18), label: const Text('Editar perfil')),
        if (p.esPrestador) ...[
          const SizedBox(height: 12),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(p.verificado ? Icons.verified_user_outlined : Icons.hourglass_top, size: 18, color: p.verificado ? CP.exito : CP.advertencia),
              const SizedBox(width: 6),
              Text(p.verificado ? 'Identidad verificada' : 'Verificación pendiente',
                  style: TextStyle(fontWeight: FontWeight.w700, color: p.verificado ? CP.exito : CP.advertencia)),
            ]),
            const SizedBox(height: 12),
            Text('Oficios', style: tt.titleSmall),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final o in p.oficios) ChipEstado(nombreCategoria(o)),
              if (p.oficios.isEmpty) Text('Sin oficios registrados', style: tt.bodySmall),
            ]),
          ]))),
          const _MisResenas(),
        ],
        const SizedBox(height: 12),
        Card(child: Column(children: [
          _Dato(Icons.person_outline, 'Nombre', p.nombre),
          const Divider(indent: 16, endIndent: 16),
          _Dato(Icons.mail_outline, 'Correo', p.email.isEmpty ? '—' : p.email),
          const Divider(indent: 16, endIndent: 16),
          _Dato(Icons.smartphone_outlined, 'Celular', p.telefono?.isNotEmpty == true ? p.telefono! : '—'),
        ])),
        const SizedBox(height: 12),
        const _EstadoNotificaciones(),
        const SizedBox(height: 12),
        Card(child: ListTile(
          leading: const Icon(Icons.logout, color: CP.error),
          title: const Text('Cerrar sesión', style: TextStyle(color: CP.error, fontWeight: FontWeight.w700)),
          onTap: () async {
            final ok = await confirmar(context, titulo: '¿Cerrar sesión?', destructivo: true, si: 'Sí, cerrar sesión',
                mensaje: 'Tendrás que volver a ingresar con tu correo y contraseña.');
            if (ok) await AuthRepository().salir();
          },
        )),
        const SizedBox(height: 10),
        Text('Cerrar sesión borra la sesión de este dispositivo.', textAlign: TextAlign.center, style: tt.bodySmall),
      ]),
    );
  }
}

// Muestra si este celular puede recibir notificaciones y permite reintentar
class _EstadoNotificaciones extends StatefulWidget {
  const _EstadoNotificaciones();
  @override
  State<_EstadoNotificaciones> createState() => _EstadoNotificacionesState();
}

class _EstadoNotificacionesState extends State<_EstadoNotificaciones> {
  String _estado = PushService.estado;

  @override
  Widget build(BuildContext context) {
    final ok = _estado.startsWith('Activas');
    return Card(child: Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 14), child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(ok ? Icons.notifications_active_outlined : Icons.notifications_off_outlined, color: ok ? CP.exito : CP.advertencia),
          const SizedBox(width: 10),
          Expanded(child: Text('Notificaciones', style: Theme.of(context).textTheme.titleSmall)),
        ]),
        const SizedBox(height: 6),
        Text(_estado, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 10),
        BotonAsync(contorno: true, estilo: estiloFantasma, hijo: const Text('Revisar de nuevo'), accion: () async {
          final e = await PushService.revisar();
          if (mounted) setState(() => _estado = e);
        }),
      ],
    )));
  }
}

class _Dato extends StatelessWidget {
  final IconData icono;
  final String etiqueta, valor;
  const _Dato(this.icono, this.etiqueta, this.valor);
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icono, color: CP.apagado),
    title: Text(etiqueta, style: Theme.of(context).textTheme.labelMedium),
    subtitle: Text(valor, style: const TextStyle(color: CP.tinta, fontSize: 15)),
  );
}

final _miPerfilPublicoProvider = FutureProvider.autoDispose<PerfilPublico?>((ref) async {
  final p = await ref.watch(perfilProvider.future);
  if (p == null || !p.esPrestador) return null;
  return SolicitudesRepository().perfilPrestador(p.id);
});

class _MisResenas extends ConsumerWidget {
  const _MisResenas();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    return ref.watch(_miPerfilPublicoProvider).when(
      loading: () => const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
      error: (e, _) => Padding(padding: const EdgeInsets.only(top: 12),
          child: Aviso(TipoAviso.error, 'No pudimos cargar tus reseñas', texto: mensajeError(e))),
      data: (pp) => pp == null ? const SizedBox.shrink() : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 12),
        Card(child: Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Row(children: [
          _Cifra(pp.calificacion == 0 ? '—' : pp.calificacion.toStringAsFixed(1).replaceAll('.', ','), 'calificación'),
          _Cifra('${pp.servicios}', 'servicios completados'),
          _Cifra('${pp.resenas.length}', pp.resenas.length == 1 ? 'reseña' : 'reseñas'),
        ]))),
        const EtiquetaSeccion('Mis reseñas'),
        if (pp.resenas.isEmpty) Text('Aún no tienes reseñas. Aparecerán cuando los clientes califiquen tus servicios.',
            style: tt.bodyMedium),
        for (final r in pp.resenas) TarjetaResena(r),
      ]),
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
    Text(etiqueta, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
  ]));
}
