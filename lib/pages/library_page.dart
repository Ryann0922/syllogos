import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:syllogos/pages/class_detail_page.dart';
import 'package:syllogos/pages/entry_detail_page.dart';
import 'package:syllogos/services/storage_service.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage>
    with TickerProviderStateMixin {
  List<Map> classes = [];
  List<Map> entries = [];
  late TabController _categoryTabController;
  List<String> _categoryTabs = []; // 动态生成的分类列表

  @override
  void initState() {
    super.initState();
    // 先初始化空的 TabController（会在 _load 中更新）
    _categoryTabs = ['全部', '未分类'];
    _categoryTabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _categoryTabController.dispose();
    super.dispose();
  }

  void _load() {
    final newClasses = StorageService.getAllClasses();
    entries = StorageService.getAllEntries();

    // 只在类列表改变时重新创建 TabController
    if (newClasses.length != classes.length ||
        !newClasses.asMap().entries.every(
          (e) => e.value['id'] == classes.elementAtOrNull(e.key)?['id'],
        )) {
      classes = newClasses;

      // 重新生成分类标签列表
      _categoryTabs = ['全部', '未分类'];
      _categoryTabs.addAll(classes.map((c) => c['name'] ?? 'Unnamed'));

      // 重新创建 TabController
      if (mounted) {
        _categoryTabController.dispose();
        _categoryTabController = TabController(
          length: _categoryTabs.length,
          vsync: this,
        );
      }
    } else {
      classes = newClasses;
    }

    setState(() {});
  }

  Future<void> _showAddClass() async {
    final nameController = TextEditingController();
    bool hasYearLimit = false;
    final yearController = TextEditingController();
    final targetController = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          return AlertDialog(
            title: const Text('新建类'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '名称'),
                ),
                Row(
                  children: [
                    const Text('是否有学年上限'),
                    Checkbox(
                      value: hasYearLimit,
                      onChanged: (v) => setD(() => hasYearLimit = v ?? false),
                    ),
                  ],
                ),
                if (hasYearLimit)
                  TextField(
                    controller: yearController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '学年上限（年）'),
                  ),
                TextField(
                  controller: targetController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: '目标分（可选）'),
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
                      ? int.tryParse(yearController.text)
                      : null;
                  final target = double.tryParse(targetController.text);
                  await StorageService.createClass({
                    'name': nameController.text.trim(),
                    'hasYearLimit': hasYearLimit,
                    'yearLimit': yearLimit,
                    'target': target,
                  });
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
  }

  Future<void> _showAddEntry() async {
    final nameController = TextEditingController();
    String? selectedClassId;
    DateTime? selectedDate;
    bool settled = false;
    List<Map> proofs = [];
    final scoreController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (c, setD) {
            return AlertDialog(
              title: const Text('新建条目'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: '名称'),
                    ),
                    DropdownButtonFormField<String?>(
                      value: selectedClassId,
                      decoration: const InputDecoration(
                        labelText: '所属类（不选为未分类）',
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('未分类')),
                        ...classes.map(
                          (c) => DropdownMenuItem(
                            value: c['id'].toString(),
                            child: Text(c['name'] ?? 'Unnamed'),
                          ),
                        ),
                      ],
                      onChanged: (v) => setD(() => selectedClassId = v),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            selectedDate != null
                                ? '${selectedDate!.year}-${selectedDate!.month}-${selectedDate!.day}'
                                : '未选择日期',
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(1970),
                              lastDate: DateTime(2100),
                            );
                            if (d != null) setD(() => selectedDate = d);
                          },
                          child: const Text('选择日期'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: scoreController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: '分数（可选）'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: () async {
                            final result = await FilePicker.platform.pickFiles(
                              allowMultiple: true,
                            );
                            if (result != null && result.files.isNotEmpty) {
                              final saved =
                                  await StorageService.saveProofPlatformFiles(
                                    result.files,
                                  );
                              setD(() => proofs.addAll(saved));
                            }
                          },
                          child: const Text('选择证明文件'),
                        ),
                        const SizedBox(width: 8),
                        Text('已选 ${proofs.length} 个'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('是否结清'),
                        Checkbox(
                          value: settled,
                          onChanged: (v) => setD(() => settled = v ?? false),
                        ),
                      ],
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
                    if (nameController.text.trim().isEmpty) return;
                    final score = double.tryParse(scoreController.text);
                    final data = {
                      'name': nameController.text.trim(),
                      'classId': selectedClassId,
                      'date': selectedDate?.toIso8601String(),
                      'proofs': proofs,
                      'settled': settled,
                      'score': score,
                    };
                    await StorageService.createEntry(data);
                    Navigator.pop(ctx);
                    _load();
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('库'),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _categoryTabController,
            tabs: _categoryTabs.map((cat) => Tab(text: cat)).toList(),
            isScrollable: true,
            indicatorColor: cs.primary,
            labelColor: cs.primary,
            unselectedLabelColor: cs.onSurfaceVariant,
          ),
        ),
      ),
      body: TabBarView(
        controller: _categoryTabController,
        children: List.generate(_categoryTabs.length, (tabIndex) {
          // 根据 tabIndex 确定要显示的分类
          final list =
              entries.where((e) {
                if (tabIndex == 0) {
                  // '全部' 标签页
                  return true;
                } else if (tabIndex == 1) {
                  // '未分类' 标签页
                  return e['classId'] == null;
                } else {
                  // 类别标签页：tabIndex - 2 对应到 classes 数组
                  final classIndex = tabIndex - 2;
                  if (classIndex < classes.length) {
                    return e['classId']?.toString() ==
                        classes[classIndex]['id'].toString();
                  }
                  return false;
                }
              }).toList()..sort((a, b) {
                final da = a['date'] != null
                    ? DateTime.tryParse(a['date'])
                    : null;
                final db = b['date'] != null
                    ? DateTime.tryParse(b['date'])
                    : null;
                if (da == null && db == null) return 0;
                if (da == null) return 1;
                if (db == null) return -1;
                return db.compareTo(da);
              });

          if (list.isEmpty) {
            return const Center(child: Text('暂无条目'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            itemBuilder: (ctx, i) {
              final item = list[i];
              final proofs = List<Map>.from(item['proofs'] ?? []);
              String? thumbPath;
              if (proofs.isNotEmpty) {
                final p = proofs.first;
                final ppath = p['path']?.toString() ?? '';
                if (ppath.toLowerCase().endsWith('.png') ||
                    ppath.toLowerCase().endsWith('.jpg') ||
                    ppath.toLowerCase().endsWith('.jpeg') ||
                    ppath.toLowerCase().endsWith('.gif')) {
                  thumbPath = ppath;
                }
              }

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: GestureDetector(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            EntryDetailPage(entryId: item['id'].toString()),
                      ),
                    );
                    _load();
                  },
                  child: Card(
                    elevation: 0,
                    color: cs.surfaceContainerLow,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 64,
                              height: 64,
                              color: cs.surfaceContainerHighest,
                              child: thumbPath != null
                                  ? Image.file(
                                      File(thumbPath),
                                      width: 64,
                                      height: 64,
                                      fit: BoxFit.cover,
                                    )
                                  : Icon(
                                      Icons.insert_drive_file,
                                      color: cs.onSurfaceVariant,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['name'] ?? 'Unnamed',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w500),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${item['date'] != null ? (DateTime.tryParse(item['date'])?.toString().split(' ').first ?? '') : '无日期'}${item['score'] != null ? ' · ${item['score']} 分' : ''}',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(color: cs.onSurfaceVariant),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (item['settled'] == true) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: cs.tertiaryContainer,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '已结清',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: cs.onTertiaryContainer,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: cs.outline),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        }),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          showModalBottomSheet(
            context: context,
            builder: (ctx) {
              return SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.category),
                      title: const Text('新建类'),
                      onTap: () {
                        Navigator.pop(ctx);
                        _showAddClass();
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.note_add),
                      title: const Text('新建条目'),
                      onTap: () {
                        Navigator.pop(ctx);
                        _showAddEntry();
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
