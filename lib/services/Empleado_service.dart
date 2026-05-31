import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:taller_rodriguez/models/empleado_back.dart';

class EmpleadoService {
  static final _supabase = Supabase.instance.client;
  static const _table = 'empleados';

  static Future<List<Empleado>> getAll() async {
    final response = await _supabase
        .from(_table)
        .select()
        .eq('activo', true)
        .order('id', ascending: true);
    return (response as List).map((json) => Empleado.fromJson(json)).toList();
  }

  static Future<Empleado> create(Empleado empleado) async {
    final response = await _supabase
        .from(_table)
        .insert({...empleado.toJson(), 'activo': true})
        .select()
        .single();
    return Empleado.fromJson(response);
  }

  static Future<Empleado> update(Empleado empleado) async {
    assert(empleado.id != null, 'El empleado debe tener un id para actualizar');
    final response = await _supabase
        .from(_table)
        .update(empleado.toJson())
        .eq('id', empleado.id!)
        .select()
        .single();
    return Empleado.fromJson(response);
  }

  static Future<void> delete(int id) async {
    await _supabase.from(_table).update({'activo': false}).eq('id', id);
  }
}