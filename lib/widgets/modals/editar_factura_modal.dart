import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/facturacion_api.dart';
import '../../services/cliente_service.dart';
import '../../models/cliente.dart';

class EditarFacturaModal extends StatefulWidget {
  final Map<String, dynamic> factura;
  final VoidCallback onFacturaEditada;

  const EditarFacturaModal({
    super.key,
    required this.factura,
    required this.onFacturaEditada,
  });

  @override
  State<EditarFacturaModal> createState() => _EditarFacturaModalState();
}

class _EditarFacturaModalState extends State<EditarFacturaModal> {
  final FacturacionApi _api = FacturacionApi();

  String? _tipoFactura;
  int? _clienteId;
  List<Cliente> _clientes = [];
  bool _cargando = true;
  bool _guardando = false;

  // Items editables: lista de mapas con los detalles de la factura
  List<Map<String, dynamic>> _items = [];

  // Controladores de texto para cada ítem (precio y cantidad)
  final List<TextEditingController> _precioCtrl = [];
  final List<TextEditingController> _cantidadCtrl = [];

  @override
  void initState() {
    super.initState();
    _tipoFactura = widget.factura['tipo_factura']?.toString() ?? 'Consumidor Final';
    _clienteId = widget.factura['clientes']?['id'] as int?;
    _cargarDatos();
  }

