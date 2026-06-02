import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _tipoFactura = widget.factura['tipo_factura']?.toString() ?? 'Consumidor Final';
    _clienteId = widget.factura['clientes']?['id'] as int?;
    _cargarClientes();
  }

  Future<void> _cargarClientes() async {
    try {
      final clientes = await ClienteService.getAll();
      if (mounted) setState(() { _clientes = clientes; _cargando = false; });
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);

    final result = await _api.actualizarFactura(
      id: widget.factura['id'] as int,
      tipoFactura: _tipoFactura ?? 'Consumidor Final',
      idCliente: _clienteId,
    );

    setState(() => _guardando = false);

    if (result['success'] == true) {
      widget.onFacturaEditada();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Factura actualizada correctamente'),
          backgroundColor: Color(0xFFC0392B),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Error al actualizar'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final codigo = 'FAC-${widget.factura['id'].toString().padLeft(4, '0')}';
    final total = (widget.factura['total'] as num?)?.toDouble() ?? 0.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Editar Factura',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Itim'),
                  ),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),

            // Aviso legal leve
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF9A825)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFFF9A825), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Corrección interna — $codigo  •  Total: \$${total.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF7A5000)),
                    ),
                  ),
                ],
              ),
            ),

            // Tipo de factura
            const Text('Tipo de factura', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _tipoFactura,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              items: const [
                DropdownMenuItem(value: 'Consumidor Final', child: Text('Consumidor Final')),
                DropdownMenuItem(value: 'Credito Fiscal', child: Text('Crédito Fiscal')),
              ],
              onChanged: (val) => setState(() => _tipoFactura = val),
            ),
            const SizedBox(height: 16),

            // Cliente
            const Text('Cliente', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            _cargando
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFC0392B)))
                : DropdownButtonFormField<int>(
                    value: _clienteId,
                    hint: const Text('Sin cliente asignado'),
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    items: [
                      const DropdownMenuItem<int>(value: null, child: Text('Sin cliente')),
                      ..._clientes.map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.nombre, overflow: TextOverflow.ellipsis),
                      )),
                    ],
                    onChanged: (val) => setState(() => _clienteId = val),
                  ),
            const SizedBox(height: 28),

            // Botón guardar
            SizedBox(
              width: double.infinity,
              height: 52,
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
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold,
                            fontFamily: 'Itim', color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}