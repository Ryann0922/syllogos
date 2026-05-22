import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syllogos/services/storage_service.dart';

class ExportService {
  /// 导出全部数据为 zip，结构：className/entryId/entry.json + proof files
  static Future<File> exportAllToZip({String? filename}) async {
    return exportToZip(filename: filename);
  }

  /// 按学年筛选导出。schoolYearStarts 为空则导出全部
  static Future<File> exportToZip({
    String? filename,
    List<int>? schoolYearStarts,
    int startMonth = 9,
  }) async {
    final classes = StorageService.getAllClasses();
    final allEntries = StorageService.getAllEntries();

    // 按学年筛选
    var entries = allEntries;
    if (schoolYearStarts != null && schoolYearStarts.isNotEmpty) {
      entries = allEntries.where((e) {
        final sy = StorageService.getEntrySchoolYearStart(e, startMonth);
        return sy != null && schoolYearStarts.contains(sy);
      }).toList();
    }

    final tempDir = await getTemporaryDirectory();
    final exportDir = Directory('${tempDir.path}/syllogos_export_data');
    if (exportDir.existsSync()) exportDir.deleteSync(recursive: true);
    exportDir.createSync();

    final outPath = '${tempDir.path}/${filename ?? 'syllogos_export'}.zip';
    final encoder = ZipFileEncoder();
    encoder.create(outPath);

    for (final c in classes) {
      final className = (c['name'] ?? 'unnamed').toString();
      final classEntries = entries.where((e) => e['classId'] == c['id']);
      for (final e in classEntries) {
        final entryId = e['id'].toString();
        final entryDir = '${exportDir.path}/$className/$entryId';
        Directory(entryDir).createSync(recursive: true);
        // entry.json
        File('$entryDir/entry.json').writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(e),
        );
        // 证明文件
        final proofs = List.from(e['proofs'] ?? []);
        for (final p in proofs) {
          final path = p['path'];
          if (path == null) continue;
          final src = File(path.toString());
          if (await src.exists()) {
            await src.copy('$entryDir/${src.uri.pathSegments.last}');
          }
        }
      }
    }

    // 未分类
    final unclassified = entries.where(
      (e) => e['classId'] == null || e['classId'] == '',
    );
    for (final e in unclassified) {
      final entryId = e['id'].toString();
      final entryDir = '${exportDir.path}/Uncategorized/$entryId';
      Directory(entryDir).createSync(recursive: true);
      File('$entryDir/entry.json').writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(e),
      );
      final proofs = List.from(e['proofs'] ?? []);
      for (final p in proofs) {
        final path = p['path'];
        if (path == null) continue;
        final src = File(path.toString());
        if (await src.exists()) {
          await src.copy('$entryDir/${src.uri.pathSegments.last}');
        }
      }
    }

    // 添加整个目录树，保留 ClassName/entryId/ 层级结构
    encoder.addDirectory(exportDir);
    encoder.close();
    // 清理临时文件
    exportDir.deleteSync(recursive: true);
    return File(outPath);
  }

  /// 从 ZIP 文件导入数据
  static Future<int> importFromZip(String zipPath) async {
    final bytes = File(zipPath).readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);
    final docDir = await getApplicationDocumentsDirectory();
    int importCount = 0;

    // 按 entryId 分组：找到每个 entryId 下的 entry.json 和证明文件
    final Map<String, Map<String, dynamic>> entryJsons = {};
    final Map<String, List<String>> entryProofs = {};

    for (final file in archive) {
      if (!file.isFile) continue;
      final path = file.name;
      final parts = path.split('/');
      // 路径格式：ClassName/entryId/entry.json 或 ClassName/entryId/filename
      if (parts.length < 3) continue;
      final entryId = parts[parts.length - 2];

      if (parts.last == 'entry.json') {
        final jsonStr = utf8.decode(file.content as List<int>);
        entryJsons[entryId] =
            json.decode(jsonStr) as Map<String, dynamic>;
      } else {
        entryProofs.putIfAbsent(entryId, () => []);
        // 保存证明文件到文档目录
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${parts.last}';
        final destPath = '${docDir.path}/$fileName';
        File(destPath).writeAsBytesSync(file.content as List<int>);
        entryProofs[entryId]!.add(destPath);
      }
    }

    for (final entryId in entryJsons.keys) {
      final data = entryJsons[entryId]!;
      // 更新证明路径
      final savedProofs = <Map>[];
      final proofPaths = entryProofs[entryId] ?? [];
      final oldProofs = List<Map>.from(data['proofs'] ?? []);
      for (int i = 0; i < oldProofs.length && i < proofPaths.length; i++) {
        savedProofs.add({
          'path': proofPaths[i],
          'name': oldProofs[i]['name'] ?? proofPaths[i].split('/').last,
        });
      }
      data['proofs'] = savedProofs;
      data.remove('id');
      data.remove('createdAt');
      data['createdAt'] = DateTime.now().toIso8601String();
      // 如果导入的数据里有 activityInfo 且为 null，去掉
      if (data['activityInfo'] == null) data.remove('activityInfo');

      await StorageService.createEntry(data);
      importCount++;
    }

    return importCount;
  }
}
