import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config.dart';

// Sirve para enviar la ubicación del técnico mientras hace un servicio
class LocationService {
  static final _svc = FlutterBackgroundService();

  static const _canal = AndroidNotificationChannel('chambapo_ubicacion', 'Ubicación durante el servicio',
      description: 'Aviso fijo mientras compartes tu ubicación con el cliente', importance: Importance.low);

  static AndroidFlutterLocalNotificationsPlugin? get _android => FlutterLocalNotificationsPlugin()
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  static Future<void> configurar() async {
    await _android?.createNotificationChannel(_canal);
    await _svc.configure(
      androidConfiguration: AndroidConfiguration(onStart: _onStart, autoStart: false, isForegroundMode: true,
          notificationChannelId: 'chambapo_ubicacion', initialNotificationTitle: 'Chambapo',
          initialNotificationContent: 'Compartiendo tu ubicación con el cliente', foregroundServiceNotificationId: 888),
      iosConfiguration: IosConfiguration(autoStart: false, onForeground: _onStart, onBackground: _onIosBackground),
    );
  }

  static Future<void> iniciar(String solicitudId) async {
    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) permiso = await Geolocator.requestPermission();
    if (permiso == LocationPermission.denied || permiso == LocationPermission.deniedForever) {
      throw Exception('Necesitamos el permiso de ubicación para que el cliente vea tu llegada');
    }
    try { await _android?.requestNotificationsPermission(); } catch (_) {}
    await _android?.createNotificationChannel(_canal);
    if (await _svc.isRunning()) {
      _svc.invoke('solicitud', {'id': solicitudId});
      return;
    }
    await _svc.startService();
    await Future<void>.delayed(const Duration(milliseconds: 800));
    _svc.invoke('solicitud', {'id': solicitudId});
  }

  static Future<void> detener() async => _svc.invoke('detener');
}

@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance s) async => true;

@pragma('vm:entry-point')
void _onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  await Supabase.initialize(url: Config.supabaseUrl, anonKey: Config.supabaseAnonKey);
  final sb = Supabase.instance.client;
  String? solicitudId; StreamSubscription<Position>? sub;

  service.on('solicitud').listen((data) {
    solicitudId = data?['id'];
    sub?.cancel();
    sub = Geolocator.getPositionStream(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10))
        .listen((pos) async {
      final uid = sb.auth.currentUser?.id;
      if (uid == null || solicitudId == null) return;
      try {
        await sb.from('posiciones').insert({'solicitud_id': solicitudId, 'prestador_id': uid, 'lat': pos.latitude, 'lng': pos.longitude});
        await sb.from('prestadores').update({'ubicacion': 'POINT(${pos.longitude} ${pos.latitude})', 'ubicacion_en': DateTime.now().toIso8601String()}).eq('id', uid);
      } catch (_) {
        try {
          final s = await sb.from('solicitudes').select('estado').eq('id', solicitudId!).maybeSingle();
          if (s == null || !['asignada', 'en_camino', 'en_curso'].contains(s['estado'])) {
            await sub?.cancel();
            service.stopSelf();
          }
        } catch (_) {}
      }
    });
  });

  service.on('detener').listen((_) async { await sub?.cancel(); service.stopSelf(); });
}
