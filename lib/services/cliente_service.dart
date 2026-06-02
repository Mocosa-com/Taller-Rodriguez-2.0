import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:taller_rodriguez/models/cliente.dart';

class ClienteService {
  static final _client = Supabase.instance.client;

  static Future<List<Cliente>> getAll() async {
    final data = await _client
        .from('clientes')
        .select()
        .order('nombre', ascending: true);
     
    final lista = (data as List)
        .where((e) {
          final activo = e['activo'];
          
          return activo == true || activo.toString() == 'true';
        })
        .map((e) => Cliente.fromJson(e))
        .toList();
    
    return lista;
  }

  static Future<void> create(Cliente cliente) async {
    final json = cliente.toJson()..remove('id');
    json['activo'] = true;
    await _client.from('clientes').insert(json);
  }

  static Future<void> update(Cliente cliente) async {
    await _client.from('clientes').update(cliente.toJson()).eq('id', cliente.id!);
  }

  static Future<void> delete(int id) async {
    await _client.from('clientes').update({'activo': false}).eq('id', id);
  }
}