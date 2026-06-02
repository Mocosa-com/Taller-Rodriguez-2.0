import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:taller_rodriguez/widgets/navigation/sidebar.dart';
import 'package:taller_rodriguez/widgets/inputs/busqueda.dart';
import 'package:taller_rodriguez/widgets/modals/agregar_producto_modal.dart';
import 'package:taller_rodriguez/widgets/modals/entrada_stock_modal.dart';
import 'package:taller_rodriguez/widgets/modals/salida_stock_modal.dart';
import 'package:taller_rodriguez/widgets/modals/editar_producto_modal.dart';
import 'package:taller_rodriguez/widgets/modals/editar_servicio_modal.dart';
import 'package:taller_rodriguez/widgets/modals/eliminar_producto_modal.dart';
import 'package:taller_rodriguez/services/inventario_api.dart';
import 'package:taller_rodriguez/services/proveedor_api.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';

class InventarioPage extends StatefulWidget {
  const InventarioPage({super.key});

  @override
  State<InventarioPage> createState() => InventarioPageState();
}

class InventarioPageState extends State<InventarioPage> {
  final TextEditingController _searchController = TextEditingController();

  List<String> _clasificacionesPersonalizadas = [];
  String? _clasificacionSeleccionada;
  String? _filtroProveedor;
  String? _ordenStock;

  final InventarioApi _api = InventarioApi();
  final ProveedorApi _proveedorApi = ProveedorApi();

  bool _cargando = false;
  bool _importando = false;
  bool _hayFiltrosActivos = false;

  List<Map<String, dynamic>> _proveedores = [];
  List<Map<String, dynamic>> _productos = [];

  static const Color _headerColor = Color(0xFFA61B1B);

  List<String> get _todasLasClasificaciones {
    final fromData = _productos
        .map((p) => p['clasificacion']?.toString().trim() ?? '')
        .where((c) => c.isNotEmpty)
        .toSet();
    final combined = {...fromData, ..._clasificacionesPersonalizadas}.toList()..sort();
    return combined;
  }

  List<Map<String, dynamic>> get _productosStockBajo => _productos
      .where((p) =>
          p['tipo']?.toString().toLowerCase() != 'servicio' &&
          (int.tryParse(p['stock']?.toString() ?? '0') ?? 0) <=
              (int.tryParse(p['stock_minimo']?.toString() ?? '0') ?? 0))
      .toList();

  @override
  void initState() {
    super.initState();
    _cargarDatosIniciales();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  Future<void> _cargarProductos({String? busqueda}) async {
    setState(() => _cargando = true);

    final textoBusqueda = busqueda ?? _searchController.text.trim();

    _hayFiltrosActivos = textoBusqueda.isNotEmpty ||
        _clasificacionSeleccionada != null ||
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
      clasificacion: _clasificacionSeleccionada,
      ordenStock: _ordenStock,
    );

    if (!mounted) return;

    setState(() {
      _productos = productos;
      _cargando = false;
    });
  }

  void _limpiarFiltros() {
    setState(() {
      _searchController.clear();
      _clasificacionSeleccionada = null;
      _filtroProveedor = null;
      _ordenStock = null;
      _hayFiltrosActivos = false;
    });
    _cargarProductos();
  }

