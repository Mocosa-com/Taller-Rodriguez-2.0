import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:taller_rodriguez/widgets/navigation/sidebar.dart';
import 'package:taller_rodriguez/services/oferta_api.dart';

class OfertasScreen extends StatefulWidget {
  const OfertasScreen({super.key});

  @override
  State<OfertasScreen> createState() => _OfertasScreenState();
}

class _OfertasScreenState extends State<OfertasScreen> {
  final OfertaApi _api = OfertaApi();
  bool _mostrarExpirados = false;
  bool _cargando = false;

  List<Map<String, dynamic>> _ofertas = [];

  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _descuentoController = TextEditingController();
  final _productoController = TextEditingController();

  DateTime _fechaInicio = DateTime.now();
  DateTime _fechaFin = DateTime.now().add(const Duration(days: 30));

  int? _ofertaEditandoId;

  @override
  void initState() {
    super.initState();
    _cargarOfertas();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    _descuentoController.dispose();
    _productoController.dispose();
    super.dispose();
  }

  Future<void> _cargarOfertas() async {
    setState(() => _cargando = true);
    try {
      final ofertas = await _api.obtenerTodas();
      setState(() => _ofertas = ofertas);
    } catch (e) {
      _mostrarMensaje('Error al cargar ofertas', isError: true);
    } finally {
      setState(() => _cargando = false);
    }
  }

  Future<void> _crearOActualizarOferta() async {
    final nombre = _nombreController.text.trim();
    final descripcion = _descripcionController.text.trim();
    final descuento = int.tryParse(_descuentoController.text) ?? 0;

    if (nombre.isEmpty) {
      _mostrarMensaje('El nombre es requerido', isError: true);
      return;
    }

    if (descuento <= 0 || descuento > 100) {
      _mostrarMensaje('El descuento debe ser entre 1 y 100', isError: true);
      return;
    }

    if (_fechaFin.isBefore(_fechaInicio)) {
      _mostrarMensaje('La fecha de fin debe ser posterior al inicio', isError: true);
      return;
    }

    setState(() => _cargando = true);

    Map<String, dynamic> resultado;
    if (_ofertaEditandoId != null) {
      resultado = await _api.actualizarOferta(
        id: _ofertaEditandoId!,
        nombreOferta: nombre,
        descripcion: descripcion,
        porcentajeDescuento: descuento.toDouble(),
        fechaInicio: _fechaInicio,
        fechaFin: _fechaFin,
        idProductoFirebase: _productoController.text.isNotEmpty ? _productoController.text : null,
      );
    } else {
      resultado = await _api.crearOferta(
        nombreOferta: nombre,
        descripcion: descripcion,
        porcentajeDescuento: descuento.toDouble(),
        fechaInicio: _fechaInicio,
        fechaFin: _fechaFin,
        idProductoFirebase: _productoController.text.isNotEmpty ? _productoController.text : null,
      );
    }

    setState(() => _cargando = false);

    if (resultado['success'] == true) {
      _mostrarMensaje(_ofertaEditandoId != null ? 'Oferta actualizada' : 'Oferta creada');
      _limpiarFormulario();
      _cargarOfertas();
    } else {
      _mostrarMensaje(resultado['message'] ?? 'Error', isError: true);
    }
  }

