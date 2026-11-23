import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../auth/auth_provider.dart';
import '../solicitudes/lista_solicitudes_screen.dart';
import '../solicitudes/solicitud.dart';
import '../solicitudes/solicitudes_repository.dart';

final categoriasProvider = FutureProvider<List<Map<String, dynamic>>>((ref) => SolicitudesRepository().categorias());

// Pantalla de inicio del cliente: buscador, categorías y su solicitud activa
class InicioClienteTab extends ConsumerWidget {
  const InicioClienteTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final perfil = ref.watch(perfilProvider).value;
    final categorias = ref.watch(categoriasProvider);
    final mias = ref.watch(misSolicitudesProvider);
    final activas = (mias.value ?? const <Solicitud>[]).where((s) => s.activa || s.enServicio).toList();

    return Scaffold(
      backgroundColor: CP.fondoApp,
      body: SafeArea(child: RefreshIndicator(
        onRefresh: () => ref.refresh(misSolicitudesProvider.future),
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 24), children: [
          Text('Hola, ${perfil?.primerNombre ?? ''}', style: tt.bodySmall),
          const SizedBox(height: 4),
          Text('¿Qué necesitas arreglar hoy?', style: tt.headlineMedium),
          const SizedBox(height: 16),
          TextField(
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(hintText: 'Ej.: la lavadora no centrifuga', prefixIcon: Icon(Icons.search),
                fillColor: Colors.white),
            onSubmitted: (q) => context.push(Uri(path: '/nueva', queryParameters: q.trim().isEmpty ? null : {'q': q.trim()}).toString()),
          ),
          const EtiquetaSeccion('Categorías'),
          categorias.when(
            loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Aviso(TipoAviso.error, 'No pudimos cargar las categorías',
                accion: TextButton(onPressed: () => ref.invalidate(categoriasProvider), child: const Text('Reintentar'))),
            data: (cs) => GridView.count(
              crossAxisCount: 3, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.05,
              children: [for (final c in cs) _Categoria(c['nombre'] as String)],
            ),
          ),
          if (activas.isNotEmpty) ...[
            const EtiquetaSeccion('Tu solicitud activa'),
            for (final s in activas.take(2)) Padding(padding: const EdgeInsets.only(bottom: 10), child: TarjetaServicioActivo(s)),
          ] else if (mias.hasValue) ...[
            const SizedBox(height: 20),
            const Aviso(TipoAviso.informacion, 'Elige una categoría para empezar',
                texto: 'Describe el problema y te avisamos cuando los técnicos cercanos envíen sus ofertas.'),
          ],
        ]),
      )),
    );
  }
}

class _Categoria extends StatelessWidget {
  final String nombre;
  const _Categoria(this.nombre);
  @override
  Widget build(BuildContext context) {
    final (color, fondo) = colorCategoria(nombre);
    return Material(
      color: Colors.white, borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/nueva?categoria=$nombre'),
        child: Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(10)),
              child: Icon(iconoCategoria(nombre), color: color, size: 20)),
          const Spacer(),
          Text(nombreCategoria(nombre), maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: CP.tinta, height: 1.2)),
        ])),
      ),
    );
  }
}

// Tarjeta con el servicio que está en curso
class TarjetaServicioActivo extends StatelessWidget {
  final Solicitud s;
  final bool esTecnico;
  const TarjetaServicioActivo(this.s, {super.key, this.esTecnico = false});

  String get _linea {
    if (s.revisionPendiente) return 'Detenido: un administrador lo está revisando';
    if (esTecnico) {
      return '${s.clienteNombre ?? 'Cliente'} · ${switch (s.paso) {
        Paso.asignada => 'te eligió: avísale cuando salgas',
        Paso.enCamino => 'vas en camino',
        Paso.confirmarLlegada => 'esperando que confirme tu llegada',
        Paso.codigo => 'pídele el código para empezar',
        Paso.enCurso => 'trabajo en curso',
        Paso.confirmarFin => 'esperando que confirme el final',
        _ => nombreEstado(s.estado).toLowerCase(),
      }}';
    }
    if (s.activa) {
      return s.numPostulaciones == 0 ? 'Avisando a técnicos cercanos'
          : '${s.numPostulaciones} ${s.numPostulaciones == 1 ? 'prestador respondió' : 'prestadores respondieron'}';
    }
    return '${s.prestadorNombre ?? 'Tu prestador'} · ${switch (s.paso) {
      Paso.confirmarLlegada => 'dice que llegó: confírmalo',
      Paso.codigo => 'llegó: dale el código',
      Paso.confirmarFin => 'dice que terminó: confírmalo',
      _ => nombreEstado(s.estado).toLowerCase(),
    }}';
  }

  @override
  Widget build(BuildContext context) {
    final linea = _linea;
    final accion = esTecnico ? 'Ver trabajo'
        : (s.activa ? (s.numPostulaciones > 0 ? 'Comparar ofertas' : 'Ver solicitud') : 'Ver servicio');
    return Material(
      color: CP.tinta, borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/solicitud/${s.id}'),
        child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(s.descripcion, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15))),
            const SizedBox(width: 8),
            ChipEstado.deSolicitud(s.estado, sobreOscuro: true, enRevision: s.enRevision),
          ]),
          const SizedBox(height: 6),
          Text('$linea · ${hace(s.creadoEn)}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 10),
          Row(children: [
            Text(accion, style: const TextStyle(color: CP.naranjaSuave, fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward, color: CP.naranjaSuave, size: 16),
          ]),
        ])),
      ),
    );
  }
}
