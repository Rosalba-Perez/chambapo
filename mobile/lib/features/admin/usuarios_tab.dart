import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'admin_repository.dart';

typedef DatosUsuarios = ({List<Fila> pendientes, List<Fila> reportes, List<Fila> vetados, List<Fila> historial});

final datosUsuariosProvider = FutureProvider.autoDispose<DatosUsuarios>((ref) async {
  final r = AdminRepository();
  final res = await Future.wait([r.tecnicosPendientes(), r.reportesAbiertos(), r.vetados(), r.historialReportes()]);
  return (pendientes: res[0], reportes: res[1], vetados: res[2], historial: res[3]);
});

String _rol(Object? rol) => rol == 'prestador' ? 'técnico' : 'cliente';
String _fecha(Object? iso) {
  final f = DateTime.tryParse('$iso')?.toLocal();
  return f == null ? '' : '${f.day}/${f.month}/${f.year}';
}

// Pestaña para aprobar técnicos, atender reportes y reactivar cuentas
class UsuariosTab extends ConsumerWidget {
  const UsuariosTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datos = ref.watch(datosUsuariosProvider);
    Future<void> recargar() async => ref.invalidate(datosUsuariosProvider);
    return Scaffold(
      backgroundColor: CP.fondoApp,
      appBar: AppBar(backgroundColor: CP.fondoApp, title: const Text('Usuarios'),
          actions: [IconButton(tooltip: 'Actualizar', onPressed: recargar, icon: const Icon(Icons.refresh))]),
      body: datos.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorPantalla(mensajeError(e), reintentar: recargar),
        data: (d) => RefreshIndicator(
          onRefresh: recargar,
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
            EtiquetaSeccion('Técnicos por aprobar (${d.pendientes.length})'),
            if (d.pendientes.isEmpty) const _Nada('Nadie en espera.'),
            for (final p in d.pendientes) _TarjetaPendiente(p, alTerminar: recargar),
            EtiquetaSeccion('Reportes sin atender (${d.reportes.length})'),
            if (d.reportes.isEmpty) const _Nada('No hay reportes abiertos.'),
            for (final r in d.reportes) _TarjetaReporte(r, alTerminar: recargar),
            EtiquetaSeccion('Usuarios vetados (${d.vetados.length})'),
            if (d.vetados.isEmpty) const _Nada('No hay usuarios vetados.'),
            for (final v in d.vetados)
              _TarjetaVetado(v, reportes: [for (final r in d.historial) if (r['reportado_id'] == v['id']) r], alTerminar: recargar),
          ]),
        ),
      ),
    );
  }
}

class _Nada extends StatelessWidget {
  final String texto;
  const _Nada(this.texto);
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(16),
      child: Text(texto, style: Theme.of(context).textTheme.bodyMedium)));
}

Future<void> _accion(BuildContext context, Future<void> Function() hacer, String hecho, Future<void> Function() alTerminar) async {
  await hacer();
  if (context.mounted) avisar(context, hecho);
  await alTerminar();
}

// Tarjeta de un técnico que espera aprobación
class _TarjetaPendiente extends StatelessWidget {
  final Fila p;
  final Future<void> Function() alTerminar;
  const _TarjetaPendiente(this.p, {required this.alTerminar});
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final perfil = p['perfiles'] as Map;
    final nombre = '${perfil['nombre'] ?? 'Sin nombre'}';
    final oficios = List<String>.from(p['oficios'] ?? const []);
    final docs = [
      if (perfil['foto_url'] != null) ('Foto', perfil['foto_url'] as String),
      if (p['documento_url'] != null) ('Cédula frente', p['documento_url'] as String),
      if (p['documento_reverso_url'] != null) ('Cédula reverso', p['documento_reverso_url'] as String),
      if (p['certificado_url'] != null) ('Certificado', p['certificado_url'] as String),
    ];
    return Card(margin: const EdgeInsets.only(bottom: 10), child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          AvatarIniciales(nombre, foto: perfil['foto_url'] as String?),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(nombre, style: tt.titleMedium),
            Text([if (perfil['telefono'] != null) perfil['telefono'], if (p['zona_habitual'] != null) p['zona_habitual']].join(' · '),
                style: tt.bodySmall),
          ])),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final o in oficios) ChipEstado(nombreCategoria(o)),
          if (oficios.isEmpty) Text('Sin oficios registrados', style: tt.bodySmall),
        ]),
        const SizedBox(height: 10),
        if (docs.length < 3) const Padding(padding: EdgeInsets.only(bottom: 8),
            child: Aviso(TipoAviso.advertencia, 'Faltan documentos', texto: 'Este técnico no ha subido su foto o su cédula completa.')),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (titulo, ruta) in docs)
            OutlinedButton.icon(style: estiloFantasma, onPressed: () => verDocumento(context, titulo, ruta),
                icon: const Icon(Icons.image_outlined, size: 18), label: Text(titulo)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: BotonAsync(estilo: estiloSecundario, hijo: const Text('Aprobar'),
              accion: () => _accion(context, () => AdminRepository().aprobar(p['id']), '$nombre quedó aprobado.', alTerminar))),
          const SizedBox(width: 10),
          Expanded(child: BotonAsync(contorno: true, estilo: estiloFantasma, hijo: const Text('Suspender'), accion: () async {
            final ok = await confirmar(context, titulo: '¿Suspender a $nombre?', si: 'Sí, suspender', destructivo: true,
                mensaje: 'No podrá usar Chambapo hasta que reactives su cuenta.');
            if (ok && context.mounted) {
              await _accion(context, () => AdminRepository().suspender(p['id'], true), '$nombre quedó suspendido.', alTerminar);
            }
          })),
        ]),
      ]),
    ));
  }
}

