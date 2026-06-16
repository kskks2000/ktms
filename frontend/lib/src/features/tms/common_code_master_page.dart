import 'package:flutter/material.dart';

import '../../design/app_theme.dart';
import '../../design/numeric_input_formatters.dart';
import 'master_api.dart';

class CommonCodeMasterPage extends StatefulWidget {
  const CommonCodeMasterPage({super.key, this.compact = false});

  final bool compact;

  @override
  State<CommonCodeMasterPage> createState() => _CommonCodeMasterPageState();
}

class _CommonCodeMasterPageState extends State<CommonCodeMasterPage> {
  final _groupCodeController = TextEditingController();
  final _groupNameController = TextEditingController();
  final _groupDescriptionController = TextEditingController();
  final _codeController = TextEditingController();
  final _codeNameController = TextEditingController();
  final _codeValueController = TextEditingController();
  final _sortOrderController = TextEditingController();
  final _appliesToController = TextEditingController();
  final _memoController = TextEditingController();

  late final List<_CommonCodeRecord> _records;
  _CodeFamily? _familyFilter;
  _CodeFamily _selectedFamily = _CodeFamily.audit;
  String _statusFilter = 'ALL';
  String _query = '';
  int? _selectedId;
  bool _isActive = true;
  bool _isDefault = false;
  bool _isSystem = false;

  @override
  void initState() {
    super.initState();
    _records = List<_CommonCodeRecord>.from(_seedCommonCodes);
    _selectRecord(_records.first, notify: false);
  }

