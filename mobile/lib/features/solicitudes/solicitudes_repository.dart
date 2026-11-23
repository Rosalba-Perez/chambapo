import '../../core/api_client.dart';
import '../../core/supabase_client.dart';
import 'solicitud.dart';


class SolicitudesRepository {
  static const _campos = 'id, estado, descripcion, barrio, presupuesto, prob_contratacion, prestador_id, cliente_id, '
      'creado_en, fecha_deseada, precio_acordado, categorias(nombre), '
      'llegada_reportada_en, llegada_confirmada_en, fin_reportado_en, rechazos_llegada, rechazos_fin, en_revision, '
      'fotos, tiene_materiales, materiales, motivo_cancelacion, cancelada_por, con_inconvenientes, '
      'cliente:perfiles!cliente_id(nombre, foto_url), prestador:perfiles!prestador_id(nombre, foto_url), postulaciones(count)';
  static const _estadosConChat = ['asignada', 'en_camino', 'en_curso', 'finalizada'];

  String get _uid => supabase.auth.currentUser!.id;

  Future<List<Solicitud>> misSolicitudes() async {
    final rows = await supabase.from('solicitudes').select(_campos)
        .or('cliente_id.eq.$_uid,prestador_id.eq.$_uid').order('creado_en', ascending: false);
    return rows.map((r) => Solicitud.fromMap(r)).toList();
  }

  Future<List<Solicitud>> solicitudesAbiertas() async {
    final rows = await supabase.from('solicitudes').select(_campos)
        .inFilter('estado', ['publicada', 'con_postulaciones']).order('creado_en', ascending: false).limit(50);
    return rows.map((r) => Solicitud.fromMap(r)).toList();
  }

  Future<List<Solicitud>> misTrabajos() async {
    final rows = await supabase.from('solicitudes').select(_campos).eq('prestador_id', _uid)
        .order('creado_en', ascending: false);
    return rows.map((r) => Solicitud.fromMap(r)).toList();
  }


  Future<List<Solicitud>> conversaciones() async {
    final rows = await supabase.from('solicitudes').select(_campos)
        .or('cliente_id.eq.$_uid,prestador_id.eq.$_uid').inFilter('estado', _estadosConChat)
        .order('creado_en', ascending: false);
    return rows.map((r) => Solicitud.fromMap(r)).toList();
  }

  Future<Solicitud> una(String id) async =>
      Solicitud.fromMap(await supabase.from('solicitudes').select(_campos).eq('id', id).single());

  Future<List<Postulacion>> postulaciones(String solicitudId) async {
    final rows = await supabase.from('postulaciones')
        .select('id, prestador_id, precio, minutos_llegada, perfiles(nombre, foto_url, prestadores(calificacion_prom, servicios_completados))')
        .eq('solicitud_id', solicitudId).order('precio');
    return rows.map((r) => Postulacion.fromMap(r)).toList();
  }

  Future<List<Map<String, dynamic>>> categorias() => supabase.from('categorias').select('id, nombre').order('id');

  Future<PerfilPublico> perfilPrestador(String id) async {
    final p = await supabase.from('prestadores')
        .select('id, oficios, verificado, calificacion_prom, servicios_completados, descripcion, zona_habitual, '
            'perfiles(nombre, creado_en, foto_url)')
        .eq('id', id).single();
    final rs = await supabase.rpc('resenas_prestador', params: {'p_id': id}) as List;
    return PerfilPublico.fromMap(p, rs.map((r) => Resena.fromMap(Map<String, dynamic>.from(r))).toList());
  }

  // Sirve para saber dónde es el servicio
  Future<({double lat, double lng})?> coordenadas(String id) async {
    final r = await supabase.rpc('solicitud_coordenadas', params: {'p_id': id});
    if (r is! List || r.isEmpty) return null;
    return (lat: (r.first['lat'] as num).toDouble(), lng: (r.first['lng'] as num).toDouble());
  }

