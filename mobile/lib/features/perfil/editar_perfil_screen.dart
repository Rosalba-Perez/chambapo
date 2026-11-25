import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/selector_imagen.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../auth/auth_provider.dart';
import '../auth/registro_screen.dart' show oficiosDisponibles;

// Pantalla para editar el perfil
class EditarPerfilScreen extends ConsumerStatefulWidget {
  const EditarPerfilScreen({super.key});
  @override
  ConsumerState<EditarPerfilScreen> createState() => _EditarPerfilScreenState();
}

class _EditarPerfilScreenState extends ConsumerState<EditarPerfilScreen> {
  final _form = GlobalKey<FormState>();
  late final Perfil _p = ref.read(perfilProvider).value!;
  late final _nombre = TextEditingController(text: _p.nombre);
  late final _tel = TextEditingController(text: _p.telefono ?? '');
  late final _zona = TextEditingController(text: _p.zona ?? '');
  late final _descripcion = TextEditingController(text: _p.descripcion ?? '');
  late final Set<String> _oficios = {..._p.oficios};
  XFile? _foto, _cedulaFrente, _cedulaReverso, _certificado;
  bool _intentado = false;

  Future<void> _guardar() async {
    setState(() => _intentado = true);
    if (!_form.currentState!.validate() || (_p.esPrestador && _oficios.isEmpty)) {
      throw const ErrorConMensaje('Revisa los campos marcados en rojo.');
    }
    final repo = AuthRepository();
    await repo.actualizarPerfil(nombre: _nombre.text.trim(), telefono: _tel.text.replaceAll(RegExp(r'\D'), ''), foto: _foto,
        oficios: _p.esPrestador ? _oficios.toList() : null, zona: _zona.text, descripcion: _descripcion.text);
    if (_p.esPrestador && (_cedulaFrente != null || _cedulaReverso != null || _certificado != null)) {
      await repo.guardarArchivosPrestador(cedulaFrente: _cedulaFrente, cedulaReverso: _cedulaReverso, certificado: _certificado);
    }
    ref.invalidate(perfilProvider);
    if (!mounted) return;
    avisar(context, 'Guardamos los cambios de tu perfil.');
    context.pop();
  }

  @override
  void dispose() { for (final c in [_nombre, _tel, _zona, _descripcion]) { c.dispose(); } super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Editar perfil')),
      body: Form(key: _form, child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
        SelectorFotoPerfil(archivo: _foto, url: _p.fotoUrl, nombre: _p.nombre, alElegir: (f) => setState(() => _foto = f)),
        const SizedBox(height: 6),
        Text(_p.esPrestador ? 'Foto de perfil (obligatoria)' : 'Foto de perfil (opcional)', textAlign: TextAlign.center, style: tt.bodySmall),
        const SizedBox(height: 20),
        TextFormField(controller: _nombre, textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nombre completo', prefixIcon: Icon(Icons.person_outline)),
            validator: (v) => (v ?? '').trim().length < 3 ? 'Escribe tu nombre y apellido' : null),
        const SizedBox(height: 12),
        TextFormField(controller: _tel, keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Celular', prefixIcon: Icon(Icons.smartphone_outlined)),
            validator: (v) => (v ?? '').replaceAll(RegExp(r'\D'), '').length == 10 ? null : 'El celular debe tener 10 dígitos'),
        const SizedBox(height: 12),
        TextFormField(initialValue: _p.email, enabled: false,
            decoration: const InputDecoration(labelText: 'Correo (no se puede cambiar)', prefixIcon: Icon(Icons.mail_outline))),
        if (_p.esPrestador) ...[
          const EtiquetaSeccion('Tu trabajo'),
          Wrap(spacing: 8, runSpacing: 8, children: [for (final o in oficiosDisponibles) FilterChip(
            label: Text(nombreCategoria(o)), selected: _oficios.contains(o), labelStyle: estiloChip(_oficios.contains(o)),
            onSelected: (v) => setState(() => v ? _oficios.add(o) : _oficios.remove(o)))]),
          if (_intentado && _oficios.isEmpty) const Padding(padding: EdgeInsets.only(top: 6),
              child: Text('Elige al menos un oficio', style: TextStyle(color: CP.error, fontSize: 12, fontWeight: FontWeight.w600))),
          const SizedBox(height: 12),
          TextFormField(controller: _zona, decoration: const InputDecoration(labelText: 'Zona donde trabajas (opcional)',
              hintText: 'Ej.: Manga, Pie de la Popa, Centro', prefixIcon: Icon(Icons.map_outlined))),
          const SizedBox(height: 12),
          TextFormField(controller: _descripcion, maxLines: 3, minLines: 2, maxLength: 300,
              decoration: const InputDecoration(labelText: 'Sobre ti (opcional)', hintText: 'Años de experiencia, especialidades…')),
          const EtiquetaSeccion('Documentos'),
          CasillaImagen(titulo: 'Cédula · frente', archivo: _cedulaFrente, cargado: _p.documentoFrente != null,
              alElegir: (f) => setState(() => _cedulaFrente = f)),
          const SizedBox(height: 8),
          CasillaImagen(titulo: 'Cédula · reverso', archivo: _cedulaReverso, cargado: _p.documentoReverso != null,
              alElegir: (f) => setState(() => _cedulaReverso = f)),
          const SizedBox(height: 8),
          CasillaImagen(titulo: 'Certificado de oficio', obligatorio: false, archivo: _certificado, cargado: _p.certificado != null,
              alElegir: (f) => setState(() => _certificado = f)),
        ],
        const SizedBox(height: 24),
        BotonAsync(accion: _guardar, hijo: const Text('Guardar cambios')),
      ])),
    );
  }
}

