import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:taller_rodriguez/services/inventario_api.dart';
import 'package:taller_rodriguez/services/proveedor_api.dart';
import 'package:taller_rodriguez/utils/validadores.dart';

void mostrarModalEditarServicio(BuildContext context, Map<String, dynamic> producto, {VoidCallback? onSuccess}) {
  showDialog(
    context: context,
    builder: (context) => _EditarServicioDialog(producto: producto, onSuccess: onSuccess),
  );
}

class _EditarServicioDialog extends StatefulWidget {
  final Map<String, dynamic> producto;
  final VoidCallback? onSuccess;
  const _EditarServicioDialog({required this.producto, this.onSuccess});
  @override
  State<_EditarServicioDialog> createState() => _EditarServicioDialogState();
}

class _EditarServicioDialogState extends State<_EditarServicioDialog> {
  late final TextEditingController nombreController;
  late final TextEditingController precioCompraController;
  late final TextEditingController precioVentaController;
  late final TextEditingController descripcionController;
  late final TextEditingController skuController;
  String? clasificacion;
  bool cargando = false;
  List<Map<String, dynamic>> proveedores = [];
  bool proveedoresCargando = true;
  String? idProveedorSeleccionado;

  final api = InventarioApi();
  final proveedorApi = ProveedorApi();

  @override
  void initState() {
    super.initState();
    final p = widget.producto;
    nombreController = TextEditingController(text: p['nombre']?.toString() ?? '');
    precioCompraController = TextEditingController(text: p['precio_compra']?.toString() ?? '');
    precioVentaController = TextEditingController(text: p['precio_venta']?.toString() ?? '');
    descripcionController = TextEditingController(text: p['descripcion']?.toString() ?? '');
    skuController = TextEditingController(text: p['sku']?.toString() ?? '');
    clasificacion = p['clasificacion']?.toString();
    idProveedorSeleccionado = p['id_proveedor']?.toString();
    _cargarProveedores();
  }

  @override
  void dispose() {
    nombreController.dispose();
    precioCompraController.dispose();
    precioVentaController.dispose();
    descripcionController.dispose();
    skuController.dispose();
    super.dispose();
  }

  Future<void> _cargarProveedores() async {
    final data = await proveedorApi.obtenerProveedores();
    if (mounted) {
      setState(() {
        proveedores = data;
        proveedoresCargando = false;
      });
    }
  }

  String? get nombreProveedorSeleccionado {
    if (idProveedorSeleccionado == null || idProveedorSeleccionado!.isEmpty) return 'Sin proveedor';
    final prov = proveedores.firstWhere(
      (p) => p['id']?.toString() == idProveedorSeleccionado,
      orElse: () => {},
    );
    return prov['nombre']?.toString() ?? 'Sin proveedor';
  }

  @override
  Widget build(BuildContext context) {
    final String id = widget.producto['id']?.toString() ?? '';
    final nombres = ['Sin proveedor', ...proveedores.map((p) => p['nombre']?.toString() ?? '')];
    final provValue = (nombreProveedorSeleccionado != null && nombres.contains(nombreProveedorSeleccionado))
        ? nombreProveedorSeleccionado
        : null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text('Editar servicio',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, fontFamily: 'Itim')),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(child: _modalTextField('Nombre del servicio:', nombreController)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: proveedoresCargando
                        ? const Center(child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)))
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Proveedor', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, fontFamily: 'Itim')),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                value: provValue,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                                selectedItemBuilder: (context) => nombres.map((n) => Text(n, overflow: TextOverflow.ellipsis, maxLines: 1)).toList(),
                                items: nombres.map((n) => DropdownMenuItem(value: n, child: Text(n, overflow: TextOverflow.ellipsis))).toList(),
                                onChanged: (val) {
                                  setState(() {
                                    if (val == null || val == 'Sin proveedor') {
                                      idProveedorSeleccionado = null;
                                    } else {
                                      final prov = proveedores.firstWhere((p) => p['nombre'] == val, orElse: () => {});
                                      idProveedorSeleccionado = prov['id']?.toString();
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _modalTextField('SKU (código del servicio):', skuController),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _modalTextField('Precio de compra:', precioCompraController, prefix: '\$', keyboardType: TextInputType.number, formatters: [ValidadorPrecio()])),
                  const SizedBox(width: 16),
                  Expanded(child: _modalTextField('Precio de venta:', precioVentaController, prefix: '\$', keyboardType: TextInputType.number, formatters: [ValidadorPrecio()])),
                ],
              ),
              const SizedBox(height: 16),
              _modalDropdown('Clasificación de servicio:', clasificacion,
                  ['Aceites y fluidos', 'Frenos', 'Motor', 'Eléctrico', 'Suspensión', 'Transmisión', 'Carrocería', 'Accesorios'],
                  (val) => setState(() => clasificacion = val)),
              const SizedBox(height: 16),
              _modalTextField('Descripción (Opcional):', descripcionController, maxLines: 4),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: cargando ? null : () async {
                    if (nombreController.text.isEmpty || id.isEmpty) return;
                    setState(() => cargando = true);
                    final resultado = await api.actualizarProducto(id, {
                      'nombre': nombreController.text,
                      'sku': skuController.text.trim(),
                      'tipo': 'Servicio',
                      'clasificacion': clasificacion,
                      'descripcion': descripcionController.text,
                      'precio_compra': double.tryParse(precioCompraController.text) ?? 0,
                      'precio_venta': double.tryParse(precioVentaController.text) ?? 0,
                      'id_proveedor': idProveedorSeleccionado,
                    });
                    setState(() => cargando = false);
                    if (resultado['success'] == true) {
                      Navigator.pop(context);
                      widget.onSuccess?.call();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Servicio actualizado exitosamente'), backgroundColor: Colors.green),
                        );
                      }
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(resultado['message'] ?? 'Error al actualizar'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    cargando ? 'Guardando...' : 'Guardar cambios',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Itim'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _modalTextField(String label, TextEditingController controller,
    {int maxLines = 1, String? prefix, TextInputType? keyboardType, Function(String)? onChanged, List<TextInputFormatter>? formatters}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, fontFamily: 'Itim')),
      const SizedBox(height: 6),
      TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        inputFormatters: formatters ?? [],
        onChanged: onChanged,
        decoration: InputDecoration(
          prefixText: prefix,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    ],
  );
}

Widget _modalDropdown(String label, String? value, List<String> options, ValueChanged<String?> onChanged) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, fontFamily: 'Itim')),
      const SizedBox(height: 6),
      DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
        onChanged: onChanged,
      ),
    ],
  );
}