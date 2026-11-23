import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/api_client.dart';
import '../../core/mapa_ampliable.dart';
import '../../core/selector_imagen.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../auth/auth_provider.dart';
import '../chat/conversaciones_tab.dart';
import '../ubicacion/location_service.dart';
import 'flujo_servicio.dart';
import 'lista_solicitudes_screen.dart';
import 'solicitud.dart';
import 'solicitudes_repository.dart';

typedef Detalle = ({Solicitud s, List<Postulacion> posts, bool yaCalifique});

final detalleProvider = FutureProvider.autoDispose.family<Detalle, String>((ref, id) async {
  final repo = SolicitudesRepository();
  final s = await repo.una(id);
  final perfil = await ref.read(perfilProvider.future);
  if (perfil?.esPrestador == true && s.activa && s.clienteId != supabase.auth.currentUser?.id) {
    repo.registrarVista(id);
  }
  final cerrado = ['cancelada', 'finalizada', 'expirada'].contains(s.estado);
  if (!kIsWeb && (s.revisionPendiente || cerrado) && s.prestadorId == supabase.auth.currentUser?.id) {
    LocationService.detener().catchError((_) {});
  }
  if (s.enServicio && !s.revisionPendiente) {
    final t = Timer(const Duration(seconds: 20), ref.invalidateSelf);
    ref.onDispose(t.cancel);
  }
  return (s: s, posts: await repo.postulaciones(id), yaCalifique: s.estado == 'finalizada' && await repo.yaCalifique(id));
});

final coordenadasProvider = FutureProvider.autoDispose.family<({double lat, double lng})?, String>(
    (ref, id) => SolicitudesRepository().coordenadas(id));

// Pantalla con el detalle de una solicitud
class DetalleSolicitudScreen extends ConsumerWidget {
  final String id;
  const DetalleSolicitudScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(perfilProvider).value;
    final uid = supabase.auth.currentUser!.id;
    final data = ref.watch(detalleProvider(id));

    void refrescar() {
      ref.invalidate(detalleProvider(id));
      ref.invalidate(misSolicitudesProvider);
      ref.invalidate(abiertasProvider);
      ref.invalidate(trabajosProvider);
      ref.invalidate(conversacionesProvider);
    }

    return data.when(
      loading: () => Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(appBar: AppBar(), body: ErrorPantalla(mensajeError(e), reintentar: refrescar)),
      data: (d) {
        final s = d.s;
        final soyCliente = s.clienteId == uid;
        final soyPrestador = perfil?.esPrestador == true;
        final soyAsignado = s.prestadorId == uid;

        if (soyCliente && s.activa && d.posts.isNotEmpty) {
          return _Ofertas(s: s, posts: d.posts, alElegir: refrescar);
        }
        return Scaffold(
          backgroundColor: CP.fondoApp,
          appBar: AppBar(backgroundColor: CP.fondoApp, title: Text(nombreCategoria(s.categoria))),
          body: RefreshIndicator(
            onRefresh: () async => refrescar(),
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 32), children: [
              _Resumen(s),
              const SizedBox(height: 12),
              if (soyCliente || soyPrestador) ...[_MapaServicio(s.id), const SizedBox(height: 12)],
              if (soyPrestador && !soyCliente && s.clienteId != null) ...[
                _TarjetaCliente(s), const SizedBox(height: 16)],
              if (s.revisionPendiente && (soyCliente || soyAsignado)) ...[
                const Aviso(TipoAviso.advertencia, 'Servicio en revisión',
                    texto: 'Este servicio quedó detenido. Un administrador revisará lo ocurrido, decidirá si toma medidas '
                        'con el técnico o con el cliente y lo cerrará. Mientras tanto no se puede avanzar.'),
                const SizedBox(height: 12),
                OutlinedButton.icon(style: estiloFantasma, onPressed: () => context.push('/chat/${s.id}'),
                    icon: const Icon(Icons.chat_bubble_outline, size: 18), label: const Text('Ir al chat')),
              ],
              if (soyCliente && s.activa) _Buscando(s: s, alCancelar: refrescar),
              if (soyPrestador && s.activa)
                if (d.posts.where((p) => p.prestadorId == uid).firstOrNull case final mia?)
                  _YaPostulado(mia)
                else
                  _FormPostular(onEnviar: (p, m) => SolicitudesRepository().postular(id, p, m), onEnviado: refrescar),
              if (s.enServicio && !s.revisionPendiente && (soyCliente || soyAsignado))
                _Seguimiento(s: s, soyCliente: soyCliente, alCambiar: refrescar),
              if (s.estado == 'finalizada' && soyAsignado && s.conInconvenientes) ...[
                const Aviso(TipoAviso.advertencia, 'Realizado, pero tuviste inconvenientes',
                    texto: 'Durante este servicio hubo rechazos del cliente, código bloqueado o una revisión.'),
                const SizedBox(height: 12),
              ],
              if (s.estado == 'finalizada' && (soyCliente || soyAsignado))
                if (d.yaCalifique)
                  const _Finalizada()
                else ...[
                  Felicitaciones(s: s, soyCliente: soyCliente),
                  const SizedBox(height: 16),
                  _Calificar(s: s, soyCliente: soyCliente, alEnviar: refrescar),
                ],
              if (s.estado == 'cancelada' || s.estado == 'expirada')
                Aviso(TipoAviso.advertencia, s.estado == 'cancelada' ? 'Esta solicitud fue cancelada' : 'Esta solicitud expiró',
                    texto: _textoCierre(s, uid, soyCliente)),
            ]),
          ),
        );
      },
    );
  }
}

