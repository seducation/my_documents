enum FileSystemItemType { document, folder }

class FileSystemItem {
  final String id;
  final String name;
  final FileSystemItemType type;
  final String? parentId; // null means root
  final DateTime lastModified;
  final DateTime createdAt;

  FileSystemItem({
    required this.id,
    required this.name,
    required this.type,
    this.parentId,
    required this.lastModified,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'parentId': parentId,
      'lastModified': lastModified.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory FileSystemItem.fromJson(Map<String, dynamic> json) {
    return FileSystemItem(
      id: json['id'] as String,
      name: json['name'] as String,
      type: FileSystemItemType.values
          .firstWhere((e) => e.name == json['type'] as String),
      parentId: json['parentId'] as String?,
      lastModified: DateTime.parse(json['lastModified'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  FileSystemItem copyWith({
    String? name,
    String? parentId,
    DateTime? lastModified,
  }) {
    return FileSystemItem(
      id: id,
      name: name ?? this.name,
      type: type,
      parentId: parentId ?? this.parentId,
      lastModified: lastModified ?? this.lastModified,
      createdAt: createdAt,
    );
  }
}
