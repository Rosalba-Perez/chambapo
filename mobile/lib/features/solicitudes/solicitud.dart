class Solicitud {
  final String id, estado, descripcion, categoria;
  final String? barrio, prestadorId, clienteId, clienteNombre, prestadorNombre, clienteFoto, prestadorFoto, materiales;
  final String? motivoCancelacion, canceladaPor;
  final bool conInconvenientes;
  final bool? tieneMateriales;
  final List<String> fotos;
  final num? presupuesto, probContratacion, precioAcordado;
  final DateTime creadoEn;
  final DateTime? fechaDeseada;
  final int numPostulaciones;
  final bool llegadaReportada, llegadaConfirmada, finReportado, enRevision;
  final int rechazosLlegada, rechazosFin;

  Solicitud.fromMap(Map<String, dynamic> m)
      : id = m['id'], estado = m['estado'], descripcion = m['descripcion'],
        categoria = m['categorias']?['nombre'] ?? '', barrio = m['barrio'], prestadorId = m['prestador_id'],
        clienteId = m['cliente_id'], presupuesto = m['presupuesto'], probContratacion = m['prob_contratacion'],
        precioAcordado = m['precio_acordado'],
        clienteNombre = m['cliente']?['nombre'], prestadorNombre = m['prestador']?['nombre'],
        clienteFoto = m['cliente']?['foto_url'], prestadorFoto = m['prestador']?['foto_url'],
        fotos = List<String>.from(m['fotos'] ?? const []),
        tieneMateriales = m['tiene_materiales'], materiales = m['materiales'],
        creadoEn = DateTime.parse(m['creado_en']),
        fechaDeseada = m['fecha_deseada'] == null ? null : DateTime.parse(m['fecha_deseada']),
        numPostulaciones = (m['postulaciones'] is List && (m['postulaciones'] as List).isNotEmpty)
            ? ((m['postulaciones'] as List).first['count'] ?? 0) as int : 0,
        llegadaReportada = m['llegada_reportada_en'] != null, llegadaConfirmada = m['llegada_confirmada_en'] != null,
        finReportado = m['fin_reportado_en'] != null, enRevision = m['en_revision'] ?? false,
        rechazosLlegada = m['rechazos_llegada'] ?? 0, rechazosFin = m['rechazos_fin'] ?? 0,
        motivoCancelacion = m['motivo_cancelacion'], canceladaPor = m['cancelada_por'],
        conInconvenientes = m['con_inconvenientes'] ?? false;

  bool get activa => ['publicada', 'con_postulaciones'].contains(estado);
  bool get enServicio => ['asignada', 'en_camino', 'en_curso'].contains(estado);
  bool get urgente => fechaDeseada == null;
  bool get revisionPendiente => enRevision && estado != 'cancelada' && estado != 'finalizada';

  Paso get paso => switch (estado) {
    'asignada' => Paso.asignada,
    'en_camino' when llegadaConfirmada => Paso.codigo,
    'en_camino' when llegadaReportada => Paso.confirmarLlegada,
    'en_camino' => Paso.enCamino,
    'en_curso' when finReportado => Paso.confirmarFin,
    'en_curso' => Paso.enCurso,
    'finalizada' => Paso.finalizada,
    _ => Paso.otro,
  };
}

// Pasos del servicio, desde que se asigna hasta que termina
enum Paso { asignada, enCamino, confirmarLlegada, codigo, enCurso, confirmarFin, finalizada, otro }

class Postulacion {
  final String id, prestadorId, nombre;
  final String? foto;
  final num precio, calificacion;
  final int minutosLlegada, servicios;
  Postulacion.fromMap(Map<String, dynamic> m)
      : id = m['id'], prestadorId = m['prestador_id'], precio = m['precio'], minutosLlegada = m['minutos_llegada'],
        nombre = m['perfiles']?['nombre'] ?? 'Prestador', foto = m['perfiles']?['foto_url'],
        calificacion = m['perfiles']?['prestadores']?['calificacion_prom'] ?? 0,
        servicios = m['perfiles']?['prestadores']?['servicios_completados'] ?? 0;
}

class Resena {
  final String autor, texto, categoria;
  final int puntaje;
  final DateTime fecha;
  Resena.fromMap(Map<String, dynamic> m)
      : autor = m['autor'] ?? 'Cliente', texto = m['resena'] ?? '', puntaje = m['puntaje'],
        categoria = m['categoria'] ?? '', fecha = DateTime.parse(m['creado_en']);
}

class PerfilPublico {
  final String id, nombre;
  final String? foto, descripcion, zona;
  final List<String> oficios;
  final bool verificado;
  final num calificacion;
  final int servicios;
  final DateTime desde;
  final List<Resena> resenas;
  PerfilPublico.fromMap(Map<String, dynamic> m, this.resenas)
      : id = m['id'], nombre = m['perfiles']?['nombre'] ?? 'Prestador', foto = m['perfiles']?['foto_url'],
        descripcion = m['descripcion'], zona = m['zona_habitual'],
        oficios = List<String>.from(m['oficios'] ?? const []), verificado = m['verificado'] ?? false,
        calificacion = m['calificacion_prom'] ?? 0, servicios = m['servicios_completados'] ?? 0,
        desde = DateTime.parse(m['perfiles']?['creado_en'] ?? DateTime.now().toIso8601String());
}

class PerfilCliente {
  final String id, nombre;
  final String? foto;
  final DateTime desde;
  final int publicadas, finalizadas;
  final List<Resena> resenas;
  PerfilCliente({required this.id, required this.nombre, this.foto, required this.desde,
      required this.publicadas, required this.finalizadas, required this.resenas});
  double? get promedio => resenas.isEmpty ? null : resenas.map((r) => r.puntaje).reduce((a, b) => a + b) / resenas.length;
}