class _Resumen extends StatelessWidget {
  final Solicitud s;
  const _Resumen(this.s);
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final (color, fondo) = colorCategoria(s.categoria);
    final cuando = s.fechaDeseada == null ? 'Lo antes posible'
        : 'Para el ${s.fechaDeseada!.toLocal().day}/${s.fechaDeseada!.toLocal().month} · ${horaCorta(s.fechaDeseada!)}';
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(12)),
            child: Icon(iconoCategoria(s.categoria), color: color, size: 22)),
        const SizedBox(width: 10),
        Expanded(child: Text(nombreCategoria(s.categoria), style: tt.titleMedium)),
        ChipEstado.deSolicitud(s.estado, enRevision: s.enRevision),
      ]),
      const SizedBox(height: 12),
      Text(s.descripcion, style: tt.bodyLarge),
      if (s.fotos.isNotEmpty) ...[
        const SizedBox(height: 12),
        SizedBox(height: 76, child: ListView.separated(
          scrollDirection: Axis.horizontal, itemCount: s.fotos.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) => Semantics(button: true, label: 'Ver foto ${i + 1}', child: GestureDetector(
            onTap: () => _verFoto(context, s.fotos, i),
            child: ClipRRect(borderRadius: BorderRadius.circular(12),
                child: SizedBox(width: 76, height: 76, child: VistaImagen(url: s.fotos[i]))),
          )),
        )),
      ],
      if (s.tieneMateriales != null) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: CP.fondoApp, borderRadius: BorderRadius.circular(14)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(s.tieneMateriales! ? Icons.inventory_2_outlined : Icons.shopping_bag_outlined, size: 20, color: CP.verde),
            const SizedBox(width: 10),
            Expanded(child: Text.rich(TextSpan(style: tt.bodyMedium, children: [
              TextSpan(text: s.tieneMateriales! ? 'El cliente tiene los materiales: ' : 'El técnico debe llevar: ',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: CP.tinta)),
              TextSpan(text: s.materiales ?? ''),
            ]))),
          ]),
        ),
      ],
      const SizedBox(height: 12),
      Wrap(spacing: 14, runSpacing: 6, children: [
        if (s.barrio != null) _Dato(Icons.location_on_outlined, s.barrio!),
        _Dato(Icons.schedule, cuando),
        if (s.presupuesto != null) _Dato(Icons.payments_outlined, 'Presupuesto ${pesos(s.presupuesto)}'),
        if (s.precioAcordado != null) _Dato(Icons.handshake_outlined, 'Acordado ${pesos(s.precioAcordado)}'),
      ]),
    ])));
  }
}

