class CategoryModel {
  final int? id;
  final String name;
  final String colorHex;
  final int iconCode;

  const CategoryModel({
    this.id,
    required this.name,
    required this.colorHex,
    required this.iconCode,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'color_hex': colorHex,
      'icon_code': iconCode,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      colorHex: map['color_hex'] as String,
      iconCode: map['icon_code'] as int,
    );
  }

  CategoryModel copyWith({
    int? id,
    String? name,
    String? colorHex,
    int? iconCode,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      iconCode: iconCode ?? this.iconCode,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          colorHex == other.colorHex &&
          iconCode == other.iconCode;

  @override
  int get hashCode =>
      id.hashCode ^ name.hashCode ^ colorHex.hashCode ^ iconCode.hashCode;

  @override
  String toString() =>
      'CategoryModel(id: $id, name: $name, colorHex: $colorHex, iconCode: $iconCode)';
}
