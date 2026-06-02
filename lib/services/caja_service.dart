 import 'package:taller_rodriguez/core/supabase/supabase_client.dart';
import 'package:taller_rodriguez/services/session_service.dart';

class CajaService {
  static final _client = SupabaseClientService.client;

  
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

  static Future<Map<String, dynamic>> abrirCaja(double baseInicial) async {
    try {
      final empleadoId = SessionService.currentUser?['id'];
      if (empleadoId == null) {
        return {'success': false, 'message': 'No hay sesión activa'};
      }

    
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

  
  static Future<Map<String, dynamic>> cerrarCaja(int idCaja) async {
  try {
    
    final cajaData = await _client
        .from('apertura_cierre')
        .select('fecha, hora_apertura, base_inicial')
        .eq('id', idCaja)
        .single();

    final fecha       = cajaData['fecha']?.toString() ?? '';
    final horaApertura = cajaData['hora_apertura']?.toString() ?? '00:00:00';
    final baseInicial = (cajaData['base_inicial'] as num?)?.toDouble() ?? 0;

    final inicioCaja = DateTime.tryParse('${fecha}T$horaApertura') 
                    ?? DateTime.now().subtract(const Duration(hours: 8));

    final facturas = await _client
        .from('facturacion')
        .select('total')
        .gte('fecha', inicioCaja.toIso8601String());

    double totalVentas = 0;
    int cantidadFacturas = facturas.length;
    for (final f in facturas) {
      totalVentas += (f['total'] as num?)?.toDouble() ?? 0;
    }

    final totalEnCaja    = baseInicial + totalVentas;
    final horaCierre     = DateTime.now()
        .toIso8601String().split('T')[1].substring(0, 8);

    await _client.from('apertura_cierre').update({
      'estado'           : 'Cerrada',
      'hora_cierre'      : horaCierre,
      'total_cierre'     : totalEnCaja,
      'total_ventas'     : totalVentas,
      'cantidad_facturas': cantidadFacturas,
    }).eq('id', idCaja);

    return {
      'success'           : true,
      'base_inicial'      : baseInicial,
      'total_ventas'      : totalVentas,
      'total_en_caja'     : totalEnCaja,
      'cantidad_facturas' : cantidadFacturas,
    };
  } catch (e) {
    return {'success': false, 'message': e.toString()};
  }
}


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