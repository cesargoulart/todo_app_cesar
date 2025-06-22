// lib/services/label_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/label.dart';

class LabelService {
  final SupabaseClient _client = Supabase.instance.client;
  final String _labelsTable = 'todo_labels';
  final String _taskLabelsTable = 'todo_task_labels';

  // Get all available labels
  Future<List<Label>> getAllLabels() async {
    try {
      final response = await _client
          .from(_labelsTable)
          .select()
          .order('name', ascending: true);

      if (response.isEmpty) return [];
      
      return (response as List)
          .map((json) => Label.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error loading labels: $e');
      return [];
    }
  }

  // Create a new label
  Future<Label> createLabel(String name, String color) async {
    try {
      final response = await _client
          .from(_labelsTable)
          .insert({
            'name': name,
            'color': color,
          })
          .select()
          .single();
      
      return Label.fromJson(response);
    } catch (e) {
      print('Error creating label: $e');
      rethrow;
    }
  }

  // Update an existing label
  Future<Label> updateLabel(Label label) async {
    try {
      final response = await _client
          .from(_labelsTable)
          .update({
            'name': label.name,
            'color': label.color,
          })
          .eq('id', label.id!)
          .select()
          .single();
      
      return Label.fromJson(response);
    } catch (e) {
      print('Error updating label: $e');
      rethrow;
    }
  }

  // Delete a label
  Future<void> deleteLabel(String labelId) async {
    try {
      await _client.from(_labelsTable).delete().eq('id', labelId);
    } catch (e) {
      print('Error deleting label: $e');
      rethrow;
    }
  }

  // Add label to task
  Future<void> addLabelToTask(String taskId, String labelId) async {
    try {
      await _client.from(_taskLabelsTable).insert({
        'task_id': taskId,
        'label_id': labelId,
      });
    } catch (e) {
      print('Error adding label to task: $e');
      rethrow;
    }
  }

  // Remove label from task
  Future<void> removeLabelFromTask(String taskId, String labelId) async {
    try {
      await _client
          .from(_taskLabelsTable)
          .delete()
          .eq('task_id', taskId)
          .eq('label_id', labelId);
    } catch (e) {
      print('Error removing label from task: $e');
      rethrow;
    }
  }

  // Get labels for a specific task
  Future<List<Label>> getLabelsForTask(String taskId) async {
    try {
      final response = await _client
          .from(_taskLabelsTable)
          .select('''
            todo_labels (
              id,
              name,
              color,
              created_at,
              updated_at
            )
          ''')
          .eq('task_id', taskId);

      if (response.isEmpty) return [];
      
      return (response as List)
          .map((item) => Label.fromJson(item['todo_labels'] as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting labels for task: $e');
      return [];
    }
  }
}