  @override
  void dispose() {
    _groupCodeController.dispose();
    _groupNameController.dispose();
    _groupDescriptionController.dispose();
    _codeController.dispose();
    _codeNameController.dispose();
    _codeValueController.dispose();
    _sortOrderController.dispose();
    _appliesToController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  List<_CommonCodeRecord> get _filteredRecords {
    final normalizedQuery = _query.trim().toLowerCase();
    return _records.where((record) {
      final matchesFamily =
          _familyFilter == null || record.family == _familyFilter;
      final matchesStatus =
          _statusFilter == 'ALL' ||
          (_statusFilter == 'ACTIVE' && record.isActive) ||
          (_statusFilter == 'INACTIVE' && !record.isActive) ||
          (_statusFilter == 'DEFAULT' && record.isDefault) ||
          (_statusFilter == 'SYSTEM' && record.isSystem);
      final matchesQuery =
          normalizedQuery.isEmpty ||
          record.groupCode.toLowerCase().contains(normalizedQuery) ||
          record.groupName.toLowerCase().contains(normalizedQuery) ||
          record.code.toLowerCase().contains(normalizedQuery) ||
          record.codeName.toLowerCase().contains(normalizedQuery) ||
          record.codeValue.toLowerCase().contains(normalizedQuery);
      return matchesFamily && matchesStatus && matchesQuery;
    }).toList();
  }

  _CommonCodeRecord? get _selectedRecord {
    for (final record in _records) {
      if (record.id == _selectedId) {
        return record;
      }
    }
    return null;
  }

  void _selectRecord(_CommonCodeRecord record, {bool notify = true}) {
    void apply() {
      _selectedId = record.id;
      _selectedFamily = record.family;
      _groupCodeController.text = record.groupCode;
      _groupNameController.text = record.groupName;
      _groupDescriptionController.text = record.groupDescription;
      _codeController.text = record.code;
      _codeNameController.text = record.codeName;
      _codeValueController.text = record.codeValue;
      _sortOrderController.text = record.sortOrder.toString();
      _appliesToController.text = record.appliesTo;
      _memoController.text = record.memo;
      _isActive = record.isActive;
      _isDefault = record.isDefault;
      _isSystem = record.isSystem;
    }

    if (notify) {
      setState(apply);
    } else {
      apply();
    }
  }

  void _clearEditor() {
    final family = _familyFilter ?? _CodeFamily.audit;
    _selectedId = null;
    _selectedFamily = family;
    _groupCodeController.text = family.defaultGroupCode;
    _groupNameController.text = family.defaultGroupName;
    _groupDescriptionController.text = family.description;
    _codeController.text = _nextCode(family);
    _codeNameController.clear();
    _codeValueController.clear();
    _sortOrderController.text = '10';
    _appliesToController.text = family.appliesTo;
    _memoController.clear();
    _isActive = true;
    _isDefault = false;
    _isSystem = family.systemDefault;
  }

  String _nextCode(_CodeFamily family) {
    final count =
        _records.where((record) => record.family == family).length + 1;
    return '${family.prefix}_${count.toString().padLeft(2, '0')}';
  }

  void _startCreate() {
    setState(_clearEditor);
  }

  void _applyFamily(_CodeFamily family) {
    setState(() {
      _selectedFamily = family;
      if (_selectedId == null) {
        _groupCodeController.text = family.defaultGroupCode;
        _groupNameController.text = family.defaultGroupName;
        _groupDescriptionController.text = family.description;
        _codeController.text = _nextCode(family);
        _appliesToController.text = family.appliesTo;
        _isSystem = family.systemDefault;
      }
    });
  }

  Future<void> _saveRecord() async {
    final groupCode = _groupCodeController.text.trim().toUpperCase();
    final groupName = _groupNameController.text.trim();
    final code = _codeController.text.trim().toUpperCase();
    final codeName = _codeNameController.text.trim();

    if (groupCode.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('그룹 코드를 입력하세요.')));
      return;
    }
    if (groupName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('그룹명을 입력하세요.')));
      return;
    }
    if (code.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('코드를 입력하세요.')));
      return;
    }
    if (codeName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('코드명을 입력하세요.')));
      return;
    }

    final record = _CommonCodeRecord(
      id: _selectedId ?? _nextRecordId(),
      family: _selectedFamily,
      groupCode: groupCode,
      groupName: groupName,
      groupDescription: _groupDescriptionController.text.trim(),
      code: code,
      codeName: codeName,
      codeValue: _codeValueController.text.trim(),
      sortOrder: int.tryParse(_sortOrderController.text.trim()) ?? 0,
      isDefault: _isDefault,
      isSystem: _isSystem,
      isActive: _isActive,
      appliesTo: _appliesToController.text.trim(),
      memo: _memoController.text.trim(),
    );

    setState(() {
      final index = _records.indexWhere((item) => item.id == record.id);
      if (index == -1) {
        _records.insert(0, record);
      } else {
        _records[index] = record;
      }
      if (record.isDefault) {
        for (var index = 0; index < _records.length; index += 1) {
          final item = _records[index];
          if (item.id != record.id && item.groupCode == record.groupCode) {
            _records[index] = item.copyWith(isDefault: false);
          }
        }
      }
      _selectedId = record.id;
    });

    final result = await MasterApi.instance.saveCommonCode(
      record.toApiPayload(),
    );
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.failed
              ? '${record.codeName} 공통코드 화면 반영 완료, DB 저장 실패: ${result.message}'
              : '${record.codeName} 공통코드 마스터가 반영되었습니다.',
        ),
      ),
    );
  }

  int _nextRecordId() {
    return _records.map((record) => record.id).reduce((a, b) => a > b ? a : b) +
        1;
  }

  @override
  Widget build(BuildContext context) {
    final filteredRecords = _filteredRecords;
    final selectedRecord = _selectedRecord;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1140 && !widget.compact;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            widget.compact ? 16 : 24,
            widget.compact ? 18 : 22,
            widget.compact ? 16 : 24,
            widget.compact ? 90 : 28,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CommonCodeHeader(onCreate: _startCreate),
              const SizedBox(height: 16),
              _CommonCodeStats(records: _records),
              const SizedBox(height: 16),
              _CodeFamilySelector(
                selectedFamily: _familyFilter,
                counts: {
                  for (final family in _CodeFamily.values)
                    family: _records
                        .where((record) => record.family == family)
                        .length,
                },
                onSelect: (family) => setState(() {
                  _familyFilter = _familyFilter == family ? null : family;
                  final records = _filteredRecords;
                  if (records.isNotEmpty) {
                    _selectRecord(records.first, notify: false);
                  }
                }),
              ),
              const SizedBox(height: 12),
              _CommonCodeToolbar(
                query: _query,
                statusFilter: _statusFilter,
                onQueryChanged: (value) => setState(() => _query = value),
                onStatusChanged: (value) =>
                    setState(() => _statusFilter = value),
              ),
              const SizedBox(height: 16),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 6,
                      child: _CommonCodeDirectoryPanel(
                        records: filteredRecords,
                        selectedId: _selectedId,
                        onSelect: _selectRecord,
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 468,
                      child: _CommonCodeEditorPanel(
                        selectedRecord: selectedRecord,
                        groupCodeController: _groupCodeController,
                        groupNameController: _groupNameController,
                        groupDescriptionController: _groupDescriptionController,
                        codeController: _codeController,
                        codeNameController: _codeNameController,
                        codeValueController: _codeValueController,
                        sortOrderController: _sortOrderController,
                        appliesToController: _appliesToController,
                        memoController: _memoController,
                        selectedFamily: _selectedFamily,
                        isActive: _isActive,
                        isDefault: _isDefault,
                        isSystem: _isSystem,
                        onFamilyChanged: _applyFamily,
                        onActiveChanged: (value) =>
                            setState(() => _isActive = value),
                        onDefaultChanged: (value) =>
                            setState(() => _isDefault = value),
                        onSystemChanged: (value) =>
                            setState(() => _isSystem = value),
                        onSave: _saveRecord,
                      ),
                    ),
                  ],
                )
              else ...[
                _CommonCodeDirectoryPanel(
                  records: filteredRecords,
                  selectedId: _selectedId,
                  onSelect: _selectRecord,
                ),
                const SizedBox(height: 16),
                _CommonCodeEditorPanel(
                  selectedRecord: selectedRecord,
                  groupCodeController: _groupCodeController,
                  groupNameController: _groupNameController,
                  groupDescriptionController: _groupDescriptionController,
                  codeController: _codeController,
                  codeNameController: _codeNameController,
                  codeValueController: _codeValueController,
                  sortOrderController: _sortOrderController,
                  appliesToController: _appliesToController,
                  memoController: _memoController,
                  selectedFamily: _selectedFamily,
                  isActive: _isActive,
                  isDefault: _isDefault,
                  isSystem: _isSystem,
                  onFamilyChanged: _applyFamily,
                  onActiveChanged: (value) => setState(() => _isActive = value),
                  onDefaultChanged: (value) =>
                      setState(() => _isDefault = value),
                  onSystemChanged: (value) => setState(() => _isSystem = value),
                  onSave: _saveRecord,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _CommonCodeHeader extends StatelessWidget {
  const _CommonCodeHeader({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.tune_rounded,
              color: Color(0xFF2563EB),
              size: 27,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '공통코드 마스터',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.graphite,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'TMS 전 영역의 상태, 유형, 채널, 권한, 정산 기준 코드를 통합 관리합니다.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.slate,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_box_rounded, size: 19),
            label: const Text('코드 등록'),
          ),
        ],
      ),
    );
  }
}

