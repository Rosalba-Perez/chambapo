import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'admin_comunes.dart';
import 'admin_repository.dart';
import 'graficas.dart';

final resumenProvider = FutureProvider.autoDispose.family<Fila, int>((ref, dias) => AdminRepository().resumen(dias));

// Pestaña con los indicadores generales de la operación
class ResumenTab extends ConsumerStatefulWidget {
  const ResumenTab({super.key});
  @override
  ConsumerState<ResumenTab> createState() => _ResumenTabState();
}

class _ResumenTabState extends ConsumerState<ResumenTab> {
  int _dias = 30;

  @override
  Widget build(BuildContext context) {
    final datos = ref.watch(resumenProvider(_dias));
    Future<void> recargar() async => ref.invalidate(resumenProvider(_dias));
    return Scaffold(
      backgroundColor: CP.fondoApp,
      appBar: AppBar(backgroundColor: CP.fondoApp, title: const Text('Resumen'),
          actions: [IconButton(tooltip: 'Actualizar', onPressed: recargar, icon: const Icon(Icons.refresh))]),
      body: RefreshIndicator(
        onRefresh: recargar,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
          SelectorPeriodo(dias: _dias, alCambiar: (d) => setState(() => _dias = d)),
          const SizedBox(height: 12),
          ...datos.when(
            loading: () => [const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()))],
            error: (e, _) => [ErrorPantalla(mensajeError(e), reintentar: recargar)],
            data: (d) => _contenido(d),
          ),
        ]),
      ),
    );
  }

  List<Widget> _contenido(Fila d) {
    final r = Map<String, dynamic>.from(d['resumen'] ?? const {});
    final e = Map<String, dynamic>.from(d['embudo'] ?? const {});
    final serie = [for (final x in (d['serie'] as List? ?? const [])) Map<String, dynamic>.from(x)];
    final prob = aNumero(r['prob_media']);
    return [
      GrillaKpi([
        TarjetaKpi(numero(r['publicadas']), 'Solicitudes publicadas'),
        TarjetaKpi(porcentaje(r['tasa_contratacion']), 'Tasa de contratación', destacado: true),
        TarjetaKpi(numero(r['mediana_min_primera'], 1), 'Minutos hasta la primera oferta (mediana)'),
        TarjetaKpi(numero(r['postulaciones_prom'], 2), 'Ofertas por solicitud'),
        TarjetaKpi(numero(r['precio_relativo_prom'], 2), 'Precio acordado / presupuesto'),
        TarjetaKpi(prob == null ? '—' : porcentaje(prob * 100, 0), 'Probabilidad media de contratación (modelo)'),
      ]),
      PanelSeccion(
        titulo: 'Solicitudes por día',
        hijo: serie.isEmpty ? sinDatos : Column(children: [
          GraficaLineas(
            etiquetas: [for (final s in serie) '${s['dia']}'.length >= 10 ? '${'${s['dia']}'.substring(8, 10)}/${'${s['dia']}'.substring(5, 7)}' : '${s['dia']}'],
            series: [
              ([for (final s in serie) aNumero(s['publicadas']) ?? 0], CP.verde),
              ([for (final s in serie) aNumero(s['finalizadas']) ?? 0], CP.naranjaLogo),
            ],
          ),
          const SizedBox(height: 10),
          const Wrap(spacing: 16, children: [MuestraColor(CP.verde, 'Publicadas'), MuestraColor(CP.naranjaLogo, 'Finalizadas')]),
        ]),
      ),
      PanelSeccion(
        titulo: 'Embudo de conversión',
        subtitulo: 'Hasta dónde llega cada solicitud publicada.',
        hijo: _Embudo(e),
      ),
    ];
  }
}

class _Embudo extends StatelessWidget {
  final Map<String, dynamic> e;
  const _Embudo(this.e);
  @override
  Widget build(BuildContext context) {
    final total = aNumero(e['publicadas']) ?? 0;
    if (total == 0) return sinDatos;
    final con = aNumero(e['con_postulaciones']) ?? 0, asig = aNumero(e['asignadas']) ?? 0, fin = aNumero(e['finalizadas']) ?? 0;
    final etapas = [
      ('Sin ofertas', total - con, const Color(0xFFC9D3CF)),
      ('Con oferta, sin asignar', con - asig, CP.naranjaSuave),
      ('Asignadas sin finalizar', asig - fin, const Color(0xFF5F9E9B)),
      ('Finalizadas', fin, CP.verde),
    ];
    final tt = Theme.of(context).textTheme;
    return Column(children: [
      GraficaDona(partes: [for (final (_, n, c) in etapas) (n, c)], centro: numero(total), debajo: 'publicadas'),
      const SizedBox(height: 12),
      for (final (nombre, n, color) in etapas)
        Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 8),
          Expanded(child: Text(nombre, style: tt.bodyMedium)),
          Text(numero(n), style: const TextStyle(fontWeight: FontWeight.w700)),
          SizedBox(width: 64, child: Text(porcentaje(100 * n / total), textAlign: TextAlign.right, style: tt.bodySmall)),
        ])),
    ]);
  }
}
