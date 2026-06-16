import 'package:flutter/material.dart';

import '../../design/app_theme.dart';
import 'master_api.dart';

class DeliveryDestinationMasterPage extends StatefulWidget {
  const DeliveryDestinationMasterPage({super.key, this.compact = false});

  final bool compact;

  @override
  State<DeliveryDestinationMasterPage> createState() =>
      _DeliveryDestinationMasterPageState();
}

class _DeliveryDestinationMasterPageState
    extends State<DeliveryDestinationMasterPage> {
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _customerController = TextEditingController();
  final _shipperController = TextEditingController();
  final _addressController = TextEditingController();
  final _detailAddressController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _timeWindowController = TextEditingController();
  final _dockCountController = TextEditingController();
  final _vehicleLimitController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _memoController = TextEditingController();

  late final List<_DestinationRecord> _records;
  _DestinationType? _typeFilter;
  _DestinationType _selectedType = _DestinationType.rdc;
  String _query = '';
  String _statusFilter = 'ALL';
  int? _selectedId;
  bool _appointmentRequired = true;
  bool _podRequired = true;
  bool _temperatureControl = false;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    _records = List<_DestinationRecord>.from(_seedDestinations);
    _selectRecord(_records.first);
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _customerController.dispose();
    _shipperController.dispose();
    _addressController.dispose();
    _detailAddressController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _timeWindowController.dispose();
    _dockCountController.dispose();
    _vehicleLimitController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  List<_DestinationRecord> get _filteredRecords {
    final normalizedQuery = _query.trim().toLowerCase();
    return _records.where((record) {
      final matchesType = _typeFilter == null || record.type == _typeFilter;
      final matchesStatus =
          _statusFilter == 'ALL' || record.statusCode == _statusFilter;
      final matchesQuery =
          normalizedQuery.isEmpty ||
          record.destinationCode.toLowerCase().contains(normalizedQuery) ||
          record.destinationName.toLowerCase().contains(normalizedQuery) ||
          record.customerName.toLowerCase().contains(normalizedQuery) ||
          record.shipperName.toLowerCase().contains(normalizedQuery) ||
          record.zoneName.toLowerCase().contains(normalizedQuery) ||
          record.address.toLowerCase().contains(normalizedQuery);
      return matchesType && matchesStatus && matchesQuery;
    }).toList();
  }

  _DestinationRecord? get _selectedRecord {
    for (final record in _records) {
      if (record.id == _selectedId) {
        return record;
      }
    }
    return null;
  }

  void _selectRecord(_DestinationRecord record, {bool notify = true}) {
    void apply() {
      _selectedId = record.id;
      _selectedType = record.type;
      _codeController.text = record.destinationCode;
      _nameController.text = record.destinationName;
      _customerController.text = record.customerName;
      _shipperController.text = record.shipperName;
      _addressController.text = record.address;
      _detailAddressController.text = record.detailAddress;
      _contactNameController.text = record.contactName;
      _contactPhoneController.text = record.contactPhone;
      _timeWindowController.text = record.timeWindow;
      _dockCountController.text = record.dockCount.toString();
      _vehicleLimitController.text = record.vehicleLimit;
      _latitudeController.text = record.latitude;
      _longitudeController.text = record.longitude;
      _memoController.text = record.memo;
      _appointmentRequired = record.appointmentRequired;
      _podRequired = record.podRequired;
      _temperatureControl = record.temperatureControl;
      _isActive = record.isActive;
    }

    if (notify) {
      setState(apply);
    } else {
      apply();
    }
  }

  void _clearEditor() {
    _selectedId = null;
    _selectedType = _typeFilter ?? _DestinationType.rdc;
    _codeController.text = _nextCode(_selectedType);
    _nameController.clear();
    _customerController.text = '삼성전자';
    _shipperController.text = '삼성전자 물류센터';
    _addressController.clear();
    _detailAddressController.clear();
    _contactNameController.clear();
    _contactPhoneController.clear();
    _timeWindowController.text = '09:00-18:00';
    _dockCountController.text = '1';
    _vehicleLimitController.text = '11톤 이하';
    _latitudeController.clear();
    _longitudeController.clear();
    _memoController.clear();
    _appointmentRequired = true;
    _podRequired = true;
    _temperatureControl = false;
    _isActive = true;
  }

  String _nextCode(_DestinationType type) {
    final count = _records.where((record) => record.type == type).length + 1;
    return '${type.prefix}${count.toString().padLeft(4, '0')}';
  }

  void _startCreate() {
    setState(_clearEditor);
  }

  void _saveRecord() async {
    final destinationName = _nameController.text.trim();
    if (destinationName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('배송처명을 입력하세요.')));
      return;
    }

    final dockCount = int.tryParse(_dockCountController.text.trim()) ?? 0;
    final record = _DestinationRecord(
      id: _selectedId ?? _nextRecordId(),
      type: _selectedType,
      destinationCode: _codeController.text.trim(),
      destinationName: destinationName,
      customerName: _customerController.text.trim(),
      shipperName: _shipperController.text.trim(),
      zoneName: _selectedRecord?.zoneName ?? '수도권',
      routeName: _selectedRecord?.routeName ?? '수도권 순환',
      address: _addressController.text.trim(),
      detailAddress: _detailAddressController.text.trim(),
      contactName: _contactNameController.text.trim(),
      contactPhone: _contactPhoneController.text.trim(),
      timeWindow: _timeWindowController.text.trim(),
      dockCount: dockCount,
      vehicleLimit: _vehicleLimitController.text.trim(),
      latitude: _latitudeController.text.trim(),
      longitude: _longitudeController.text.trim(),
      todayOrders: _selectedRecord?.todayOrders ?? 0,
      delayRisk: _selectedRecord?.delayRisk ?? 0,
      appointmentRequired: _appointmentRequired,
      podRequired: _podRequired,
      temperatureControl: _temperatureControl,
      statusCode: _isActive ? 'ACTIVE' : 'INACTIVE',
      isActive: _isActive,
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

    final result = await MasterApi.instance.saveLocation(record.toApiPayload());
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.failed
              ? '${record.destinationName} 배송처 화면 반영 완료, DB 저장 실패: ${result.message}'
              : '${record.destinationName} 배송처가 반영되었습니다.',
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
          _DestinationHeader(
            totalCount: filteredRecords.length,
            activeCount: filteredRecords
                .where((record) => record.isActive)
                .length,
            onCreate: _startCreate,
          ),
          const SizedBox(height: 16),
          _DestinationTypeSelector(
            selectedType: _typeFilter,
            counts: {
              for (final type in _DestinationType.values)
                type: _records.where((record) => record.type == type).length,
            },
            onSelect: (type) => setState(() {
              _typeFilter = _typeFilter == type ? null : type;
              final first = _filteredRecords.firstOrNull;
              if (first != null) {
                _selectRecord(first, notify: false);
              }
            }),
          ),
          const SizedBox(height: 16),
          _DestinationStats(records: filteredRecords),
          const SizedBox(height: 16),
          _DestinationToolbar(
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
                    _DestinationDirectoryPanel(
                      records: filteredRecords,
                      selectedId: _selectedId,
                      onSelect: _selectRecord,
                    ),
                    const SizedBox(height: 16),
                    _DestinationEditorPanel(
                      selectedRecord: selectedRecord,
                      selectedType: _selectedType,
                      onTypeChanged: (type) =>
                          setState(() => _selectedType = type),
                      codeController: _codeController,
                      nameController: _nameController,
                      customerController: _customerController,
                      shipperController: _shipperController,
                      addressController: _addressController,
                      detailAddressController: _detailAddressController,
                      contactNameController: _contactNameController,
                      contactPhoneController: _contactPhoneController,
                      timeWindowController: _timeWindowController,
                      dockCountController: _dockCountController,
                      vehicleLimitController: _vehicleLimitController,
                      latitudeController: _latitudeController,
                      longitudeController: _longitudeController,
                      memoController: _memoController,
                      appointmentRequired: _appointmentRequired,
                      podRequired: _podRequired,
                      temperatureControl: _temperatureControl,
                      isActive: _isActive,
                      onAppointmentChanged: (value) =>
                          setState(() => _appointmentRequired = value),
                      onPodChanged: (value) =>
                          setState(() => _podRequired = value),
                      onTemperatureChanged: (value) =>
                          setState(() => _temperatureControl = value),
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
                    child: _DestinationDirectoryPanel(
                      records: filteredRecords,
                      selectedId: _selectedId,
                      onSelect: _selectRecord,
                      dense: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 8,
                    child: _DestinationEditorPanel(
                      selectedRecord: selectedRecord,
                      selectedType: _selectedType,
                      onTypeChanged: (type) =>
                          setState(() => _selectedType = type),
                      codeController: _codeController,
                      nameController: _nameController,
                      customerController: _customerController,
                      shipperController: _shipperController,
                      addressController: _addressController,
                      detailAddressController: _detailAddressController,
                      contactNameController: _contactNameController,
                      contactPhoneController: _contactPhoneController,
                      timeWindowController: _timeWindowController,
                      dockCountController: _dockCountController,
                      vehicleLimitController: _vehicleLimitController,
                      latitudeController: _latitudeController,
                      longitudeController: _longitudeController,
                      memoController: _memoController,
                      appointmentRequired: _appointmentRequired,
                      podRequired: _podRequired,
                      temperatureControl: _temperatureControl,
                      isActive: _isActive,
                      onAppointmentChanged: (value) =>
                          setState(() => _appointmentRequired = value),
                      onPodChanged: (value) =>
                          setState(() => _podRequired = value),
                      onTemperatureChanged: (value) =>
                          setState(() => _temperatureControl = value),
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

class _DestinationHeader extends StatelessWidget {
  const _DestinationHeader({
    required this.totalCount,
    required this.activeCount,
    required this.onCreate,
  });

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
              const _IconBox(
                icon: Icons.store_mall_directory_rounded,
                color: Color(0xFF2563EB),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '배송처 마스터',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: AppTheme.graphite,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '납품처, 하차지, 시간창, 지도 좌표 기준정보',
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
                icon: const Icon(Icons.add_location_alt_rounded, size: 19),
                label: const Text('배송처 등록'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(136, 42),
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

class _DestinationTypeSelector extends StatelessWidget {
  const _DestinationTypeSelector({
    required this.selectedType,
    required this.counts,
    required this.onSelect,
  });

  final _DestinationType? selectedType;
  final Map<_DestinationType, int> counts;
  final ValueChanged<_DestinationType> onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1060
            ? 4
            : constraints.maxWidth >= 720
            ? 2
            : 1;
        const spacing = 12.0;
        final width =
            (constraints.maxWidth - (columns - 1) * spacing) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: 10,
          children: _DestinationType.values.map((type) {
            final selected = selectedType == type;
            return SizedBox(
              width: width,
              child: Material(
                color: selected
                    ? type.color.withValues(alpha: 0.10)
                    : Colors.white,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => onSelect(type),
                  child: Container(
                    height: 74,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected ? type.color : AppTheme.line,
                        width: selected ? 1.4 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        _IconBox(icon: type.icon, color: type.color, size: 38),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                type.label,
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
                                type.code,
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
                          value: '${counts[type] ?? 0}',
                          color: selected ? type.color : AppTheme.slate,
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

class _DestinationStats extends StatelessWidget {
  const _DestinationStats({required this.records});

  final List<_DestinationRecord> records;

  @override
  Widget build(BuildContext context) {
    final todayOrders = records.fold<int>(
      0,
      (sum, record) => sum + record.todayOrders,
    );
    final dockCount = records.fold<int>(
      0,
      (sum, record) => sum + record.dockCount,
    );
    final reservationCount = records
        .where((record) => record.appointmentRequired)
        .length;
    final riskCount = records.where((record) => record.delayRisk > 0).length;

    final metrics = [
      _MasterMetric(
        label: '활성 배송처',
        value: '${records.where((record) => record.isActive).length}',
        icon: Icons.verified_rounded,
        color: AppTheme.teal,
      ),
      _MasterMetric(
        label: '오늘 납품',
        value: '$todayOrders',
        icon: Icons.route_rounded,
        color: AppTheme.cyan,
      ),
      _MasterMetric(
        label: '도크 수',
        value: '$dockCount',
        icon: Icons.door_sliding_rounded,
        color: const Color(0xFF2563EB),
      ),
      _MasterMetric(
        label: '예약 필수',
        value: '$reservationCount',
        icon: Icons.event_available_rounded,
        color: AppTheme.amber,
      ),
      _MasterMetric(
        label: '지연 주의',
        value: '$riskCount',
        icon: Icons.report_rounded,
        color: const Color(0xFFDC2626),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1180
            ? 5
            : constraints.maxWidth >= 820
            ? 3
            : constraints.maxWidth >= 560
            ? 2
            : 1;
        const spacing = 12.0;
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

class _DestinationToolbar extends StatelessWidget {
  const _DestinationToolbar({
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
              labelText: '배송처 검색',
              hintText: '코드, 배송처명, 고객사, 화주, 주소',
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

class _DestinationDirectoryPanel extends StatelessWidget {
  const _DestinationDirectoryPanel({
    required this.records,
    required this.selectedId,
    required this.onSelect,
    this.dense = false,
  });

  final List<_DestinationRecord> records;
  final int? selectedId;
  final ValueChanged<_DestinationRecord> onSelect;
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
            title: '배송처 목록',
            subtitle: 'delivery_destinations',
          ),
          const SizedBox(height: 14),
          if (records.isEmpty)
            const _EmptyState()
          else
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 900 || !dense) {
                  return Column(
                    children: records
                        .map(
                          (record) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _DestinationListTile(
                              record: record,
                              selected: selectedId == record.id,
                              onTap: () => onSelect(record),
                            ),
                          ),
                        )
                        .toList(),
                  );
                }

                return _DestinationTable(
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

class _DestinationTable extends StatelessWidget {
  const _DestinationTable({
    required this.records,
    required this.selectedId,
    required this.onSelect,
  });

  final List<_DestinationRecord> records;
  final int? selectedId;
  final ValueChanged<_DestinationRecord> onSelect;

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
          columnSpacing: 26,
          horizontalMargin: 14,
          columns: const [
            DataColumn(label: Text('코드')),
            DataColumn(label: Text('배송처')),
            DataColumn(label: Text('고객사')),
            DataColumn(label: Text('화주')),
            DataColumn(label: Text('권역/노선')),
            DataColumn(label: Text('시간창')),
            DataColumn(label: Text('상태')),
          ],
          rows: records.map((record) {
            final selected = selectedId == record.id;
            return DataRow(
              selected: selected,
              onSelectChanged: (_) => onSelect(record),
              cells: [
                DataCell(_StrongText(record.destinationCode)),
                DataCell(_BoundedCell(record.destinationName, width: 170)),
                DataCell(_BoundedCell(record.customerName, width: 120)),
                DataCell(_BoundedCell(record.shipperName, width: 140)),
                DataCell(
                  _BoundedCell(
                    '${record.zoneName} / ${record.routeName}',
                    width: 160,
                  ),
                ),
                DataCell(Text(record.timeWindow)),
                DataCell(_StatusBadge(record: record)),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _DestinationListTile extends StatelessWidget {
  const _DestinationListTile({
    required this.record,
    required this.selected,
    required this.onTap,
  });

  final _DestinationRecord record;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? record.type.color.withValues(alpha: 0.08)
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
              color: selected ? record.type.color : AppTheme.line,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _IconBox(icon: record.type.icon, color: record.type.color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.destinationName,
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
                          '${record.destinationCode} · ${record.customerName}',
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
                    icon: Icons.schedule_rounded,
                    label: record.timeWindow,
                  ),
                  _TinyInfo(
                    icon: Icons.door_sliding_rounded,
                    label: '${record.dockCount}개 도크',
                  ),
                  _TinyInfo(
                    icon: Icons.route_rounded,
                    label: '${record.todayOrders}건 납품',
                  ),
                  if (record.appointmentRequired)
                    const _TinyInfo(
                      icon: Icons.event_available_rounded,
                      label: '예약 필수',
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

class _DestinationEditorPanel extends StatelessWidget {
  const _DestinationEditorPanel({
    required this.selectedRecord,
    required this.selectedType,
    required this.onTypeChanged,
    required this.codeController,
    required this.nameController,
    required this.customerController,
    required this.shipperController,
    required this.addressController,
    required this.detailAddressController,
    required this.contactNameController,
    required this.contactPhoneController,
    required this.timeWindowController,
    required this.dockCountController,
    required this.vehicleLimitController,
    required this.latitudeController,
    required this.longitudeController,
    required this.memoController,
    required this.appointmentRequired,
    required this.podRequired,
    required this.temperatureControl,
    required this.isActive,
    required this.onAppointmentChanged,
    required this.onPodChanged,
    required this.onTemperatureChanged,
    required this.onActiveChanged,
    required this.onSave,
  });

  final _DestinationRecord? selectedRecord;
  final _DestinationType selectedType;
  final ValueChanged<_DestinationType> onTypeChanged;
  final TextEditingController codeController;
  final TextEditingController nameController;
  final TextEditingController customerController;
  final TextEditingController shipperController;
  final TextEditingController addressController;
  final TextEditingController detailAddressController;
  final TextEditingController contactNameController;
  final TextEditingController contactPhoneController;
  final TextEditingController timeWindowController;
  final TextEditingController dockCountController;
  final TextEditingController vehicleLimitController;
  final TextEditingController latitudeController;
  final TextEditingController longitudeController;
  final TextEditingController memoController;
  final bool appointmentRequired;
  final bool podRequired;
  final bool temperatureControl;
  final bool isActive;
  final ValueChanged<bool> onAppointmentChanged;
  final ValueChanged<bool> onPodChanged;
  final ValueChanged<bool> onTemperatureChanged;
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
            icon: selectedType.icon,
            title: '배송처 상세',
            subtitle: selectedRecord?.destinationCode ?? 'DESTINATION',
          ),
          const SizedBox(height: 16),
          _EditorSummary(record: selectedRecord, selectedType: selectedType),
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
                      label: '배송처 코드',
                      icon: Icons.tag_rounded,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: DropdownButtonFormField<_DestinationType>(
                      initialValue: selectedType,
                      onChanged: (type) {
                        if (type != null) {
                          onTypeChanged(type);
                        }
                      },
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.category_rounded),
                        labelText: '배송처 유형',
                      ),
                      items: _DestinationType.values
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(type.label),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _TextInput(
                      controller: nameController,
                      label: '배송처명',
                      icon: Icons.store_mall_directory_rounded,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _TextInput(
                      controller: customerController,
                      label: '고객사',
                      icon: Icons.business_rounded,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _TextInput(
                      controller: shipperController,
                      label: '화주',
                      icon: Icons.apartment_rounded,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _TextInput(
                      controller: timeWindowController,
                      label: '납품 시간창',
                      icon: Icons.schedule_rounded,
                    ),
                  ),
                  SizedBox(
                    width: constraints.maxWidth,
                    child: _TextInput(
                      controller: addressController,
                      label: '주소',
                      icon: Icons.location_on_rounded,
                    ),
                  ),
                  SizedBox(
                    width: constraints.maxWidth,
                    child: _TextInput(
                      controller: detailAddressController,
                      label: '상세 주소',
                      icon: Icons.location_city_rounded,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _TextInput(
                      controller: contactNameController,
                      label: '담당자',
                      icon: Icons.person_rounded,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _TextInput(
                      controller: contactPhoneController,
                      label: '연락처',
                      icon: Icons.call_rounded,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _TextInput(
                      controller: dockCountController,
                      label: '도크 수',
                      icon: Icons.door_sliding_rounded,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _TextInput(
                      controller: vehicleLimitController,
                      label: '차량 제약',
                      icon: Icons.local_shipping_rounded,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _TextInput(
                      controller: latitudeController,
                      label: '위도',
                      icon: Icons.explore_rounded,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _TextInput(
                      controller: longitudeController,
                      label: '경도',
                      icon: Icons.explore_outlined,
                    ),
                  ),
                  SizedBox(
                    width: constraints.maxWidth,
                    child: _TextInput(
                      controller: memoController,
                      label: '운영 메모',
                      icon: Icons.notes_rounded,
                      maxLines: 3,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          _SwitchGrid(
            appointmentRequired: appointmentRequired,
            podRequired: podRequired,
            temperatureControl: temperatureControl,
            isActive: isActive,
            onAppointmentChanged: onAppointmentChanged,
            onPodChanged: onPodChanged,
            onTemperatureChanged: onTemperatureChanged,
            onActiveChanged: onActiveChanged,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.map_rounded, size: 18),
                  label: const Text('지도 확인'),
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
  const _EditorSummary({required this.record, required this.selectedType});

  final _DestinationRecord? record;
  final _DestinationType selectedType;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: selectedType.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: selectedType.color.withValues(alpha: 0.26)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _TinyInfo(
            icon: Icons.category_rounded,
            label: record?.type.code ?? selectedType.code,
          ),
          _TinyInfo(
            icon: Icons.route_rounded,
            label: '${record?.todayOrders ?? 0}건 납품',
          ),
          _TinyInfo(
            icon: Icons.door_sliding_rounded,
            label: '${record?.dockCount ?? 0}개 도크',
          ),
          _TinyInfo(
            icon: Icons.schedule_rounded,
            label: record?.timeWindow ?? '시간창',
          ),
        ],
      ),
    );
  }
}

class _SwitchGrid extends StatelessWidget {
  const _SwitchGrid({
    required this.appointmentRequired,
    required this.podRequired,
    required this.temperatureControl,
    required this.isActive,
    required this.onAppointmentChanged,
    required this.onPodChanged,
    required this.onTemperatureChanged,
    required this.onActiveChanged,
  });

  final bool appointmentRequired;
  final bool podRequired;
  final bool temperatureControl;
  final bool isActive;
  final ValueChanged<bool> onAppointmentChanged;
  final ValueChanged<bool> onPodChanged;
  final ValueChanged<bool> onTemperatureChanged;
  final ValueChanged<bool> onActiveChanged;

  @override
  Widget build(BuildContext context) {
    final items = [
      _SwitchItem(
        title: '예약 필수',
        subtitle: appointmentRequired ? 'appointment_required' : '예약 없음',
        value: appointmentRequired,
        onChanged: onAppointmentChanged,
      ),
      _SwitchItem(
        title: 'POD 필수',
        subtitle: podRequired ? 'pod_required' : '선택 수집',
        value: podRequired,
        onChanged: onPodChanged,
      ),
      _SwitchItem(
        title: '온도 관리',
        subtitle: temperatureControl ? 'temperature_control' : '상온',
        value: temperatureControl,
        onChanged: onTemperatureChanged,
      ),
      _SwitchItem(
        title: '신규 업무 사용',
        subtitle: isActive ? 'is_active = true' : 'is_active = false',
        value: isActive,
        onChanged: onActiveChanged,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 620 ? 2 : 1;
        const spacing = 10.0;
        final width =
            (constraints.maxWidth - (columns - 1) * spacing) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items
              .map((item) => SizedBox(width: width, child: item))
              .toList(),
        );
      },
    );
  }
}

class _SwitchItem extends StatelessWidget {
  const _SwitchItem({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
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
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.graphite,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.slate,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
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

  final _DestinationRecord record;

  @override
  Widget build(BuildContext context) {
    final color = record.isActive ? AppTheme.teal : AppTheme.slate;
    final label = record.isActive ? '활성' : '비활성';

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

enum _DestinationType {
  rdc,
  store,
  plant,
  customerSite;

  String get label => switch (this) {
    _DestinationType.rdc => '물류센터',
    _DestinationType.store => '매장',
    _DestinationType.plant => '공장',
    _DestinationType.customerSite => '고객 납품처',
  };

  String get code => switch (this) {
    _DestinationType.rdc => 'RDC',
    _DestinationType.store => 'STORE',
    _DestinationType.plant => 'PLANT',
    _DestinationType.customerSite => 'CUSTOMER_SITE',
  };

  String get prefix => switch (this) {
    _DestinationType.rdc => 'RDC',
    _DestinationType.store => 'STR',
    _DestinationType.plant => 'PLT',
    _DestinationType.customerSite => 'DST',
  };

  IconData get icon => switch (this) {
    _DestinationType.rdc => Icons.warehouse_rounded,
    _DestinationType.store => Icons.storefront_rounded,
    _DestinationType.plant => Icons.factory_rounded,
    _DestinationType.customerSite => Icons.store_mall_directory_rounded,
  };

  Color get color => switch (this) {
    _DestinationType.rdc => AppTheme.teal,
    _DestinationType.store => const Color(0xFF2563EB),
    _DestinationType.plant => AppTheme.amber,
    _DestinationType.customerSite => const Color(0xFF7C3AED),
  };
}

class _DestinationRecord {
  const _DestinationRecord({
    required this.id,
    required this.type,
    required this.destinationCode,
    required this.destinationName,
    required this.customerName,
    required this.shipperName,
    required this.zoneName,
    required this.routeName,
    required this.address,
    required this.detailAddress,
    required this.contactName,
    required this.contactPhone,
    required this.timeWindow,
    required this.dockCount,
    required this.vehicleLimit,
    required this.latitude,
    required this.longitude,
    required this.todayOrders,
    required this.delayRisk,
    required this.appointmentRequired,
    required this.podRequired,
    required this.temperatureControl,
    required this.statusCode,
    required this.isActive,
    required this.memo,
  });

  final int id;
  final _DestinationType type;
  final String destinationCode;
  final String destinationName;
  final String customerName;
  final String shipperName;
  final String zoneName;
  final String routeName;
  final String address;
  final String detailAddress;
  final String contactName;
  final String contactPhone;
  final String timeWindow;
  final int dockCount;
  final String vehicleLimit;
  final String latitude;
  final String longitude;
  final int todayOrders;
  final int delayRisk;
  final bool appointmentRequired;
  final bool podRequired;
  final bool temperatureControl;
  final String statusCode;
  final bool isActive;
  final String memo;

  Map<String, Object?> toApiPayload() {
    return {
      'location_code': destinationCode,
      'location_name': destinationName,
      'location_type': type.code,
      'country_code': 'KR',
      'address_line1': address,
      'address_line2': detailAddress,
      'latitude': latitude,
      'longitude': longitude,
      'is_active': isActive,
      'metadata': {
        'destination_type': type.code,
        'customer_name': customerName,
        'shipper_name': shipperName,
        'zone_name': zoneName,
        'route_name': routeName,
        'contact_name': contactName,
        'contact_phone': contactPhone,
        'time_window': timeWindow,
        'dock_count': dockCount,
        'vehicle_limit': vehicleLimit,
        'today_orders': todayOrders,
        'delay_risk': delayRisk,
        'appointment_required': appointmentRequired,
        'pod_required': podRequired,
        'temperature_control': temperatureControl,
        'status': statusCode,
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

const _seedDestinations = [
  _DestinationRecord(
    id: 1,
    type: _DestinationType.rdc,
    destinationCode: 'RDC0001',
    destinationName: '이천 RDC',
    customerName: '삼성전자',
    shipperName: '삼성전자 물류센터',
    zoneName: '수도권',
    routeName: '수도권 순환',
    address: '경기도 이천시 마장면 서이천로 320',
    detailAddress: 'A동 3번 도크',
    contactName: '김민준',
    contactPhone: '031-640-1100',
    timeWindow: '08:00-17:00',
    dockCount: 8,
    vehicleLimit: '25톤 이하',
    latitude: '37.2491',
    longitude: '127.4079',
    todayOrders: 22,
    delayRisk: 1,
    appointmentRequired: true,
    podRequired: true,
    temperatureControl: false,
    statusCode: 'ACTIVE',
    isActive: true,
    memo: '도착 30분 전 관제실 연락. 야간 입차 제한 있음.',
  ),
  _DestinationRecord(
    id: 2,
    type: _DestinationType.store,
    destinationCode: 'STR0001',
    destinationName: '이마트 성수점',
    customerName: '이마트',
    shipperName: '신세계푸드 평택센터',
    zoneName: '서울',
    routeName: '강북 리테일',
    address: '서울특별시 성동구 뚝섬로 377',
    detailAddress: '지하 하역장',
    contactName: '박서연',
    contactPhone: '02-3408-1234',
    timeWindow: '06:00-10:30',
    dockCount: 2,
    vehicleLimit: '5톤 이하',
    latitude: '37.5398',
    longitude: '127.0530',
    todayOrders: 9,
    delayRisk: 0,
    appointmentRequired: true,
    podRequired: true,
    temperatureControl: true,
    statusCode: 'ACTIVE',
    isActive: true,
    memo: '상온/냉장 분리 검수. 지하 진입 높이 확인 필요.',
  ),
  _DestinationRecord(
    id: 3,
    type: _DestinationType.plant,
    destinationCode: 'PLT0001',
    destinationName: '구미 제조공장',
    customerName: '삼성전자',
    shipperName: '삼성전자 물류센터',
    zoneName: '경북',
    routeName: '영남 간선',
    address: '경상북도 구미시 3공단3로 302',
    detailAddress: '자재동 후문',
    contactName: '이도윤',
    contactPhone: '054-460-2100',
    timeWindow: '09:00-18:00',
    dockCount: 5,
    vehicleLimit: '윙바디 필수',
    latitude: '36.1071',
    longitude: '128.4166',
    todayOrders: 13,
    delayRisk: 2,
    appointmentRequired: true,
    podRequired: true,
    temperatureControl: false,
    statusCode: 'ACTIVE',
    isActive: true,
    memo: '보안 게이트 출입증 사전 등록 필요.',
  ),
  _DestinationRecord(
    id: 4,
    type: _DestinationType.customerSite,
    destinationCode: 'DST0001',
    destinationName: '대전 B2B 납품처',
    customerName: '삼성전자',
    shipperName: '삼성전자 물류센터',
    zoneName: '충청',
    routeName: '중부 B2B',
    address: '대전광역시 유성구 테크노중앙로 55',
    detailAddress: '1층 입고장',
    contactName: '최지훈',
    contactPhone: '042-930-7600',
    timeWindow: '13:00-16:00',
    dockCount: 1,
    vehicleLimit: '탑차 권장',
    latitude: '36.4244',
    longitude: '127.3931',
    todayOrders: 4,
    delayRisk: 0,
    appointmentRequired: false,
    podRequired: true,
    temperatureControl: false,
    statusCode: 'ACTIVE',
    isActive: true,
    memo: '현장 담당자 도착 확인 후 하차.',
  ),
  _DestinationRecord(
    id: 5,
    type: _DestinationType.rdc,
    destinationCode: 'RDC0002',
    destinationName: '부산 동부 RDC',
    customerName: '이마트',
    shipperName: '신세계푸드 평택센터',
    zoneName: '부산',
    routeName: '부산 냉장',
    address: '부산광역시 강서구 녹산산단로 333',
    detailAddress: '냉장 입고장',
    contactName: '정하린',
    contactPhone: '051-970-3300',
    timeWindow: '22:00-04:00',
    dockCount: 6,
    vehicleLimit: '냉장 차량',
    latitude: '35.0956',
    longitude: '128.8550',
    todayOrders: 11,
    delayRisk: 1,
    appointmentRequired: true,
    podRequired: true,
    temperatureControl: true,
    statusCode: 'ACTIVE',
    isActive: true,
    memo: '온도 로그 필수. 심야 입고는 경비실 승인 필요.',
  ),
  _DestinationRecord(
    id: 6,
    type: _DestinationType.store,
    destinationCode: 'STR0002',
    destinationName: '이마트 대구점',
    customerName: '이마트',
    shipperName: '신세계푸드 평택센터',
    zoneName: '대구',
    routeName: '대구 리테일',
    address: '대구광역시 북구 침산로 93',
    detailAddress: '후면 하역장',
    contactName: '오유진',
    contactPhone: '053-350-1200',
    timeWindow: '05:30-09:30',
    dockCount: 2,
    vehicleLimit: '5톤 이하',
    latitude: '35.8877',
    longitude: '128.5905',
    todayOrders: 7,
    delayRisk: 0,
    appointmentRequired: true,
    podRequired: true,
    temperatureControl: true,
    statusCode: 'INACTIVE',
    isActive: false,
    memo: '리뉴얼 공사 기간 신규 오더 사용 중지.',
  ),
];
