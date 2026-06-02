import 'package:supabase_flutter/supabase_flutter.dart';

class OfertaApi {
  static get _db => Supabase.instance.client;

  /// Obtiene TODAS las ofertas (activas e inactivas) para el panel de gestión
  Future<List<Map<String, dynamic>>> obtenerTodas() async {
    try {
      final data = await _db
          .from('ofertas')
          .select()
          .order('id', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      return [];
    }
  }

  /// Obtiene solo las ofertas activas (para usar en facturación)
  Future<List<Map<String, dynamic>>> obtenerOfertas() async {
    try {
      final data = await _db
          .from('ofertas')
          .select()
          .eq('activo', true)
          .order('id', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> crearOferta({
    required String nombreOferta,
    required String descripcion,
    required double porcentajeDescuento,
    required DateTime fechaInicio,
    required DateTime fechaFin,
    String? idProductoFirebase,
  }) async {
    try {
      await _db.from('ofertas').insert({
        'nombre_oferta': nombreOferta,
        'descripcion': descripcion.isEmpty ? null : descripcion,
        'porcentaje_descuento': porcentajeDescuento,
        'fecha_inicio': fechaInicio.toIso8601String().split('T')[0],
        'fecha_fin': fechaFin.toIso8601String().split('T')[0],
        'activo': true,
      });
      return {'success': true};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> actualizarOferta({
    required int id,
    required String nombreOferta,
    required String descripcion,
    required double porcentajeDescuento,
    required DateTime fechaInicio,
    required DateTime fechaFin,
    String? idProductoFirebase,
  }) async {
    try {
      await _db.from('ofertas').update({
        'nombre_oferta': nombreOferta,
        'descripcion': descripcion.isEmpty ? null : descripcion,
        'porcentaje_descuento': porcentajeDescuento,
        'fecha_inicio': fechaInicio.toIso8601String().split('T')[0],
        'fecha_fin': fechaFin.toIso8601String().split('T')[0],
      }).eq('id', id);
      return {'success': true};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Soft-delete: desactiva la oferta sin eliminarla de la base de datos
  Future<Map<String, dynamic>> desactivarOferta(int id) async {
    try {
      await _db.from('ofertas').update({
        'activo': false,
      }).eq('id', id);
      return {'success': true};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Reactivar una oferta desactivada
  Future<Map<String, dynamic>> reactivarOferta(int id) async {
    try {
      await _db.from('ofertas').update({
        'activo': true,
      }).eq('id', id);
      return {'success': true};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Eliminado físico — NO usar en producción, solo para admin con privilegios
  @Deprecated('Usar desactivarOferta() para mantener integridad de datos')
  Future<Map<String, dynamic>> eliminarOferta(int id) async {
    try {
      await _db.from('ofertas').update({'activo': false}).eq('id', id);
      return {'success': true};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}