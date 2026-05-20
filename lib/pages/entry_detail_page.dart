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
  final _nameCtrl = TextEditingController();
  final _scoreCtrl = TextEditingController();
  DateTime? _date;
  bool _settled = false;
  List<Map> _proofs = [];
  String? _classId;
  List<Map> _classes = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final all = StorageService.getAllEntries();

    // 尝试通过 ID 精确查找
    try {
      entry = all.firstWhere(
        (e) => e['id'].toString() == widget.entryId,
        orElse: () => null,
      );
    } catch (e) {
      entry = null;
    }

    // 如果找不到，尝试数值比较
    if (entry == null && int.tryParse(widget.entryId) != null) {
      final entryId = int.parse(widget.entryId);
      entry = all.firstWhere(
        (e) =>
            (e['id'] is int ? e['id'] : int.tryParse(e['id'].toString())) ==
            entryId,
        orElse: () => null,
      );
    }

    if (entry != null) {
      _nameCtrl.text = entry!['name'] ?? '';
      _scoreCtrl.text = entry!['score']?.toString() ?? '';
      _classId = entry!['classId'];
      _date = entry!['date'] != null ? DateTime.parse(entry!['date']) : null;
      _settled = entry!['settled'] ?? false;
      _proofs = List.from(entry!['proofs'] ?? []);
    }
    _classes = StorageService.getAllClasses();
    setState(() {});
  }

  Future<void> _addProofs() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null && result.files.isNotEmpty) {
      final saved = await StorageService.saveProofPlatformFiles(result.files);
      _proofs.addAll(saved);
      setState(() {});
    }
  }

  Future<void> _removeProof(String path) async {
    await StorageService.removeProofFromEntry(widget.entryId, path);
    _proofs.removeWhere((p) => p['path'] == path);
    setState(() {});
  }

  Future<void> _save() async {
    final data = {
      'name': _nameCtrl.text.trim(),
      'classId': _classId,
      'date': _date?.toIso8601String(),
      'proofs': _proofs,
      'settled': _settled,
      'score': double.tryParse(_scoreCtrl.text),
    };
    await StorageService.updateEntry(widget.entryId, data);
    Navigator.pop(context);
  }

  Future<void> _deleteEntry() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
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

    return Scaffold(
      appBar: AppBar(title: const Text('条目详情'), elevation: 0),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 条目名称卡片
          Card(
            elevation: 0,
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
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      labelText: '名称',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _scoreCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: '分数（可选）',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          value: _classId,
                          decoration: InputDecoration(
                            labelText: '所属类',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('未分类'),
                            ),
                            ..._classes.map(
                              (c) => DropdownMenuItem(
                                value: c['id'].toString(),
                                child: Text(c['name'] ?? 'Unnamed'),
                              ),
                            ),
                          ],
                          onChanged: (v) => setState(() => _classId = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '日期',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _date != null
                                ? '${_date!.year}-${_date!.month.toString().padLeft(2, '0')}-${_date!.day.toString().padLeft(2, '0')}'
                                : '未选择',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      FilledButton.tonal(
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: _date ?? DateTime.now(),
                            firstDate: DateTime(1970),
                            lastDate: DateTime(2100),
                          );
                          if (d != null) setState(() => _date = d);
                        },
                        child: const Text('选择日期'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        value: _settled,
                        onChanged: (v) => setState(() => _settled = v ?? false),
                      ),
                      Text(
                        '已结清',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 证明文件卡片
          Card(
            elevation: 0,
            color: cs.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '证明文件',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: cs.primary,
                            ),
                      ),
                      FilledButton.icon(
                        onPressed: _addProofs,
                        icon: const Icon(Icons.add),
                        label: const Text('添加'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_proofs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24.0),
                      child: Center(
                        child: Text(
                          '暂无证明文件',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _proofs.length,
                      itemBuilder: (ctx, i) {
                        final p = _proofs[i];
                        final path = p['path']?.toString() ?? '';
                        final isImage =
                            path.toLowerCase().endsWith('.jpg') ||
                            path.toLowerCase().endsWith('.jpeg') ||
                            path.toLowerCase().endsWith('.png') ||
                            path.toLowerCase().endsWith('.gif');

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Card(
                            elevation: 0,
                            color: cs.surfaceContainerHighest,
                            child: ListTile(
                              leading: isImage
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
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
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(
                                        Icons.insert_drive_file,
                                        color: cs.onPrimaryContainer,
                                        size: 24,
                                      ),
                                    ),
                              title: Text(
                                p['name'] ?? path.split('/').last,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              trailing: IconButton(
                                icon: Icon(Icons.delete, color: cs.error),
                                onPressed: () => _removeProof(p['path']),
                              ),
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
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