class _CommonCodeStats extends StatelessWidget {
  const _CommonCodeStats({required this.records});

  final List<_CommonCodeRecord> records;

  @override
  Widget build(BuildContext context) {
    final groupCount = records.map((record) => record.groupCode).toSet().length;
    final active = records.where((record) => record.isActive).length;
    final system = records.where((record) => record.isSystem).length;
    final defaults = records.where((record) => record.isDefault).length;

    final metrics = [
      _CodeMetric(
        label: '코드 그룹',
        value: groupCount.toString(),
        icon: Icons.folder_copy_rounded,
        color: const Color(0xFF2563EB),
      ),
      _CodeMetric(
        label: '활성 코드',
        value: active.toString(),
        icon: Icons.verified_rounded,
        color: AppTheme.teal,
      ),
      _CodeMetric(
        label: '시스템 그룹',
        value: system.toString(),
        icon: Icons.security_rounded,
        color: const Color(0xFF7C3AED),
      ),
      _CodeMetric(
        label: '기본 코드',
        value: defaults.toString(),
        icon: Icons.star_rounded,
        color: AppTheme.amber,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 820;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: compact ? 2 : 4,
            mainAxisExtent: 96,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: metrics.length,
          itemBuilder: (context, index) =>
              _CodeMetricCard(metric: metrics[index]),
        );
      },
    );
  }
}

class _CodeFamilySelector extends StatelessWidget {
  const _CodeFamilySelector({
    required this.selectedFamily,
    required this.counts,
    required this.onSelect,
  });

  final _CodeFamily? selectedFamily;
  final Map<_CodeFamily, int> counts;
  final ValueChanged<_CodeFamily> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _CodeFamily.values.map((family) {
        final selected = selectedFamily == family;
        return ChoiceChip(
          avatar: Icon(
            family.icon,
            size: 17,
            color: selected ? family.color : AppTheme.slate,
          ),
          label: Text('${family.label} ${counts[family] ?? 0}'),
          selected: selected,
          selectedColor: family.color.withValues(alpha: 0.12),
          checkmarkColor: family.color,
          onSelected: (_) => onSelect(family),
          labelStyle: TextStyle(
            color: selected ? family.color : AppTheme.slate,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        );
      }).toList(),
    );
  }
}