void _verFoto(BuildContext context, List<String> fotos, int inicial) => showDialog(context: context, builder: (ctx) => Dialog.fullscreen(
  backgroundColor: Colors.black,
  child: Stack(children: [
    PageView(controller: PageController(initialPage: inicial), children: [
      for (final f in fotos) InteractiveViewer(child: Center(child: VistaImagen(url: f, fit: BoxFit.contain))),
    ]),
    SafeArea(child: Align(alignment: Alignment.topRight, child: IconButton(tooltip: 'Cerrar',
        onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close, color: Colors.white)))),
  ]),
));

String? _textoCierre(Solicitud s, String uid, bool soyCliente) {
  final partes = [
    if (s.estado == 'cancelada' && s.canceladaPor != null)
      s.canceladaPor == uid ? 'La cancelaste tú.' : (soyCliente ? 'La canceló el técnico.' : 'La canceló el cliente.'),
    if (s.motivoCancelacion != null) 'Motivo: ${s.motivoCancelacion}',
    if (soyCliente) 'Puedes publicar una nueva desde Inicio.',
  ];
  return partes.isEmpty ? null : partes.join(' ');
}

class _MapaServicio extends ConsumerWidget {
  final String id;
  const _MapaServicio(this.id);
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref.watch(coordenadasProvider(id)).maybeWhen(
    data: (c) => c == null ? const SizedBox.shrink() : MapaAmpliable(
      centro: LatLng(c.lat, c.lng), zoom: 15, alto: 170,
      capas: () => [MarkerLayer(markers: [Marker(point: LatLng(c.lat, c.lng), width: 40, height: 40,
          alignment: Alignment.topCenter, child: const Icon(Icons.location_on, color: CP.naranja, size: 40))])],
    ),
    orElse: () => const SizedBox.shrink(),
  );
}

class _TarjetaCliente extends StatelessWidget {
  final Solicitud s;
  const _TarjetaCliente(this.s);
  @override
  Widget build(BuildContext context) => Card(child: ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    leading: AvatarIniciales(s.clienteNombre ?? 'Cliente', tam: 40, color: CP.naranja, foto: s.clienteFoto),
    title: Text(s.clienteNombre ?? 'Cliente', style: Theme.of(context).textTheme.titleSmall),
    subtitle: const Text('Ver perfil y reseñas del cliente'),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => context.push('/solicitud/${s.id}/cliente/${s.clienteId}'),
  ));
}

class _Dato extends StatelessWidget {
  final IconData icono;
  final String texto;
  const _Dato(this.icono, this.texto);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icono, size: 16, color: CP.apagado), const SizedBox(width: 4),
    Text(texto, style: Theme.of(context).textTheme.bodySmall),
  ]);
}

// Mientras se buscan técnicos
class _Buscando extends StatelessWidget {
  final Solicitud s;
  final VoidCallback alCancelar;
  const _Buscando({required this.s, required this.alCancelar});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
      const SizedBox(height: 100, width: 100, child: CustomPaint(painter: _Radar())),
      const SizedBox(height: 12),
      Text('Buscando prestadores cerca', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
      const SizedBox(height: 6),
      Text('Avisamos a los técnicos de tu zona. Cuando envíen sus ofertas las verás aquí para comparar.',
          textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
    ]))),
    const SizedBox(height: 16),
    OutlinedButton(style: estiloFantasma, onPressed: () async {
      final motivo = await pedirCancelacion(context, titulo: '¿Cancelar la búsqueda?', no: 'Seguir buscando',
          mensaje: 'Dejaremos de avisar a los técnicos y la solicitud se cerrará.');
      if (motivo == null || !context.mounted) return;
      try {
        await SolicitudesRepository().cambiarEstado(s.id, 'cancelada', motivo: motivo);
        alCancelar();
      } catch (e) {
        if (context.mounted) avisar(context, mensajeError(e));
      }
    }, child: const Text('Cancelar solicitud')),
  ]);
}

