import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'admin_comunes.dart';
import 'admin_repository.dart';
import 'graficas_demanda.dart';

typedef DatosDemanda = ({List<Fila> categorias, List<Fila> diaFranja, List<Fila> barrios, List<Fila> tiempo});

final demandaProvider = FutureProvider.autoDispose.family<DatosDemanda, int>((ref, dias) async {
  final r = AdminRepository();
  final res = await Future.wait([r.por('categoria', dias), r.por('dia_franja', dias), r.por('barrio', dias), r.por('tiempo_tomada', dias)]);
  return (categorias: res[0], diaFranja: res[1], barrios: res[2], tiempo: res[3]);
});

const _umbralTasaBaja = 45;

// Pestaña con qué se pide, cuándo y dónde, y cuánto se concreta
class DemandaTab extends ConsumerStatefulWidget {
  const DemandaTab({super.key});
  @override
  ConsumerState<DemandaTab> createState() => _DemandaTabState();
}

class _DemandaTabState extends ConsumerState<DemandaTab> {
  int _dias = 30;

  @override
  Widget build(BuildContext context) {
    final datos = ref.watch(demandaProvider(_dias));
    Future<void> recargar() async => ref.invalidate(demandaProvider(_dias));
    return Scaffold(
      backgroundColor: CP.fondoApp,
      appBar: AppBar(backgroundColor: CP.fondoApp, title: const Text('Demanda'),
          actions: [IconButton(tooltip: 'Actualizar', onPressed: recargar, icon: const Icon(Icons.refresh))]),
      body: RefreshIndicator(
        onRefresh: recargar,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
          SelectorPeriodo(dias: _dias, alCambiar: (d) => setState(() => _dias = d)),
          ...datos.when(
            loading: () => [const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()))],
            error: (e, _) => [ErrorPantalla(mensajeError(e), reintentar: recargar)],
            data: _contenido,
          ),
        ]),
      ),
    );
  }

  List<Widget> _contenido(DatosDemanda d) => [
    PanelSeccion(
      titulo: 'Conversión por tipo de servicio',
      subtitulo: 'Porcentaje de solicitudes publicadas que toma un técnico, de mayor a menor.',
      hijo: d.categorias.isEmpty ? sinDatos : _ConversionCategorias(d.categorias),
    ),
    PanelSeccion(
      titulo: 'Mapa de demanda semanal',
      subtitulo: 'Cuándo se publican más solicitudes: cuanto más intenso el azul, más demanda.',
      hijo: d.diaFranja.isEmpty ? sinDatos : MapaSemanal(d.diaFranja),
    ),
    PanelSeccion(
      titulo: 'Precisión del modelo por barrio',
      subtitulo: 'Tasa real de contratación frente a la probabilidad estimada: cuánto acierta el modelo en cada zona.',
      hijo: d.barrios.isEmpty ? sinDatos : DumbbellBarrios(d.barrios),
    ),
    PanelSeccion(
      titulo: 'Velocidad de contratación por servicio',
      subtitulo: 'Porcentaje acumulado de solicitudes tomadas según las horas desde su publicación.',
      hijo: d.tiempo.isEmpty ? sinDatos : CurvasTomada(d.tiempo),
    ),
  ];
}

class _ConversionCategorias extends StatelessWidget {
  final List<Fila> datos;
  const _ConversionCategorias(this.datos);
  @override
  Widget build(BuildContext context) {
    final filas = [
      for (final f in datos)
        (nombre: nombreCategoria('${f['clave']}'), publicadas: aNumero(f['publicadas']) ?? 0, tomadas: aNumero(f['tomadas']) ?? 0),
    ]..sort((a, b) => (b.publicadas == 0 ? 0 : b.tomadas / b.publicadas).compareTo(a.publicadas == 0 ? 0 : a.tomadas / a.publicadas));
    final maximo = filas.fold<double>(1, (m, f) => f.publicadas > m ? f.publicadas : m);
    final tt = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final f in filas) Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(f.nombre, style: tt.bodyMedium)),
            Text('${numero(f.tomadas)} de ${numero(f.publicadas)} · ', style: tt.bodySmall),
            Text(porcentaje(f.publicadas == 0 ? 0 : 100 * f.tomadas / f.publicadas, 0),
                style: TextStyle(fontWeight: FontWeight.w700,
                    color: f.publicadas > 0 && 100 * f.tomadas / f.publicadas < _umbralTasaBaja ? CP.naranja : CP.verde)),
          ]),
          const SizedBox(height: 4),
          LayoutBuilder(builder: (context, c) {
            final ancho = c.maxWidth * f.publicadas / maximo;
            final bajo = f.publicadas > 0 && 100 * f.tomadas / f.publicadas < _umbralTasaBaja;
            return Align(alignment: Alignment.centerLeft, child: Container(
              width: ancho, height: 10,
              decoration: BoxDecoration(color: CP.seleccion, borderRadius: BorderRadius.circular(5)),
              alignment: Alignment.centerLeft,
              child: Container(width: f.publicadas == 0 ? 0 : ancho * f.tomadas / f.publicadas, height: 10,
                  decoration: BoxDecoration(color: bajo ? CP.naranjaLogo : CP.verde, borderRadius: BorderRadius.circular(5))),
            ));
          }),
        ]),
      ),
      const SizedBox(height: 8),
      const Wrap(spacing: 14, runSpacing: 6, children: [
        MuestraColor(CP.seleccion, 'publicadas'),
        MuestraColor(CP.verde, 'tomadas por un técnico'),
        MuestraColor(CP.naranjaLogo, 'menos del $_umbralTasaBaja %'),
      ]),
    ]);
  }
}