class _CommonCodeToolbar extends StatelessWidget {
  const _CommonCodeToolbar({
    required this.query,
    required this.statusFilter,
    required this.onQueryChanged,
    required this.onStatusChanged,
  });

  final String query;
  final String statusFilter;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.line),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 380,
            child: TextField(
              onChanged: onQueryChanged,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: '그룹 코드, 코드, 코드명, 코드값',
              ),
            ),
          ),
          ...[
            const MapEntry('ALL', '전체'),
            const MapEntry('ACTIVE', '사용 중'),
            const MapEntry('INACTIVE', '비활성'),
            const MapEntry('DEFAULT', '기본'),
            const MapEntry('SYSTEM', '시스템'),
          ].map(
            (entry) => ChoiceChip(
              label: Text(entry.value),
              selected: statusFilter == entry.key,
              selectedColor: AppTheme.teal.withValues(alpha: 0.12),
              checkmarkColor: AppTheme.teal,
              onSelected: (_) => onStatusChanged(entry.key),
              labelStyle: TextStyle(
                color: statusFilter == entry.key
                    ? AppTheme.teal
                    : AppTheme.slate,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommonCodeDirectoryPanel extends StatelessWidget {
  const _CommonCodeDirectoryPanel({
    required this.records,
    required this.selectedId,
    required this.onSelect,
  });

  final List<_CommonCodeRecord> records;
  final int? selectedId;
  final ValueChanged<_CommonCodeRecord> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelTitle(
            icon: Icons.tune_rounded,
            title: '공통코드 기준정보',
            subtitle: 'code_groups / codes',
          ),
          if (records.isEmpty)
            const _EmptyState()
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AppTheme.panel),
                columns: const [
                  DataColumn(label: Text('그룹')),
                  DataColumn(label: Text('그룹명')),
                  DataColumn(label: Text('코드')),
                  DataColumn(label: Text('코드명')),
                  DataColumn(label: Text('코드값')),
                  DataColumn(label: Text('순서')),
                  DataColumn(label: Text('속성')),
                  DataColumn(label: Text('상태')),
                ],
                rows: records
                    .map(
                      (record) => DataRow(
                        selected: selectedId == record.id,
                        onSelectChanged: (_) => onSelect(record),
                        cells: [
                          DataCell(_StrongText(record.groupCode)),
                          DataCell(Text(record.groupName)),
                          DataCell(_StrongText(record.code)),
                          DataCell(Text(record.codeName)),
                          DataCell(Text(record.codeValue)),
                          DataCell(Text(record.sortOrder.toString())),
                          DataCell(_CodeFlags(record: record)),
                          DataCell(_StatusPill(record: record)),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _CommonCodeEditorPanel extends StatelessWidget {
  const _CommonCodeEditorPanel({
    required this.selectedRecord,
    required this.groupCodeController,
    required this.groupNameController,
    required this.groupDescriptionController,
    required this.codeController,
    required this.codeNameController,
    required this.codeValueController,
    required this.sortOrderController,
    required this.appliesToController,
    required this.memoController,
    required this.selectedFamily,
    required this.isActive,
    required this.isDefault,
    required this.isSystem,
    required this.onFamilyChanged,
    required this.onActiveChanged,
    required this.onDefaultChanged,
    required this.onSystemChanged,
    required this.onSave,
  });

  final _CommonCodeRecord? selectedRecord;
  final TextEditingController groupCodeController;
  final TextEditingController groupNameController;
  final TextEditingController groupDescriptionController;
  final TextEditingController codeController;
  final TextEditingController codeNameController;
  final TextEditingController codeValueController;
  final TextEditingController sortOrderController;
  final TextEditingController appliesToController;
  final TextEditingController memoController;
  final _CodeFamily selectedFamily;
  final bool isActive;
  final bool isDefault;
  final bool isSystem;
  final ValueChanged<_CodeFamily> onFamilyChanged;
  final ValueChanged<bool> onActiveChanged;
  final ValueChanged<bool> onDefaultChanged;
  final ValueChanged<bool> onSystemChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _PanelTitle(
                  icon: Icons.rule_folder_rounded,
                  title: selectedRecord == null ? '신규 코드 등록' : '코드 상세',
                  subtitle: selectedRecord?.code ?? 'code_groups / codes',
                  compact: true,
                ),
              ),
              Switch(value: isActive, onChanged: onActiveChanged),
            ],
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<_CodeFamily>(
            initialValue: selectedFamily,
            decoration: const InputDecoration(
              labelText: '코드 영역',
              prefixIcon: Icon(Icons.account_tree_rounded),
            ),
            items: _CodeFamily.values
                .map(
                  (family) => DropdownMenuItem(
                    value: family,
                    child: Text(family.label),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                onFamilyChanged(value);
              }
            },
          ),
          const SizedBox(height: 12),
          _EditorGrid(
            children: [
              _CodeTextField(
                controller: groupCodeController,
                label: '그룹 코드',
                icon: Icons.folder_rounded,
              ),
              _CodeTextField(
                controller: groupNameController,
                label: '그룹명',
                icon: Icons.drive_file_rename_outline_rounded,
              ),
              _CodeTextField(
                controller: codeController,
                label: '코드',
                icon: Icons.tag_rounded,
              ),
              _CodeTextField(
                controller: codeNameController,
                label: '코드명',
                icon: Icons.label_rounded,
              ),
              _CodeTextField(
                controller: codeValueController,
                label: '코드값',
                icon: Icons.data_object_rounded,
              ),
              _CodeTextField(
                controller: sortOrderController,
                label: '정렬 순서',
                icon: Icons.sort_rounded,
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: groupDescriptionController,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '그룹 설명',
              prefixIcon: Icon(Icons.description_rounded),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: appliesToController,
            decoration: const InputDecoration(
              labelText: '적용 화면/테이블',
              prefixIcon: Icon(Icons.view_module_rounded),
            ),
          ),
          const SizedBox(height: 10),
          _SwitchTile(
            label: '기본 코드',
            value: isDefault,
            onChanged: onDefaultChanged,
            icon: Icons.star_rounded,
          ),
          _SwitchTile(
            label: '시스템 그룹',
            value: isSystem,
            onChanged: onSystemChanged,
            icon: Icons.security_rounded,
          ),
          const SizedBox(height: 4),
          TextField(
            controller: memoController,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: '운영 메모',
              prefixIcon: Icon(Icons.edit_note_rounded),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onSave,
            icon: const Icon(Icons.save_rounded),
            label: const Text('저장'),
          ),
        ],
      ),
    );
  }
}

class _EditorGrid extends StatelessWidget {
  const _EditorGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 640 ? 2 : 1;
        final itemWidth =
            (constraints.maxWidth - ((columns - 1) * 10)) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: children
              .map((child) => SizedBox(width: itemWidth, child: child))
              .toList(),
        );
      },
    );
  }
}

