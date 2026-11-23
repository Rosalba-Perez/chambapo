import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgresChangeEvent, RealtimeChannel;
import '../../core/router.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../chat/conversaciones_tab.dart';
import '../solicitudes/detalle_solicitud_screen.dart';
import '../solicitudes/flujo_servicio.dart';
import '../solicitudes/lista_solicitudes_screen.dart';
import '../solicitudes/solicitud.dart';
import '../solicitudes/solicitudes_repository.dart';
import '../ubicacion/location_service.dart';

class AvisosServicio extends ConsumerStatefulWidget {
  final bool esCliente;
  final Widget child;
  const AvisosServicio({super.key, required this.esCliente, required this.child});
  @override
  ConsumerState<AvisosServicio> createState() => _AvisosServicioState();
}

class _AvisosServicioState extends ConsumerState<AvisosServicio> with WidgetsBindingObserver {
  StreamSubscription? _sub;
  RealtimeChannel? _canal;
  Timer? _sondeo;
  final Map<String, Paso> _pasos = {};
  final Map<String, String> _firmas = {};
  bool _primeraCarga = true, _dialogoAbierto = false;

  String get _columna => widget.esCliente ? 'cliente_id' : 'prestador_id';

  // Sirve para enterarse al momento de los cambios en las solicitudes
  void _suscribir() {
    _sub?.cancel();
    _sub = supabase.from('solicitudes').stream(primaryKey: ['id'])
        .eq(_columna, supabase.auth.currentUser!.id)
        .listen(_alCambiar, onError: (_) {
          _sub?.cancel();
          Future.delayed(const Duration(seconds: 5), () { if (mounted) _suscribir(); });
        });
  }

