import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:syllogos/services/storage_service.dart';

class EntryEditPage extends StatefulWidget {
  final Map entry;
  final String entryId;
  const EntryEditPage({
    super.key,
    required this.entry,
    required this.entryId,
  });

  @override
  State<EntryEditPage> createState() => _EntryEditPageState();
}

class _EntryEditPageState extends State<EntryEditPage> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _scoreCtrl;
  final _nameFocus = FocusNode();

  List<Map> classes = [];
  String? _selectedClassId;
  DateTime? _selectedDate;
  bool _settled = false;
  List<Map> proofs = [];
  bool _saving = false;
  late final List<TextEditingController> _activityCtrls;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.entry['name'] ?? '');
    _scoreCtrl = TextEditingController(
      text: widget.entry['score']?.toString() ?? '',
    );
    _selectedDate = widget.entry['date'] != null
        ? DateTime.tryParse(widget.entry['date'])
        : null;
    _settled = widget.entry['settled'] ?? false;
    proofs = List.from(widget.entry['proofs'] ?? []);
    _selectedClassId = widget.entry['classId'];

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

    // validate class still exists
    if (_selectedClassId != null) {
      final exists = classes.any(
        (c) => c['id'].toString() == _selectedClassId,
      );
      if (!exists) _selectedClassId = null;
    }

    // init activity info
    final existingActivity =
        List<String>.from(widget.entry['activityInfo'] ?? []);
    _activityCtrls = existingActivity.isEmpty
        ? [TextEditingController()]
        : existingActivity.map((s) => TextEditingController(text: s)).toList();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _scoreCtrl.dispose();
    _nameFocus.dispose();
    for (final c in _activityCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickFiles() async {
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

  Future<void> _pickImages() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final saved = await StorageService.saveProofPlatformFiles(result.files);
        setState(() => proofs.addAll(saved));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择图片失败: $e')),
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
      final oldScore = (widget.entry['score'] is num)
          ? (widget.entry['score'] as num).toDouble()
          : double.tryParse(widget.entry['score']?.toString() ?? '') ?? 0.0;
      final newScore = double.tryParse(_scoreCtrl.text) ?? 0.0;
      final scoreDiff = newScore - oldScore;

      // score limit check
      if (_selectedClassId != null &&
          (scoreDiff != 0 ||
              _selectedClassId.toString() !=
                  widget.entry['classId'].toString())) {
        final selectedClass = classes.firstWhere(
          (c) => c['id'].toString() == _selectedClassId,
          orElse: () => <String, dynamic>{},
        );
        if (selectedClass.isNotEmpty &&
            selectedClass['scoreLimit'] != null) {
          final scoreLimit =
              (selectedClass['scoreLimit'] as num).toDouble();

          final allEntries = StorageService.getAllEntries();
          final classEntries = allEntries
              .where(
                (e) =>
                    e['classId'].toString() == _selectedClassId &&
                    e['id'].toString() != widget.entryId,
              )
              .toList();
          double currentSum = 0;
          for (final e in classEntries) {
            final s = (e['score'] is num)
                ? (e['score'] as num).toDouble()
                : double.tryParse(e['score']?.toString() ?? '') ?? 0.0;
            currentSum += s;
          }
          final newSum = currentSum + newScore;
          if (newSum > scoreLimit) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '该类的分数将超过上限 $scoreLimit。当前: $currentSum，新分数: $newScore，总计: $newSum',
                ),
              ),
            );
            setState(() => _saving = false);
            return;
          }
        }
      }

      await StorageService.updateEntry(widget.entryId, {
        'name': trimmedName,
        'classId': _selectedClassId,
        'date': _selectedDate?.toIso8601String(),
        'proofs': proofs,
        'settled': _settled,
        'score': double.tryParse(_scoreCtrl.text),
        'activityInfo': _activityCtrls
            .map((c) => c.text.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        'createdAt': DateTime.now().toIso8601String(),
        if (widget.entry['schoolYearStart'] != null)
          'schoolYearStart': widget.entry['schoolYearStart'],
      });

      if (!mounted) return;
      Navigator.pop(context, true);
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
      appBar: AppBar(title: const Text('编辑条目'), elevation: 0),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
                      labelText: '所属类',
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedDate != null
                            ? '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}'
                            : '未选择日期',
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
          // 活动信息卡片
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
                  ..._activityCtrls.asMap().entries.map((e) {
                    final i = e.key;
                    final ctrl = e.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: ctrl,
                              decoration: const InputDecoration(
                                hintText: '输入文字或链接',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (_activityCtrls.length > 1)
                            IconButton(
                              icon: Icon(Icons.remove_circle_outline,
                                  color: cs.error),
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                              onPressed: () {
                                setState(() {
                                  ctrl.dispose();
                                  _activityCtrls.removeAt(i);
                                });
                              },
                            ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 4),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(
                          () => _activityCtrls.add(TextEditingController()));
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('添加'),
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
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _pickFiles,
                          icon: const Icon(Icons.attach_file),
                          label: const Text('选择文件'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _pickImages,
                          icon: const Icon(Icons.image),
                          label: const Text('选择图片'),
                        ),
                      ),
                    ],
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
