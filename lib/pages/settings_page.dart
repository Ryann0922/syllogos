import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:syllogos/main.dart';
import 'package:syllogos/pages/class_management_page.dart';
import 'package:syllogos/pages/export_page.dart';
import 'package:syllogos/services/export_service.dart';
import 'package:syllogos/services/storage_service.dart';
import 'package:syllogos/services/webdav_service.dart';
import 'package:dynamic_color/dynamic_color.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int startMonth = 9;
  int? selectedSchoolYearStart;
  List<int> availableYears = [];
  String themeMode = 'system';
  int primaryColorValue = 0xFF3F51B5; // Colors.indigo
  // WebDAV settings
  String webdavUrl = '';
  String webdavUser = '';
  String webdavPass = '';
  String webdavRemotePath = '/';

  @override
  void initState() {
    super.initState();
    final s = StorageService.getSettings();
    if (s.containsKey('startMonth')) startMonth = s['startMonth'];
    if (s.containsKey('selectedSchoolYearStart')) {
      selectedSchoolYearStart = s['selectedSchoolYearStart'];
    }
    availableYears = StorageService.getAvailableSchoolYears(startMonth);
    if (s.containsKey('theme')) themeMode = s['theme'];
    if (s.containsKey('primaryColor')) primaryColorValue = s['primaryColor'];
    if (s.containsKey('webdavUrl')) webdavUrl = s['webdavUrl'];
    if (s.containsKey('webdavUser')) webdavUser = s['webdavUser'];
    if (s.containsKey('webdavPass')) webdavPass = s['webdavPass'];
    if (s.containsKey('webdavRemotePath')) {
      webdavRemotePath = s['webdavRemotePath'];
    }
  }

  String get _currentSchoolYearLabel {
    if (selectedSchoolYearStart != null) {
      return '${selectedSchoolYearStart}年$startMonth月 ~ ${selectedSchoolYearStart! + 1}年$startMonth月';
    }
    final now = DateTime.now();
    final sy = (now.month >= startMonth) ? now.year : now.year - 1;
    return '$sy年$startMonth月 ~ ${sy + 1}年$startMonth月（跟随系统）';
  }

  Future<void> _pickSchoolYear() async {
    final now = DateTime.now();
    final currentSy = StorageService.getSchoolYear(now, startMonth);
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) {
        int temp = selectedSchoolYearStart ?? -1;
        return AlertDialog(
          title: const Text('选择学年'),
          content: StatefulBuilder(
            builder: (c, s) {
              return DropdownButton<int>(
                value: temp,
                isExpanded: true,
                items: [
                  const DropdownMenuItem(value: -1, child: Text('跟随系统')),
                  ...List.generate(currentSy - 2020 + 1, (i) => 2020 + i).map(
                    (y) => DropdownMenuItem(
                      value: y,
                      child: Text('$y年$startMonth月 ~ ${y + 1}年$startMonth月'),
                    ),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) {
                    temp = v;
                    s(() {});
                  }
                },
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, temp),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
    if (picked != null) {
      if (picked == -1) {
        setState(() => selectedSchoolYearStart = null);
        await StorageService.saveSetting('selectedSchoolYearStart', null);
      } else {
        setState(() => selectedSchoolYearStart = picked);
        await StorageService.saveSetting('selectedSchoolYearStart', picked);
      }
    }
  }

  Future<void> _webdavDownload() async {
    if (webdavUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先配置 WebDAV')),
      );
      return;
    }
    var base = webdavUrl.trim();
    var remote = webdavRemotePath.trim();
    if (base.endsWith('/')) base = base.substring(0, base.length - 1);
    if (!remote.startsWith('/')) remote = '/$remote';
    if (!remote.endsWith('/')) remote = '$remote/';
    final listUrl = '$base$remote';

    final files = await WebDavService.listFiles(
      listUrl,
      username: webdavUser,
      password: webdavPass,
    );
    if (files.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有找到可下载的文件')),
      );
      return;
    }

    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) {
        String? temp;
        return AlertDialog(
          title: const Text('选择要下载的文件'),
          content: SingleChildScrollView(
            child: RadioGroup<String>(
              groupValue: temp,
              onChanged: (v) {
                if (v != null) Navigator.pop(ctx, v);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: files.map((f) {
                  final name = f.split('/').last;
                  return RadioListTile<String>(
                    value: f,
                    title: Text(name),
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );

    if (selected == null) return;

    final fullUrl = selected.startsWith('http')
        ? selected
        : '$base$selected';
    final downloaded = await WebDavService.downloadFile(
      fullUrl,
      username: webdavUser,
      password: webdavPass,
    );
    if (downloaded == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('下载失败')),
      );
      return;
    }

    try {
      final count = await ExportService.importFromZip(downloaded.path);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('成功下载并导入 $count 个条目')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败: $e')),
      );
    }
  }

  Future<void> _showColorPicker(BuildContext context) async {
    final predefinedColors = {
      'Indigo': Colors.indigo,
      'Teal': Colors.teal,
      'Pink': Colors.pink,
      'Amber': Colors.amber,
      'Blue': Colors.blue,
      'Green': Colors.green,
      'Purple': Colors.purple,
      'Red': Colors.red,
      'Cyan': Colors.cyan,
      'Orange': Colors.orange,
    };

    int? selected = await showDialog<int>(
      context: context,
      builder: (ctx) {
        int temp = primaryColorValue;
        return AlertDialog(
          title: const Text('选择主题色'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 系统动态取色选项
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.pop(ctx, -1), // -1 表示系统动态取色
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.indigo,
                                    Colors.cyan,
                                    Colors.teal,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '系统动态取色',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  'Android 12+ 从壁纸自动提取',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 预设颜色网格
                Text(
                  '预设颜色',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 5,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: predefinedColors.entries.map((e) {
                    final isSelected = temp == e.value.toARGB32();
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx, e.value.toARGB32());
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: e.value,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                            width: isSelected ? 3 : 0,
                          ),
                        ),
                        child: isSelected
                            ? Icon(Icons.check, color: Colors.white)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );

    if (selected != null) {
      if (selected == -1) {
        // 使用系统动态取色
        try {
          await DynamicColorPlugin.getCorePalette().then((corePalette) {
            if (corePalette != null) {
              // 从系统色盘提取主色
              final dynamicColor = Color(corePalette.primary.get(80));
              setState(() => primaryColorValue = dynamicColor.toARGB32());
              StorageService.saveSetting('primaryColor', dynamicColor.toARGB32());
              MyApp.refreshTheme();
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('已应用系统动态取色')));
            }
          });
        } catch (e) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('此设备不支持系统动态取色')));
        }
      } else {
        setState(() => primaryColorValue = selected);
        await StorageService.saveSetting('primaryColor', primaryColorValue);
        MyApp.refreshTheme();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('设置'), elevation: 0),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // 学年设置组
          Text(
            '学年设置',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            color: cs.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '学年起始月份',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$startMonth 月',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                      FilledButton.tonal(
                        onPressed: () async {
                          final picked = await showDialog<int>(
                            context: context,
                            builder: (ctx) {
                              int temp = startMonth;
                              return AlertDialog(
                                title: const Text('选择起始月份'),
                                content: StatefulBuilder(
                                  builder: (c, s) {
                                    return DropdownButton<int>(
                                      value: temp,
                                      items: List.generate(12, (i) => i + 1)
                                          .map(
                                            (m) => DropdownMenuItem(
                                              value: m,
                                              child: Text('$m 月'),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (v) {
                                        if (v != null) {
                                          temp = v;
                                          s(() {});
                                        }
                                      },
                                    );
                                  },
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('取消'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(ctx, temp),
                                    child: const Text('确定'),
                                  ),
                                ],
                              );
                            },
                          );
                          if (picked != null) {
                            setState(() => startMonth = picked);
                            availableYears =
                                StorageService.getAvailableSchoolYears(startMonth);
                            await StorageService.saveSetting(
                              'startMonth',
                              startMonth,
                            );
                          }
                        },
                        child: const Text('修改'),
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
                            '当前学年',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _currentSchoolYearLabel,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                      FilledButton.tonal(
                        onPressed: _pickSchoolYear,
                        child: const Text('切换'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 主题设置组
          Text(
            '外观设置',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            color: cs.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '主题',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            themeMode == 'system'
                                ? '跟随系统'
                                : (themeMode == 'light'
                                    ? '亮色'
                                    : (themeMode == 'amoled'
                                        ? 'AMOLED黑'
                                        : '暗色')),
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                      FilledButton.tonal(
                        onPressed: () async {
                          final picked = await showDialog<String>(
                            context: context,
                            builder: (ctx) {
                              String temp = themeMode;
                              return AlertDialog(
                                title: const Text('选择主题'),
                                content: StatefulBuilder(
                                  builder: (c, s) {
                                    return RadioGroup<String>(
                                      groupValue: temp,
                                      onChanged: (v) {
                                        if (v != null) s(() => temp = v);
                                      },
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          RadioListTile(
                                            value: 'system',
                                            title: Text('跟随系统'),
                                          ),
                                          RadioListTile(
                                            value: 'light',
                                            title: Text('亮色'),
                                          ),
                                          RadioListTile(
                                            value: 'dark',
                                            title: Text('暗色'),
                                          ),
                                          RadioListTile(
                                            value: 'amoled',
                                            title: Text('AMOLED黑'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('取消'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(ctx, temp),
                                    child: const Text('确定'),
                                  ),
                                ],
                              );
                            },
                          );
                          if (picked != null) {
                            setState(() => themeMode = picked);
                            await StorageService.saveSetting(
                              'theme',
                              themeMode,
                            );
                          }
                        },
                        child: const Text('修改'),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '主题色',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Color(primaryColorValue),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: cs.outline, width: 1),
                            ),
                          ),
                        ],
                      ),
                      FilledButton.tonal(
                        onPressed: () => _showColorPicker(context),
                        child: const Text('选择'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 数据管理组
          Text(
            '数据管理',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            color: cs.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ClassManagementPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.category),
                    label: const Text('编辑分类'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ExportPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.download),
                    label: const Text('导出数据（ZIP）'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.any,
                        allowMultiple: false,
                        withData: true,
                      );
                      if (result == null || result.files.isEmpty) return;
                      final pf = result.files.single;
                      try {
                        String zipPath;
                        if (pf.path != null &&
                            !pf.path!.startsWith('content://')) {
                          zipPath = pf.path!;
                        } else if (pf.bytes != null) {
                          final tempDir = Directory.systemTemp;
                          final tempFile = File(
                            '${tempDir.path}/${pf.name}',
                          );
                          await tempFile.writeAsBytes(pf.bytes!);
                          zipPath = tempFile.path;
                        } else {
                          return;
                        }
                        final count =
                            await ExportService.importFromZip(zipPath);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('成功导入 $count 个条目'),
                          ),
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('导入失败: $e')),
                        );
                      }
                    },
                    icon: const Icon(Icons.upload),
                    label: const Text('导入数据（ZIP）'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final f = await ExportService.exportAllToZip();
                      if (!await f.exists()) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('导出失败，无法上传')),
                        );
                        return;
                      }
                      final fileName = f.uri.pathSegments.last;
                      var base = webdavUrl.trim();
                      var remote = webdavRemotePath.trim();
                      if (base.endsWith('/')) {
                        base = base.substring(0, base.length - 1);
                      }
                      if (!remote.startsWith('/')) {
                        remote = '/$remote';
                      }
                      if (!remote.endsWith('/')) remote = '$remote/';
                      final full = '$base$remote$fileName';
                      final ok = await WebDavService.uploadFile(
                        full,
                        username: webdavUser,
                        password: webdavPass,
                        file: f,
                      );
                      if (ok) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(
                            const SnackBar(content: Text('上传成功')));
                      } else {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(
                            const SnackBar(content: Text('上传失败')));
                      }
                    },
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text('上传到 WebDAV'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _webdavDownload,
                    icon: const Icon(Icons.cloud_download),
                    label: const Text('从 WebDAV 下载'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            color: cs.surfaceContainerLow,
            child: InkWell(
              onTap: () async {
                final urlCtrl = TextEditingController(text: webdavUrl);
                final userCtrl = TextEditingController(text: webdavUser);
                final passCtrl = TextEditingController(text: webdavPass);
                final pathCtrl = TextEditingController(text: webdavRemotePath);
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) {
                    return AlertDialog(
                      title: const Text('WebDAV 设置'),
                      content: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: urlCtrl,
                              decoration: const InputDecoration(
                                labelText:
                                    '服务器地址（例如 https://webdav.example.com）',
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: pathCtrl,
                              decoration: const InputDecoration(
                                labelText: '远程目录（例如 /remote.php/webdav/）',
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: userCtrl,
                              decoration: const InputDecoration(
                                labelText: '用户名（可选）',
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: passCtrl,
                              decoration: const InputDecoration(
                                labelText: '密码（可选）',
                              ),
                              obscureText: true,
                            ),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('取消'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('保存'),
                        ),
                      ],
                    );
                  },
                );
                if (ok == true) {
                  webdavUrl = urlCtrl.text.trim();
                  webdavUser = userCtrl.text.trim();
                  webdavPass = passCtrl.text;
                  webdavRemotePath = pathCtrl.text.trim();
                  await StorageService.saveSetting('webdavUrl', webdavUrl);
                  await StorageService.saveSetting('webdavUser', webdavUser);
                  await StorageService.saveSetting('webdavPass', webdavPass);
                  await StorageService.saveSetting(
                    'webdavRemotePath',
                    webdavRemotePath,
                  );
                  setState(() {});
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'WebDAV 配置',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          webdavUrl.isNotEmpty ? webdavUrl : '未配置',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    Icon(Icons.edit, color: cs.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            color: cs.errorContainer.withValues(alpha: 0.3),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cs.error,
                    ),
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('确认删除'),
                          content: const Text(
                            '确定要删除当前学年的所有数据吗？此操作不可恢复。',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('取消'),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: cs.error,
                              ),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('删除'),
                            ),
                          ],
                        ),
                      );
                      if (ok != true) return;
                      final sy = selectedSchoolYearStart;
                      if (sy != null) {
                        await StorageService.deleteEntriesBySchoolYear(
                          sy,
                          startMonth,
                        );
                      } else {
                        final now = DateTime.now();
                        final cur = (now.month >= startMonth)
                            ? now.year
                            : now.year - 1;
                        await StorageService.deleteEntriesBySchoolYear(
                          cur,
                          startMonth,
                        );
                      }
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('当前学年数据已删除')),
                      );
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('删除当前学年数据'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cs.error,
                    ),
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('确认删除所有数据'),
                          content: const Text(
                            '确定要删除所有数据吗？此操作不可恢复。',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('取消'),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: cs.error,
                              ),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('删除所有'),
                            ),
                          ],
                        ),
                      );
                      if (ok != true) return;
                      await StorageService.deleteAllEntries();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('所有数据已删除')),
                      );
                    },
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('删除所有数据'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
