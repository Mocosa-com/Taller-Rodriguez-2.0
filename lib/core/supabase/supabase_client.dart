import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseClientService {
  static final SupabaseClient _client = Supabase.instance.client;

  static SupabaseClient get client => _client;

 
  static Future<List<Map<String, dynamic>>> select(
    String table, {
    String? filtros,
    String? orderBy,
  }) async {
    var query = _client.from(table).select();

    
    return await query;
  }

  static Future<Map<String, dynamic>> insert(
    String table,
    Map<String, dynamic> data,
  ) async {
    final response = await _client.from(table).insert(data).select().single();
    return response;
  }
}