class _CodeTextField extends StatelessWidget {
  const _CodeTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: KtmsNumericInputFormatters.forKeyboardType(
        keyboardType,
        label: label,
      ),
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.icon,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        children: [
          Icon(icon, color: value ? AppTheme.teal : AppTheme.slate, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.graphite,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _PanelTitle extends StatelessWidget {
  const _PanelTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(compact ? 0 : 16),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.teal, size: compact ? 20 : 22),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.graphite,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.slate,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeMetricCard extends StatelessWidget {
  const _CodeMetricCard({required this.metric});

  final _CodeMetric metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: metric.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(metric.icon, color: metric.color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.graphite,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                Text(
                  metric.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.slate,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeFlags extends StatelessWidget {
  const _CodeFlags({required this.record});

  final _CommonCodeRecord record;

  @override
  Widget build(BuildContext context) {
    final flags = <Widget>[
      if (record.isDefault)
        const _TinyFlag(icon: Icons.star_rounded, label: '기본'),
      if (record.isSystem)
        const _TinyFlag(icon: Icons.security_rounded, label: '시스템'),
    ];
    if (flags.isEmpty) {
      return const Text('일반');
    }
    return Wrap(spacing: 6, runSpacing: 6, children: flags);
  }
}

class _TinyFlag extends StatelessWidget {
  const _TinyFlag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.teal),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.slate,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.record});

  final _CommonCodeRecord record;

  @override
  Widget build(BuildContext context) {
    final color = record.isActive ? AppTheme.teal : AppTheme.slate;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        record.isActive ? '사용 중' : '비활성',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 12,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _StrongText extends StatelessWidget {
  const _StrongText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.graphite,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      child: const Text(
        '조회된 공통코드 기준정보가 없습니다.',
        style: TextStyle(color: AppTheme.slate, letterSpacing: 0),
      ),
    );
  }
}

enum _CodeFamily {
  audit,
  partner,
  order,
  execution,
  settlement,
  asset,
  access;

  String get code => switch (this) {
    _CodeFamily.audit => 'AUDIT',
    _CodeFamily.partner => 'PARTNER',
    _CodeFamily.order => 'ORDER',
    _CodeFamily.execution => 'EXECUTION',
    _CodeFamily.settlement => 'SETTLEMENT',
    _CodeFamily.asset => 'ASSET',
    _CodeFamily.access => 'ACCESS',
  };

  String get label => switch (this) {
    _CodeFamily.audit => '감사/채널',
    _CodeFamily.partner => '거래처',
    _CodeFamily.order => '오더',
    _CodeFamily.execution => '실행',
    _CodeFamily.settlement => '정산',
    _CodeFamily.asset => '자산',
    _CodeFamily.access => '권한',
  };

  String get prefix => switch (this) {
    _CodeFamily.audit => 'CH',
    _CodeFamily.partner => 'PT',
    _CodeFamily.order => 'OD',
    _CodeFamily.execution => 'EX',
    _CodeFamily.settlement => 'ST',
    _CodeFamily.asset => 'AS',
    _CodeFamily.access => 'AC',
  };

  String get defaultGroupCode => switch (this) {
    _CodeFamily.audit => 'ACTION_CHANNEL',
    _CodeFamily.partner => 'PARTNER_TYPE',
    _CodeFamily.order => 'TRANSPORT_ORDER_STATUS',
    _CodeFamily.execution => 'EXECUTION_EVENT_TYPE',
    _CodeFamily.settlement => 'SETTLEMENT_STATUS',
    _CodeFamily.asset => 'VEHICLE_STATUS',
    _CodeFamily.access => 'USER_STATUS',
  };

  String get defaultGroupName => switch (this) {
    _CodeFamily.audit => '생성/수정 채널',
    _CodeFamily.partner => '거래처 유형',
    _CodeFamily.order => '운송오더 상태',
    _CodeFamily.execution => '운송 실행 이벤트',
    _CodeFamily.settlement => '정산 상태',
    _CodeFamily.asset => '차량 상태',
    _CodeFamily.access => '사용자 상태',
  };

  String get description => switch (this) {
    _CodeFamily.audit => '데이터 생성과 수정이 발생한 화면, 연동, 모바일 채널',
    _CodeFamily.partner => '고객사, 화주, 운송사 등 거래처 분류 기준',
    _CodeFamily.order => '운송오더 수명주기와 업무 단계 상태',
    _CodeFamily.execution => '출발, 도착, 완료, 예외 등 실행 이벤트',
    _CodeFamily.settlement => '실적 확정, 매출/매입 정산, 거래명세서 상태',
    _CodeFamily.asset => '차량, 기사, 창고, 거점의 운영 상태',
    _CodeFamily.access => '사용자 계정, 역할, 권한 운영 상태',
  };

  String get appliesTo => switch (this) {
    _CodeFamily.audit => 'all_master_tables',
    _CodeFamily.partner => 'business_partners',
    _CodeFamily.order => 'transport_orders',
    _CodeFamily.execution => 'shipment_events',
    _CodeFamily.settlement => 'settlements, invoices',
    _CodeFamily.asset => 'vehicles, drivers, locations',
    _CodeFamily.access => 'app_users, roles, permissions',
  };

  bool get systemDefault => switch (this) {
    _CodeFamily.audit => true,
    _CodeFamily.partner => true,
    _CodeFamily.order => true,
    _CodeFamily.execution => false,
    _CodeFamily.settlement => false,
    _CodeFamily.asset => false,
    _CodeFamily.access => true,
  };

  IconData get icon => switch (this) {
    _CodeFamily.audit => Icons.hub_rounded,
    _CodeFamily.partner => Icons.business_rounded,
    _CodeFamily.order => Icons.playlist_add_check_rounded,
    _CodeFamily.execution => Icons.route_rounded,
    _CodeFamily.settlement => Icons.receipt_long_rounded,
    _CodeFamily.asset => Icons.local_shipping_rounded,
    _CodeFamily.access => Icons.admin_panel_settings_rounded,
  };

  Color get color => switch (this) {
    _CodeFamily.audit => const Color(0xFF2563EB),
    _CodeFamily.partner => AppTheme.teal,
    _CodeFamily.order => AppTheme.cyan,
    _CodeFamily.execution => const Color(0xFF16A34A),
    _CodeFamily.settlement => AppTheme.amber,
    _CodeFamily.asset => const Color(0xFF7C3AED),
    _CodeFamily.access => const Color(0xFF0891B2),
  };
}

class _CommonCodeRecord {
  const _CommonCodeRecord({
    required this.id,
    required this.family,
    required this.groupCode,
    required this.groupName,
    required this.groupDescription,
    required this.code,
    required this.codeName,
    required this.codeValue,
    required this.sortOrder,
    required this.isDefault,
    required this.isSystem,
    required this.isActive,
    required this.appliesTo,
    required this.memo,
  });

  final int id;
  final _CodeFamily family;
  final String groupCode;
  final String groupName;
  final String groupDescription;
  final String code;
  final String codeName;
  final String codeValue;
  final int sortOrder;
  final bool isDefault;
  final bool isSystem;
  final bool isActive;
  final String appliesTo;
  final String memo;

  _CommonCodeRecord copyWith({bool? isDefault}) {
    return _CommonCodeRecord(
      id: id,
      family: family,
      groupCode: groupCode,
      groupName: groupName,
      groupDescription: groupDescription,
      code: code,
      codeName: codeName,
      codeValue: codeValue,
      sortOrder: sortOrder,
      isDefault: isDefault ?? this.isDefault,
      isSystem: isSystem,
      isActive: isActive,
      appliesTo: appliesTo,
      memo: memo,
    );
  }

  Map<String, Object?> toApiPayload() {
    return {
      'group_code': groupCode,
      'group_name': groupName,
      'group_description': groupDescription,
      'code': code,
      'code_name': codeName,
      'code_value': codeValue,
      'sort_order': sortOrder,
      'is_default': isDefault,
      'group_is_system': isSystem,
      'is_active': isActive,
      'metadata': {
        'code_family': family.code,
        'applies_to': appliesTo,
        'memo': memo,
      },
    };
  }
}

class _CodeMetric {
  const _CodeMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

const _seedCommonCodes = [
  _CommonCodeRecord(
    id: 1,
    family: _CodeFamily.audit,
    groupCode: 'ACTION_CHANNEL',
    groupName: '생성/수정 채널',
    groupDescription: '사용자 또는 연동 시스템이 데이터를 생성/수정한 채널입니다.',
    code: 'WEB',
    codeName: '웹 콘솔',
    codeValue: 'web',
    sortOrder: 10,
    isDefault: true,
    isSystem: true,
    isActive: true,
    appliesTo: 'all_master_tables',
    memo: '관리자와 운영자가 사용하는 웹 화면',
  ),
  _CommonCodeRecord(
    id: 2,
    family: _CodeFamily.audit,
    groupCode: 'ACTION_CHANNEL',
    groupName: '생성/수정 채널',
    groupDescription: '사용자 또는 연동 시스템이 데이터를 생성/수정한 채널입니다.',
    code: 'MOBILE',
    codeName: '모바일 앱',
    codeValue: 'mobile',
    sortOrder: 20,
    isDefault: false,
    isSystem: true,
    isActive: true,
    appliesTo: 'all_master_tables',
    memo: '기사 앱과 현장 모바일',
  ),
  _CommonCodeRecord(
    id: 3,
    family: _CodeFamily.audit,
    groupCode: 'ACTION_CHANNEL',
    groupName: '생성/수정 채널',
    groupDescription: '사용자 또는 연동 시스템이 데이터를 생성/수정한 채널입니다.',
    code: 'EDI',
    codeName: 'EDI 연동',
    codeValue: 'edi',
    sortOrder: 30,
    isDefault: false,
    isSystem: true,
    isActive: true,
    appliesTo: 'all_master_tables',
    memo: '고객사/운송사 시스템 연동',
  ),
  _CommonCodeRecord(
    id: 4,
    family: _CodeFamily.partner,
    groupCode: 'PARTNER_TYPE',
    groupName: '거래처 유형',
    groupDescription: 'TMS 거래처의 업무상 역할을 구분합니다.',
    code: 'CUSTOMER',
    codeName: '고객사',
    codeValue: 'customer',
    sortOrder: 10,
    isDefault: true,
    isSystem: true,
    isActive: true,
    appliesTo: 'business_partners',
    memo: '매출 청구 대상',
  ),
  _CommonCodeRecord(
    id: 5,
    family: _CodeFamily.partner,
    groupCode: 'PARTNER_TYPE',
    groupName: '거래처 유형',
    groupDescription: 'TMS 거래처의 업무상 역할을 구분합니다.',
    code: 'SHIPPER',
    codeName: '화주',
    codeValue: 'shipper',
    sortOrder: 20,
    isDefault: false,
    isSystem: true,
    isActive: true,
    appliesTo: 'business_partners',
    memo: '실제 화물 또는 오더 주체',
  ),
  _CommonCodeRecord(
    id: 6,
    family: _CodeFamily.partner,
    groupCode: 'PARTNER_TYPE',
    groupName: '거래처 유형',
    groupDescription: 'TMS 거래처의 업무상 역할을 구분합니다.',
    code: 'CARRIER',
    codeName: '운송사',
    codeValue: 'carrier',
    sortOrder: 30,
    isDefault: false,
    isSystem: true,
    isActive: true,
    appliesTo: 'business_partners',
    memo: '매입 정산 대상',
  ),
  _CommonCodeRecord(
    id: 7,
    family: _CodeFamily.order,
    groupCode: 'TRANSPORT_ORDER_STATUS',
    groupName: '운송오더 상태',
    groupDescription: '오더 등록 이후 배차, 실행, 정산까지의 상태입니다.',
    code: 'REGISTERED',
    codeName: '등록',
    codeValue: 'registered',
    sortOrder: 10,
    isDefault: true,
    isSystem: true,
    isActive: true,
    appliesTo: 'transport_orders',
    memo: '오더 생성 직후 상태',
  ),
  _CommonCodeRecord(
    id: 8,
    family: _CodeFamily.order,
    groupCode: 'TRANSPORT_ORDER_STATUS',
    groupName: '운송오더 상태',
    groupDescription: '오더 등록 이후 배차, 실행, 정산까지의 상태입니다.',
    code: 'PLANNED',
    codeName: '운송계획',
    codeValue: 'planned',
    sortOrder: 20,
    isDefault: false,
    isSystem: true,
    isActive: true,
    appliesTo: 'transport_orders',
    memo: '편성과 배정이 완료된 계획 상태',
  ),
  _CommonCodeRecord(
    id: 9,
    family: _CodeFamily.execution,
    groupCode: 'EXECUTION_EVENT_TYPE',
    groupName: '운송 실행 이벤트',
    groupDescription: '실행 트래킹에서 발생하는 이벤트 유형입니다.',
    code: 'DEPARTED',
    codeName: '출발',
    codeValue: 'departed',
    sortOrder: 10,
    isDefault: false,
    isSystem: false,
    isActive: true,
    appliesTo: 'shipment_events',
    memo: '상차지 출발 이벤트',
  ),
  _CommonCodeRecord(
    id: 10,
    family: _CodeFamily.execution,
    groupCode: 'EXECUTION_EVENT_TYPE',
    groupName: '운송 실행 이벤트',
    groupDescription: '실행 트래킹에서 발생하는 이벤트 유형입니다.',
    code: 'ARRIVED',
    codeName: '도착',
    codeValue: 'arrived',
    sortOrder: 20,
    isDefault: false,
    isSystem: false,
    isActive: true,
    appliesTo: 'shipment_events',
    memo: '하차지 도착 이벤트',
  ),
  _CommonCodeRecord(
    id: 11,
    family: _CodeFamily.settlement,
    groupCode: 'SETTLEMENT_STATUS',
    groupName: '정산 상태',
    groupDescription: '실적 확정 후 매출/매입 정산 처리 상태입니다.',
    code: 'CONFIRMED',
    codeName: '실적확정',
    codeValue: 'confirmed',
    sortOrder: 10,
    isDefault: false,
    isSystem: false,
    isActive: true,
    appliesTo: 'settlements',
    memo: '운송 완료 실적 검증 완료',
  ),
  _CommonCodeRecord(
    id: 12,
    family: _CodeFamily.asset,
    groupCode: 'VEHICLE_STATUS',
    groupName: '차량 상태',
    groupDescription: '차량 가용성과 배차 가능 여부를 관리합니다.',
    code: 'AVAILABLE',
    codeName: '가용',
    codeValue: 'available',
    sortOrder: 10,
    isDefault: true,
    isSystem: false,
    isActive: true,
    appliesTo: 'vehicles',
    memo: '배차 가능 차량',
  ),
  _CommonCodeRecord(
    id: 13,
    family: _CodeFamily.access,
    groupCode: 'USER_STATUS',
    groupName: '사용자 상태',
    groupDescription: '사용자 계정의 초대, 활성, 잠김 상태입니다.',
    code: 'ACTIVE',
    codeName: '활성',
    codeValue: 'active',
    sortOrder: 10,
    isDefault: true,
    isSystem: true,
    isActive: true,
    appliesTo: 'app_users',
    memo: '로그인 가능한 사용자',
  ),
];
