class Template {
  final String id;
  final String name;
  final String description;
  final String prompt;
  final bool isDefault;

  Template({
    required this.id,
    required this.name,
    required this.description,
    required this.prompt,
    this.isDefault = false,
  });

  Template copyWith({
    String? id,
    String? name,
    String? description,
    String? prompt,
    bool? isDefault,
  }) {
    return Template(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      prompt: prompt ?? this.prompt,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  factory Template.fromJson(Map<String, dynamic> json) {
    return Template(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      prompt: json['prompt'] as String,
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'prompt': prompt,
      'isDefault': isDefault,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Template && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}