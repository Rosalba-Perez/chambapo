import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/supabase_client.dart';

// Interruptor para que el técnico diga si está disponible
class DisponibilidadSwitch extends StatefulWidget {
  const DisponibilidadSwitch({super.key});
  @override
  State<DisponibilidadSwitch> createState() => _DisponibilidadSwitchState();
}

class _DisponibilidadSwitchState extends State<DisponibilidadSwitch> {
  bool _disponible = false;

  @override
  void initState() {
    super.initState();
    supabase.from('prestadores').select('disponible').eq('id', supabase.auth.currentUser!.id).single()
        .then((r) => setState(() => _disponible = r['disponible'] ?? false));
  }

  Future<void> _cambiar(bool v) async {
    final datos = <String, dynamic>{'disponible': v};
    if (v) {
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) permiso = await Geolocator.requestPermission();
      final pos = await Geolocator.getCurrentPosition();
      datos['ubicacion'] = 'POINT(${pos.longitude} ${pos.latitude})';
      datos['ubicacion_en'] = DateTime.now().toIso8601String();
    }
    await supabase.from('prestadores').update(datos).eq('id', supabase.auth.currentUser!.id);
    setState(() => _disponible = v);
  }

  @override
  Widget build(BuildContext context) => SwitchListTile(
    title: Text(_disponible ? 'Disponible: recibirás solicitudes cercanas' : 'No disponible'),
    value: _disponible, onChanged: _cambiar);
}
