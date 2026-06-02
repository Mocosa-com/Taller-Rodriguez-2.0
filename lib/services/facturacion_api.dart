import 'package:supabase_flutter/supabase_flutter.dart';

class FacturacionApi {
  static get _db => Supabase.instance.client;

  // ─── CLIENTES ──────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> obtenerClientes() async {
    try {
      final data = await _db
          .from('clientes')
          .select('id, nombre, nit, nrc, dui')
          .eq('activo', true)
          .order('nombre');
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      return [];
    }
  }

  // ─── VEHICULOS POR CLIENTE ─────────────────────────────────
  Future<List<Map<String, dynamic>>> obtenerVehiculosPorCliente(int? clienteId) async {
    if (clienteId == null) return [];
    try {
      final data = await _db
          .from('vehiculos')
          .select('id, marca, modelo, placa')
          .eq('id_cliente', clienteId)
          .eq('activo', true)
          .order('marca');
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      return [];
    }
  }

  // ─── OFERTAS ACTIVAS ───────────────────────────────────────
  Future<List<Map<String, dynamic>>> obtenerOfertas() async {
    try {
      final hoy = DateTime.now().toIso8601String().split('T')[0];
      final data = await _db
          .from('ofertas')
          .select()
          .eq('activo', true)
          .gte('fecha_fin', hoy)
          .order('nombre_oferta');
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      return [];
    }
  }

  // ─── INVENTARIO ────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> obtenerInventario({String? busqueda}) async {
    try {
      var query = _db
          .from('inventario')
          .select('id, nombre, precio_venta, tipo, stock, stock_minimo, clasificacion, descripcion, sku')
          .eq('activo', true);

      if (busqueda != null && busqueda.isNotEmpty) {
        query = query.ilike('nombre', '%$busqueda%');
      }

      final data = await query.order('nombre');
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      return [];
    }
  }

  // ─── OBTENER FACTURAS (HISTORIAL) ─────────────────────────
  Future<List<Map<String, dynamic>>> obtenerFacturas() async {
    try {
      final data = await _db
          .from('facturacion')
          .select('''
            id, fecha, tipo_factura, subtotal, iva, descuento,
            descuento_porcentaje, total,
            clientes:id_cliente(id, nombre, nit),
            vehiculos:id_vehiculo(id, marca, modelo, placa)
          ''')
          .order('id', ascending: false)
          .limit(200);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      return [];
    }
  }

  // ─── OBTENER FACTURA POR ID ────────────────────────────────
  Future<Map<String, dynamic>?> obtenerFacturaPorId(int id) async {
    try {
      final factura = await _db
          .from('facturacion')
          .select('''
            id, fecha, tipo_factura, subtotal, iva, descuento,
            descuento_porcentaje, total,
            clientes:id_cliente(id, nombre, nit, dui),
            vehiculos:id_vehiculo(id, marca, modelo, placa)
          ''')
          .eq('id', id)
          .single();

      final detalles = await _db
          .from('detalles_factura')
          .select()
          .eq('id_factura', id)
          .order('id');

      return {
        ...Map<String, dynamic>.from(factura),
        'items': detalles,
      };
    } catch (e) {
      return null;
    }
  }

  // ─── CREAR FACTURA (TRANSACCIÓN COMPLETA) ─────────────────
  Future<Map<String, dynamic>> crearFactura({
    int? idCliente,
    int? idVehiculo,
    required String tipoFactura,
    required List<Map<String, dynamic>> items,
    double descuentoPorcentaje = 0,
    int? idOferta,
    int? idCaja,
  }) async {
    try {
      if (items.isEmpty) {
        return {'success': false, 'message': 'Debe agregar al menos un ítem'};
      }
      if (descuentoPorcentaje < 0 || descuentoPorcentaje > 100) {
        return {'success': false, 'message': 'El descuento debe ser entre 0 y 100%'};
      }

      // ── Calcular totales ──
      double subtotal = 0;
      for (final item in items) {
        final cantidad = (item['cantidad'] as int? ?? 1);
        final precio = (item['precio_unitario'] as num?)?.toDouble() ?? 0.0;
        subtotal += cantidad * precio;
      }

      final descuento = subtotal * (descuentoPorcentaje / 100);
      final subtotalConDescuento = subtotal - descuento;
      final iva = subtotalConDescuento * 0.13;
      final total = subtotalConDescuento + iva;

      // ── Verificar stock antes de insertar ──
      final List<Map<String, dynamic>> warnings = [];
      for (final item in items) {
        final tipo = (item['tipo'] as String? ?? '').toLowerCase();
        if (tipo == 'servicio') continue;

        final idProducto = item['id_producto']?.toString() ?? '';
        final cantidad = item['cantidad'] as int? ?? 1;

        try {
          final prodData = await _db
              .from('inventario')
              .select('stock, stock_minimo, nombre')
              .eq('id', int.tryParse(idProducto) ?? 0)
              .single();

          final stockActual = prodData['stock'] as int? ?? 0;
          if (stockActual < cantidad) {
            return {
              'success': false,
              'message': 'Stock insuficiente para ${prodData['nombre']}: disponible $stockActual, solicitado $cantidad',
            };
          }
        } catch (_) {}
      }

      // ── Insertar factura ──
      final facturaInsertada = await _db.from('facturacion').insert({
        'fecha': DateTime.now().toIso8601String(),
        'tipo_factura': tipoFactura,
        'subtotal': subtotal,
        'iva': iva,
        'descuento': descuento,
        'descuento_porcentaje': descuentoPorcentaje,
        'total': total,
        'id_cliente': idCliente,
        'id_vehiculo': idVehiculo,
      }).select().single();

      final int idFactura = facturaInsertada['id'] as int;

      // ── Insertar detalles ──
      for (final item in items) {
        final cantidad = item['cantidad'] as int? ?? 1;
        final precio = (item['precio_unitario'] as num?)?.toDouble() ?? 0.0;
        final tipo = (item['tipo'] as String? ?? 'Producto');
        final esProducto = tipo.toLowerCase() != 'servicio';

        await _db.from('detalles_factura').insert({
          'id_factura': idFactura,
          'id_producto': int.tryParse(item['id_producto']?.toString() ?? '') ?? item['id_producto'],
          'nombre_producto': item['nombre']?.toString() ?? '',
          'tipo_producto': esProducto ? 'Producto' : 'Servicio',
          'cantidad': cantidad,
          'precio_unitario': precio,
          'subtotal': cantidad * precio,
          'clasificacion': item['clasificacion']?.toString(),
          'descripcion': item['descripcion']?.toString(),
          'sku': item['sku']?.toString(),
        });

        // ── Descontar stock si es producto ──
        if (esProducto) {
          final idProducto = int.tryParse(item['id_producto']?.toString() ?? '');
          if (idProducto != null) {
            try {
              final stockData = await _db
                  .from('inventario')
                  .select('stock, stock_minimo, nombre')
                  .eq('id', idProducto)
                  .single();

              final stockActual = stockData['stock'] as int? ?? 0;
              final stockMinimo = stockData['stock_minimo'] as int? ?? 0;
              final nuevoStock = stockActual - cantidad;

              await _db
                  .from('inventario')
                  .update({'stock': nuevoStock})
                  .eq('id', idProducto);

              if (nuevoStock <= stockMinimo) {
                warnings.add({
                  'nombre': stockData['nombre'],
                  'stock_actual': nuevoStock,
                  'stock_minimo': stockMinimo,
                });
              }
            } catch (_) {}
          }
        }
      }

      // Buscar datos completos del cliente para el PDF
      Map<String, dynamic>? clienteData;
      if (idCliente != null) {
        try {
          final cRow = await _db
              .from('clientes')
              .select('id, nombre, nit, nrc, dui')
              .eq('id', idCliente)
              .single();
          clienteData = Map<String, dynamic>.from(cRow);
        } catch (_) {}
      }

      return {
        'success': true,
        'id': idFactura,
        'total': total,
        'warnings_stock': warnings,
        'factura': {
          ...facturaInsertada,
          'items': items,
          'cliente': clienteData,
          'numero_factura': idFactura,
          'tipo_factura': tipoFactura,
        },
      };
    } catch (e) {
      return {'success': false, 'message': 'Error al crear factura: $e'};
    }
  }

  // ─── ANULAR FACTURA (SOFT DELETE) ─────────────────────────
  Future<bool> anularFactura(int id) async {
    try {
      // Verificar si existe la columna anulada, si no usar otro campo
      await _db
          .from('facturacion')
          .update({'anulada': true})
          .eq('id', id);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ─── REPORTES ─────────────────────────────────────────────

  /// Ventas totales por período
  Future<Map<String, dynamic>> obtenerResumenVentas({
    required DateTime desde,
    required DateTime hasta,
  }) async {
    try {
      final data = await _db
          .from('facturacion')
          .select('total, subtotal, iva, descuento, fecha')
          .gte('fecha', desde.toIso8601String())
          .lte('fecha', hasta.toIso8601String());

      double totalVentas = 0;
      double totalIva = 0;
      double totalDescuentos = 0;
      int cantidadFacturas = data.length;

      for (final f in data) {
        totalVentas += (f['total'] as num?)?.toDouble() ?? 0;
        totalIva += (f['iva'] as num?)?.toDouble() ?? 0;
        totalDescuentos += (f['descuento'] as num?)?.toDouble() ?? 0;
      }

      return {
        'total_ventas': totalVentas,
        'total_iva': totalIva,
        'total_descuentos': totalDescuentos,
        'cantidad_facturas': cantidadFacturas,
      };
    } catch (e) {
      return {};
    }
  }

  /// Productos más vendidos
  Future<List<Map<String, dynamic>>> obtenerProductosMasVendidos({int limit = 10}) async {
    try {
      final data = await _db
          .from('detalles_factura')
          .select('nombre_producto, tipo_producto, cantidad')
          .order('cantidad', ascending: false)
          .limit(limit * 5); // Traemos más para agrupar

      // Agrupar por nombre
      final Map<String, Map<String, dynamic>> agrupado = {};
      for (final d in data) {
        final nombre = d['nombre_producto'] as String;
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
      lista.sort((a, b) => (b['cantidad'] as int).compareTo(a['cantidad'] as int));
      return lista.take(limit).toList();
    } catch (e) {
      return [];
    }
  }
}
