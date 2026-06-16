import 'package:flutter/material.dart';

import '../../design/app_theme.dart';
import '../../design/numeric_input_formatters.dart';
import 'master_api.dart';

class VehicleMasterPage extends StatefulWidget {
  const VehicleMasterPage({super.key, this.compact = false});

  final bool compact;

  @override
  State<VehicleMasterPage> createState() => _VehicleMasterPageState();
}

class _VehicleMasterPageState extends State<VehicleMasterPage> {
  final _codeController = TextEditingController();
  final _plateController = TextEditingController();
  final _carrierController = TextEditingController();
  final _driverController = TextEditingController();
  final _tonnageController = TextEditingController();
  final _payloadController = TextEditingController();
  final _volumeController = TextEditingController();
  final _fuelTypeController = TextEditingController();
  final _homeYardController = TextEditingController();
  final _insuranceExpiryController = TextEditingController();
  final _inspectionExpiryController = TextEditingController();
  final _memoController = TextEditingController();

  late final List<_VehicleRecord> _records;
  _VehicleType? _typeFilter;
  _VehicleType _selectedType = _VehicleType.wingBody;
  String _query = '';
  String _statusFilter = 'ALL';
  String _operationStatus = 'AVAILABLE';
  int? _selectedId;
  bool _isActive = true;
  bool _gpsEnabled = true;
  bool _temperatureControl = false;
  bool _tailLift = false;

  @override
  void initState() {
    super.initState();
    _records = List<_VehicleRecord>.from(_seedVehicles);
    _selectRecord(_records.first, notify: false);
  }

  @override
  void dispose() {
    _codeController.dispose();
    _plateController.dispose();
    _carrierController.dispose();
    _driverController.dispose();
    _tonnageController.dispose();
    _payloadController.dispose();
    _volumeController.dispose();
    _fuelTypeController.dispose();
    _homeYardController.dispose();
    _insuranceExpiryController.dispose();
    _inspectionExpiryController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  List<_VehicleRecord> get _filteredRecords {
    final normalizedQuery = _query.trim().toLowerCase();
    return _records.where((record) {
      final matchesType = _typeFilter == null || record.type == _typeFilter;
      final matchesStatus =
          _statusFilter == 'ALL' || record.statusCode == _statusFilter;
      final matchesQuery =
          normalizedQuery.isEmpty ||
          record.vehicleCode.toLowerCase().contains(normalizedQuery) ||
          record.plateNo.toLowerCase().contains(normalizedQuery) ||
          record.carrierName.toLowerCase().contains(normalizedQuery) ||
          record.driverName.toLowerCase().contains(normalizedQuery) ||
          record.homeYard.toLowerCase().contains(normalizedQuery);
      return matchesType && matchesStatus && matchesQuery;
    }).toList();
  }

  _VehicleRecord? get _selectedRecord {
    for (final record in _records) {
      if (record.id == _selectedId) {
        return record;
      }
    }
    return null;
  }

  void _selectRecord(_VehicleRecord record, {bool notify = true}) {
    void apply() {
      _selectedId = record.id;
      _selectedType = record.type;
      _codeController.text = record.vehicleCode;
      _plateController.text = record.plateNo;
      _carrierController.text = record.carrierName;
      _driverController.text = record.driverName;
      _tonnageController.text = record.tonnage;
      _payloadController.text = record.payloadKg.toString();
      _volumeController.text = record.volumeCbm.toString();
      _fuelTypeController.text = record.fuelType;
      _homeYardController.text = record.homeYard;
      _insuranceExpiryController.text = record.insuranceExpiry;
      _inspectionExpiryController.text = record.inspectionExpiry;
      _memoController.text = record.memo;
      _operationStatus = record.statusCode;
      _isActive = record.isActive;
      _gpsEnabled = record.gpsEnabled;
      _temperatureControl = record.temperatureControl;
      _tailLift = record.tailLift;
    }

    if (notify) {
      setState(apply);
    } else {
      apply();
    }
  }

  void _selectType(_VehicleType type) {
    setState(() {
      _typeFilter = _typeFilter == type ? null : type;
      final records = _filteredRecords;
      if (records.isNotEmpty) {
        _selectRecord(records.first, notify: false);
      } else {
        _selectedType = type;
        _clearEditor(nextCode: _nextCode(type));
      }
    });
  }

  void _clearEditor({String? nextCode}) {
    _selectedId = null;
    _selectedType = _typeFilter ?? _VehicleType.wingBody;
    _codeController.text = nextCode ?? _nextCode(_selectedType);
    _plateController.clear();
    _carrierController.text = 'CJ대한통운';
    _driverController.clear();
    _tonnageController.text = _selectedType.defaultTonnage;
    _payloadController.text = _selectedType.defaultPayload.toString();
    _volumeController.text = _selectedType.defaultVolume.toString();
    _fuelTypeController.text = 'DIESEL';
    _homeYardController.text = '용인 RDC';
    _insuranceExpiryController.text = '2027-12-31';
    _inspectionExpiryController.text = '2027-06-30';
    _memoController.clear();
    _operationStatus = 'AVAILABLE';
    _isActive = true;
    _gpsEnabled = true;
    _temperatureControl = _selectedType == _VehicleType.refrigerated;
    _tailLift = false;
  }

  String _nextCode(_VehicleType type) {
    final count = _records.where((record) => record.type == type).length + 1;
    return '${type.prefix}${count.toString().padLeft(4, '0')}';
  }

  void _startCreate() {
    setState(_clearEditor);
  }

  void _saveRecord() async {
    final plateNo = _plateController.text.trim();
    if (plateNo.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('차량번호를 입력하세요.')));
      return;
    }

