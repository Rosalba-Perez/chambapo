import 'package:flutter/material.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../solicitudes/solicitud.dart';
import '../solicitudes/solicitudes_repository.dart';

// Pantalla del chat entre el cliente y el técnico
class ChatScreen extends StatefulWidget {
  final String solicitudId;
  const ChatScreen({super.key, required this.solicitudId});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _texto = TextEditingController();
  late final Stream<List<Map<String, dynamic>>> _mensajes = supabase.from('mensajes')
      .stream(primaryKey: ['id']).eq('solicitud_id', widget.solicitudId).order('creado_en', ascending: true);
  late final Future<Solicitud> _solicitud = SolicitudesRepository().una(widget.solicitudId);
  final Set<Object> _marcados = {};
  final List<String> _fallidos = [];
  bool _enviando = false;

  Future<void> _enviar([String? reintento]) async {
    final t = (reintento ?? _texto.text).trim();
    if (t.isEmpty || _enviando) return;
    setState(() { _enviando = true; if (reintento == null) _texto.clear(); _fallidos.remove(t); });
    try {
      await supabase.from('mensajes').insert({'solicitud_id': widget.solicitudId,
          'emisor_id': supabase.auth.currentUser!.id, 'texto': t});
    } catch (_) {
      if (mounted) setState(() => _fallidos.add(t));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  void dispose() { _texto.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final uid = supabase.auth.currentUser!.id;
    return FutureBuilder<Solicitud>(future: _solicitud, builder: (context, snapSol) {
      final s = snapSol.data;
      final soyCliente = s?.clienteId == uid;
      final otro = s == null ? '' : ((soyCliente ? s.prestadorNombre : s.clienteNombre) ?? '');
      final rapidas = soyCliente
          ? const ['¿Cuánto te falta?', 'Ya bajo a abrir', 'Te espero en la portería']
          : const ['Voy en camino', 'Ya llegué', '¿Me confirmas la dirección?'];
      return Scaffold(
        backgroundColor: CP.fondoApp,
        appBar: AppBar(titleSpacing: 0, title: Row(children: [
          if (otro.isNotEmpty) ...[
            AvatarIniciales(otro, tam: 36, foto: s == null ? null : (soyCliente ? s.prestadorFoto : s.clienteFoto)),
            const SizedBox(width: 10),
          ],
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(otro.isEmpty ? 'Chat' : otro, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CP.tinta)),
            if (s != null) Text(nombreEstado(s.estado), style: const TextStyle(fontSize: 12, color: CP.verde, fontWeight: FontWeight.w600)),
          ])),
        ])),
        body: Column(children: [
          Expanded(child: StreamBuilder(stream: _mensajes, builder: (_, snap) {
            if (snap.hasError) {
              return ErrorPantalla('No pudimos conectar con el chat. Revisa tu conexión.', reintentar: () => setState(() {}));
            }
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final msgs = snap.data!;
            final nuevos = msgs.where((m) => m['emisor_id'] != uid && m['leido_en'] == null && !_marcados.contains(m['id']))
                .map((m) => m['id'] as Object).toList();
            if (nuevos.isNotEmpty) {
              _marcados.addAll(nuevos);
              WidgetsBinding.instance.addPostFrameCallback((_) => SolicitudesRepository().marcarLeidos(widget.solicitudId));
            }
            if (msgs.isEmpty && _fallidos.isEmpty) {
              return const Vacio(Icons.chat_bubble_outline, 'Aún no hay mensajes', 'Escribe para coordinar los detalles del servicio.');
            }
            final total = msgs.length + _fallidos.length;
            return ListView.builder(
              reverse: true, padding: const EdgeInsets.fromLTRB(16, 12, 16, 12), itemCount: total,
              itemBuilder: (_, i) {
                final idx = total - 1 - i;
                if (idx >= msgs.length) {
                  final t = _fallidos[idx - msgs.length];
                  return _Burbuja(texto: t, mio: true, fallido: true, onTap: () => _enviar(t));
                }
                final m = msgs[idx];
                return _Burbuja(texto: m['texto'], mio: m['emisor_id'] == uid,
                    hora: horaCorta(DateTime.parse(m['creado_en'])));
              },
            );
          })),
          SizedBox(height: 44, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [for (final r in rapidas) Padding(padding: const EdgeInsets.only(right: 8),
                child: ActionChip(label: Text(r), labelStyle: estiloChip(false), onPressed: () => _enviar(r)))])),
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(16, 8, 10, 8 + MediaQuery.paddingOf(context).bottom),
            child: Row(children: [
              Expanded(child: TextField(controller: _texto, textCapitalization: TextCapitalization.sentences,
                  minLines: 1, maxLines: 4, onSubmitted: (_) => _enviar(),
                  decoration: InputDecoration(hintText: 'Escribe un mensaje…',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: CP.borde)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: CP.borde)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: CP.verde, width: 2)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)))),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Enviar', onPressed: _enviando ? null : _enviar,
                style: IconButton.styleFrom(backgroundColor: CP.naranja, foregroundColor: Colors.white, minimumSize: const Size(48, 48)),
                icon: const Icon(Icons.send_rounded, size: 20),
              ),
            ]),
          ),
        ]),
      );
    });
  }
}

class _Burbuja extends StatelessWidget {
  final String texto;
  final String? hora;
  final bool mio, fallido;
  final VoidCallback? onTap;
  const _Burbuja({required this.texto, required this.mio, this.hora, this.fallido = false, this.onTap});
  @override
  Widget build(BuildContext context) => Align(
    alignment: mio ? Alignment.centerRight : Alignment.centerLeft,
    child: GestureDetector(onTap: onTap, child: Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 7),
      decoration: BoxDecoration(
        color: fallido ? CP.errorFondo : (mio ? CP.verde : Colors.white),
        border: fallido ? Border.all(color: CP.error) : (mio ? null : Border.all(color: CP.borde)),
        borderRadius: BorderRadius.only(topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mio ? 16 : 4), bottomRight: Radius.circular(mio ? 4 : 16)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(texto, style: TextStyle(fontSize: 14.5, height: 1.35, color: fallido ? CP.tinta : (mio ? Colors.white : CP.tinta))),
        const SizedBox(height: 2),
        Text(fallido ? 'No se envió · toca para reintentar' : (hora ?? ''),
            style: TextStyle(fontSize: 11, color: fallido ? CP.error : (mio ? Colors.white70 : CP.apagado),
                fontWeight: fallido ? FontWeight.w700 : FontWeight.w400)),
      ]),
    )),
  );
}
