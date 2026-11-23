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

  static Future<void> init() async {
    if (kIsWeb) { debugPrint('Push desactivado: la app web no usa Firebase'); return; }
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('Push desactivado: Firebase no está configurado ($e)');
      return;
    }
    activo = true;
    final fcm = FirebaseMessaging.instance;
    await fcm.requestPermission();
    await _local.initialize(const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher'), iOS: DarwinInitializationSettings()),
        onDidReceiveNotificationResponse: (r) => _abrir(r.payload));

    supabase.auth.onAuthStateChange.listen((_) => _guardarToken());
    fcm.onTokenRefresh.listen((_) => _guardarToken());
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
    final uid = supabase.auth.currentUser?.id; final token = await FirebaseMessaging.instance.getToken();
    if (uid != null && token != null) await supabase.rpc('registrar_token', params: {'p_token': token});
  }

  static bool _esParaMi(RemoteMessage m) {
    final para = m.data['para'];
    return para == null || para == supabase.auth.currentUser?.id;
  }

  static void _abrir(String? solicitudId) { if (solicitudId != null) router.go('/solicitud/$solicitudId'); }
}
