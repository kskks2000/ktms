import 'package:flutter/material.dart';

import '../../design/app_theme.dart';
import '../../design/numeric_input_formatters.dart';
import 'master_api.dart';

class WarehouseHubMasterPage extends StatefulWidget {
  const WarehouseHubMasterPage({super.key, this.compact = false});

  final bool compact;

  @override
  State<WarehouseHubMasterPage> createState() => _WarehouseHubMasterPageState();
}

class _WarehouseHubMasterPageState extends State<WarehouseHubMasterPage> {
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _operatorController = TextEditingController();
  final _addressController = TextEditingController();
  final _detailAddressController = TextEditingController();
  final _stateController = TextEditingController();
  final _cityController = TextEditingController();
  final _districtController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _operatingHoursController = TextEditingController();
  final _dockCountController = TextEditingController();
  final _stagingCapacityController = TextEditingController();
  final _storageCapacityController = TextEditingController();
  final _yardCapacityController = TextEditingController();
  final _temperatureZoneController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _geofenceController = TextEditingController();
  final _memoController = TextEditingController();

  late final List<_FacilityRecord> _records;
  _FacilityType? _typeFilter;
  _FacilityType _selectedType = _FacilityType.warehouse;
  _FacilityStatus _selectedStatus = _FacilityStatus.operating;
  String _query = '';
  String _statusFilter = 'ALL';
  int? _selectedId;
  bool _isActive = true;
  bool _temperatureControlled = false;
  bool _appointmentRequired = true;
  bool _bondedArea = false;
  bool _yardManagement = false;

  @override
  void initState() {
    super.initState();
    _records = List<_FacilityRecord>.from(_seedFacilities);
    _selectRecord(_records.first, notify: false);
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _operatorController.dispose();
    _addressController.dispose();
    _detailAddressController.dispose();
    _stateController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _operatingHoursController.dispose();
    _dockCountController.dispose();
    _stagingCapacityController.dispose();
    _storageCapacityController.dispose();
    _yardCapacityController.dispose();
    _temperatureZoneController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _geofenceController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  List<_FacilityRecord> get _filteredRecords {
    final normalizedQuery = _query.trim().toLowerCase();
    return _records.where((record) {
      final matchesType = _typeFilter == null || record.type == _typeFilter;
      final matchesStatus =
          _statusFilter == 'ALL' || record.statusCode == _statusFilter;
      final matchesQuery =
          normalizedQuery.isEmpty ||
          record.facilityCode.toLowerCase().contains(normalizedQuery) ||
          record.facilityName.toLowerCase().contains(normalizedQuery) ||
          record.operatorName.toLowerCase().contains(normalizedQuery) ||
          record.city.toLowerCase().contains(normalizedQuery) ||
          record.address.toLowerCase().contains(normalizedQuery) ||
          record.temperatureZone.toLowerCase().contains(normalizedQuery);
      return matchesType && matchesStatus && matchesQuery;
    }).toList();
  }

  _FacilityRecord? get _selectedRecord {
    for (final record in _records) {
      if (record.id == _selectedId) {
        return record;
      }
    }
    return null;
  }

  void _selectRecord(_FacilityRecord record, {bool notify = true}) {
    void apply() {
      _selectedId = record.id;
      _selectedType = record.type;
      _selectedStatus = record.status;
      _codeController.text = record.facilityCode;
      _nameController.text = record.facilityName;
      _operatorController.text = record.operatorName;
      _addressController.text = record.address;
      _detailAddressController.text = record.detailAddress;
      _stateController.text = record.stateProvince;
      _cityController.text = record.city;
      _districtController.text = record.district;
      _contactNameController.text = record.contactName;
      _contactPhoneController.text = record.contactPhone;
      _operatingHoursController.text = record.operatingHours;
      _dockCountController.text = record.dockCount.toString();
      _stagingCapacityController.text = record.stagingCapacity.toString();
      _storageCapacityController.text = record.storageCapacity.toString();
      _yardCapacityController.text = record.yardCapacity.toString();
      _temperatureZoneController.text = record.temperatureZone;
      _latitudeController.text = record.latitude;
      _longitudeController.text = record.longitude;
      _geofenceController.text = record.geofenceRadiusM.toString();
      _memoController.text = record.memo;
      _isActive = record.isActive;
      _temperatureControlled = record.temperatureControlled;
      _appointmentRequired = record.appointmentRequired;
      _bondedArea = record.bondedArea;
      _yardManagement = record.yardManagement;
    }

    if (notify) {
      setState(apply);
    } else {
      apply();
    }
  }

  void _clearEditor() {
    _selectedId = null;
    _selectedType = _typeFilter ?? _FacilityType.warehouse;
    _selectedStatus = _FacilityStatus.operating;
    _codeController.text = _nextCode(_selectedType);
    _nameController.clear();
    _operatorController.text = 'KCASTLE 본사';
    _addressController.clear();
    _detailAddressController.clear();
    _stateController.text = '경기도';
    _cityController.clear();
    _districtController.clear();
    _contactNameController.clear();
    _contactPhoneController.clear();
    _operatingHoursController.text = '08:00-20:00';
    _dockCountController.text = '8';
    _stagingCapacityController.text = '1200';
    _storageCapacityController.text = '8000';
    _yardCapacityController.text = '60';
    _temperatureZoneController.text = '상온';
    _latitudeController.clear();
    _longitudeController.clear();
    _geofenceController.text = '300';
    _memoController.clear();
    _isActive = true;
    _temperatureControlled = false;
    _appointmentRequired = true;
    _bondedArea = false;
    _yardManagement = true;
  }

  String _nextCode(_FacilityType type) {
    final count = _records.where((record) => record.type == type).length + 1;
    return '${type.prefix}${count.toString().padLeft(4, '0')}';
  }

  void _startCreate() {
    setState(_clearEditor);
  }

  Future<void> _saveRecord() async {
    final facilityName = _nameController.text.trim();
    if (facilityName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('창고/거점명을 입력하세요.')));
      return;
    }

