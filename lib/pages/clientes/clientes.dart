import 'package:flutter/material.dart';
import 'package:taller_rodriguez/widgets/navigation/sidebar.dart';
import 'package:taller_rodriguez/widgets/inputs/busqueda.dart';
import 'package:taller_rodriguez/widgets/inputs/select.dart';
import 'package:taller_rodriguez/widgets/modals/agregar_cliente_modal.dart';
import 'package:taller_rodriguez/models/cliente.dart';
import 'package:taller_rodriguez/services/cliente_service.dart';
import 'package:taller_rodriguez/services/reporte_service.dart';

class ClientesPage extends StatefulWidget {
  const ClientesPage({super.key});

  @override
  State<ClientesPage> createState() => _ClientesPageState();
}

class _ClientesPageState extends State<ClientesPage> {
  final TextEditingController _searchController = TextEditingController();
  String? _filtroFrecuencia;
  List<Cliente> _clientes = [];
  bool _cargando = true;
  String? _error;

  static const Color _headerBg = Color(0xFFC0392B);

  @override
  void initState() {
    super.initState();
    print('CLIENTES PAGE INIT');
    _cargarClientes();
  }

  Future<void> _cargarClientes() async {
    try {
      final data = await ClienteService.getAll();
      setState(() {
        _clientes = data;
        _cargando = false;
      });
    } catch (e) {
      setState(() => _cargando = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Cliente> get _clientesFiltrados {
    return _clientes.where((c) {
      final query = _searchController.text.toLowerCase();
      final matchSearch = query.isEmpty ||
          c.nombre.toLowerCase().contains(query) ||
          c.telefono.toLowerCase().contains(query) ||
          c.dui.toLowerCase().contains(query);
      final matchFrecuencia =
          _filtroFrecuencia == null || c.frecuenciaVisita == _filtroFrecuencia;
      return matchSearch && matchFrecuencia;
    }).toList();
  }

  Future<void> _eliminarCliente(Cliente c) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar cliente'),
        content: Text('¿Estás seguro de eliminar a "${c.nombre}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      await ClienteService.delete(c.id!);
      _cargarClientes();
    }
  }

Future<void> _reportarCliente(Cliente c) async {
  final TextEditingController _notasCtrl = TextEditingController();

  final confirmar = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(children: [
        const Icon(Icons.assignment, color: Color(0xFF1A6B3A)),
        const SizedBox(width: 8),
        Expanded(child: Text('Reporte — ${c.nombre}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
      ]),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
           
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow(Icons.person, 'Nombre', c.nombre),
                  _infoRow(Icons.phone, 'Teléfono',
                      c.telefono.isNotEmpty ? c.telefono : 'N/A'),
                  _infoRow(Icons.badge, 'DUI',
                      c.dui.isNotEmpty ? c.dui : 'N/A'),
                  if (c.nrc?.isNotEmpty == true)
                    _infoRow(Icons.receipt_long, 'NRC', c.nrc!),
                  if (c.nit?.isNotEmpty == true)
                    _infoRow(Icons.numbers, 'NIT', c.nit!),
                  _infoRow(Icons.repeat, 'Frecuencia', c.frecuenciaVisita),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text('Notas del reporte',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: _notasCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Escribe observaciones, motivo del reporte...',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(ctx, true),
          icon: const Icon(Icons.save, size: 16),
          label: const Text('Guardar reporte'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A6B3A),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    ),
  );

  if (confirmar == true) {
    final exito = await ReporteService.guardarReporte(
      tipo: 'cliente',
      idReferencia: c.id!,
      nombreReferencia: c.nombre,
      notas: _notasCtrl.text.trim(),
      creadoPor: 'Sistema',
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(exito
            ? 'Reporte de ${c.nombre} guardado ✓'
            : 'Error al guardar el reporte'),
        backgroundColor: exito ? const Color(0xFF1A6B3A) : Colors.red,
      ));
    }
  }
}

Widget _infoRow(IconData icon, String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Icon(icon, size: 14, color: Colors.grey),
      const SizedBox(width: 6),
      Text('$label: ', style: const TextStyle(
          fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
      Expanded(child: Text(value,
          style: const TextStyle(fontSize: 12),
          overflow: TextOverflow.ellipsis)),
    ]),
  );
}

