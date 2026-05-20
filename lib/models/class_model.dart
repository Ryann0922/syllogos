class ClassModel {
  String id;
  String name;
  bool hasYearLimit;
  int? yearLimit;
  double? target;

  ClassModel({
    required this.id,
    required this.name,
    this.hasYearLimit = false,
    this.yearLimit,
    this.target,
  });

  Map toJson() => {
    'id': id,
    'name': name,
    'hasYearLimit': hasYearLimit,
    'yearLimit': yearLimit,
    'target': target,
  };

  static ClassModel fromJson(Map m) => ClassModel(
    id: m['id'].toString(),
    name: m['name'] ?? '',
    hasYearLimit: m['hasYearLimit'] ?? false,
    yearLimit: m['yearLimit'],
    target: m['target'] != null
        ? (m['target'] is num
              ? (m['target'] as num).toDouble()
              : double.tryParse(m['target'].toString()))
        : null,
  );
}
