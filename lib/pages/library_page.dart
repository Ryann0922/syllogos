import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syllogos/pages/entry_create_page.dart';
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
  List<String> _categoryTabs = [];

  // 多选相关
  bool _isMultiSelectMode = false;
  final Set<String> _selectedEntryIds = {};

  // 搜索和筛选
  String _searchQuery = '';
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;

  @override
  void initState() {
    super.initState();
    _categoryTabs = ['全部'];
    _categoryTabController = TabController(length: 1, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _categoryTabController.dispose();
    super.dispose();
  }

  String _getClassName(String classId) {
    try {
      final found = classes.where((c) => c['id'].toString() == classId);
      return found.isNotEmpty ? found.first['name'] ?? '未命名' : '分类不存在';
    } catch (_) {
      return '分类不存在';
    }
  }

  void _load() {
    var newClasses = StorageService.getAllClasses();
    entries = StorageService.getAllEntries();

    // 恢复保存的类别顺序
    final settings = StorageService.getSettings();
    if (settings.containsKey('classOrder')) {
      final order = List<String>.from(settings['classOrder'] ?? []);
      try {
        newClasses.sort((a, b) {
          final indexA = order.indexOf(a['id'].toString());
          final indexB = order.indexOf(b['id'].toString());
          if (indexA == -1) return 1;
          if (indexB == -1) return -1;
          return indexA.compareTo(indexB);
        });
      } catch (_) {}
    }

    if (newClasses.length != classes.length ||
        !newClasses.asMap().entries.every(
          (e) => e.value['id'] == classes.elementAtOrNull(e.key)?['id'],
        )) {
      classes = newClasses;
      _categoryTabs = ['全部'];
      _categoryTabs.addAll(classes.map((c) => c['name'] ?? 'Unnamed'));
      _categoryTabs.add('未分类');

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
    _selectedEntryIds.clear();
    _isMultiSelectMode = false;
    setState(() {});
  }

  List<Map> _getFilteredEntries() {
    return entries.where((e) {
      // 按名称搜索
      if (_searchQuery.isNotEmpty) {
        if (!(e['name'] ?? '').toLowerCase().contains(
          _searchQuery.toLowerCase(),
        )) {
          return false;
        }
      }

      // 按日期范围筛选
      if (_filterStartDate != null || _filterEndDate != null) {
        if (e['date'] != null) {
          final date = DateTime.tryParse(e['date']);
          if (date != null) {
            if (_filterStartDate != null && date.isBefore(_filterStartDate!)) {
              return false;
            }
            if (_filterEndDate != null && date.isAfter(_filterEndDate!)) {
              return false;
            }
          }
        } else {
          if (_filterStartDate != null || _filterEndDate != null) {
            return false;
          }
        }
      }

      return true;
    }).toList()..sort((a, b) {
      final da = a['date'] != null ? DateTime.tryParse(a['date']) : null;
      final db = b['date'] != null ? DateTime.tryParse(b['date']) : null;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });
  }

  Future<void> _showAddClass() async {
    final nameController = TextEditingController();
    final scoreLimitController = TextEditingController();
    final targetController = TextEditingController();
    final nameFocus = FocusNode();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          // 请求焦点
          WidgetsBinding.instance.addPostFrameCallback((_) {
            nameFocus.requestFocus();
          });

          return AlertDialog(
            title: const Text('新建类'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    focusNode: nameFocus,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: '名称'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: scoreLimitController,
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
                    controller: targetController,
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
                  final scoreLimit = double.tryParse(scoreLimitController.text);
                  final target = double.tryParse(targetController.text);
                  await StorageService.createClass({
                    'name': nameController.text.trim(),
                    'scoreLimit': scoreLimit,
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
    ).then((_) {
      nameController.dispose();
      scoreLimitController.dispose();
      targetController.dispose();
      nameFocus.dispose();
    });
  }

  Future<void> _showFilterDialog() async {
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: const Text('筛选条件'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('按日期范围筛选'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _filterStartDate != null
                            ? '从 ${_filterStartDate!.toString().split(' ').first}'
                            : '从 (未设置)',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _filterStartDate ?? DateTime.now(),
                          firstDate: DateTime(1970),
                          lastDate: DateTime(2100),
                        );
                        if (d != null) {
                          setD(() => _filterStartDate = d);
                          setState(() {});
                        }
                      },
                      child: const Text('设置'),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _filterEndDate != null
                            ? '至 ${_filterEndDate!.toString().split(' ').first}'
                            : '至 (未设置)',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _filterEndDate ?? DateTime.now(),
                          firstDate: DateTime(1970),
                          lastDate: DateTime(2100),
                        );
                        if (d != null) {
                          setD(() => _filterEndDate = d);
                          setState(() {});
                        }
                      },
                      child: const Text('设置'),
                    ),
                  ],
                ),
                if (_filterStartDate != null || _filterEndDate != null)
                  TextButton(
                    onPressed: () {
                      setD(() {
                        _filterStartDate = null;
                        _filterEndDate = null;
                      });
                      setState(() {});
                    },
                    child: const Text('清除日期筛选'),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('关闭'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showReorderCategoryMenu(int tabIndex) async {
    if (tabIndex == 0 || tabIndex == _categoryTabs.length - 1) return;

    final classIndex = tabIndex - 1;
    final canMoveUp = classIndex > 0;
    final canMoveDown = classIndex < classes.length - 1;

    await showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canMoveUp)
              ListTile(
                leading: const Icon(Icons.arrow_upward),
                title: const Text('向上移动'),
                onTap: () {
                  Navigator.pop(ctx);
                  _swapClasses(classIndex, classIndex - 1);
                },
              ),
            if (canMoveDown)
              ListTile(
                leading: const Icon(Icons.arrow_downward),
                title: const Text('向下移动'),
                onTap: () {
                  Navigator.pop(ctx);
                  _swapClasses(classIndex, classIndex + 1);
                },
              ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('取消'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  void _swapClasses(int indexA, int indexB) {
    // 交换两个类的位置
    final temp = classes[indexA];
    classes[indexA] = classes[indexB];
    classes[indexB] = temp;

    // 保存新的顺序
    final order = classes.map((c) => c['id'].toString()).toList();
    StorageService.saveSetting('classOrder', order);

    // 更新标签
    _categoryTabs = ['全部'];
    _categoryTabs.addAll(classes.map((c) => c['name'] ?? 'Unnamed'));
    _categoryTabs.add('未分类');

    // 保持当前选中的tab
    final currentTab = _categoryTabController.index;
    _categoryTabController.dispose();
    _categoryTabController = TabController(
      length: _categoryTabs.length,
      vsync: this,
      initialIndex: currentTab,
    );

    setState(() {});
  }

  Future<void> _batchDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除选中的 ${_selectedEntryIds.length} 个条目吗？'),
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
      for (final id in _selectedEntryIds) {
        await StorageService.deleteEntry(id);
      }
      _load();
    }
  }

  Future<void> _batchChangeClass() async {
    String? newClassId;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: const Text('调整类别'),
          content: InputDecorator(
            decoration: const InputDecoration(
              labelText: '新所属类',
              border: OutlineInputBorder(),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: newClassId,
                isExpanded: true,
                isDense: true,
                items: [
                  const DropdownMenuItem(value: null, child: Text('未分类')),
                  ...classes.map(
                    (c) => DropdownMenuItem(
                      value: c['id'].toString(),
                      child: Text(c['name'] ?? 'Unnamed'),
                    ),
                  ),
                ],
                onChanged: (v) => setD(() => newClassId = v),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                for (final id in _selectedEntryIds) {
                  final entry = entries
                      .where((e) => e['id'].toString() == id)
                      .toList();
                  if (entry.isNotEmpty) {
                    final data = Map.from(entry.first);
                    data['classId'] = newClassId;
                    await StorageService.updateEntry(id, data);
                  }
                }
                Navigator.pop(ctx);
                _load();
              },
              child: const Text('确认'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filteredEntries = _getFilteredEntries();

    return Scaffold(
      appBar: AppBar(
        title: _isMultiSelectMode
            ? Text('已选 ${_selectedEntryIds.length} 个')
            : const Text('库'),
        elevation: 0,
        actions: _isMultiSelectMode
            ? [
                if (_selectedEntryIds.isNotEmpty) ...[
                  IconButton(
                    icon: const Icon(Icons.drive_file_rename_outline),
                    tooltip: '更改类别',
                    onPressed: _batchChangeClass,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    tooltip: '删除',
                    onPressed: _batchDelete,
                  ),
                ],
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _isMultiSelectMode = false;
                      _selectedEntryIds.clear();
                    });
                  },
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.tune),
                  tooltip: '筛选',
                  onPressed: _showFilterDialog,
                ),
                IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: '搜索',
                  onPressed: () {
                    final focusNode = FocusNode();
                    showDialog(
                      context: context,
                      builder: (ctx) => StatefulBuilder(
                        builder: (c, setD) => AlertDialog(
                          title: const Text('搜索条目'),
                          content: TextField(
                            focusNode: focusNode,
                            autofocus: true,
                            decoration: const InputDecoration(
                              labelText: '输入条目名称',
                              hintText: '输入要搜索的条目名称',
                            ),
                            onChanged: (v) {
                              setState(() => _searchQuery = v);
                            },
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('关闭'),
                            ),
                          ],
                        ),
                      ),
                    ).then((_) => focusNode.dispose());
                  },
                ),
              ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _categoryTabController,
            tabs: List.generate(_categoryTabs.length, (idx) {
              return GestureDetector(
                onLongPress: _categoryTabs.length > 1
                    ? () {
                        _showReorderCategoryMenu(idx);
                      }
                    : null,
                child: Tab(text: _categoryTabs[idx]),
              );
            }),
            isScrollable: true,
            indicatorColor: cs.primary,
            labelColor: cs.primary,
            unselectedLabelColor: cs.onSurfaceVariant,
            tabAlignment: TabAlignment.center,
          ),
        ),
      ),
      body: TabBarView(
        controller: _categoryTabController,
        children: List.generate(_categoryTabs.length, (tabIndex) {
          final list = filteredEntries.where((e) {
            if (tabIndex == 0) {
              return true;
            } else if (tabIndex == _categoryTabs.length - 1) {
              return e['classId'] == null;
            } else {
              final classIndex = tabIndex - 1;
              if (classIndex < classes.length) {
                return e['classId']?.toString() ==
                    classes[classIndex]['id'].toString();
              }
              return false;
            }
          }).toList();

          if (list.isEmpty) {
            return const Center(child: Text('暂无条目'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            itemBuilder: (ctx, i) {
              final item = list[i];
              final isSelected = _selectedEntryIds.contains(
                item['id'].toString(),
              );
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
                  onTap: _isMultiSelectMode
                      ? () {
                          setState(() {
                            if (isSelected) {
                              _selectedEntryIds.remove(item['id'].toString());
                            } else {
                              _selectedEntryIds.add(item['id'].toString());
                            }
                          });
                        }
                      : () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EntryDetailPage(
                                entryId: item['id'].toString(),
                              ),
                            ),
                          );
                          _load();
                        },
                  onLongPress: !_isMultiSelectMode
                      ? () {
                          setState(() {
                            _isMultiSelectMode = true;
                            _selectedEntryIds.add(item['id'].toString());
                          });
                        }
                      : null,
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    color: isSelected
                        ? cs.primaryContainer
                        : cs.surfaceContainerLow,
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Row(
                        children: [
                          if (_isMultiSelectMode)
                            Checkbox(
                              value: isSelected,
                              onChanged: (v) {
                                setState(() {
                                  if (v == true) {
                                    _selectedEntryIds.add(
                                      item['id'].toString(),
                                    );
                                  } else {
                                    _selectedEntryIds.remove(
                                      item['id'].toString(),
                                    );
                                  }
                                });
                              },
                            )
                          else
                            const SizedBox.shrink(),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
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
                                  '${item['date'] != null ? (DateTime.tryParse(item['date'])?.toString().split(' ').first ?? '') : '无日期'}${item['score'] != null ? ' · ${item['score']}分' : ''}${item['classId'] != null ? ' · ${_getClassName(item['classId'].toString())}' : ''}',
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
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const EntryCreatePage(),
                          ),
                        ).then((saved) {
                          if (saved == true) _load();
                        });
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
