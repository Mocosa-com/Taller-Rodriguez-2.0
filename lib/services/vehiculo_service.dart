import 'package:taller_rodriguez/core/supabase/supabase_client.dart';

class VehiculoService {
  static final _client = SupabaseClientService.client;

  static Future<Map<String, dynamic>> obtenerVehiculos({bool entregados = false}) async {
    try {
      
     final data = entregados
    ? await _client
        .from('vehiculos')
        .select('*, clientes(nombre, dui), empleados(nombre)')
        .eq('estado', 'Entregado')
        .eq('activo', true)
        .order('fecha_ingreso', ascending: false)
    : await _client
        .from('vehiculos')
        .select('*, clientes(nombre, dui), empleados(nombre)')
        .neq('estado', 'Entregado')
        .eq('activo', true)
        .order('fecha_ingreso', ascending: false);

      final lista = (data as List).map((v) {
        final Map<String, dynamic> item = Map<String, dynamic>.from(v);
        final cliente = v['clientes'] as Map?;
        final empleado = v['empleados'] as Map?;
        item['cliente_nombre'] = cliente?['nombre'];
        item['cliente_dui'] = cliente?['dui'];
        item['empleado_nombre'] = empleado?['nombre'];
        return item;
      }).toList();

      return {'success': true, 'data': lista};
    } catch (e) {
      return {'success': false, 'message': 'Error al obtener vehículos: $e'};
    }
  }

  static Future<Map<String, dynamic>> crearVehiculo(Map<String, dynamic> datos) async {
    try {
      final resultado = await _client
          .from('vehiculos')
          .insert(datos)
          .select()
          .single();
      return {'success': true, 'data': resultado};
    } catch (e) {
      return {'success': false, 'message': 'Error al crear vehículo: $e'};
    }
  }

  static Future<Map<String, dynamic>> actualizarVehiculo(int id, Map<String, dynamic> datos) async {
    try {
      await _client.from('vehiculos').update(datos).eq('id', id);
      return {'success': true};
    } catch (e) {
      return {'success': false, 'message': 'Error al actualizar vehículo: $e'};
    }
  }

  static Future<Map<String, dynamic>> eliminarVehiculo(int id) async {
  try {
    await _client.from('vehiculos').update({'activo': false}).eq('id', id);
    return {'success': true};
  } catch (e) {
    return {'success': false, 'message': 'Error al eliminar vehículo: $e'};
  }
}

  static Future<List<Map<String, dynamic>>> obtenerVehiculosPorCliente(int clienteId) async {
    try {
      final data = await _client
          .from('vehiculos')
          .select()
          .eq('id_cliente', clienteId)
          .neq('estado', 'Entregado');
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      return [];
    }
  }
}