  @override
  Widget build(BuildContext context) {
    final bool isWide = MediaQuery.of(context).size.width > 1000;

    return Scaffold(
      drawer: isWide ? null : const SidebarDrawerContent(),
      appBar: isWide ? null : AppBar(title: const Text('Clientes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await showDialog<bool>(
            context: context,
            builder: (_) => const AgregarClienteModal(),
          );
          if (result == true) _cargarClientes();
        },
        backgroundColor: const Color(0xFFC0392B),
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Agregar cliente',
            style: TextStyle(color: Colors.white, fontFamily: 'Itim')),
      ),
      body: Row(
        children: [
          const Sidebar(),
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildErrorState()
                    : SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isWide)
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 25),
                                child: Text('Clientes',
                                    style: TextStyle(
                                        fontSize: 42,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Itim')),
                              ),
                            if (isWide) const SizedBox(height: 16),

                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 25),
                              child: isWide
                                  ? Row(children: [
                                      Expanded(
                                        child: SearchField(
                                          hint: 'Buscar cliente',
                                          controller: _searchController,
                                          onChanged: (val) => setState(() {}),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      FilterDropdown(
                                        label: 'Filtrar por:',
                                        value: _filtroFrecuencia,
                                        options: const ['Todos', 'Frecuente', 'Regular', 'Muy poco'],
                                        onChanged: (val) => setState(() =>
                                            _filtroFrecuencia = (val == 'Todos') ? null : val),
                                      ),
                                      if (_filtroFrecuencia != null) ...[
                                        const SizedBox(width: 12),
                                        TextButton.icon(
                                          onPressed: () => setState(() => _filtroFrecuencia = null),
                                          icon: const Icon(Icons.filter_alt_off, size: 18),
                                          label: const Text('Limpiar'),
                                        ),
                                      ],
                                    ])
                                  : Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        SearchField(
                                          hint: 'Buscar cliente',
                                          controller: _searchController,
                                          onChanged: (val) => setState(() {}),
                                        ),
                                        const SizedBox(height: 10),
                                        FilterDropdown(
                                          label: 'Filtrar por:',
                                          value: _filtroFrecuencia,
                                          options: const ['Todos', 'Frecuente', 'Regular', 'Muy poco'],
                                          onChanged: (val) => setState(() =>
                                              _filtroFrecuencia = (val == 'Todos') ? null : val),
                                        ),
                                      ],
                                    ),
                            ),
                            const SizedBox(height: 20),

                            if (_clientes.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 25),
                                child: Text(
                                  '${_clientesFiltrados.length} cliente${_clientesFiltrados.length != 1 ? 's' : ''}',
                                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                                ),
                              ),
                            if (_clientes.isNotEmpty) const SizedBox(height: 8),

                            isWide
                                ? Container(
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
                                    child: _clientesFiltrados.isEmpty
                                        ? _buildEmptyState()
                                        : ClipRRect(
                                            borderRadius: BorderRadius.circular(15),
                                            child: Column(
                                              children: [
                                                _buildTableHeader(),
                                                SizedBox(
                                                  height: 400,
                                                  child: SingleChildScrollView(
                                                    child: ListView.separated(
                                                      shrinkWrap: true,
                                                      physics: const NeverScrollableScrollPhysics(),
                                                      itemCount: _clientesFiltrados.length,
                                                      separatorBuilder: (_, __) => const Divider(height: 1),
                                                      itemBuilder: (context, index) =>
                                                          _buildTableRow(_clientesFiltrados[index]),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                  )
                                : _clientesFiltrados.isEmpty
                                    ? _buildEmptyStateMobile()
                                    : _buildCardList(),

                            const SizedBox(height: 80),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No se pudo cargar los clientes',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_error ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _cargarClientes,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC0392B)),
            ),
          ],
        ),
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
                  _filtroFrecuencia != null || _searchController.text.isNotEmpty
                      ? Icons.search_off
                      : Icons.person_add_alt_1_outlined,
                  size: 80,
                  color: Colors.black54,
                ),
                const SizedBox(height: 16),
                Text(
                  _filtroFrecuencia != null || _searchController.text.isNotEmpty
                      ? 'NO HAY RESULTADOS PARA LA BÚSQUEDA ACTUAL'
                      : 'NO SE HA AGREGADO NINGÚN CLIENTE',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    const style =
        TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        color: _headerBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      child: const Row(
        children: [
          Expanded(flex: 3, child: Text('Nombre / Teléfono', style: style)),
          Expanded(flex: 2, child: Text('DUI', style: style)),
          Expanded(flex: 2, child: Text('Frecuencia de visita', style: style)),
          Expanded(flex: 3, child: Text('Acciones', style: style)),
        ],
      ),
    );
  }

  Widget _buildTableRow(Cliente c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.nombre,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text(c.telefono,
                    style: const TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ),
          ),
          Expanded(
              flex: 2, child: Text(c.dui, style: const TextStyle(fontSize: 13))),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _FrecuenciaChip(frecuencia: c.frecuenciaVisita),
            ),
          ),
          Expanded(
            flex: 3,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _AccionButton(
                  label: 'Editar',
                  color: const Color(0xFFC0392B),
                  onTap: () async {
                    final result = await showDialog<bool>(
                      context: context,
                      builder: (_) => AgregarClienteModal(cliente: c),
                    );
                    if (result == true) _cargarClientes();
                  },
                ),
                _AccionButton(
                  label: 'Eliminar',
                  color: const Color(0xFF7B1111),
                  onTap: () => _eliminarCliente(c),
                ),
                _AccionButton(
                  label: 'Reportar',
                  color: const Color(0xFF1A6B3A),
                  onTap: () => _reportarCliente(c),
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
          Icon(
            _filtroFrecuencia != null || _searchController.text.isNotEmpty
                ? Icons.search_off
                : Icons.person_add_alt_1_outlined,
            size: 80,
            color: Colors.black54,
          ),
          const SizedBox(height: 16),
          Text(
            _filtroFrecuencia != null || _searchController.text.isNotEmpty
                ? 'NO HAY RESULTADOS PARA LA BÚSQUEDA ACTUAL'
                : 'NO SE HA AGREGADO NINGÚN CLIENTE',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
                letterSpacing: 1),
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
      itemCount: _clientesFiltrados.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final c = _clientesFiltrados[index];
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 12,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  color: _headerBg,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.nombre,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15)),
                          Text(c.telefono,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                    _FrecuenciaChip(frecuencia: c.frecuenciaVisita),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    _cardRow('DUI', c.dui),
                    if (c.correo != null && c.correo!.isNotEmpty)
                      _cardRow('Correo', c.correo!),
                    if (c.direccion != null && c.direccion!.isNotEmpty)
                      _cardRow('Dirección', c.direccion!),
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
                    Row(
                      children: [
                        Expanded(
                          child: _AccionButton(
                            label: 'Editar',
                            color: const Color(0xFFC0392B),
                            fullWidth: true,
                            onTap: () async {
                              final result = await showDialog<bool>(
                                context: context,
                                builder: (_) => AgregarClienteModal(cliente: c),
                              );
                              if (result == true) _cargarClientes();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _AccionButton(
                            label: 'Eliminar',
                            color: const Color(0xFF7B1111),
                            fullWidth: true,
                            onTap: () => _eliminarCliente(c),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _AccionButton(
                            label: 'Reportar',
                            color: const Color(0xFF1A6B3A),
                            fullWidth: true,
                            onTap: () => _reportarCliente(c),
                          ),
                        ),
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
            width: 80,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}


class _FrecuenciaChip extends StatelessWidget {
  final String frecuencia;
  const _FrecuenciaChip({required this.frecuencia});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color text;
    switch (frecuencia) {
      case 'Frecuente':
        bg = const Color(0xFFDFF5E1);
        text = const Color(0xFF2E7D32);
        break;
      case 'Regular':
        bg = const Color(0xFFFFF8E1);
        text = const Color(0xFFF9A825);
        break;
      default:
        bg = const Color(0xFFFFEBEE);
        text = const Color(0xFFC62828);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(frecuencia,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.bold, color: text)),
    );
  }
}

class _AccionButton extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool fullWidth;
  const _AccionButton(
      {required this.label,
      required this.color,
      required this.onTap,
      this.fullWidth = false});

  @override
  State<_AccionButton> createState() => _AccionButtonState();
}

class _AccionButtonState extends State<_AccionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final hoverColor = Color.lerp(widget.color, Colors.black, 0.2)!;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: widget.fullWidth ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _hovered ? hoverColor : widget.color,
            borderRadius: BorderRadius.circular(6),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                        color: widget.color.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 3))
                  ]
                : [],
          ),
          child: Text(widget.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Itim')),
        ),
      ),
    );
  }
}