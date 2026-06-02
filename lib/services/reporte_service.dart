import 'package:supabase_flutter/supabase_flutter.dart';

class ReporteService {
  static final _db = Supabase.instance.client;

 
  static Future<bool> guardarReporte({
    required String tipo,      
    required int idReferencia,   
    required String nombreReferencia,
    required String notas,
    required String creadoPor,
  }) async {
    try {
      await _db.from('reportes').insert({
        'tipo': tipo,
        'id_referencia': idReferencia,
        'nombre_referencia': nombreReferencia,
        'notas': notas,
        'creado_por': creadoPor,
        'fecha': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  
  static Future<List<Map<String, dynamic>>> getAll() async {
    try {
      final data = await _db
          .from('reportes')
          .select()
          .order('fecha', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      return [];
    }
  }

 
  static Future<void> eliminar(int id) async {
    await _db.from('reportes').delete().eq('id', id);
  }
}