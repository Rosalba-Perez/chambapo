import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/selector_imagen.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../auth/auth_provider.dart';
import '../inicio/inicio_cliente_tab.dart' show TarjetaServicioActivo;
import '../solicitudes/lista_solicitudes_screen.dart';
import '../solicitudes/solicitud.dart';

// Panel del técnico: disponibilidad, resumen y solicitudes cercanas
class PanelPrestadorTab extends ConsumerWidget {
  const PanelPrestadorTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(perfilProvider).value;
    final abiertas = ref.watch(abiertasProvider);
    final enCurso = (ref.watch(trabajosProvider).value ?? const <Solicitud>[]).where((s) => s.enServicio).toList();
    if (p == null) return const SizedBox.shrink();
    return Scaffold(
      backgroundColor: CP.tinta,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(perfilProvider);
          ref.invalidate(abiertasProvider);
          ref.invalidate(trabajosProvider);
          await ref.read(abiertasProvider.future);
        },
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(child: SafeArea(bottom: false, child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Hola, ${p.primerNombre}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
              _Disponibilidad(inicial: p.disponible),
              const SizedBox(height: 16),
              Row(children: [
                _Metrica(p.calificacion == 0 ? '—' : p.calificacion.toStringAsFixed(1).replaceAll('.', ','), 'calificación'),
                const SizedBox(width: 8),
                _Metrica('${p.servicios}', 'servicios'),
                const SizedBox(width: 8),
                _Metrica(p.verificado ? 'Sí' : 'No', 'verificado', resaltar: !p.verificado),
              ]),
            ]),
          ))),
          SliverFillRemaining(hasScrollBody: false, child: Container(
            decoration: const BoxDecoration(color: CP.fondoApp, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (enCurso.isNotEmpty) ...[
                EtiquetaSeccion(enCurso.length == 1 ? 'Tu trabajo en curso' : 'Tus trabajos en curso'),
                for (final s in enCurso) Padding(padding: const EdgeInsets.only(bottom: 10),
                    child: TarjetaServicioActivo(s, esTecnico: true)),
              ],
              const EtiquetaSeccion('Solicitudes cerca'),
              if (!p.verificado)
                const Aviso(TipoAviso.advertencia, 'Tu perfil está en revisión',
                    texto: 'Cuando un administrador verifique tu identidad podrás ver solicitudes y enviar ofertas.')
              else abiertas.when(
                loading: () => const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
                error: (e, _) => Aviso(TipoAviso.error, mensajeError(e),
                    accion: TextButton(onPressed: () => ref.invalidate(abiertasProvider), child: const Text('Reintentar'))),
                data: (items) => items.isEmpty
                    ? const Vacio(Icons.notifications_none, 'No hay solicitudes abiertas ahora',
                        'Mantente disponible: te avisaremos cuando un cliente cerca de ti pida un servicio.')
                    : Column(children: [for (final s in items) Padding(padding: const EdgeInsets.only(bottom: 12), child: _NuevaSolicitud(s))]),
              ),
            ]),
          )),
        ]),
      ),
    );
  }
}

class _Metrica extends StatelessWidget {
  final String valor, etiqueta;
  final bool resaltar;
  const _Metrica(this.valor, this.etiqueta, {this.resaltar = false});
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(valor, style: estiloTitulo.copyWith(color: resaltar ? CP.naranjaSuave : Colors.white, fontSize: 20)),
      const SizedBox(height: 2),
      Text(etiqueta, style: const TextStyle(color: Colors.white60, fontSize: 11)),
    ]),
  ));
}

class _Disponibilidad extends ConsumerStatefulWidget {
  final bool inicial;
  const _Disponibilidad({required this.inicial});
  @override
  ConsumerState<_Disponibilidad> createState() => _DisponibilidadState();
}

class _DisponibilidadState extends ConsumerState<_Disponibilidad> {
  late bool _disponible = widget.inicial;
  bool _cambiando = false;

  Future<void> _cambiar(bool v) async {
    setState(() => _cambiando = true);
    try {
      final datos = <String, dynamic>{'disponible': v};
      if (v) {
        var permiso = await Geolocator.checkPermission();
        if (permiso == LocationPermission.denied) permiso = await Geolocator.requestPermission();
        if (permiso == LocationPermission.denied || permiso == LocationPermission.deniedForever) {
          throw const ErrorConMensaje('Necesitamos tu ubicación para mostrarte solicitudes cercanas. Actívala en los ajustes.');
        }
        final pos = await Geolocator.getCurrentPosition();
        datos['ubicacion'] = 'POINT(${pos.longitude} ${pos.latitude})';
        datos['ubicacion_en'] = DateTime.now().toIso8601String();
      }
      await supabase.from('prestadores').update(datos).eq('id', supabase.auth.currentUser!.id);
      setState(() => _disponible = v);
    } catch (e) {
      if (mounted) avisar(context, mensajeError(e));
    } finally {
      if (mounted) setState(() => _cambiando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Expanded(child: Text(_disponible ? 'Estás disponible' : 'No estás disponible',
          style: estiloTitulo.copyWith(color: Colors.white, fontSize: 24))),
      _cambiando
          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
          : Switch(value: _disponible, onChanged: _cambiar),
    ]),
    const SizedBox(height: 4),
    Text(_disponible ? 'Recibes solicitudes de clientes cerca de tu ubicación.' : 'Actívalo para recibir solicitudes cercanas.',
        style: const TextStyle(color: Colors.white60, fontSize: 13)),
  ]);
}

class _NuevaSolicitud extends StatelessWidget {
  final Solicitud s;
  const _NuevaSolicitud(this.s);
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final meta = [if (s.barrio != null) s.barrio!, if (s.clienteNombre != null) 'cliente ${s.clienteNombre}', hace(s.creadoEn)].join(' · ');
    return Card(child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => context.push('/solicitud/${s.id}'),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(nombreCategoria(s.categoria), style: tt.titleSmall)),
          if (s.urgente) const ChipEstado('Urgente'),
        ]),
        const SizedBox(height: 2),
        Text(meta, style: tt.bodySmall),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(s.descripcion, maxLines: 3, overflow: TextOverflow.ellipsis, style: tt.bodyMedium)),
          if (s.fotos.isNotEmpty) ...[
            const SizedBox(width: 10),
            ClipRRect(borderRadius: BorderRadius.circular(10),
                child: SizedBox(width: 56, height: 56, child: VistaImagen(url: s.fotos.first))),
          ],
        ]),
        if (s.tieneMateriales != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(
            s.tieneMateriales! ? 'El cliente tiene los materiales' : 'Debes llevar materiales',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: s.tieneMateriales! ? CP.exito : CP.advertencia))),
        const SizedBox(height: 12),
        Row(children: [
          if (s.presupuesto != null) Expanded(child: Text('Presupuesto ${pesos(s.presupuesto)}',
              style: const TextStyle(fontWeight: FontWeight.w700, color: CP.tinta))) else const Spacer(),
          const Text('Ver y ofertar', style: TextStyle(color: CP.naranja, fontWeight: FontWeight.w700)),
          const Icon(Icons.arrow_forward, color: CP.naranja, size: 18),
        ]),
      ])),
    ));
  }
}
