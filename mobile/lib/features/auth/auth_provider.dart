import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/almacenamiento.dart';
import '../../core/supabase_client.dart';
import '../../core/ui.dart';

class Perfil {
  final String id, rol, nombre, email;
  final String? telefono, fotoUrl;
  final List<String> oficios;
  final bool verificado, disponible, suspendido;
  final num calificacion;
  final int servicios;
  final String? zona, descripcion, documentoFrente, documentoReverso, certificado;

  Perfil.fromMap(Map<String, dynamic> m, this.email)
      : id = m['id'], rol = m['rol'], nombre = m['nombre'], telefono = m['telefono'], fotoUrl = m['foto_url'],
        suspendido = m['suspendido'] ?? false,
        oficios = List<String>.from(m['prestadores']?['oficios'] ?? const []),
        verificado = m['prestadores']?['verificado'] ?? false,
        disponible = m['prestadores']?['disponible'] ?? false,
        calificacion = m['prestadores']?['calificacion_prom'] ?? 0,
        servicios = m['prestadores']?['servicios_completados'] ?? 0,
        zona = m['prestadores']?['zona_habitual'], descripcion = m['prestadores']?['descripcion'],
        documentoFrente = m['prestadores']?['documento_url'], documentoReverso = m['prestadores']?['documento_reverso_url'],
        certificado = m['prestadores']?['certificado_url'];

  bool get registroIncompleto => esPrestador && (fotoUrl == null || documentoFrente == null || documentoReverso == null);

  bool get esPrestador => rol == 'prestador';
  bool get esCliente => rol == 'cliente';
  bool get esAdmin => rol == 'admin';
  String get primerNombre => nombre.trim().split(' ').first;
}

// Archivos que el técnico eligió al registrarse
class ArchivosRegistro {
  final XFile foto, cedulaFrente, cedulaReverso;
  final XFile? certificado;
  const ArchivosRegistro({required this.foto, required this.cedulaFrente, required this.cedulaReverso, this.certificado});
}
ArchivosRegistro? archivosPendientes;
Future<void>? _subidaPendiente;

void prepararArchivosRegistro(ArchivosRegistro? archivos) {
  archivosPendientes = archivos;
  _subidaPendiente = null;
}

// Sube una sola vez los archivos del registro, aunque la pantalla se abra varias veces
Future<void>? subirArchivosPendientes() {
  if (_subidaPendiente != null) return _subidaPendiente;
  final a = archivosPendientes;
  if (a == null) return null;
  return _subidaPendiente = AuthRepository()
      .guardarArchivosPrestador(foto: a.foto, cedulaFrente: a.cedulaFrente, cedulaReverso: a.cedulaReverso, certificado: a.certificado)
      .then((_) => archivosPendientes = null, onError: (Object e) {
    _subidaPendiente = null;
    throw e;
  });
}

final sesionProvider = StreamProvider<String?>((ref) async* {
  yield supabase.auth.currentUser?.id;
  yield* supabase.auth.onAuthStateChange.map((e) => e.session?.user.id).distinct();
});

// Datos del usuario que inició sesión
final perfilProvider = FutureProvider<Perfil?>((ref) async {
  final uid = await ref.watch(sesionProvider.future);
  if (uid == null) return null;
  return AuthRepository().leerPerfil(uid);
});

class AuthRepository {
  static const _campos = 'id, rol, nombre, telefono, suspendido, foto_url, '
      'prestadores(oficios, verificado, disponible, calificacion_prom, servicios_completados, zona_habitual, descripcion, '
      'documento_url, documento_reverso_url, certificado_url)';

  Future<void> guardarArchivosPrestador({XFile? foto, XFile? cedulaFrente, XFile? cedulaReverso, XFile? certificado}) async {
    final uid = supabase.auth.currentUser!.id;
    if (foto != null) {
      final url = await Almacenamiento.subirFoto(foto, 'perfil');
      await supabase.from('perfiles').update({'foto_url': url}).eq('id', uid);
    }
    final docs = <String, String>{
      if (cedulaFrente != null) 'documento_url': await Almacenamiento.subirDocumento(cedulaFrente, 'cedula-frente'),
      if (cedulaReverso != null) 'documento_reverso_url': await Almacenamiento.subirDocumento(cedulaReverso, 'cedula-reverso'),
      if (certificado != null) 'certificado_url': await Almacenamiento.subirDocumento(certificado, 'certificado'),
    };
    if (docs.isNotEmpty) await supabase.from('prestadores').update(docs).eq('id', uid);
  }

  Future<void> actualizarPerfil({required String nombre, required String telefono, XFile? foto,
      List<String>? oficios, String? zona, String? descripcion}) async {
    final uid = supabase.auth.currentUser!.id;
    final datos = <String, dynamic>{'nombre': nombre, 'telefono': telefono};
    if (foto != null) datos['foto_url'] = await Almacenamiento.subirFoto(foto, 'perfil');
    await supabase.from('perfiles').update(datos).eq('id', uid);
    if (oficios != null) {
      await supabase.from('prestadores').update({'oficios': oficios,
          'zona_habitual': zona?.trim().isEmpty == true ? null : zona?.trim(),
          'descripcion': descripcion?.trim().isEmpty == true ? null : descripcion?.trim()}).eq('id', uid);
    }
  }

  Future<void> login(String email, String clave) =>
      supabase.auth.signInWithPassword(email: email, password: clave);

  // Sirve para crear una cuenta nueva
  Future<void> registrar({required String email, required String clave, required String nombre,
      required String rol, required String telefono, List<String> oficios = const []}) async {
    final res = await supabase.auth.signUp(email: email, password: clave,
        data: {'rol': rol, 'nombre': nombre, 'telefono': telefono, 'oficios': oficios});
    final user = res.user;
    if (user == null) throw const ErrorConMensaje('No pudimos crear la cuenta. Inténtalo de nuevo.');
    if (res.session == null) {
      throw const ErrorConMensaje('Te enviamos un correo para confirmar tu cuenta. Ábrelo y luego inicia sesión.');
    }
    await _asegurarPerfil(user);
  }

  Future<Perfil?> leerPerfil(String uid) async {
    final user = supabase.auth.currentUser;
    var row = await supabase.from('perfiles').select(_campos).eq('id', uid).maybeSingle();
    if (row == null && user != null && user.id == uid) {
      await _asegurarPerfil(user);
      row = await supabase.from('perfiles').select(_campos).eq('id', uid).maybeSingle();
    }
    return row == null ? null : Perfil.fromMap(row, user?.email ?? '');
  }

  Future<void> _asegurarPerfil(User user) async {
    final existe = await supabase.from('perfiles').select('id').eq('id', user.id).maybeSingle();
    if (existe != null) return;
    final meta = user.userMetadata ?? const {};
    final rol = meta['rol'] == 'prestador' ? 'prestador' : 'cliente';
    final nombre = (meta['nombre'] as String?)?.trim();
    if (nombre == null || nombre.isEmpty) return;
    await supabase.from('perfiles').upsert({'id': user.id, 'rol': rol, 'nombre': nombre, 'telefono': meta['telefono']},
        onConflict: 'id', ignoreDuplicates: true);
    if (rol == 'prestador') {
      await supabase.from('prestadores').upsert({'id': user.id, 'oficios': List<String>.from(meta['oficios'] ?? const [])},
          onConflict: 'id', ignoreDuplicates: true);
    }
  }

  Future<void> salir() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid != null) {
      try { await supabase.from('perfiles').update({'fcm_token': null}).eq('id', uid); } catch (_) {}
    }
    await supabase.auth.signOut();
  }
}
