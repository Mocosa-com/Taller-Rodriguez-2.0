import 'package:taller_rodriguez/core/supabase/supabase_client.dart';

class InventarioApi {
  final _client = SupabaseClientService.client;

  Future<List<Map<String, dynamic>>> obtenerInventario({
    String? busqueda,
    String? idProveedor,
    String? clasificacion,
    String? ordenStock,
  }) async {
    try {
      var query = _client
          .from('inventario')
          .select('*, proveedores(nombre)')
          .eq('activo', true);

      if (clasificacion != null && clasificacion.isNotEmpty) {
        query = query.eq('clasificacion', clasificacion);
      }
      if (idProveedor != null && idProveedor.isNotEmpty) {
        query = query.eq('id_proveedor', idProveedor);
      }
      if (busqueda != null && busqueda.isNotEmpty) {
        query = query.ilike('nombre', '%$busqueda%');
      }

      final data = await query;

      List<Map<String, dynamic>> resultado = List<Map<String, dynamic>>.from(data);

      if (ordenStock == 'asc') {
        resultado.sort((a, b) => (a['stock'] ?? 0).compareTo(b['stock'] ?? 0));
      } else if (ordenStock == 'desc') {
        resultado.sort((a, b) => (b['stock'] ?? 0).compareTo(a['stock'] ?? 0));
      }

      return resultado;
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> crearProducto(Map<String, dynamic> producto) async {
    try {
      await _client.from('inventario').insert({...producto, 'activo': true});
      return {'success': true};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> actualizarProducto(String id, Map<String, dynamic> producto) async {
    try {
      await _client.from('inventario').update(producto).eq('id', id);
      return {'success': true};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> entradaStock(String id, int cantidad, {String? motivo}) async {
    try {
      final actual = await _client
          .from('inventario')
          .select('stock')
          .eq('id', id)
          .single();
      final stockActual = actual['stock'] as int? ?? 0;
      await _client
          .from('inventario')
          .update({'stock': stockActual + cantidad})
          .eq('id', id);
      return {'success': true};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> salidaStock(String id, int cantidad, {String? motivo}) async {
    try {
      final actual = await _client
          .from('inventario')
          .select('stock')
          .eq('id', id)
          .single();
      final stockActual = actual['stock'] as int? ?? 0;
      if (cantidad > stockActual) {
        return {'success': false, 'message': 'Stock insuficiente'};
      }
      await _client
          .from('inventario')
          .update({'stock': stockActual - cantidad})
          .eq('id', id);
      return {'success': true};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<bool> eliminarProducto(String id) async {
    try {
      // No se borra, se desactiva
      await _client.from('inventario').update({'activo': false}).eq('id', id);
      return true;
    } catch (e) {
      return false;
    }
  }
}