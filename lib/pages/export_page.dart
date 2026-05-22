import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:syllogos/services/export_service.dart';
import 'package:syllogos/services/storage_service.dart';

class ExportPage extends StatefulWidget {
  const ExportPage({super.key});

  @override
  State<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends State<ExportPage> {
  int startMonth = 9;
  List<int> availableYears = [];
  Set<int> selectedYears = {};
  bool _selectAll = true;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    final s = StorageService.getSettings();
    if (s.containsKey('startMonth')) startMonth = s['startMonth'];
    availableYears = StorageService.getAvailableSchoolYears(startMonth)
        .where((y) => _entryCountForYear(y) > 0)
        .toList();
    selectedYears = Set.from(availableYears);
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectAll) {
        selectedYears.clear();
      } else {
        selectedYears = Set.from(availableYears);
      }
      _selectAll = !_selectAll;
    });
  }

  Future<void> _export() async {
    if (selectedYears.isEmpty) return;
    setState(() => _exporting = true);
    try {
      final file = await ExportService.exportToZip(
        filename: 'syllogos_export',
        schoolYearStarts: selectedYears.toList(),
        startMonth: startMonth,
      );
      final bytes = await file.readAsBytes();
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: '选择保存位置',
        fileName: 'syllogos_export.zip',
        bytes: bytes,
      );
      if (savePath == null) {
        setState(() => _exporting = false);
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('导出成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('导出数据'),
        actions: [
          if (availableYears.isNotEmpty)
            IconButton(
              onPressed: _toggleSelectAll,
              icon: Icon(_selectAll ? Icons.deselect : Icons.select_all),
              tooltip: _selectAll ? '全不选' : '全选',
            ),
        ],
      ),
      body: availableYears.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 64, color: cs.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text(
                    '没有可导出的数据',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: availableYears.map((year) {
                final label =
                    '${year}年$startMonth月 ~ ${year + 1}年$startMonth月';
                return Card(
                  color: cs.surfaceContainerLow,
                  child: CheckboxListTile(
                    value: selectedYears.contains(year),
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          selectedYears.add(year);
                        } else {
                          selectedYears.remove(year);
                        }
                        _selectAll =
                            selectedYears.length == availableYears.length;
                      });
                    },
                    title: Text(label),
                    subtitle: Text(
                      '${_entryCountForYear(year)} 个条目',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                );
              }).toList(),
            ),
      bottomNavigationBar: availableYears.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: _exporting || selectedYears.isEmpty
                      ? null
                      : _export,
                  icon: _exporting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download),
                  label: Text(
                    _exporting
                        ? '导出中...'
                        : '导出 (${selectedYears.length})',
                  ),
                ),
              ),
            )
          : null,
    );
  }

  int _entryCountForYear(int year) {
    final all = StorageService.getAllEntries();
    int count = 0;
    for (final e in all) {
      final sy = StorageService.getEntrySchoolYearStart(e, startMonth);
      if (sy == year) count++;
    }
    return count;
  }
}
