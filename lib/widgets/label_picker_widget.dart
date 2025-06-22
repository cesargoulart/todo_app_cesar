// lib/widgets/label_picker_widget.dart

import 'package:flutter/material.dart';
import '../models/label.dart';
import '../services/label_service.dart';

class LabelPickerWidget extends StatefulWidget {
  final List<Label> selectedLabels;
  final Function(List<Label>) onLabelsChanged;

  const LabelPickerWidget({
    super.key,
    required this.selectedLabels,
    required this.onLabelsChanged,
  });

  @override
  State<LabelPickerWidget> createState() => _LabelPickerWidgetState();
}

class _LabelPickerWidgetState extends State<LabelPickerWidget> {
  final LabelService _labelService = LabelService();
  List<Label> _allLabels = [];
  List<Label> _selectedLabels = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedLabels = List.from(widget.selectedLabels);
    _loadLabels();
  }

  Future<void> _loadLabels() async {
    setState(() => _isLoading = true);
    try {
      _allLabels = await _labelService.getAllLabels();
    } catch (e) {
      print('Error loading labels: $e');
    }
    setState(() => _isLoading = false);
  }

  void _toggleLabel(Label label) {
    setState(() {
      if (_selectedLabels.any((l) => l.id == label.id)) {
        _selectedLabels.removeWhere((l) => l.id == label.id);
      } else {
        _selectedLabels.add(label);
      }
    });
    widget.onLabelsChanged(_selectedLabels);
  }

  void _showCreateLabelDialog() {
    final TextEditingController nameController = TextEditingController();
    Color selectedColor = Colors.blue;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Create New Label'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Label Name',
                      border: OutlineInputBorder(),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 20),
                  const Text('Choose Color:'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      Colors.red,
                      Colors.pink,
                      Colors.purple,
                      Colors.blue,
                      Colors.cyan,
                      Colors.teal,
                      Colors.green,
                      Colors.orange,
                      Colors.brown,
                      Colors.grey,
                    ].map((color) {
                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            selectedColor = color;
                          });
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: selectedColor == color
                                ? Border.all(color: Colors.black, width: 3)
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('CANCEL'),
                ),
                TextButton(
                  onPressed: () async {
                    if (nameController.text.isNotEmpty) {
                      try {
                        final newLabel = await _labelService.createLabel(
                          nameController.text,
                          '#${selectedColor.value.toRadixString(16).substring(2)}',
                        );
                        await _loadLabels();
                        Navigator.of(context).pop();
                        
                        // Auto-select the new label
                        _toggleLabel(newLabel);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error creating label: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('CREATE'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Color _parseColor(String colorString) {
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Labels',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: _showCreateLabelDialog,
              icon: const Icon(Icons.add),
              label: const Text('New'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_allLabels.isEmpty)
          const Text('No labels available. Create your first label!')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allLabels.map((label) {
              final isSelected = _selectedLabels.any((l) => l.id == label.id);
              return FilterChip(
                label: Text(label.name),
                selected: isSelected,
                onSelected: (_) => _toggleLabel(label),
                backgroundColor: _parseColor(label.color).withOpacity(0.2),
                selectedColor: _parseColor(label.color).withOpacity(0.6),
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.black,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}