  void _agregarClasificacion() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nueva clasificación'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Ej: Filtros, Neumáticos...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC0392B)),
            onPressed: () {
              final val = ctrl.text.trim();
              if (val.isNotEmpty && !_todasLasClasificaciones.contains(val)) {
                setState(() => _clasificacionesPersonalizadas.add(val));
              }
              Navigator.pop(context);
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  void _editarClasificacion(String clasifActual) {
    final ctrl = TextEditingController(text: clasifActual);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Editar clasificación'),
        content: TextField(controller: ctrl),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _clasificacionesPersonalizadas.remove(clasifActual);
                if (_clasificacionSeleccionada == clasifActual) _clasificacionSeleccionada = null;
              });
              Navigator.pop(context);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC0392B)),
            onPressed: () {
              final val = ctrl.text.trim();
              if (val.isNotEmpty) {
                setState(() {
                  final i = _clasificacionesPersonalizadas.indexOf(clasifActual);
                  if (i >= 0) _clasificacionesPersonalizadas[i] = val;
                  if (_clasificacionSeleccionada == clasifActual) _clasificacionSeleccionada = val;
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportarCSV() async {
    try {
      final sb = StringBuffer();
      sb.writeln('SKU,Nombre,Tipo,Clasificacion,Stock,Stock Minimo,Precio Compra,Precio Venta,Descripcion,Proveedor');

      for (final p in _productos) {
        String esc(dynamic v) {
          final s = v?.toString() ?? '';
          return s.contains(',') || s.contains('"') || s.contains('\n')
              ? '"${s.replaceAll('"', '""')}"'
              : s;
        }

        final proveedor = _obtenerNombreProveedor(p['id_proveedor']?.toString());

        sb.writeln([
          esc(p['sku']),
          esc(p['nombre']),
          esc(p['tipo']),
          esc(p['clasificacion']),
          esc(p['stock']),
          esc(p['stock_minimo']),
          esc(p['precio_compra']),
          esc(p['precio_venta']),
          esc(p['descripcion']),
          esc(proveedor),
        ].join(','));
      }

      final bytes = utf8.encode(sb.toString());
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", "inventario_${DateTime.now().toIso8601String().split('T')[0]}.csv")
        ..style.display = 'none';

      html.document.body!.append(anchor);
      anchor.click();
      anchor.remove();
      html.Url.revokeObjectUrl(url);

      _snack('✅ CSV descargado correctamente');
    } catch (e) {
      _snack('Error al exportar: $e', isError: true);
    }
  }


     Future<void> _importarCSV() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Importar CSV'),
        content: const Text(
          'CSV esperado:\n'
          'SKU,Nombre,Tipo,Clasificacion,Descripcion,Precio Compra,Precio Venta,Stock,Stock Minimo',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC0392B)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Seleccionar archivo', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final bytes = result.files.first.bytes;
      if (bytes == null) return;

      final content = utf8.decode(bytes);
      final lines = content.split('\n').where((l) => l.trim().isNotEmpty).toList();

      setState(() => _importando = true);
      int importados = 0;
      int errores = 0;
      List<String> logErrores = [];

      for (int i = 1; i < lines.length; i++) {
        try {
          final cols = _parsearCSVLinea(lines[i].trim());
          if (cols.length < 2) continue;

          final producto = {
            'sku': cols.length > 0 ? cols[0].trim() : '',
            'nombre': cols.length > 1 ? cols[1].trim() : '',
            'tipo': (cols.length > 2 && cols[2].trim().isNotEmpty) ? cols[2].trim() : 'Producto',
            'clasificacion': (cols.length > 3 && cols[3].trim().isNotEmpty) ? cols[3].trim() : 'General',
            'descripcion': (cols.length > 4) ? cols[4].trim() : '',
            'precio_compra': (cols.length > 5) ? (double.tryParse(cols[5].trim().replaceAll(',', '.')) ?? 0.0) : 0.0,
            'precio_venta': (cols.length > 6) ? (double.tryParse(cols[6].trim().replaceAll(',', '.')) ?? 0.0) : 0.0,
            'stock': (cols.length > 7) ? (int.tryParse(cols[7].trim()) ?? 0) : 0,
            'stock_minimo': (cols.length > 8) ? (int.tryParse(cols[8].trim()) ?? 0) : 5,
          };

          if (producto['nombre'].toString().isEmpty) {
            throw Exception('Nombre vacío');
          }

          final res = await _api.crearProducto(producto);

          if (res != null && (res['success'] == true || res['id'] != null)) {
            importados++;
          } else {
            errores++;
            logErrores.add('Línea ${i+1}: Error en API');
          }
        } catch (e) {
          errores++;
          logErrores.add('Línea ${i+1}: $e');
        }
      }

      setState(() => _importando = false);
      await _cargarProductos();

      if (importados > 0) {
        _snack('$importados producto(s) importados correctamente', isError: false);
      }
      if (errores > 0) {
        _snack('$errores con error\n${logErrores.take(3).join("\n")}', isError: true);
      }
    } catch (e) {
      setState(() => _importando = false);
      _snack('Error general: $e', isError: true);
    }
  }

  List<String> _parsearCSVLinea(String linea) {
    final result = <String>[];
    var campo = StringBuffer();
    var enComillas = false;
    var i = 0;

    while (i < linea.length) {
      final c = linea[i];
      if (c == '"') {
        enComillas = !enComillas;
        i++;
        continue;
      } else if (c == ',' && !enComillas) {
        result.add(campo.toString());
        campo = StringBuffer();
      } else {
        campo.write(c);
      }
      i++;
    }
    result.add(campo.toString());
    return result;
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : const Color(0xFFC0392B),
      behavior: SnackBarBehavior.floating,
    ));
  }

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
        label: const Text('Agregar producto', style: TextStyle(color: Colors.white, fontFamily: 'Itim')),
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
           
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 25),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Inventario',
          style: TextStyle(
              fontSize: 42, 
              fontWeight: FontWeight.bold, 
              fontFamily: 'Itim',
              color: Color(0xFF2C2C2C))),

      const SizedBox(height: 16),

     
      Row(
        children: [
          Expanded(
            flex: 3,
            child: SearchField(
              hint: 'Buscar producto o servicio',
              controller: _searchController,
              onSubmitted: (_) => _cargarProductos(),
              onSearch: () => _cargarProductos(),
            ),
          ),

          const SizedBox(width: 16),

        
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButton<String?>(
              value: _filtroProveedor,
              hint: const Text('Todos los proveedores'),
              underline: const SizedBox(),
              borderRadius: BorderRadius.circular(12),
              isDense: true,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
              icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFFC0392B)),
              items: [
                const DropdownMenuItem(value: null, child: Text('Todos los proveedores')),
                ..._proveedores.map((p) => DropdownMenuItem(
                      value: p['nombre']?.toString(),
                      child: Text(p['nombre']?.toString() ?? ''),
                    )),
              ],
              onChanged: (val) {
                setState(() => _filtroProveedor = val);
                _cargarProductos();
              },
            ),
          ),

          const SizedBox(width: 12),

      
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButton<String?>(
              value: _ordenStock,
              hint: const Text('Sin orden'),
              underline: const SizedBox(),
              borderRadius: BorderRadius.circular(12),
              isDense: true,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
              icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFFC0392B)),
              items: const [
                DropdownMenuItem(value: null, child: Text('Sin orden')),
                DropdownMenuItem(value: 'asc', child: Text('Stock ↑ menor primero')),
                DropdownMenuItem(value: 'desc', child: Text('Stock ↓ mayor primero')),
              ],
              onChanged: (val) {
                setState(() => _ordenStock = val);
                _cargarProductos();
              },
            ),
          ),

          const SizedBox(width: 12),

         
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButton<String?>(
              value: null,
              hint: const Text('Todos'),
              underline: const SizedBox(),
              borderRadius: BorderRadius.circular(12),
              isDense: true,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
              icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFFC0392B)),
              items: const [
                DropdownMenuItem(value: null, child: Text('Todos')),
                DropdownMenuItem(value: 'Producto', child: Text('Producto')),
                DropdownMenuItem(value: 'Servicio', child: Text('Servicio')),
              ],
              onChanged: (val) {
                
              },
            ),
          ),

          const SizedBox(width: 16),

         
          OutlinedButton.icon(
            onPressed: _importarCSV,
            icon: const Icon(Icons.upload_file, size: 18, color: Color(0xFFC0392B)),
            label: const Text('Importar CSV'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFC0392B)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),

          const SizedBox(width: 10),

          OutlinedButton.icon(
            onPressed: _productos.isEmpty ? null : _exportarCSV,
            icon: const Icon(Icons.download, size: 18, color: Color(0xFFC0392B)),
            label: Text(_clasificacionSeleccionada != null 
                ? 'Exportar ${_clasificacionSeleccionada!}' 
                : 'Exportar Todo'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFC0392B)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    ],
  ),
),
                  const SizedBox(height: 12),
                  _buildClasificacionChips(),
                  const SizedBox(height: 12),

                 
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
                          ? const SizedBox(height: 300, child: Center(child: CircularProgressIndicator()))
                          : _productos.isEmpty
                              ? _buildEmptyState()
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(15),
                                  child: Column(
                                    children: [
                                      _buildTableHeader(),
                                      SizedBox(
                                        height: 450,
                                        child: ListView.separated(
                                          itemCount: _productos.length,
                                          separatorBuilder: (_, __) => const Divider(height: 1),
                                          itemBuilder: (_, i) => _buildTableRow(_productos[i]),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                    )
                 
                  else
                    _cargando
                        ? const Padding(
                            padding: EdgeInsets.all(40),
                            child: Center(child: CircularProgressIndicator()))
                        : _productos.isEmpty
                            ? _buildEmptyStateMobile()
                            : _buildCardList(),

                  if (_productosStockBajo.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
                      child: _buildBannerStockBajo(),
                    ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClasificacionChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          
          _ClasifChip(
            label: 'Todos',
            selected: _clasificacionSeleccionada == null,
            isPersonalizada: false,
            onTap: () {
              setState(() => _clasificacionSeleccionada = null);
              _cargarProductos();
            },
            onLongPress: null,
          ),
        
          ..._todasLasClasificaciones.map((c) {
            final esPersonalizada = _clasificacionesPersonalizadas.contains(c);
            return _ClasifChip(
              label: c,
              selected: _clasificacionSeleccionada == c,
              isPersonalizada: esPersonalizada,
              onTap: () {
                setState(() =>
                    _clasificacionSeleccionada = _clasificacionSeleccionada == c ? null : c);
                _cargarProductos();
              },
              onLongPress: esPersonalizada ? () => _editarClasificacion(c) : null,
            );
          }),
       
          ActionChip(
            avatar: const Icon(Icons.add, size: 16, color: Color(0xFFC0392B)),
            label: const Text('Nueva', style: TextStyle(fontSize: 12, color: Color(0xFFC0392B))),
            backgroundColor: const Color(0xFFFFF0F0),
            side: const BorderSide(color: Color(0xFFC0392B)),
            onPressed: _agregarClasificacion,
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
            child: GestureDetector(
              onTap: () {
                setState(() {
                  if (_ordenStock == 'asc') _ordenStock = 'desc';
                  else if (_ordenStock == 'desc') _ordenStock = null;
                  else _ordenStock = 'asc';
                });
                _cargarProductos();
              },
              child: Row(
                children: [
                  const Text('Stock', style: style),
                  const SizedBox(width: 4),
                  Icon(
                    _ordenStock == 'asc' ? Icons.arrow_downward
                        : _ordenStock == 'desc' ? Icons.arrow_upward
                        : Icons.unfold_more,
                    size: 16, color: _headerColor,
                  ),
                ],
              ),
            ),
          ),
          const Expanded(flex: 1, child: Text('Compra', style: style)),
          const Expanded(flex: 1, child: Text('Venta', style: style)),
          const Expanded(flex: 2, child: Text('Proveedor', style: style)),
          const Expanded(flex: 2, child: Text('Clasificación', style: style)),
          const Expanded(flex: 2, child: Text('Acciones', style: style)),
        ],
      ),
    );
  }

  Widget _buildTableRow(Map<String, dynamic> p) {
    final esProducto = p['tipo']?.toString().toLowerCase() != 'servicio';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(flex: 1, child: Text(p['sku']?.toString() ?? '-', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
          Expanded(flex: 2, child: Text(p['nombre']?.toString() ?? '', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
          Expanded(flex: 1, child: _cellTipo(p['tipo']?.toString() ?? '')),
          Expanded(flex: 1, child: Text(p['stock']?.toString() ?? '0', style: const TextStyle(fontSize: 13))),
          Expanded(flex: 1, child: Text(_formatearPrecio(p['precio_compra']), style: const TextStyle(fontSize: 13))),
          Expanded(flex: 1, child: Text(_formatearPrecio(p['precio_venta']), style: const TextStyle(fontSize: 13))),
          Expanded(flex: 2, child: Text(_obtenerNombreProveedor(p['id_proveedor']?.toString()), style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
          Expanded(flex: 2, child: Text(p['clasificacion']?.toString() ?? '', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
          Expanded(
            flex: 2,
            child: Wrap(
              spacing: 2, runSpacing: 2,
              children: [
                _accionBtn('Editar', Icons.edit, Colors.blue, () => esProducto
                    ? mostrarModalEditarProducto(context, p, onSuccess: _cargarProductos)
                    : mostrarModalEditarServicio(context, p, onSuccess: _cargarProductos)),
                if (esProducto) ...[
                  _accionBtn('+ Stock', Icons.add, Colors.green, () =>
                      mostrarModalEntradaStock(context, p['id']?.toString() ?? '', p['nombre']?.toString() ?? '', onSuccess: _cargarProductos)),
                  _accionBtn('- Stock', Icons.remove, Colors.orange, () =>
                      mostrarModalSalidaStock(context, p['id']?.toString() ?? '', p['nombre']?.toString() ?? '',
                          int.tryParse(p['stock']?.toString() ?? '0') ?? 0, onSuccess: _cargarProductos)),
                ],
                _accionBtn('Eliminar', Icons.delete, Colors.red, () =>
                    mostrarModalEliminarProducto(context, p['id']?.toString() ?? '', p['nombre']?.toString() ?? '', onSuccess: _cargarProductos)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cellTipo(String tipo) {
    final esProducto = tipo.toLowerCase() == 'producto';
    return Text(
      tipo.isEmpty ? '-' : tipo,
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
          color: esProducto ? Colors.blue : const Color(0xFFFF8C00)),
    );
  }

  Widget _accionBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 11, color: color)),
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
                Icon(_hayFiltrosActivos ? Icons.search_off : Icons.add_circle_outline, size: 80, color: Colors.black26),
                const SizedBox(height: 16),
                Text(
                  _hayFiltrosActivos ? 'NO HAY RESULTADOS\nPARA LA BÚSQUEDA ACTUAL' : 'INVENTARIO VACÍO',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateMobile() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_hayFiltrosActivos ? Icons.search_off : Icons.add_circle_outline, size: 80, color: Colors.black26),
          const SizedBox(height: 16),
          Text(
            _hayFiltrosActivos ? 'SIN RESULTADOS' : 'INVENTARIO VACÍO',
            style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerStockBajo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        border: Border.all(color: const Color(0xFFFFB300)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFE65100), size: 20),
            const SizedBox(width: 8),
            Text('${_productosStockBajo.length} producto(s) con stock bajo',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE65100), fontSize: 14)),
          ]),
          const SizedBox(height: 8),
          ..._productosStockBajo.map((p) => Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(children: [
              const SizedBox(width: 28),
              const Icon(Icons.circle, size: 6, color: Color(0xFFE65100)),
              const SizedBox(width: 8),
              Expanded(child: Text(
                '${p['nombre']} — Stock: ${p['stock']} / Mínimo: ${p['stock_minimo']}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF5D4037)),
              )),
            ]),
          )),
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
        final esProducto = p['tipo']?.toString().toLowerCase() != 'servicio';
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 12, offset: const Offset(0, 4))],
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
                child: Row(children: [
                  Text('#${p['id'] ?? ''}', style: const TextStyle(color: _headerColor, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(p['nombre']?.toString() ?? '',
                      style: const TextStyle(color: _headerColor, fontWeight: FontWeight.bold, fontSize: 15))),
                  if ((p['clasificacion']?.toString() ?? '').isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: _headerColor, borderRadius: BorderRadius.circular(6)),
                      child: Text(p['clasificacion'].toString(), style: const TextStyle(color: Colors.white, fontSize: 11)),
                    ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(children: [
                  _cardRow('Stock', p['stock']?.toString() ?? '0'),
                  _cardRow('Precio compra', _formatearPrecio(p['precio_compra'])),
                  _cardRow('Precio venta', _formatearPrecio(p['precio_venta'])),
                  _cardRow('Proveedor', _obtenerNombreProveedor(p['id_proveedor']?.toString())),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 14, right: 14, bottom: 14),
                child: Wrap(
                  spacing: 8, runSpacing: 6,
                  children: [
                    _accionBtn('Editar', Icons.edit, Colors.blue, () => esProducto
                        ? mostrarModalEditarProducto(context, p, onSuccess: _cargarProductos)
                        : mostrarModalEditarServicio(context, p, onSuccess: _cargarProductos)),
                    if (esProducto) ...[
                      _accionBtn('+ Stock', Icons.add, Colors.green, () =>
                          mostrarModalEntradaStock(context, p['id']?.toString() ?? '', p['nombre']?.toString() ?? '', onSuccess: _cargarProductos)),
                      _accionBtn('- Stock', Icons.remove, Colors.orange, () =>
                          mostrarModalSalidaStock(context, p['id']?.toString() ?? '', p['nombre']?.toString() ?? '',
                              int.tryParse(p['stock']?.toString() ?? '0') ?? 0, onSuccess: _cargarProductos)),
                    ],
                    _accionBtn('Eliminar', Icons.delete, Colors.red, () =>
                        mostrarModalEliminarProducto(context, p['id']?.toString() ?? '', p['nombre']?.toString() ?? '', onSuccess: _cargarProductos)),
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
      child: Row(children: [
        SizedBox(width: 120, child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
      ]),
    );
  }
}

class _ClasifChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isPersonalizada;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _ClasifChip({
    required this.label,
    required this.selected,
    required this.isPersonalizada,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              color: selected ? Colors.white : const Color(0xFFA61B1B),
            )),
            if (isPersonalizada) ...[
              const SizedBox(width: 4),
              Icon(Icons.edit, size: 11, color: selected ? Colors.white70 : Colors.grey),
            ],
          ],
        ),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: const Color(0xFFC0392B),
        backgroundColor: const Color(0xFFFFF0F0),
        checkmarkColor: Colors.white,
        side: BorderSide(color: selected ? const Color(0xFFC0392B) : const Color(0xFFE0B0B0)),
        showCheckmark: false,
        tooltip: isPersonalizada ? 'Mantén presionado para editar' : null,
      ),
    );
  }
}