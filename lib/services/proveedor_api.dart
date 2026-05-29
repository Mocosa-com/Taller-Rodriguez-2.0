import 'package:taller_rodriguez/core/supabase/supabase_client.dart';

class ProveedorApi {
  final _client = SupabaseClientService.client;

  Future<List<Map<String, dynamic>>> obtenerProveedores({String? busqueda}) async {
    try {
      var query = _client
          .from('proveedores')
          .select()
          .eq('activo', true);

      if (busqueda != null && busqueda.isNotEmpty) {
        query = query.ilike('nombre', '%$busqueda%');
      }

      final data = await query;
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> crearProveedor(Map<String, dynamic> proveedor) async {
    try {
      await _client.from('proveedores').insert({...proveedor, 'activo': true});
      return {'success': true};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> actualizarProveedor(int id, Map<String, dynamic> proveedor) async {
    try {
      await _client.from('proveedores').update(proveedor).eq('id', id);
      return {'success': true};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> eliminarProveedor(int id) async {
    try {
      await _client.from('proveedores').update({'activo': false}).eq('id', id);
      return {'success': true};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}