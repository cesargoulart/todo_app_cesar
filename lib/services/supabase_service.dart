// lib/services/supabase_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/todo_item.dart';

class SupabaseService {
  // Get a reference to the Supabase client
  final SupabaseClient _client = Supabase.instance.client;

  // IMPORTANT: This is where you define your table name.
  // This must match the table name in your Supabase dashboard.
  final String _tableName = 'todo_cesar';

  // Load all todos from Supabase
  Future<List<ToDoItem>> loadTodos() async {
    try {
      final response = await _client
          .from(_tableName)
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
  }  // Save a single todo to Supabase
  Future<ToDoItem> saveTodo(ToDoItem todo) async {
    try {
      final todoJson = todo.toJson();
      
      // Remove null ID to let Supabase generate it
      if (todoJson['id'] == null) {
        todoJson.remove('id');
      }
      
      final response = await _client
          .from(_tableName)
          .upsert(todoJson)
          .select()
          .single();
      
      // Return the todo with the database-generated ID
      return ToDoItem.fromJson(response);
    } catch (e) {
      print('Error saving todo: $e');
      rethrow;
    }
  }  // Save multiple todos to Supabase
  Future<List<ToDoItem>> saveTodos(List<ToDoItem> todos) async {
    if (todos.isEmpty) return [];
    
    try {
      // Convert all todos to JSON for batch insert/update
      final todoJsonList = todos.map((todo) {
        final todoJson = todo.toJson();
        // Remove null ID to let Supabase generate it
        if (todoJson['id'] == null) {
          todoJson.remove('id');
        }
        return todoJson;
      }).toList();
      
      // Use upsert to insert new todos or update existing ones
      final response = await _client
          .from(_tableName)
          .upsert(todoJsonList)
          .select();
      
      // Return the todos with database-generated IDs
      return (response as List)
          .map((json) => ToDoItem.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error saving todos: $e');
      rethrow;
    }
  }

  // Delete a todo from Supabase
  Future<void> deleteTodo(String id) async {
    try {
      await _client.from(_tableName).delete().eq('id', id);
    } catch (e) {
      print('Error deleting todo: $e');
      rethrow;
    }
  }

  // Update a todo's status
  Future<void> updateTodoStatus(String id, bool isDone) async {
    try {
      await _client
          .from(_tableName)
          .update({'is_done': isDone})
          .eq('id', id);
    } catch (e) {
      print('Error updating todo status: $e');
      rethrow;
    }
  }
  // Add a subtask to a parent todo
  Future<void> addSubtask(ToDoItem parentTodo, ToDoItem subtask) async {
    try {
      // Set the parent_id for the subtask (only if parent has an ID)
      if (parentTodo.id != null) {
        subtask.parentId = parentTodo.id;
      }
      
      // Save the subtask to the database
      await saveTodo(subtask);
      
      // Update the parent's subtasks array in memory
      parentTodo.addSubtask(subtask);
      
      // Update the parent in the database with the new subtasks
      await saveTodo(parentTodo);
    } catch (e) {
      print('Error adding subtask: $e');
      rethrow;
    }
  }

  // Remove a subtask
  Future<void> removeSubtask(ToDoItem parentTodo, String subtaskId) async {
    try {
      // Delete the subtask from the database
      await deleteTodo(subtaskId);
      
      // Remove from parent's subtasks array in memory
      parentTodo.removeSubtask(subtaskId);
      
      // Update the parent in the database
      await saveTodo(parentTodo);
    } catch (e) {
      print('Error removing subtask: $e');
      rethrow;
    }
  }
}