import 'dart:io';

import 'package:flutter/material.dart';
import 'package:syllogos/pages/entry_detail_page.dart';
import 'package:syllogos/services/storage_service.dart';

class ClassDetailPage extends StatefulWidget {
  final String? classId;
  final String title;
  const ClassDetailPage({
    super.key,
    required this.classId,
    required this.title,
  });

  @override
  State<ClassDetailPage> createState() => _ClassDetailPageState();
}

class _ClassDetailPageState extends State<ClassDetailPage> {
  List<Map> entries = [];
  Map? classInfo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    entries = StorageService.getEntriesByClassId(widget.classId);
    if (widget.classId != null) {
      final all = StorageService.getAllClasses();
      classInfo = all.firstWhere(
        (c) => c['id'].toString() == widget.classId,
        orElse: () => <String, dynamic>{},
      );
      if (classInfo != null && classInfo!.isEmpty) classInfo = null;
    } else {
      classInfo = null;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title),
            if (classInfo != null && classInfo!['target'] != null)
              Text(
                '目标：${classInfo!['target']}',
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        actions: [
          if (widget.classId != null)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final nameCtrl = TextEditingController(
                  text: classInfo?['name'] ?? '',
                );
                bool hasYearLimit = classInfo?['hasYearLimit'] ?? false;
                final yearCtrl = TextEditingController(
                  text: classInfo?['yearLimit']?.toString() ?? '',
                );
                final targetCtrl = TextEditingController(
                  text: classInfo?['target']?.toString() ?? '',
                );
                await showDialog(
                  context: context,
                  builder: (ctx) => StatefulBuilder(
                    builder: (c, setD) {
                      return AlertDialog(
                        title: const Text('编辑类'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: nameCtrl,
                              decoration: const InputDecoration(
                                labelText: '名称',
                              ),
                            ),
                            Row(
                              children: [
                                const Text('是否有学年上限'),
                                Checkbox(
                                  value: hasYearLimit,
                                  onChanged: (v) =>
                                      setD(() => hasYearLimit = v ?? false),
                                ),
                              ],
                            ),
                            if (hasYearLimit)
                              TextField(
                                controller: yearCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: '学年上限（年）',
                                ),
                              ),
                            TextField(
                              controller: targetCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: '目标分（可选）',
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('取消'),
                          ),
                          TextButton(
                            onPressed: () async {
                              final yearLimit = hasYearLimit
                                  ? int.tryParse(yearCtrl.text)
                                  : null;
                              final target = double.tryParse(targetCtrl.text);
                              await StorageService.updateClass(
                                widget.classId!,
                                {
                                  'name': nameCtrl.text.trim(),
                                  'hasYearLimit': hasYearLimit,
                                  'yearLimit': yearLimit,
                                  'target': target,
                                },
                              );
                              Navigator.pop(ctx);
                              _load();
                            },
                            child: const Text('保存'),
                          ),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
        ],
      ),
      body: entries.isEmpty
          ? const Center(child: Text('暂无条目'))
          : ListView.separated(
              itemCount: entries.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final e = entries[i];
                Widget? leading;
                final proofs = List.from(e['proofs'] ?? []);
                if (proofs.isNotEmpty) {
                  final p = proofs.first;
                  final path = p['path']?.toString() ?? '';
                  if (path.toLowerCase().endsWith('.jpg') ||
                      path.toLowerCase().endsWith('.jpeg') ||
                      path.toLowerCase().endsWith('.png') ||
                      path.toLowerCase().endsWith('.gif')) {
                    leading = ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.file(
                        File(path),
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                      ),
                    );
                  } else {
                    leading = const Icon(Icons.insert_drive_file);
                  }
                } else {
                  leading = const Icon(Icons.note);
                }

                final score = (e['score'] is num)
                    ? (e['score'] as num).toDouble()
                    : double.tryParse(e['score']?.toString() ?? '');

                return ListTile(
                  leading: leading,
                  title: Text(e['name'] ?? 'Unnamed'),
                  subtitle: Text(
                    '${e['date'] ?? ''}${score != null ? ' · 分数：${score.toStringAsFixed(2)}' : ''}',
                  ),
                  trailing: e['settled'] == true
                      ? Icon(Icons.check_circle,
                          color: Theme.of(ctx).colorScheme.tertiary)
                      : null,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            EntryDetailPage(entryId: e['id'].toString()),
                      ),
                    );
                    _load();
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // 新建条目（留给上层实现）
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
