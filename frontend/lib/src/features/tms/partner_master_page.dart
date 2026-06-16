import 'package:flutter/material.dart';

import '../../design/app_theme.dart';
import 'master_api.dart';

class PartnerMasterPage extends StatefulWidget {
  const PartnerMasterPage({super.key, this.compact = false});

  final bool compact;

  @override
  State<PartnerMasterPage> createState() => _PartnerMasterPageState();
}

class _PartnerMasterPageState extends State<PartnerMasterPage> {
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _shortNameController = TextEditingController();
  final _taxNoController = TextEditingController();
  final _representativeController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _paymentTermsController = TextEditingController();
  final _creditLimitController = TextEditingController();
  final _memoController = TextEditingController();

  late final List<_PartnerRecord> _records;
  _PartnerKind _selectedKind = _PartnerKind.customer;
  String _query = '';
  String _statusFilter = 'ALL';
  int? _selectedId;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    _records = List<_PartnerRecord>.from(_seedPartners);
    _selectRecord(_records.first);
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _shortNameController.dispose();
    _taxNoController.dispose();
    _representativeController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _paymentTermsController.dispose();
    _creditLimitController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  List<_PartnerRecord> get _filteredRecords {
    final normalizedQuery = _query.trim().toLowerCase();
    return _records.where((record) {
      final matchesKind = record.kind == _selectedKind;
      final matchesStatus =
          _statusFilter == 'ALL' || record.statusCode == _statusFilter;
      final matchesQuery =
          normalizedQuery.isEmpty ||
          record.partnerCode.toLowerCase().contains(normalizedQuery) ||
          record.partnerName.toLowerCase().contains(normalizedQuery) ||
          record.partnerShortName.toLowerCase().contains(normalizedQuery) ||
          record.taxRegistrationNo.toLowerCase().contains(normalizedQuery);
      return matchesKind && matchesStatus && matchesQuery;
    }).toList();
  }

  _PartnerRecord? get _selectedRecord {
    for (final record in _records) {
      if (record.id == _selectedId) {
        return record;
      }
    }
    return null;
  }

  void _selectKind(_PartnerKind kind) {
    setState(() {
      _selectedKind = kind;
      _selectedId = null;
      final first = _filteredRecords.firstOrNull;
      if (first == null) {
        _clearEditor(nextCode: _nextCode(kind));
      } else {
        _selectRecord(first, notify: false);
      }
    });
  }

  void _selectRecord(_PartnerRecord record, {bool notify = true}) {
    void apply() {
      _selectedId = record.id;
      _codeController.text = record.partnerCode;
      _nameController.text = record.partnerName;
      _shortNameController.text = record.partnerShortName;
      _taxNoController.text = record.taxRegistrationNo;
      _representativeController.text = record.representativeName;
      _phoneController.text = record.phone;
      _emailController.text = record.email;
      _paymentTermsController.text = record.paymentTerms;
      _creditLimitController.text = record.creditLimit;
      _memoController.text = record.memo;
      _isActive = record.isActive;
    }

    if (notify) {
      setState(apply);
    } else {
      apply();
    }
  }

  void _clearEditor({String? nextCode}) {
    _selectedId = null;
    _codeController.text = nextCode ?? _nextCode(_selectedKind);
    _nameController.clear();
    _shortNameController.clear();
    _taxNoController.clear();
    _representativeController.clear();
    _phoneController.clear();
    _emailController.clear();
    _paymentTermsController.text = '월말 +30일';
    _creditLimitController.text = '0';
    _memoController.clear();
    _isActive = true;
  }

  String _nextCode(_PartnerKind kind) {
    final prefix = switch (kind) {
      _PartnerKind.customer => 'CUST',
      _PartnerKind.shipper => 'SHIP',
      _PartnerKind.carrier => 'CARR',
    };
    final count = _records.where((record) => record.kind == kind).length + 1;
    return '$prefix${count.toString().padLeft(4, '0')}';
  }

  void _startCreate() {
    setState(() => _clearEditor());
  }