// Ventana que muestra una foto o un documento del técnico
Future<void> verDocumento(BuildContext context, String titulo, String ruta) async {
  final String url;
  try {
    url = await AdminRepository().urlDocumento(ruta);
  } catch (e) {
    if (context.mounted) avisar(context, 'No se pudo abrir el documento: ${mensajeError(e)}');
    return;
  }
  if (!context.mounted) return;
  await showDialog<void>(context: context, builder: (ctx) => Dialog(
    insetPadding: const EdgeInsets.all(12),
    clipBehavior: Clip.antiAlias,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(title: Text(titulo), trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx))),
      Flexible(child: InteractiveViewer(maxScale: 5, child: Image.network(url, fit: BoxFit.contain,
        loadingBuilder: (_, hijo, progreso) => progreso == null ? hijo
            : const Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()),
        errorBuilder: (_, __, ___) => const Padding(padding: EdgeInsets.all(32),
            child: Text('No se pudo cargar la imagen.', textAlign: TextAlign.center)),
      ))),
      const SizedBox(height: 8),
    ]),
  ));
}

// Tarjeta de un reporte que el administrador debe atender
class _TarjetaReporte extends StatelessWidget {
  final Fila r;
  final Future<void> Function() alTerminar;
  const _TarjetaReporte(this.r, {required this.alTerminar});
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final reportado = r['reportado'] as Map?;
    final autor = r['autor'] as Map?;
    final solicitud = r['solicitud'] as Map?;
    final enRevision = solicitud?['en_revision'] == true && !const ['cancelada', 'finalizada'].contains(solicitud?['estado']);
    return Card(margin: const EdgeInsets.only(bottom: 10), child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (enRevision) const Padding(padding: EdgeInsets.only(bottom: 8),
            child: Align(alignment: Alignment.centerLeft, child: ChipEstado('Servicio en revisión', fondo: CP.advertenciaFondo, color: CP.advertencia))),
        Text('${reportado?['nombre'] ?? '?'} (${_rol(reportado?['rol'])})', style: tt.titleMedium),
        Text('Reportado por ${autor?['nombre'] ?? '?'} · ${_fecha(r['creado_en'])}', style: tt.bodySmall),
        const SizedBox(height: 8),
        Text('${r['motivo'] ?? ''}', style: tt.bodyMedium),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final p in [reportado, autor])
            if (p != null)
              p['suspendido'] == true
                  ? ChipEstado('${p['nombre']} vetado', fondo: CP.errorFondo, color: CP.error)
                  : BotonAsync(contorno: true, estilo: estiloFantasma, hijo: Text('Vetar ${_rol(p['rol'])}'), accion: () async {
                      final ok = await confirmar(context, titulo: '¿Vetar a ${p['nombre']}?', si: 'Sí, vetar', destructivo: true,
                          mensaje: 'No podrá volver a usar Chambapo hasta que se reactive su cuenta.');
                      if (ok && context.mounted) {
                        await _accion(context, () => AdminRepository().suspender(p['id'], true), '${p['nombre']} quedó vetado.', alTerminar);
                      }
                    }),
        ]),
        const SizedBox(height: 8),
        enRevision
            ? BotonAsync(estilo: estiloDestructivo, hijo: const Text('Cerrar revisión y cancelar el servicio'), accion: () async {
                final ok = await confirmar(context, titulo: '¿Cerrar la revisión?', si: 'Sí, cerrar', destructivo: true,
                    mensaje: 'El servicio quedará cancelado. Veta antes al técnico o al cliente si corresponde.');
                if (ok && context.mounted) {
                  await _accion(context, () => AdminRepository().cerrarRevision(r['id'], solicitud!['id']), 'Revisión cerrada.', alTerminar);
                }
              })
            : BotonAsync(estilo: estiloSecundario, hijo: const Text('Marcar como atendido'),
                accion: () => _accion(context, () => AdminRepository().atenderReporte(r['id']), 'Reporte atendido.', alTerminar)),
      ]),
    ));
  }
}

// Tarjeta de una cuenta suspendida que se puede reactivar
class _TarjetaVetado extends StatelessWidget {
  final Fila v;
  final List<Fila> reportes;
  final Future<void> Function() alTerminar;
  const _TarjetaVetado(this.v, {required this.reportes, required this.alTerminar});
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final nombre = '${v['nombre']}';
    final ultimo = reportes.isEmpty ? null : reportes.first;
    return Card(margin: const EdgeInsets.only(bottom: 10), child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          AvatarIniciales(nombre, color: CP.apagado, foto: v['foto_url'] as String?),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(nombre, style: tt.titleMedium),
            Text('${v['rol'] == 'prestador' ? 'Técnico' : 'Cliente'} · ${v['telefono'] ?? 'sin teléfono'}', style: tt.bodySmall),
          ])),
        ]),
        const SizedBox(height: 10),
        Text(reportes.isEmpty ? 'Sin reportes recibidos.'
            : '${reportes.length} ${reportes.length == 1 ? 'reporte' : 'reportes'} · último: ${ultimo!['motivo']} (${_fecha(ultimo['creado_en'])})',
            style: tt.bodyMedium),
        const SizedBox(height: 12),
        BotonAsync(contorno: true, estilo: estiloFantasma, hijo: const Text('Desvetar'), accion: () async {
          final ok = await confirmar(context, titulo: '¿Desvetar a $nombre?', si: 'Sí, desvetar',
              mensaje: 'Podrá volver a usar Chambapo de inmediato.');
          if (ok && context.mounted) {
            await _accion(context, () => AdminRepository().suspender(v['id'], false), '$nombre puede volver a usar la app.', alTerminar);
          }
        }),
      ]),
    ));
  }
}
