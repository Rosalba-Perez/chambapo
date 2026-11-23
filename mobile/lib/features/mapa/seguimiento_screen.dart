import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/config.dart';
import '../../core/supabase_client.dart';
import '../../core/mapa_ampliable.dart';
import '../../core/theme.dart';

// Mapa para ver por dónde va el técnico en tiempo real
class SeguimientoScreen extends StatefulWidget {
  final String solicitudId;
  const SeguimientoScreen({super.key, required this.solicitudId});
  @override
  State<SeguimientoScreen> createState() => _SeguimientoScreenState();
}

class _SeguimientoScreenState extends State<SeguimientoScreen> {
  LatLng? _destino, _prestador; List<LatLng> _ruta = []; int? _minutos;
  StreamSubscription? _sub; final _mapa = MapController();

  @override
  void initState() {
    super.initState();
    _cargarDestino();
    _sub = supabase.from('posiciones').stream(primaryKey: ['id']).eq('solicitud_id', widget.solicitudId)
        .order('creado_en', ascending: false).limit(1).listen((rows) {
      if (rows.isEmpty) return;
      final p = LatLng(rows.first['lat'], rows.first['lng']);
      setState(() => _prestador = p);
      _mapa.move(p, _mapa.camera.zoom);
      _calcularRuta();
    });
  }

  Future<void> _cargarDestino() async {
    final r = await supabase.rpc('solicitud_coordenadas', params: {'p_id': widget.solicitudId});
    if (r is List && r.isNotEmpty) setState(() => _destino = LatLng(r.first['lat'], r.first['lng']));
  }

  Future<void> _calcularRuta() async {
    if (_prestador == null || _destino == null) return;
    try {
      final url = '${Config.osrmUrl}/route/v1/driving/${_prestador!.longitude},${_prestador!.latitude};${_destino!.longitude},${_destino!.latitude}?overview=full&geometries=geojson';
      final r = await Dio().get(url);
      final route = r.data['routes'][0];
      final coords = (route['geometry']['coordinates'] as List).map((c) => LatLng(c[1], c[0])).toList();
      setState(() { _ruta = coords; _minutos = (route['duration'] / 60).round(); });
    } catch (_) {}
  }

  @override
  void dispose() { _sub?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(backgroundColor: Colors.transparent,
          leading: Padding(padding: const EdgeInsets.all(6), child: IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: Colors.white, foregroundColor: CP.tinta),
              onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.arrow_back)))),
      body: Stack(children: [
        FlutterMap(mapController: _mapa, options: MapOptions(initialCenter: _destino ?? const LatLng(10.40, -75.50), initialZoom: 14, minZoom: 5, maxZoom: 19), children: [
          TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'co.chambapo.app'),
          if (_ruta.isNotEmpty) PolylineLayer(polylines: [Polyline(points: _ruta, strokeWidth: 5, color: CP.verde)]),
          MarkerLayer(markers: [
            if (_destino != null) Marker(point: _destino!, width: 40, height: 40, alignment: Alignment.topCenter,
                child: const Icon(Icons.location_on, color: CP.naranja, size: 40)),
            if (_prestador != null) Marker(point: _prestador!, width: 26, height: 26, child: Container(
                decoration: BoxDecoration(color: CP.verde, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)))),
          ]),
        ]),
        Positioned(right: 16, top: MediaQuery.paddingOf(context).top + 64, child: BotonesZoom(_mapa)),
        if (_minutos != null) Positioned(top: MediaQuery.paddingOf(context).top + 10, right: 16, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: CP.tinta, borderRadius: BorderRadius.circular(14)),
          child: Text('$_minutos min', style: estiloTitulo.copyWith(color: Colors.white, fontSize: 20)),
        )),
        Positioned(left: 0, right: 0, bottom: 0, child: Container(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.paddingOf(context).bottom),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [BoxShadow(color: Color(0x1A000000), blurRadius: 24, offset: Offset(0, -6))]),
          child: Text(
            _prestador == null ? 'Esperando la ubicación del prestador…'
                : _minutos == null ? 'El prestador va en camino' : 'Llega en unos $_minutos minutos',
            style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
        )),
      ]),
    );
  }
}