  @override
  void dispose() {
    for (final c in _precioCtrl) c.dispose();
    for (final c in _cantidadCtrl) c.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      // Cargar clientes e ítems de la factura en paralelo
      final results = await Future.wait([
        ClienteService.getAll(),
        _api.obtenerItemsFactura(widget.factura['id'] as int),
      ]);

      final clientes = results[0] as List<Cliente>;
      final items = results[1] as List<Map<String, dynamic>>;

      // Inicializar controladores
      for (final c in _precioCtrl) c.dispose();
      for (final c in _cantidadCtrl) c.dispose();
      _precioCtrl.clear();
      _cantidadCtrl.clear();

      for (final item in items) {
        final precio = (item['precio_unitario'] as num?)?.toDouble() ?? 0.0;
        final cantidad = (item['cantidad'] as int? ?? 1);
        _precioCtrl.add(TextEditingController(text: precio.toStringAsFixed(2)));
        _cantidadCtrl.add(TextEditingController(text: cantidad.toString()));
      }

      if (mounted) {
        setState(() {
          _clientes = clientes;
          _items = items.map((i) => Map<String, dynamic>.from(i)).toList();
          _cargando = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  // ── Cálculos en tiempo real ──────────────────────────────────
  double get _subtotal {
    double s = 0;
    for (int i = 0; i < _items.length; i++) {
      final cantidad = int.tryParse(_cantidadCtrl[i].text) ?? 0;
      final precio = double.tryParse(_precioCtrl[i].text) ?? 0.0;
      s += cantidad * precio;
    }
    return s;
  }

  double get _descuentoPct =>
      (widget.factura['descuento_porcentaje'] as num?)?.toDouble() ?? 0.0;

  double get _descuento => _subtotal * (_descuentoPct / 100);
  double get _subtotalConDescuento => _subtotal - _descuento;
  double get _iva => _subtotalConDescuento * 0.13;
  double get _total => _subtotalConDescuento + _iva;

  // ── Guardar ──────────────────────────────────────────────────
  Future<void> _guardar() async {
    // Validar que no haya cantidades ni precios en cero
    for (int i = 0; i < _items.length; i++) {
      final cantidad = int.tryParse(_cantidadCtrl[i].text) ?? 0;
      final precio = double.tryParse(_precioCtrl[i].text) ?? 0.0;
      if (cantidad <= 0) {
        _snack('La cantidad del ítem "${_items[i]['nombre_producto']}" debe ser mayor a 0', isError: true);
        return;
      }
      if (precio < 0) {
        _snack('El precio no puede ser negativo', isError: true);
        return;
      }
    }

    setState(() => _guardando = true);

    // Construir lista actualizada de ítems
    final itemsActualizados = <Map<String, dynamic>>[];
    for (int i = 0; i < _items.length; i++) {
      final cantidad = int.tryParse(_cantidadCtrl[i].text) ?? 1;
      final precio = double.tryParse(_precioCtrl[i].text) ?? 0.0;
      itemsActualizados.add({
        ..._items[i],
        'cantidad': cantidad,
        'precio_unitario': precio,
        'subtotal': cantidad * precio,
      });
    }

    final result = await _api.actualizarFacturaCompleta(
      id: widget.factura['id'] as int,
      tipoFactura: _tipoFactura ?? 'Consumidor Final',
      idCliente: _clienteId,
      items: itemsActualizados,
      subtotal: _subtotal,
      descuento: _descuento,
      descuentoPorcentaje: _descuentoPct,
      iva: _iva,
      total: _total,
    );

    setState(() => _guardando = false);

    if (result['success'] == true) {
      widget.onFacturaEditada();
      if (mounted) Navigator.pop(context);
      _snack('Factura actualizada correctamente ✓');
    } else {
      _snack(result['message'] ?? 'Error al actualizar', isError: true);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : const Color(0xFFC0392B),
    ));
  }

  // ── UI ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final codigo = 'FAC-${widget.factura['id'].toString().padLeft(4, '0')}';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Encabezado ──
              Row(
                children: [
                  const Expanded(
                    child: Text('Editar Factura',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Itim')),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),

              // ── Aviso ──
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF9A825)),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline, color: Color(0xFFF9A825), size: 18),
                  const SizedBox(width: 8),
                  Text('Corrección interna — $codigo',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF7A5000))),
                ]),
              ),

              // ── Tipo y cliente ──
              Row(
                children: [
                  Expanded(child: _buildTipoDropdown()),
                  const SizedBox(width: 12),
                  Expanded(child: _buildClienteDropdown()),
                ],
              ),
              const SizedBox(height: 16),

              // ── Tabla de ítems ──
              const Text('Ítems de la factura',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),

              Expanded(
                child: _cargando
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFC0392B)))
                    : _items.isEmpty
                        ? const Center(
                            child: Text('No se encontraron ítems',
                                style: TextStyle(color: Colors.grey)))
                        : _buildItemsTable(),
              ),

              // ── Totales ──
              if (!_cargando && _items.isNotEmpty) ...[
                const Divider(height: 24),
                _buildTotales(),
                const SizedBox(height: 16),
              ],

              // ── Botón guardar ──
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _guardando ? null : _guardar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC0392B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _guardando
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Guardar cambios',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                              fontFamily: 'Itim', color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTipoDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tipo', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: _tipoFactura,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            isDense: true,
          ),
          items: const [
            DropdownMenuItem(value: 'Consumidor Final', child: Text('Consumidor Final')),
            DropdownMenuItem(value: 'Credito Fiscal', child: Text('Crédito Fiscal')),
          ],
          onChanged: (val) => setState(() => _tipoFactura = val),
        ),
      ],
    );
  }

  Widget _buildClienteDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Cliente', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 4),
        _cargando
            ? const SizedBox(height: 44, child: Center(child: LinearProgressIndicator()))
            : DropdownButtonFormField<int>(
                value: _clienteId,
                hint: const Text('Sin cliente', style: TextStyle(fontSize: 13)),
                isExpanded: true,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem<int>(value: null, child: Text('Sin cliente')),
                  ..._clientes.map((c) => DropdownMenuItem(
                    value: c.id,
                    child: Text(c.nombre, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                  )),
                ],
                onChanged: (val) => setState(() => _clienteId = val),
              ),
      ],
    );
  }

  Widget _buildItemsTable() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          // Encabezado tabla
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0F0),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: const Row(
              children: [
                Expanded(flex: 4, child: Text('PRODUCTO/SERVICIO',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFA61B1B)))),
                SizedBox(width: 70, child: Text('CANT.', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFA61B1B)))),
                SizedBox(width: 90, child: Text('PRECIO', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFA61B1B)))),
                SizedBox(width: 80, child: Text('TOTAL', textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFA61B1B)))),
              ],
            ),
          ),
          // Filas editables
          Expanded(
            child: ListView.separated(
              itemCount: _items.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
              itemBuilder: (context, i) => _buildItemRow(i),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(int i) {
    final item = _items[i];
    final nombre = item['nombre_producto']?.toString() ?? '-';
    final tipo = item['tipo_producto']?.toString() ?? 'Producto';
    final esServicio = tipo.toLowerCase() == 'servicio';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Nombre + badge
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombre, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: esServicio ? Colors.orange.shade50 : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(tipo,
                    style: TextStyle(fontSize: 10,
                      color: esServicio ? Colors.orange.shade700 : Colors.blue.shade700,
                      fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          // Cantidad
          SizedBox(
            width: 70,
            child: TextField(
              controller: _cantidadCtrl[i],
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          // Precio unitario
          SizedBox(
            width: 90,
            child: TextField(
              controller: _precioCtrl[i],
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                prefixText: '\$',
                contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          // Subtotal calculado
          SizedBox(
            width: 80,
            child: Text(
              '\$${((int.tryParse(_cantidadCtrl[i].text) ?? 0) * (double.tryParse(_precioCtrl[i].text) ?? 0.0)).toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotales() {
    final filas = [
      if (_descuentoPct > 0) ...[
        ('Subtotal', _subtotal),
        ('Descuento (${_descuentoPct.toStringAsFixed(0)}%)', -_descuento),
        ('Subtotal c/desc.', _subtotalConDescuento),
      ] else
        ('Subtotal', _subtotal),
      ('IVA (13%)', _iva),
    ];

    return Column(
      children: [
        ...(_descuentoPct > 0
            ? [
                _filaTotal('Subtotal', _subtotal),
                _filaTotal('Descuento (${_descuentoPct.toStringAsFixed(0)}%)', -_descuento, isRed: true),
                _filaTotal('Subtotal c/desc.', _subtotalConDescuento),
                _filaTotal('IVA (13%)', _iva),
              ]
            : [
                _filaTotal('Subtotal', _subtotal),
                _filaTotal('IVA (13%)', _iva),
              ]),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Itim')),
            Text('\$${_total.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFC0392B))),
          ],
        ),
      ],
    );
  }

  Widget _filaTotal(String label, double value, {bool isRed = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: isRed ? Colors.red : Colors.black54)),
          Text('\$${value.abs().toStringAsFixed(2)}',
              style: TextStyle(fontSize: 13, color: isRed ? Colors.red : Colors.black87)),
        ],
      ),
    );
  }
}