    final active = _isActive && _selectedStatus != _FacilityStatus.inactive;
    final record = _FacilityRecord(
      id: _selectedId ?? _nextRecordId(),
      type: _selectedType,
      facilityCode: _codeController.text.trim(),
      facilityName: facilityName,
      operatorName: _operatorController.text.trim(),
      address: _addressController.text.trim(),
      detailAddress: _detailAddressController.text.trim(),
      stateProvince: _stateController.text.trim(),
      city: _cityController.text.trim(),
      district: _districtController.text.trim(),
      contactName: _contactNameController.text.trim(),
      contactPhone: _contactPhoneController.text.trim(),
      operatingHours: _operatingHoursController.text.trim(),
      dockCount: int.tryParse(_dockCountController.text.trim()) ?? 0,
      stagingCapacity:
          int.tryParse(_stagingCapacityController.text.trim()) ?? 0,
      storageCapacity:
          int.tryParse(_storageCapacityController.text.trim()) ?? 0,
      yardCapacity: int.tryParse(_yardCapacityController.text.trim()) ?? 0,
      temperatureZone: _temperatureZoneController.text.trim(),
      latitude: _latitudeController.text.trim(),
      longitude: _longitudeController.text.trim(),
      geofenceRadiusM: int.tryParse(_geofenceController.text.trim()) ?? 300,
      status: active ? _selectedStatus : _FacilityStatus.inactive,
      isActive: active,
      temperatureControlled: _temperatureControlled,
      appointmentRequired: _appointmentRequired,
      bondedArea: _bondedArea,
      yardManagement: _yardManagement,
      todayInbound: _selectedRecord?.todayInbound ?? 0,
      todayOutbound: _selectedRecord?.todayOutbound ?? 0,
      utilizationRate: _selectedRecord?.utilizationRate ?? 72,
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
              ? '${record.facilityName} 창고/거점 화면 반영 완료, DB 저장 실패: ${result.message}'
              : '${record.facilityName} 창고/거점이 반영되었습니다.',
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
        final wide = constraints.maxWidth >= 1120 && !widget.compact;
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
              _FacilityHeader(onCreate: _startCreate),
              const SizedBox(height: 16),
              _FacilityStats(records: _records),
              const SizedBox(height: 16),
              _FacilityTypeSelector(
                selectedType: _typeFilter,
                counts: {
                  for (final type in _FacilityType.values)
                    type: _records
                        .where((record) => record.type == type)
                        .length,
                },
                onSelect: (type) => setState(() {
                  _typeFilter = _typeFilter == type ? null : type;
                  final records = _filteredRecords;
                  if (records.isNotEmpty) {
                    _selectRecord(records.first, notify: false);
                  }
                }),
              ),
              const SizedBox(height: 12),
              _FacilityToolbar(
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
                      child: _FacilityDirectoryPanel(
                        records: filteredRecords,
                        selectedId: _selectedId,
                        onSelect: _selectRecord,
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 440,
                      child: _FacilityEditorPanel(
                        selectedRecord: selectedRecord,
                        codeController: _codeController,
                        nameController: _nameController,
                        operatorController: _operatorController,
                        addressController: _addressController,
                        detailAddressController: _detailAddressController,
                        stateController: _stateController,
                        cityController: _cityController,
                        districtController: _districtController,
                        contactNameController: _contactNameController,
                        contactPhoneController: _contactPhoneController,
                        operatingHoursController: _operatingHoursController,
                        dockCountController: _dockCountController,
                        stagingCapacityController: _stagingCapacityController,
                        storageCapacityController: _storageCapacityController,
                        yardCapacityController: _yardCapacityController,
                        temperatureZoneController: _temperatureZoneController,
                        latitudeController: _latitudeController,
                        longitudeController: _longitudeController,
                        geofenceController: _geofenceController,
                        memoController: _memoController,
                        selectedType: _selectedType,
                        selectedStatus: _selectedStatus,
                        isActive: _isActive,
                        temperatureControlled: _temperatureControlled,
                        appointmentRequired: _appointmentRequired,
                        bondedArea: _bondedArea,
                        yardManagement: _yardManagement,
                        onTypeChanged: (value) {
                          setState(() {
                            _selectedType = value;
                            if (_selectedId == null) {
                              _codeController.text = _nextCode(value);
                            }
                          });
                        },
                        onStatusChanged: (value) =>
                            setState(() => _selectedStatus = value),
                        onActiveChanged: (value) =>
                            setState(() => _isActive = value),
                        onTemperatureChanged: (value) =>
                            setState(() => _temperatureControlled = value),
                        onAppointmentChanged: (value) =>
                            setState(() => _appointmentRequired = value),
                        onBondedChanged: (value) =>
                            setState(() => _bondedArea = value),
                        onYardChanged: (value) =>
                            setState(() => _yardManagement = value),
                        onSave: _saveRecord,
                      ),
                    ),
                  ],
                )
              else ...[
                _FacilityEditorPanel(
                  selectedRecord: selectedRecord,
                  codeController: _codeController,
                  nameController: _nameController,
                  operatorController: _operatorController,
                  addressController: _addressController,
                  detailAddressController: _detailAddressController,
                  stateController: _stateController,
                  cityController: _cityController,
                  districtController: _districtController,
                  contactNameController: _contactNameController,
                  contactPhoneController: _contactPhoneController,
                  operatingHoursController: _operatingHoursController,
                  dockCountController: _dockCountController,
                  stagingCapacityController: _stagingCapacityController,
                  storageCapacityController: _storageCapacityController,
                  yardCapacityController: _yardCapacityController,
                  temperatureZoneController: _temperatureZoneController,
                  latitudeController: _latitudeController,
                  longitudeController: _longitudeController,
                  geofenceController: _geofenceController,
                  memoController: _memoController,
                  selectedType: _selectedType,
                  selectedStatus: _selectedStatus,
                  isActive: _isActive,
                  temperatureControlled: _temperatureControlled,
                  appointmentRequired: _appointmentRequired,
                  bondedArea: _bondedArea,
                  yardManagement: _yardManagement,
                  onTypeChanged: (value) => setState(() {
                    _selectedType = value;
                    if (_selectedId == null) {
                      _codeController.text = _nextCode(value);
                    }
                  }),
                  onStatusChanged: (value) =>
                      setState(() => _selectedStatus = value),
                  onActiveChanged: (value) => setState(() => _isActive = value),
                  onTemperatureChanged: (value) =>
                      setState(() => _temperatureControlled = value),
                  onAppointmentChanged: (value) =>
                      setState(() => _appointmentRequired = value),
                  onBondedChanged: (value) =>
                      setState(() => _bondedArea = value),
                  onYardChanged: (value) =>
                      setState(() => _yardManagement = value),
                  onSave: _saveRecord,
                ),
                const SizedBox(height: 16),
                _FacilityDirectoryPanel(
                  records: filteredRecords,
                  selectedId: _selectedId,
                  onSelect: _selectRecord,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _FacilityHeader extends StatelessWidget {
  const _FacilityHeader({required this.onCreate});

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
              color: const Color(0xFF0891B2).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.warehouse_rounded,
              color: Color(0xFF0891B2),
              size: 27,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '창고/거점 마스터',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.graphite,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '물류창고, 허브, RDC, CDC, 야드의 위치와 운영 조건을 관리합니다.',
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
            icon: const Icon(Icons.add_business_rounded, size: 19),
            label: const Text('창고/거점 등록'),
          ),
        ],
      ),
    );
  }
}

