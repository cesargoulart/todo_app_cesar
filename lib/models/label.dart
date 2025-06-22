// lib/models/label.dart

class Label {
  String? id;
  String name;
  String color;
  DateTime? createdAt;
  DateTime? updatedAt;

  Label({
    this.id,
    required this.name,
    required this.color,
    this.createdAt,
    this.updatedAt,
  });

  // Method to convert a Label instance to a JSON map.
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'name': name,
      'color': color,
    };
    
    if (id != null) {
      data['id'] = id;
    }
    
    if (createdAt != null) {
      data['created_at'] = createdAt!.toIso8601String();
    }
    
    if (updatedAt != null) {
      data['updated_at'] = updatedAt!.toIso8601String();
    }
    
    return data;
  }

  // Factory constructor to create a Label from a JSON map.
  factory Label.fromJson(Map<String, dynamic> json) {
    return Label(
      id: json['id'],
      name: json['name'],
      color: json['color'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Label && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Label(id: $id, name: $name, color: $color)';
}