    final payloadKg =
        int.tryParse(_payloadController.text.trim().replaceAll(',', '')) ?? 0;
    final volumeCbm =
        double.tryParse(_volumeController.text.trim().replaceAll(',', '')) ?? 0;
    final active = _isActive && _operationStatus != 'INACTIVE';
    final record = _VehicleRecord(
      id: _selectedId ?? _nextRecordId(),
      type: _selectedType,
      vehicleCode: _codeController.text.trim(),
      plateNo: plateNo,
      carrierName: _carrierController.text.trim(),
      driverName: _driverController.text.trim(),
      tonnage: _tonnageController.text.trim(),
      payloadKg: payloadKg,
      volumeCbm: volumeCbm,
      fuelType: _fuelTypeController.text.trim(),
      homeYard: _homeYardController.text.trim(),
      insuranceExpiry: _insuranceExpiryController.text.trim(),
      inspectionExpiry: _inspectionExpiryController.text.trim(),
      statusCode: active ? _operationStatus : 'INACTIVE',
      isActive: active,
      gpsEnabled: _gpsEnabled,
      temperatureControl: _temperatureControl,
      tailLift: _tailLift,
      todayDispatchCount: _selectedRecord?.todayDispatchCount ?? 0,
      utilizationRate: _selectedRecord?.utilizationRate ?? 0,
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

    final result = await MasterApi.instance.saveVehicle(record.toApiPayload());
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.failed
              ? '${record.plateNo} 차량 화면 반영 완료, DB 저장 실패: ${result.message}'
              : '${record.plateNo} 차량 마스터가 반영되었습니다.',
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
          _VehicleHeader(
            totalCount: filteredRecords.length,
            activeCount: filteredRecords
                .where((record) => record.assignable)
                .length,
            onCreate: _startCreate,
          ),
          const SizedBox(height: 16),
          _VehicleTypeSelector(
            selectedType: _typeFilter,
            counts: {
              for (final type in _VehicleType.values)
                type: _records.where((record) => record.type == type).length,
            },
            onSelect: _selectType,
          ),
          const SizedBox(height: 16),
          _VehicleStats(records: filteredRecords),
          const SizedBox(height: 16),
          _VehicleToolbar(
            query: _query,
            statusFilter: _statusFilter,
            onQueryChanged: (value) => setState(() => _query = value),
            onStatusChanged: (value) =>
                setState(() => _statusFilter = value ?? 'ALL'),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 980 && !widget.compact;
              if (!wide) {
                return Column(
                  children: [
                    _FleetAvailabilityPanel(records: filteredRecords),
                    const SizedBox(height: 16),
                    _VehicleEditorPanel(
                      selectedType: _selectedType,
                      selectedRecord: selectedRecord,
                      codeController: _codeController,
                      plateController: _plateController,
                      carrierController: _carrierController,
                      driverController: _driverController,
                      tonnageController: _tonnageController,
                      payloadController: _payloadController,
                      volumeController: _volumeController,
                      fuelTypeController: _fuelTypeController,
                      homeYardController: _homeYardController,
                      insuranceExpiryController: _insuranceExpiryController,
                      inspectionExpiryController: _inspectionExpiryController,
                      memoController: _memoController,
                      operationStatus: _operationStatus,
                      isActive: _isActive,
                      gpsEnabled: _gpsEnabled,
                      temperatureControl: _temperatureControl,
                      tailLift: _tailLift,
                      onTypeChanged: (value) =>
                          setState(() => _selectedType = value),
                      onStatusChanged: (value) =>
                          setState(() => _operationStatus = value),
                      onActiveChanged: (value) =>
                          setState(() => _isActive = value),
                      onGpsChanged: (value) =>
                          setState(() => _gpsEnabled = value),
                      onTemperatureChanged: (value) =>
                          setState(() => _temperatureControl = value),
                      onTailLiftChanged: (value) =>
                          setState(() => _tailLift = value),
                      onSave: _saveRecord,
                    ),
                    const SizedBox(height: 16),
                    _VehicleDirectoryPanel(
                      records: filteredRecords,
                      selectedId: _selectedId,
                      onSelect: _selectRecord,
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 13,
                    child: Column(
                      children: [
                        _FleetAvailabilityPanel(records: filteredRecords),
                        const SizedBox(height: 16),
                        _VehicleDirectoryPanel(
                          records: filteredRecords,
                          selectedId: _selectedId,
                          onSelect: _selectRecord,
                          dense: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 8,
                    child: _VehicleEditorPanel(
                      selectedType: _selectedType,
                      selectedRecord: selectedRecord,
                      codeController: _codeController,
                      plateController: _plateController,
                      carrierController: _carrierController,
                      driverController: _driverController,
                      tonnageController: _tonnageController,
                      payloadController: _payloadController,
                      volumeController: _volumeController,
                      fuelTypeController: _fuelTypeController,
                      homeYardController: _homeYardController,
                      insuranceExpiryController: _insuranceExpiryController,
                      inspectionExpiryController: _inspectionExpiryController,
                      memoController: _memoController,
                      operationStatus: _operationStatus,
                      isActive: _isActive,
                      gpsEnabled: _gpsEnabled,
                      temperatureControl: _temperatureControl,
                      tailLift: _tailLift,
                      onTypeChanged: (value) =>
                          setState(() => _selectedType = value),
                      onStatusChanged: (value) =>
                          setState(() => _operationStatus = value),
                      onActiveChanged: (value) =>
                          setState(() => _isActive = value),
                      onGpsChanged: (value) =>
                          setState(() => _gpsEnabled = value),
                      onTemperatureChanged: (value) =>
                          setState(() => _temperatureControl = value),
                      onTailLiftChanged: (value) =>
                          setState(() => _tailLift = value),
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

class _VehicleHeader extends StatelessWidget {
  const _VehicleHeader({
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
                icon: Icons.fire_truck_rounded,
                color: AppTheme.amber,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '차량 마스터',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: AppTheme.graphite,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '차량번호, 톤급, 제원, GPS, 보험/검사, 배차 가능 상태 기준정보',
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
              _InlineMetric(label: '배차가능', value: '$activeCount'),
              ElevatedButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded, size: 19),
                label: const Text('차량 등록'),
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

class _VehicleTypeSelector extends StatelessWidget {
  const _VehicleTypeSelector({
    required this.selectedType,
    required this.counts,
    required this.onSelect,
  });

  final _VehicleType? selectedType;
  final Map<_VehicleType, int> counts;
  final ValueChanged<_VehicleType> onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100
            ? 5
            : constraints.maxWidth >= 760
            ? 3
            : 1;
        final spacing = 12.0;
        final width =
            (constraints.maxWidth - (columns - 1) * spacing) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: 10,
          children: _VehicleType.values.map((type) {
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
                    height: 84,
                    padding: const EdgeInsets.all(12),
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
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                type.typeCode,
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

class _VehicleStats extends StatelessWidget {
  const _VehicleStats({required this.records});

  final List<_VehicleRecord> records;

  @override
  Widget build(BuildContext context) {
    final assignable = records.where((record) => record.assignable).length;
    final dispatched = records.fold<int>(
      0,
      (sum, record) => sum + record.todayDispatchCount,
    );
    final maintenance = records
        .where((record) => record.statusCode == 'MAINTENANCE')
        .length;
    final expiringDocs = records.where((record) => record.documentRisk).length;
    final coldChain = records
        .where((record) => record.temperatureControl)
        .length;

    final metrics = [
      _Metric(
        label: '배차 가능',
        value: '$assignable',
        icon: Icons.verified_rounded,
        color: AppTheme.teal,
      ),
      _Metric(
        label: '오늘 배차',
        value: '$dispatched',
        icon: Icons.route_rounded,
        color: AppTheme.cyan,
      ),
      _Metric(
        label: '정비/보류',
        value: '$maintenance',
        icon: Icons.build_circle_rounded,
        color: AppTheme.amber,
      ),
      _Metric(
        label: '문서 확인',
        value: '$expiringDocs',
        icon: Icons.policy_rounded,
        color: const Color(0xFFDC2626),
      ),
      _Metric(
        label: '온도 차량',
        value: '$coldChain',
        icon: Icons.ac_unit_rounded,
        color: const Color(0xFF2563EB),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1200
            ? 5
            : constraints.maxWidth >= 900
            ? 3
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

class _VehicleToolbar extends StatelessWidget {
  const _VehicleToolbar({
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
              labelText: '차량 검색',
              hintText: '차량 코드, 차량번호, 운송사, 기사, 차고지',
            ),
          );

          final filter = DropdownButtonFormField<String>(
            initialValue: statusFilter,
            onChanged: onStatusChanged,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.filter_list_rounded),
              labelText: '운영상태',
            ),
            items: const [
              DropdownMenuItem(value: 'ALL', child: Text('전체')),
              DropdownMenuItem(value: 'AVAILABLE', child: Text('배차 가능')),
              DropdownMenuItem(value: 'DISPATCHED', child: Text('운행 중')),
              DropdownMenuItem(value: 'MAINTENANCE', child: Text('정비')),
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
              SizedBox(width: 210, child: filter),
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

class _FleetAvailabilityPanel extends StatelessWidget {
  const _FleetAvailabilityPanel({required this.records});

  final List<_VehicleRecord> records;

  @override
  Widget build(BuildContext context) {
    final total = records.isEmpty ? 1 : records.length;
    final available = records
        .where((record) => record.statusCode == 'AVAILABLE' && record.isActive)
        .length;
    final dispatched = records
        .where((record) => record.statusCode == 'DISPATCHED')
        .length;
    final maintenance = records
        .where((record) => record.statusCode == 'MAINTENANCE')
        .length;
    final inactive = records.where((record) => !record.isActive).length;

    return _SurfacePanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.local_shipping_rounded,
            title: '차량 가용 현황',
            subtitle: '배차 가능, 운행, 정비, 비활성 차량 비율',
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 16,
              child: Row(
                children: [
                  _AvailabilitySegment(
                    flex: available,
                    color: AppTheme.teal,
                    fallback: total,
                  ),
                  _AvailabilitySegment(
                    flex: dispatched,
                    color: const Color(0xFF2563EB),
                    fallback: total,
                  ),
                  _AvailabilitySegment(
                    flex: maintenance,
                    color: AppTheme.amber,
                    fallback: total,
                  ),
                  _AvailabilitySegment(
                    flex: inactive,
                    color: AppTheme.slate,
                    fallback: total,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _LegendChip(color: AppTheme.teal, label: '배차 가능 $available'),
              _LegendChip(
                color: const Color(0xFF2563EB),
                label: '운행 $dispatched',
              ),
              _LegendChip(color: AppTheme.amber, label: '정비 $maintenance'),
              _LegendChip(color: AppTheme.slate, label: '비활성 $inactive'),
            ],
          ),
        ],
      ),
    );
  }
}

class _AvailabilitySegment extends StatelessWidget {
  const _AvailabilitySegment({
    required this.flex,
    required this.color,
    required this.fallback,
  });

  final int flex;
  final Color color;
  final int fallback;

  @override
  Widget build(BuildContext context) {
    if (flex <= 0) {
      return const SizedBox.shrink();
    }
    return Expanded(
      flex: flex,
      child: ColoredBox(color: color, child: const SizedBox.expand()),
    );
  }
}

class _VehicleDirectoryPanel extends StatelessWidget {
  const _VehicleDirectoryPanel({
    required this.records,
    required this.selectedId,
    required this.onSelect,
    this.dense = false,
  });

  final List<_VehicleRecord> records;
  final int? selectedId;
  final ValueChanged<_VehicleRecord> onSelect;
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
            title: '차량 목록',
            subtitle: 'vehicles',
          ),
          const SizedBox(height: 14),
          if (records.isEmpty)
            const _EmptyState()
          else
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 880 || !dense) {
                  return Column(
                    children: records
                        .map(
                          (record) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _VehicleListTile(
                              record: record,
                              selected: selectedId == record.id,
                              onTap: () => onSelect(record),
                            ),
                          ),
                        )
                        .toList(),
                  );
                }

                return _VehicleTable(
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

class _VehicleTable extends StatelessWidget {
  const _VehicleTable({
    required this.records,
    required this.selectedId,
    required this.onSelect,
  });

  final List<_VehicleRecord> records;
  final int? selectedId;
  final ValueChanged<_VehicleRecord> onSelect;

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
            DataColumn(label: Text('차량 코드')),
            DataColumn(label: Text('차량번호')),
            DataColumn(label: Text('유형')),
            DataColumn(label: Text('운송사')),
            DataColumn(label: Text('기사')),
            DataColumn(label: Text('톤급/적재')),
            DataColumn(label: Text('상태')),
          ],
          rows: records.map((record) {
            return DataRow(
              selected: selectedId == record.id,
              onSelectChanged: (_) => onSelect(record),
              cells: [
                DataCell(_StrongText(record.vehicleCode)),
                DataCell(_BoundedText(record.plateNo, width: 110)),
                DataCell(Text(record.type.label)),
                DataCell(_BoundedText(record.carrierName, width: 140)),
                DataCell(Text(record.driverName)),
                DataCell(Text('${record.tonnage} / ${record.payloadKg}kg')),
                DataCell(_StatusPill(record: record)),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _VehicleListTile extends StatelessWidget {
  const _VehicleListTile({
    required this.record,
    required this.selected,
    required this.onTap,
  });

  final _VehicleRecord record;
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
                          record.plateNo,
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
                          '${record.vehicleCode} · ${record.carrierName}',
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
                  _StatusPill(record: record),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _TinyInfo(
                    icon: Icons.scale_rounded,
                    label: '${record.tonnage} / ${record.payloadKg}kg',
                  ),
                  _TinyInfo(
                    icon: Icons.person_rounded,
                    label: record.driverName,
                  ),
                  _TinyInfo(
                    icon: Icons.route_rounded,
                    label: '${record.todayDispatchCount}건 배차',
                  ),
                  if (record.temperatureControl)
                    const _TinyInfo(icon: Icons.ac_unit_rounded, label: '온도'),
                  if (record.gpsEnabled)
                    const _TinyInfo(
                      icon: Icons.gps_fixed_rounded,
                      label: 'GPS',
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

class _VehicleEditorPanel extends StatelessWidget {
  const _VehicleEditorPanel({
    required this.selectedType,
    required this.selectedRecord,
    required this.codeController,
    required this.plateController,
    required this.carrierController,
    required this.driverController,
    required this.tonnageController,
    required this.payloadController,
    required this.volumeController,
    required this.fuelTypeController,
    required this.homeYardController,
    required this.insuranceExpiryController,
    required this.inspectionExpiryController,
    required this.memoController,
    required this.operationStatus,
    required this.isActive,
    required this.gpsEnabled,
    required this.temperatureControl,
    required this.tailLift,
    required this.onTypeChanged,
    required this.onStatusChanged,
    required this.onActiveChanged,
    required this.onGpsChanged,
    required this.onTemperatureChanged,
    required this.onTailLiftChanged,
    required this.onSave,
  });

  final _VehicleType selectedType;
  final _VehicleRecord? selectedRecord;
  final TextEditingController codeController;
  final TextEditingController plateController;
  final TextEditingController carrierController;
  final TextEditingController driverController;
  final TextEditingController tonnageController;
  final TextEditingController payloadController;
  final TextEditingController volumeController;
  final TextEditingController fuelTypeController;
  final TextEditingController homeYardController;
  final TextEditingController insuranceExpiryController;
  final TextEditingController inspectionExpiryController;
  final TextEditingController memoController;
  final String operationStatus;
  final bool isActive;
  final bool gpsEnabled;
  final bool temperatureControl;
  final bool tailLift;
  final ValueChanged<_VehicleType> onTypeChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<bool> onActiveChanged;
  final ValueChanged<bool> onGpsChanged;
  final ValueChanged<bool> onTemperatureChanged;
  final ValueChanged<bool> onTailLiftChanged;
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
            title: '차량 상세',
            subtitle: selectedRecord?.vehicleCode ?? selectedType.typeCode,
          ),
          const SizedBox(height: 14),
          _EditorActions(onSave: onSave),
          const SizedBox(height: 16),
          _EditorSummary(
            color: selectedType.color,
            items: [
              _TinyInfo(
                icon: Icons.route_rounded,
                label: '${selectedRecord?.todayDispatchCount ?? 0}건 오늘',
              ),
              _TinyInfo(
                icon: Icons.speed_rounded,
                label: '${selectedRecord?.utilizationRate ?? 0}%',
              ),
              _TinyInfo(
                icon: Icons.policy_rounded,
                label: selectedRecord?.documentLabel ?? '문서 확인',
              ),
            ],
          ),
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
                      label: '차량 코드',
                      icon: Icons.tag_rounded,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: DropdownButtonFormField<_VehicleType>(
                      initialValue: selectedType,
                      onChanged: (value) {
                        if (value != null) {
                          onTypeChanged(value);
                        }
                      },
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.fire_truck_rounded),
                        labelText: '차량 유형',
                      ),
                      items: _VehicleType.values
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
                      controller: plateController,
                      label: '차량번호',
                      icon: Icons.confirmation_number_rounded,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: DropdownButtonFormField<String>(
                      initialValue: operationStatus,
                      onChanged: (value) {
                        if (value != null) {
                          onStatusChanged(value);
                        }
                      },
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.fact_check_rounded),
                        labelText: '운영상태',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'AVAILABLE',
                          child: Text('배차 가능'),
                        ),
                        DropdownMenuItem(
                          value: 'DISPATCHED',
                          child: Text('운행 중'),
                        ),
                        DropdownMenuItem(
                          value: 'MAINTENANCE',
                          child: Text('정비'),
                        ),
                        DropdownMenuItem(value: 'INACTIVE', child: Text('비활성')),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _TextInput(
                      controller: carrierController,
                      label: '소속 운송사',
                      icon: Icons.business_rounded,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _TextInput(
                      controller: driverController,
                      label: '기본 기사',
                      icon: Icons.person_rounded,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _TextInput(
                      controller: tonnageController,
                      label: '톤급',
                      icon: Icons.local_shipping_rounded,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _TextInput(
                      controller: payloadController,
                      label: '최대 적재 kg',
                      icon: Icons.scale_rounded,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _TextInput(
                      controller: volumeController,
                      label: '적재 용적 CBM',
                      icon: Icons.inventory_2_rounded,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _TextInput(
                      controller: fuelTypeController,
                      label: '연료',
                      icon: Icons.local_gas_station_rounded,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _TextInput(
                      controller: homeYardController,
                      label: '기준 차고지',
                      icon: Icons.garage_rounded,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _TextInput(
                      controller: insuranceExpiryController,
                      label: '보험 만료일',
                      icon: Icons.policy_rounded,
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _TextInput(
                      controller: inspectionExpiryController,
                      label: '검사 만료일',
                      icon: Icons.verified_user_rounded,
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
          _SwitchRow(
            title: '신규 배차 사용',
            subtitle: isActive ? 'is_active = true' : 'is_active = false',
            value: isActive,
            onChanged: onActiveChanged,
          ),
          const SizedBox(height: 10),
          _SwitchRow(
            title: 'GPS 추적',
            subtitle: '실행 트래킹 및 도착 예측 사용',
            value: gpsEnabled,
            onChanged: onGpsChanged,
          ),
          const SizedBox(height: 10),
          _SwitchRow(
            title: '온도 관리',
            subtitle: '냉장/냉동 품목 배차 가능',
            value: temperatureControl,
            onChanged: onTemperatureChanged,
          ),
          const SizedBox(height: 10),
          _SwitchRow(
            title: '리프트 장착',
            subtitle: '상하차 보조 장비 보유',
            value: tailLift,
            onChanged: onTailLiftChanged,
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

  final _Metric metric;

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
        color: color.withValues(alpha: 0.10),
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
            style: const TextStyle(
              color: AppTheme.slate,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
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
    return Container(
      constraints: const BoxConstraints(minWidth: 34),
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
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
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.record});

  final _VehicleRecord record;

  @override
  Widget build(BuildContext context) {
    final color = record.statusColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        record.statusLabel,
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
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
              color: AppTheme.slate,
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

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
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
    return OutlinedButton.icon(
      onPressed: () {},
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(minimumSize: const Size(112, 52)),
    );
  }
}

class _TextInput extends StatelessWidget {
  const _TextInput({
    required this.controller,
    required this.label,
    required this.icon,
    this.maxLines = 1,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: KtmsNumericInputFormatters.forKeyboardType(
        keyboardType,
        label: label,
      ),
      decoration: InputDecoration(prefixIcon: Icon(icon), labelText: label),
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

class _BoundedText extends StatelessWidget {
  const _BoundedText(this.text, {required this.width});

  final String text;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
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
                  style: const TextStyle(
                    color: AppTheme.slate,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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

class _EditorSummary extends StatelessWidget {
  const _EditorSummary({required this.color, required this.items});

  final Color color;
  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Wrap(spacing: 8, runSpacing: 8, children: items),
    );
  }
}

class _EditorActions extends StatelessWidget {
  const _EditorActions({required this.onSave});

  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Row(
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
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.line),
      ),
      child: const Text(
        '조회된 차량 기준정보가 없습니다.',
        style: TextStyle(color: AppTheme.slate, letterSpacing: 0),
      ),
    );
  }
}

enum _VehicleType {
  wingBody,
  cargo,
  refrigerated,
  trailer,
  container;

  String get label => switch (this) {
    _VehicleType.wingBody => '윙바디',
    _VehicleType.cargo => '카고',
    _VehicleType.refrigerated => '냉장/냉동',
    _VehicleType.trailer => '트레일러',
    _VehicleType.container => '컨테이너',
  };

  String get typeCode => switch (this) {
    _VehicleType.wingBody => 'WING_BODY',
    _VehicleType.cargo => 'CARGO',
    _VehicleType.refrigerated => 'REEFER',
    _VehicleType.trailer => 'TRAILER',
    _VehicleType.container => 'CONTAINER',
  };

  String get prefix => switch (this) {
    _VehicleType.wingBody => 'VEH-WB',
    _VehicleType.cargo => 'VEH-CG',
    _VehicleType.refrigerated => 'VEH-RF',
    _VehicleType.trailer => 'VEH-TR',
    _VehicleType.container => 'VEH-CT',
  };

  String get defaultTonnage => switch (this) {
    _VehicleType.wingBody => '11톤',
    _VehicleType.cargo => '5톤',
    _VehicleType.refrigerated => '5톤 냉장',
    _VehicleType.trailer => '25톤',
    _VehicleType.container => '40FT',
  };

  int get defaultPayload => switch (this) {
    _VehicleType.wingBody => 11000,
    _VehicleType.cargo => 5000,
    _VehicleType.refrigerated => 4500,
    _VehicleType.trailer => 25000,
    _VehicleType.container => 26000,
  };

  double get defaultVolume => switch (this) {
    _VehicleType.wingBody => 52,
    _VehicleType.cargo => 31,
    _VehicleType.refrigerated => 28,
    _VehicleType.trailer => 86,
    _VehicleType.container => 67,
  };

  IconData get icon => switch (this) {
    _VehicleType.wingBody => Icons.fire_truck_rounded,
    _VehicleType.cargo => Icons.local_shipping_rounded,
    _VehicleType.refrigerated => Icons.ac_unit_rounded,
    _VehicleType.trailer => Icons.rv_hookup_rounded,
    _VehicleType.container => Icons.inventory_2_rounded,
  };

  Color get color => switch (this) {
    _VehicleType.wingBody => AppTheme.amber,
    _VehicleType.cargo => AppTheme.teal,
    _VehicleType.refrigerated => const Color(0xFF2563EB),
    _VehicleType.trailer => const Color(0xFF7C3AED),
    _VehicleType.container => AppTheme.cyan,
  };
}

class _VehicleRecord {
  const _VehicleRecord({
    required this.id,
    required this.type,
    required this.vehicleCode,
    required this.plateNo,
    required this.carrierName,
    required this.driverName,
    required this.tonnage,
    required this.payloadKg,
    required this.volumeCbm,
    required this.fuelType,
    required this.homeYard,
    required this.insuranceExpiry,
    required this.inspectionExpiry,
    required this.statusCode,
    required this.isActive,
    required this.gpsEnabled,
    required this.temperatureControl,
    required this.tailLift,
    required this.todayDispatchCount,
    required this.utilizationRate,
    required this.memo,
  });

  final int id;
  final _VehicleType type;
  final String vehicleCode;
  final String plateNo;
  final String carrierName;
  final String driverName;
  final String tonnage;
  final int payloadKg;
  final double volumeCbm;
  final String fuelType;
  final String homeYard;
  final String insuranceExpiry;
  final String inspectionExpiry;
  final String statusCode;
  final bool isActive;
  final bool gpsEnabled;
  final bool temperatureControl;
  final bool tailLift;
  final int todayDispatchCount;
  final int utilizationRate;
  final String memo;

  Map<String, Object?> toApiPayload() {
    return {
      'vehicle_code': vehicleCode,
      'plate_no': plateNo,
      'vehicle_type': type.typeCode,
      'carrier_name': carrierName,
      'driver_name': driverName,
      'tonnage': tonnage,
      'max_weight_kg': payloadKg,
      'max_volume_cbm': volumeCbm,
      'fuel_type': fuelType,
      'home_yard': homeYard,
      'insurance_expiry': insuranceExpiry,
      'inspection_expiry': inspectionExpiry,
      'status': statusCode,
      'is_active': isActive,
      'gps_enabled': gpsEnabled,
      'temperature_controlled': temperatureControl,
      'tail_lift': tailLift,
      'metadata': {
        'today_dispatch_count': todayDispatchCount,
        'utilization_rate': utilizationRate,
        'memo': memo,
      },
    };
  }

  bool get assignable => isActive && statusCode == 'AVAILABLE';

  bool get documentRisk {
    return insuranceExpiry.compareTo('2026-09-30') <= 0 ||
        inspectionExpiry.compareTo('2026-09-30') <= 0;
  }

  String get documentLabel => documentRisk ? '문서 확인' : '문서 정상';

  String get statusLabel => switch (statusCode) {
    'AVAILABLE' => '배차 가능',
    'DISPATCHED' => '운행 중',
    'MAINTENANCE' => '정비',
    'INACTIVE' => '비활성',
    _ => statusCode,
  };

  Color get statusColor => switch (statusCode) {
    'AVAILABLE' => AppTheme.teal,
    'DISPATCHED' => const Color(0xFF2563EB),
    'MAINTENANCE' => AppTheme.amber,
    'INACTIVE' => AppTheme.slate,
    _ => AppTheme.slate,
  };
}

class _Metric {
  const _Metric({
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

const _seedVehicles = [
  _VehicleRecord(
    id: 1,
    type: _VehicleType.wingBody,
    vehicleCode: 'VEH-WB0001',
    plateNo: '서울 84바 7291',
    carrierName: 'CJ대한통운',
    driverName: '김도윤',
    tonnage: '11톤',
    payloadKg: 11000,
    volumeCbm: 52,
    fuelType: 'DIESEL',
    homeYard: '용인 RDC',
    insuranceExpiry: '2027-12-31',
    inspectionExpiry: '2027-05-31',
    statusCode: 'AVAILABLE',
    isActive: true,
    gpsEnabled: true,
    temperatureControl: false,
    tailLift: true,
    todayDispatchCount: 2,
    utilizationRate: 86,
    memo: '수도권 순환 우선 배정. 리프트 사용 가능.',
  ),
  _VehicleRecord(
    id: 2,
    type: _VehicleType.cargo,
    vehicleCode: 'VEH-CG0001',
    plateNo: '경기 91아 4826',
    carrierName: 'OO운송',
    driverName: '박민재',
    tonnage: '5톤',
    payloadKg: 5000,
    volumeCbm: 31,
    fuelType: 'DIESEL',
    homeYard: '평택 공장',
    insuranceExpiry: '2027-08-20',
    inspectionExpiry: '2026-08-15',
    statusCode: 'DISPATCHED',
    isActive: true,
    gpsEnabled: true,
    temperatureControl: false,
    tailLift: false,
    todayDispatchCount: 3,
    utilizationRate: 92,
    memo: '평택-용인 고정 셔틀. 검사 만료 사전 확인 필요.',
  ),
  _VehicleRecord(
    id: 3,
    type: _VehicleType.refrigerated,
    vehicleCode: 'VEH-RF0001',
    plateNo: '광주 80사 1164',
    carrierName: '콜드체인로지스',
    driverName: '이서준',
    tonnage: '5톤 냉장',
    payloadKg: 4500,
    volumeCbm: 28,
    fuelType: 'DIESEL',
    homeYard: '광주 물류센터',
    insuranceExpiry: '2028-01-31',
    inspectionExpiry: '2027-03-30',
    statusCode: 'AVAILABLE',
    isActive: true,
    gpsEnabled: true,
    temperatureControl: true,
    tailLift: true,
    todayDispatchCount: 1,
    utilizationRate: 74,
    memo: '냉장/냉동 겸용. 온도 이탈 알림 정상.',
  ),
  _VehicleRecord(
    id: 4,
    type: _VehicleType.trailer,
    vehicleCode: 'VEH-TR0001',
    plateNo: '부산 97자 3388',
    carrierName: '동남물류',
    driverName: '최현우',
    tonnage: '25톤',
    payloadKg: 25000,
    volumeCbm: 86,
    fuelType: 'DIESEL',
    homeYard: '양산 CDC',
    insuranceExpiry: '2027-11-15',
    inspectionExpiry: '2027-07-10',
    statusCode: 'AVAILABLE',
    isActive: true,
    gpsEnabled: true,
    temperatureControl: false,
    tailLift: false,
    todayDispatchCount: 1,
    utilizationRate: 69,
    memo: '장거리 간선 우선. 부산항 야드 반입 가능.',
  ),
  _VehicleRecord(
    id: 5,
    type: _VehicleType.container,
    vehicleCode: 'VEH-CT0001',
    plateNo: '인천 99허 7204',
    carrierName: 'KCTC',
    driverName: '정하준',
    tonnage: '40FT',
    payloadKg: 26000,
    volumeCbm: 67,
    fuelType: 'DIESEL',
    homeYard: '인천항',
    insuranceExpiry: '2026-09-15',
    inspectionExpiry: '2026-10-20',
    statusCode: 'MAINTENANCE',
    isActive: true,
    gpsEnabled: true,
    temperatureControl: false,
    tailLift: false,
    todayDispatchCount: 0,
    utilizationRate: 41,
    memo: '샤시 정비 중. 보험 만료 전 갱신 필요.',
  ),
  _VehicleRecord(
    id: 6,
    type: _VehicleType.wingBody,
    vehicleCode: 'VEH-WB0002',
    plateNo: '대전 82바 4417',
    carrierName: '한빛운송',
    driverName: '윤지호',
    tonnage: '8톤',
    payloadKg: 8000,
    volumeCbm: 43,
    fuelType: 'LNG',
    homeYard: '대전 허브',
    insuranceExpiry: '2028-04-30',
    inspectionExpiry: '2027-09-30',
    statusCode: 'INACTIVE',
    isActive: false,
    gpsEnabled: false,
    temperatureControl: false,
    tailLift: false,
    todayDispatchCount: 0,
    utilizationRate: 0,
    memo: '계약 종료 예정 차량. 신규 배차 제한.',
  ),
];
