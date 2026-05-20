class EntryModel {
  String id;
  String name;
  String? classId;
  DateTime? date;
  List proofs; // list of ProofModel as Map
  bool settled;
  double? score;
  EntryModel({
    required this.id,
    required this.name,
    this.classId,
    this.date,
    this.proofs = const [],
    this.settled = false,
    this.score,
  });

  Map toJson() => {
    'id': id,
    'name': name,
    'classId': classId,
    'date': date?.toIso8601String(),
    'proofs': proofs,
    'settled': settled,
    'score': score,
  };

  static EntryModel fromJson(Map m) => EntryModel(
    id: m['id'].toString(),
    name: m['name'] ?? '',
    classId: m['classId'],
    date: m['date'] != null ? DateTime.parse(m['date']) : null,
    proofs: List.from(m['proofs'] ?? []),
    settled: m['settled'] ?? false,
    score: m['score'] != null
        ? (m['score'] is num
              ? (m['score'] as num).toDouble()
              : double.tryParse(m['score'].toString()))
        : null,
  );
}
