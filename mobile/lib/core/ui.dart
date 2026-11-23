import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'api_client.dart';
import 'theme.dart';

final estiloSecundario = FilledButton.styleFrom(backgroundColor: CP.verde, foregroundColor: Colors.white);
final estiloOscuro = FilledButton.styleFrom(backgroundColor: CP.tinta, foregroundColor: Colors.white);
final estiloDestructivo = FilledButton.styleFrom(backgroundColor: CP.error, foregroundColor: Colors.white);
final estiloFantasma = OutlinedButton.styleFrom(foregroundColor: CP.tinta, side: const BorderSide(color: CP.borde, width: 1.5));
final estiloContornoClaro = OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white70, width: 1.5));

const cargandoBoton = SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: CP.desactivadoTexto));

// Botón que muestra que está cargando mientras espera respuesta
class BotonAsync extends StatefulWidget {
  final Future<void> Function() accion;
  final Widget hijo;
  final ButtonStyle? estilo;
  final bool contorno;
  final Widget? icono;
  const BotonAsync({super.key, required this.accion, required this.hijo, this.estilo, this.contorno = false, this.icono});
  @override
  State<BotonAsync> createState() => _BotonAsyncState();
}

class _BotonAsyncState extends State<BotonAsync> {
  bool _ocupado = false;
  Future<void> _ejecutar() async {
    setState(() => _ocupado = true);
    try {
      await widget.accion();
    } catch (e) {
      if (mounted) avisar(context, mensajeError(e));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hijo = _ocupado ? cargandoBoton : widget.hijo;
    final onPressed = _ocupado ? null : _ejecutar;
    if (widget.contorno) {
      return widget.icono == null
          ? OutlinedButton(style: widget.estilo, onPressed: onPressed, child: hijo)
          : OutlinedButton.icon(style: widget.estilo, onPressed: onPressed, icon: widget.icono!, label: hijo);
    }
    return widget.icono == null
        ? FilledButton(style: widget.estilo, onPressed: onPressed, child: hijo)
        : FilledButton.icon(style: widget.estilo, onPressed: onPressed, icon: widget.icono!, label: hijo);
  }
}

class LogoChambapo extends StatelessWidget {
  final double tam;
  final bool texto, claro;
  const LogoChambapo({super.key, this.tam = 56, this.texto = true, this.claro = false});
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    Container(
      width: tam, height: tam,
      decoration: BoxDecoration(color: CP.naranjaLogo, borderRadius: BorderRadius.circular(tam * 0.28),
          boxShadow: [BoxShadow(color: CP.naranjaLogo.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6))]),
      child: Icon(Icons.build_rounded, color: Colors.white, size: tam * 0.5),
    ),
    if (texto) ...[
      SizedBox(height: tam * 0.2),
      Text('chambapo', style: estiloTitulo.copyWith(fontSize: tam * 0.62, color: claro ? Colors.white : CP.verde)),
    ],
  ]);
}

class LogoLinea extends StatelessWidget {
  const LogoLinea({super.key});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 24, height: 24, decoration: BoxDecoration(color: CP.naranjaLogo, borderRadius: BorderRadius.circular(7)),
        child: const Icon(Icons.build_rounded, color: Colors.white, size: 14)),
    const SizedBox(width: 6),
    Text('chambapo', style: estiloTitulo.copyWith(fontSize: 18, color: CP.verde)),
  ]);
}

enum TipoAviso { error, advertencia, informacion }

