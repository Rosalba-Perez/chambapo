import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'supabase_client.dart';
import '../features/auth/bienvenida_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/registro_screen.dart';
import '../features/inicio/inicio_screen.dart';
import '../features/solicitudes/crear_solicitud_screen.dart';
import '../features/solicitudes/detalle_solicitud_screen.dart';
import '../features/solicitudes/perfil_cliente_screen.dart';
import '../features/solicitudes/perfil_prestador_screen.dart';
import '../features/solicitudes/reportar_screen.dart';
import '../features/mapa/seguimiento_screen.dart';
import '../features/chat/chat_screen.dart';
import '../features/perfil/editar_perfil_screen.dart';

const _rutasPublicas = {'/bienvenida', '/login', '/registro'};

class _CambiosDeSesion extends ChangeNotifier {
  late final StreamSubscription _sub = supabase.auth.onAuthStateChange.listen((_) => notifyListeners());
  _CambiosDeSesion() { _sub; }
}

final router = GoRouter(
  initialLocation: '/',
  refreshListenable: _CambiosDeSesion(),
  redirect: (context, state) {
    final logueado = supabase.auth.currentSession != null;
    final publica = _rutasPublicas.contains(state.matchedLocation);
    if (!logueado && !publica) return '/bienvenida';
    if (logueado && publica) return '/';
    return null;
  },
  routes: [
    GoRoute(path: '/bienvenida', builder: (_, __) => const BienvenidaScreen()),
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/registro', builder: (_, s) => RegistroScreen(rolInicial: s.uri.queryParameters['rol'])),
    GoRoute(path: '/', builder: (_, __) => const InicioScreen(), routes: [
      GoRoute(path: 'nueva', builder: (_, s) => CrearSolicitudScreen(
          categoria: s.uri.queryParameters['categoria'], descripcion: s.uri.queryParameters['q'])),
      GoRoute(path: 'solicitud/:id', builder: (_, s) => DetalleSolicitudScreen(id: s.pathParameters['id']!), routes: [
        GoRoute(path: 'prestador/:pid', builder: (_, s) =>
            PerfilPrestadorScreen(solicitudId: s.pathParameters['id']!, prestadorId: s.pathParameters['pid']!)),
        GoRoute(path: 'cliente/:cid', builder: (_, s) => PerfilClienteScreen(clienteId: s.pathParameters['cid']!)),
        GoRoute(path: 'reportar', builder: (_, s) => ReportarScreen(solicitudId: s.pathParameters['id']!)),
      ]),
      GoRoute(path: 'seguimiento/:id', builder: (_, s) => SeguimientoScreen(solicitudId: s.pathParameters['id']!)),
      GoRoute(path: 'chat/:id', builder: (_, s) => ChatScreen(solicitudId: s.pathParameters['id']!)),
      GoRoute(path: 'perfil/editar', builder: (_, __) => const EditarPerfilScreen()),
    ]),
  ],
);
