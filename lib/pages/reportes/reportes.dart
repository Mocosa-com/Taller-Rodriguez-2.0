import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:taller_rodriguez/services/reporte_service.dart';
import 'package:taller_rodriguez/widgets/navigation/sidebar.dart';

class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
   
}

class _ReportesScreenState extends State<ReportesScreen> {
  static get _db => Supabase.instance.client;

  String _filtroSeleccionado = 'Este mes';
  final List<String> _filtros = ['Este mes', 'Última semana', 'Este año'];
  bool _cargando = true;

  List<Map<String, dynamic>> _reportesGuardados = [];

  // KPIs
  double _ventasDia = 0;
  double _saldoCaja = 0;
  int _totalProductos = 0;
  int _vehiculosActivos = 0;
  int _facturasDia = 0;

  // Gráfica de barras: ventas por semana del mes
  List<double> _ventasProductosSemana = [0, 0, 0, 0];
  List<double> _ventasServiciosSemana = [0, 0, 0, 0];

  // Productos stock bajo
  List<Map<String, dynamic>> _stockBajo = [];

  // Más vendidos
  List<Map<String, dynamic>> _masVendidos = [];

  // Donut
  double _pctProductos = 0;
  double _pctServicios = 0;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  DateTimeRange get _rango {
    final hoy = DateTime.now();
    switch (_filtroSeleccionado) {
      case 'Última semana':
        return DateTimeRange(
          start: hoy.subtract(const Duration(days: 7)),
          end: hoy,
        );
      case 'Este año':
        return DateTimeRange(
          start: DateTime(hoy.year, 1, 1),
          end: hoy,
        );
      default: // Este mes
        return DateTimeRange(
          start: DateTime(hoy.year, hoy.month, 1),
          end: hoy,
        );
    }
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      await Future.wait([
        _cargarKpis(),
        _cargarVentasSemana(),
        _cargarStockBajo(),
        _cargarMasVendidos(),
        _cargarDonut(),
        _cargarReportesGuardados(),

      ]);
    } catch (e) {
      debugPrint('Error cargando reportes: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

Future<void> _cargarReportesGuardados() async {
    try {
      final data = await _db
          .from('reportes')
          .select()
          .order('fecha', ascending: false);
      _reportesGuardados = List<Map<String, dynamic>>.from(data);
    } catch (_) {
      _reportesGuardados = [];
    }
  }

  Future<void> _cargarKpis() async {
    final hoy = DateTime.now();
    final inicioDia = DateTime(hoy.year, hoy.month, hoy.day);

    // Ventas del día
    try {
      final factDia = await _db
          .from('facturacion')
          .select('total')
          .gte('fecha', inicioDia.toIso8601String());
      double suma = 0;
      for (final f in factDia) {
        suma += (f['total'] as num?)?.toDouble() ?? 0;
      }
      _ventasDia = suma;
      _facturasDia = factDia.length;
    } catch (_) {}

    // Inventario total
    try {
      final inv = await _db.from('inventario').select('id').eq('activo', true);
      _totalProductos = inv.length;
    } catch (_) {}

    // Vehículos activos en taller
    try {
      final vehs = await _db.from('vehiculos_taller').select('id').eq('activo', true);
      _vehiculosActivos = vehs.length;
    } catch (_) {
      // Si no existe la tabla, usar 0
      _vehiculosActivos = 0;
    }

    // Saldo caja (último turno abierto)
    try {
      final cajas = await _db
          .from('caja')
          .select('monto_base, total_ingresos, total_egresos')
          .eq('estado', 'abierta')
          .limit(1);
      if (cajas.isNotEmpty) {
        final c = cajas.first;
        _saldoCaja = ((c['monto_base'] as num?)?.toDouble() ?? 0) +
            ((c['total_ingresos'] as num?)?.toDouble() ?? 0) -
            ((c['total_egresos'] as num?)?.toDouble() ?? 0);
      }
    } catch (_) {}
  }

  Future<void> _cargarVentasSemana() async {
    final rango = _rango;
    try {
      final facturas = await _db
          .from('facturacion')
          .select('fecha, total, id')
          .gte('fecha', rango.start.toIso8601String())
          .lte('fecha', rango.end.toIso8601String());

      // Dividir el rango en 4 semanas
      final duracion = rango.end.difference(rango.start).inDays;
      final porSemana = (duracion / 4).ceil().clamp(1, 365);

      List<double> productos = [0, 0, 0, 0];
      List<double> servicios = [0, 0, 0, 0];

      for (final f in facturas) {
        try {
          final fecha = DateTime.parse(f['fecha'].toString());
          final diasDesdeInicio = fecha.difference(rango.start).inDays;
          final semana = (diasDesdeInicio ~/ porSemana).clamp(0, 3);
          final id = f['id'] as int;

          // Obtener detalles
          final detalles = await _db
              .from('detalles_factura')
              .select('tipo_producto, subtotal')
              .eq('id_factura', id);

          for (final d in detalles) {
            final tipo = (d['tipo_producto'] ?? '').toString().toLowerCase();
            final sub = (d['subtotal'] as num?)?.toDouble() ?? 0;
            if (tipo == 'servicio') {
              servicios[semana] += sub;
            } else {
              productos[semana] += sub;
            }
          }
        } catch (_) {}
      }

      _ventasProductosSemana = productos;
      _ventasServiciosSemana = servicios;
    } catch (_) {}
  }

  Future<void> _cargarStockBajo() async {
    try {
      final data = await _db
          .from('inventario')
          .select('nombre, stock, stock_minimo')
          .eq('activo', true)
          .filter('stock', 'lte', 'stock_minimo')
          .order('stock')
          .limit(5);
      _stockBajo = List<Map<String, dynamic>>.from(data);
    } catch (_) {
      // Fallback: traer todos y filtrar manualmente
      try {
        final data = await _db
            .from('inventario')
            .select('nombre, stock, stock_minimo')
            .eq('activo', true)
            .order('stock')
            .limit(50);
        _stockBajo = data
            .where((d) =>
                (d['stock'] as int? ?? 0) <= (d['stock_minimo'] as int? ?? 0))
            .take(5)
            .toList()
            .cast<Map<String, dynamic>>();
      } catch (_) {}
    }
  }

  Future<void> _cargarMasVendidos() async {
    try {
      final rango = _rango;
      // Obtener IDs de facturas del período
      final factIds = await _db
          .from('facturacion')
          .select('id')
          .gte('fecha', rango.start.toIso8601String())
          .lte('fecha', rango.end.toIso8601String());

      if (factIds.isEmpty) return;

      final ids = factIds.map((f) => f['id']).toList();

      final detalles = await _db
          .from('detalles_factura')
          .select('nombre_producto, tipo_producto, cantidad')
          .inFilter('id_factura', ids);

      // Agrupar
      final Map<String, Map<String, dynamic>> agrupado = {};
      for (final d in detalles) {
        final nombre = d['nombre_producto'].toString();
        if (agrupado.containsKey(nombre)) {
          agrupado[nombre]!['cantidad'] =
              (agrupado[nombre]!['cantidad'] as int) + (d['cantidad'] as int);
        } else {
          agrupado[nombre] = {
            'nombre_producto': nombre,
            'tipo_producto': d['tipo_producto'],
            'cantidad': d['cantidad'] as int,
          };
        }
      }

      final lista = agrupado.values.toList();
      lista.sort((a, b) =>
          (b['cantidad'] as int).compareTo(a['cantidad'] as int));
      _masVendidos = lista.take(5).toList();
    } catch (_) {}
  }

  Future<void> _cargarDonut() async {
    try {
      final rango = _rango;
      final factIds = await _db
          .from('facturacion')
          .select('id')
          .gte('fecha', rango.start.toIso8601String())
          .lte('fecha', rango.end.toIso8601String());

      if (factIds.isEmpty) {
        _pctProductos = 0;
        _pctServicios = 0;
        return;
      }

      final ids = factIds.map((f) => f['id']).toList();
      final detalles = await _db
          .from('detalles_factura')
          .select('tipo_producto, subtotal')
          .inFilter('id_factura', ids);

      double totalProd = 0, totalServ = 0;
      for (final d in detalles) {
        final tipo = (d['tipo_producto'] ?? '').toString().toLowerCase();
        final sub = (d['subtotal'] as num?)?.toDouble() ?? 0;
        if (tipo == 'servicio') {
          totalServ += sub;
        } else {
          totalProd += sub;
        }
      }

      final total = totalProd + totalServ;
      if (total > 0) {
        _pctProductos = (totalProd / total) * 100;
        _pctServicios = (totalServ / total) * 100;
      }
} catch (_) {}
}

Widget _buildGrupoReportes(String tipo, IconData icon, Color color) {
  final lista = _reportesGuardados
      .where((r) => r['tipo'] == tipo)
      .toList();
  if (lista.isEmpty) return const SizedBox();

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 12),
      Row(children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          tipo == 'empleado' ? 'Empleados' : 'Clientes',
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color),
        ),
      ]),
      const SizedBox(height: 8),
      ...lista.map((r) => _buildReporteItem(r)),
    ],
  );
}