// Aviso que explica qué pasó y qué hacer
class Aviso extends StatelessWidget {
  final TipoAviso tipo;
  final String titulo;
  final String? texto;
  final Widget? accion;
  const Aviso(this.tipo, this.titulo, {super.key, this.texto, this.accion});
  @override
  Widget build(BuildContext context) {
    final (color, fondo, icono) = switch (tipo) {
      TipoAviso.error => (CP.error, CP.errorFondo, Icons.error_outline),
      TipoAviso.advertencia => (CP.advertencia, CP.advertenciaFondo, Icons.warning_amber_rounded),
      TipoAviso.informacion => (CP.verde, CP.seleccion, Icons.info_outline),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.35))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icono, color: color, size: 20), const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titulo, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14)),
          if (texto != null) Padding(padding: const EdgeInsets.only(top: 2),
              child: Text(texto!, style: const TextStyle(color: CP.texto2, fontSize: 13, height: 1.35))),
          if (accion != null) Padding(padding: const EdgeInsets.only(top: 6), child: accion!),
        ])),
      ]),
    );
  }
}

void avisar(BuildContext context, String texto, {VoidCallback? reintentar}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texto),
        action: reintentar == null ? null : SnackBarAction(label: 'Reintentar', onPressed: reintentar)));
}

// Ventana para que el usuario confirme una acción
Future<bool> confirmar(BuildContext context, {required String titulo, required String mensaje,
    required String si, String no = 'Volver', bool destructivo = false}) async {
  final r = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
    title: Text(titulo), content: Text(mensaje),
    actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
    actions: [Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      FilledButton(style: destructivo ? estiloDestructivo : null, onPressed: () => Navigator.pop(ctx, true), child: Text(si)),
      const SizedBox(height: 8),
      OutlinedButton(style: estiloFantasma, onPressed: () => Navigator.pop(ctx, false), child: Text(no)),
    ])],
  ));
  return r ?? false;
}

TextStyle estiloChip(bool seleccionado) => TextStyle(fontFamily: 'Figtree', fontSize: 13, fontWeight: FontWeight.w600,
    color: seleccionado ? Colors.white : CP.tinta);

Future<String?> pedirCancelacion(BuildContext context, {required String titulo, required String mensaje,
    String si = 'Sí, cancelar', String no = 'Volver'}) {
  final motivo = TextEditingController();
  return showDialog<String>(context: context, builder: (ctx) => AlertDialog(
    title: Text(titulo),
    content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(mensaje),
      const SizedBox(height: 14),
      TextField(controller: motivo, maxLength: 300, maxLines: 3, minLines: 2, textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Motivo (opcional)', hintText: 'Ej.: ya lo resolví, me cambió el horario…')),
    ]),
    actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
    actions: [Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      FilledButton(style: estiloDestructivo, onPressed: () => Navigator.pop(ctx, motivo.text.trim()), child: Text(si)),
      const SizedBox(height: 8),
      OutlinedButton(style: estiloFantasma, onPressed: () => Navigator.pop(ctx), child: Text(no)),
    ])],
  ));
}

// Sirve para convertir los errores en mensajes fáciles de entender
String mensajeError(Object e) {
  if (e is ApiException) {
    if (e.codigo == null) return 'Sin conexión con el servidor. Revisa tu internet e inténtalo de nuevo.';
    if (e.codigo! >= 500) return 'Tuvimos un problema en el servidor. Inténtalo de nuevo en un momento.';
    if (e.codigo == 401) return 'Tu sesión expiró. Vuelve a iniciar sesión.';
    if (e.codigo == 403) return 'Tu cuenta no tiene permiso para esta acción.';
    return e.mensaje == 'Error' ? 'Revisa los datos e inténtalo de nuevo.' : e.mensaje;
  }
  if (e is AuthException) return mensajeAuth(e);
  if (e is PostgrestException) {
    if (e.code == '23505') return 'Esto ya quedó registrado.';
    if (e.code == '42501') return 'Tu cuenta no tiene permiso para esta acción.';
    return 'No pudimos completar la operación. Inténtalo de nuevo.';
  }
  if (e is ErrorConMensaje) return e.mensaje;
  return 'Algo salió mal. Inténtalo de nuevo.';
}

