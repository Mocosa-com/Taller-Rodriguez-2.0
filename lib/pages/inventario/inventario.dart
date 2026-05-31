import 'package:flutter/material.dart';
import 'package:taller_rodriguez/widgets/navigation/sidebar.dart';
import 'package:taller_rodriguez/widgets/inputs/busqueda.dart';
import 'package:taller_rodriguez/widgets/inputs/select.dart';
import 'package:taller_rodriguez/widgets/modals/agregar_producto_modal.dart';
import 'package:taller_rodriguez/widgets/modals/entrada_stock_modal.dart';
import 'package:taller_rodriguez/widgets/modals/salida_stock_modal.dart';
import 'package:taller_rodriguez/widgets/modals/editar_producto_modal.dart';
import 'package:taller_rodriguez/widgets/modals/editar_servicio_modal.dart';
import 'package:taller_rodriguez/widgets/modals/eliminar_producto_modal.dart';
import 'package:taller_rodriguez/services/inventario_api.dart';
import 'package:taller_rodriguez/services/proveedor_api.dart';

class InventarioPage extends StatefulWidget {
  const InventarioPage({super.key});

  @override
  State<InventarioPage> createState() => InventarioPageState();
}

class InventarioPageState extends State<InventarioPage> {
  final TextEditingController _searchController = TextEditingController();
  String? _filtroProducto;
  String? _filtroProveedor;
  String? _ordenStock;
  final InventarioApi _api = InventarioApi();
  final ProveedorApi _proveedorApi = ProveedorApi();
  bool _cargando = false;
  bool _hayFiltrosActivos = false;
  List<Map<String, dynamic>> _proveedores = [];
  List<Map<String, dynamic>> _productos = [];

  List<Map<String, dynamic>> get _productosStockBajo => _productos
      .where((p) =>
          p['tipo']?.toString().toLowerCase() != 'servicio' &&
          (int.tryParse(p['stock']?.toString() ?? '0') ?? 0) <=
              (int.tryParse(p['stock_minimo']?.toString() ?? '0') ?? 0))
      .toList();

