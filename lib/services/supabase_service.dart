// lib/services/supabase_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/todo_item.dart';

class SupabaseService {
  // Get a reference to the Supabase client
  final SupabaseClient _client = Supabase.instance.client;

  // IMPORTANT: This is where you define your table name.
  // This must match the table name in your Supabase dashboard.
  final String _tableName = 'todo_cesar';
  // Load all todos from Supabase (including recurring task instances)
  Future<List<ToDoItem>> loadTodos() async {
    try {
      // First generate any pending recurring task instances
      await generateRecurringTaskInstances();
      
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
      return [];    }
  }

  // Generate recurring task instances by calling the database function
  Future<void> generateRecurringTaskInstances() async {
    try {
      await _client.rpc('generate_recurring_task_instances');
    } catch (e) {
      print('Error generating recurring task instances: $e');
      // Don't rethrow - this shouldn't break the app if it fails
    }
  }  // Save a single todo to Supabase
  Future<ToDoItem> saveTodo(ToDoItem todo) async {
    try {
      final todoJson = todo.toJson();
      
      // Remove null ID to let Supabase generate it
      if (todoJson['id'] == null) {
        todoJson.remove('id');
      }
      
      // If this is a recurring task, ensure next occurrence is calculated
      if (todo.isRecurring && todo.dueDate != null && todo.recurrenceInterval != RecurrenceInterval.none) {
        if (todo.nextOccurrenceDate == null) {
          todo.nextOccurrenceDate = todo.calculateNextOccurrence();
        }
        todoJson['next_occurrence_date'] = todo.nextOccurrenceDate?.toIso8601String();
        
        // Debug logging
        print('Saving recurring task:');
        print('  isRecurring: ${todo.isRecurring}');
        print('  recurrenceInterval: ${todo.recurrenceInterval.value}');
        print('  dueDate: ${todo.dueDate}');
        print('  nextOccurrenceDate: ${todo.nextOccurrenceDate}');
        print('  todoJson next_occurrence_date: ${todoJson['next_occurrence_date']}');
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
  }// Save multiple todos to Supabase
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
      print('Error removing subtask: $e');      rethrow;
    }
  }

  // Get all recurring task instances for a specific original task
  Future<List<ToDoItem>> getRecurringTaskInstances(String originalTaskId) async {
    try {
      final response = await _client
          .from(_tableName)
          .select()
          .eq('original_recurring_task_id', originalTaskId)
          .order('due_date', ascending: true);

      if (response.isEmpty) return [];
      
      return (response as List)
          .map((json) => ToDoItem.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting recurring task instances: $e');
      return [];
    }
  }

  // Delete a recurring task and optionally its instances
  Future<void> deleteRecurringTask(String id, {bool deleteInstances = false}) async {
    try {
      if (deleteInstances) {
        // Delete all instances first
        await _client
            .from(_tableName)
            .delete()
            .eq('original_recurring_task_id', id);
      }
      
      // Delete the original recurring task
      await _client.from(_tableName).delete().eq('id', id);
    } catch (e) {
      print('Error deleting recurring task: $e');
      rethrow;
    }
  }

  // Update recurring task settings
  Future<ToDoItem> updateRecurringTask(ToDoItem todo) async {
    try {
      final todoJson = todo.toJson();
      
      // Recalculate next occurrence if settings changed
      if (todo.isRecurring && todo.dueDate != null) {
        todo.nextOccurrenceDate = todo.calculateNextOccurrence();
        todoJson['next_occurrence_date'] = todo.nextOccurrenceDate?.toIso8601String();
      }
      
      final response = await _client
          .from(_tableName)
          .update(todoJson)
          .eq('id', todo.id!)
          .select()
          .single();
      
      return ToDoItem.fromJson(response);
    } catch (e) {
      print('Error updating recurring task: $e');
      rethrow;
    }
  }
}