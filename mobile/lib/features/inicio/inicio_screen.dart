import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../admin/panel_admin_screen.dart';
import '../auth/auth_provider.dart';
import '../chat/conversaciones_tab.dart';
import '../perfil/editar_perfil_screen.dart';
import '../perfil/perfil_tab.dart';
import '../prestador/panel_prestador_tab.dart';
import '../solicitudes/lista_solicitudes_screen.dart';
import 'avisos_servicio.dart';
import 'inicio_cliente_tab.dart';

// Pantalla principal con las pestañas de abajo según el tipo de usuario
class InicioScreen extends ConsumerStatefulWidget {
  const InicioScreen({super.key});
  @override
  ConsumerState<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends ConsumerState<InicioScreen> {
  int _tab = 0;
  String? _uidAnterior;

  @override
  Widget build(BuildContext context) {
    final perfil = ref.watch(perfilProvider);
    return perfil.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: ErrorPantalla(mensajeError(e), reintentar: () => ref.invalidate(perfilProvider))),
      data: (p) {
        if (p == null) return const _SinPerfil();
        if (p.suspendido) {
          return const _CuentaBloqueada(icono: Icons.block, titulo: 'Tu cuenta está suspendida',
              texto: 'Un administrador suspendió tu cuenta después de revisar un servicio. Si crees que es un error, '
                  'escríbenos a soporte de Chambapo.');
        }
        if (p.registroIncompleto) return CompletarRegistroScreen(p);
        if (p.esAdmin) return const PanelAdminScreen();
        if (_uidAnterior != p.id) { _uidAnterior = p.id; _tab = 0; }

        final sinLeer = (ref.watch(noLeidosProvider).value ?? const <String, int>{}).values.fold(0, (a, b) => a + b);
        final mensajes = NavigationDestination(
            icon: InsigniaMensajes(n: sinLeer, child: const Icon(Icons.chat_bubble_outline)),
            selectedIcon: InsigniaMensajes(n: sinLeer, child: const Icon(Icons.chat_bubble)), label: 'Mensajes');
        final (paginas, destinos) = p.esPrestador
            ? (const [PanelPrestadorTab(), ListaSolicitudesTab(trabajos: true), ConversacionesTab(), PerfilTab()], [
                const NavigationDestination(icon: Icon(Icons.location_on_outlined), selectedIcon: Icon(Icons.location_on), label: 'Solicitudes'),
                const NavigationDestination(icon: Icon(Icons.work_outline), selectedIcon: Icon(Icons.work), label: 'Mis trabajos'),
                mensajes,
                const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Mi perfil'),
              ])
            : (const [InicioClienteTab(), ListaSolicitudesTab(), ConversacionesTab(), PerfilTab()], [
                const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'),
                const NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Solicitudes'),
                mensajes,
                const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Perfil'),
              ]);

        return AvisosServicio(
          key: ValueKey(p.id),
          esCliente: p.esCliente,
          child: Scaffold(
            body: IndexedStack(index: _tab, children: paginas),
            bottomNavigationBar: DecoratedBox(
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: CP.borde))),
              child: NavigationBar(selectedIndex: _tab, destinations: destinos,
                  onDestinationSelected: (i) => setState(() => _tab = i)),
            ),
          ),
        );
      },
    );
  }
}

class _CuentaBloqueada extends StatelessWidget {
  final IconData icono;
  final String titulo, texto;
  const _CuentaBloqueada({required this.icono, required this.titulo, required this.texto});
  @override
  Widget build(BuildContext context) => Scaffold(body: SafeArea(child: Padding(
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Center(child: Container(width: 72, height: 72, decoration: const BoxDecoration(color: CP.seleccion, shape: BoxShape.circle),
          child: Icon(icono, color: CP.verde, size: 36))),
      const SizedBox(height: 18),
      Text(titulo, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      Text(texto, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 24),
      OutlinedButton(style: estiloFantasma, onPressed: () => AuthRepository().salir(), child: const Text('Cerrar sesión')),
    ]),
  )));
}

class _SinPerfil extends ConsumerWidget {
  const _SinPerfil();
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(body: SafeArea(child: Padding(
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Aviso(TipoAviso.advertencia, 'No encontramos los datos de tu cuenta',
          texto: 'Tu registro no se completó. Vuelve a intentarlo; si sigue pasando, cierra sesión y crea la cuenta de nuevo.'),
      const SizedBox(height: 16),
      FilledButton(style: estiloSecundario, onPressed: () => ref.invalidate(perfilProvider), child: const Text('Reintentar')),
      const SizedBox(height: 8),
      OutlinedButton(style: estiloFantasma, onPressed: () => AuthRepository().salir(), child: const Text('Cerrar sesión')),
    ]),
  )));
}
