import 'package:flutter/material.dart';
import 'package:syllogos/services/storage_service.dart';

class ClassManagementPage extends StatefulWidget {
  const ClassManagementPage({super.key});

  @override
  State<ClassManagementPage> createState() => _ClassManagementPageState();
}

class _ClassManagementPageState extends State<ClassManagementPage> {
  List<Map> classes = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    classes = StorageService.getAllClasses();

    // 恢复保存的类别顺序
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

    setState(() {});
  }

  void _saveOrder() {
    final order = classes.map((c) => c['id'].toString()).toList();
    StorageService.saveSetting('classOrder', order);
  }

  Future<void> _editClass(Map classData) async {
    final nameCtrl = TextEditingController(text: classData['name'] ?? '');
    final nameFocus = FocusNode();
    final scoreLimitCtrl = TextEditingController(
      text: classData['scoreLimit']?.toString() ?? '',
    );
    final targetCtrl = TextEditingController(
      text: classData['target']?.toString() ?? '',
    );

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setD) {
          // 请求焦点
          WidgetsBinding.instance.addPostFrameCallback((_) {
            nameFocus.requestFocus();
          });

          return AlertDialog(
            title: const Text('编辑类'),
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
                  TextField(
                    controller: scoreLimitCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: '分数上限（可选）',
                      hintText: '到达此分数后无法添加新条目',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: targetCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: '目标分（可选）',
                      hintText: '统计显示用，不限制添加',
                    ),
                  ),
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
                  if (nameCtrl.text.trim().isEmpty) return;
                  final data = {
                    'name': nameCtrl.text.trim(),
                    'scoreLimit': double.tryParse(scoreLimitCtrl.text),
                    'target': double.tryParse(targetCtrl.text),
                  };
                  await StorageService.updateClass(
                    classData['id'].toString(),
                    data,
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
    ).then((_) {
      nameCtrl.dispose();
      scoreLimitCtrl.dispose();
      targetCtrl.dispose();
      nameFocus.dispose();
    });
  }

  Future<void> _deleteClass(String classId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这个类吗？'),
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
      await StorageService.deleteClass(classId);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('编辑分类'), elevation: 0),
      body: classes.isEmpty
          ? const Center(child: Text('暂无分类'))
          : ReorderableListView.builder(
              padding: const EdgeInsets.all(12),
              onReorderItem: (int oldIndex, int newIndex) {
                final item = classes.removeAt(oldIndex);
                classes.insert(newIndex, item);
                _saveOrder();
                setState(() {});
              },
              itemCount: classes.length,
              itemBuilder: (ctx, i) {
                final cls = classes[i];
                return Padding(
                  key: ValueKey(cls['id']),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    color: cs.surfaceContainerLow,
                    child: ListTile(
                      leading: ReorderableDragStartListener(
                        index: i,
                        child: Icon(
                          Icons.drag_handle,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      title: Text(
                        cls['name'] ?? 'Unnamed',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (cls['scoreLimit'] != null)
                            Text(
                              '上限: ${cls['scoreLimit']}',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          if (cls['target'] != null)
                            Text(
                              '目标: ${cls['target']}',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: '编辑',
                            onPressed: () => _editClass(cls),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outlined),
                            tooltip: '删除',
                            onPressed: () => _deleteClass(cls['id'].toString()),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