Widget _buildReporteItem(Map<String, dynamic> r) {
  final fecha = r['fecha'] != null
      ? DateTime.tryParse(r['fecha'].toString())
      : null;
  final fechaStr = fecha != null
      ? '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}'
      : '—';
  final tipo = r['tipo']?.toString() ?? '';
  final color = tipo == 'empleado' ? coral : teal;
  final notas = r['notas']?.toString() ?? '';

  return Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: tipo == 'empleado'
          ? const Color(0xFFFAECE7)
          : const Color(0xFFE1F5EE),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: color.withOpacity(0.2),
        width: 0.5,
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            tipo == 'empleado' ? Icons.assignment_ind : Icons.assignment,
            color: color,
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      r['nombre_referencia']?.toString() ?? '—',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(fechaStr,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey)),
                ],
              ),
              if (notas.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  notas,
                  style: const TextStyle(
                      fontSize: 12, color: Colors.black54),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (r['creado_por'] != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Por: ${r['creado_por']}',
                  style:
                      const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline,
              size: 18, color: Colors.grey),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          tooltip: 'Eliminar reporte',
          onPressed: () async {
            await ReporteService.eliminar(r['id'] as int);
            _cargarDatos();
          },
        ),
      ],
    ),
  );
}

Widget _buildReportesGuardados() {
  if (_reportesGuardados.isEmpty) {
    return const SizedBox();
  }

  return _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _CardTitle('Reportes guardados'),

        _buildGrupoReportes(
          'empleado',
          Icons.assignment_ind,
          coral,
        ),

        _buildGrupoReportes(
          'cliente',
          Icons.assignment,
          teal,
        ),
      ],
    ),
  );
}
 
  static const Color purple = Color(0xFF7F77DD);
  static const Color teal   = Color(0xFF1D9E75);
  static const Color coral  = Color(0xFFD85A30);
  static const Color bgPage = Color(0xFFF4F3F7);
  static const Color border = Color(0xFFE0DCED);



  @override
  Widget build(BuildContext context) {
    final bool isWide = MediaQuery.of(context).size.width > 1000;

    return Scaffold(
      backgroundColor: bgPage,
      drawer: isWide ? null : const SidebarDrawerContent(),
      appBar: isWide
          ? null
          : AppBar(
              backgroundColor: bgPage,
              elevation: 0,
              title: const Text('Reportes', style: TextStyle(color: Colors.black87)),
            ),
      body: SafeArea(
        child: Row(
          children: [
            if (isWide) const Sidebar(),
            Expanded(
              child: _cargando
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _cargarDatos,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isWide) _buildHeader(),
                            if (!isWide) _buildMobileFiltro(),
                            const SizedBox(height: 16),
                            _buildKpis(),
                            const SizedBox(height: 16),
                            _buildMainRow(),
                            const SizedBox(height: 16),
                            _buildBottomRow(),
                             const SizedBox(height: 16),
                            _buildReportesGuardados(),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Reportes', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500)),
        Row(
          children: [
            _FiltroDropdown(
              value: _filtroSeleccionado,
              items: _filtros,
              onChanged: (v) {
                setState(() => _filtroSeleccionado = v!);
                _cargarDatos();
              },
            ),
            const SizedBox(width: 10),
            IconButton(
              tooltip: 'Actualizar',
              onPressed: _cargarDatos,
              icon: const Icon(Icons.refresh, color: Colors.red),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMobileFiltro() {
    return _FiltroDropdown(
      value: _filtroSeleccionado,
      items: _filtros,
      onChanged: (v) {
        setState(() => _filtroSeleccionado = v!);
        _cargarDatos();
      },
    );
  }

  Widget _buildKpis() {
    return LayoutBuilder(builder: (context, c) {
      final bool mobile = c.maxWidth < 600;
      final int crossCount = mobile ? 2 : 4;
      const double spacing = 12;
      final double itemW = (c.maxWidth - spacing * (crossCount - 1)) / crossCount;

      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          SizedBox(width: itemW, child: _KpiCard(
            icon: Icons.attach_money_rounded,
            iconBg: const Color(0xFFEEEDFE), iconColor: const Color(0xFF534AB7),
            label: 'Ventas del día',
            value: '\$${_ventasDia.toStringAsFixed(2)}',
            sub: '$_facturasDia factura(s)',
            subColor: const Color(0xFF3B6D11),
            subIcon: Icons.receipt,
          )),
          SizedBox(width: itemW, child: _KpiCard(
            icon: Icons.storefront_outlined,
            iconBg: const Color(0xFFEAF3DE), iconColor: const Color(0xFF3B6D11),
            label: 'Inventario',
            value: '$_totalProductos prod.',
            sub: '${_stockBajo.length} en stock bajo',
            subColor: _stockBajo.isEmpty ? Colors.grey : const Color(0xFF854F0B),
            subIcon: _stockBajo.isEmpty ? null : Icons.warning_amber_rounded,
          )),
          SizedBox(width: itemW, child: _KpiCard(
            icon: Icons.account_balance_wallet_outlined,
            iconBg: const Color(0xFFE1F5EE), iconColor: const Color(0xFF0F6E56),
            label: 'Saldo en caja',
            value: '\$${_saldoCaja.toStringAsFixed(2)}',
            sub: 'Turno actual',
            subColor: Colors.grey,
          )),
          SizedBox(width: itemW, child: _KpiCard(
            icon: Icons.directions_car_outlined,
            iconBg: const Color(0xFFFAECE7), iconColor: const Color(0xFF993C1D),
            label: 'Vehículos taller',
            value: '$_vehiculosActivos activos',
            sub: '',
            subColor: Colors.grey,
          )),
        ],
      );
    });
  }

  Widget _buildMainRow() {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth > 600) {
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 2, child: _buildVentasMesCard()),
          const SizedBox(width: 16),
          Expanded(child: _buildTopVendidosCard()),
        ]);
      }
      return Column(children: [
        _buildVentasMesCard(),
        const SizedBox(height: 16),
        _buildTopVendidosCard(),
      ]);
    });
  }

  Widget _buildVentasMesCard() {
    final maxY = [..._ventasProductosSemana, ..._ventasServiciosSemana]
        .fold(0.0, (a, b) => a > b ? a : b);

    final escala = maxY > 0 ? maxY * 1.3 : 500.0;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle('Ventas — $_filtroSeleccionado'),
          _LegendRow(items: const [
            _LegendItem(color: purple, label: 'Productos'),
            _LegendItem(color: teal, label: 'Servicios'),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: _ventasProductosSemana.every((v) => v == 0) && _ventasServiciosSemana.every((v) => v == 0)
                ? const Center(child: Text('Sin ventas en el período', style: TextStyle(color: Colors.grey)))
                : BarChart(BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: escala,
                    barTouchData: BarTouchData(enabled: true),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (v, _) => Text('\$${v.toInt()}',
                            style: const TextStyle(fontSize: 9, color: Colors.grey)),
                        interval: escala / 4,
                      )),
                      bottomTitles: AxisTitles(sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          final labels = ['Sem 1', 'Sem 2', 'Sem 3', 'Sem 4'];
                          final i = v.toInt();
                          if (i < 0 || i >= labels.length) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(labels[i], style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          );
                        },
                      )),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(
                      show: true,
                      getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFFEEEEEE), strokeWidth: 1),
                      drawVerticalLine: false,
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: List.generate(4, (i) => BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(toY: _ventasProductosSemana[i], color: purple, width: 12,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                        BarChartRodData(toY: _ventasServiciosSemana[i], color: teal, width: 12,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                      ],
                    )),
                  )),
          ),
        ],
      ),
    );
  }

  Widget _buildTopVendidosCard() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle('Más vendidos'),
          if (_masVendidos.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: Text('Sin datos', style: TextStyle(color: Colors.grey))),
            )
          else
            ..._masVendidos.map((p) {
              final tipo = (p['tipo_producto'] ?? '').toString().toLowerCase();
              return _StatusRow(
                label: p['nombre_producto']?.toString() ?? '-',
                value: '${p['cantidad']} uds.',
                valueColor: tipo == 'servicio' ? Colors.orange.shade700 : Colors.blue.shade700,
              );
            }),
        ],
      ),
    );
  }

  Widget _buildBottomRow() {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth > 600) {
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _buildInventarioCard()),
          const SizedBox(width: 16),
          Expanded(child: _buildDonutCard()),
        ]);
      }
      return Column(children: [
        _buildInventarioCard(),
        const SizedBox(height: 16),
        _buildDonutCard(),
      ]);
    });
  }

  Widget _buildInventarioCard() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle('Stock bajo'),
          if (_stockBajo.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Icon(Icons.check_circle, color: Colors.green, size: 18),
                SizedBox(width: 6),
                Text('Todo el inventario OK', style: TextStyle(color: Colors.green)),
              ]),
            )
          else
            ..._stockBajo.map((p) => _AlertItem(
              label: p['nombre']?.toString() ?? '-',
              cantidad: '${p['stock']} / min ${p['stock_minimo']}',
            )),
        ],
      ),
    );
  }

  Widget _buildDonutCard() {
    final hasDatos = _pctProductos > 0 || _pctServicios > 0;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle('Ventas por tipo'),
          SizedBox(
            height: 160,
            child: hasDatos
                ? PieChart(PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 45,
                    sections: [
                      PieChartSectionData(value: _pctProductos, color: purple, radius: 40, showTitle: false),
                      PieChartSectionData(value: _pctServicios, color: teal, radius: 40, showTitle: false),
                    ],
                  ))
                : const Center(child: Text('Sin datos', style: TextStyle(color: Colors.grey))),
          ),
          const SizedBox(height: 8),
          if (hasDatos)
            _LegendRow(items: [
              _LegendItem(color: purple, label: 'Prod. ${_pctProductos.toStringAsFixed(0)}%'),
              _LegendItem(color: teal, label: 'Serv. ${_pctServicios.toStringAsFixed(0)}%'),
            ]),
        ],
      ),
    );
  }
}

