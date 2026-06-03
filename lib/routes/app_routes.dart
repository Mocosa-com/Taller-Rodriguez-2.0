import 'package:flutter/material.dart';
import 'package:taller_rodriguez/services/session_service.dart';
import '../pages/clientes/clientes.dart';
import '../pages/auth/login_pages.dart';
import '../pages/home/home_screen.dart';
import '../pages/perfil/perfil.dart';
import '../pages/ofertas/ofertas.dart';
import '../pages/facturacion/factura.dart';
import '../pages/facturacion/historialFacturas.dart';
import '../pages/inventario/inventario.dart';
import '../pages/caja/caja.dart';
import '../pages/caja/historialTurnos.dart';
import '../pages/empleados/empleados.dart';
import '../pages/vehiculos/vehiculos.dart';
import '../pages/proveedores/proveedores.dart';
import '../pages/reportes/reportes.dart';
import 'package:taller_rodriguez/services/caja_service.dart';

class AppRoutes {
  static const String clientes          = '/clientes';
  static const String login             = '/login';
  static const String home              = '/dashboard';
  static const String perfil            = '/perfil';
  static const String ofertas           = '/ofertas';
  static const String facturacion       = '/facturacion';
  static const String inventario        = '/inventario';
  static const String caja              = '/caja';
  static const String empleados         = '/empleados';
  static const String vehiculos         = '/vehiculos';
  static const String proveedores       = '/proveedores';
  static const String historialTurnos   = '/historialTurnos';
  static const String reportes          = '/reportes';
  static const String historialFacturas = '/historialFacturas';

  // ── Ruta de inicio por rol ──────────────────────────────────────
  static String get _rutaInicioRol {
    if (SessionService.esMecanico) return vehiculos;
    return home;
  }

  // ── Generador de rutas con control de acceso ────────────────────
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final name = settings.name ?? login;

    // Sin sesión → solo puede ir a login
    if (SessionService.rolActual.isEmpty) {
      return _ir(const LoginPage(), login);
    }

    // Ruta no permitida para el rol actual → redirigir a inicio del rol
    if (!SessionService.puedeAcceder(name)) {
      final inicio = _rutaInicioRol;
      final builder = _builders[inicio]!;
      return MaterialPageRoute(
        builder: builder,
        settings: RouteSettings(name: inicio),
      );
    }

    // Facturación requiere caja abierta
    if (name == facturacion) {
      return MaterialPageRoute(
        builder: (context) => FutureBuilder<bool>(
          future: _verificarCajaAbierta(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                  body: Center(child: CircularProgressIndicator()));
            }
            if (snapshot.data == true) return const FacturacionScreen();

            WidgetsBinding.instance.addPostFrameCallback((_) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Debes abrir la caja antes de facturar'),
                  backgroundColor: Colors.red,
                ),
              );
              Navigator.pushReplacementNamed(context, caja);
            });
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          },
        ),
        settings: settings,
      );
    }

    final builder = _builders[name];
    if (builder != null) {
      return MaterialPageRoute(builder: builder, settings: settings);
    }

    return _ir(const LoginPage(), login);
  }

  static Route<dynamic> _ir(Widget page, String name) =>
      MaterialPageRoute(
          builder: (_) => page, settings: RouteSettings(name: name));

  static Future<bool> _verificarCajaAbierta() async {
    final c = await CajaService.getCajaAbierta();
    return c != null;
  }

  static final Map<String, WidgetBuilder> _builders = {
    login:             (_) => const LoginPage(),
    home:              (_) => const HomeScreen(),
    perfil:            (_) => const PerfilPage(),
    clientes:          (_) => const ClientesPage(),
    ofertas:           (_) => const OfertasScreen(),
    facturacion:       (_) => const FacturacionScreen(),
    historialFacturas: (_) => const HistorialFacturasPage(),
    inventario:        (_) => const InventarioPage(),
    caja:              (_) => const CajaPage(),
    historialTurnos:   (_) => const HistorialTurnosPage(),
    empleados:         (_) => const EmpleadosPage(),
    vehiculos:         (_) => const VehiculosPage(),
    proveedores:       (_) => const ProveedoresScreen(),
    reportes:          (_) => const ReportesScreen(),
  };

  static Map<String, WidgetBuilder> get routes => _builders;
}