class _Radar extends CustomPainter {
  const _Radar();
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    canvas.drawCircle(c, size.width / 2, Paint()..color = CP.seleccion);
    canvas.drawCircle(c, size.width / 3, Paint()..style = PaintingStyle.stroke..color = CP.verde.withValues(alpha: 0.5)..strokeWidth = 1.5);
    canvas.drawCircle(c, size.width / 2 - 1, Paint()..style = PaintingStyle.stroke..color = CP.naranja.withValues(alpha: 0.5)..strokeWidth = 1.5);
    canvas.drawCircle(c, 7, Paint()..color = CP.naranja);
    for (final o in [const Offset(-30, -18), const Offset(26, -30), const Offset(32, 22), const Offset(-20, 34)]) {
      canvas.drawCircle(c + o, 3.5, Paint()..color = CP.tinta);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Ofertas de los técnicos para que el cliente elija
class _Ofertas extends StatefulWidget {
  final Solicitud s;
  final List<Postulacion> posts;
  final VoidCallback alElegir;
  const _Ofertas({required this.s, required this.posts, required this.alElegir});
  @override
  State<_Ofertas> createState() => _OfertasState();
}

class _OfertasState extends State<_Ofertas> {
  String _orden = 'recomendadas';
  late String _seleccion = _ordenadas.first.id;
  bool _eligiendo = false;

  List<Postulacion> get _ordenadas {
    final l = [...widget.posts];
    switch (_orden) {
      case 'precio': l.sort((a, b) => a.precio.compareTo(b.precio));
      case 'llegada': l.sort((a, b) => a.minutosLlegada.compareTo(b.minutosLlegada));
      default: l.sort((a, b) => b.calificacion != a.calificacion ? b.calificacion.compareTo(a.calificacion) : a.precio.compareTo(b.precio));
    }
    return l;
  }

  Postulacion get _elegida => widget.posts.firstWhere((p) => p.id == _seleccion);

  Future<void> _elegir() async {
    final p = _elegida;
    setState(() => _eligiendo = true);
    try {
      await SolicitudesRepository().elegir(widget.s.id, p.id);
      if (mounted) avisar(context, 'Elegiste a ${p.nombre}. Ya puedes escribirle por el chat.');
      widget.alElegir();
    } catch (e) {
      if (!mounted) return;
      avisar(context, mensajeError(e));
      if (e is ApiException && e.codigo != null && e.codigo! < 500) widget.alElegir();
    } finally {
      if (mounted) setState(() => _eligiendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final n = widget.posts.length;
    final colores = [CP.verde, const Color(0xFF5B3E8A), const Color(0xFFA33A12), const Color(0xFF1D5E7A)];
    return Scaffold(
      appBar: AppBar(titleSpacing: 0, title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(n == 1 ? '1 oferta recibida' : '$n ofertas recibidas'),
        Text(widget.s.descripcion, maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.bodySmall),
      ])),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 20), children: [
        Wrap(spacing: 8, children: [
          for (final (v, t) in [('recomendadas', 'Recomendadas'), ('precio', 'Menor precio'), ('llegada', 'Llega antes')])
            ChoiceChip(label: Text(t), selected: _orden == v, labelStyle: estiloChip(_orden == v), onSelected: (_) => setState(() => _orden = v)),
        ]),
        const SizedBox(height: 14),
        for (final (i, p) in _ordenadas.indexed) Padding(padding: const EdgeInsets.only(bottom: 12), child: _TarjetaOferta(
          p: p, color: colores[i % colores.length], seleccionada: p.id == _seleccion,
          onTap: _eligiendo ? null : () => setState(() => _seleccion = p.id),
        )),
      ]),
      bottomNavigationBar: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 12), child: Row(children: [
        Expanded(flex: 2, child: OutlinedButton(style: estiloFantasma,
            onPressed: _eligiendo ? null : () => context.push('/solicitud/${widget.s.id}/prestador/${_elegida.prestadorId}'),
            child: const Text('Ver perfil'))),
        const SizedBox(width: 10),
        Expanded(flex: 3, child: FilledButton(onPressed: _eligiendo ? null : _elegir,
            child: _eligiendo ? cargandoBoton : Text('Elegir a ${_elegida.nombre.split(' ').first}', overflow: TextOverflow.ellipsis))),
      ]))),
    );
  }
}