  Future<PerfilCliente> perfilCliente(String id) async {
    final p = await supabase.from('perfiles').select('id, nombre, foto_url, creado_en').eq('id', id).single();
    final sols = await supabase.from('solicitudes').select('estado').eq('cliente_id', id) as List;
    final rs = await supabase.rpc('resenas_prestador', params: {'p_id': id}) as List;
    return PerfilCliente(id: p['id'], nombre: p['nombre'] ?? 'Cliente', foto: p['foto_url'],
        desde: DateTime.parse(p['creado_en']), publicadas: sols.length,
        finalizadas: sols.where((x) => x['estado'] == 'finalizada').length,
        resenas: rs.map((r) => Resena.fromMap(Map<String, dynamic>.from(r))).toList());
  }

  Future<Map<String, int>> noLeidos() async {
    final r = await supabase.rpc('mensajes_no_leidos') as List;
    return {for (final x in r) x['solicitud_id'] as String: (x['n'] as num).toInt()};
  }

  Future<void> marcarLeidos(String solicitudId) async {
    try { await supabase.rpc('marcar_leidos', params: {'p_solicitud': solicitudId}); } catch (_) {}
  }

  Future<bool> yaCalifique(String solicitudId) async => (await supabase.from('calificaciones').select('id')
      .eq('solicitud_id', solicitudId).eq('autor_id', _uid).maybeSingle()) != null;

  Future<void> registrarVista(String solicitudId) async {
    try {
      await supabase.from('vistas_solicitud').upsert(
          {'solicitud_id': solicitudId, 'prestador_id': _uid},
          onConflict: 'solicitud_id,prestador_id', ignoreDuplicates: true);
    } catch (_) {}
  }

  Future<String> crear({required int categoriaId, required String descripcion, int? presupuesto,
      DateTime? fechaDeseada, required double lat, required double lng, required List<String> fotos,
      required bool tieneMateriales, required String materiales}) async {
    final r = await api.post('/api/solicitudes/', {
      'categoria_id': categoriaId, 'descripcion': descripcion, 'presupuesto': presupuesto,
      'fecha_deseada': fechaDeseada?.toUtc().toIso8601String(), 'lat': lat, 'lng': lng, 'fotos': fotos,
      'tiene_materiales': tieneMateriales, 'materiales': materiales});
    return r['id'];
  }

  Future<void> postular(String id, int precio, int minutos) =>
      api.post('/api/solicitudes/$id/postular/', {'precio': precio, 'minutos_llegada': minutos});

  Future<void> elegir(String id, String postulacionId) =>
      api.post('/api/solicitudes/$id/elegir/', {'postulacion_id': postulacionId});

  Future<void> cambiarEstado(String id, String estado, {String? motivo}) =>
      api.post('/api/solicitudes/$id/estado/', {'estado': estado, if (motivo != null && motivo.isNotEmpty) 'motivo': motivo});

  Future<void> llegue(String id) => api.post('/api/solicitudes/$id/llegue/', {});

  Future<({String? codigo, bool revision})> confirmarLlegada(String id, bool si) async {
    final r = await api.post('/api/solicitudes/$id/confirmar-llegada/', {'si': si});
    return (codigo: r['codigo'] as String?, revision: r['revision'] == true);
  }

  Future<String> codigoInicio(String id) async => (await api.get('/api/solicitudes/$id/codigo/'))['codigo'] as String;

  Future<void> iniciar(String id, String codigo) => api.post('/api/solicitudes/$id/iniciar/', {'codigo': codigo});

  Future<void> termine(String id) => api.post('/api/solicitudes/$id/termine/', {});

  Future<bool> confirmarFin(String id, bool si) async =>
      (await api.post('/api/solicitudes/$id/confirmar-fin/', {'si': si}))['revision'] == true;

  Future<void> calificar(String solicitudId, String receptorId, int puntaje, String resena) =>
      supabase.from('calificaciones').insert({'solicitud_id': solicitudId, 'autor_id': _uid,
          'receptor_id': receptorId, 'puntaje': puntaje, 'resena': resena.trim().isEmpty ? null : resena.trim()});

  Future<void> reportar(String solicitudId, String reportadoId, String motivo) =>
      supabase.from('reportes').insert({'solicitud_id': solicitudId, 'autor_id': _uid,
          'reportado_id': reportadoId, 'motivo': motivo});
}
