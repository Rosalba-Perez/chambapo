import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../auth/auth_provider.dart';
import '../solicitudes/solicitud.dart';
import '../solicitudes/solicitudes_repository.dart';

final conversacionesProvider = FutureProvider.autoDispose<List<Solicitud>>((ref) async {
  await ref.watch(sesionProvider.future);
  return SolicitudesRepository().conversaciones();
});

final noLeidosProvider = FutureProvider<Map<String, int>>((ref) async {
  await ref.watch(sesionProvider.future);
  try {
    return await SolicitudesRepository().noLeidos();
  } catch (_) {
    return const {};
  }
});

class InsigniaMensajes extends StatelessWidget {
  final int n;
  final Widget child;
  const InsigniaMensajes({super.key, required this.n, required this.child});
  @override
  Widget build(BuildContext context) => Badge(
    isLabelVisible: n > 0, backgroundColor: CP.naranja, textColor: Colors.white,
    label: Text(n > 99 ? '99+' : '$n'), child: child,
  );
}

// Pestaña de mensajes: un chat por cada servicio
class ConversacionesTab extends ConsumerWidget {
  const ConversacionesTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lista = ref.watch(conversacionesProvider);
    final noLeidos = ref.watch(noLeidosProvider).value ?? const <String, int>{};
    final uid = supabase.auth.currentUser?.id;
    return Scaffold(
      backgroundColor: CP.fondoApp,
      appBar: AppBar(backgroundColor: CP.fondoApp, title: const Text('Mensajes')),
      body: lista.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorPantalla(mensajeError(e), reintentar: () => ref.invalidate(conversacionesProvider)),
        data: (items) => RefreshIndicator(
          onRefresh: () => ref.refresh(conversacionesProvider.future),
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
            if (items.isEmpty) const Vacio(Icons.chat_bubble_outline, 'Sin conversaciones',
                'Cuando se asigne un servicio podrás escribirte con la otra persona desde aquí.'),
            for (final s in items) Padding(padding: const EdgeInsets.only(bottom: 10), child: Card(child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              leading: AvatarIniciales((s.clienteId == uid ? s.prestadorNombre : s.clienteNombre) ?? '?'),
              title: Text((s.clienteId == uid ? s.prestadorNombre : s.clienteNombre) ?? 'Conversación',
                  style: Theme.of(context).textTheme.titleSmall),
              subtitle: Text('${nombreCategoria(s.categoria)} · ${nombreEstado(s.estado).toLowerCase()}',
                  style: Theme.of(context).textTheme.bodySmall),
              trailing: (noLeidos[s.id] ?? 0) > 0
                  ? InsigniaMensajes(n: noLeidos[s.id]!, child: const Icon(Icons.mark_chat_unread_outlined, color: CP.naranja))
                  : const Icon(Icons.chevron_right, color: CP.apagado),
              onTap: () => context.push('/chat/${s.id}'),
            ))),
          ]),
        ),
      ),
    );
  }
}
