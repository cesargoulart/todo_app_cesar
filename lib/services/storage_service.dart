import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/todo_item.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();
  
  SupabaseClient get _client => Supabase.instance.client;
  
  Future<List<ToDoItem>> loadTodos() async {
    try {
      final response = await _client
          .from('todos')
          .select()
          .order('due_date', ascending: true);

      if (response.isEmpty) return [];
      return (response as List)
          .map((json) => ToDoItem.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error loading todos: $e');
      return [];
    }
  }
  Future<void> saveTodo(ToDoItem todo) async {
    await _client.from('todos').upsert(todo.toJson());
  }

  Future<void> saveTodos(List<ToDoItem> todos) async {
    if (todos.isEmpty) return;
    
    // Convert all todos to JSON for batch insert/update
    final todoJsonList = todos.map((todo) => todo.toJson()).toList();
    
    // Use upsert to insert new todos or update existing ones
    await _client.from('todos').upsert(todoJsonList);
  }

  Future<void> deleteTodo(String id) async {
    await _client.from('todos').delete().eq('id', id);
  }
}