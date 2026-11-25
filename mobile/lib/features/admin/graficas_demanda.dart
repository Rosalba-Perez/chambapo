import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'admin_comunes.dart';
import 'admin_repository.dart';

const _azul = Color(0xFF1F5FAE);
const _gris = Color(0xFF9AA6A1);
const _azulClaro = Color(0xFFEAF2FB);
const _azulIntenso = Color(0xFF0B3D91);
const _textoEje = TextStyle(fontSize: 11, color: CP.apagado);

// Mapa de calor: cuántas solicitudes hay en cada día de la semana y franja horaria
class MapaSemanal extends StatelessWidget {
  final List<Fila> datos;
  const MapaSemanal(this.datos, {super.key});

  static const _orden = ['manana', 'tarde', 'noche', 'madrugada'];
  static const _cortas = ['Mañana', 'Tarde', 'Noche', 'Madrug.'];

  @override
  Widget build(BuildContext context) {
    final celdas = <String, double>{};
    for (final d in datos) {
      celdas['${aNumero(d['dia'])?.toInt()}-${d['franja']}'] = aNumero(d['n']) ?? 0;
    }
    double valor(int dia, String fr) => celdas['$dia-$fr'] ?? 0;
    final maximo = celdas.values.fold<double>(1, math.max);
    final totalesDia = [for (var d = 0; d < 7; d++) _orden.fold<double>(0, (s, fr) => s + valor(d, fr))];
    final totalesFranja = [for (final fr in _orden) List.generate(7, (d) => valor(d, fr)).fold<double>(0, (a, b) => a + b)];

    Widget celda(double n) {
      final t = n / maximo;
      return Container(
        height: 34, margin: const EdgeInsets.all(2), alignment: Alignment.center,
        decoration: BoxDecoration(color: Color.lerp(_azulClaro, _azulIntenso, t), borderRadius: BorderRadius.circular(6)),
        child: Text(numero(n), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t > 0.5 ? Colors.white : CP.tinta)),
      );
    }
    Widget encabezado(String t) => Padding(padding: const EdgeInsets.only(bottom: 4),
        child: Text(t, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CP.apagado)));
    Widget total(double n) => Center(child: Text(numero(n), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)));

    return Column(children: [
      Table(
        columnWidths: const {0: FixedColumnWidth(40), 5: FixedColumnWidth(44)},
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(children: [const SizedBox(), for (final c in _cortas) encabezado(c), encabezado('Total')]),
          for (var d = 0; d < 7; d++)
            TableRow(children: [
              Text(diasSemana[d], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              for (final fr in _orden) celda(valor(d, fr)),
              total(totalesDia[d]),
            ]),
          TableRow(children: [
            const Text('Total', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            for (final n in totalesFranja) Padding(padding: const EdgeInsets.only(top: 6), child: total(n)),
            Padding(padding: const EdgeInsets.only(top: 6), child: total(totalesDia.fold(0, (a, b) => a + b))),
          ]),
        ],
      ),
      const SizedBox(height: 12),
      Row(children: [
        Text('Menos', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 10, decoration: BoxDecoration(borderRadius: BorderRadius.circular(5),
            gradient: const LinearGradient(colors: [_azulClaro, _azulIntenso])))),
        const SizedBox(width: 8),
        Text('Más', style: Theme.of(context).textTheme.bodySmall),
      ]),
    ]);
  }
}

// Gráfico dumbbell: tasa real de contratación frente a la probabilidad estimada por el modelo, por barrio
class DumbbellBarrios extends StatelessWidget {
  final List<Fila> datos;
  const DumbbellBarrios(this.datos, {super.key});

  static const _umbralDesvio = 10.0;