  List<String> get _clasificacionesOptions {
    final Set<String> clasificaciones = {'Todos'};
    for (var p in _productos) {
      final clasif = p['clasificacion']?.toString();
      if (clasif != null && clasif.isNotEmpty) clasificaciones.add(clasif);
    }
    final list = clasificaciones.toList()..sort();
    if (_filtroProducto != null && _filtroProducto!.isNotEmpty && !list.contains(_filtroProducto)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _filtroProducto = null);
      });
    }
    return list;
  }

  @override
  void initState() {
    super.initState();
    _cargarDatosIniciales();
  }

  Future<void> _cargarDatosIniciales() async {
    setState(() => _cargando = true);
    final resultados = await Future.wait([
      _proveedorApi.obtenerProveedores(),
      _api.obtenerInventario(),
    ]);
    if (!mounted) return;
    setState(() {
      _proveedores = resultados[0];
      _productos = resultados[1];
      _cargando = false;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarProductos({String? busqueda}) async {
    setState(() => _cargando = true);
    final textoBusqueda = busqueda ?? _searchController.text.trim();
    _hayFiltrosActivos = textoBusqueda.isNotEmpty ||
        _filtroProducto != null ||
        _filtroProveedor != null ||
        _ordenStock != null;

    String? idProveedor;
    if (_filtroProveedor != null && _filtroProveedor!.isNotEmpty) {
      final prov = _proveedores.firstWhere(
        (p) => p['nombre']?.toString() == _filtroProveedor,
        orElse: () => {},
      );
      idProveedor = prov['id']?.toString();
    }

    final productos = await _api.obtenerInventario(
      busqueda: textoBusqueda.isEmpty ? null : textoBusqueda,
      idProveedor: idProveedor,
      clasificacion: _filtroProducto,
      ordenStock: _ordenStock,
    );

    if (!mounted) return;
    setState(() {
      _productos = productos;
      _cargando = false;
    });
  }

  void _ejecutarBusqueda() {
    final texto = _searchController.text.trim();
    _cargarProductos(busqueda: texto.isEmpty ? null : texto);
  }

  void _onSearchSubmitted(String valor) => _ejecutarBusqueda();
  void _onSearchPressed() => _ejecutarBusqueda();

  static const Color _headerColor = Color(0xFFA61B1B);

  String _formatearPrecio(dynamic valor) {
    if (valor == null) return '\$0.00';
    final numero = (valor is num) ? valor.toDouble() : double.tryParse(valor.toString()) ?? 0;
    return '\$${numero.toStringAsFixed(2)}';
  }

  String _obtenerNombreProveedor(String? idProveedor) {
    if (idProveedor == null || idProveedor.isEmpty) return '-';
    final proveedor = _proveedores.firstWhere(
      (p) => p['id']?.toString() == idProveedor,
      orElse: () => {},
    );
    return proveedor['nombre']?.toString() ?? '-';
  }

  Widget _buildBannerStockBajo() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        border: Border.all(color: const Color(0xFFFFB300)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFE65100), size: 20),
              const SizedBox(width: 8),
              Text(
                '${_productosStockBajo.length} producto${_productosStockBajo.length > 1 ? 's' : ''} con stock bajo',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE65100),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._productosStockBajo.map((p) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    const SizedBox(width: 28),
                    const Icon(Icons.circle, size: 6, color: Color(0xFFE65100)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${p['nombre']} — Stock actual: ${p['stock']} / Mínimo: ${p['stock_minimo']}',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF5D4037)),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isWide = MediaQuery.of(context).size.width > 1000;

    return Scaffold(
      drawer: isWide ? null : const SidebarDrawerContent(),
      appBar: isWide ? null : AppBar(title: const Text('Inventario')),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => mostrarModalAgregarProducto(context, onSuccess: _cargarProductos),
        backgroundColor: const Color(0xFFC0392B),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Agregar producto',
            style: TextStyle(color: Colors.white, fontFamily: 'Itim')),
      ),

      body: Row(
        children: [
          const Sidebar(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isWide)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 25),
                      child: Text(
                        'Inventario',
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Itim',
                        ),
                      ),
                    ),
                  if (isWide) const SizedBox(height: 20),

                  // Filtros
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    child: isWide
                        ? Row(
                            children: [
                              Expanded(
                                child: SearchField(
                                  hint: 'Buscar producto',
                                  controller: _searchController,
                                  onSubmitted: _onSearchSubmitted,
                                  onSearch: _onSearchPressed,
                                ),
                              ),
                              const SizedBox(width: 12),
                              FilterDropdown(
                                label: 'Filtrar productos:',
                                value: _filtroProducto,
                                options: ['Todos', 'Aceites y fluidos', 'Frenos', 'Motor', 'Eléctrico', 'Suspensión', 'Transmisión', 'Carrocería', 'Accesorios'],
                                onChanged: (val) {
                                  setState(() {
                                    _filtroProducto = (val == 'Todos' || val == null) ? null : val;
                                  });
                                  _cargarProductos();
                                },
                              ),
                              const SizedBox(width: 12),
                              FilterDropdown(
                                label: 'Filtrar por proveedor:',
                                value: _filtroProveedor,
                                options: ['Todos', ..._proveedores.map((p) => p['nombre']?.toString() ?? '')],
                                onChanged: (val) {
                                  setState(() {
                                    _filtroProveedor = (val == 'Todos' || val == null) ? null : val;
                                  });
                                  _cargarProductos();
                                },
                              ),
                              if (_hayFiltrosActivos) ...[
                                const SizedBox(width: 12),
                                _LimpiarFiltrosButton(
                                  onTap: () {
                                    setState(() {
                                      _searchController.clear();
                                      _filtroProducto = null;
                                      _filtroProveedor = null;
                                      _ordenStock = null;
                                      _hayFiltrosActivos = false;
                                    });
                                    _cargarProductos();
                                  },
                                ),
                              ],
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SearchField(
                                hint: 'Buscar producto',
                                controller: _searchController,
                                onSubmitted: _onSearchSubmitted,
                                onSearch: _onSearchPressed,
                              ),
                              const SizedBox(height: 10),
                              FilterDropdown(
                                label: 'Filtrar productos:',
                                value: _filtroProducto,
                                options: ['Todos', 'Aceites y fluidos', 'Frenos', 'Motor', 'Eléctrico', 'Suspensión', 'Transmisión', 'Carrocería', 'Accesorios'],
                                onChanged: (val) {
                                  setState(() {
                                    _filtroProducto = (val == 'Todos' || val == null) ? null : val;
                                  });
                                  _cargarProductos();
                                },
                              ),
                              const SizedBox(height: 10),
                              FilterDropdown(
                                label: 'Filtrar por proveedor:',
                                value: _filtroProveedor,
                                options: ['Todos', ..._proveedores.map((p) => p['nombre']?.toString() ?? '')],
                                onChanged: (val) {
                                  setState(() {
                                    _filtroProveedor = (val == 'Todos' || val == null) ? null : val;
                                  });
                                  _cargarProductos();
                                },
                              ),
                              if (_hayFiltrosActivos) ...[
                                const SizedBox(height: 10),
                                _LimpiarFiltrosButton(
                                  onTap: () {
                                    setState(() {
                                      _searchController.clear();
                                      _filtroProducto = null;
                                      _filtroProveedor = null;
                                      _ordenStock = null;
                                      _hayFiltrosActivos = false;
                                    });
                                    _cargarProductos();
                                  },
                                ),
                              ],
                            ],
                          ),
                  ),

                  const SizedBox(height: 10),

                  // TABLA DESKTOP
                  if (isWide)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 25),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          )
                        ],
                      ),
                      child: _cargando
                          ? const SizedBox(
                              height: 200,
                              child: Center(child: CircularProgressIndicator()),
                            )
                          : _productos.isEmpty
                              ? _buildEmptyState()
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(15),
                                  child: Column(
                                    children: [
                                      _buildTableHeader(),
                                      SizedBox(
                                        height: 400,
                                        child: SingleChildScrollView(
                                          scrollDirection: Axis.vertical,
                                          child: ListView.separated(
                                            shrinkWrap: true,
                                            physics: const NeverScrollableScrollPhysics(),
                                            itemCount: _productos.length,
                                            separatorBuilder: (_, __) => const Divider(height: 1),
                                            itemBuilder: (context, index) {
                                              final p = _productos[index];
                                              final esProducto = p['tipo']?.toString().toLowerCase() != 'servicio';
                                              return Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                child: Row(
                                                  children: [
                                                    Expanded(flex: 1, child: Text(
                                                      p['sku']?.toString().isNotEmpty == true ? p['sku'].toString() : '-',
                                                      style: const TextStyle(fontSize: 13),
                                                      overflow: TextOverflow.ellipsis,
                                                    )),
                                                    Expanded(flex: 2, child: Text(
                                                      p['nombre']?.toString() ?? '',
                                                      style: const TextStyle(fontSize: 13),
                                                      overflow: TextOverflow.ellipsis,
                                                    )),
                                                    Expanded(flex: 1, child: _cellTipo(p['tipo']?.toString() ?? '')),
                                                    Expanded(flex: 1, child: Text(p['stock']?.toString() ?? '0', style: const TextStyle(fontSize: 13))),
                                                    Expanded(flex: 1, child: Text(_formatearPrecio(p['precio_compra']), style: const TextStyle(fontSize: 13))),
                                                    Expanded(flex: 1, child: Text(_formatearPrecio(p['precio_venta']), style: const TextStyle(fontSize: 13))),
                                                    Expanded(flex: 2, child: Tooltip(
                                                      message: _obtenerNombreProveedor(p['id_proveedor']?.toString()),
                                                      child: Text(
                                                        _obtenerNombreProveedor(p['id_proveedor']?.toString()),
                                                        style: const TextStyle(fontSize: 13),
                                                        overflow: TextOverflow.ellipsis,
                                                        maxLines: 1,
                                                      ),
                                                    )),
                                                    Expanded(flex: 2, child: Tooltip(
                                                      message: p['descripcion']?.toString() ?? '',
                                                      child: Text(
                                                        p['descripcion']?.toString() ?? '',
                                                        style: const TextStyle(fontSize: 13),
                                                        overflow: TextOverflow.ellipsis,
                                                        maxLines: 2,
                                                      ),
                                                    )),
                                                    Expanded(flex: 2, child: Text(
                                                      p['clasificacion']?.toString() ?? '',
                                                      style: const TextStyle(fontSize: 13),
                                                      overflow: TextOverflow.ellipsis,
                                                    )),
                                                    Expanded(flex: 2, child: Wrap(
                                                      spacing: 4,
                                                      runSpacing: 2,
                                                      children: [
                                                        _accionBtn('Editar', Icons.edit, Colors.blue, () => esProducto
                                                          ? mostrarModalEditarProducto(context, p, onSuccess: _cargarProductos)
                                                          : mostrarModalEditarServicio(context, p, onSuccess: _cargarProductos)),
                                                        if (esProducto) _accionBtn('+ Stock', Icons.add, Colors.green, () => mostrarModalEntradaStock(context, p['id']?.toString() ?? '', p['nombre']?.toString() ?? '', onSuccess: _cargarProductos)),
                                                        if (esProducto) _accionBtn('- Stock', Icons.remove, Colors.orange, () => mostrarModalSalidaStock(context, p['id']?.toString() ?? '', p['nombre']?.toString() ?? '', int.tryParse(p['stock']?.toString() ?? '0') ?? 0, onSuccess: _cargarProductos)),
                                                        _accionBtn('Eliminar', Icons.delete, Colors.red, () => mostrarModalEliminarProducto(context, p['id']?.toString() ?? '', p['nombre']?.toString() ?? '', onSuccess: _cargarProductos)),
                                                      ],
                                                    )),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                    ),

                  // LISTA MÓVIL
                  if (!isWide)
                    _cargando
                        ? const Padding(
                            padding: EdgeInsets.all(40),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : _productos.isEmpty
                            ? _buildEmptyStateMobile()
                            : _buildCardList(),

                  // ✅ BANNER DE STOCK BAJO - AHORA ABAJO DE TODO
                  if (_productosStockBajo.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
                      child: _buildBannerStockBajo(),
                    ),

                  // Espacio para que el FAB no tape el último elemento
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

 
  Widget _buildEmptyState() {
    return SizedBox(
      height: 400,
      child: Column(
        children: [
          _buildTableHeader(),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _hayFiltrosActivos ? Icons.search_off : Icons.add_circle_outline,
                  size: 80,
                  color: Colors.black87,
                ),
                const SizedBox(height: 16),
                Text(
                  _hayFiltrosActivos
                      ? 'NO HAY RESULTADOS\nPARA LA BÚSQUEDA ACTUAL'
                      : 'NO SE HA AGREGADO NINGÚN PRODUCTO\nAL INVENTARIO',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    const style = TextStyle(color: _headerColor, fontWeight: FontWeight.bold, fontSize: 13);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFFFF0F0),
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      child: Row(
        children: [
          const Expanded(flex: 1, child: Text('SKU', style: style)),
          const Expanded(flex: 2, child: Text('Producto', style: style)),
          const Expanded(flex: 1, child: Text('Tipo', style: style)),
          Expanded(
            flex: 1,
            child: Row(
              children: [
                const Text('Stock', style: style),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      if (_ordenStock == 'asc') _ordenStock = 'desc';
                      else if (_ordenStock == 'desc') _ordenStock = null;
                      else _ordenStock = 'asc';
                    });
                    _cargarProductos();
                  },
                  child: Icon(
                    _ordenStock == 'asc'
                        ? Icons.arrow_downward
                        : _ordenStock == 'desc'
                            ? Icons.arrow_upward
                            : Icons.unfold_more,
                    size: 16,
                    color: _headerColor,
                  ),
                ),
              ],
            ),
          ),
          const Expanded(flex: 1, child: Text('Compra', style: style)),
          const Expanded(flex: 1, child: Text('Venta', style: style)),
          const Expanded(flex: 2, child: Text('Proveedor', style: style)),
          const Expanded(flex: 2, child: Text('Descripción', style: style)),
          const Expanded(flex: 2, child: Text('Clasificación', style: style)),
          const Expanded(flex: 2, child: Text('Acciones', style: style)),
        ],
      ),
    );
  }

  Widget _cellTipo(String tipo) {
    final esProducto = tipo.toLowerCase() == 'producto';
    return Text(
      tipo.isEmpty ? '-' : tipo,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: esProducto ? Colors.blue : const Color(0xFFFF8C00),
      ),
    );
  }

  Widget _buildEmptyStateMobile() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _hayFiltrosActivos ? Icons.search_off : Icons.add_circle_outline,
            size: 80,
            color: Colors.black87,
          ),
          const SizedBox(height: 16),
          Text(
            _hayFiltrosActivos
                ? 'NO HAY RESULTADOS\nPARA LA BÚSQUEDA ACTUAL'
                : 'NO SE HA AGREGADO NINGÚN PRODUCTO\nAL INVENTARIO',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 25),
      itemCount: _productos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final p = _productos[index];
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF0F0),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    Text('#${p['id'] ?? ''}',
                        style: const TextStyle(color: _headerColor, fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(p['nombre']?.toString() ?? '',
                          style: const TextStyle(color: _headerColor, fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: _headerColor, borderRadius: BorderRadius.circular(6)),
                      child: Text(p['clasificacion']?.toString() ?? '',
                          style: const TextStyle(color: Colors.white, fontSize: 11)),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    _cardRow('Stock', p['stock']?.toString() ?? '0'),
                    _cardRow('Precio compra', _formatearPrecio(p['precio_compra'])),
                    _cardRow('Precio venta', _formatearPrecio(p['precio_venta'])),
                    _cardRow('Proveedor', _obtenerNombreProveedor(p['id_proveedor']?.toString())),
                    _cardRow('Descripción', p['descripcion']?.toString() ?? ''),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 14, right: 14, bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _accionBtnMobile('Editar', Icons.edit, Colors.blue, () {
                          final esProducto = p['tipo']?.toString().toLowerCase() != 'servicio';
                          if (esProducto) {
                            mostrarModalEditarProducto(context, p, onSuccess: _cargarProductos);
                          } else {
                            mostrarModalEditarServicio(context, p, onSuccess: _cargarProductos);
                          }
                        }),
                        if (p['tipo']?.toString().toLowerCase() != 'servicio') ...[
                          _accionBtnMobile('Agregar Stock', Icons.add, Colors.green,
                              () => mostrarModalEntradaStock(context, p['id']?.toString() ?? '', p['nombre']?.toString() ?? '', onSuccess: _cargarProductos)),
                          _accionBtnMobile('Salida Stock', Icons.remove, Colors.orange,
                              () => mostrarModalSalidaStock(context, p['id']?.toString() ?? '', p['nombre']?.toString() ?? '', int.tryParse(p['stock']?.toString() ?? '0') ?? 0, onSuccess: _cargarProductos)),
                        ],
                        _accionBtnMobile('Eliminar', Icons.delete, Colors.red,
                            () => mostrarModalEliminarProducto(context, p['id']?.toString() ?? '', p['nombre']?.toString() ?? '', onSuccess: _cargarProductos)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _cardRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _accionBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return TextButton(
      onPressed: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }

  Widget _accionBtnMobile(String label, IconData icon, Color color, VoidCallback onTap) {
    return TextButton(
      onPressed: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}

class _LimpiarFiltrosButton extends StatefulWidget {
  final VoidCallback onTap;
  const _LimpiarFiltrosButton({required this.onTap});

  @override
  State<_LimpiarFiltrosButton> createState() => _LimpiarFiltrosButtonState();
}

class _LimpiarFiltrosButtonState extends State<_LimpiarFiltrosButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: _hovered ? const Color(0xFF7B2FF7) : const Color(0xFF6A1B9A),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7B2FF7).withValues(alpha: _hovered ? 0.6 : 0.4),
                blurRadius: _hovered ? 12 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.filter_alt_off, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Limpiar filtros',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'Itim')),
            ],
          ),
        ),
      ),
    );
  }
}