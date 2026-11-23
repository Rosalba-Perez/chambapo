import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../ubicacion/location_service.dart';
import 'solicitud.dart';
import 'solicitudes_repository.dart';

const maxRechazos = 2;

final codigoInicioProvider = FutureProvider.autoDispose.family<String, String>(
    (ref, id) => SolicitudesRepository().codigoInicio(id));


Future<bool> _confirmarRevision(BuildContext context, String que) => confirmar(context,
    titulo: '¿Pedir revisión del servicio?', destructivo: true, si: 'Sí, pedir revisión', no: 'Cancelar',
    mensaje: 'Ya indicaste $maxRechazos veces que $que. Un administrador revisará lo ocurrido y podrá vetar al técnico o al cliente.');

// Pregunta al cliente si el técnico ya llegó
Future<bool> responderLlegada(BuildContext context, Solicitud s, {required bool si}) async {
  final tecnico = s.prestadorNombre ?? 'el técnico';
  if (!si && s.rechazosLlegada >= maxRechazos && !await _confirmarRevision(context, 'no había llegado')) return false;
  if (!context.mounted) return false;
  try {
    final r = await SolicitudesRepository().confirmarLlegada(s.id, si);
    if (!context.mounted) return true;
    avisar(context, si ? 'Listo. Dale el código a $tecnico para empezar.'
        : r.revision ? 'El servicio quedó en revisión. Un administrador revisará lo ocurrido.'
        : 'Le avisamos a $tecnico que aún no ha llegado.');
    return true;
  } catch (e) {
    if (context.mounted) avisar(context, mensajeError(e));
    return false;
  }
}

Future<bool> responderFin(BuildContext context, Solicitud s, {required bool si}) async {
  final tecnico = s.prestadorNombre ?? 'el técnico';
  if (!si && s.rechazosFin >= maxRechazos && !await _confirmarRevision(context, 'el trabajo no estaba terminado')) return false;
  if (!context.mounted) return false;
  try {
    final revision = await SolicitudesRepository().confirmarFin(s.id, si);
    if (!context.mounted) return true;
    if (!si) {
      avisar(context, revision ? 'El servicio quedó en revisión. Un administrador revisará lo ocurrido.'
          : 'Le avisamos a $tecnico que el trabajo aún no está terminado.');
    }
    return true;
  } catch (e) {
    if (context.mounted) avisar(context, mensajeError(e));
    return false;
  }
}

// Tarjeta con una pregunta para el cliente
class TarjetaPregunta extends StatelessWidget {
  final IconData icono;
  final String titulo, texto, si, no;
  final bool noEsRevision;
  final Future<void> Function() alSi, alNo;
  const TarjetaPregunta({super.key, required this.icono, required this.titulo, required this.texto,
      required this.si, required this.no, required this.alSi, required this.alNo, this.noEsRevision = false});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CP.naranja, width: 2),
        boxShadow: [BoxShadow(color: CP.naranja.withValues(alpha: 0.12), blurRadius: 18, offset: const Offset(0, 6))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Container(width: 40, height: 40, decoration: const BoxDecoration(color: Color(0xFFFCEFE8), shape: BoxShape.circle),
            child: Icon(icono, color: CP.naranja, size: 22)),
        const SizedBox(width: 12),
        Expanded(child: Text(titulo, style: Theme.of(context).textTheme.headlineSmall)),
      ]),
      const SizedBox(height: 10),
      Text(texto, style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 16),
      BotonAsync(accion: alSi, hijo: Text(si)),
      const SizedBox(height: 8),
      BotonAsync(contorno: true, estilo: noEsRevision ? OutlinedButton.styleFrom(foregroundColor: CP.error,
          side: const BorderSide(color: CP.error, width: 1.5)) : estiloFantasma, accion: alNo, hijo: Text(no)),
    ]),
  );
}

class TarjetaCodigo extends ConsumerWidget {
  final Solicitud s;
  const TarjetaCodigo(this.s, {super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final codigo = ref.watch(codigoInicioProvider(s.id));
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: CP.verde, borderRadius: BorderRadius.circular(20)),
      child: Column(children: [
        const Text('Tu código de inicio', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        codigo.when(
          loading: () => const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: Colors.white)),
          error: (e, _) => Column(children: [
            Text(mensajeError(e), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
            TextButton(onPressed: () => ref.invalidate(codigoInicioProvider(s.id)),
                style: TextButton.styleFrom(foregroundColor: CP.naranjaSuave), child: const Text('Reintentar')),
          ]),
          data: (c) => Semantics(label: 'Código ${c.split('').join(' ')}', child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (final d in c.split('')) Container(
              width: 54, height: 64, margin: const EdgeInsets.symmetric(horizontal: 5), alignment: Alignment.center,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
              child: Text(d, style: estiloTitulo.copyWith(fontSize: 34, color: CP.verde)),
            ),
          ])),
        ),
        const SizedBox(height: 12),
        Text('Dáselo a ${s.prestadorNombre ?? 'tu técnico'} para que empiece el trabajo. No lo compartas antes de que llegue.',
            textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4)),
      ]),
    );
  }
}

