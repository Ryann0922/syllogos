class ProofModel {
  String path; // local file path
  String? name;

  ProofModel({required this.path, this.name});

  Map toJson() => {'path': path, 'name': name};

  static ProofModel fromJson(Map m) =>
      ProofModel(path: m['path'], name: m['name']);
}
