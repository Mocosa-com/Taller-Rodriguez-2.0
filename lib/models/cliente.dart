class Cliente {
  final int? id;
  final String nombre;
  final String telefono;
  final String dui;
  final String? correo;
  final String? direccion;
  final String frecuenciaVisita;
  final bool estado;
  final String? fechaRegistro;
  final String? nit;
  final String? nrc;

  const Cliente({
    this.id,
    required this.nombre,
    required this.telefono,
    required this.dui,
    this.correo,
    this.direccion,
    required this.frecuenciaVisita,
    required this.estado,
    this.fechaRegistro,
    this.nit,
    this.nrc,
  });

  factory Cliente.fromJson(Map<String, dynamic> json) => Cliente(
    id: json['id'] != null ? int.tryParse(json['id'].toString()) : null,
    nombre: json['nombre']?.toString() ?? '',
    telefono: json['telefono']?.toString() ?? '',
    dui: json['dui']?.toString() ?? '',
    correo: json['correo']?.toString(),
    direccion: json['direccion']?.toString(),
    frecuenciaVisita: json['frecuencia_visita']?.toString() ?? 'Regular',
    estado: json['activo'] == true || json['activo'].toString() == 'true',
    fechaRegistro: json['fecha_registro']?.toString(),
    nit: json['nit']?.toString(),
    nrc: json['nrc']?.toString(),
  );

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'nombre': nombre,
    'telefono': telefono,
    'dui': dui,
    if (correo != null && correo!.isNotEmpty) 'correo': correo,
    if (direccion != null && direccion!.isNotEmpty) 'direccion': direccion,
    'frecuencia_visita': frecuenciaVisita,
    'activo': estado,
    if (nit != null && nit!.isNotEmpty) 'nit': nit,
    if (nrc != null && nrc!.isNotEmpty) 'nrc': nrc,
  };
}