// Campo donde el técnico escribe el código que le da el cliente
class FormCodigo extends StatefulWidget {
  final Solicitud s;
  final VoidCallback alIniciar;
  const FormCodigo({super.key, required this.s, required this.alIniciar});
  @override
  State<FormCodigo> createState() => _FormCodigoState();
}

class _FormCodigoState extends State<FormCodigo> {
  final _codigo = TextEditingController();
  String? _error;

  Future<void> _iniciar() async {
    final c = _codigo.text.trim();
    if (!RegExp(r'^\d{4}$').hasMatch(c)) { setState(() => _error = 'Escribe los 4 números del código'); return; }
    setState(() => _error = null);
    try {
      await SolicitudesRepository().iniciar(widget.s.id, c);
      if (!kIsWeb) { try { await LocationService.detener(); } catch (_) {} }
      if (mounted) avisar(context, 'Código correcto. ¡Comenzó el trabajo!');
      widget.alIniciar();
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = mensajeError(e); _codigo.clear(); });
      if (_error!.startsWith('Demasiados intentos')) widget.alIniciar();
    }
  }

  @override
  void dispose() { _codigo.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('El cliente confirmó tu llegada', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 6),
      Text('Pídele a ${widget.s.clienteNombre ?? 'el cliente'} el código de 4 números para confirmar el inicio del trabajo.',
          style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 16),
      TextField(
        controller: _codigo, keyboardType: TextInputType.number, textAlign: TextAlign.center, maxLength: 4,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: estiloTitulo.copyWith(fontSize: 30, letterSpacing: 18),
        onSubmitted: (_) => _iniciar(),
        decoration: InputDecoration(counterText: '', hintText: '• • • •', errorText: _error, errorMaxLines: 3),
      ),
      const SizedBox(height: 14),
      BotonAsync(accion: _iniciar, hijo: const Text('Confirmar inicio del trabajo')),
    ],
  )));
}

String _precio(Solicitud s) => s.precioAcordado == null ? 'lo acordado' : pesos(s.precioAcordado);

String textoGracias(bool soyCliente) => soyCliente
    ? 'Tu opinión y solicitar tus servicios con nosotros nos ayudan a crecer.'
    : 'Tu opinión y tus servicios nos ayudan a crecer.';

String textoRecordatorioPago(Solicitud s, bool soyCliente) => soyCliente
    ? 'Recuerda: Chambapo no procesa pagos. El pago se hace directamente entre ustedes; asegúrate de cumplir con el pago de ${_precio(s)}.'
    : 'Recuerda: Chambapo no procesa pagos. El pago se hace directamente entre ustedes; asegúrate de recibir tu pago de ${_precio(s)}.';

Future<void> mostrarGracias(BuildContext context, Solicitud s, bool soyCliente) => showDialog(context: context, builder: (ctx) => AlertDialog(
  icon: Container(width: 56, height: 56, decoration: const BoxDecoration(color: Color(0xFFFCEFE8), shape: BoxShape.circle),
      child: const Icon(Icons.favorite, color: CP.naranja, size: 28)),
  title: const Text('¡Gracias por usar Chambapo!', textAlign: TextAlign.center),
  content: Column(mainAxisSize: MainAxisSize.min, children: [
    Text(textoGracias(soyCliente), textAlign: TextAlign.center),
    const SizedBox(height: 14),
    Aviso(TipoAviso.advertencia, 'Recuerda', texto: textoRecordatorioPago(s, soyCliente).replaceFirst('Recuerda: ', '')),
  ]),
  actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
  actions: [SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido')))],
));

class Felicitaciones extends StatelessWidget {
  final Solicitud s;
  final bool soyCliente;
  const Felicitaciones({super.key, required this.s, required this.soyCliente});
  @override
  Widget build(BuildContext context) {
    final otro = soyCliente ? (s.prestadorNombre ?? 'el técnico') : (s.clienteNombre ?? 'el cliente');
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
      decoration: BoxDecoration(color: CP.verde, borderRadius: BorderRadius.circular(20)),
      child: Column(children: [
        Container(width: 52, height: 52, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: const Icon(Icons.celebration_outlined, color: CP.verde, size: 28)),
        const SizedBox(height: 12),
        Text(soyCliente ? '¡Servicio finalizado con éxito!' : '¡Felicidades! Has terminado el trabajo',
            textAlign: TextAlign.center, style: estiloTitulo.copyWith(color: Colors.white, fontSize: 22)),
        const SizedBox(height: 8),
        Text(soyCliente ? 'Ya puedes pagarle ${_precio(s)} directamente a $otro.' : 'Ya puedes recibir tu paga de ${_precio(s)}.',
            textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.info_outline, color: Colors.white70, size: 16), SizedBox(width: 6),
            Flexible(child: Text('Chambapo no procesa pagos: el pago se hace directamente entre ustedes.',
                style: TextStyle(color: Colors.white70, fontSize: 12))),
          ]),
        ),
      ]),
    );
  }
}
