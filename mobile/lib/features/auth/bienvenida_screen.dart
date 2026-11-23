import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';

// Pantalla de bienvenida de la app
class BienvenidaScreen extends StatelessWidget {
  const BienvenidaScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: CP.verde,
    body: Stack(children: [
      const Positioned.fill(child: CustomPaint(painter: _Ondas())),
      SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Spacer(flex: 3),
          const LogoChambapo(tam: 72, claro: true),
          const SizedBox(height: 14),
          const Text('El técnico que necesitas,\ncerca de tu casa', textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.4)),
          const Spacer(flex: 4),
          FilledButton(onPressed: () => context.push('/login'), child: const Text('Iniciar sesión')),
          const SizedBox(height: 12),
          OutlinedButton(style: estiloContornoClaro, onPressed: () => context.push('/registro'), child: const Text('Crear cuenta')),
          const SizedBox(height: 16),
          const Text('Al continuar aceptas los términos de uso y el tratamiento de datos según la Ley 1581 de 2012.',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.35)),
        ]),
      )),
    ]),
  );
}

class _Ondas extends CustomPainter {
  const _Ondas();
  @override
  void paint(Canvas canvas, Size size) {
    final centro = Offset(size.width / 2, size.height * 0.38);
    final linea = Paint()..style = PaintingStyle.stroke..color = Colors.white.withValues(alpha: 0.07)..strokeWidth = 1.2;
    for (final r in [90.0, 150.0, 220.0, 300.0]) { canvas.drawCircle(centro, r, linea); }
    canvas.drawCircle(centro + const Offset(110, -105), 5, Paint()..color = CP.naranjaLogo);
    canvas.drawCircle(centro + const Offset(-138, 12), 3.5, Paint()..color = Colors.white.withValues(alpha: 0.35));
    canvas.drawCircle(centro + const Offset(60, 95), 3, Paint()..color = Colors.white.withValues(alpha: 0.25));
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
