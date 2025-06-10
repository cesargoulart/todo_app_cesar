// lib/services/storage_service.dart

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/todo_item.dart';

class StorageService {
  // The key we'll use to store our to-do list in shared_preferences.
  static const String _todosKey = 'todos';

  // Method to save the list of ToDoItems.
  Future<void> saveTodos(List<ToDoItem> todos) async {
    // 1. Get the instance of SharedPreferences.
    final prefs = await SharedPreferences.getInstance();

    // 2. Convert the list of ToDoItem objects to a list of JSON maps.
    List<Map<String, dynamic>> todosAsJson =
        todos.map((todo) => todo.toJson()).toList();

    // 3. Encode the list of maps into a single JSON string.
    String todosAsString = jsonEncode(todosAsJson);

    // 4. Save the string to shared_preferences.
    await prefs.setString(_todosKey, todosAsString);
  }

  // Method to load the list of ToDoItems.
  Future<List<ToDoItem>> loadTodos() async {
    // 1. Get the instance of SharedPreferences.
    final prefs = await SharedPreferences.getInstance();

    // 2. Try to get the saved string. It might be null if it's the first time.
    final String? todosAsString = prefs.getString(_todosKey);

    // 3. If there's no saved data, return an empty list.
    if (todosAsString == null) {
      return [];
    }

    // 4. Decode the string back into a list of JSON maps.
    List<dynamic> todosAsJson = jsonDecode(todosAsString);

    // 5. Convert the list of maps back into a list of ToDoItem objects.
    List<ToDoItem> todos =
        todosAsJson.map((json) => ToDoItem.fromJson(json)).toList();

    return todos;
  }
}
