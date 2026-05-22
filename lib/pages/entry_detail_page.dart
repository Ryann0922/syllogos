import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syllogos/pages/entry_edit_page.dart';
import 'package:syllogos/pages/image_preview_page.dart';
import 'package:syllogos/services/storage_service.dart';

class EntryDetailPage extends StatefulWidget {
  final String entryId;
  const EntryDetailPage({super.key, required this.entryId});

  @override
  State<EntryDetailPage> createState() => _EntryDetailPageState();
}

class _EntryDetailPageState extends State<EntryDetailPage> {
  Map? entry;
  String? _classNameDisplay;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final all = StorageService.getAllEntries();

    // 尝试通过 ID 精确查找
    final foundByString = all
        .where((e) => e['id'].toString() == widget.entryId)
        .toList();
    entry = foundByString.isNotEmpty ? foundByString.first : null;

    // 如果找不到，尝试数值比较
    if (entry == null && int.tryParse(widget.entryId) != null) {
      final entryId = int.parse(widget.entryId);
      final foundByNumeric = all
          .where(
            (e) =>
                (e['id'] is int ? e['id'] : int.tryParse(e['id'].toString())) ==
                entryId,
          )
          .toList();
      entry = foundByNumeric.isNotEmpty ? foundByNumeric.first : null;
    }

    if (entry != null) {
      final classId = entry!['classId'];
      if (classId != null) {
        final classes = StorageService.getAllClasses();
        final foundClass = classes
            .where((c) => c['id'].toString() == classId.toString())
            .toList();
        _classNameDisplay = foundClass.isNotEmpty
            ? foundClass.first['name']
            : '未分类';
      } else {
        _classNameDisplay = '未分类';
      }
    }
    setState(() {});
  }

  Future<void> _showEditDialog() async {
    if (entry == null) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EntryEditPage(
          entry: entry!,
          entryId: widget.entryId,
        ),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _deleteEntry() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这个条目吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await StorageService.deleteEntry(widget.entryId);
      Navigator.pop(context);
    }
  }

  Future<void> _saveProofFile(Map proof) async {
    final srcPath = proof['path']?.toString();
    if (srcPath == null) return;
    final src = File(srcPath);
    if (!await src.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('文件不存在')),
        );
      }
      return;
    }
    final fileName = proof['name']?.toString() ?? srcPath.split('/').last;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final destPath = '${dir.path}/$fileName';
      await src.copy(destPath);
      // try to use file_picker saveFile for user-selected location
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: '保存文件',
        fileName: fileName,
      );
      if (savePath != null) {
        await src.copy(savePath);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('文件已保存')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }

  String _formatDateTime(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final y = dt.year;
      final mo = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      final h = dt.hour.toString().padLeft(2, '0');
      final mi = dt.minute.toString().padLeft(2, '0');
      final s = dt.second.toString().padLeft(2, '0');
      return '$y-$mo-$d $h:$mi:$s';
    } catch (_) {
      return iso;
    }
  }

  bool _isUrl(String text) {
    final uri = Uri.tryParse(text);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  @override
  Widget build(BuildContext context) {
    if (entry == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('条目详情')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline,
                  size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              const Text('条目不存在或已被删除'),
            ],
          ),
        ),
      );
    }
    final cs = Theme.of(context).colorScheme;
    final proofs = List<Map>.from(entry!['proofs'] ?? []);

    return Scaffold(
      appBar: AppBar(title: const Text('条目详情'), elevation: 0),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 基本信息卡片
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            color: cs.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '基本信息',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '名称',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              entry!['name'] ?? '无',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '分数',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            entry!['score'] != null
                                ? '${entry!['score']}'
                                : '无',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '所属类',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _classNameDisplay ?? '未分类',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '状态',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                          const SizedBox(height: 4),
                          if (entry!['settled'] == true)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: cs.tertiaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '已结清',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onTertiaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          else
                            Text(
                              '未结清',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '日期',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry!['date'] != null
                            ? DateTime.parse(
                                entry!['date'],
                              ).toString().split(' ').first
                            : '无',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '修改时间',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry!['createdAt'] != null
                            ? _formatDateTime(entry!['createdAt'])
                            : '无',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // 活动信息卡片
          if ((entry!['activityInfo'] as List?)?.isNotEmpty == true)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              color: cs.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '活动信息',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...List<String>.from(entry!['activityInfo'] ?? []).map(
                      (text) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _isUrl(text)
                            ? GestureDetector(
                                onTap: () async {
                                  final uri = Uri.tryParse(text);
                                  if (uri != null) {
                                    try {
                                      await launchUrl(
                                        uri,
                                        mode:
                                            LaunchMode.externalApplication,
                                      );
                                    } catch (_) {}
                                  }
                                },
                                child: Text(
                                  text,
                                  style: TextStyle(
                                    color: cs.primary,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              )
                            : Text(text),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),

          // 证明文件卡片
          if (proofs.isNotEmpty)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              color: cs.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '证明文件',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: proofs.length,
                      itemBuilder: (ctx, i) {
                        final p = proofs[i];
                        final path = p['path']?.toString() ?? '';
                        final isImage =
                            path.toLowerCase().endsWith('.jpg') ||
                            path.toLowerCase().endsWith('.jpeg') ||
                            path.toLowerCase().endsWith('.png') ||
                            path.toLowerCase().endsWith('.gif');

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: GestureDetector(
                            onTap: () {
                              if (isImage) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ImagePreviewPage(path: path),
                                  ),
                                );
                              } else {
                                // 使用系统应用打开 PDF 等文件
                                OpenFilex.open(path).then((result) {
                                  if (result.type != ResultType.done &&
                                      context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '无法打开文件: ${result.message}',
                                        ),
                                      ),
                                    );
                                  }
                                });
                              }
                            },
                            child: Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              color: cs.surfaceContainerHighest,
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  children: [
                                    isImage
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            child: Image.file(
                                              File(path),
                                              width: 48,
                                              height: 48,
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        : Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              color: cs.primaryContainer,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Icon(
                                              Icons.insert_drive_file,
                                              color: cs.onPrimaryContainer,
                                              size: 24,
                                            ),
                                          ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p['name'] ?? path.split('/').last,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodyMedium,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            path.split('/').last,
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                  color: cs.onSurfaceVariant,
                                                ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.download,
                                        color: cs.primary,
                                        size: 20,
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 36,
                                        minHeight: 36,
                                      ),
                                      padding: EdgeInsets.zero,
                                      tooltip: '保存到本地',
                                      onPressed: () => _saveProofFile(p),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.of(context).viewPadding.bottom,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _deleteEntry,
                icon: const Icon(Icons.delete),
                label: const Text('删除'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _showEditDialog,
                icon: const Icon(Icons.edit),
                label: const Text('编辑'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
