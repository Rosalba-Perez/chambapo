import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'almacenamiento.dart';
import 'theme.dart';
import 'ui.dart';

class VistaImagen extends StatelessWidget {
  final XFile? archivo;
  final String? url;
  final BoxFit fit;
  const VistaImagen({super.key, this.archivo, this.url, this.fit = BoxFit.cover});
  @override
  Widget build(BuildContext context) {
    if (archivo != null) {
      return FutureBuilder<Uint8List>(future: archivo!.readAsBytes(), builder: (_, s) => s.hasData
          ? Image.memory(s.data!, fit: fit) : const Center(child: CircularProgressIndicator(strokeWidth: 2)));
    }
    if (url != null) {
      return Image.network(url!, fit: fit, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined, color: CP.apagado)));
    }
    return const SizedBox.shrink();
  }
}

// Foto de perfil redonda con un botón para cambiarla
class SelectorFotoPerfil extends StatelessWidget {
  final XFile? archivo;
  final String? url, nombre;
  final bool error;
  final ValueChanged<XFile> alElegir;
  const SelectorFotoPerfil({super.key, this.archivo, this.url, this.nombre, this.error = false, required this.alElegir});
  @override
  Widget build(BuildContext context) => Center(child: Semantics(button: true, label: 'Elegir foto de perfil', child: GestureDetector(
    onTap: () async { final f = await elegirImagen(context); if (f != null) alElegir(f); },
    child: Stack(children: [
      Container(
        width: 96, height: 96, clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(shape: BoxShape.circle, color: CP.fondoApp,
            border: Border.all(color: error ? CP.error : CP.borde, width: error ? 2 : 1)),
        child: archivo != null || url != null
            ? VistaImagen(archivo: archivo, url: url)
            : (nombre?.trim().isNotEmpty == true
                ? AvatarIniciales(nombre!, tam: 96)
                : const Icon(Icons.person_outline, size: 44, color: CP.apagado)),
      ),
      Positioned(right: 0, bottom: 0, child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(color: CP.naranja, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
        child: const Icon(Icons.photo_camera, color: Colors.white, size: 16),
      )),
    ]),
  )));
}

// Casilla para subir un documento o una foto
class CasillaImagen extends StatelessWidget {
  final String titulo;
  final String? ayuda;
  final XFile? archivo;
  final bool cargado, obligatorio, error;
  final ValueChanged<XFile> alElegir;
  const CasillaImagen({super.key, required this.titulo, this.ayuda, this.archivo, this.cargado = false,
      this.obligatorio = true, this.error = false, required this.alElegir});
  @override
  Widget build(BuildContext context) {
    final listo = archivo != null || cargado;
    return Material(
      color: listo ? CP.seleccion : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: error ? CP.error : (listo ? CP.verde : CP.borde), width: error || listo ? 1.5 : 1)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async { final f = await elegirImagen(context); if (f != null) alElegir(f); },
        child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(10), child: Container(
            width: 56, height: 44, color: CP.fondoApp,
            child: archivo != null ? VistaImagen(archivo: archivo)
                : Icon(listo ? Icons.check_circle : Icons.badge_outlined, color: listo ? CP.exito : CP.apagado),
          )),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$titulo${obligatorio ? '' : ' (opcional)'}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: CP.tinta)),
            Text(error ? 'Este documento es obligatorio' : listo ? (archivo != null ? 'Listo para enviar' : 'Ya enviado · toca para cambiarlo') : (ayuda ?? 'Toca para subir una foto'),
                style: TextStyle(fontSize: 12, color: error ? CP.error : CP.apagado, fontWeight: error ? FontWeight.w600 : FontWeight.w400)),
          ])),
          Icon(listo ? Icons.edit_outlined : Icons.upload_outlined, color: CP.verde, size: 20),
        ])),
      ),
    );
  }
}

// Sirve para agregar las fotos de una solicitud
class SelectorFotosSolicitud extends StatelessWidget {
  final List<XFile> fotos;
  final int maximo;
  final bool error;
  final ValueChanged<List<XFile>> alCambiar;
  const SelectorFotosSolicitud({super.key, required this.fotos, this.maximo = 4, this.error = false, required this.alCambiar});
  @override
  Widget build(BuildContext context) {
    Widget casilla(int i) {
      final hay = i < fotos.length;
      final principal = i == 0;
      return AspectRatio(aspectRatio: 1, child: Material(
        color: hay ? Colors.black : (principal ? const Color(0xFFFCEFE8) : CP.fondoCampo),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: principal && error ? CP.error : (principal && !hay ? CP.naranja : CP.borde),
                width: principal && !hay ? 1.5 : 1)),
        child: InkWell(
          onTap: hay ? null : () async {
            final f = await elegirImagen(context);
            if (f != null) alCambiar([...fotos, f]);
          },
          child: hay
              ? Stack(fit: StackFit.expand, children: [
                  VistaImagen(archivo: fotos[i]),
                  Positioned(top: 4, right: 4, child: IconButton.filled(
                    tooltip: 'Quitar foto', iconSize: 16, constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    style: IconButton.styleFrom(backgroundColor: Colors.black54, foregroundColor: Colors.white, padding: EdgeInsets.zero),
                    onPressed: () => alCambiar([...fotos]..removeAt(i)), icon: const Icon(Icons.close),
                  )),
                ])
              : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(principal ? Icons.add_a_photo_outlined : Icons.add, color: principal ? CP.naranja : CP.apagado),
                  const SizedBox(height: 4),
                  Text(principal ? 'Obligatoria' : 'Opcional', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                      color: principal ? CP.naranja : CP.apagado)),
                ]),
        ),
      ));
    }
    final casillas = (fotos.length + 1).clamp(1, maximo);
    return Row(children: [
      for (var i = 0; i < maximo; i++) ...[
        if (i > 0) const SizedBox(width: 8),
        Expanded(child: i < casillas ? casilla(i) : const SizedBox()),
      ],
    ]);
  }
}
