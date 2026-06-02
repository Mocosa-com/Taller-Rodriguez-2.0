import 'package:flutter/material.dart';
import 'package:taller_rodriguez/services/facturacion_api.dart';
import 'package:taller_rodriguez/services/factura_pdf_service.dart';
import 'package:taller_rodriguez/widgets/navigation/sidebar.dart';
import 'package:taller_rodriguez/widgets/modals/editar_factura_modal.dart';

class HistorialFacturasPage extends StatefulWidget {
  const HistorialFacturasPage({super.key});

  @override
  State<HistorialFacturasPage> createState() => _HistorialFacturasPageState();
}

class _HistorialFacturasPageState extends State<HistorialFacturasPage> {
  static const Color _headerColor = Color(0xFFA61B1B);

  final FacturacionApi _api = FacturacionApi();
  final FacturaPdfService _pdfService = FacturaPdfService();

  bool _cargando = true;
  bool _cargandoMas = false;
  bool _hayMas = true;
  int _pagina = 0;
  static const int _porPagina = 50;
  String _busqueda = '';
  List<Map<String, dynamic>> _facturas = [];
  List<Map<String, dynamic>> _facturasFiltradas = [];

  final TextEditingController _busquedaCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarFacturas();
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarFacturas() async {
    setState(() { _cargando = true; _pagina = 0; _hayMas = true; });
    try {
      final data = await _api.obtenerFacturas(pagina: 0, porPagina: _porPagina);
      setState(() {
        _facturas = data;
        _hayMas = data.length == _porPagina;
        _filtrar(_busquedaCtrl.text);
        _cargando = false;
      });
    } catch (e) {
      setState(() => _cargando = false);
      _mostrarMensaje('Error al cargar facturas: $e', isError: true);
    }
  }

  Future<void> _cargarMas() async {
    if (_cargandoMas || !_hayMas) return;
    setState(() => _cargandoMas = true);
    try {
      final siguientePag = _pagina + 1;
      final data = await _api.obtenerFacturas(pagina: siguientePag, porPagina: _porPagina);
      setState(() {
        _pagina = siguientePag;
        _facturas.addAll(data);
        _hayMas = data.length == _porPagina;
        _filtrar(_busquedaCtrl.text);
        _cargandoMas = false;
      });
    } catch (e) {
      setState(() => _cargandoMas = false);
    }
  }

  void _filtrar(String query) {
    setState(() {
      _busqueda = query;
      if (query.isEmpty) {
        _facturasFiltradas = List.from(_facturas);
      } else {
        final q = query.toLowerCase();
        _facturasFiltradas = _facturas.where((f) {
          final codigo = 'FAC-${f['id'].toString().padLeft(4, '0')}';
          final cliente = (f['clientes']?['nombre'] ?? '').toString().toLowerCase();
          final tipo = (f['tipo_factura'] ?? '').toString().toLowerCase();
          return codigo.contains(q) || cliente.contains(q) || tipo.contains(q);
        }).toList();
      }
    });
  }

  void _editarFactura(Map<String, dynamic> f) {
    showDialog(
      context: context,
      builder: (_) => EditarFacturaModal(
        factura: f,
        onFacturaEditada: _cargarFacturas,
      ),
    );
  }

  Future<void> _verYDescargarPdf(Map<String, dynamic> facturaResumen) async {
    setState(() => _cargando = true);
    try {
      final facturaCompleta = await _api.obtenerFacturaPorId(facturaResumen['id'] as int);
      setState(() => _cargando = false);

      if (facturaCompleta == null) {
        _mostrarMensaje('No se pudo cargar la factura', isError: true);
        return;
      }

      _mostrarMensaje('Generando PDF...');
      await _pdfService.generarFacturaPdf(facturaCompleta);
      _mostrarMensaje('PDF descargado correctamente ✓');
    } catch (e) {
      setState(() => _cargando = false);
      _mostrarMensaje('Error: $e', isError: true);
    }
  }

