import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syllogos/services/storage_service.dart';

class ExportService {
  /// 导出全部数据为 zip，结构：className/entryId/entry.json + proof files
  static Future<File> exportAllToZip({String? filename}) async {
    final classes = StorageService.getAllClasses();
    final entries = StorageService.getAllEntries();

    final tempDir = await getTemporaryDirectory();
    final encoder = ZipFileEncoder();
    final outPath = '${tempDir.path}/${filename ?? 'syllogos_export'}.zip';
    encoder.create(outPath);

    for (final c in classes) {
      final className = (c['name'] ?? 'unnamed').toString();
      final classDir = '${tempDir.path}/$className';
      Directory(classDir).createSync(recursive: true);

      final classEntries = entries.where((e) => e['classId'] == c['id']);
      for (final e in classEntries) {
        final entryDir = '$classDir/${e['id']}';
        Directory(entryDir).createSync(recursive: true);
        final jsonFile = File('$entryDir/entry.json');
        jsonFile.writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(e),
        );

        final proofs = List.from(e['proofs'] ?? []);
        for (final p in proofs) {
          final path = p['path'];
          if (path == null) continue;
          final src = File(path.toString());
          if (await src.exists()) {
            final dest = '$entryDir/${src.uri.pathSegments.last}';
            await src.copy(dest);
          }
        }
        encoder.addDirectory(Directory(entryDir));
      }
    }

    // 未分类
    final unclassified = entries.where(
      (e) => e['classId'] == null || e['classId'] == '',
    );
    if (unclassified.isNotEmpty) {
      final dir = '${tempDir.path}/Uncategorized';
      Directory(dir).createSync(recursive: true);
      for (final e in unclassified) {
        final entryDir = '$dir/${e['id']}';
        Directory(entryDir).createSync(recursive: true);
        final jsonFile = File('$entryDir/entry.json');
        jsonFile.writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(e),
        );
        final proofs = List.from(e['proofs'] ?? []);
        for (final p in proofs) {
          final path = p['path'];
          if (path == null) continue;
          final src = File(path.toString());
          if (await src.exists()) {
            final dest = '$entryDir/${src.uri.pathSegments.last}';
            await src.copy(dest);
          }
        }
        encoder.addDirectory(Directory(entryDir));
      }
    }

    encoder.close();
    return File(outPath);
  }
}
