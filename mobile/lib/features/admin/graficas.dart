import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/theme.dart';

const _textoEje = TextStyle(fontSize: 11, color: CP.apagado);

double _intervalo(double maximo) => math.max(1, (maximo / 4).ceilToDouble());

AxisTitles get _sinTitulos => const AxisTitles(sideTitles: SideTitles(showTitles: false));

AxisTitles _ejeIzquierdo(double intervalo) => AxisTitles(sideTitles: SideTitles(
  showTitles: true, reservedSize: 32, interval: intervalo,
  getTitlesWidget: (v, meta) => v % 1 != 0 ? const SizedBox.shrink() : Text('${v.toInt()}', style: _textoEje),
));

FlGridData _rejilla(double intervalo) => FlGridData(drawVerticalLine: false, horizontalInterval: intervalo,
    getDrawingHorizontalLine: (_) => const FlLine(color: CP.borde, strokeWidth: 1));

// Gráfica de líneas con una o varias series que comparten el eje de abajo
class GraficaLineas extends StatelessWidget {
  final List<String> etiquetas;
  final List<(List<double>, Color)> series;
  const GraficaLineas({super.key, required this.etiquetas, required this.series});
  @override
  Widget build(BuildContext context) {
    final n = etiquetas.length;
    final maximo = series.expand((s) => s.$1).fold<double>(1, math.max);
    final intervalo = _intervalo(maximo);
    final cadaCuanto = math.max(1, (n / 5).ceil());
    return SizedBox(height: 220, child: LineChart(LineChartData(
      minY: 0, maxY: (maximo / intervalo).ceil() * intervalo,
      gridData: _rejilla(intervalo),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: _sinTitulos, rightTitles: _sinTitulos, leftTitles: _ejeIzquierdo(intervalo),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 26, interval: 1,
          getTitlesWidget: (v, meta) {
            final i = v.toInt();
            if (v != i || i < 0 || i >= n || i % cadaCuanto != 0) return const SizedBox.shrink();
            return Padding(padding: const EdgeInsets.only(top: 6), child: Text(etiquetas[i], style: _textoEje));
          })),
      ),
      lineBarsData: [
        for (final (valores, color) in series)
          LineChartBarData(
            spots: [for (var i = 0; i < valores.length; i++) FlSpot(i.toDouble(), valores[i])],
            isCurved: true, preventCurveOverShooting: true, color: color, barWidth: 2.5,
            dotData: FlDotData(show: n <= 2),
          ),
      ],
    )));
  }
}

// Gráfica de dona con el total en el centro
class GraficaDona extends StatelessWidget {
  final List<(double, Color)> partes;
  final String centro, debajo;
  const GraficaDona({super.key, required this.partes, required this.centro, required this.debajo});
  @override
  Widget build(BuildContext context) => SizedBox(height: 190, child: Stack(alignment: Alignment.center, children: [
    PieChart(PieChartData(
      sectionsSpace: 2, centerSpaceRadius: 58, startDegreeOffset: -90,
      sections: [
        for (final (valor, color) in partes)
          if (valor > 0) PieChartSectionData(value: valor, color: color, radius: 28, showTitle: false),
      ],
    )),
    Column(mainAxisSize: MainAxisSize.min, children: [
      Text(centro, style: estiloTitulo.copyWith(fontSize: 24)),
      Text(debajo, style: _textoEje),
    ]),
  ]));
}