  @override
  Widget build(BuildContext context) {
    final filas = [
      for (final b in datos)
        if (b['clave'] != null && (aNumero(b['cerradas']) ?? 0) > 0 && b['tasa_real'] != null && b['prob_cerradas'] != null)
          (barrio: '${b['clave']}', publicadas: aNumero(b['publicadas']) ?? 0,
           real: aNumero(b['tasa_real'])! * 100, estimada: aNumero(b['prob_cerradas'])! * 100),
    ].take(8).toList();
    if (filas.isEmpty) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: Text('Aún no hay solicitudes cerradas por barrio en el periodo.',
              textAlign: TextAlign.center, style: TextStyle(color: CP.apagado))));
    }
    final valores = filas.expand((f) => [f.real, f.estimada]);
    final minimo = math.min(40.0, (valores.reduce(math.min) / 10).floor() * 10.0);
    final maximo = math.max(70.0, (valores.reduce(math.max) / 10).ceil() * 10.0);
    final tt = Theme.of(context).textTheme;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(height: 16, child: CustomPaint(painter: _EjeDumbbell(minimo, maximo))),
      for (final f in filas) Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(f.barrio, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
            Text('${numero(f.publicadas)} publicadas · ', style: tt.bodySmall),
            Text('${f.estimada - f.real >= 0 ? '+' : '−'}${numero((f.estimada - f.real).abs())} pts',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                    color: (f.estimada - f.real).abs() >= _umbralDesvio ? CP.naranja : CP.apagado)),
          ]),
          SizedBox(height: 22, child: CustomPaint(painter: _FilaDumbbell(f.real, f.estimada, minimo, maximo,
              lejos: (f.estimada - f.real).abs() >= _umbralDesvio))),
        ]),
      ),
      const SizedBox(height: 12),
      const Wrap(spacing: 14, runSpacing: 6, children: [
        MuestraColor(_azul, 'tasa real de contratación'),
        MuestraColor(CP.naranjaLogo, 'probabilidad estimada por el modelo'),
      ]),
      const SizedBox(height: 6),
      Text('Diferencia = estimada − real. La línea se pinta naranja desde ${_umbralDesvio.toInt()} puntos.', style: tt.bodySmall),
    ]);
  }
}

class _EjeDumbbell extends CustomPainter {
  final double minimo, maximo;
  _EjeDumbbell(this.minimo, this.maximo);
  @override
  void paint(Canvas canvas, Size size) {
    for (var v = minimo; v <= maximo; v += 10) {
      final x = (v - minimo) / (maximo - minimo) * size.width;
      final tp = TextPainter(text: TextSpan(text: '${v.toInt()} %', style: _textoEje), textDirection: TextDirection.ltr)..layout();
      final dx = (x - tp.width / 2).clamp(0.0, size.width - tp.width);
      tp.paint(canvas, Offset(dx, 0));
    }
  }
  @override
  bool shouldRepaint(_EjeDumbbell old) => old.minimo != minimo || old.maximo != maximo;
}

class _FilaDumbbell extends CustomPainter {
  final double real, estimada, minimo, maximo;
  final bool lejos;
  _FilaDumbbell(this.real, this.estimada, this.minimo, this.maximo, {required this.lejos});
  @override
  void paint(Canvas canvas, Size size) {
    double x(double v) => 7 + (v - minimo) / (maximo - minimo) * (size.width - 14);
    final y = size.height / 2;
    final rejilla = Paint()..color = CP.borde..strokeWidth = 1;
    for (var v = minimo; v <= maximo; v += 10) {
      canvas.drawLine(Offset(x(v), 0), Offset(x(v), size.height), rejilla);
    }
    canvas.drawLine(Offset(x(real), y), Offset(x(estimada), y),
        Paint()..color = lejos ? CP.naranjaLogo : _gris..strokeWidth = 3..strokeCap = StrokeCap.round);
    final borde = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2;
    for (final (v, c) in [(real, _azul), (estimada, CP.naranjaLogo)]) {
      canvas.drawCircle(Offset(x(v), y), 7, Paint()..color = c);
      canvas.drawCircle(Offset(x(v), y), 7, borde);
    }
  }
  @override
  bool shouldRepaint(_FilaDumbbell old) => old.real != real || old.estimada != estimada;
}

// Gráfica de líneas múltiples: porcentaje acumulado de solicitudes tomadas según las horas desde su publicación
class CurvasTomada extends StatelessWidget {
  final List<Fila> datos;
  const CurvasTomada(this.datos, {super.key});

  static const _minParaDestacar = 5;
  static const _corteHoras = 2.0;

