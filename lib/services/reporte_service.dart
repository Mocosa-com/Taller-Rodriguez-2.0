import 'package:supabase_flutter/supabase_flutter.dart';

class ReporteService {
  static final _db = Supabase.instance.client;

  // Guarda un reporte en la tabla 'reportes'
  static Future<bool> guardarReporte({
    required String tipo,        // 'cliente' o 'empleado'
    required int idReferencia,   // id del cliente o empleado
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

  // Trae todos los reportes ordenados por fecha
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

  // Eliminar reporte
  static Future<void> eliminar(int id) async {
    await _db.from('reportes').delete().eq('id', id);
  }
}