import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/vehiculo_service.dart';

class EditarVehiculoModal extends StatefulWidget {
  final Map<String, dynamic> vehiculo;
  final VoidCallback onVehiculoEditado;

  const EditarVehiculoModal({
    super.key,
    required this.vehiculo,
    required this.onVehiculoEditado,
  });

  @override
  State<EditarVehiculoModal> createState() => _EditarVehiculoModalState();
}

class _EditarVehiculoModalState extends State<EditarVehiculoModal> {
  late TextEditingController _modeloCtrl;
  late TextEditingController _marcaCtrl;
  late TextEditingController _placaCtrl;
  late TextEditingController _anioCtrl;
  late TextEditingController _fechaIngresoCtrl;
  late TextEditingController _fechaSalidaCtrl;
  late TextEditingController _diagnosticoCtrl;
  String? _estado;
  bool _guardando = false;

  // Imágenes
  XFile? _imagenVehiculo;
  XFile? _imagenTarjeta;
  bool _subiendoImagen = false;

  // URLs actuales de imágenes (las que ya existen en BD)
  String? _urlVehiculoActual;
  String? _urlTarjetaActual;

  @override
  void initState() {
    super.initState();
    final v = widget.vehiculo;
    _modeloCtrl       = TextEditingController(text: v['modelo'] ?? '');
    _marcaCtrl        = TextEditingController(text: v['marca'] ?? '');
    _placaCtrl        = TextEditingController(text: v['placa'] ?? '');
    _anioCtrl         = TextEditingController(text: '${v['anio'] ?? ''}');
    _diagnosticoCtrl  = TextEditingController(text: v['diagnostico'] ?? '');
    _estado           = v['estado'];
    _urlVehiculoActual = v['url_imagen_vehiculo']?.toString();
    _urlTarjetaActual  = v['url_tarjeta_circulacion']?.toString();

    _fechaIngresoCtrl = TextEditingController(text: _fechaParaCampo(v['fecha_ingreso']));
    _fechaSalidaCtrl  = TextEditingController(text: _fechaParaCampo(v['fecha_salida']));
  }

  @override
  void dispose() {
    _modeloCtrl.dispose();
    _marcaCtrl.dispose();
    _placaCtrl.dispose();
    _anioCtrl.dispose();
    _fechaIngresoCtrl.dispose();
    _fechaSalidaCtrl.dispose();
    _diagnosticoCtrl.dispose();
    super.dispose();
  }