String mensajeAuth(AuthException e) {
  final c = e.code ?? '';
  final m = e.message.toLowerCase();
  if (e is AuthRetryableFetchException || m.contains('failed host lookup') || m.contains('socket') || m.contains('connection')) {
    return 'Sin conexión. Revisa tu internet e inténtalo de nuevo.';
  }
  if (c == 'invalid_credentials' || m.contains('invalid login')) return 'Correo o contraseña incorrectos.';
  if (c == 'user_already_exists' || c == 'email_exists' || m.contains('already registered')) return 'Este correo ya está registrado.';
  if (c == 'weak_password' || m.contains('password should')) return 'La contraseña debe tener al menos 6 caracteres.';
  if (c == 'email_not_confirmed' || m.contains('not confirmed')) return 'Confirma tu correo antes de entrar. Revisa tu bandeja de entrada.';
  if (c == 'email_address_invalid' || (m.contains('invalid') && m.contains('email'))) return 'Escribe un correo válido.';
  if (c.startsWith('over_') || m.contains('rate limit')) return 'Demasiados intentos. Espera un momento y vuelve a intentarlo.';
  return 'No pudimos completar la operación. Inténtalo de nuevo.';
}

class ErrorConMensaje implements Exception {
  final String mensaje;
  const ErrorConMensaje(this.mensaje);
  @override
  String toString() => mensaje;
}

String pesos(num? valor) {
  if (valor == null) return '';
  final s = valor.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return '\$$b';
}

String hace(DateTime fecha) {
  final d = DateTime.now().difference(fecha.toLocal());
  if (d.inMinutes < 1) return 'ahora';
  if (d.inMinutes < 60) return 'hace ${d.inMinutes} min';
  if (d.inHours < 24) return 'hace ${d.inHours} h';
  return d.inDays == 1 ? 'hace 1 día' : 'hace ${d.inDays} días';
}

String horaCorta(DateTime fecha) {
  final f = fecha.toLocal();
  return '${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}';
}

String iniciales(String nombre) {
  final p = nombre.trim().split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
  if (p.isEmpty) return '?';
  return (p.first[0] + (p.length > 1 ? p[1][0] : '')).toUpperCase();
}

String nombreCategoria(String n) => const {
  'plomeria': 'Plomería', 'electricidad': 'Electricidad', 'aire_acondicionado': 'Aire acondicionado',
  'electrodomesticos': 'Electrodomésticos', 'pintura': 'Pintura', 'cerrajeria': 'Cerrajería',
  'carpinteria': 'Carpintería', 'albanileria': 'Albañilería', 'otros': 'Otros arreglos',
}[n] ?? n.replaceAll('_', ' ');

(Color, Color) colorCategoria(String n) => switch (n) {
  'plomeria' => (const Color(0xFF1D5E7A), const Color(0xFFE1EEF3)),
  'electricidad' => (const Color(0xFF8A5300), const Color(0xFFFBEBD3)),
  'aire_acondicionado' => (const Color(0xFF0E5C5A), const Color(0xFFE0F0EC)),
  'electrodomesticos' => (const Color(0xFF5B3E8A), const Color(0xFFECE6F4)),
  'pintura' => (const Color(0xFFA33A12), const Color(0xFFFBE3D8)),
  'cerrajeria' => (const Color(0xFF2E3A36), const Color(0xFFE6EAE8)),
  _ => (CP.verde, CP.seleccion),
};

IconData iconoCategoria(String n) => switch (n) {
  'plomeria' => Icons.water_drop_outlined,
  'electricidad' => Icons.bolt_outlined,
  'aire_acondicionado' => Icons.ac_unit,
  'electrodomesticos' => Icons.local_laundry_service_outlined,
  'pintura' => Icons.format_paint_outlined,
  'cerrajeria' => Icons.key_outlined,
  'carpinteria' => Icons.carpenter_outlined,
  'albanileria' => Icons.foundation_outlined,
  'otros' => Icons.home_repair_service_outlined,
  _ => Icons.handyman_outlined,
};