  Future<void> _sondear() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null || !mounted) return;
    try {
      final filas = await supabase.from('solicitudes').select().eq(_columna, uid);
      if (mounted) _alCambiar(List<Map<String, dynamic>>.from(filas));
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado == AppLifecycleState.resumed) { _sondear(); _suscribir(); }
  }

  @override
  void initState() {
    super.initState();
    final uid = supabase.auth.currentUser!.id;
    WidgetsBinding.instance.addObserver(this);
    _suscribir();
    _sondeo = Timer.periodic(const Duration(seconds: 15), (_) => _sondear());
    _canal = supabase.channel('novedades-$uid')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert, schema: 'public',
        table: widget.esCliente ? 'postulaciones' : 'solicitudes',
        callback: (p) => widget.esCliente ? _nuevaOferta(p.newRecord) : _nuevaSolicitud(p.newRecord),
      )
      ..onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'mensajes',
          callback: (p) => _mensaje(p.eventType == PostgresChangeEvent.insert ? p.newRecord : null))
      ..subscribe();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sondeo?.cancel();
    _sub?.cancel();
    if (_canal != null) supabase.removeChannel(_canal!);
    super.dispose();
  }

  void _nuevaOferta(Map<String, dynamic> fila) {
    final id = fila['solicitud_id'] as String?;
    if (id == null || !mounted) return;
    ref.invalidate(detalleProvider(id));
    ref.invalidate(misSolicitudesProvider);
    _snack(id, 'Recibiste una nueva oferta. Compárala y elige.');
  }

  void _mensaje(Map<String, dynamic>? nuevo) {
    if (!mounted) return;
    ref.invalidate(noLeidosProvider);
    final id = nuevo?['solicitud_id'] as String?;
    if (id == null || nuevo!['emisor_id'] == supabase.auth.currentUser?.id) return;
    if (router.routerDelegate.currentConfiguration.uri.path == '/chat/$id') return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.mark_chat_unread_outlined, color: CP.naranjaSuave, size: 20), SizedBox(width: 10),
          Expanded(child: Text('Tienes un mensaje nuevo')),
        ]),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(label: 'Abrir', onPressed: () => router.go('/chat/$id'))));
  }

  void _nuevaSolicitud(Map<String, dynamic> fila) {
    final id = fila['id'] as String?;
    if (id == null || !mounted) return;
    ref.invalidate(abiertasProvider);
    _snack(id, 'Hay una nueva solicitud cerca de ti.');
  }

  void _alCambiar(List<Map<String, dynamic>> filas) {
    final cambiadas = <Solicitud>[];
    for (final f in filas) {
      final s = Solicitud.fromMap(f);
      final antes = _pasos[s.id];
      _pasos[s.id] = s.paso;
      final firma = '${s.estado}|${s.paso.name}|${s.enRevision}';
      final cambio = _firmas[s.id] != firma;
      _firmas[s.id] = firma;
      if (cambio) {
        cambiadas.add(s);
        if (!_primeraCarga) ref.invalidate(detalleProvider(s.id));
        if (!_primeraCarga && antes != null && antes != s.paso) _avisar(s, antes);
      }
    }
    if (cambiadas.isNotEmpty && !_primeraCarga) {
      ref.invalidate(misSolicitudesProvider);
      ref.invalidate(trabajosProvider);
      ref.invalidate(conversacionesProvider);
    }
    if (_primeraCarga && widget.esCliente) {
      for (final s in cambiadas) {
        if (s.paso == Paso.confirmarLlegada || s.paso == Paso.confirmarFin) _preguntar(s.id);
      }
    }
    _primeraCarga = false;
  }

  bool _viendoDetalle(String id) => router.routerDelegate.currentConfiguration.uri.path == '/solicitud/$id';

  void _avisar(Solicitud s, Paso antes) {
    if (!mounted) return;
    if (s.estado == 'cancelada') {
      if (!widget.esCliente && !kIsWeb) LocationService.detener().catchError((_) {});
      if (s.canceladaPor == supabase.auth.currentUser?.id) return;
      final quien = widget.esCliente ? 'El técnico' : 'El cliente';
      final motivo = s.motivoCancelacion == null ? '.' : ': ${s.motivoCancelacion}';
      _snack(s.id, '$quien canceló el servicio$motivo');
      return;
    }
    if (widget.esCliente) {
      if (s.paso == Paso.confirmarLlegada || s.paso == Paso.confirmarFin) _preguntar(s.id);
      if (s.paso == Paso.enCurso && antes == Paso.codigo) _snack(s.id, 'Comenzó el trabajo.');
      return;
    }
    final texto = switch ((antes, s.paso)) {
      (Paso.confirmarLlegada, Paso.codigo) => 'El cliente confirmó tu llegada. Pídele el código para empezar.',
      (Paso.confirmarLlegada, Paso.enCamino) => s.enRevision
          ? 'El cliente volvió a indicar que no has llegado. El servicio quedó en revisión.'
          : 'El cliente indica que aún no has llegado.',
      (Paso.codigo, Paso.enCamino) => 'El código se bloqueó. El cliente debe confirmar tu llegada de nuevo.',
      (Paso.confirmarFin, Paso.finalizada) => '¡Felicidades! Has terminado el trabajo. Ya puedes recibir tu paga.',
      (Paso.confirmarFin, Paso.enCurso) => s.enRevision
          ? 'El cliente volvió a indicar que el trabajo no ha terminado. El servicio quedó en revisión.'
          : 'El cliente indica que el trabajo aún no está terminado.',
      _ => null,
    };
    if (texto != null) _snack(s.id, texto);
  }

  void _snack(String id, String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto), duration: const Duration(seconds: 6),
          action: _viendoDetalle(id) ? null : SnackBarAction(label: 'Ver', onPressed: () => router.go('/solicitud/$id'))));
  }

  // Ventana con la pregunta para el cliente
  Future<void> _preguntar(String id) async {
    if (_dialogoAbierto || !mounted || _viendoDetalle(id)) return;
    final Solicitud s;
    try { s = await SolicitudesRepository().una(id); } catch (_) { return; }
    if (!mounted || _dialogoAbierto || (s.paso != Paso.confirmarLlegada && s.paso != Paso.confirmarFin)) return;
    final llegada = s.paso == Paso.confirmarLlegada;
    final tecnico = s.prestadorNombre ?? 'Tu técnico';
    _dialogoAbierto = true;
    final respuesta = await showDialog<bool>(
      context: router.routerDelegate.navigatorKey.currentContext ?? context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: Container(width: 56, height: 56, decoration: const BoxDecoration(color: Color(0xFFFCEFE8), shape: BoxShape.circle),
            child: Icon(llegada ? Icons.notifications_active_outlined : Icons.task_alt, color: CP.naranja, size: 28)),
        title: Text(llegada ? 'Tu técnico llegó' : '¿El técnico terminó el trabajo?', textAlign: TextAlign.center),
        content: Text(llegada ? '$tecnico indica que ya está en el lugar del servicio. ¿Confirmas que llegó?'
            : '$tecnico indica que terminó el trabajo. ¿Confirmas que quedó listo?', textAlign: TextAlign.center),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(llegada ? 'Sí, llegó' : 'Sí, terminó')),
          const SizedBox(height: 8),
          OutlinedButton(style: estiloFantasma, onPressed: () => Navigator.pop(ctx, false),
              child: Text(llegada ? 'No ha llegado' : 'Todavía no')),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Responder más tarde')),
        ])],
      ),
    );
    _dialogoAbierto = false;
    if (respuesta == null || !mounted) return;
    final ctx = router.routerDelegate.navigatorKey.currentContext ?? context;
    if (!ctx.mounted) return;
    final ok = llegada ? await responderLlegada(ctx, s, si: respuesta) : await responderFin(ctx, s, si: respuesta);
    if (!ok) return;
    ref.invalidate(detalleProvider(id));
    if (respuesta && !_viendoDetalle(id)) router.go('/solicitud/$id');
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