  String _fechaParaCampo(dynamic fecha) {
    if (fecha == null) return '';
    final dt = DateTime.tryParse(fecha.toString());
    if (dt == null) return '';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  String _parseFecha(String fecha) {
    final partes = fecha.split('/');
    if (partes.length == 3) {
      return '${partes[2]}-${partes[1].padLeft(2, '0')}-${partes[0].padLeft(2, '0')}T00:00:00';
    }
    return DateTime.now().toIso8601String();
  }

  Future<void> _seleccionarImagen(bool esVehiculo) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 60, maxWidth: 800, maxHeight: 800);
    if (picked == null) return;
    setState(() {
      if (esVehiculo) {
        _imagenVehiculo = picked;
      } else {
        _imagenTarjeta = picked;
      }
    });
  }

  Future<String?> _subirImagen(XFile imagen, String carpeta, String nombre) async {
    try {
      final bytes     = await imagen.readAsBytes();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path      = '$carpeta/${nombre}_$timestamp.jpg';
      await Supabase.instance.client.storage.from('vehiculos').uploadBinary(
        path, bytes,
        fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
      );
      return Supabase.instance.client.storage.from('vehiculos').getPublicUrl(path);
    } catch (_) {
      return null;
    }
  }

  Future<void> _guardarCambios() async {
    // Placa es opcional — solo modelo, marca y año son requeridos
    if (_modeloCtrl.text.trim().isEmpty ||
        _marcaCtrl.text.trim().isEmpty ||
        _anioCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completa los campos requeridos: modelo, marca y año'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _guardando = true);

    final nombreBase = _placaCtrl.text.trim().isNotEmpty
        ? _placaCtrl.text.trim()
        : 'vehiculo_${widget.vehiculo['id']}';

    String? urlVehiculo = _urlVehiculoActual;
    String? urlTarjeta  = _urlTarjetaActual;

    if (_imagenVehiculo != null) {
      setState(() => _subiendoImagen = true);
      urlVehiculo = await _subirImagen(_imagenVehiculo!, 'imagenes', nombreBase);
      setState(() => _subiendoImagen = false);
    }
    if (_imagenTarjeta != null) {
      setState(() => _subiendoImagen = true);
      urlTarjeta = await _subirImagen(_imagenTarjeta!, 'tarjetas', nombreBase);
      setState(() => _subiendoImagen = false);
    }

    final datos = {
      'modelo'      : _modeloCtrl.text.trim(),
      'marca'       : _marcaCtrl.text.trim(),
      'placa'       : _placaCtrl.text.trim().isNotEmpty ? _placaCtrl.text.trim() : null,
      'anio'        : int.tryParse(_anioCtrl.text.trim()) ?? 0,
      'diagnostico' : _diagnosticoCtrl.text.trim(),
      'estado'      : _estado ?? widget.vehiculo['estado'],
      'fecha_ingreso': _fechaIngresoCtrl.text.isNotEmpty
          ? _parseFecha(_fechaIngresoCtrl.text)
          : null,
      'fecha_salida': _fechaSalidaCtrl.text.isNotEmpty
          ? _parseFecha(_fechaSalidaCtrl.text)
          : null,
      if (urlVehiculo != null) 'url_imagen_vehiculo'    : urlVehiculo,
      if (urlTarjeta  != null) 'url_tarjeta_circulacion': urlTarjeta,
    };

    final result = await VehiculoService.actualizarVehiculo(widget.vehiculo['id'], datos);
    setState(() => _guardando = false);

    if (result['success'] == true) {
      widget.onVehiculoEditado();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vehículo actualizado correctamente'),
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
    final isWide = MediaQuery.of(context).size.width > 850;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: isWide ? 920 : double.infinity,
        padding: const EdgeInsets.all(28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Título
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      "Editar Vehículo",
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, fontFamily: 'Itim'),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Fila 1: Modelo, Marca, Placa
              isWide
                  ? Row(children: [
                      Expanded(child: _buildTextField("Modelo del vehículo *", _modeloCtrl)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTextField("Marca del vehículo *", _marcaCtrl)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTextField("Placa (opcional)", _placaCtrl)),
                    ])
                  : Column(children: [
                      _buildTextField("Modelo del vehículo *", _modeloCtrl),
                      const SizedBox(height: 14),
                      _buildTextField("Marca del vehículo *", _marcaCtrl),
                      const SizedBox(height: 14),
                      _buildTextField("Placa (opcional)", _placaCtrl),
                    ]),
              const SizedBox(height: 16),

              // Fila 2: Año, Estado, Fechas
              isWide
                  ? Row(children: [
                      Expanded(child: _buildTextField("Año *", _anioCtrl, keyboardType: TextInputType.number)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildDropdown("Estado", _estado,
                          ["En revisión", "Reparando", "En espera", "Entregado"],
                          (val) => setState(() => _estado = val))),
                      const SizedBox(width: 16),
                      Expanded(child: _buildFechaField("Fecha de ingreso", _fechaIngresoCtrl)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildFechaField("Fecha de salida", _fechaSalidaCtrl)),
                    ])
                  : Column(children: [
                      _buildTextField("Año *", _anioCtrl, keyboardType: TextInputType.number),
                      const SizedBox(height: 14),
                      _buildDropdown("Estado", _estado,
                          ["En revisión", "Reparando", "En espera", "Entregado"],
                          (val) => setState(() => _estado = val)),
                      const SizedBox(height: 14),
                      _buildFechaField("Fecha de ingreso", _fechaIngresoCtrl),
                      const SizedBox(height: 14),
                      _buildFechaField("Fecha de salida", _fechaSalidaCtrl),
                    ]),
              const SizedBox(height: 16),

              // Diagnóstico + imágenes
              isWide
                  ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(flex: 2, child: _buildDiagnostico()),
                      const SizedBox(width: 20),
                      Expanded(flex: 1, child: Column(children: [
                        const SizedBox(height: 28),
                        _botonImagen("Foto del vehículo", _imagenVehiculo, _urlVehiculoActual, true),
                        const SizedBox(height: 12),
                        _botonImagen("Tarjeta de circulación", _imagenTarjeta, _urlTarjetaActual, false),
                      ])),
                    ])
                  : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      _buildDiagnostico(),
                      const SizedBox(height: 12),
                      _botonImagen("Foto del vehículo", _imagenVehiculo, _urlVehiculoActual, true),
                      const SizedBox(height: 12),
                      _botonImagen("Tarjeta de circulación", _imagenTarjeta, _urlTarjetaActual, false),
                    ]),
              const SizedBox(height: 32),

              // Botón guardar
              Center(
                child: SizedBox(
                  width: 320,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _guardando ? null : _guardarCambios,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC0392B),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _guardando
                        ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const SizedBox(width: 20, height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                            const SizedBox(width: 12),
                            Text(_subiendoImagen ? 'Subiendo imágenes...' : 'Guardando...',
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'Itim')),
                          ])
                        : const Text(
                            "Guardar cambios",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Itim', color: Colors.white),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Botón imagen: muestra miniatura si ya existe, o botón para subir ──────
  Widget _botonImagen(String label, XFile? nuevaImagen, String? urlActual, bool esVehiculo) {
    final tieneNueva   = nuevaImagen != null;
    final tieneActual  = urlActual != null && urlActual.isNotEmpty;
    final tieneAlguna  = tieneNueva || tieneActual;

    return GestureDetector(
      onTap: () => _seleccionarImagen(esVehiculo),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: tieneAlguna ? const Color(0xFFDFF5E1) : const Color(0xFFFFF0F0),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: tieneAlguna ? const Color(0xFF2E7D32) : const Color(0xFFC0392B)),
        ),
        child: Column(children: [
          // Miniatura de imagen actual (si existe y no se seleccionó nueva)
          if (tieneActual && !tieneNueva) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                urlActual,
                height: 70,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(),
              ),
            ),
            const SizedBox(height: 6),
          ],
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(
              tieneNueva
                  ? Icons.check_circle
                  : tieneActual
                      ? Icons.edit
                      : Icons.add_a_photo,
              color: tieneAlguna ? const Color(0xFF2E7D32) : const Color(0xFFC0392B),
              size: 18,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                tieneNueva
                    ? '✓ ${nuevaImagen.name}'
                    : tieneActual
                        ? 'Cambiar imagen'
                        : label,
                style: TextStyle(
                  color: tieneAlguna ? const Color(0xFF2E7D32) : const Color(0xFFC0392B),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {TextInputType keyboardType = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, String? value, List<String> items, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          hint: Text("Seleccionar $label"),
          isExpanded: true,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildDiagnostico() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Diagnóstico", style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _diagnosticoCtrl,
          maxLines: 5,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            hintText: "Diagnóstico del vehículo...",
          ),
        ),
      ],
    );
  }

  Widget _buildFechaField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          readOnly: true,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            suffixIcon: const Icon(Icons.calendar_today),
          ),
          onTap: () async {
            DateTime? picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
            );
            if (picked != null) {
              setState(() {
                controller.text =
                    "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
              });
            }
          },
        ),
      ],
    );
  }
}