class _TarjetaOferta extends StatelessWidget {
  final Postulacion p;
  final Color color;
  final bool seleccionada;
  final VoidCallback? onTap;
  const _TarjetaOferta({required this.p, required this.color, required this.seleccionada, this.onTap});
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Semantics(selected: seleccionada, button: true, child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: seleccionada ? CP.verde : CP.borde, width: seleccionada ? 2 : 1)),
      child: InkWell(borderRadius: BorderRadius.circular(20), onTap: onTap, child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            AvatarIniciales(p.nombre, tam: 42, color: color, foto: p.foto),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.nombre, style: tt.titleSmall),
              Row(children: [
                const Icon(Icons.star_rounded, size: 16, color: CP.naranjaLogo),
                Text(' ${p.calificacion == 0 ? 'Nuevo' : p.calificacion.toStringAsFixed(1).replaceAll('.', ',')} · ${p.servicios} servicios',
                    style: tt.bodySmall),
              ]),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(pesos(p.precio), style: estiloTitulo.copyWith(fontSize: 18)),
              Text('precio estimado', style: tt.bodySmall),
            ]),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            ChipEstado('Llega en ${p.minutosLlegada} min', fondo: CP.fondoApp, color: CP.tinta),
            const Spacer(),
            if (seleccionada) const ChipEstado('Seleccionada'),
          ]),
        ]),
      )),
    ));
  }
}

// Formulario para que el técnico envíe su oferta
class _YaPostulado extends StatelessWidget {
  final Postulacion p;
  const _YaPostulado(this.p);
  @override
  Widget build(BuildContext context) => Aviso(TipoAviso.informacion, 'Ya enviaste tu oferta',
      texto: 'Propusiste ${pesos(p.precio)} y llegar en ${p.minutosLlegada} min. Te avisaremos si el cliente te elige.');
}

class _FormPostular extends StatefulWidget {
  final Future<void> Function(int precio, int minutos) onEnviar;
  final VoidCallback onEnviado;
  const _FormPostular({required this.onEnviar, required this.onEnviado});
  @override
  State<_FormPostular> createState() => _FormPostularState();
}

class _FormPostularState extends State<_FormPostular> {
  final _form = GlobalKey<FormState>();
  final _precio = TextEditingController(), _min = TextEditingController(text: '30');
  bool _enviando = false;

  String? _validarEntero(String? v) {
    final n = int.tryParse((v ?? '').replaceAll(RegExp(r'[\s.$]'), ''));
    return (n == null || n <= 0) ? 'Escribe un número mayor que 0' : null;
  }

  int _numero(TextEditingController c) => int.parse(c.text.replaceAll(RegExp(r'[\s.$]'), ''));

  Future<void> _enviar() async {
    if (_enviando || !_form.currentState!.validate()) return;
    setState(() => _enviando = true);
    final avisos = ScaffoldMessenger.of(context);
    try {
      await widget.onEnviar(_numero(_precio), _numero(_min));
      avisos.showSnackBar(const SnackBar(content: Text('Oferta enviada')));
      if (mounted) widget.onEnviado();
    } on ApiException catch (e) {
      avisos.showSnackBar(SnackBar(content: Text(mensajeError(e))));
      if (e.codigo == 409 && mounted) widget.onEnviado();
    } catch (e) {
      avisos.showSnackBar(SnackBar(content: Text(mensajeError(e))));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  void dispose() { _precio.dispose(); _min.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Form(key: _form,
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Envía tu oferta', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 12),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: TextFormField(controller: _precio, enabled: !_enviando, keyboardType: TextInputType.number,
            validator: _validarEntero, decoration: const InputDecoration(labelText: 'Tu precio', prefixText: '\$ '))),
        const SizedBox(width: 10),
        Expanded(child: TextFormField(controller: _min, enabled: !_enviando, keyboardType: TextInputType.number,
            validator: _validarEntero, decoration: const InputDecoration(labelText: 'Llego en', suffixText: 'min'))),
      ]),
      const SizedBox(height: 14),
      FilledButton(onPressed: _enviando ? null : _enviar, child: _enviando ? cargandoBoton : const Text('Enviar oferta')),
      const SizedBox(height: 8),
      Text('Tu ubicación solo se comparte con el cliente cuando te asigne el servicio.',
          style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
    ]),
  )));
}

// Seguimiento del servicio
class _Seguimiento extends StatelessWidget {
  final Solicitud s;
  final bool soyCliente;
  final VoidCallback alCambiar;
  const _Seguimiento({required this.s, required this.soyCliente, required this.alCambiar});