  void _mostrarMensaje(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: isError ? 4 : 3),
      ),
    );
  }

  String _formatearFecha(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    try {
      final f = DateTime.parse(iso).toLocal();
      final d = f.day.toString().padLeft(2, '0');
      final m = f.month.toString().padLeft(2, '0');
      return '$d/$m/${f.year}';
    } catch (_) {
      return iso;
    }
  }

  String _codigoFactura(dynamic id) =>
      'FAC-${id.toString().padLeft(4, '0')}';

  @override
  Widget build(BuildContext context) {
    final bool isWide = MediaQuery.of(context).size.width > 1000;

    return Scaffold(
      drawer: isWide ? null : const SidebarDrawerContent(),
      appBar: isWide ? null : AppBar(title: const Text('Historial de facturas')),
      backgroundColor: const Color(0xFFF8F9FA),
      body: Row(
        children: [
          const Sidebar(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isWide)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(25, 20, 25, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Historial de facturas',
                          style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold, fontFamily: 'Itim'),
                        ),
                        IconButton(
                          tooltip: 'Actualizar',
                          onPressed: _cargarFacturas,
                          icon: const Icon(Icons.refresh, color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(25, 16, 25, 0),
                  child: TextField(
                    controller: _busquedaCtrl,
                    decoration: InputDecoration(
                      hintText: 'Buscar por código, cliente o tipo...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      fillColor: Colors.white,
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: _filtrar,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: _cargando
                          ? const Center(child: CircularProgressIndicator())
                          : _facturasFiltradas.isEmpty
                              ? _buildEmptyState()
                              : _buildTable(isWide),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_facturasFiltradas.length} factura(s)',
                            style: const TextStyle(color: Colors.black54, fontSize: 13),
                          ),
                          if (_hayMas && _busqueda.isEmpty)
                            TextButton.icon(
                              onPressed: _cargandoMas ? null : _cargarMas,
                              icon: _cargandoMas
                                  ? const SizedBox(width: 14, height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFC0392B)))
                                  : const Icon(Icons.expand_more, size: 16, color: Color(0xFFC0392B)),
                              label: Text(_cargandoMas ? 'Cargando...' : 'Cargar más',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFFC0392B))),
                              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2)),
                            ),
                        ],
                      ),
                      _BotonVolver(onPressed: () => Navigator.pushNamed(context, '/caja')),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.receipt_long, size: 80, color: Colors.black26),
        SizedBox(height: 16),
        Text(
          'NO HAY FACTURAS REGISTRADAS',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
      ],
    );
  }

  Widget _buildTable(bool isWide) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: Column(
        children: [
          _buildTableHeader(isWide),
          Expanded(
            child: ListView.separated(
              itemCount: _facturasFiltradas.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final f = _facturasFiltradas[i];
                final codigo = _codigoFactura(f['id']);
                final cliente = f['clientes']?['nombre']?.toString() ?? 'Consumidor Final';
                final tipo = f['tipo_factura']?.toString() ?? '-';
                final total = '\$${((f['total'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}';
                final fecha = _formatearFecha(f['fecha']?.toString());

                if (!isWide) {
                  return _buildMobileRow(f, codigo, cliente, tipo, total, fecha);
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      SizedBox(width: 130, child: Text(codigo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                      SizedBox(width: 180, child: Text(cliente, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                      SizedBox(width: 140, child: _tipoBadge(tipo)),
                      SizedBox(width: 120, child: Text(total, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                      SizedBox(width: 120, child: Text(fecha, style: const TextStyle(fontSize: 13))),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _botonEditar(f),
                            const SizedBox(width: 8),
                            _botonDescargar(f),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileRow(Map<String, dynamic> f, String codigo, String cliente,
      String tipo, String total, String fecha) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(codigo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              _tipoBadge(tipo),
            ],
          ),
          const SizedBox(height: 4),
          Text(cliente, style: const TextStyle(fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(total, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFFC0392B))),
                Text(fecha, style: const TextStyle(fontSize: 12, color: Colors.black45)),
              ]),
              Row(children: [
                _botonEditar(f),
                const SizedBox(width: 6),
                _botonDescargar(f),
              ]),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(bool isWide) {
    const style = TextStyle(color: _headerColor, fontWeight: FontWeight.bold, fontSize: 12);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFFFF0F0),
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      child: isWide
          ? const Row(
              children: [
                SizedBox(width: 130, child: Text('CÓDIGO', style: style)),
                SizedBox(width: 180, child: Text('CLIENTE', style: style)),
                SizedBox(width: 140, child: Text('TIPO', style: style)),
                SizedBox(width: 120, child: Text('TOTAL', style: style)),
                SizedBox(width: 120, child: Text('FECHA', style: style)),
                Expanded(child: Text('ACCIONES', textAlign: TextAlign.right, style: style)),
              ],
            )
          : const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('FACTURAS', style: style),
                Text('ACCIONES', style: style),
              ],
            ),
    );
  }

  Widget _tipoBadge(String tipo) {
    final esCredito = tipo.toLowerCase().contains('credito') || tipo.toLowerCase().contains('crédito');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: esCredito ? Colors.blue.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: esCredito ? Colors.blue.shade200 : Colors.green.shade200),
      ),
      child: Text(
        tipo,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: esCredito ? Colors.blue.shade800 : Colors.green.shade800,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _botonEditar(Map<String, dynamic> f) {
    return OutlinedButton.icon(
      onPressed: () => _editarFactura(f),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFC0392B),
        side: const BorderSide(color: Color(0xFFC0392B)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: const Icon(Icons.edit, size: 14),
      label: const Text('Editar', style: TextStyle(fontSize: 12)),
    );
  }

  Widget _botonDescargar(Map<String, dynamic> f) {
    return ElevatedButton.icon(
      onPressed: () => _verYDescargarPdf(f),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFC0392B),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: const Icon(Icons.picture_as_pdf, size: 14),
      label: const Text('PDF', style: TextStyle(fontSize: 12)),
    );
  }
}


class _BotonVolver extends StatefulWidget {
  final VoidCallback onPressed;
  const _BotonVolver({required this.onPressed});

  @override
  State<_BotonVolver> createState() => _BotonVolverState();
}

class _BotonVolverState extends State<_BotonVolver> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _hovered ? const Color(0xFF9B1B1B) : const Color(0xFFC0392B),
          borderRadius: BorderRadius.circular(8),
          boxShadow: _hovered
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 4))]
              : [],
        ),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            child: Text('Volver a caja',
                style: TextStyle(color: Colors.white, fontSize: 15, fontFamily: 'Itim', fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}