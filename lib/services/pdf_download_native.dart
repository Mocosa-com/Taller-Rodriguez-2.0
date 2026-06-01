import 'dart:io';
import 'dart:typed_data';

/// Guarda el PDF en el directorio temporal del dispositivo.
Future<void> descargarPdf(Uint8List bytes, String filename) async {
  final dir  = Directory.systemTemp;
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(bytes);
  // En apps móviles reales conviene abrir el archivo con open_file o share_plus.
}