class CompletarRegistroScreen extends ConsumerStatefulWidget {
  final Perfil perfil;
  const CompletarRegistroScreen(this.perfil, {super.key});
  @override
  ConsumerState<CompletarRegistroScreen> createState() => _CompletarRegistroScreenState();
}

class _CompletarRegistroScreenState extends ConsumerState<CompletarRegistroScreen> {
  XFile? _foto, _frente, _reverso, _certificado;
  bool _intentado = false, _subiendoAuto = false;
  String? _errorAuto;

  Perfil get _p => widget.perfil;

  @override
  void initState() {
    super.initState();
    final pendientes = archivosPendientes;
    final subida = subirArchivosPendientes();
    if (subida == null) return;
    if (pendientes != null) {
      _foto = pendientes.foto; _frente = pendientes.cedulaFrente;
      _reverso = pendientes.cedulaReverso; _certificado = pendientes.certificado;
    }
    _subiendoAuto = true;
    subida.then((_) {
      if (mounted) ref.invalidate(perfilProvider);
    }, onError: (Object e) {
      if (mounted) setState(() { _subiendoAuto = false; _errorAuto = mensajeError(e); });
    });
  }

  Future<void> _enviar() async {
    setState(() => _intentado = true);
    if ((_p.fotoUrl == null && _foto == null) || (_p.documentoFrente == null && _frente == null) ||
        (_p.documentoReverso == null && _reverso == null)) {
      throw const ErrorConMensaje('Falta subir los documentos marcados en rojo.');
    }
    await AuthRepository().guardarArchivosPrestador(foto: _foto, cedulaFrente: _frente, cedulaReverso: _reverso, certificado: _certificado);
    prepararArchivosRegistro(null);
    if (mounted) ref.invalidate(perfilProvider);
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    if (_subiendoAuto) {
      return Scaffold(body: SafeArea(child: Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(
        mainAxisSize: MainAxisSize.min, children: [
          const LogoLinea(),
          const SizedBox(height: 28),
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text('Subiendo tus documentos…', style: tt.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text('Tu cuenta ya está creada. Estamos guardando tu foto y tu cédula; tarda unos segundos.',
              style: tt.bodyMedium, textAlign: TextAlign.center),
        ])))));
    }
    return Scaffold(body: SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(24, 24, 24, 24), children: [
      if (_errorAuto != null) ...[
        Aviso(TipoAviso.error, 'No pudimos subir tus documentos', texto: '$_errorAuto Ya están elegidos: toca «Enviar y continuar» para reintentar.'),
        const SizedBox(height: 16),
      ],
      const Center(child: LogoLinea()),
      const SizedBox(height: 20),
      Text('Completa tu registro', style: tt.headlineSmall, textAlign: TextAlign.center),
      const SizedBox(height: 6),
      Text('Hola, ${_p.primerNombre}. Para verificarte y que los clientes confíen en ti necesitamos tu foto y tu cédula.',
          style: tt.bodyMedium, textAlign: TextAlign.center),
      const SizedBox(height: 20),
      SelectorFotoPerfil(archivo: _foto, url: _p.fotoUrl, nombre: _p.nombre, error: _intentado && _p.fotoUrl == null && _foto == null,
          alElegir: (f) => setState(() => _foto = f)),
      const SizedBox(height: 6),
      Text('Foto de perfil', textAlign: TextAlign.center, style: tt.bodySmall),
      const SizedBox(height: 20),
      CasillaImagen(titulo: 'Cédula · frente', archivo: _frente, cargado: _p.documentoFrente != null,
          error: _intentado && _p.documentoFrente == null && _frente == null, alElegir: (f) => setState(() => _frente = f)),
      const SizedBox(height: 8),
      CasillaImagen(titulo: 'Cédula · reverso', archivo: _reverso, cargado: _p.documentoReverso != null,
          error: _intentado && _p.documentoReverso == null && _reverso == null, alElegir: (f) => setState(() => _reverso = f)),
      const SizedBox(height: 8),
      CasillaImagen(titulo: 'Certificado de oficio', obligatorio: false, archivo: _certificado, cargado: _p.certificado != null,
          ayuda: 'SENA, curso o certificación: da más confianza', alElegir: (f) => setState(() => _certificado = f)),
      const SizedBox(height: 12),
      const Aviso(TipoAviso.informacion, 'Tus documentos son privados', texto: 'Solo los ve el equipo de Chambapo para verificarte.'),
      const SizedBox(height: 20),
      BotonAsync(accion: _enviar, hijo: const Text('Enviar y continuar')),
      const SizedBox(height: 8),
      OutlinedButton(style: estiloFantasma, onPressed: () => AuthRepository().salir(), child: const Text('Cerrar sesión')),
    ])));
  }
}
