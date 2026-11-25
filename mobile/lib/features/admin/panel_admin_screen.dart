import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../perfil/perfil_tab.dart';
import 'demanda_tab.dart';
import 'resumen_tab.dart';
import 'usuarios_tab.dart';

// Pantalla principal del administrador con sus pestañas
class PanelAdminScreen extends StatefulWidget {
  const PanelAdminScreen({super.key});
  @override
  State<PanelAdminScreen> createState() => _PanelAdminScreenState();
}

class _PanelAdminScreenState extends State<PanelAdminScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(index: _tab, children: const [ResumenTab(), DemandaTab(), UsuariosTab(), PerfilTab()]),
    bottomNavigationBar: DecoratedBox(
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: CP.borde))),
      child: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'Resumen'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Demanda'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Usuarios'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    ),
  );
}
