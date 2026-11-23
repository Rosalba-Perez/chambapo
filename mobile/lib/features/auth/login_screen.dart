import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'auth_provider.dart';

// Pantalla para iniciar sesión
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(), _clave = TextEditingController();
  String? _error;
  bool _cargando = false, _verClave = false, _credencialesMal = false;

  Future<void> _entrar() async {
    setState(() { _error = null; _credencialesMal = false; });
    if (!_form.currentState!.validate()) return;
    setState(() => _cargando = true);
    try {
      await AuthRepository().login(_email.text.trim(), _clave.text);
      if (mounted) context.go('/');
    } catch (e) {
      final m = mensajeError(e);
      setState(() { _error = m; _credencialesMal = m.startsWith('Correo o contraseña'); });
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  void dispose() { _email.dispose(); _clave.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      body: ListView(padding: EdgeInsets.zero, children: [
        SizedBox(height: 230, child: Stack(children: [
          const Positioned.fill(child: CustomPaint(painter: _MapaDecorativo())),
          Positioned(top: MediaQuery.paddingOf(context).top + 4, left: 4,
              child: BackButton(onPressed: () => context.canPop() ? context.pop() : context.go('/bienvenida'))),
          const Align(alignment: Alignment(0, 0.55), child: Column(mainAxisSize: MainAxisSize.min, children: [
            LogoChambapo(tam: 52),
            SizedBox(height: 2),
            Text('El técnico que necesitas, cerca de tu casa', style: TextStyle(color: CP.apagado, fontSize: 12)),
          ])),
        ])),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Form(key: _form, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Iniciar sesión', style: tt.headlineSmall),
            const SizedBox(height: 4),
            Text('Ingresa con tu correo para continuar.', style: tt.bodyMedium),
            const SizedBox(height: 18),
            if (_error != null) ...[
              Aviso(TipoAviso.error, _error!,
                  texto: _credencialesMal ? 'Revisa los datos e inténtalo otra vez.' : null),
              const SizedBox(height: 14),
            ],
            TextFormField(
              controller: _email, keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Correo electrónico', prefixIcon: Icon(Icons.mail_outline)),
              validator: (v) => (v ?? '').trim().contains('@') ? null : 'Escribe tu correo electrónico',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _clave, obscureText: !_verClave, autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _entrar(),
              decoration: InputDecoration(
                labelText: 'Contraseña', prefixIcon: const Icon(Icons.lock_outline),
                errorText: _credencialesMal ? 'Contraseña o correo incorrectos' : null,
                suffixIcon: IconButton(tooltip: _verClave ? 'Ocultar contraseña' : 'Mostrar contraseña',
                    icon: Icon(_verClave ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    onPressed: () => setState(() => _verClave = !_verClave)),
              ),
              validator: (v) => (v ?? '').isEmpty ? 'Escribe tu contraseña' : null,
            ),
            const SizedBox(height: 22),
            DecoratedBox(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), boxShadow: [
                BoxShadow(color: CP.naranja.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6))]),
              child: FilledButton(onPressed: _cargando ? null : _entrar,
                  child: _cargando ? cargandoBoton : const Text('Ingresar')),
            ),
            const SizedBox(height: 20),
            Row(children: [
              const Expanded(child: Divider()),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('¿Eres técnico u ofreces un oficio?', style: tt.bodySmall)),
              const Expanded(child: Divider()),
            ]),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              icon: const Icon(Icons.build_outlined, size: 18),
              onPressed: () => context.push('/registro?rol=prestador'),
              label: const Text('Regístrate como prestador'),
            ),
            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('¿No tienes cuenta?', style: tt.bodyMedium),
              TextButton(onPressed: () => context.push('/registro'), child: const Text('Regístrate')),
            ]),
          ])),
        ),
      ]),
    );
  }
}

class _MapaDecorativo extends CustomPainter {
  const _MapaDecorativo();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFE7EDE9));
    final calle = Paint()..color = Colors.white..strokeWidth = 14;
    canvas.drawLine(Offset(0, size.height * 0.30), Offset(size.width, size.height * 0.12), calle);
    canvas.drawLine(Offset(size.width * 0.18, 0), Offset(size.width * 0.32, size.height), calle);
    canvas.drawLine(Offset(size.width * 0.70, 0), Offset(size.width * 0.82, size.height), calle..strokeWidth = 10);
    canvas.drawLine(Offset(0, size.height * 0.78), Offset(size.width, size.height * 0.66), calle..strokeWidth = 8);
    final radar = Paint()..style = PaintingStyle.stroke..color = CP.naranjaLogo.withValues(alpha: 0.25)..strokeWidth = 1.2;
    final c = Offset(size.width * 0.76, size.height * 0.30);
    canvas.drawCircle(c, 26, radar);
    canvas.drawCircle(c, 46, radar..color = CP.naranjaLogo.withValues(alpha: 0.14));
    canvas.drawCircle(c, 5, Paint()..color = CP.naranja);
    canvas.drawRect(Rect.fromLTWH(0, size.height * 0.55, size.width, size.height * 0.45), Paint()
      ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Colors.white.withValues(alpha: 0), Colors.white])
          .createShader(Rect.fromLTWH(0, size.height * 0.55, size.width, size.height * 0.45)));
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
