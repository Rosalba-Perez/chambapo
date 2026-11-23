import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../../core/almacenamiento.dart';
import '../../core/selector_imagen.dart';
import '../../core/mapa_ampliable.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../inicio/inicio_cliente_tab.dart' show categoriasProvider;
import 'lista_solicitudes_screen.dart';
import 'solicitudes_repository.dart';

// Pantalla para crear una nueva solicitud
class CrearSolicitudScreen extends ConsumerStatefulWidget {
  final String? categoria, descripcion;
  const CrearSolicitudScreen({super.key, this.categoria, this.descripcion});
  @override
  ConsumerState<CrearSolicitudScreen> createState() => _CrearSolicitudScreenState();
}

class _CrearSolicitudScreenState extends ConsumerState<CrearSolicitudScreen> {
  final _repo = SolicitudesRepository();
  late final _desc = TextEditingController(text: widget.descripcion ?? '');
  final _presupuesto = TextEditingController(), _materiales = TextEditingController();
  final _mapa = MapController();
  List<XFile> _fotos = [];
  bool? _tieneMateriales;
  String? _progreso;
  String? _categoria;
  LatLng _punto = const LatLng(10.40, -75.50);
  bool _ubicado = false, _sinPermiso = false, _programar = false, _enviando = false, _intentado = false;
  DateTime? _fecha;
  String? _error;

  @override
  void initState() {
    super.initState();
    _categoria = widget.categoria;
    _ubicarme();
  }

