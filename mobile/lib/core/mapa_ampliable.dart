import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'theme.dart';

// Mapa con botones para acercar, alejar y verlo en pantalla completa
class MapaAmpliable extends StatefulWidget {
  final LatLng centro;
  final double zoom, alto;
  final List<Widget> Function() capas;
  final void Function(LatLng punto)? alTocar;
  final MapController? controlador;
  final String titulo;
  const MapaAmpliable({super.key, required this.centro, required this.capas, this.zoom = 15, this.alto = 200,
      this.alTocar, this.controlador, this.titulo = 'Ubicación del servicio'});

  @override
  State<MapaAmpliable> createState() => _MapaAmpliableState();
}

class _MapaAmpliableState extends State<MapaAmpliable> {
  late final MapController _mapa = widget.controlador ?? MapController();

  Future<void> _ampliar() async {
    LatLng centro = widget.centro; double zoom = widget.zoom;
    try { centro = _mapa.camera.center; zoom = _mapa.camera.zoom; } catch (_) {}
    await Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => _MapaCompleto(
        titulo: widget.titulo, centro: centro, zoom: zoom, capas: widget.capas,
        alTocar: widget.alTocar == null ? null : (p) { widget.alTocar!(p); if (mounted) setState(() {}); })));
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: SizedBox(height: widget.alto, child: Stack(children: [
      _Mapa(controlador: _mapa, centro: widget.centro, zoom: widget.zoom, capas: widget.capas(), alTocar: widget.alTocar),
      Positioned(right: 8, top: 8, child: Column(children: [
        _BotonMapa(Icons.open_in_full, 'Ver en pantalla completa', _ampliar),
        const SizedBox(height: 8),
        BotonesZoom(_mapa),
      ])),
    ])),
  );
}

class _Mapa extends StatelessWidget {
  final MapController controlador;
  final LatLng centro;
  final double zoom;
  final List<Widget> capas;
  final void Function(LatLng)? alTocar;
  const _Mapa({required this.controlador, required this.centro, required this.zoom, required this.capas, this.alTocar});
  @override
  Widget build(BuildContext context) => FlutterMap(
    mapController: controlador,
    options: MapOptions(initialCenter: centro, initialZoom: zoom, minZoom: 5, maxZoom: 19,
        onTap: alTocar == null ? null : (_, p) => alTocar!(p)),
    children: [
      TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'co.chambapo.app'),
      ...capas,
    ],
  );
}

// Botones para acercar y alejar el mapa
class BotonesZoom extends StatelessWidget {
  final MapController mapa;
  const BotonesZoom(this.mapa, {super.key});
  void _zoom(double delta) {
    final c = mapa.camera;
    mapa.move(c.center, (c.zoom + delta).clamp(5, 19).toDouble());
  }
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    _BotonMapa(Icons.add, 'Acercar', () => _zoom(1)),
    const SizedBox(height: 4),
    _BotonMapa(Icons.remove, 'Alejar', () => _zoom(-1)),
  ]);
}

class _BotonMapa extends StatelessWidget {
  final IconData icono;
  final String ayuda;
  final VoidCallback alPulsar;
  const _BotonMapa(this.icono, this.ayuda, this.alPulsar);
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white, shape: const CircleBorder(), elevation: 2,
    child: IconButton(tooltip: ayuda, onPressed: alPulsar, icon: Icon(icono, color: CP.tinta, size: 20),
        constraints: const BoxConstraints.tightFor(width: 40, height: 40), padding: EdgeInsets.zero),
  );
}

class _MapaCompleto extends StatefulWidget {
  final String titulo;
  final LatLng centro;
  final double zoom;
  final List<Widget> Function() capas;
  final void Function(LatLng)? alTocar;
  const _MapaCompleto({required this.titulo, required this.centro, required this.zoom, required this.capas, this.alTocar});
  @override
  State<_MapaCompleto> createState() => _MapaCompletoState();
}

class _MapaCompletoState extends State<_MapaCompleto> {
  final _mapa = MapController();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.titulo)),
    body: Stack(children: [
      _Mapa(controlador: _mapa, centro: widget.centro, zoom: widget.zoom, capas: widget.capas(),
          alTocar: widget.alTocar == null ? null : (p) { widget.alTocar!(p); setState(() {}); }),
      Positioned(right: 12, top: 12, child: BotonesZoom(_mapa)),
      if (widget.alTocar != null) Positioned(left: 16, right: 16, bottom: 24, child: FilledButton(
          onPressed: () => Navigator.pop(context), child: const Text('Listo'))),
    ]),
  );
}
