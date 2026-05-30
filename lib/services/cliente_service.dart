import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:taller_rodriguez/models/cliente.dart';

class ClienteService {
  static final _db = Supabase.instance.client.from('clientes');

static Future<List<Cliente>> getAll() async {
  final data = await _db
      .select()
      .or('activo.eq.true,activo.is.null')
      .order('nombre', ascending: true);
  print('CLIENTES RAW: $data');
  return (data as List).map((e) => Cliente.fromJson(e)).toList();
}

  static Future<void> create(Cliente cliente) async {
    final json = cliente.toJson()..remove('id');
    json['activo'] = true;
    await _db.insert(json);
  }

  static Future<void> update(Cliente cliente) async {
    await _db.update(cliente.toJson()).eq('id', cliente.id!);
  }

  static Future<void> delete(int id) async {
    // No se borra — se desactiva
    await _db.update({'activo': false}).eq('id', id);
  }
}