  Future<void> _cambiar(BuildContext context, String estado, {String? motivo}) async {
    final repo = SolicitudesRepository();
    await repo.cambiarEstado(s.id, estado, motivo: motivo);
    if (!kIsWeb) {
      try {
        if (estado == 'en_camino') await LocationService.iniciar(s.id);
        if (estado != 'en_camino') await LocationService.detener();
      } catch (e) {
        if (context.mounted) avisar(context, mensajeError(e));
      }
    }
    alCambiar();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final otro = soyCliente ? (s.prestadorNombre ?? 'Tu prestador') : (s.clienteNombre ?? 'El cliente');
    final paso = s.paso;
    final titulo = switch (paso) {
      Paso.asignada => soyCliente ? '$otro aceptó tu servicio' : 'Te eligieron para este servicio',
      Paso.enCamino => soyCliente ? '$otro va en camino' : 'Vas en camino',
      Paso.confirmarLlegada => soyCliente ? '$otro dice que llegó' : 'Avisaste que llegaste',
      Paso.codigo => soyCliente ? '$otro llegó' : 'Llegaste al servicio',
      Paso.enCurso => soyCliente ? '$otro está trabajando' : 'Trabajo en curso',
      Paso.confirmarFin => soyCliente ? '$otro dice que terminó' : 'Avisaste que terminaste',
      _ => nombreEstado(s.estado),
    };
    final siRevisionLlegada = s.rechazosLlegada >= maxRechazos, siRevisionFin = s.rechazosFin >= maxRechazos;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (soyCliente) ...switch (paso) {
        Paso.confirmarLlegada => [TarjetaPregunta(
          icono: Icons.notifications_active_outlined, titulo: 'Tu técnico llegó',
          texto: '$otro indica que ya está en el lugar del servicio. ¿Confirmas que llegó?',
          si: 'Sí, llegó', no: siRevisionLlegada ? 'No, pedir revisión' : 'No ha llegado', noEsRevision: siRevisionLlegada,
          alSi: () async { if (await responderLlegada(context, s, si: true)) alCambiar(); },
          alNo: () async { if (await responderLlegada(context, s, si: false)) alCambiar(); },
        ), const SizedBox(height: 16)],
        Paso.codigo => [TarjetaCodigo(s), const SizedBox(height: 16)],
        Paso.confirmarFin => [TarjetaPregunta(
          icono: Icons.task_alt, titulo: '¿El técnico terminó el trabajo?',
          texto: '$otro indica que terminó. Revisa el trabajo y confírmalo.',
          si: 'Sí, terminó', no: siRevisionFin ? 'No, pedir revisión' : 'Todavía no', noEsRevision: siRevisionFin,
          alSi: () async { if (await responderFin(context, s, si: true)) alCambiar(); },
          alNo: () async { if (await responderFin(context, s, si: false)) alCambiar(); },
        ), const SizedBox(height: 16)],
        _ => const <Widget>[],
      } else ...switch (paso) {
        Paso.codigo => [FormCodigo(s: s, alIniciar: alCambiar), const SizedBox(height: 16)],
        Paso.confirmarLlegada => [const _Esperando('Esperando que el cliente confirme tu llegada…'), const SizedBox(height: 16)],
        Paso.confirmarFin => [const _Esperando('En espera de confirmación: el cliente debe confirmar que terminaste.'), const SizedBox(height: 16)],
        _ => const <Widget>[],
      },
      if (!soyCliente && paso == Paso.enCamino && s.rechazosLlegada > 0) ...[
        Aviso(TipoAviso.advertencia, 'El cliente indicó que aún no habías llegado',
            texto: 'Rechazos: ${s.rechazosLlegada} de $maxRechazos. Pulsa «Llegué» cuando estés en el lugar.'),
        const SizedBox(height: 12),
      ],
      if (!soyCliente && paso == Paso.enCurso && s.rechazosFin > 0) ...[
        Aviso(TipoAviso.advertencia, 'El cliente indicó que el trabajo no estaba terminado',
            texto: 'Rechazos: ${s.rechazosFin} de $maxRechazos. Habla con el cliente y avisa cuando termines.'),
        const SizedBox(height: 12),
      ],

      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(titulo, style: tt.headlineSmall),
        const SizedBox(height: 12),
        _Pasos(paso),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: CP.fondoApp, borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            AvatarIniciales(otro, tam: 40, foto: soyCliente ? s.prestadorFoto : s.clienteFoto),
            const SizedBox(width: 10),
            Expanded(child: InkWell(
              onTap: () => context.push(soyCliente
                  ? '/solicitud/${s.id}/prestador/${s.prestadorId}' : '/solicitud/${s.id}/cliente/${s.clienteId}'),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(otro, style: tt.titleSmall),
                Text('${soyCliente ? nombreCategoria(s.categoria) : (s.barrio ?? 'Cliente')} · ver perfil', style: tt.bodySmall),
              ]),
            )),
            if (s.precioAcordado != null) Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(pesos(s.precioAcordado), style: estiloTitulo.copyWith(fontSize: 17)),
              Text('pago directo', style: tt.bodySmall),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          _BotonCuadro(Icons.chat_bubble_outline, 'Chat', () => context.push('/chat/${s.id}'), solicitudChat: s.id),
          const SizedBox(width: 8),
          _BotonCuadro(Icons.map_outlined, soyCliente ? 'Mapa' : 'Ruta', () => context.push('/seguimiento/${s.id}')),
          const SizedBox(width: 8),
          _BotonCuadro(Icons.flag_outlined, 'Reportar', () => context.push('/solicitud/${s.id}/reportar'), color: CP.error),
        ]),
      ]))),
      const SizedBox(height: 16),
      if (!soyCliente && paso == Paso.asignada)
        BotonAsync(estilo: estiloOscuro, accion: () => _cambiar(context, 'en_camino'), hijo: const Text('Voy en camino')),
      if (!soyCliente && paso == Paso.enCamino)
        BotonAsync(estilo: estiloOscuro, icono: const Icon(Icons.where_to_vote_outlined),
            accion: () async { await SolicitudesRepository().llegue(s.id); alCambiar(); }, hijo: const Text('Llegué')),
      if (!soyCliente && paso == Paso.enCurso)
        BotonAsync(icono: const Icon(Icons.task_alt),
            accion: () async { await SolicitudesRepository().termine(s.id); alCambiar(); },
            hijo: const Text('Trabajo finalizado')),
      if (soyCliente && (paso == Paso.asignada || paso == Paso.enCamino))
        Text('Cuando $otro llegue te pediremos que lo confirmes.', textAlign: TextAlign.center, style: tt.bodySmall),
      if (soyCliente && paso == Paso.enCurso)
        Text('Cuando $otro termine te pediremos que lo confirmes.', textAlign: TextAlign.center, style: tt.bodySmall),
      const SizedBox(height: 8),
      TextButton(
        style: TextButton.styleFrom(foregroundColor: CP.error),
        onPressed: () async {
          final motivo = await pedirCancelacion(context, titulo: '¿Cancelar el servicio?', no: 'Seguir con el servicio',
              mensaje: soyCliente ? 'Le avisaremos a $otro que ya no necesitas el servicio.' : 'Le avisaremos al cliente que no podrás atenderlo.');
          if (motivo == null || !context.mounted) return;
          try { await _cambiar(context, 'cancelada', motivo: motivo); } catch (e) { if (context.mounted) avisar(context, mensajeError(e)); }
        },
        child: const Text('Cancelar servicio'),
      ),
    ]);
  }
}