// ─── Widgets de apoyo ──────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE0DCED), width: 0.5),
        ),
        padding: const EdgeInsets.all(16),
        child: child,
      );
}

class _CardTitle extends StatelessWidget {
  final String text;
  const _CardTitle(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      );
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg, iconColor;
  final String label, value, sub;
  final Color subColor;
  final IconData? subIcon;
  const _KpiCard({required this.icon, required this.iconBg, required this.iconColor,
      required this.label, required this.value, required this.sub, required this.subColor, this.subIcon});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE0DCED), width: 0.5),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 36, height: 36,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: iconColor, size: 18)),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Row(children: [
            if (subIcon != null) ...[Icon(subIcon, size: 12, color: subColor), const SizedBox(width: 2)],
            Flexible(child: Text(sub, style: TextStyle(fontSize: 11, color: subColor))),
          ]),
        ]),
      );
}

class _StatusRow extends StatelessWidget {
  final String label;
  final String? value;
  final Color valueColor;
  final bool bold;
  const _StatusRow({required this.label, this.value, this.valueColor = Colors.black87, this.bold = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: bold ? Colors.black87 : Colors.grey,
              fontWeight: bold ? FontWeight.w500 : FontWeight.normal), overflow: TextOverflow.ellipsis)),
          if (value != null)
            Text(value!, style: TextStyle(fontSize: bold ? 15 : 13,
                fontWeight: bold ? FontWeight.w500 : FontWeight.normal, color: valueColor)),
        ]),
      );
}

class _AlertItem extends StatelessWidget {
  final String label, cantidad;
  const _AlertItem({required this.label, required this.cantidad});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: const Color(0xFFFAEEDA), borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF633806)),
              overflow: TextOverflow.ellipsis)),
          Text(cantidad, style: const TextStyle(fontSize: 12, color: Color(0xFF633806), fontWeight: FontWeight.bold)),
        ]),
      );
}

class _LegendRow extends StatelessWidget {
  final List<_LegendItem> items;
  const _LegendRow({required this.items});
  @override
  Widget build(BuildContext context) => Wrap(spacing: 16, children: items);
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ]);
}

class _FiltroDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  const _FiltroDropdown({required this.value, required this.items, required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFC9C2E8), width: 0.5)),
        child: DropdownButton<String>(
          value: value, isExpanded: false, underline: const SizedBox(),
          style: const TextStyle(fontSize: 13, color: Colors.black87),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
        ),
      );
}
