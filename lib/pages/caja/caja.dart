import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:taller_rodriguez/widgets/navigation/sidebar.dart';
import 'package:taller_rodriguez/services/caja_service.dart';
import 'package:taller_rodriguez/services/session_service.dart';

class CajaPage extends StatefulWidget {
  const CajaPage({super.key});

  @override
  State<CajaPage> createState() => _CajaPageState();
}

class _CajaPageState extends State<CajaPage> {
  bool _cargando = true;
  Map<String, dynamic>? _cajaAbierta;
  final TextEditingController _baseController = TextEditingController();
  final TextEditingController _efectivoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarEstadoCaja();
  }

  @override
  void dispose() {
    _baseController.dispose();
    _efectivoController.dispose();
    super.dispose();
  }

  Future<void> _cargarEstadoCaja() async {
    setState(() => _cargando = true);
    final caja = await CajaService.getCajaAbierta();
    setState(() {
      _cajaAbierta = caja;
      _cargando = false;
      if (caja != null) {
        _efectivoController.text = caja['efectivo_actual']?.toString() ?? '';
      }
    });
  }

  Future<void> _abrirCaja() async {
    final base = double.tryParse(_baseController.text);
    if (base == null || base <= 0) {
      _mostrarMensaje('Ingresa un monto base válido', isError: true);
      return;
    }
    setState(() => _cargando = true);
    final resultado = await CajaService.abrirCaja(base);
    if (resultado['success'] == true) {
      _mostrarMensaje('Caja abierta exitosamente');
      _baseController.clear();
      await _cargarEstadoCaja();
    } else {
      setState(() => _cargando = false);
      _mostrarMensaje(resultado['message'] ?? 'Error al abrir caja', isError: true);
    }
  }

  Future<void> _cerrarCaja() async {
  if (_cajaAbierta == null) return;

  final confirmar = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(children: [
        Icon(Icons.lock_outline, color: Colors.red),
        SizedBox(width: 8),
        Text('Cerrar caja'),
      ]),
      content: const Text('¿Estás segura de cerrar la caja?\nSe calculará el resumen del turno.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Cerrar caja', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );

  if (confirmar != true) return;
  setState(() => _cargando = true);

  final resultado = await CajaService.cerrarCaja(_cajaAbierta!['id']);

  if (resultado['success'] == true && mounted) {
   
    final baseInicial     = (resultado['base_inicial']      as num?)?.toDouble() ?? 0;
    final totalVentas     = (resultado['total_ventas']      as num?)?.toDouble() ?? 0;
    final totalEnCaja     = (resultado['total_en_caja']     as num?)?.toDouble() ?? 0;
    final cantFacturas    = resultado['cantidad_facturas']   as int? ?? 0;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.check_circle, color: Colors.green, size: 28),
          SizedBox(width: 8),
          Text('Resumen del turno'),
        ]),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _resumenFila('Base inicial', '\$${baseInicial.toStringAsFixed(2)}', Colors.grey),
              const Divider(),
              _resumenFila('Facturas emitidas', '$cantFacturas facturas', Colors.blue),
              _resumenFila('Ventas del turno', '\$${totalVentas.toStringAsFixed(2)}', Colors.green),
              const Divider(),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TOTAL EN CAJA',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text('\$${totalEnCaja.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.green)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Base \$${baseInicial.toStringAsFixed(2)} + Ventas \$${totalVentas.toStringAsFixed(2)} = \$${totalEnCaja.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Entendido', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    await _cargarEstadoCaja();
  } else {
    setState(() => _cargando = false);
    _mostrarMensaje(resultado['message'] ?? 'Error al cerrar caja', isError: true);
  }
}

