import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_client.dart';
import 'theme.dart';

// Sirve para subir fotos y documentos a la nube
class Almacenamiento {
  static String get _uid => supabase.auth.currentUser!.id;

  static String _extension(XFile f) {
    final n = f.name.toLowerCase();
    if (n.endsWith('.png')) return 'png';
    if (n.endsWith('.webp')) return 'webp';
    return 'jpg';
  }

  static String _tipo(String ext) => switch (ext) { 'png' => 'image/png', 'webp' => 'image/webp', _ => 'image/jpeg' };

  static Future<String> subirFoto(XFile f, String carpeta) async {
    final ext = _extension(f);
    final ruta = '$_uid/$carpeta/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await supabase.storage.from('fotos').uploadBinary(ruta, await f.readAsBytes(),
        fileOptions: FileOptions(contentType: _tipo(ext), upsert: true));
    return supabase.storage.from('fotos').getPublicUrl(ruta);
  }

  static Future<String> subirDocumento(XFile f, String nombre) async {
    final ext = _extension(f);
    final ruta = '$_uid/$nombre-${DateTime.now().millisecondsSinceEpoch}.$ext';
    await supabase.storage.from('documentos').uploadBinary(ruta, await f.readAsBytes(),
        fileOptions: FileOptions(contentType: _tipo(ext), upsert: true));
    return ruta;
  }
}

// Sirve para elegir una imagen desde la cámara o la galería
Future<XFile?> elegirImagen(BuildContext context, {bool permitirCamara = true}) async {
  ImageSource? fuente = ImageSource.gallery;
  if (!kIsWeb && permitirCamara) {
    fuente = await showModalBottomSheet<ImageSource>(context: context, showDragHandle: true, builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.photo_camera_outlined, color: CP.verde), title: const Text('Tomar foto'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera)),
        ListTile(leading: const Icon(Icons.photo_library_outlined, color: CP.verde), title: const Text('Elegir de la galería'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
        const SizedBox(height: 8),
      ]),
    ));
  }
  if (fuente == null) return null;
  return ImagePicker().pickImage(source: fuente, maxWidth: 1600, maxHeight: 1600, imageQuality: 82);
}
