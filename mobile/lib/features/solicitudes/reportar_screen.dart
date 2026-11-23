import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'solicitud.dart';
import 'solicitudes_repository.dart';


class ReportarScreen extends StatefulWidget {
  final String solicitudId;
  const ReportarScreen({super.key, required this.solicitudId});
  @override
  State<ReportarScreen> createState() => _ReportarScreenState();
}

class _ReportarScreenState extends State<ReportarScreen> {
  static const _motivosCliente = ['El prestador no llegó', 'El trabajo quedó mal hecho', 'Me cobró más de lo acordado',
      'Trato inadecuado o inseguro', 'Otro'];
  static const _motivosPrestador = ['El cliente no estaba', 'El cliente no pagó lo acordado', 'Trato inadecuado o inseguro', 'Otro'];
  final _detalle = TextEditingController();
  late Future<Solicitud> _solicitud =SolicitudesRepository().una(widget.solicitudId);
  String? _motivo;
  bool _intentado = false;

  @override
  void dispose() { _detalle.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return FutureBuilder(
      future: _solicitud,
      builder: (context, snap) {
        final Solicitud? s = snap.data;
        final uid = supabase.auth.currentUser!.id;
        final soyCliente = s?.clienteId == uid;
        final motivos = soyCliente ? _motivosCliente : _motivosPrestador;
        final reportado = soyCliente ? s?.prestadorId : s?.clienteId;
        return Scaffold(
          appBar: AppBar(titleSpacing: 0, title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Reportar un problema'),
            if (s != null) Text('${nombreCategoria(s.categoria)} · ${(soyCliente ? s.prestadorNombre : s.clienteNombre) ?? ''}',
                style: tt.bodySmall),
          ])),
          body: snap.hasError
              ? ErrorPantalla(mensajeError(snap.error!),
                  reintentar: () => setState(() => _solicitud = SolicitudesRepository().una(widget.solicitudId)))
              : s == null
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
                      Text('¿Qué pasó?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                          color: _intentado && _motivo == null ? CP.error : CP.tinta)),
                      const SizedBox(height: 10),
                      RadioGroup<String>(
                        groupValue: _motivo,
                        onChanged: (v) => setState(() => _motivo = v),
                        child: Column(children: [
                          for (final m in motivos) Padding(padding: const EdgeInsets.only(bottom: 8), child: Material(
                            color: _motivo == m ? CP.seleccion : Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14),
                                side: BorderSide(color: _motivo == m ? CP.verde : CP.borde, width: _motivo == m ? 1.5 : 1)),
                            child: RadioListTile<String>(value: m, title: Text(m, style: const TextStyle(fontSize: 14)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                          )),
                        ]),
                      ),
                      if (_intentado && _motivo == null) const Text('Elige un motivo',
                          style: TextStyle(color: CP.error, fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 14),
                      const Text('Cuéntanos más', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      TextField(controller: _detalle, maxLines: 4, minLines: 3,
                          decoration: const InputDecoration(hintText: 'Describe lo que ocurrió')),
                      const SizedBox(height: 8),
                      Text('Nuestro equipo revisará el caso en máximo 24 horas y te escribirá por correo.', style: tt.bodySmall),
                      const SizedBox(height: 20),
                      BotonAsync(
                        hijo: const Text('Enviar reporte'),
                        accion: () async {
                          setState(() => _intentado = true);
                          if (_motivo == null || reportado == null) return;
                          final texto = _detalle.text.trim().isEmpty ? _motivo! : '${_motivo!}: ${_detalle.text.trim()}';
                          await SolicitudesRepository().reportar(s.id, reportado, texto);
                          if (!context.mounted) return;
                          avisar(context, 'Recibimos tu reporte. Te escribiremos pronto.');
                          context.pop();
                        },
                      ),
                    ]),
        );
      },
    );
  }
}
