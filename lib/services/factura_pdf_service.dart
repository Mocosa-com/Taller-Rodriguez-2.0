import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;

// Import condicional: en web usa dart:html, en nativo usa dart:io
import 'pdf_download_stub.dart'
    if (dart.library.html) 'pdf_download_web.dart'
    if (dart.library.io) 'pdf_download_native.dart';

class FacturaPdfService {
  Future<void> generarFacturaPdf(Map<String, dynamic> facturaData) async {
    final pdf = pw.Document();

    final nombreCliente       = facturaData['cliente']?['nombre'] ?? 'N/A';
    final rtnCliente          = facturaData['cliente']?['rtn']    ?? '';
    final tipoFactura         = facturaData['tipo_factura']        ?? 'Consumidor Final';
    final numeroFactura       = facturaData['numero_factura']      ?? facturaData['id']?.toString() ?? 'N/A';
    final fecha               = _formatearFecha(facturaData['fecha'] ?? DateTime.now().toIso8601String());
    final items               = (facturaData['items'] as List?)?.map((e) { final m = e as Map; return m.map((k, v) => MapEntry(k.toString(), v)); }).toList() ?? [];
    final subtotal            = (facturaData['subtotal']             as num?)?.toDouble() ?? 0.0;
    final descuentoPorcentaje = (facturaData['descuento_porcentaje'] as num?)?.toDouble() ?? 0.0;
    final descuento           = (facturaData['descuento']            as num?)?.toDouble() ?? 0.0;
    final iva                 = (facturaData['iva']                  as num?)?.toDouble() ?? 0.0;
    final total               = (facturaData['total']                as num?)?.toDouble() ?? 0.0;

    Uint8List? logoBytes;
    try {
      final data = await rootBundle.load('assets/logo_taller.png');
      logoBytes = data.buffer.asUint8List();
    } catch (_) {
      logoBytes = null;
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader(tipoFactura, numeroFactura, fecha, logoBytes),
              pw.SizedBox(height: 20),
              _buildClienteInfo(nombreCliente, rtnCliente),
              pw.SizedBox(height: 20),
              _buildItemsTable(items),
              pw.SizedBox(height: 20),
              _buildTotales(subtotal, descuentoPorcentaje, descuento, iva, total),
            ],
          );
        },
      ),
    );

    final bytes = await pdf.save();
    final filename = 'factura_$numeroFactura.pdf';

    // descargarPdf viene del import condicional (web o nativo)
    await descargarPdf(bytes, filename);
  }

  pw.Widget _buildHeader(String tipoFactura, String numeroFactura, String fecha, Uint8List? logoBytes) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.red, width: 2),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(children: [
            if (logoBytes != null)
              pw.ClipRRect(
                horizontalRadius: 8,
                verticalRadius: 8,
                child: pw.Image(pw.MemoryImage(logoBytes), width: 50, height: 50, fit: pw.BoxFit.contain),
              ),
            if (logoBytes != null) pw.SizedBox(width: 12),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('TALLER RODRIGUEZ',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.red)),
            ]),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text(tipoFactura.toUpperCase(),
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text('N° $numeroFactura', style: const pw.TextStyle(fontSize: 12)),
            pw.Text(fecha, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
          ]),
        ],
      ),
    );
  }

  pw.Widget _buildClienteInfo(String nombre, String rtn) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(4)),
      child: pw.Row(children: [
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Cliente:', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            pw.Text(nombre, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          ]),
        ),
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('RTN:', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            pw.Text(rtn.isNotEmpty ? rtn : 'N/A', style: const pw.TextStyle(fontSize: 12)),
          ]),
        ),
      ]),
    );
  }

  pw.Widget _buildItemsTable(List<Map<String, dynamic>> items) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: const {
        0: pw.FlexColumnWidth(1),
        1: pw.FlexColumnWidth(3),
        2: pw.FlexColumnWidth(1.5),
        3: pw.FlexColumnWidth(1.5),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.red),
          children: [
            _tableHeader('CANT.'),
            _tableHeader('DESCRIPCIÓN'),
            _tableHeader('PRECIO'),
            _tableHeader('TOTAL'),
          ],
        ),
        ...items.map((item) => pw.TableRow(children: [
              _tableCell('${item['cantidad']}'),
              _tableCell(item['nombre_producto']?.toString() ?? item['nombre']?.toString() ?? ''),
              _tableCell('\$${(item['precio_unitario'] as num?)?.toStringAsFixed(2) ?? '0.00'}'),
              _tableCell('\$${((item['cantidad'] as int) * ((item['precio_unitario'] as num?)?.toDouble() ?? 0.0)).toStringAsFixed(2)}'),
            ])),
      ],
    );
  }

  pw.Widget _tableHeader(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(text,
          style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10),
          textAlign: pw.TextAlign.center),
    );
  }

  pw.Widget _tableCell(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 10)),
    );
  }

  pw.Widget _buildTotales(
      double subtotal, double descuentoPorcentaje, double descuento, double iva, double total) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.SizedBox(
        width: 200,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            _fila('Subtotal:', '\$${subtotal.toStringAsFixed(2)}'),
            if (descuentoPorcentaje > 0)
              _fila('Descuento (${descuentoPorcentaje.toStringAsFixed(1)}%):',
                  '-\$${descuento.toStringAsFixed(2)}',
                  color: PdfColors.green700)
            else if (descuento > 0)
              _fila('Descuento:', '-\$${descuento.toStringAsFixed(2)}', color: PdfColors.green700),
            _fila('IVA (15%):', '\$${iva.toStringAsFixed(2)}'),
            pw.Divider(color: PdfColors.red, thickness: 1),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('TOTAL:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.Text('\$${total.toStringAsFixed(2)}',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.red)),
            ]),
          ],
        ),
      ),
    );
  }

  pw.Widget _fila(String label, String valor, {PdfColor color = PdfColors.black}) {
    return pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text(label, style: pw.TextStyle(fontSize: 10, color: color)),
      pw.Text(valor, style: pw.TextStyle(fontSize: 10, color: color)),
    ]);
  }

  String _formatearFecha(String isoFecha) {
    try {
      final fecha = DateTime.parse(isoFecha);
      return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
    } catch (_) {
      return isoFecha;
    }
  }
}