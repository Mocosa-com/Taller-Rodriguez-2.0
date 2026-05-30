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

  // Rutas que puede ver cualquier empleado logueado
static const _rutasEmpleado = {
  vehiculos, perfil, home, login
};

// Rutas que puede ver secretaria (+ las de empleado)
static const _rutasSecretaria = {
  vehiculos, perfil, home, login,
  clientes, facturacion, historialFacturas, caja, historialTurnos, reportes
};
static Route<dynamic> onGenerateRoute(RouteSettings settings) {
  final name = settings.name ?? login;

  if (SessionService.rolActual.isNotEmpty) {
    // Mecánico solo ve vehículos y perfil
    if (SessionService.esMecanico) {
      const rutasMecanico = {vehiculos, perfil, home, login};
      if (!rutasMecanico.contains(name)) {
        return MaterialPageRoute(
          builder: (_) => const VehiculosPage(),
          settings: const RouteSettings(name: vehiculos),
        );
      }
    }

    // Bloquear facturación si caja está cerrada
    if (name == facturacion) {
      return MaterialPageRoute(
        builder: (context) => FutureBuilder<bool>(
          future: _verificarCajaAbierta(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (snapshot.data == true) {
              return const FacturacionScreen();
            }
            // Caja cerrada — redirige a caja con mensaje
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Debes abrir la caja antes de facturar'),
                  backgroundColor: Colors.red,
                ),
              );
              Navigator.pushReplacementNamed(context, caja);
            });
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          },
        ),
        settings: settings,
      );
    }
  }

  final builder = _builders[name];
  if (builder != null) {
    return MaterialPageRoute(builder: builder, settings: settings);
  }

  return MaterialPageRoute(
    builder: (_) => const LoginPage(),
    settings: const RouteSettings(name: login),
  );
}

static Future<bool> _verificarCajaAbierta() async {
  final caja = await CajaService.getCajaAbierta();
  return caja != null;
}

  static final Map<String, WidgetBuilder> _builders = {
    historialFacturas: (_) => const HistorialFacturasPage(),
    login:             (_) => const LoginPage(),
    clientes:          (_) => const ClientesPage(),
    home:              (_) => const HomeScreen(),
    perfil:            (_) => const PerfilPage(),
    ofertas:           (_) => const OfertasScreen(),
    facturacion:       (_) => const FacturacionScreen(),
    inventario:        (_) => const InventarioPage(),
    caja:              (_) => const CajaPage(),
    empleados:         (_) => const EmpleadosPage(),
    vehiculos:         (_) => const VehiculosPage(),
    proveedores:       (_) => const ProveedoresScreen(),
    historialTurnos:   (_) => const HistorialTurnosPage(),
    reportes:          (_) => const ReportesScreen(),
  };

  static Map<String, WidgetBuilder> get routes => _builders;
}