class _Pasos extends StatelessWidget {
  final Paso paso;
  const _Pasos(this.paso);
  static const _etiquetas = ['Asignada', 'En camino', 'Llegó', 'En curso', 'Finalizada'];
  @override
  Widget build(BuildContext context) {
    final actual = switch (paso) {
      Paso.asignada => 0,
      Paso.enCamino || Paso.confirmarLlegada => 1,
      Paso.codigo => 2,
      Paso.enCurso || Paso.confirmarFin => 3,
      _ => 4,
    };
    return Row(children: [
      for (final (i, e) in _etiquetas.indexed) Expanded(child: Padding(
        padding: EdgeInsets.only(right: i < _etiquetas.length - 1 ? 5 : 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(height: 4, decoration: BoxDecoration(color: i <= actual ? CP.verde : CP.borde, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 6),
          Text(e, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11,
              fontWeight: i == actual ? FontWeight.w700 : FontWeight.w500, color: i == actual ? CP.verde : CP.apagado)),
        ]),
      )),
    ]);
  }
}

class _Esperando extends StatelessWidget {
  final String texto;
  const _Esperando(this.texto);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: CP.advertenciaFondo, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CP.advertencia.withValues(alpha: 0.35))),
    child: Row(children: [
      const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: CP.advertencia)),
      const SizedBox(width: 12),
      Expanded(child: Text(texto, style: const TextStyle(color: CP.advertencia, fontWeight: FontWeight.w700, fontSize: 14))),
    ]),
  );
}

