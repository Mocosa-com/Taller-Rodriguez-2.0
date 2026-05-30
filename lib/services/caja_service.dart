 import 'package:taller_rodriguez/core/supabase/supabase_client.dart';
import 'package:taller_rodriguez/services/session_service.dart';

class CajaService {
  static final _client = SupabaseClientService.client;

  // Verifica si hay una caja abierta ahorita
  static Future<Map<String, dynamic>?> getCajaAbierta() async {
    try {
      final data = await _client
          .from('apertura_cierre')
          .select('*, empleados(nombre)')
          .eq('estado', 'Abierta')
          .eq('activo', true)
          .maybeSingle();
      return data;
    } catch (e) {
      return null;
    }
  }

  // Abre una nueva caja
  static Future<Map<String, dynamic>> abrirCaja(double baseInicial) async {
    try {
      final empleadoId = SessionService.currentUser?['id'];
      if (empleadoId == null) {
        return {'success': false, 'message': 'No hay sesión activa'};
      }

      // Verificar que no haya caja abierta
      final cajaActual = await getCajaAbierta();
      if (cajaActual != null) {
        return {'success': false, 'message': 'Ya hay una caja abierta'};
      }

      await _client.from('apertura_cierre').insert({
        'fecha': DateTime.now().toIso8601String().split('T')[0],
        'estado': 'Abierta',
        'base_inicial': baseInicial,
        'efectivo_actual': baseInicial,
        'hora_apertura': DateTime.now().toIso8601String().split('T')[1].substring(0, 8),
        'id_empleado': empleadoId,
        'activo': true,
      });

      return {'success': true};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Cierra la caja actual
  static Future<Map<String, dynamic>> cerrarCaja(int idCaja, {String? observacion}) async {
    try {
      await _client.from('apertura_cierre').update({
        'estado': 'Cerrada',
        'hora_cierre': DateTime.now().toIso8601String().split('T')[1].substring(0, 8),
        'total_cierre': null, // se puede calcular después
        if (observacion != null) 'observacion': observacion,
      }).eq('id', idCaja);

      return {'success': true};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Actualiza el efectivo actual
  static Future<Map<String, dynamic>> actualizarEfectivo(int idCaja, double efectivo) async {
    try {
      await _client.from('apertura_cierre')
          .update({'efectivo_actual': efectivo})
          .eq('id', idCaja);
      return {'success': true};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Historial de turnos
  static Future<List<Map<String, dynamic>>> getHistorial() async {
    try {
      final data = await _client
          .from('apertura_cierre')
          .select('*, empleados(nombre)')
          .eq('activo', true)
          .order('fecha', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      return [];
    }
  }
}