  /// Soft-delete: solo desactiva, NUNCA elimina de la base de datos
  Future<void> _desactivarOferta(int id, String nombre) async {
    final confirmacion = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.block, color: Colors.orange),
            SizedBox(width: 8),
            Text('Desactivar oferta'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Desea desactivar la oferta "$nombre"?'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'La oferta quedará inactiva pero se conservará el historial.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.block, size: 16),
            label: const Text('Desactivar'),
          ),
        ],
      ),
    );

    if (confirmacion == true) {
      setState(() => _cargando = true);
      final resultado = await _api.desactivarOferta(id);
      setState(() => _cargando = false);

      if (resultado['success'] == true) {
        _mostrarMensaje('Oferta desactivada correctamente');
        _cargarOfertas();
      } else {
        _mostrarMensaje(resultado['message'] ?? 'Error al desactivar', isError: true);
      }
    }
  }

  /// Reactivar una oferta desactivada
  Future<void> _reactivarOferta(int id, String nombre) async {
    final confirmacion = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Reactivar oferta'),
          ],
        ),
        content: Text('¿Desea reactivar la oferta "$nombre"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.check_circle, size: 16),
            label: const Text('Reactivar'),
          ),
        ],
      ),
    );

    if (confirmacion == true) {
      setState(() => _cargando = true);
      final resultado = await _api.reactivarOferta(id);
      setState(() => _cargando = false);

      if (resultado['success'] == true) {
        _mostrarMensaje('Oferta reactivada correctamente');
        _cargarOfertas();
      } else {
        _mostrarMensaje(resultado['message'] ?? 'Error al reactivar', isError: true);
      }
    }
  }

  void _editarOferta(Map<String, dynamic> oferta) {
    setState(() {
      _ofertaEditandoId = oferta['id'];
      _nombreController.text = oferta['nombre_oferta'] ?? '';
      _descripcionController.text = oferta['descripcion'] ?? '';
      _descuentoController.text = (oferta['porcentaje_descuento'] ?? 0).toInt().toString();
      _productoController.text = oferta['id_producto_firebase'] ?? '';
      _fechaInicio = DateTime.tryParse(oferta['fecha_inicio'] ?? '') ?? DateTime.now();
      _fechaFin = DateTime.tryParse(oferta['fecha_fin'] ?? '') ?? DateTime.now().add(const Duration(days: 30));
    });
  }

  void _limpiarFormulario() {
    setState(() {
      _ofertaEditandoId = null;
      _nombreController.clear();
      _descripcionController.clear();
      _descuentoController.clear();
      _productoController.clear();
      _fechaInicio = DateTime.now();
      _fechaFin = DateTime.now().add(const Duration(days: 30));
    });
  }

  void _mostrarMensaje(String mensaje, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _seleccionarFecha(bool esInicio) async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: esInicio ? _fechaInicio : _fechaFin,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (fecha != null) {
      setState(() {
        if (esInicio) {
          _fechaInicio = fecha;
        } else {
          _fechaFin = fecha;
        }
      });
    }
  }

  String _formatearFecha(String fechaStr) {
    try {
      final fecha = DateTime.parse(fechaStr);
      final dia = fecha.day.toString().padLeft(2, '0');
      final mes = fecha.month.toString().padLeft(2, '0');
      return '$dia/$mes/${fecha.year}';
    } catch (e) {
      return fechaStr;
    }
  }

  bool _estaActiva(Map<String, dynamic> oferta) {
    return oferta['activo'] == true;
  }

  bool _estaExpirada(Map<String, dynamic> oferta) {
    try {
      final fin = DateTime.parse(oferta['fecha_fin'] ?? '');
      return fin.isBefore(DateTime.now()) && oferta['activo'] == true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isWide = MediaQuery.of(context).size.width > 1000;

    return Scaffold(
      appBar: isWide ? null : AppBar(title: const Text('Ofertas')),
      drawer: isWide ? null : const SidebarDrawerContent(),
      backgroundColor: const Color(0xFFF8F9FA),
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
                        'Ofertas',
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Itim',
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  isWide ? _buildWideLayout() : _buildMobileLayout(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWideLayout() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: _buildFormPanel()),
          const SizedBox(width: 24),
          Expanded(flex: 3, child: _buildOffersTablePanel()),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _buildFormPanel(),
          const SizedBox(height: 20),
          _buildOffersTablePanel(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildFormPanel() {
    final bool isWide = MediaQuery.of(context).size.width > 1000;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _ofertaEditandoId != null ? 'Editar oferta' : 'Agregar nueva oferta',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Itim',
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nombreController,
              decoration: InputDecoration(
                labelText: 'Nombre de la oferta',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _descripcionController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Descripción',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),
            isWide
                ? Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _descuentoController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          onChanged: (value) {
                            final descuento = int.tryParse(value) ?? 0;
                            if (descuento > 100) {
                              _descuentoController.text = '100';
                              _descuentoController.selection = TextSelection.fromPosition(
                                  TextPosition(offset: _descuentoController.text.length));
                            }
                          },
                          decoration: InputDecoration(
                            labelText: '% de descuento',
                            suffixText: '%',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _productoController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: InputDecoration(
                            labelText: 'ID Producto (opcional)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      TextField(
                        controller: _descuentoController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: '% de descuento',
                          suffixText: '%',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _productoController,
                        decoration: InputDecoration(
                          labelText: 'ID Producto (opcional)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _buildFechaField('Fecha inicio', _fechaInicio, true),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildFechaField('Fecha fin', _fechaFin, false),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _cargando ? null : _crearOActualizarOferta,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  _ofertaEditandoId != null ? 'Actualizar Oferta' : 'Agregar Oferta',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Itim',
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            if (_ofertaEditandoId != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 45,
                child: TextButton(
                  onPressed: _cargando ? null : () {
                    setState(() => _ofertaEditandoId = null);
                    _limpiarFormulario();
                  },
                  child: const Text('Cancelar edición'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFechaField(String label, DateTime fecha, bool esInicio) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Itim')),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => _seleccionarFecha(esInicio),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _formatearFecha(fecha.toIso8601String()),
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
                const Icon(Icons.calendar_today, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOffersTablePanel() {
    final bool isWide = MediaQuery.of(context).size.width > 1000;

    // Filtrado: activas = activo:true; expiradas = activo:false
    final ofertasFiltradas = _mostrarExpirados
        ? _ofertas.where((o) => o['activo'] == false).toList()
        : _ofertas.where((o) => o['activo'] == true).toList();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: isWide
                ? const Row(
                    children: [
                      Expanded(flex: 2, child: Text("Oferta", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                      Expanded(flex: 1, child: Text("Descuento", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text("Inicio", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text("Vencimiento", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                      Expanded(flex: 1, child: Text("Estado", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                      Expanded(flex: 1, child: Text("Acciones", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    ],
                  )
                : const Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Ofertas", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Itim')),
                  ),
          ),
          if (_cargando)
            const Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())
          else if (ofertasFiltradas.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  _mostrarExpirados ? 'No hay ofertas desactivadas' : 'No hay ofertas activas',
                  style: const TextStyle(color: Colors.black45),
                ),
              ),
            )
          else if (isWide)
            ...ofertasFiltradas.map((oferta) => _buildTableRow(oferta)).toList()
          else
            ...ofertasFiltradas.map((oferta) => _buildOfferCard(oferta)).toList(),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text("Mostrar desactivadas", style: TextStyle(fontSize: 13, color: Colors.black54)),
                Switch(
                  value: _mostrarExpirados,
                  onChanged: (val) => setState(() => _mostrarExpirados = val),
                  activeColor: Colors.red,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(Map<String, dynamic> oferta) {
    final activa = _estaActiva(oferta);
    final expirada = _estaExpirada(oferta);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(flex: 2, child: Text(oferta['nombre_oferta'] ?? '', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w500))),
              Expanded(flex: 1, child: Text('${(oferta['porcentaje_descuento'] ?? 0).toInt()}%', textAlign: TextAlign.center)),
              Expanded(flex: 2, child: Text(_formatearFecha(oferta['fecha_inicio'] ?? ''), textAlign: TextAlign.center)),
              Expanded(flex: 2, child: Text(_formatearFecha(oferta['fecha_fin'] ?? ''), textAlign: TextAlign.center)),
              Expanded(flex: 1, child: _buildEstadoBadge(activa, expirada)),
              Expanded(flex: 1, child: _buildActionButtons(oferta)),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildOfferCard(Map<String, dynamic> oferta) {
    final activa = _estaActiva(oferta);
    final expirada = _estaExpirada(oferta);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(oferta['nombre_oferta'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                  const SizedBox(width: 8),
                  _buildEstadoBadge(activa, expirada),
                ],
              ),
              const SizedBox(height: 10),
              Text('${(oferta['porcentaje_descuento'] ?? 0).toInt()}% de descuento', style: const TextStyle(color: Colors.green)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildDateInfo("Inicio", _formatearFecha(oferta['fecha_inicio'] ?? ''))),
                  Expanded(child: _buildDateInfo("Vencimiento", _formatearFecha(oferta['fecha_fin'] ?? ''))),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: activa ? () => _editarOferta(oferta) : null,
                      style: TextButton.styleFrom(
                        backgroundColor: activa ? const Color(0xFFE53935) : Colors.grey.shade300,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text("Editar", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextButton(
                      onPressed: () => activa
                          ? _desactivarOferta(oferta['id'], oferta['nombre_oferta'] ?? '')
                          : _reactivarOferta(oferta['id'], oferta['nombre_oferta'] ?? ''),
                      style: TextButton.styleFrom(
                        backgroundColor: activa ? Colors.orange : Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(
                        activa ? "Desactivar" : "Reactivar",
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildEstadoBadge(bool activa, bool expirada) {
    Color color;
    String texto;
    if (!activa) {
      color = Colors.grey;
      texto = 'Inactiva';
    } else if (expirada) {
      color = Colors.orange;
      texto = 'Expirada';
    } else {
      color = Colors.green;
      texto = 'Activa';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Text(texto, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> oferta) {
    final activa = _estaActiva(oferta);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (activa)
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
            onPressed: () => _editarOferta(oferta),
          ),
        IconButton(
          tooltip: activa ? 'Desactivar' : 'Reactivar',
          icon: Icon(
            activa ? Icons.block : Icons.check_circle,
            color: activa ? Colors.orange : Colors.green,
            size: 20,
          ),
          onPressed: () => activa
              ? _desactivarOferta(oferta['id'], oferta['nombre_oferta'] ?? '')
              : _reactivarOferta(oferta['id'], oferta['nombre_oferta'] ?? ''),
        ),
      ],
    );
  }

  Widget _buildDateInfo(String label, String valor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
        Text(valor, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}
