import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';

double? aNumero(Object? v) => v == null ? null : v is num ? v.toDouble() : double.tryParse('$v');

String numero(Object? v, [int decimales = 0]) {
  final n = aNumero(v);
  if (n == null) return '—';
  final partes = n.toStringAsFixed(decimales).split('.');
  final entero = partes[0].replaceFirst('-', '');
  final b = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < entero.length; i++) {
    if (i > 0 && (entero.length - i) % 3 == 0) b.write('.');
    b.write(entero[i]);
  }
  if (partes.length > 1 && int.parse(partes[1]) != 0) b.write(',${partes[1]}');
  return b.toString();
}

String porcentaje(Object? v, [int decimales = 1]) => aNumero(v) == null ? '—' : '${numero(v, decimales)} %';

const diasSemana = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
const franjas = {'manana': 'Mañana', 'tarde': 'Tarde', 'noche': 'Noche', 'madrugada': 'Madrugada'};

// Botones para elegir el periodo de las estadísticas
class SelectorPeriodo extends StatelessWidget {
  final int dias;
  final ValueChanged<int> alCambiar;
  const SelectorPeriodo({super.key, required this.dias, required this.alCambiar});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(children: [
      for (final (d, t) in const [(1, 'Hoy'), (7, '7 días'), (30, '30 días'), (90, '90 días')])
        Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(
          label: Text(t, style: estiloChip(dias == d)),
          selected: dias == d, showCheckmark: false, selectedColor: CP.verde, backgroundColor: Colors.white,
          side: BorderSide(color: dias == d ? CP.verde : CP.borde),
          onSelected: (_) => alCambiar(d),
        )),
    ]),
  );
}

// Tarjeta con un indicador y su nombre
class TarjetaKpi extends StatelessWidget {
  final String valor, nombre;
  final bool destacado;
  const TarjetaKpi(this.valor, this.nombre, {super.key, this.destacado = false});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: destacado ? CP.verde : Colors.white, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: destacado ? CP.verde : CP.borde)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(valor, style: estiloTitulo.copyWith(fontSize: 22, color: destacado ? Colors.white : CP.tinta)),
      const SizedBox(height: 4),
      Text(nombre, style: TextStyle(fontSize: 12.5, height: 1.3, color: destacado ? Colors.white70 : CP.apagado)),
    ]),
  );
}

class GrillaKpi extends StatelessWidget {
  final List<Widget> hijos;
  const GrillaKpi(this.hijos, {super.key});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
    final ancho = (c.maxWidth - 10) / 2;
    return Wrap(spacing: 10, runSpacing: 10, children: [for (final h in hijos) SizedBox(width: ancho, child: h)]);
  });
}

// Tarjeta con título para agrupar una gráfica o una lista
class PanelSeccion extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final Widget hijo;
  const PanelSeccion({super.key, required this.titulo, this.subtitulo, required this.hijo});
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Card(margin: const EdgeInsets.only(top: 14), child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(titulo, style: tt.titleMedium),
        if (subtitulo != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(subtitulo!, style: tt.bodySmall)),
        const SizedBox(height: 14),
        hijo,
      ]),
    ));
  }
}

class MuestraColor extends StatelessWidget {
  final Color color;
  final String texto;
  const MuestraColor(this.color, this.texto, {super.key});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
    const SizedBox(width: 6),
    Text(texto, style: Theme.of(context).textTheme.bodySmall),
  ]);
}

const sinDatos = Padding(padding: EdgeInsets.symmetric(vertical: 24),
    child: Center(child: Text('Sin solicitudes en el periodo.', style: TextStyle(color: CP.apagado))));
