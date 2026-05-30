import 'package:flutter/material.dart';
import 'package:taller_rodriguez/widgets/navigation/sidebar.dart';
import 'package:taller_rodriguez/services/caja_service.dart';

class HistorialTurnosPage extends StatefulWidget {
  const HistorialTurnosPage({super.key});

  @override
  State<HistorialTurnosPage> createState() => _HistorialTurnosPageState();
}

class _HistorialTurnosPageState extends State<HistorialTurnosPage> {
  static const Color _headerColor = Color(0xFFA61B1B);
  List<Map<String, dynamic>> _turnos = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarTurnos();
  }

  Future<void> _cargarTurnos() async {
    setState(() => _cargando = true);
    final turnos = await CajaService.getHistorial();
    setState(() {
      _turnos = turnos;
      _cargando = false;
    });
  }

  String _formatearFecha(String? fecha) {
    if (fecha == null) return '-';
    try {
      final d = DateTime.parse(fecha);
      return '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
    } catch (_) { return fecha; }
  }

  String _formatearHora(String? hora) {
    if (hora == null) return '-';
    return hora.substring(0, 5);
  }

  String _formatearMonto(dynamic valor) {
    if (valor == null) return '-';
    final n = (valor is num) ? valor.toDouble() : double.tryParse(valor.toString()) ?? 0;
    return '\$${n.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final bool isWide = MediaQuery.of(context).size.width > 1000;

    return Scaffold(
      drawer: isWide ? null : const SidebarDrawerContent(),
      appBar: isWide ? null : AppBar(title: const Text('Historial de turnos')),
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
                      child: Text('Historial de turnos',
                        style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold, fontFamily: 'Itim')),
                    ),
                  if (isWide) const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 10))],
                      ),
                      child: _cargando
                          ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
                          : _turnos.isEmpty ? _buildEmptyState() : _buildTable(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _BotonVolver(onPressed: () => Navigator.pushNamed(context, '/caja')),
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

  Widget _buildEmptyState() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: SizedBox(
        height: 300,
        child: Column(
          children: [
            _buildTableHeader(),
            const Expanded(child: Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 80, color: Colors.black26),
                SizedBox(height: 16),
                Text('NO HAY TURNOS REGISTRADOS',
                  style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ],
            ))),
          ],
        ),
      ),
    );
  }

  Widget _buildTable() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double tableWidth = constraints.maxWidth > 860 ? constraints.maxWidth : 860;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: Column(
                children: [
                  _buildTableHeader(),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _turnos.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final t = _turnos[index];
                      final responsable = t['empleados'] is Map
                          ? t['empleados']['nombre']?.toString() ?? '-'
                          : '-';
                      final estado = t['estado']?.toString() ?? '-';
                      final esAbierta = estado == 'Abierta';
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            SizedBox(width: 100, child: Text(_formatearFecha(t['fecha']?.toString()), style: const TextStyle(fontSize: 13))),
                            SizedBox(width: 90,  child: Text('#${t['id']}', style: const TextStyle(fontSize: 13))),
                            SizedBox(width: 130, child: Text(responsable, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                            SizedBox(width: 90,  child: Text(_formatearMonto(t['base_inicial']), style: const TextStyle(fontSize: 13))),
                            SizedBox(width: 90,  child: Text(_formatearMonto(t['efectivo_actual']), style: const TextStyle(fontSize: 13))),
                            SizedBox(width: 90,  child: Text(_formatearMonto(t['total_cierre']), style: const TextStyle(fontSize: 13))),
                            SizedBox(width: 100, child: Text(_formatearHora(t['hora_apertura']?.toString()), style: const TextStyle(fontSize: 13))),
                            SizedBox(width: 100, child: Text(_formatearHora(t['hora_cierre']?.toString()), style: const TextStyle(fontSize: 13))),
                            Expanded(child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: esAbierta ? Colors.green.shade50 : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(estado,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                                  color: esAbierta ? Colors.green : Colors.grey.shade600)),
                            )),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
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
      child: const Row(
        children: [
          SizedBox(width: 100, child: Text('FECHA',        style: style)),
          SizedBox(width: 90,  child: Text('TURNO',        style: style)),
          SizedBox(width: 130, child: Text('RESPONSABLE',  style: style)),
          SizedBox(width: 90,  child: Text('BASE',         style: style)),
          SizedBox(width: 90,  child: Text('EFECTIVO',     style: style)),
          SizedBox(width: 90,  child: Text('CIERRE',       style: style)),
          SizedBox(width: 100, child: Text('HORA INICIO',  style: style)),
          SizedBox(width: 100, child: Text('HORA CIERRE',  style: style)),
          Expanded(            child: Text('ESTADO',       style: style)),
        ],
      ),
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
            padding: EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            child: Text('Volver a caja',
              style: TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'Itim', fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}