  void _saveRecord() async {
    final partnerName = _nameController.text.trim();
    if (partnerName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('거래처명을 입력하세요.')));
      return;
    }

    final record = _PartnerRecord(
      id: _selectedId ?? _nextRecordId(),
      kind: _selectedKind,
      partnerCode: _codeController.text.trim(),
      partnerName: partnerName,
      partnerShortName: _shortNameController.text.trim().isEmpty
          ? partnerName
          : _shortNameController.text.trim(),
      taxRegistrationNo: _taxNoController.text.trim(),
      representativeName: _representativeController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      paymentTerms: _paymentTermsController.text.trim(),
      creditLimit: _creditLimitController.text.trim().isEmpty
          ? '0'
          : _creditLimitController.text.trim(),
      statusCode: _isActive ? 'ACTIVE' : 'INACTIVE',
      isActive: _isActive,
      managerName: _selectedKind.defaultManager,
      openOrders: _selectedRecord?.openOrders ?? 0,
      settlementHold: _selectedRecord?.settlementHold ?? 0,
      siteCount: _selectedRecord?.siteCount ?? 0,
      relationshipCount: _selectedRecord?.relationshipCount ?? 0,
      memo: _memoController.text.trim(),
    );

    setState(() {
      final index = _records.indexWhere((item) => item.id == record.id);
      if (index == -1) {
        _records.insert(0, record);
      } else {
        _records[index] = record;
      }
      _selectedId = record.id;
    });

    final result = await MasterApi.instance.saveBusinessPartner(
      record.toApiPayload(),
    );
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.failed
              ? '${record.kind.label} 마스터 화면 반영 완료, DB 저장 실패: ${result.message}'
              : '${record.kind.label} 마스터가 반영되었습니다.',
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
    final selectedRecord = _selectedRecord;
    final filteredRecords = _filteredRecords;

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
          _MasterHeader(
            selectedKind: _selectedKind,
            totalCount: filteredRecords.length,
            activeCount: filteredRecords
                .where((record) => record.isActive)
                .length,
            onCreate: _startCreate,
          ),
          const SizedBox(height: 16),
          _PartnerKindSelector(
            selectedKind: _selectedKind,
            onSelect: _selectKind,
            counts: {
              for (final kind in _PartnerKind.values)
                kind: _records.where((record) => record.kind == kind).length,
            },
          ),
          const SizedBox(height: 16),
          _MasterStats(records: filteredRecords),
          const SizedBox(height: 16),
          _MasterToolbar(
            query: _query,
            statusFilter: _statusFilter,
            onQueryChanged: (value) => setState(() => _query = value),
            onStatusChanged: (value) =>
                setState(() => _statusFilter = value ?? 'ALL'),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1180 && !widget.compact;
              if (!wide) {
                return Column(
                  children: [
                    _PartnerDirectoryPanel(
                      records: filteredRecords,
                      selectedId: _selectedId,
                      onSelect: _selectRecord,
                    ),
                    const SizedBox(height: 16),
                    _PartnerEditorPanel(
                      selectedKind: _selectedKind,
                      selectedRecord: selectedRecord,
                      codeController: _codeController,
                      nameController: _nameController,
                      shortNameController: _shortNameController,
                      taxNoController: _taxNoController,
                      representativeController: _representativeController,
                      phoneController: _phoneController,
                      emailController: _emailController,
                      paymentTermsController: _paymentTermsController,
                      creditLimitController: _creditLimitController,
                      memoController: _memoController,
                      isActive: _isActive,
                      onActiveChanged: (value) =>
                          setState(() => _isActive = value),
                      onSave: _saveRecord,
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 13,
                    child: _PartnerDirectoryPanel(
                      records: filteredRecords,
                      selectedId: _selectedId,
                      onSelect: _selectRecord,
                      dense: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 8,
                    child: _PartnerEditorPanel(
                      selectedKind: _selectedKind,
                      selectedRecord: selectedRecord,
                      codeController: _codeController,
                      nameController: _nameController,
                      shortNameController: _shortNameController,
                      taxNoController: _taxNoController,
                      representativeController: _representativeController,
                      phoneController: _phoneController,
                      emailController: _emailController,
                      paymentTermsController: _paymentTermsController,
                      creditLimitController: _creditLimitController,
                      memoController: _memoController,
                      isActive: _isActive,
                      onActiveChanged: (value) =>
                          setState(() => _isActive = value),
                      onSave: _saveRecord,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MasterHeader extends StatelessWidget {
  const _MasterHeader({
    required this.selectedKind,
    required this.totalCount,
    required this.activeCount,
    required this.onCreate,
  });

  final _PartnerKind selectedKind;
  final int totalCount;
  final int activeCount;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return _SurfacePanel(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final titleBlock = Row(
            children: [
              _IconBox(icon: selectedKind.icon, color: selectedKind.color),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '거래처 마스터',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: AppTheme.graphite,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '고객사, 화주, 운송사 기준정보',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.slate,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          final actions = Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _InlineMetric(label: '조회', value: '$totalCount'),
              _InlineMetric(label: '활성', value: '$activeCount'),
              ElevatedButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded, size: 19),
                label: Text('${selectedKind.label} 등록'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(134, 42),
                ),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [titleBlock, const SizedBox(height: 14), actions],
            );
          }

          return Row(
            children: [
              Expanded(child: titleBlock),
              const SizedBox(width: 14),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _PartnerKindSelector extends StatelessWidget {
  const _PartnerKindSelector({
    required this.selectedKind,
    required this.onSelect,
    required this.counts,
  });

  final _PartnerKind selectedKind;
  final ValueChanged<_PartnerKind> onSelect;
  final Map<_PartnerKind, int> counts;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = constraints.maxWidth >= 900
            ? (constraints.maxWidth - 24) / 3
            : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 10,
          children: _PartnerKind.values.map((kind) {
            final selected = selectedKind == kind;
            return SizedBox(
              width: tileWidth,
              child: Material(
                color: selected
                    ? kind.color.withValues(alpha: 0.10)
                    : Colors.white,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => onSelect(kind),
                  child: Container(
                    height: 74,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected ? kind.color : AppTheme.line,
                        width: selected ? 1.4 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        _IconBox(icon: kind.icon, color: kind.color, size: 38),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                kind.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      color: AppTheme.graphite,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0,
                                    ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                kind.typeCode,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: AppTheme.slate,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        _CountBadge(
                          value: '${counts[kind] ?? 0}',
                          color: selected ? kind.color : AppTheme.slate,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _MasterStats extends StatelessWidget {
  const _MasterStats({required this.records});

  final List<_PartnerRecord> records;

  @override
  Widget build(BuildContext context) {
    final openOrders = records.fold<int>(
      0,
      (sum, record) => sum + record.openOrders,
    );
    final sites = records.fold<int>(0, (sum, record) => sum + record.siteCount);
    final holds = records
        .where((record) => record.settlementHold > 0 || !record.isActive)
        .length;

    final metrics = [
      _MasterMetric(
        label: '활성 거래처',
        value: '${records.where((record) => record.isActive).length}',
        icon: Icons.verified_rounded,
        color: AppTheme.teal,
      ),
      _MasterMetric(
        label: '진행 오더',
        value: '$openOrders',
        icon: Icons.route_rounded,
        color: AppTheme.cyan,
      ),
      _MasterMetric(
        label: '등록 거점',
        value: '$sites',
        icon: Icons.location_on_rounded,
        color: const Color(0xFF2563EB),
      ),
      _MasterMetric(
        label: '주의 대상',
        value: '$holds',
        icon: Icons.report_rounded,
        color: AppTheme.amber,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1080
            ? 4
            : constraints.maxWidth >= 620
            ? 2
            : 1;
        final spacing = 12.0;
        final width =
            (constraints.maxWidth - (columns - 1) * spacing) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: metrics
              .map(
                (metric) => SizedBox(width: width, child: _MetricTile(metric)),
              )
              .toList(),
        );
      },
    );
  }
}

class _MasterToolbar extends StatelessWidget {
  const _MasterToolbar({
    required this.query,
    required this.statusFilter,
    required this.onQueryChanged,
    required this.onStatusChanged,
  });

  final String query;
  final String statusFilter;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String?> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return _SurfacePanel(
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final search = TextField(
            onChanged: onQueryChanged,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              labelText: '거래처 검색',
              hintText: '코드, 거래처명, 약칭, 사업자번호',
            ),
          );

          final filter = DropdownButtonFormField<String>(
            initialValue: statusFilter,
            onChanged: onStatusChanged,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.filter_list_rounded),
              labelText: '상태',
            ),
            items: const [
              DropdownMenuItem(value: 'ALL', child: Text('전체')),
              DropdownMenuItem(value: 'ACTIVE', child: Text('활성')),
              DropdownMenuItem(value: 'ON_HOLD', child: Text('보류')),
              DropdownMenuItem(value: 'INACTIVE', child: Text('비활성')),
            ],
          );

          if (compact) {
            return Column(
              children: [search, const SizedBox(height: 10), filter],
            );
          }

          return Row(
            children: [
              Expanded(flex: 4, child: search),
              const SizedBox(width: 12),
              SizedBox(width: 220, child: filter),
              const SizedBox(width: 12),
              _ToolbarButton(icon: Icons.download_rounded, label: '내보내기'),
              const SizedBox(width: 8),
              _ToolbarButton(icon: Icons.upload_file_rounded, label: '업로드'),
            ],
          );
        },
      ),
    );
  }
}

class _PartnerDirectoryPanel extends StatelessWidget {
  const _PartnerDirectoryPanel({
    required this.records,
    required this.selectedId,
    required this.onSelect,
    this.dense = false,
  });

  final List<_PartnerRecord> records;
  final int? selectedId;
  final ValueChanged<_PartnerRecord> onSelect;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return _SurfacePanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.format_list_bulleted_rounded,
            title: '거래처 목록',
            subtitle: 'business_partners',
          ),
          const SizedBox(height: 14),
          if (records.isEmpty)
            const _EmptyState()
          else
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 820 || !dense) {
                  return Column(
                    children: records
                        .map(
                          (record) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _PartnerListTile(
                              record: record,
                              selected: selectedId == record.id,
                              onTap: () => onSelect(record),
                            ),
                          ),
                        )
                        .toList(),
                  );
                }

                return _PartnerTable(
                  records: records,
                  selectedId: selectedId,
                  onSelect: onSelect,
                );
              },
            ),
        ],
      ),
    );
  }
}

class _PartnerTable extends StatelessWidget {
  const _PartnerTable({
    required this.records,
    required this.selectedId,
    required this.onSelect,
  });

  final List<_PartnerRecord> records;
  final int? selectedId;
  final ValueChanged<_PartnerRecord> onSelect;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
          dataRowMinHeight: 58,
          dataRowMaxHeight: 64,
          columnSpacing: 28,
          horizontalMargin: 14,
          columns: const [
            DataColumn(label: Text('코드')),
            DataColumn(label: Text('거래처명')),
            DataColumn(label: Text('약칭')),
            DataColumn(label: Text('사업자번호')),
            DataColumn(label: Text('담당')),
            DataColumn(label: Text('정산')),
            DataColumn(label: Text('상태')),
          ],
          rows: records.map((record) {
            final selected = selectedId == record.id;
            return DataRow(
              selected: selected,
              onSelectChanged: (_) => onSelect(record),
              cells: [
                DataCell(_StrongText(record.partnerCode)),
                DataCell(_BoundedCell(record.partnerName, width: 190)),
                DataCell(_BoundedCell(record.partnerShortName, width: 120)),
                DataCell(Text(record.taxRegistrationNo)),
                DataCell(Text(record.managerName)),
                DataCell(Text(record.paymentTerms)),
                DataCell(_StatusBadge(record: record)),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _PartnerListTile extends StatelessWidget {
  const _PartnerListTile({
    required this.record,
    required this.selected,
    required this.onTap,
  });

  final _PartnerRecord record;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? record.kind.color.withValues(alpha: 0.08)
          : Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? record.kind.color : AppTheme.line,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _IconBox(icon: record.kind.icon, color: record.kind.color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.partnerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: AppTheme.graphite,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0,
                              ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${record.partnerCode} · ${record.partnerShortName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppTheme.slate,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0,
                              ),
                        ),
                      ],
                    ),
                  ),
                  _StatusBadge(record: record),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _TinyInfo(
                    icon: Icons.pin_drop_rounded,
                    label: '${record.siteCount}개 거점',
                  ),
                  _TinyInfo(
                    icon: Icons.route_rounded,
                    label: '${record.openOrders}건 진행',
                  ),
                  _TinyInfo(
                    icon: Icons.account_tree_rounded,
                    label: '${record.relationshipCount}개 관계',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PartnerEditorPanel extends StatelessWidget {
  const _PartnerEditorPanel({
    required this.selectedKind,
    required this.selectedRecord,
    required this.codeController,
    required this.nameController,
    required this.shortNameController,
    required this.taxNoController,
    required this.representativeController,
    required this.phoneController,
    required this.emailController,
    required this.paymentTermsController,
    required this.creditLimitController,
    required this.memoController,
    required this.isActive,
    required this.onActiveChanged,
    required this.onSave,
  });

  final _PartnerKind selectedKind;
  final _PartnerRecord? selectedRecord;
  final TextEditingController codeController;
  final TextEditingController nameController;
  final TextEditingController shortNameController;
  final TextEditingController taxNoController;
  final TextEditingController representativeController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final TextEditingController paymentTermsController;
  final TextEditingController creditLimitController;
  final TextEditingController memoController;
  final bool isActive;
  final ValueChanged<bool> onActiveChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return _SurfacePanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: selectedKind.icon,
            title: '${selectedKind.label} 상세',
            subtitle: selectedRecord?.partnerCode ?? selectedKind.typeCode,
          ),
          const SizedBox(height: 16),
          _EditorSummary(record: selectedRecord, selectedKind: selectedKind),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumn = constraints.maxWidth >= 620;
              final fieldWidth = twoColumn
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: fieldWidth,
                    child: _TextInput(
                      controller: codeController,
                      label: '거래처 코드',
                      icon: Icons.tag_rounded,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _ReadOnlyValue(
                      label: '거래처 유형',
                      value: selectedKind.typeCode,
                      icon: selectedKind.icon,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _TextInput(
                      controller: nameController,
                      label: '정식 거래처명',
                      icon: Icons.business_rounded,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _TextInput(
                      controller: shortNameController,
                      label: '약칭',
                      icon: Icons.short_text_rounded,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _TextInput(
                      controller: taxNoController,
                      label: '사업자번호',
                      icon: Icons.badge_rounded,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _TextInput(
                      controller: representativeController,
                      label: '대표자',
                      icon: Icons.person_rounded,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _TextInput(
                      controller: phoneController,
                      label: '대표 전화',
                      icon: Icons.call_rounded,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _TextInput(
                      controller: emailController,
                      label: '대표 이메일',
                      icon: Icons.alternate_email_rounded,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _TextInput(
                      controller: paymentTermsController,
                      label: '정산 조건',
                      icon: Icons.event_available_rounded,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _TextInput(
                      controller: creditLimitController,
                      label: '여신한도',
                      icon: Icons.payments_rounded,
                    ),
                  ),
                  SizedBox(
                    width: constraints.maxWidth,
                    child: _TextInput(
                      controller: memoController,
                      label: '관리 메모',
                      icon: Icons.notes_rounded,
                      maxLines: 3,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.line),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '신규 업무 사용',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isActive ? 'is_active = true' : 'is_active = false',
                        style: const TextStyle(
                          color: AppTheme.slate,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(value: isActive, onChanged: onActiveChanged),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.history_rounded, size: 18),
                  label: const Text('변경이력'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onSave,
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: const Text('저장'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditorSummary extends StatelessWidget {
  const _EditorSummary({required this.record, required this.selectedKind});

  final _PartnerRecord? record;
  final _PartnerKind selectedKind;

  @override
  Widget build(BuildContext context) {
    final siteCount = record?.siteCount ?? 0;
    final relationCount = record?.relationshipCount ?? 0;
    final openOrders = record?.openOrders ?? 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: selectedKind.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: selectedKind.color.withValues(alpha: 0.26)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _TinyInfo(icon: Icons.location_on_rounded, label: '$siteCount개 거점'),
          _TinyInfo(
            icon: Icons.account_tree_rounded,
            label: '$relationCount개 관계',
          ),
          _TinyInfo(icon: Icons.route_rounded, label: '$openOrders건 진행'),
          _TinyInfo(
            icon: Icons.currency_exchange_rounded,
            label: record?.paymentTerms ?? '정산 조건',
          ),
        ],
      ),
    );
  }
}

class _SurfacePanel extends StatelessWidget {
  const _SurfacePanel({required this.child, required this.padding});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _IconBox(icon: icon, color: AppTheme.graphite),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.graphite,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
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
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile(this.metric);

  final _MasterMetric metric;

  @override
  Widget build(BuildContext context) {
    return _SurfacePanel(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          _IconBox(icon: metric.icon, color: metric.color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.slate,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  metric.value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.graphite,
                    fontWeight: FontWeight.w900,
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

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon, required this.color, this.size = 40});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: size * 0.52),
    );
  }
}

class _InlineMetric extends StatelessWidget {
  const _InlineMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.slate,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppTheme.graphite,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.value, required this.color});

  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 32),
      child: Container(
        height: 28,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.record});

  final _PartnerRecord record;

  @override
  Widget build(BuildContext context) {
    final color = switch (record.statusCode) {
      'ACTIVE' => AppTheme.teal,
      'ON_HOLD' => AppTheme.amber,
      _ => AppTheme.slate,
    };
    final label = switch (record.statusCode) {
      'ACTIVE' => '활성',
      'ON_HOLD' => '보류',
      _ => '비활성',
    };

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _TinyInfo extends StatelessWidget {
  const _TinyInfo({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppTheme.slate),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.ink,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 116,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: () {},
        icon: Icon(icon, size: 18),
        label: Text(label),
      ),
    );
  }
}

class _TextInput extends StatelessWidget {
  const _TextInput({
    required this.controller,
    required this.label,
    required this.icon,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(prefixIcon: Icon(icon), labelText: label),
    );
  }
}

class _ReadOnlyValue extends StatelessWidget {
  const _ReadOnlyValue({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      enabled: false,
      controller: TextEditingController(text: value),
      decoration: InputDecoration(prefixIcon: Icon(icon), labelText: label),
    );
  }
}

class _StrongText extends StatelessWidget {
  const _StrongText(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      style: const TextStyle(
        color: AppTheme.graphite,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
    );
  }
}

class _BoundedCell extends StatelessWidget {
  const _BoundedCell(this.value, {required this.width});

  final String value;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        children: [
          const Icon(Icons.search_off_rounded, color: AppTheme.slate, size: 34),
          const SizedBox(height: 10),
          Text(
            '조회 결과 없음',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppTheme.graphite,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

enum _PartnerKind {
  customer,
  shipper,
  carrier;

  String get label => switch (this) {
    _PartnerKind.customer => '고객사',
    _PartnerKind.shipper => '화주',
    _PartnerKind.carrier => '운송사',
  };

  String get typeCode => switch (this) {
    _PartnerKind.customer => 'CUSTOMER',
    _PartnerKind.shipper => 'SHIPPER',
    _PartnerKind.carrier => 'CARRIER',
  };

  IconData get icon => switch (this) {
    _PartnerKind.customer => Icons.business_rounded,
    _PartnerKind.shipper => Icons.apartment_rounded,
    _PartnerKind.carrier => Icons.local_shipping_rounded,
  };

  Color get color => switch (this) {
    _PartnerKind.customer => AppTheme.teal,
    _PartnerKind.shipper => AppTheme.cyan,
    _PartnerKind.carrier => const Color(0xFF7C3AED),
  };

  String get defaultManager => switch (this) {
    _PartnerKind.customer => '영업1팀',
    _PartnerKind.shipper => '운영기획팀',
    _PartnerKind.carrier => '수송관리팀',
  };
}

class _PartnerRecord {
  const _PartnerRecord({
    required this.id,
    required this.kind,
    required this.partnerCode,
    required this.partnerName,
    required this.partnerShortName,
    required this.taxRegistrationNo,
    required this.representativeName,
    required this.phone,
    required this.email,
    required this.paymentTerms,
    required this.creditLimit,
    required this.statusCode,
    required this.isActive,
    required this.managerName,
    required this.openOrders,
    required this.settlementHold,
    required this.siteCount,
    required this.relationshipCount,
    required this.memo,
  });

  final int id;
  final _PartnerKind kind;
  final String partnerCode;
  final String partnerName;
  final String partnerShortName;
  final String taxRegistrationNo;
  final String representativeName;
  final String phone;
  final String email;
  final String paymentTerms;
  final String creditLimit;
  final String statusCode;
  final bool isActive;
  final String managerName;
  final int openOrders;
  final int settlementHold;
  final int siteCount;
  final int relationshipCount;
  final String memo;

  Map<String, Object?> toApiPayload() {
    return {
      'partner_code': partnerCode,
      'partner_name': partnerName,
      'partner_short_name': partnerShortName,
      'partner_type': kind.typeCode,
      'tax_registration_no': taxRegistrationNo,
      'representative_name': representativeName,
      'phone': phone,
      'email': email,
      'payment_terms': paymentTerms,
      'credit_limit': creditLimit,
      'status': statusCode,
      'is_active': isActive,
      'metadata': {
        'manager_name': managerName,
        'open_orders': openOrders,
        'settlement_hold': settlementHold,
        'site_count': siteCount,
        'relationship_count': relationshipCount,
        'memo': memo,
      },
    };
  }
}

class _MasterMetric {
  const _MasterMetric({
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

const _seedPartners = [
  _PartnerRecord(
    id: 1,
    kind: _PartnerKind.customer,
    partnerCode: 'CUST0001',
    partnerName: '삼성전자 주식회사',
    partnerShortName: '삼성전자',
    taxRegistrationNo: '124-81-00998',
    representativeName: '한종희',
    phone: '02-2255-0114',
    email: 'logistics@samsung.example',
    paymentTerms: '월말 +30일',
    creditLimit: '500,000,000',
    statusCode: 'ACTIVE',
    isActive: true,
    managerName: '영업1팀',
    openOrders: 38,
    settlementHold: 0,
    siteCount: 12,
    relationshipCount: 8,
    memo: '수도권/영남권 고정 노선 운영.',
  ),
  _PartnerRecord(
    id: 2,
    kind: _PartnerKind.customer,
    partnerCode: 'CUST0002',
    partnerName: '이마트 주식회사',
    partnerShortName: '이마트',
    taxRegistrationNo: '206-86-50913',
    representativeName: '한채양',
    phone: '02-380-5678',
    email: 'transport@emart.example',
    paymentTerms: '월말 +45일',
    creditLimit: '320,000,000',
    statusCode: 'ACTIVE',
    isActive: true,
    managerName: '리테일영업팀',
    openOrders: 24,
    settlementHold: 1,
    siteCount: 18,
    relationshipCount: 6,
    memo: '냉장/상온 분리 운영.',
  ),
  _PartnerRecord(
    id: 3,
    kind: _PartnerKind.shipper,
    partnerCode: 'SHIP0001',
    partnerName: '삼성전자 물류센터',
    partnerShortName: '삼성전자 물류',
    taxRegistrationNo: '124-81-00998',
    representativeName: '김도현',
    phone: '031-200-1000',
    email: 'shipper.se@samsung.example',
    paymentTerms: '고객사 청구',
    creditLimit: '0',
    statusCode: 'ACTIVE',
    isActive: true,
    managerName: '운영기획팀',
    openOrders: 31,
    settlementHold: 0,
    siteCount: 7,
    relationshipCount: 5,
    memo: '상차 예약 필수.',
  ),
  _PartnerRecord(
    id: 4,
    kind: _PartnerKind.shipper,
    partnerCode: 'SHIP0002',
    partnerName: '신세계푸드 평택센터',
    partnerShortName: '신세계푸드',
    taxRegistrationNo: '215-81-47377',
    representativeName: '문준석',
    phone: '031-650-4100',
    email: 'dispatch@ssgfood.example',
    paymentTerms: '월말 +30일',
    creditLimit: '120,000,000',
    statusCode: 'ACTIVE',
    isActive: true,
    managerName: '콜드체인팀',
    openOrders: 17,
    settlementHold: 0,
    siteCount: 9,
    relationshipCount: 4,
    memo: '온도 로그 첨부 필요.',
  ),
  _PartnerRecord(
    id: 5,
    kind: _PartnerKind.carrier,
    partnerCode: 'CARR0001',
    partnerName: 'CJ대한통운 주식회사',
    partnerShortName: 'CJ대한통운',
    taxRegistrationNo: '110-81-05034',
    representativeName: '신영수',
    phone: '1588-1255',
    email: 'carrier@cjlogistics.example',
    paymentTerms: '월말 +30일',
    creditLimit: '0',
    statusCode: 'ACTIVE',
    isActive: true,
    managerName: '수송관리팀',
    openOrders: 42,
    settlementHold: 0,
    siteCount: 24,
    relationshipCount: 11,
    memo: '간선/택배 연계 가능.',
  ),
  _PartnerRecord(
    id: 6,
    kind: _PartnerKind.carrier,
    partnerCode: 'CARR0002',
    partnerName: '한진 주식회사',
    partnerShortName: '한진',
    taxRegistrationNo: '201-81-02823',
    representativeName: '노삼석',
    phone: '1588-0011',
    email: 'tms@hanjin.example',
    paymentTerms: '월말 +45일',
    creditLimit: '0',
    statusCode: 'ON_HOLD',
    isActive: true,
    managerName: '수송관리팀',
    openOrders: 15,
    settlementHold: 2,
    siteCount: 16,
    relationshipCount: 7,
    memo: '정산 단가 검토 중.',
  ),
];
