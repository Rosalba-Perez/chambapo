import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router.dart';
import 'core/supabase_client.dart';
import 'core/theme.dart';
import 'features/notificaciones/push_service.dart';
import 'features/ubicacion/location_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSupabase();
  runApp(const ProviderScope(child: ChambapoApp()));
  _iniciarServicios();
}

Future<void> _iniciarServicios() async {
  try {
    await PushService.init();
  } catch (e) {
    debugPrint('No se pudo iniciar push: $e');
  }
  if (kIsWeb) return;
  try {
    await LocationService.configurar();
  } catch (e) {
    debugPrint('No se pudo configurar el servicio de ubicación: $e');
  }
}

class ChambapoApp extends StatelessWidget {
  const ChambapoApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Chambapo',
      debugShowCheckedModeBanner: false,
      theme: temaChambapo(),
      routerConfig: router,
    );
  }
}
