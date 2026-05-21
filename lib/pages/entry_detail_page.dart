import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
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

    final nameCtrl = TextEditingController(text: entry!['name'] ?? '');
    final nameFocus = FocusNode();
    final scoreCtrl = TextEditingController(
      text: entry!['score']?.toString() ?? '',
    );
    DateTime? selectedDate = entry!['date'] != null
        ? DateTime.parse(entry!['date'])
        : null;
    bool settled = entry!['settled'] ?? false;
    List<Map> proofs = List.from(entry!['proofs'] ?? []);
    String? selectedClassId = entry!['classId'];
    final classes = StorageService.getAllClasses();

    // 验证条目的类是否仍存在，不存在则置为未分类
    if (selectedClassId != null) {
      final classExists = classes.any(
        (c) => c['id'].toString() == selectedClassId.toString(),
      );
      if (!classExists) {
        selectedClassId = null;
      }
    }

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setD) {
          // 请求焦点
          WidgetsBinding.instance.addPostFrameCallback((_) {
            nameFocus.requestFocus();
          });

          return AlertDialog(
            title: const Text('编辑条目'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    focusNode: nameFocus,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: '名称'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: scoreCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: '分数（可选）',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          initialValue: selectedClassId,
                          decoration: const InputDecoration(labelText: '所属类'),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('未分类'),
                            ),
                            ...classes.map(
                              (c) => DropdownMenuItem(
                                value: c['id'].toString(),
                                child: Text(c['name'] ?? 'Unnamed'),
                              ),
                            ),
                          ],
                          onChanged: (v) => setD(() => selectedClassId = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        selectedDate != null
                            ? '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}'
                            : '未选择日期',
                      ),
                      TextButton(
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: selectedDate ?? DateTime.now(),
                            firstDate: DateTime(1970),
                            lastDate: DateTime(2100),
                          );
                          if (d != null) setD(() => selectedDate = d);
                        },
                        child: const Text('选择日期'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('是否结清'),
                      Checkbox(
                        value: settled,
                        onChanged: (v) => setD(() => settled = v ?? false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () async {
                          final result = await FilePicker.platform.pickFiles(
                            allowMultiple: true,
                          );
                          if (result != null && result.files.isNotEmpty) {
                            try {
                              final saved =
                                  await StorageService.saveProofPlatformFiles(
                                    result.files,
                                  );
                              setD(() => proofs.addAll(saved));
                            } catch (e) {
                              print('Error saving proof files: $e');
                            }
                          }
                        },
                        child: const Text('添加证明文件'),
                      ),
                      const SizedBox(width: 8),
                      Text('已添加 ${proofs.length} 个'),
                    ],
                  ),
                  if (proofs.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: proofs.asMap().entries.map((e) {
                        final idx = e.key;
                        final p = e.value;
                        final path = p['path']?.toString() ?? '';
                        final fileName = path.split('/').last;
                        return Chip(
                          label: Text(
                            fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onDeleted: () {
                            setD(() => proofs.removeAt(idx));
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () async {
                  final trimmedName = nameCtrl.text.trim();
                  if (trimmedName.isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('请输入条目名称')),
                    );
                    return;
                  }
                  final oldScore = (entry!['score'] is num)
                      ? (entry!['score'] as num).toDouble()
                      : double.tryParse(entry!['score']?.toString() ?? '') ??
                            0.0;
                  final newScore = double.tryParse(scoreCtrl.text) ?? 0.0;
                  final scoreDiff = newScore - oldScore;

                  // 检查分数上限（仅当改变分数或改变所属类时）
                  if (selectedClassId != null &&
                      (scoreDiff != 0 ||
                          selectedClassId.toString() !=
                              entry!['classId'].toString())) {
                    final selectedClass = classes.firstWhere(
                      (c) => c['id'].toString() == selectedClassId,
                      orElse: () => {},
                    );
                    if (selectedClass.isNotEmpty &&
                        selectedClass['scoreLimit'] != null) {
                      final scoreLimit = (selectedClass['scoreLimit'] as num)
                          .toDouble();

                      // 计算该类的其他条目的总分（不含当前条目）
                      final allEntries = StorageService.getAllEntries();
                      final classEntries = allEntries
                          .where(
                            (e) =>
                                e['classId'].toString() == selectedClassId &&
                                e['id'].toString() != widget.entryId,
                          )
                          .toList();
                      double currentSum = 0;
                      for (final e in classEntries) {
                        final s = (e['score'] is num)
                            ? (e['score'] as num).toDouble()
                            : double.tryParse(e['score']?.toString() ?? '') ??
                                  0.0;
                        currentSum += s;
                      }
                      final newSum = currentSum + newScore;
                      if (newSum > scoreLimit) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '该类的分数将超过上限 $scoreLimit。当前: $currentSum，新分数: $newScore，总计: $newSum',
                            ),
                          ),
                        );
                        return;
                      }
                    }
                  }

                  final data = {
                    'name': nameCtrl.text.trim(),
                    'classId': selectedClassId,
                    'date': selectedDate?.toIso8601String(),
                    'proofs': proofs,
                    'settled': settled,
                    'score': double.tryParse(scoreCtrl.text),
                  };
                  await StorageService.updateEntry(widget.entryId, data);
                  Navigator.pop(ctx);
                  _load();
                },
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    ).then((_) {
      nameCtrl.dispose();
      scoreCtrl.dispose();
      nameFocus.dispose();
    });
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

  @override
  Widget build(BuildContext context) {
    if (entry == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('条目详情')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('条目不存在或已被删除'),
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
                            onTap: isImage
                                ? () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            ImagePreviewPage(path: path),
                                      ),
                                    );
                                  }
                                : null,
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
                                    if (isImage)
                                      Icon(
                                        Icons.image,
                                        color: cs.primary,
                                        size: 20,
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
