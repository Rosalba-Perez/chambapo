import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/selector_imagen.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'auth_provider.dart';

const oficiosDisponibles = ['plomeria', 'electricidad', 'aire_acondicionado', 'electrodomesticos', 'pintura', 'cerrajeria', 'carpinteria', 'albanileria'];

// Pantalla para crear una cuenta como cliente o como técnico
class RegistroScreen extends ConsumerStatefulWidget {
  final String? rolInicial;
  const RegistroScreen({super.key, this.rolInicial});
  @override
  ConsumerState<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends ConsumerState<RegistroScreen> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController(), _email = TextEditingController(),
      _clave = TextEditingController(), _tel = TextEditingController();
  late String _rol = widget.rolInicial == 'prestador' ? 'prestador' : 'cliente';
  final Set<String> _oficios = {};
  XFile? _foto, _cedulaFrente, _cedulaReverso, _certificado;
  bool _acepta = false, _enviando = false, _verClave = false, _intentado = false;
  String? _error, _errorEmail;

  bool get _esPrestador => _rol == 'prestador';

  @override
  void initState() {
    super.initState();
    for (final c in [_nombre, _email, _clave, _tel]) { c.addListener(() => setState(() {})); }
  }

  List<String> get _faltantes => [
    if (_nombre.text.trim().length < 3) 'tu nombre',
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim())) 'un correo válido',
    if (_tel.text.replaceAll(RegExp(r'\D'), '').length != 10) 'tu celular de 10 dígitos',
    if (_clave.text.length < 6) 'una contraseña de 6 caracteres o más',
    if (_esPrestador && _oficios.isEmpty) 'al menos un oficio',
    if (_esPrestador && _foto == null) 'tu foto de perfil',
    if (_esPrestador && _cedulaFrente == null) 'la cédula por el frente',
    if (_esPrestador && _cedulaReverso == null) 'la cédula por el reverso',
    if (!_acepta) 'autorizar el tratamiento de tus datos',
  ];

  static String _enLista(List<String> l) => l.length == 1 ? l.first : '${l.sublist(0, l.length - 1).join(', ')} y ${l.last}';

  Future<void> _registrar() async {
    setState(() { _intentado = true; _error = null; _errorEmail = null; });
    if (!_form.currentState!.validate() || _faltantes.isNotEmpty) return;
    setState(() => _enviando = true);
    prepararArchivosRegistro(_esPrestador
        ? ArchivosRegistro(foto: _foto!, cedulaFrente: _cedulaFrente!, cedulaReverso: _cedulaReverso!, certificado: _certificado)
        : null);
    try {
      await AuthRepository().registrar(email: _email.text.trim(), clave: _clave.text, nombre: _nombre.text.trim(),
          rol: _rol, telefono: _tel.text.replaceAll(RegExp(r'\D'), ''), oficios: _oficios.toList());
      if (!mounted) return;
      ref.invalidate(perfilProvider);
      context.go('/');
    } catch (e) {
      if (supabase.auth.currentSession == null) prepararArchivosRegistro(null);
      if (!mounted) return;
      final m = mensajeError(e);
      setState(() {
        if (m == 'Este correo ya está registrado.' || m == 'Escribe un correo válido.') {
          _errorEmail = m;
        } else {
          _error = m;
        }
      });
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  void dispose() { for (final c in [_nombre, _email, _clave, _tel]) { c.dispose(); } super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.canPop() ? context.pop() : context.go('/bienvenida')),
        titleSpacing: 0, title: const LogoLinea(),
      ),
      body: Form(key: _form, autovalidateMode: AutovalidateMode.onUserInteraction, child: ListView(padding: const EdgeInsets.fromLTRB(24, 4, 24, 24), children: [
        Text('Crear cuenta', style: tt.headlineSmall),
        const SizedBox(height: 4),
        Text('Completa tus datos para empezar.', style: tt.bodyMedium),
        const SizedBox(height: 16),
        _SelectorRol(rol: _rol, onCambio: (r) => setState(() => _rol = r)),
        const SizedBox(height: 16),
        if (_error != null) ...[Aviso(TipoAviso.error, _error!), const SizedBox(height: 14)],
        TextFormField(
          controller: _nombre, textCapitalization: TextCapitalization.words, textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
          decoration: const InputDecoration(labelText: 'Nombre completo', prefixIcon: Icon(Icons.person_outline)),
          validator: (v) => (v ?? '').trim().length < 3 ? 'Escribe tu nombre y apellido' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _email, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          onChanged: (_) { if (_errorEmail != null) setState(() => _errorEmail = null); },
          decoration: InputDecoration(labelText: 'Correo electrónico', prefixIcon: const Icon(Icons.mail_outline),
              errorText: _errorEmail),
          validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch((v ?? '').trim()) ? null : 'Escribe un correo válido',
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _tel, keyboardType: TextInputType.phone, textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.telephoneNumber],
          decoration: const InputDecoration(labelText: 'Celular', hintText: '301 013 5790', prefixIcon: Icon(Icons.smartphone_outlined)),
          validator: (v) => (v ?? '').replaceAll(RegExp(r'\D'), '').length == 10 ? null : 'El celular debe tener 10 dígitos',
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _clave, obscureText: !_verClave, autofillHints: const [AutofillHints.newPassword],
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: 'Contraseña', prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(tooltip: _verClave ? 'Ocultar contraseña' : 'Mostrar contraseña',
                  icon: Icon(_verClave ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  onPressed: () => setState(() => _verClave = !_verClave))),
          validator: (v) => (v ?? '').length < 6 ? 'La contraseña debe tener al menos 6 caracteres' : null,
        ),
        const SizedBox(height: 6),
        Row(children: [
          Icon(Icons.check, size: 16, color: _clave.text.length >= 6 ? CP.exito : CP.apagado),
          const SizedBox(width: 4),
          Text('Mínimo 6 caracteres', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
              color: _clave.text.length >= 6 ? CP.exito : CP.apagado)),
        ]),
        if (_esPrestador) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFFCEFE8), borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _intentado && _oficios.isEmpty ? CP.error : Colors.transparent, width: 1.5)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text.rich(TextSpan(children: [
                const TextSpan(text: '¿Qué oficios haces? ', style: TextStyle(fontWeight: FontWeight.w700, color: CP.tinta)),
                TextSpan(text: '(elige al menos uno)', style: tt.bodySmall),
              ])),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: oficiosDisponibles.map((o) => FilterChip(
                label: Text(nombreCategoria(o)), selected: _oficios.contains(o), labelStyle: estiloChip(_oficios.contains(o)),
                onSelected: (v) => setState(() => v ? _oficios.add(o) : _oficios.remove(o)),
              )).toList()),
              if (_intentado && _oficios.isEmpty) const Padding(padding: EdgeInsets.only(top: 8),
                  child: Text('Elige al menos un oficio', style: TextStyle(color: CP.error, fontSize: 12, fontWeight: FontWeight.w600))),
            ]),
          ),
          const SizedBox(height: 18),
          Text('Tu foto de perfil', style: tt.titleSmall),
          const SizedBox(height: 4),
          Text('Obligatoria: los clientes la ven antes de elegirte. Que se vea bien tu cara.', style: tt.bodySmall),
          const SizedBox(height: 10),
          SelectorFotoPerfil(archivo: _foto, nombre: _nombre.text, error: _intentado && _foto == null,
              alElegir: (f) => setState(() => _foto = f)),
          if (_intentado && _foto == null) const Padding(padding: EdgeInsets.only(top: 6),
              child: Text('Agrega tu foto de perfil', textAlign: TextAlign.center,
                  style: TextStyle(color: CP.error, fontSize: 12, fontWeight: FontWeight.w600))),
          const SizedBox(height: 18),
          Text('Documentos para verificarte', style: tt.titleSmall),
          const SizedBox(height: 4),
          Text('Solo los ve el equipo de Chambapo. Toma la foto con buena luz y que se lea completa.', style: tt.bodySmall),
          const SizedBox(height: 10),
          CasillaImagen(titulo: 'Cédula · frente', archivo: _cedulaFrente, error: _intentado && _cedulaFrente == null,
              alElegir: (f) => setState(() => _cedulaFrente = f)),
          const SizedBox(height: 8),
          CasillaImagen(titulo: 'Cédula · reverso', archivo: _cedulaReverso, error: _intentado && _cedulaReverso == null,
              alElegir: (f) => setState(() => _cedulaReverso = f)),
          const SizedBox(height: 8),
          CasillaImagen(titulo: 'Certificado de oficio', obligatorio: false, archivo: _certificado,
              ayuda: 'SENA, curso o certificación: da más confianza', alElegir: (f) => setState(() => _certificado = f)),
          const SizedBox(height: 10),
          const Aviso(TipoAviso.informacion, 'Revisamos tu perfil',
              texto: 'Un administrador verifica tu identidad antes de que puedas enviar ofertas.'),
        ],
        const SizedBox(height: 14),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Checkbox(value: _acepta, onChanged: (v) => setState(() => _acepta = v ?? false),
              isError: _intentado && !_acepta),
          Expanded(child: GestureDetector(
            onTap: () => setState(() => _acepta = !_acepta),
            child: Padding(padding: const EdgeInsets.only(top: 12), child: Text.rich(TextSpan(
              style: TextStyle(fontSize: 12, height: 1.35, color: _intentado && !_acepta ? CP.error : CP.texto2),
              children: const [
                TextSpan(text: 'Autorizo el tratamiento de mis datos según la Ley 1581 de 2012 y acepto los '),
                TextSpan(text: 'términos de uso', style: TextStyle(fontWeight: FontWeight.w700, color: CP.verde)),
                TextSpan(text: '.'),
              ],
            ))),
          )),
        ]),
        const SizedBox(height: 18),
        FilledButton(onPressed: _enviando || _faltantes.isNotEmpty ? null : _registrar,
            child: _enviando ? cargandoBoton : Text(_esPrestador ? 'Crear cuenta de prestador' : 'Crear cuenta')),
        if (!_enviando && _faltantes.isNotEmpty) Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.info_outline, size: 16, color: CP.apagado),
            const SizedBox(width: 6),
            Expanded(child: Text('Para crear la cuenta falta: ${_enLista(_faltantes)}.', style: tt.bodySmall)),
          ]),
        ),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('¿Ya tienes cuenta?', style: tt.bodyMedium),
          TextButton(onPressed: () => context.pushReplacement('/login'), child: const Text('Inicia sesión')),
        ]),
      ])),
    );
  }
}

class _SelectorRol extends StatelessWidget {
  final String rol;
  final ValueChanged<String> onCambio;
  const _SelectorRol({required this.rol, required this.onCambio});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(color: CP.fondoApp, borderRadius: BorderRadius.circular(14), border: Border.all(color: CP.borde)),
    child: Row(children: [
      for (final (valor, texto) in [('cliente', 'Necesito un servicio'), ('prestador', 'Ofrezco mi oficio')])
        Expanded(child: Semantics(selected: rol == valor, button: true, child: GestureDetector(
          onTap: () => onCambio(valor),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 44, alignment: Alignment.center,
            decoration: BoxDecoration(
              color: rol == valor ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(11),
              boxShadow: rol == valor ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2))] : null,
            ),
            child: Text(texto, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                color: rol == valor ? CP.verde : CP.apagado)),
          ),
        ))),
    ]),
  );
}