  @override
  Widget build(BuildContext context) {
    final series = [
      for (final d in datos)
        (clave: '${d['categoria']}', total: aNumero(d['total']) ?? 0,
         horas: [for (final h in d['horas'] as List) aNumero(h) ?? 0],
         curva: [for (final c in d['curva'] as List) aNumero(c) ?? 0]),
    ];
    final elegibles = series.where((s) => s.total >= _minParaDestacar).toList();
    final mejor = elegibles.isEmpty ? null : elegibles.first.clave;
    final peor = elegibles.length > 1 ? elegibles.last.clave : null;

    var grises = 0;
    final estilos = {
      for (final s in series)
        s.clave: s.clave == mejor ? (color: _azul, ancho: 3.5, guiones: null as List<int>?)
            : s.clave == peor ? (color: CP.naranjaLogo, ancho: 3.5, guiones: null)
            : (color: _gris, ancho: 1.6, guiones: ++grises % 2 == 0 ? const [5, 4] : null),
    };
    final ordenDibujo = [...series.where((s) => s.clave != mejor && s.clave != peor), ...series.where((s) => s.clave == peor || s.clave == mejor)];
    final leyenda = [...series]..sort((a, b) => b.curva.last.compareTo(a.curva.last));

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(height: 240, child: LineChart(LineChartData(
        minX: 0, maxX: 12, minY: 0, maxY: 100,
        lineTouchData: const LineTouchData(enabled: false),
        gridData: FlGridData(drawVerticalLine: false, horizontalInterval: 25,
            getDrawingHorizontalLine: (_) => const FlLine(color: CP.borde, strokeWidth: 1, dashArray: [2, 4])),
        borderData: FlBorderData(show: false),
        extraLinesData: ExtraLinesData(verticalLines: [
          VerticalLine(x: _corteHoras, color: CP.apagado, strokeWidth: 1, dashArray: [4, 4],
              label: VerticalLineLabel(show: true, alignment: Alignment.topRight, style: _textoEje, labelResolver: (_) => '2 h')),
        ]),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, interval: 25,
              getTitlesWidget: (v, meta) => Text('${v.toInt()} %', style: _textoEje))),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24, interval: 2,
              getTitlesWidget: (v, meta) => Padding(padding: const EdgeInsets.only(top: 6),
                  child: Text('${v.toInt()} h', style: _textoEje)))),
        ),
        lineBarsData: [
          for (final s in ordenDibujo)
            LineChartBarData(
              spots: [for (var i = 0; i < s.horas.length && i < s.curva.length; i++) FlSpot(s.horas[i], s.curva[i])],
              isCurved: true, preventCurveOverShooting: true,
              color: estilos[s.clave]!.color, barWidth: estilos[s.clave]!.ancho, dashArray: estilos[s.clave]!.guiones,
              dotData: FlDotData(
                show: s.clave == mejor || s.clave == peor,
                checkToShowDot: (spot, _) => spot.x == _corteHoras,
                getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(radius: 4, color: estilos[s.clave]!.color,
                    strokeColor: Colors.white, strokeWidth: 1.5),
              ),
            ),
        ],
      ))),
      const SizedBox(height: 12),
      for (final s in leyenda) Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Container(width: 18, height: estilos[s.clave]!.ancho, color: estilos[s.clave]!.color),
          const SizedBox(width: 8),
          Expanded(child: Text(nombreCategoria(s.clave), style: TextStyle(fontSize: 13,
              fontWeight: estilos[s.clave]!.color == _gris ? FontWeight.w500 : FontWeight.w700))),
          Text(porcentaje(s.curva.last, 0), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
              color: estilos[s.clave]!.color == _gris ? CP.tinta : estilos[s.clave]!.color)),
        ]),
      ),
      const SizedBox(height: 6),
      Text('Azul: el servicio con mejor conversión · naranja: el peor (entre los que tienen al menos $_minParaDestacar solicitudes). '
          'Los puntos marcan el corte de 2 h. El porcentaje final es la tasa de conversión.',
          style: Theme.of(context).textTheme.bodySmall),
    ]);
  }
}
