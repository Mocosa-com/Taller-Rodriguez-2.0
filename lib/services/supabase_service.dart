import 'package:supabase_flutter/supabase_flutter.dart';
import 'session_service.dart';

class SupabaseService {
  static final _client = Supabase.instance.client;

  // ── Credenciales root (acceso local, no va a Supabase) ──────────
  static const String _rootUsuario   = 'root';
  static const String _rootContrasena = 'root1234';

  // ── Login ────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> login(
    String usuario,
    String contrasena,
  ) async {
    // Chequeo root antes de tocar la red
    if (usuario.trim() == _rootUsuario &&
        contrasena.trim() == _rootContrasena) {
      final rootUser = {
        'id': 0,
        'nombre': 'Root',
        'cargo': 'root',
        'estado': true,
        'foto_url': null,
      };
      await SessionService.iniciar(rootUser);
      return {
        'success': true,
        'message': '¡Bienvenido Root!',
        'empleado': rootUser,
      };
    }

    // Login normal contra Supabase
    try {
      final response = await _client
          .from('empleados')
          .select()
          .or('nombre.eq.$usuario,dui.eq.$usuario')
          .eq('contrasena', contrasena)
          .eq('estado', true)
          .limit(1);

      if (response.isNotEmpty) {
        final user = response.first;
        await SessionService.iniciar(user);
        return {
          'success': true,
          'message': '¡Bienvenido ${user['nombre']}!',
          'empleado': user,
        };
      }

      return {
        'success': false,
        'message': 'Usuario o contraseña incorrectos',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error de conexión',
      };
    }
  }

  // ── Registrar administrador ──────────────────────────────────────
  static Future<Map<String, dynamic>> registrarAdmin(
    Map<String, dynamic> datos,
  ) async {
    try {
      final response = await _client
          .from('empleados')
          .insert({
            'nombre': datos['nombre'],
            'dui': datos['dui'] ??
                'TEMP-${DateTime.now().millisecondsSinceEpoch}',
            'telefono': datos['telefono'] ?? '00000000',
            'fecha_contratacion':
                DateTime.now().toIso8601String().split('T')[0],
            'sueldo_base': datos['sueldo_base'] ?? 0,
            'contrasena': datos['contrasena'],
            'cargo': 'Administrador',
            'tipo_empleado': datos['tipo_empleado'] ?? 'contratado',
            'estado': true,
          })
          .select()
          .single();

      return {
        'success': true,
        'message': 'Administrador registrado correctamente',
        'data': response,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error al registrar',
      };
    }
  }
}