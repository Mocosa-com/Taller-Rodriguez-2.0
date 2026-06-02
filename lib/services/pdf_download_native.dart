import 'dart:io';
import 'dart:typed_data';


Future<void> descargarPdf(Uint8List bytes, String filename) async {
  final dir  = Directory.systemTemp;
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(bytes);
 
}