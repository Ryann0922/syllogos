import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:syllogos/services/storage_service.dart';

class EntryCreatePage extends StatefulWidget {
  const EntryCreatePage({super.key});

  @override
  State<EntryCreatePage> createState() => _EntryCreatePageState();
}

class _EntryCreatePageState extends State<EntryCreatePage> {
  final _nameCtrl = TextEditingController();
  final _scoreCtrl = TextEditingController();
  final _nameFocus = FocusNode();

  List<Map> classes = [];
  String? _selectedClassId;
  DateTime? _selectedDate;
  bool _settled = false;
  List<Map> proofs = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    classes = StorageService.getAllClasses();

    // restore class order
    final settings = StorageService.getSettings();
    if (settings.containsKey('classOrder')) {
      final order = List<String>.from(settings['classOrder'] ?? []);
      try {
        classes.sort((a, b) {
          final indexA = order.indexOf(a['id'].toString());
          final indexB = order.indexOf(b['id'].toString());
          if (indexA == -1) return 1;
          if (indexB == -1) return -1;
          return indexA.compareTo(indexB);
        });
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _scoreCtrl.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _pickProofs() async {
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (result != null && result.files.isNotEmpty) {
        final saved = await StorageService.saveProofPlatformFiles(result.files);
        setState(() => proofs.addAll(saved));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择文件失败: $e')),
        );
      }
    }
  }

  Future<void> _save() async {
    final trimmedName = _nameCtrl.text.trim();
    if (trimmedName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入条目名称')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final score = double.tryParse(_scoreCtrl.text);

      // 检查分数上限
      if (_selectedClassId != null) {
        final selectedClass = classes.firstWhere(
          (c) => c['id'].toString() == _selectedClassId,
          orElse: () => <String, dynamic>{},
        );
        if (selectedClass.isNotEmpty &&
            selectedClass['scoreLimit'] != null) {
          final scoreLimit = (selectedClass['scoreLimit'] as num).toDouble();
          final allEntries = StorageService.getAllEntries();
          final classEntries = allEntries
              .where((e) => e['classId'].toString() == _selectedClassId)
              .toList();
          double currentSum = 0;
          for (final e in classEntries) {
            final s = (e['score'] is num)
                ? (e['score'] as num).toDouble()
                : double.tryParse(e['score']?.toString() ?? '') ?? 0.0;
            currentSum += s;
          }
          final newSum = currentSum + (score ?? 0);
          if (newSum > scoreLimit) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '该类的分数已达上限 $scoreLimit。当前: $currentSum，新增: ${score ?? 0}，总计: $newSum',
                ),
              ),
            );
            setState(() => _saving = false);
            return;
          }
        }
      }

      await StorageService.createEntry({
        'name': trimmedName,
        'classId': _selectedClassId,
        'date': _selectedDate?.toIso8601String(),
        'proofs': proofs,
        'settled': _settled,
        'score': score,
      });

      if (!mounted) return;
      Navigator.pop(context, true); // true = saved
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('新建条目'), elevation: 0),
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
              padding: const EdgeInsets.all(16),
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
                  TextField(
                    controller: _nameCtrl,
                    focusNode: _nameFocus,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: '名称'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _scoreCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: '分数（可选）',
                    ),
                  ),
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: '所属类（不选为未分类）',
                      border: OutlineInputBorder(),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _selectedClassId,
                        isExpanded: true,
                        isDense: true,
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
                        onChanged: (v) => setState(() => _selectedClassId = v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedDate != null
                              ? '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}'
                              : '未选择日期',
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate ?? DateTime.now(),
                            firstDate: DateTime(1970),
                            lastDate: DateTime(2100),
                          );
                          if (d != null) setState(() => _selectedDate = d);
                        },
                        child: const Text('选择日期'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('是否结清'),
                      Checkbox(
                        value: _settled,
                        onChanged: (v) =>
                            setState(() => _settled = v ?? false),
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
                    '证明文件',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _pickProofs,
                    icon: const Icon(Icons.attach_file),
                    label: const Text('选择证明文件'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '已添加 ${proofs.length} 个',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
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
                            setState(() => proofs.removeAt(idx));
                          },
                        );
                      }).toList(),
                    ),
                  ],
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
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _saving ? null : () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