class _FacilityStats extends StatelessWidget {
  const _FacilityStats({required this.records});

  final List<_FacilityRecord> records;

  @override
  Widget build(BuildContext context) {
    final active = records
        .where((record) => record.statusCode == 'ACTIVE')
        .length;
    final dockCount = records.fold<int>(
      0,
      (sum, record) => sum + record.dockCount,
    );
    final tempControlled = records
        .where((record) => record.temperatureControlled)
        .length;
    final avgUtilization = records.isEmpty
        ? 0
        : (records.fold<int>(0, (sum, record) => sum + record.utilizationRate) /
                  records.length)
              .round();

    final metrics = [
      _FacilityMetric(
        label: '등록 거점',
        value: records.length.toString(),
        icon: Icons.domain_rounded,
        color: AppTheme.teal,
      ),
      _FacilityMetric(
        label: '운영 중',
        value: active.toString(),
        icon: Icons.verified_rounded,
        color: const Color(0xFF16A34A),
      ),
      _FacilityMetric(
        label: '도크 수',
        value: dockCount.toString(),
        icon: Icons.door_sliding_rounded,
        color: const Color(0xFF2563EB),
      ),
      _FacilityMetric(
        label: '온도관리',
        value: tempControlled.toString(),
        icon: Icons.ac_unit_rounded,
        color: AppTheme.cyan,
      ),
      _FacilityMetric(
        label: '평균 가동률',
        value: '$avgUtilization%',
        icon: Icons.speed_rounded,
        color: AppTheme.amber,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: compact ? 2 : 5,
            mainAxisExtent: 96,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: metrics.length,
          itemBuilder: (context, index) =>
              _FacilityMetricCard(metric: metrics[index]),
        );
      },
    );
  }
}

