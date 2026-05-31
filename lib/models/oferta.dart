class Oferta {
  final int? id;
  final String nombreOferta;
  final String descripcion;
  final double porcentajeDescuento;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final String? idProductoFirebase;
  final String estadoOferta;

  Oferta({
    this.id,
    required this.nombreOferta,
    required this.descripcion,
    required this.porcentajeDescuento,
    required this.fechaInicio,
    required this.fechaFin,
    this.idProductoFirebase,
    required this.estadoOferta,
  });

  factory Oferta.fromJson(Map<String, dynamic> json) {
    return Oferta(
      id: json['id'],
      nombreOferta: json['nombre_oferta'] ?? '',
      descripcion: json['descripcion'] ?? '',
      porcentajeDescuento: (json['porcentaje_descuento'] ?? 0).toDouble(),
      fechaInicio: DateTime.parse(json['fecha_inicio']),
      fechaFin: DateTime.parse(json['fecha_fin']),
      idProductoFirebase: json['id_producto_firebase'],
      estadoOferta: json['estado_oferta'] ?? 'Activa',
    );
  }
}