  Future<void> _ubicarme() async {
    try {
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) permiso = await Geolocator.requestPermission();
      if (permiso == LocationPermission.denied || permiso == LocationPermission.deniedForever) {
        if (mounted) setState(() => _sinPermiso = true);
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() { _punto = LatLng(pos.latitude, pos.longitude); _ubicado = true; _sinPermiso = false; });
      try { _mapa.move(_punto, 16); } catch (_) {}
    } catch (_) {
      if (mounted) setState(() => _sinPermiso = true);
    }
  }

  List<String> get _faltantes => [
    if (_categoria == null) 'Elige una categoría',
    if (_desc.text.trim().length < 10) 'Describe el problema (al menos 10 caracteres)',
    if (_fotos.isEmpty) 'Agrega al menos una foto del problema',
    if (_tieneMateriales == null) 'Indica si tienes los materiales',
    if (_tieneMateriales != null && _materiales.text.trim().length < 2)
      _tieneMateriales! ? 'Cuéntanos qué materiales tienes' : 'Cuéntanos qué materiales debe llevar el técnico',
    if (!_ubicado) 'Marca en el mapa dónde es el servicio',
    if (_programar && _fecha == null) 'Elige la fecha del servicio',
  ];

  Future<void> _publicar() async {
    setState(() { _intentado = true; _error = null; });
    if (_faltantes.isNotEmpty) return;
    final cats = ref.read(categoriasProvider).value ?? const [];
    final categoriaId = cats.firstWhere((c) => c['nombre'] == _categoria)['id'] as int;
    setState(() => _enviando = true);
    try {
      final urls = <String>[];
      for (final (i, f) in _fotos.indexed) {
        setState(() => _progreso = 'Subiendo fotos ${i + 1} de ${_fotos.length}…');
        urls.add(await Almacenamiento.subirFoto(f, 'solicitudes'));
      }
      setState(() => _progreso = 'Publicando…');
      final id = await _repo.crear(categoriaId: categoriaId, descripcion: _desc.text.trim(),
          presupuesto: int.tryParse(_presupuesto.text.replaceAll(RegExp(r'\D'), '')),
          fechaDeseada: _programar ? _fecha : null, lat: _punto.latitude, lng: _punto.longitude,
          fotos: urls, tieneMateriales: _tieneMateriales!, materiales: _materiales.text.trim());
      ref.invalidate(misSolicitudesProvider);
      if (mounted) context.go('/solicitud/$id');
    } catch (e) {
      setState(() => _error = mensajeError(e));
    } finally {
      if (mounted) setState(() { _enviando = false; _progreso = null; });
    }
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final d = await showDatePicker(context: context, firstDate: hoy, lastDate: hoy.add(const Duration(days: 30)),
        initialDate: _fecha ?? hoy.add(const Duration(days: 1)), helpText: 'Fecha del servicio');
    if (d == null || !mounted) return;
    final h = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 8, minute: 0), helpText: 'Hora aproximada');
    setState(() => _fecha = DateTime(d.year, d.month, d.day, h?.hour ?? 8, h?.minute ?? 0));
  }

  @override
  void dispose() { _desc.dispose(); _presupuesto.dispose(); _materiales.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cats = ref.watch(categoriasProvider);
    final faltantes = _intentado ? _faltantes : const <String>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva solicitud')),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
        if (faltantes.isNotEmpty) ...[
          const SizedBox(height: 8),
          Aviso(TipoAviso.error, 'Revisa la solicitud antes de publicarla', texto: faltantes.map((f) => '• $f').join('\n')),
        ],
        if (_error != null) ...[const SizedBox(height: 8), Aviso(TipoAviso.error, _error!)],
        _Etiqueta('Categoría', error: _intentado && _categoria == null),
        cats.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Aviso(TipoAviso.error, 'No pudimos cargar las categorías',
              accion: TextButton(onPressed: () => ref.invalidate(categoriasProvider), child: const Text('Reintentar'))),
          data: (cs) => Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in cs) ChoiceChip(
              label: Text(nombreCategoria(c['nombre'] as String)),
              selected: _categoria == c['nombre'],
              labelStyle: estiloChip(_categoria == c['nombre']),
              onSelected: (_) => setState(() => _categoria = c['nombre'] as String),
            ),
          ]),
        ),
        const _Etiqueta('Describe el problema'),
        TextField(controller: _desc, maxLines: 4, minLines: 3, onChanged: (_) { if (_intentado) setState(() {}); },
            decoration: InputDecoration(hintText: 'Ej.: el aire de la habitación prende pero no enfría.',
                errorText: _intentado && _desc.text.trim().length < 10 ? 'Cuéntanos un poco más del problema' : null)),
        _Etiqueta('Fotos del problema', error: _intentado && _fotos.isEmpty),
        Text('Una foto es obligatoria y puedes agregar hasta 3 más para dar contexto.', style: tt.bodySmall),
        const SizedBox(height: 8),
        SelectorFotosSolicitud(fotos: _fotos, error: _intentado && _fotos.isEmpty,
            alCambiar: (l) => setState(() => _fotos = l)),
        _Etiqueta('¿Tienes los materiales?', error: _intentado && _tieneMateriales == null),
        Row(children: [
          Expanded(child: _Opcion('Sí, los tengo', _tieneMateriales == true, () => setState(() => _tieneMateriales = true))),
          const SizedBox(width: 10),
          Expanded(child: _Opcion('No los tengo', _tieneMateriales == false, () => setState(() => _tieneMateriales = false))),
        ]),
        if (_tieneMateriales != null) ...[
          const SizedBox(height: 10),
          TextField(controller: _materiales, maxLines: 2, minLines: 2, maxLength: 500,
              onChanged: (_) { if (_intentado) setState(() {}); },
              decoration: InputDecoration(
                labelText: _tieneMateriales! ? '¿Qué materiales tienes?' : '¿Qué debería llevar el técnico?',
                hintText: _tieneMateriales! ? 'Ej.: pintura, rodillo y lija' : 'Ej.: gas refrigerante. Si no sabes, escribe «no sé»',
                errorText: _intentado && _materiales.text.trim().length < 2 ? 'Este campo es obligatorio' : null)),
        ],
        const _Etiqueta('Presupuesto (opcional)'),
        TextField(controller: _presupuesto, keyboardType: TextInputType.number,
            decoration: const InputDecoration(prefixText: '\$ ', hintText: '80000',
                helperText: 'Ayuda a los técnicos a ofertar. El precio final lo acuerdas con ellos.')),
        _Etiqueta('Ubicación del servicio', error: _intentado && !_ubicado),
        if (_sinPermiso) ...[
          const Aviso(TipoAviso.advertencia, 'No tenemos permiso para ver tu ubicación',
              texto: 'Toca el mapa para marcar la dirección del servicio, o activa la ubicación en los ajustes.'),
          const SizedBox(height: 8),
        ],
        MapaAmpliable(
          controlador: _mapa, centro: _punto, zoom: 14, titulo: 'Marca el lugar del servicio',
          alTocar: (p) => setState(() { _punto = p; _ubicado = true; }),
          capas: () => [
            if (_ubicado) MarkerLayer(markers: [Marker(point: _punto, width: 40, height: 40, alignment: Alignment.topCenter,
                child: const Icon(Icons.location_on, color: CP.naranja, size: 40))]),
          ],
        ),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: Text(_ubicado ? 'Toca el mapa para ajustar el punto exacto.' : 'Toca el mapa para marcar el punto.',
              style: tt.bodySmall)),
          TextButton.icon(onPressed: _ubicarme, icon: const Icon(Icons.my_location, size: 16), label: const Text('Mi ubicación')),
        ]),
        const _Etiqueta('¿Cuándo?'),
        Row(children: [
          Expanded(child: _Opcion('Lo antes posible', !_programar, () => setState(() => _programar = false))),
          const SizedBox(width: 10),
          Expanded(child: _Opcion('Programar', _programar, () { setState(() => _programar = true); if (_fecha == null) _elegirFecha(); })),
        ]),
        if (_programar) Padding(padding: const EdgeInsets.only(top: 8), child: OutlinedButton.icon(
          style: estiloFantasma, onPressed: _elegirFecha, icon: const Icon(Icons.calendar_month_outlined, size: 18),
          label: Text(_fecha == null ? 'Elegir fecha y hora'
              : '${_fecha!.day}/${_fecha!.month} · ${horaCorta(_fecha!)}'),
        )),
        const SizedBox(height: 24),
        FilledButton(onPressed: _enviando ? null : _publicar, child: _enviando
            ? Row(mainAxisSize: MainAxisSize.min, children: [cargandoBoton, const SizedBox(width: 10), Text(_progreso ?? 'Publicando…')])
            : const Text('Publicar solicitud')),
        const SizedBox(height: 8),
        Text('El precio lo acuerdas y pagas directamente con el prestador.', textAlign: TextAlign.center, style: tt.bodySmall),
      ]),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  final String texto;
  final bool error;
  const _Etiqueta(this.texto, {this.error = false});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(texto, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: error ? CP.error : CP.tinta)));
}

class _Opcion extends StatelessWidget {
  final String texto;
  final bool activa;
  final VoidCallback onTap;
  const _Opcion(this.texto, this.activa, this.onTap);
  @override
  Widget build(BuildContext context) => Semantics(selected: activa, button: true, child: Material(
    color: activa ? CP.seleccion : Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: activa ? CP.verde : CP.borde, width: activa ? 1.5 : 1)),
    child: InkWell(borderRadius: BorderRadius.circular(14), onTap: onTap, child: SizedBox(height: 48, child: Center(
        child: Text(texto, style: TextStyle(fontWeight: FontWeight.w700, color: activa ? CP.verde : CP.tinta))))),
  ));
}
