import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static Map<String, dynamic>? _currentUser;
  static const String _key = 'session_user';

  static Map<String, dynamic>? get currentUser => _currentUser;
  static String get cargo => _currentUser?['cargo']?.toString() ?? '';
  static String get rolActual => cargo;

  // ── Roles ────────────────────────────────────────────────────────
  static bool get esRoot =>
      cargo.toLowerCase() == 'root';

  static bool get esAdmin =>
      esRoot || cargo.toLowerCase() == 'administrador';

  static bool get esSecretaria =>
      cargo.toLowerCase() == 'secretaria';

  static bool get esMecanico =>
      ['mecanico', 'empleado'].contains(cargo.toLowerCase());

  // ── Rutas permitidas por rol ─────────────────────────────────────
  static const Set<String> rutasRoot = {
    '/login', '/dashboard', '/perfil',
    '/clientes', '/empleados', '/ofertas', '/facturacion',
    '/historialFacturas', '/inventario', '/caja', '/historialTurnos',
    '/vehiculos', '/proveedores', '/reportes',
  };

  static const Set<String> rutasAdmin = {
    '/login', '/dashboard', '/perfil',
    '/clientes', '/empleados', '/ofertas', '/facturacion',
    '/historialFacturas', '/inventario', '/caja', '/historialTurnos',
    '/vehiculos', '/proveedores', '/reportes',
  };

  static const Set<String> rutasSecretaria = {
    '/login', '/dashboard', '/perfil',
    '/clientes', '/facturacion', '/historialFacturas',
    '/caja', '/historialTurnos', '/vehiculos', '/reportes',
  };

  static const Set<String> rutasMecanico = {
    '/login', '/dashboard', '/perfil', '/vehiculos',
  };

  static Set<String> get rutasPermitidas {
    if (esRoot)       return rutasRoot;
    if (esAdmin)      return rutasAdmin;
    if (esSecretaria) return rutasSecretaria;
    if (esMecanico)   return rutasMecanico;
    return {'/login'};
  }

  static bool puedeAcceder(String ruta) => rutasPermitidas.contains(ruta);

  // ── Sesión ───────────────────────────────────────────────────────
  static Future<void> iniciar(Map<String, dynamic> userData) async {
    _currentUser = userData;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(userData));
  }

  static Future<bool> restaurar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) {
        _currentUser = jsonDecode(raw) as Map<String, dynamic>;
        return true;
      }
    } catch (_) {}
    return false;
  }

  static Future<void> cerrar() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}