Widget _resumenFila(String label, String valor, Color colorValor) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.black54)),
        Text(valor, style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600, color: colorValor)),
      ],
    ),
  );
}

  Future<void> _actualizarEfectivo() async {
    if (_cajaAbierta == null) return;
    final efectivo = double.tryParse(_efectivoController.text);
    if (efectivo == null) {
      _mostrarMensaje('Ingresa un monto válido', isError: true);
      return;
    }
    final resultado = await CajaService.actualizarEfectivo(_cajaAbierta!['id'], efectivo);
    if (resultado['success'] == true) {
      _mostrarMensaje('Efectivo actualizado');
      await _cargarEstadoCaja();
    } else {
      _mostrarMensaje('Error al actualizar', isError: true);
    }
  }

  void _mostrarMensaje(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final bool isWide = MediaQuery.of(context).size.width > 1000;
    final empleado = SessionService.currentUser;
    final nombreEmpleado = empleado?['nombre']?.toString() ?? 'Sin sesión';

    return Scaffold(
      appBar: isWide ? null : AppBar(title: const Text('Caja')),
      drawer: isWide ? null : const SidebarDrawerContent(),
      body: Row(
        children: [
          const Sidebar(),
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 25),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Caja del taller',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Itim',
                                ),
                              ),
                              const SizedBox(height: 20),

                             
                              Row(
                                children: [
                                  const Text('Estado de la caja:',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                  const SizedBox(width: 10),
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: _cajaAbierta != null ? Colors.green : Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _cajaAbierta != null ? 'ABIERTA' : 'CERRADA',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: _cajaAbierta != null ? Colors.green : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              if (_cajaAbierta != null) ...[
                                _infoRow('Fecha:', _cajaAbierta!['fecha']?.toString() ?? '-'),
                                const SizedBox(height: 16),
                                _infoRow('Hora apertura:', _cajaAbierta!['hora_apertura']?.toString() ?? '-'),
                                const SizedBox(height: 16),
                                _infoRow('Responsable:', nombreEmpleado),
                                const SizedBox(height: 16),
                                _infoRow('Base inicial:', '\$${_cajaAbierta!['base_inicial']?.toString() ?? '0'}'),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    const Text('Efectivo actual:',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                    const SizedBox(width: 10),
                                    SizedBox(
                                      width: 120,
                                      child: TextField(
                                        controller: _efectivoController,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                                        decoration: InputDecoration(
                                          prefixText: '\$',
                                          isDense: true,
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton(
                                      onPressed: _actualizarEfectivo,
                                      child: const Text('Actualizar'),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                _infoRow('Responsable:', nombreEmpleado),
                                const SizedBox(height: 16),
                                const Text('Monto base inicial:',
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _baseController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                                  decoration: InputDecoration(
                                    prefixText: '\$',
                                    hintText: '0.00',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 28),

                           
                              isWide
                                  ? Row(
                                      children: [
                                        if (_cajaAbierta == null)
                                          Expanded(
                                            child: _CajaButton(
                                              label: 'Abrir caja',
                                              onTap: _abrirCaja,
                                            ),
                                          ),
                                        if (_cajaAbierta != null) ...[
                                          Expanded(
                                            child: _CajaButton(
                                              label: 'Cerrar caja',
                                              onTap: _cerrarCaja,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: _CajaButton(
                                              label: 'Facturar',
                                              onTap: () => Navigator.pushNamed(context, '/facturacion'),
                                            ),
                                          ),
                                        ],
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _CajaButton(
                                            label: 'Historial de turnos',
                                            onTap: () => Navigator.pushNamed(context, '/historialTurnos'),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _CajaButton(
                                            label: 'Historial de facturas',
                                            onTap: () => Navigator.pushNamed(context, '/historialFacturas'),
                                          ),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        if (_cajaAbierta == null)
                                          _CajaButton(label: 'Abrir caja', onTap: _abrirCaja),
                                        if (_cajaAbierta != null) ...[
                                          _CajaButton(label: 'Cerrar caja', onTap: _cerrarCaja),
                                          const SizedBox(height: 12),
                                          _CajaButton(
                                            label: 'Facturar',
                                            onTap: () => Navigator.pushNamed(context, '/facturacion'),
                                          ),
                                        ],
                                        const SizedBox(height: 12),
                                        _CajaButton(
                                          label: 'Historial de turnos',
                                          onTap: () => Navigator.pushNamed(context, '/historialTurnos'),
                                        ),
                                        const SizedBox(height: 12),
                                        _CajaButton(
                                          label: 'Historial de facturas',
                                          onTap: () => Navigator.pushNamed(context, '/historialFacturas'),
                                        ),
                                      ],
                                    ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF333333))),
        const SizedBox(width: 10),
        Text(value, style: const TextStyle(fontSize: 16, color: Color(0xFF444444))),
      ],
    );
  }
}

class _CajaButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final double? width;

  const _CajaButton({required this.label, required this.onTap, this.width});

  @override
  State<_CajaButton> createState() => _CajaButtonState();
}

class _CajaButtonState extends State<_CajaButton> {
  bool _hovered = false;
  static const _base = Color(0xFFC0392B);
  static const _hover = Color(0xFF96211F);

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
          width: widget.width,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          decoration: BoxDecoration(
            color: _hovered ? _hover : _base,
            borderRadius: BorderRadius.circular(8),
            boxShadow: _hovered
                ? [BoxShadow(
                    color: _base.withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4))]
                : [],
          ),
          child: Text(
            widget.label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              fontFamily: 'Itim',
            ),
          ),
        ),
      ),
    );
  }
}