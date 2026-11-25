import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../core/router.dart';
import '../../core/supabase_client.dart';

// Sirve para recibir notificaciones en el teléfono
class PushService {
  static final _local = FlutterLocalNotificationsPlugin();

  static bool activo = false;
  static String estado = 'Todavía no se han configurado.';

  static Future<void> init() async {
    if (kIsWeb) { estado = 'No disponibles en la versión web.'; return; }
    try {
      await Firebase.initializeApp();
    } catch (e) {
      estado = 'Firebase no está configurado: $e';
      debugPrint('Push desactivado: $estado');
      return;
    }
    activo = true;
    final fcm = FirebaseMessaging.instance;
    supabase.auth.onAuthStateChange.listen((_) => _guardarToken());
    fcm.onTokenRefresh.listen((_) => _guardarToken());
    await _local.initialize(const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher'), iOS: DarwinInitializationSettings()),
        onDidReceiveNotificationResponse: (r) => _abrir(r.payload));
    try {
      await fcm.requestPermission();
    } catch (e) {
      debugPrint('No se pudo pedir el permiso de notificaciones: $e');
    }
    await _guardarToken();
    FirebaseMessaging.onMessage.listen((m) {
      if (!_esParaMi(m)) return;
      _local.show(m.hashCode, m.notification?.title, m.notification?.body,
          const NotificationDetails(android: AndroidNotificationDetails('chambapo', 'Chambapo', importance: Importance.high)),
          payload: m.data['id']);
    });
    FirebaseMessaging.onMessageOpenedApp.listen((m) { if (_esParaMi(m)) _abrir(m.data['id']); });
  }

  static Future<void> _guardarToken() async {
    if (!activo) return;
    try {
      final permiso = await FirebaseMessaging.instance.getNotificationSettings();
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) { estado = 'Este celular no entregó un código de notificaciones.'; return; }
      if (supabase.auth.currentUser == null) { estado = 'Inicia sesión para recibir notificaciones.'; return; }
      await supabase.rpc('registrar_token', params: {'p_token': token});
      estado = permiso.authorizationStatus == AuthorizationStatus.denied
          ? 'Registradas, pero el permiso de notificaciones está desactivado en el celular.'
          : 'Activas en este celular.';
    } catch (e) {
      estado = 'No se pudieron registrar: $e';
      debugPrint(estado);
    }
  }

  // Sirve para volver a registrar el celular desde el perfil y saber el resultado
  static Future<String> revisar() async {
    if (activo) await _guardarToken();
    return estado;
  }

  static bool _esParaMi(RemoteMessage m) {
    final para = m.data['para'];
    return para == null || para == supabase.auth.currentUser?.id;
  }

  static void _abrir(String? solicitudId) { if (solicitudId != null) router.go('/solicitud/$solicitudId'); }
}