class _FacilityTypeSelector extends StatelessWidget {
  const _FacilityTypeSelector({
    required this.selectedType,
    required this.counts,
    required this.onSelect,
  });

  final _FacilityType? selectedType;
  final Map<_FacilityType, int> counts;
  final ValueChanged<_FacilityType> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _FacilityType.values.map((type) {
        final selected = selectedType == type;
        return ChoiceChip(
          avatar: Icon(
            type.icon,
            size: 17,
            color: selected ? type.color : AppTheme.slate,
          ),
          label: Text('${type.label} ${counts[type] ?? 0}'),
          selected: selected,
          selectedColor: type.color.withValues(alpha: 0.12),
          checkmarkColor: type.color,
          onSelected: (_) => onSelect(type),
          labelStyle: TextStyle(
            color: selected ? type.color : AppTheme.slate,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        );
      }).toList(),
    );
  }
}

class _FacilityToolbar extends StatelessWidget {
  const _FacilityToolbar({
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
            width: 360,
            child: TextField(
              onChanged: onQueryChanged,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: '거점 코드, 명칭, 운영사, 주소, 온도대',
              ),
            ),
          ),
          ...[
            const MapEntry('ALL', '전체'),
            const MapEntry('ACTIVE', '운영 중'),
            const MapEntry('MAINTENANCE', '점검'),
            const MapEntry('RESTRICTED', '제한'),
            const MapEntry('INACTIVE', '비활성'),
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

class _FacilityDirectoryPanel extends StatelessWidget {
  const _FacilityDirectoryPanel({
    required this.records,
    required this.selectedId,
    required this.onSelect,
  });

  final List<_FacilityRecord> records;
  final int? selectedId;
  final ValueChanged<_FacilityRecord> onSelect;

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
            icon: Icons.warehouse_rounded,
            title: '창고/거점 기준정보',
            subtitle: 'locations',
          ),
          if (records.isEmpty)
            const _EmptyState()
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AppTheme.panel),
                columns: const [
                  DataColumn(label: Text('거점 코드')),
                  DataColumn(label: Text('거점명')),
                  DataColumn(label: Text('유형')),
                  DataColumn(label: Text('상태')),
                  DataColumn(label: Text('도크')),
                  DataColumn(label: Text('가동률')),
                  DataColumn(label: Text('온도대')),
                  DataColumn(label: Text('주소')),
                ],
                rows: records
                    .map(
                      (record) => DataRow(
                        selected: selectedId == record.id,
                        onSelectChanged: (_) => onSelect(record),
                        cells: [
                          DataCell(_StrongText(record.facilityCode)),
                          DataCell(Text(record.facilityName)),
                          DataCell(_TypePill(type: record.type)),
                          DataCell(_StatusPill(record: record)),
                          DataCell(Text('${record.dockCount}')),
                          DataCell(Text('${record.utilizationRate}%')),
                          DataCell(Text(record.temperatureZone)),
                          DataCell(
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 260),
                              child: Text(
                                record.address,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
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

class _FacilityEditorPanel extends StatelessWidget {
  const _FacilityEditorPanel({
    required this.selectedRecord,
    required this.codeController,
    required this.nameController,
    required this.operatorController,
    required this.addressController,
    required this.detailAddressController,
    required this.stateController,
    required this.cityController,
    required this.districtController,
    required this.contactNameController,
    required this.contactPhoneController,
    required this.operatingHoursController,
    required this.dockCountController,
    required this.stagingCapacityController,
    required this.storageCapacityController,
    required this.yardCapacityController,
    required this.temperatureZoneController,
    required this.latitudeController,
    required this.longitudeController,
    required this.geofenceController,
    required this.memoController,
    required this.selectedType,
    required this.selectedStatus,
    required this.isActive,
    required this.temperatureControlled,
    required this.appointmentRequired,
    required this.bondedArea,
    required this.yardManagement,
    required this.onTypeChanged,
    required this.onStatusChanged,
    required this.onActiveChanged,
    required this.onTemperatureChanged,
    required this.onAppointmentChanged,
    required this.onBondedChanged,
    required this.onYardChanged,
    required this.onSave,
  });

  final _FacilityRecord? selectedRecord;
  final TextEditingController codeController;
  final TextEditingController nameController;
  final TextEditingController operatorController;
  final TextEditingController addressController;
  final TextEditingController detailAddressController;
  final TextEditingController stateController;
  final TextEditingController cityController;
  final TextEditingController districtController;
  final TextEditingController contactNameController;
  final TextEditingController contactPhoneController;
  final TextEditingController operatingHoursController;
  final TextEditingController dockCountController;
  final TextEditingController stagingCapacityController;
  final TextEditingController storageCapacityController;
  final TextEditingController yardCapacityController;
  final TextEditingController temperatureZoneController;
  final TextEditingController latitudeController;
  final TextEditingController longitudeController;
  final TextEditingController geofenceController;
  final TextEditingController memoController;
  final _FacilityType selectedType;
  final _FacilityStatus selectedStatus;
  final bool isActive;
  final bool temperatureControlled;
  final bool appointmentRequired;
  final bool bondedArea;
  final bool yardManagement;
  final ValueChanged<_FacilityType> onTypeChanged;
  final ValueChanged<_FacilityStatus> onStatusChanged;
  final ValueChanged<bool> onActiveChanged;
  final ValueChanged<bool> onTemperatureChanged;
  final ValueChanged<bool> onAppointmentChanged;
  final ValueChanged<bool> onBondedChanged;
  final ValueChanged<bool> onYardChanged;
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
                  icon: Icons.add_business_rounded,
                  title: selectedRecord == null ? '신규 창고/거점 등록' : '창고/거점 상세',
                  subtitle: selectedRecord?.facilityCode ?? 'locations',
                  compact: true,
                ),
              ),
              Switch(value: isActive, onChanged: onActiveChanged),
            ],
          ),
          const SizedBox(height: 14),
          _EditorGrid(
            children: [
              _FacilityTextField(
                controller: codeController,
                label: '거점 코드',
                icon: Icons.tag_rounded,
              ),
              _FacilityTextField(
                controller: nameController,
                label: '거점명',
                icon: Icons.warehouse_rounded,
              ),
              DropdownButtonFormField<_FacilityType>(
                initialValue: selectedType,
                decoration: const InputDecoration(
                  labelText: '거점 유형',
                  prefixIcon: Icon(Icons.category_rounded),
                ),
                items: _FacilityType.values
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(type.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    onTypeChanged(value);
                  }
                },
              ),
              DropdownButtonFormField<_FacilityStatus>(
                initialValue: selectedStatus,
                decoration: const InputDecoration(
                  labelText: '운영 상태',
                  prefixIcon: Icon(Icons.fact_check_rounded),
                ),
                items: _FacilityStatus.values
                    .map(
                      (status) => DropdownMenuItem(
                        value: status,
                        child: Text(status.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    onStatusChanged(value);
                  }
                },
              ),
              _FacilityTextField(
                controller: operatorController,
                label: '운영 주체',
                icon: Icons.business_center_rounded,
              ),
              _FacilityTextField(
                controller: operatingHoursController,
                label: '운영 시간',
                icon: Icons.schedule_rounded,
              ),
              _FacilityTextField(
                controller: stateController,
                label: '시/도',
                icon: Icons.map_rounded,
              ),
              _FacilityTextField(
                controller: cityController,
                label: '도시',
                icon: Icons.location_city_rounded,
              ),
              _FacilityTextField(
                controller: districtController,
                label: '구/군',
                icon: Icons.place_rounded,
              ),
              _FacilityTextField(
                controller: contactNameController,
                label: '담당자',
                icon: Icons.person_rounded,
              ),
              _FacilityTextField(
                controller: contactPhoneController,
                label: '연락처',
                icon: Icons.phone_rounded,
              ),
              _FacilityTextField(
                controller: dockCountController,
                label: '도크 수',
                icon: Icons.door_sliding_rounded,
                keyboardType: TextInputType.number,
              ),
              _FacilityTextField(
                controller: stagingCapacityController,
                label: '스테이징 CAPA',
                icon: Icons.inventory_rounded,
                keyboardType: TextInputType.number,
              ),
              _FacilityTextField(
                controller: storageCapacityController,
                label: '보관 CAPA',
                icon: Icons.inventory_2_rounded,
                keyboardType: TextInputType.number,
              ),
              _FacilityTextField(
                controller: yardCapacityController,
                label: '야드 CAPA',
                icon: Icons.local_parking_rounded,
                keyboardType: TextInputType.number,
              ),
              _FacilityTextField(
                controller: temperatureZoneController,
                label: '온도대',
                icon: Icons.thermostat_rounded,
              ),
              _FacilityTextField(
                controller: latitudeController,
                label: '위도',
                icon: Icons.my_location_rounded,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                  decimal: true,
                ),
              ),
              _FacilityTextField(
                controller: longitudeController,
                label: '경도',
                icon: Icons.explore_rounded,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                  decimal: true,
                ),
              ),
              _FacilityTextField(
                controller: geofenceController,
                label: '지오펜스 반경(m)',
                icon: Icons.radar_rounded,
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: addressController,
            decoration: const InputDecoration(
              labelText: '주소',
              prefixIcon: Icon(Icons.location_on_rounded),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: detailAddressController,
            decoration: const InputDecoration(
              labelText: '상세 주소',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
          const SizedBox(height: 12),
          _FacilitySwitchTile(
            label: '예약 필수',
            value: appointmentRequired,
            onChanged: onAppointmentChanged,
            icon: Icons.event_available_rounded,
          ),
          _FacilitySwitchTile(
            label: '온도관리',
            value: temperatureControlled,
            onChanged: onTemperatureChanged,
            icon: Icons.ac_unit_rounded,
          ),
          _FacilitySwitchTile(
            label: '보세구역',
            value: bondedArea,
            onChanged: onBondedChanged,
            icon: Icons.verified_user_rounded,
          ),
          _FacilitySwitchTile(
            label: '야드 관리',
            value: yardManagement,
            onChanged: onYardChanged,
            icon: Icons.route_rounded,
          ),
          const SizedBox(height: 12),
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

class _FacilityTextField extends StatelessWidget {
  const _FacilityTextField({
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

class _FacilitySwitchTile extends StatelessWidget {
  const _FacilitySwitchTile({
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

class _FacilityMetricCard extends StatelessWidget {
  const _FacilityMetricCard({required this.metric});

  final _FacilityMetric metric;

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

class _TypePill extends StatelessWidget {
  const _TypePill({required this.type});

  final _FacilityType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: type.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        type.label,
        style: TextStyle(
          color: type.color,
          fontWeight: FontWeight.w900,
          fontSize: 12,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.record});

  final _FacilityRecord record;

  @override
  Widget build(BuildContext context) {
    final color = record.status.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        record.status.label,
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
        '조회된 창고/거점 기준정보가 없습니다.',
        style: TextStyle(color: AppTheme.slate, letterSpacing: 0),
      ),
    );
  }
}

enum _FacilityType {
  warehouse,
  hub,
  rdc,
  cdc,
  crossDock,
  yard;

  String get code => switch (this) {
    _FacilityType.warehouse => 'WAREHOUSE',
    _FacilityType.hub => 'HUB',
    _FacilityType.rdc => 'RDC',
    _FacilityType.cdc => 'CDC',
    _FacilityType.crossDock => 'CROSS_DOCK',
    _FacilityType.yard => 'YARD',
  };

  String get label => switch (this) {
    _FacilityType.warehouse => '물류창고',
    _FacilityType.hub => '허브',
    _FacilityType.rdc => 'RDC',
    _FacilityType.cdc => 'CDC',
    _FacilityType.crossDock => '크로스도크',
    _FacilityType.yard => '야드',
  };

  String get prefix => switch (this) {
    _FacilityType.warehouse => 'WH',
    _FacilityType.hub => 'HUB',
    _FacilityType.rdc => 'RDC',
    _FacilityType.cdc => 'CDC',
    _FacilityType.crossDock => 'XDK',
    _FacilityType.yard => 'YARD',
  };

  IconData get icon => switch (this) {
    _FacilityType.warehouse => Icons.warehouse_rounded,
    _FacilityType.hub => Icons.hub_rounded,
    _FacilityType.rdc => Icons.inventory_2_rounded,
    _FacilityType.cdc => Icons.ac_unit_rounded,
    _FacilityType.crossDock => Icons.swap_horiz_rounded,
    _FacilityType.yard => Icons.local_parking_rounded,
  };

  Color get color => switch (this) {
    _FacilityType.warehouse => AppTheme.teal,
    _FacilityType.hub => const Color(0xFF2563EB),
    _FacilityType.rdc => const Color(0xFF7C3AED),
    _FacilityType.cdc => AppTheme.cyan,
    _FacilityType.crossDock => AppTheme.amber,
    _FacilityType.yard => const Color(0xFF16A34A),
  };
}

enum _FacilityStatus {
  operating,
  maintenance,
  restricted,
  inactive;

  String get code => switch (this) {
    _FacilityStatus.operating => 'ACTIVE',
    _FacilityStatus.maintenance => 'MAINTENANCE',
    _FacilityStatus.restricted => 'RESTRICTED',
    _FacilityStatus.inactive => 'INACTIVE',
  };

  String get label => switch (this) {
    _FacilityStatus.operating => '운영 중',
    _FacilityStatus.maintenance => '점검',
    _FacilityStatus.restricted => '제한',
    _FacilityStatus.inactive => '비활성',
  };

  Color get color => switch (this) {
    _FacilityStatus.operating => AppTheme.teal,
    _FacilityStatus.maintenance => AppTheme.amber,
    _FacilityStatus.restricted => const Color(0xFFDC2626),
    _FacilityStatus.inactive => AppTheme.slate,
  };
}

class _FacilityRecord {
  const _FacilityRecord({
    required this.id,
    required this.type,
    required this.facilityCode,
    required this.facilityName,
    required this.operatorName,
    required this.address,
    required this.detailAddress,
    required this.stateProvince,
    required this.city,
    required this.district,
    required this.contactName,
    required this.contactPhone,
    required this.operatingHours,
    required this.dockCount,
    required this.stagingCapacity,
    required this.storageCapacity,
    required this.yardCapacity,
    required this.temperatureZone,
    required this.latitude,
    required this.longitude,
    required this.geofenceRadiusM,
    required this.status,
    required this.isActive,
    required this.temperatureControlled,
    required this.appointmentRequired,
    required this.bondedArea,
    required this.yardManagement,
    required this.todayInbound,
    required this.todayOutbound,
    required this.utilizationRate,
    required this.memo,
  });

  final int id;
  final _FacilityType type;
  final String facilityCode;
  final String facilityName;
  final String operatorName;
  final String address;
  final String detailAddress;
  final String stateProvince;
  final String city;
  final String district;
  final String contactName;
  final String contactPhone;
  final String operatingHours;
  final int dockCount;
  final int stagingCapacity;
  final int storageCapacity;
  final int yardCapacity;
  final String temperatureZone;
  final String latitude;
  final String longitude;
  final int geofenceRadiusM;
  final _FacilityStatus status;
  final bool isActive;
  final bool temperatureControlled;
  final bool appointmentRequired;
  final bool bondedArea;
  final bool yardManagement;
  final int todayInbound;
  final int todayOutbound;
  final int utilizationRate;
  final String memo;

  String get statusCode => isActive ? status.code : 'INACTIVE';

  Map<String, Object?> toApiPayload() {
    return {
      'location_code': facilityCode,
      'location_name': facilityName,
      'location_type': type.code,
      'country_code': 'KR',
      'state_province': stateProvince,
      'city': city,
      'district': district,
      'address_line1': address,
      'address_line2': detailAddress,
      'latitude': latitude,
      'longitude': longitude,
      'timezone_name': 'Asia/Seoul',
      'geofence_radius_m': geofenceRadiusM,
      'is_active': isActive,
      'metadata': {
        'facility_type': type.code,
        'facility_status': statusCode,
        'operator_name': operatorName,
        'contact_name': contactName,
        'contact_phone': contactPhone,
        'operating_hours': operatingHours,
        'dock_count': dockCount,
        'staging_capacity_pallet': stagingCapacity,
        'storage_capacity_pallet': storageCapacity,
        'yard_capacity_slot': yardCapacity,
        'temperature_zone': temperatureZone,
        'temperature_controlled': temperatureControlled,
        'appointment_required': appointmentRequired,
        'bonded_area': bondedArea,
        'yard_management': yardManagement,
        'today_inbound': todayInbound,
        'today_outbound': todayOutbound,
        'utilization_rate': utilizationRate,
        'memo': memo,
      },
    };
  }
}

class _FacilityMetric {
  const _FacilityMetric({
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

const _seedFacilities = [
  _FacilityRecord(
    id: 1,
    type: _FacilityType.rdc,
    facilityCode: 'RDC0001',
    facilityName: '용인 수도권 RDC',
    operatorName: 'KCASTLE 본사',
    address: '경기도 용인시 처인구 남사읍 물류로 128',
    detailAddress: 'A동 상온센터',
    stateProvince: '경기도',
    city: '용인시',
    district: '처인구',
    contactName: '김현수',
    contactPhone: '031-410-8200',
    operatingHours: '06:00-24:00',
    dockCount: 32,
    stagingCapacity: 4200,
    storageCapacity: 18000,
    yardCapacity: 120,
    temperatureZone: '상온',
    latitude: '37.1739',
    longitude: '127.1775',
    geofenceRadiusM: 500,
    status: _FacilityStatus.operating,
    isActive: true,
    temperatureControlled: false,
    appointmentRequired: true,
    bondedArea: false,
    yardManagement: true,
    todayInbound: 74,
    todayOutbound: 91,
    utilizationRate: 82,
    memo: '수도권 간선과 이커머스 출고 핵심 거점.',
  ),
  _FacilityRecord(
    id: 2,
    type: _FacilityType.hub,
    facilityCode: 'HUB0001',
    facilityName: '대전 중부 허브',
    operatorName: 'CJ대한통운',
    address: '대전광역시 대덕구 신탄진로 410',
    detailAddress: '허브 터미널',
    stateProvince: '대전광역시',
    city: '대전광역시',
    district: '대덕구',
    contactName: '박지훈',
    contactPhone: '042-610-7700',
    operatingHours: '24시간',
    dockCount: 44,
    stagingCapacity: 6800,
    storageCapacity: 9000,
    yardCapacity: 180,
    temperatureZone: '상온',
    latitude: '36.4464',
    longitude: '127.4231',
    geofenceRadiusM: 650,
    status: _FacilityStatus.operating,
    isActive: true,
    temperatureControlled: false,
    appointmentRequired: true,
    bondedArea: false,
    yardManagement: true,
    todayInbound: 118,
    todayOutbound: 126,
    utilizationRate: 88,
    memo: '전국 간선 환적 기준 허브.',
  ),
  _FacilityRecord(
    id: 3,
    type: _FacilityType.cdc,
    facilityCode: 'CDC0001',
    facilityName: '이천 콜드체인 CDC',
    operatorName: '대한콜드체인',
    address: '경기도 이천시 마장면 냉장물류로 52',
    detailAddress: '냉장 1센터',
    stateProvince: '경기도',
    city: '이천시',
    district: '마장면',
    contactName: '이서연',
    contactPhone: '031-720-9310',
    operatingHours: '05:00-22:00',
    dockCount: 18,
    stagingCapacity: 1600,
    storageCapacity: 6200,
    yardCapacity: 70,
    temperatureZone: '냉장 2-8도',
    latitude: '37.2527',
    longitude: '127.3674',
    geofenceRadiusM: 420,
    status: _FacilityStatus.operating,
    isActive: true,
    temperatureControlled: true,
    appointmentRequired: true,
    bondedArea: false,
    yardManagement: true,
    todayInbound: 39,
    todayOutbound: 48,
    utilizationRate: 76,
    memo: '온도 로그 연동 필수.',
  ),
  _FacilityRecord(
    id: 4,
    type: _FacilityType.crossDock,
    facilityCode: 'XDK0001',
    facilityName: '부산 신항 크로스도크',
    operatorName: 'KCTC',
    address: '부산광역시 강서구 신항남로 330',
    detailAddress: '컨테이너 환적동',
    stateProvince: '부산광역시',
    city: '부산광역시',
    district: '강서구',
    contactName: '최민규',
    contactPhone: '051-920-4410',
    operatingHours: '07:00-23:00',
    dockCount: 26,
    stagingCapacity: 3500,
    storageCapacity: 4200,
    yardCapacity: 210,
    temperatureZone: '상온',
    latitude: '35.0778',
    longitude: '128.8341',
    geofenceRadiusM: 700,
    status: _FacilityStatus.restricted,
    isActive: true,
    temperatureControlled: false,
    appointmentRequired: true,
    bondedArea: true,
    yardManagement: true,
    todayInbound: 52,
    todayOutbound: 57,
    utilizationRate: 69,
    memo: '항만 보안 게이트 사전 예약 필요.',
  ),
  _FacilityRecord(
    id: 5,
    type: _FacilityType.yard,
    facilityCode: 'YARD0001',
    facilityName: '인천 북항 야드',
    operatorName: '한진',
    address: '인천광역시 서구 북항로 88',
    detailAddress: '트레일러 야드',
    stateProvince: '인천광역시',
    city: '인천광역시',
    district: '서구',
    contactName: '정도윤',
    contactPhone: '032-810-6500',
    operatingHours: '24시간',
    dockCount: 4,
    stagingCapacity: 800,
    storageCapacity: 1200,
    yardCapacity: 260,
    temperatureZone: '외부 야드',
    latitude: '37.5066',
    longitude: '126.6261',
    geofenceRadiusM: 800,
    status: _FacilityStatus.operating,
    isActive: true,
    temperatureControlled: false,
    appointmentRequired: false,
    bondedArea: true,
    yardManagement: true,
    todayInbound: 31,
    todayOutbound: 28,
    utilizationRate: 61,
    memo: '공차 대기와 트레일러 보관 중심.',
  ),
  _FacilityRecord(
    id: 6,
    type: _FacilityType.warehouse,
    facilityCode: 'WH0001',
    facilityName: '광주 호남 물류창고',
    operatorName: '동부익스프레스',
    address: '광주광역시 광산구 평동산단로 219',
    detailAddress: 'B동',
    stateProvince: '광주광역시',
    city: '광주광역시',
    district: '광산구',
    contactName: '윤지호',
    contactPhone: '062-940-3300',
    operatingHours: '08:00-19:00',
    dockCount: 14,
    stagingCapacity: 1800,
    storageCapacity: 7600,
    yardCapacity: 65,
    temperatureZone: '상온/저온',
    latitude: '35.1260',
    longitude: '126.7706',
    geofenceRadiusM: 450,
    status: _FacilityStatus.maintenance,
    isActive: true,
    temperatureControlled: true,
    appointmentRequired: true,
    bondedArea: false,
    yardManagement: true,
    todayInbound: 18,
    todayOutbound: 21,
    utilizationRate: 55,
    memo: '저온 구역 증설 점검 중.',
  ),
];
