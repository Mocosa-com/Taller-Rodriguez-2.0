import 'package:flutter/material.dart';
import 'package:taller_rodriguez/services/session_service.dart';
import '../../models/menu_item_model.dart';
import '../../widgets/common/dashboard_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const List<_MenuItem> _allItems = [
    _MenuItem('Caja',          'assets/sidebar_false/caja.png',        '/caja'),
    _MenuItem('Clientes',      'assets/sidebar_false/cliente.png',     '/clientes'),
    _MenuItem('Empleados',     'assets/sidebar_false/empleados.png',   '/empleados'),
    _MenuItem('Ofertas',       'assets/sidebar_false/ofertas.png',     '/ofertas'),
    _MenuItem('Inventario',    'assets/sidebar_false/inventario.png',  '/inventario'),
    _MenuItem('Facturacion',   'assets/sidebar_false/facturacion.png', '/facturacion'),
    _MenuItem('Vehiculos',     'assets/sidebar_false/coche.png',       '/vehiculos'),
    _MenuItem('Reportes',      'assets/sidebar_false/reportes.png',    '/reportes'),
    _MenuItem('Proveedores',   'assets/sidebar_false/proveedores.png', '/proveedores'),
    _MenuItem('Perfil',        'assets/sidebar_false/perfil.png',      '/perfil'),
  ];

  List<_MenuItem> get _visibleItems =>
      _allItems.where((i) => SessionService.puedeAcceder(i.ruta)).toList();

  @override
  Widget build(BuildContext context) {
    final items = _visibleItems;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              color: const Color(0xFFF0F0F0),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset('assets/logo_taller.png',
                            width: 50, height: 50),
                        const SizedBox(width: 12),
                        const Text(
                          'Taller Rodriguez',
                          style: TextStyle(
                              fontSize: 26, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/perfil'),
                    child: _buildUserAvatar(),
                  ),
                ],
              ),
            ),

            // ── Badge de rol ────────────────────────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _colorRol(),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _labelRol(),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 8),

            // ── Grid de módulos ─────────────────────────────────────
            Expanded(
              child: items.isEmpty
                  ? const Center(
                      child: Text('No tienes permisos para ver módulos'))
                  : Center(
                      child: ConstrainedBox(
                        constraints:
                            const BoxConstraints(maxWidth: 1000),
                        child: GridView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 20),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 1,
                          ),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return DashboardCard(
                              item: MenuItemModel(
                                  label: item.label,
                                  imagePath: item.imagePath),
                              ruta: item.ruta,
                            );
                          },
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserAvatar() {
    final userData = SessionService.currentUser ?? {};
    final fotoUrl  = userData['foto_url'] as String?;
    final nombre   = userData['nombre'] as String? ?? 'Usuario';

    return Row(
      children: [
        Text(nombre,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(width: 10),
        CircleAvatar(
          radius: 22,
          backgroundColor: Colors.grey[300],
          backgroundImage: (fotoUrl != null && fotoUrl.isNotEmpty)
              ? NetworkImage(fotoUrl)
              : null,
          child: (fotoUrl == null || fotoUrl.isEmpty)
              ? const Icon(Icons.person, size: 24, color: Colors.white)
              : null,
        ),
      ],
    );
  }

  String _labelRol() {
    if (SessionService.esRoot)       return '⚡ Root';
    if (SessionService.esAdmin)      return 'Administrador';
    if (SessionService.esSecretaria) return 'Secretaria';
    if (SessionService.esMecanico)   return 'Mecánico';
    return '';
  }

  Color _colorRol() {
    if (SessionService.esRoot)       return Colors.deepPurple;
    if (SessionService.esAdmin)      return Colors.red[700]!;
    if (SessionService.esSecretaria) return Colors.blue[600]!;
    if (SessionService.esMecanico)   return Colors.green[600]!;
    return Colors.grey;
  }
}

class _MenuItem {
  final String label, imagePath, ruta;
  const _MenuItem(this.label, this.imagePath, this.ruta);
}