class _BotonCuadro extends StatelessWidget {
  final IconData icono;
  final String texto;
  final VoidCallback onTap;
  final Color color;
  final String? solicitudChat;
  const _BotonCuadro(this.icono, this.texto, this.onTap, {this.color = CP.verde, this.solicitudChat});
  @override
  Widget build(BuildContext context) => Expanded(child: Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: CP.borde)),
    child: InkWell(borderRadius: BorderRadius.circular(14), onTap: onTap, child: SizedBox(height: 60, child: Column(
      mainAxisAlignment: MainAxisAlignment.center, children: [
        if (solicitudChat == null) Icon(icono, color: color, size: 20)
        else Consumer(builder: (_, ref, __) => InsigniaMensajes(
            n: ref.watch(noLeidosProvider).value?[solicitudChat] ?? 0, child: Icon(icono, color: color, size: 20))),
        const SizedBox(height: 4),
        Text(texto, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: CP.tinta)),
      ]))),
  ));
}

// Calificación del servicio

class _Finalizada extends StatelessWidget {
  const _Finalizada();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: CP.seleccion, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CP.exito.withValues(alpha: 0.4))),
    child: const Row(children: [
      Icon(Icons.check_circle, color: CP.exito, size: 26),
      SizedBox(width: 12),
      Expanded(child: Text('Esta solicitud ha sido finalizada exitosamente.',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: CP.verde))),
    ]),
  );
}
class _Calificar extends StatefulWidget {
  final Solicitud s;
  final bool soyCliente;
  final VoidCallback alEnviar;
  const _Calificar({required this.s, required this.soyCliente, required this.alEnviar});
  @override
  State<_Calificar> createState() => _CalificarState();
}

class _CalificarState extends State<_Calificar> {
  int _puntaje = 5;
  final _resena = TextEditingController();
  static const _textos = ['Muy malo', 'Malo', 'Regular', 'Bueno', 'Excelente'];

  @override
  void dispose() { _resena.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final s = widget.s;
    final otro = widget.soyCliente ? (s.prestadorNombre ?? 'el prestador') : (s.clienteNombre ?? 'el cliente');
    final receptor = widget.soyCliente ? s.prestadorId! : s.clienteId!;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('¿Cómo te fue con $otro?', textAlign: TextAlign.center, style: tt.titleMedium),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) => IconButton(
          tooltip: '${i + 1} de 5',
          iconSize: 36, onPressed: () => setState(() => _puntaje = i + 1),
          icon: Icon(i < _puntaje ? Icons.star_rounded : Icons.star_outline_rounded, color: CP.naranjaLogo),
        ))),
        Text(_textos[_puntaje - 1], textAlign: TextAlign.center, style: tt.bodySmall),
        const SizedBox(height: 14),
        TextField(controller: _resena, maxLines: 3, minLines: 2,
            decoration: const InputDecoration(labelText: 'Reseña (opcional)', hintText: 'Cuéntale a otros cómo fue el servicio')),
        const SizedBox(height: 14),
        BotonAsync(
          accion: () async {
            await SolicitudesRepository().calificar(s.id, receptor, _puntaje, _resena.text);
            if (context.mounted) await mostrarGracias(context, s, widget.soyCliente);
            widget.alEnviar();
          },
          hijo: const Text('Enviar calificación'),
        ),
        TextButton(style: TextButton.styleFrom(foregroundColor: CP.error),
            onPressed: () => context.push('/solicitud/${s.id}/reportar'), child: const Text('Reportar un problema')),
      ]))),
    ]);
  }
}
