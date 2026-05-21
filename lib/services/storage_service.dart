import 'dart:io';

import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';

class StorageService {
  static late Box _classesBox;
  static late Box _entriesBox;
  static late Box _settingsBox;

  static Future<void> init() async {
    _classesBox = await Hive.openBox('classes');
    _entriesBox = await Hive.openBox('entries');
    _settingsBox = await Hive.openBox('settings');
  }

  // Settings
  static Map getSettings() {
    return Map.from(_settingsBox.toMap());
  }

  static Future<void> saveSetting(String key, dynamic value) async {
    await _settingsBox.put(key, value);
  }

  // Classes
  static Future<String> createClass(Map data) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    await _classesBox.put(id, data);
    return id;
  }

  static Future<void> updateClass(String id, Map data) async {
    await _classesBox.put(id, data);
  }

  static Future<void> deleteClass(String id) async {
    await _classesBox.delete(id);
  }

  static List<Map> getAllClasses() {
    return _classesBox.toMap().entries.map((e) {
      final m = Map<String, dynamic>.from(e.value as Map);
      m['id'] = e.key;
      return m;
    }).toList();
  }

  // Entries
  static Future<String> createEntry(Map data) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    await _entriesBox.put(id, data);
    return id;
  }

  /// 将外部选中的证明文件复制到应用文档目录，返回 proofs 列表（包含 path 和 name）
  static Future<List<Map>> saveProofFiles(List<String> srcPaths) async {
    final docDir = await getApplicationDocumentsDirectory();
    final proofs = <Map>[];
    for (final p in srcPaths) {
      try {
        final src = File(p);
        if (!await src.exists()) continue;
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${src.uri.pathSegments.last}';
        final dest = File('${docDir.path}/$fileName');
        await src.copy(dest.path);
        proofs.add({'path': dest.path, 'name': src.uri.pathSegments.last});
      } catch (e) {
        // ignore file copy errors for now
      }
    }
    return proofs;
  }

  /// Save proofs from FilePicker's PlatformFile list. Handles cases where
  /// `PlatformFile.path` may be null by falling back to `bytes` or `readStream`.
  static Future<List<Map>> saveProofPlatformFiles(
    List<PlatformFile> files,
  ) async {
    final docDir = await getApplicationDocumentsDirectory();
    final proofs = <Map>[];
    for (final pf in files) {
      try {
        if (pf.path == null && pf.bytes == null && pf.readStream == null) {
          continue;
        }

        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${pf.name}';
        final dest = File('${docDir.path}/$fileName');

        // 优先使用path
        if (pf.path != null) {
          final src = File(pf.path!);
          if (await src.exists()) {
            await src.copy(dest.path);
            proofs.add({'path': dest.path, 'name': pf.name});
            continue;
          }
        }

        // 其次使用bytes
        if (pf.bytes != null) {
          await dest.writeAsBytes(pf.bytes!);
          proofs.add({'path': dest.path, 'name': pf.name});
          continue;
        }

        // 最后使用readStream
        if (pf.readStream != null) {
          final sink = dest.openWrite();
          try {
            await for (final chunk in pf.readStream!) {
              sink.add(chunk);
            }
          } finally {
            await sink.close();
          }
          proofs.add({'path': dest.path, 'name': pf.name});
        }
      } catch (e) {
        print('Error saving proof file ${pf.name}: $e');
      }
    }
    return proofs;
  }

  static Future<void> updateEntry(String id, Map data) async {
    await _entriesBox.put(id, data);
  }

  static Future<void> deleteEntry(String id) async {
    await _entriesBox.delete(id);
  }

  static List<Map> getAllEntries() {
    return _entriesBox.toMap().entries.map((e) {
      final m = Map<String, dynamic>.from(e.value as Map);
      m['id'] = e.key;
      return m;
    }).toList();
  }

  static List<Map> getEntriesByClassId(String? classId) {
    final all = getAllEntries();
    return all.where((e) => e['classId'] == classId).toList();
  }

  /// 从条目中移除证明（根据证明 path），并尝试删除文件
  static Future<void> removeProofFromEntry(
    String entryId,
    String proofPath,
  ) async {
    final entry = _entriesBox.get(entryId);
    if (entry == null) return;
    final m = Map<String, dynamic>.from(entry as Map);
    final proofs = List.from(m['proofs'] ?? []);
    proofs.removeWhere((p) => p['path'] == proofPath);
    m['proofs'] = proofs;
    await _entriesBox.put(entryId, m);
    try {
      final f = File(proofPath);
      if (await f.exists()) await f.delete();
    } catch (e) {
      // ignore
    }
  }
}