String nombreEstado(String e) => const {
  'publicada': 'Buscando', 'con_postulaciones': 'Con ofertas', 'asignada': 'Asignada', 'en_camino': 'En camino',
  'en_curso': 'En curso', 'finalizada': 'Finalizada', 'cancelada': 'Cancelada', 'expirada': 'Expirada',
}[e] ?? e.replaceAll('_', ' ');

class ChipEstado extends StatelessWidget {
  final String texto;
  final Color fondo, color;
  const ChipEstado(this.texto, {super.key, this.fondo = CP.seleccion, this.color = CP.verde});

  factory ChipEstado.deSolicitud(String estado, {bool sobreOscuro = false, bool enRevision = false}) =>
      enRevision && estado != 'cancelada' && estado != 'finalizada'
          ? const ChipEstado('En revisión', fondo: CP.advertenciaFondo, color: CP.advertencia)
          : _deEstado(estado, sobreOscuro);

  static ChipEstado _deEstado(String estado, bool sobreOscuro) => switch (estado) {
    'con_postulaciones' => ChipEstado(nombreEstado(estado), fondo: CP.naranjaSuave, color: CP.tinta),
    'publicada' => ChipEstado(nombreEstado(estado), fondo: sobreOscuro ? Colors.white24 : CP.seleccion,
        color: sobreOscuro ? Colors.white : CP.verde),
    'cancelada' || 'expirada' => ChipEstado(nombreEstado(estado), fondo: CP.errorFondo, color: CP.error),
    'finalizada' => ChipEstado(nombreEstado(estado), fondo: CP.fondoApp, color: CP.apagado),
    _ => ChipEstado(nombreEstado(estado), fondo: CP.seleccion, color: CP.verde),
  };

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(999)),
    child: Text(texto, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
  );
}

// Muestra la foto de perfil o, si no hay, las iniciales del nombre
class AvatarIniciales extends StatelessWidget {
  final String nombre;
  final double tam;
  final Color color;
  final String? foto;
  const AvatarIniciales(this.nombre, {super.key, this.tam = 44, this.color = CP.verde, this.foto});
  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: tam / 2, backgroundColor: color,
    foregroundImage: foto == null ? null : NetworkImage(foto!),
    onForegroundImageError: foto == null ? null : (_, __) {},
    child: Text(iniciales(nombre), style: estiloTitulo.copyWith(color: Colors.white, fontSize: tam * 0.36)),
  );
}

class EtiquetaSeccion extends StatelessWidget {
  final String texto;
  final Widget? accion;
  const EtiquetaSeccion(this.texto, {super.key, this.accion});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 10),
    child: Row(children: [
      Expanded(child: Text(texto, style: Theme.of(context).textTheme.titleMedium)),
      if (accion != null) accion!,
    ]),
  );
}

class ErrorPantalla extends StatelessWidget {
  final String mensaje;
  final VoidCallback? reintentar;
  const ErrorPantalla(this.mensaje, {super.key, this.reintentar});
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 64, height: 64, decoration: const BoxDecoration(color: CP.errorFondo, shape: BoxShape.circle),
          child: const Icon(Icons.cloud_off_outlined, color: CP.error, size: 32)),
      const SizedBox(height: 16),
      Text('No pudimos cargar esto', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
      const SizedBox(height: 8),
      Text(mensaje, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
      if (reintentar != null) ...[
        const SizedBox(height: 20),
        FilledButton(style: estiloSecundario, onPressed: reintentar, child: const Text('Reintentar')),
      ],
    ]),
  ));
}

// Mensaje que se muestra cuando no hay nada que ver
class Vacio extends StatelessWidget {
  final IconData icono;
  final String titulo, texto;
  const Vacio(this.icono, this.titulo, this.texto, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
    child: Column(children: [
      Container(width: 64, height: 64, decoration: const BoxDecoration(color: CP.seleccion, shape: BoxShape.circle),
          child: Icon(icono, color: CP.verde, size: 30)),
      const SizedBox(height: 14),
      Text(titulo, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
      const SizedBox(height: 4),
      Text(texto, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
    ]),
  );
}
