import '../../core/api_client.dart';
import '../../core/supabase_client.dart';

typedef Fila = Map<String, dynamic>;

// Sirve para leer las estadísticas y gestionar usuarios desde la cuenta de administrador
class AdminRepository {
  Future<Fila> resumen(int dias) => api.get('/api/estadisticas/resumen/?dias=$dias');

  Future<List<Fila>> por(String dimension, int dias) => api.getLista('/api/estadisticas/por/$dimension/?dias=$dias');

  Future<List<Fila>> tecnicosPendientes() async {
    final filas = await supabase.from('prestadores')
        .select('id, oficios, zona_habitual, documento_url, documento_reverso_url, certificado_url, '
            'perfiles(nombre, telefono, suspendido, foto_url)')
        .eq('verificado', false);
    return [for (final f in filas) if (f['perfiles'] != null && f['perfiles']['suspendido'] != true) f];
  }

  Future<List<Fila>> reportesAbiertos() => supabase.from('reportes')
      .select('id, motivo, creado_en, solicitud:solicitudes(id, estado, en_revision), '
          'autor:perfiles!reportes_autor_id_fkey(id, nombre, rol, suspendido), '
          'reportado:perfiles!reportes_reportado_id_fkey(id, nombre, rol, suspendido)')
      .eq('atendido', false)
      .order('creado_en');

  Future<List<Fila>> vetados() => supabase.from('perfiles')
      .select('id, nombre, rol, telefono, foto_url')
      .eq('suspendido', true)
      .neq('rol', 'admin')
      .order('nombre');

  Future<List<Fila>> historialReportes() => supabase.from('reportes')
      .select('id, motivo, creado_en, reportado_id')
      .order('creado_en', ascending: false);

  Future<String> urlDocumento(String ruta) async =>
      ruta.startsWith('http') ? ruta : await supabase.storage.from('documentos').createSignedUrl(ruta, 300);

  Future<void> aprobar(String id) => supabase.from('prestadores').update({'verificado': true}).eq('id', id);

  Future<void> suspender(String id, bool suspendido) =>
      supabase.from('perfiles').update({'suspendido': suspendido}).eq('id', id);

  Future<void> atenderReporte(String id) => supabase.from('reportes').update({'atendido': true}).eq('id', id);

  Future<void> cerrarRevision(String reporteId, String solicitudId) async {
    await supabase.from('solicitudes').update({
      'estado': 'cancelada', 'contratada': false, 'cerrado_en': DateTime.now().toUtc().toIso8601String(),
      'motivo_cancelacion': 'Cerrada por el administrador tras la revisión',
    }).eq('id', solicitudId);
    await atenderReporte(reporteId);
  }
}
