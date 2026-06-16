import 'package:flutter/material.dart';

import '../../design/app_theme.dart';
import '../../design/numeric_input_formatters.dart';
import 'master_api.dart';

class DriverMasterPage extends StatefulWidget {
  const DriverMasterPage({super.key, this.compact = false});

  final bool compact;

  @override
  State<DriverMasterPage> createState() => _DriverMasterPageState();
}

class _DriverMasterPageState extends State<DriverMasterPage> {
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _carrierController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _licenseNoController = TextEditingController();
  final _licenseExpiryController = TextEditingController();
  final _hireDateController = TextEditingController();
  final _homeYardController = TextEditingController();
  final _assignedVehicleController = TextEditingController();
  final _regionsController = TextEditingController();
  final _safetyScoreController = TextEditingController();
  final _memoController = TextEditingController();

  late final List<_DriverRecord> _records;
  _DriverLicenseType _licenseType = _DriverLicenseType.large;
  _DriverStatus _selectedStatus = _DriverStatus.active;
  String _query = '';
  String _statusFilter = 'ALL';
  int? _selectedId;
  bool _isActive = true;
  bool _hazmatCertified = false;
  bool _coldChainCertified = false;
  bool _mobileAppReady = true;

  @override
  void initState() {
    super.initState();
    _records = List<_DriverRecord>.from(_seedDrivers);
    _selectRecord(_records.first, notify: false);
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _carrierController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _licenseNoController.dispose();
    _licenseExpiryController.dispose();
    _hireDateController.dispose();
    _homeYardController.dispose();
    _assignedVehicleController.dispose();
    _regionsController.dispose();
    _safetyScoreController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  List<_DriverRecord> get _filteredRecords {
    final normalizedQuery = _query.trim().toLowerCase();
    return _records.where((record) {
      final matchesStatus =
          _statusFilter == 'ALL' || record.statusCode == _statusFilter;
      final matchesQuery =
          normalizedQuery.isEmpty ||
          record.driverCode.toLowerCase().contains(normalizedQuery) ||
          record.driverName.toLowerCase().contains(normalizedQuery) ||
          record.carrierName.toLowerCase().contains(normalizedQuery) ||
          record.phone.toLowerCase().contains(normalizedQuery) ||
          record.assignedVehicle.toLowerCase().contains(normalizedQuery) ||
          record.serviceRegions.toLowerCase().contains(normalizedQuery);
      return matchesStatus && matchesQuery;
    }).toList();
  }

  _DriverRecord? get _selectedRecord {
    for (final record in _records) {
      if (record.id == _selectedId) {
        return record;
      }
    }
    return null;
  }

  void _selectRecord(_DriverRecord record, {bool notify = true}) {
    void apply() {
      _selectedId = record.id;
      _codeController.text = record.driverCode;
      _nameController.text = record.driverName;
      _carrierController.text = record.carrierName;
      _phoneController.text = record.phone;
      _emailController.text = record.email;
      _licenseNoController.text = record.licenseNo;
      _licenseType = record.licenseType;
      _licenseExpiryController.text = record.licenseExpiryDate;
      _hireDateController.text = record.hireDate;
      _homeYardController.text = record.homeYard;
      _assignedVehicleController.text = record.assignedVehicle;
      _regionsController.text = record.serviceRegions;
      _safetyScoreController.text = record.safetyScore.toString();
      _memoController.text = record.memo;
      _selectedStatus = record.status;
      _isActive = record.isActive;
      _hazmatCertified = record.hazmatCertified;
      _coldChainCertified = record.coldChainCertified;
      _mobileAppReady = record.mobileAppReady;
    }

    if (notify) {
      setState(apply);
    } else {
      apply();
    }
  }

  void _clearEditor({String? nextCode}) {
    _selectedId = null;
    _codeController.text = nextCode ?? _nextCode();
    _nameController.clear();
    _carrierController.clear();
    _phoneController.clear();
    _emailController.clear();
    _licenseNoController.clear();
    _licenseType = _DriverLicenseType.large;
    _licenseExpiryController.text = '2028-12-31';
    _hireDateController.text = '2026-01-01';
    _homeYardController.text = '수도권 차고지';
    _assignedVehicleController.clear();
    _regionsController.text = '수도권';
    _safetyScoreController.text = '95';
    _memoController.clear();
    _selectedStatus = _DriverStatus.active;
    _isActive = true;
    _hazmatCertified = false;
    _coldChainCertified = false;
    _mobileAppReady = true;
  }

  String _nextCode() {
    return 'DRV${(_records.length + 1).toString().padLeft(4, '0')}';
  }

  void _startCreate() {
    setState(_clearEditor);
  }

  void _saveRecord() async {
    final driverName = _nameController.text.trim();
    if (driverName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('기사명을 입력하세요.')));
      return;
    }

    final active = _isActive && _selectedStatus != _DriverStatus.inactive;
    final record = _DriverRecord(
      id: _selectedId ?? _nextRecordId(),
      driverCode: _codeController.text.trim(),
      driverName: driverName,
      carrierName: _carrierController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      licenseNo: _licenseNoController.text.trim(),
      licenseType: _licenseType,
      licenseExpiryDate: _licenseExpiryController.text.trim(),
      hireDate: _hireDateController.text.trim(),
      status: active ? _selectedStatus : _DriverStatus.inactive,
      isActive: active,
      homeYard: _homeYardController.text.trim(),
      assignedVehicle: _assignedVehicleController.text.trim(),
      serviceRegions: _regionsController.text.trim(),
      safetyScore: int.tryParse(_safetyScoreController.text.trim()) ?? 0,
      todayDispatchCount: _selectedRecord?.todayDispatchCount ?? 0,
      onTimeRate: _selectedRecord?.onTimeRate ?? 98.0,
      restComplianceRate: _selectedRecord?.restComplianceRate ?? 99.0,
      hazmatCertified: _hazmatCertified,
      coldChainCertified: _coldChainCertified,
      mobileAppReady: _mobileAppReady,
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

    final result = await MasterApi.instance.saveDriver(record.toApiPayload());
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.failed
              ? '${record.driverName} 기사 화면 반영 완료, DB 저장 실패: ${result.message}'
              : '${record.driverName} 기사 마스터가 반영되었습니다.',
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
        final wide = constraints.maxWidth >= 1080 && !widget.compact;

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
              _DriverHeader(onCreate: _startCreate),
              const SizedBox(height: 16),
              _DriverStats(records: _records),
              const SizedBox(height: 16),
              _DriverToolbar(
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
                      child: _DriverDirectoryPanel(
                        records: filteredRecords,
                        selectedId: _selectedId,
                        onSelect: _selectRecord,
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 430,
                      child: _DriverEditorPanel(
                        selectedRecord: selectedRecord,
                        codeController: _codeController,
                        nameController: _nameController,
                        carrierController: _carrierController,
                        phoneController: _phoneController,
                        emailController: _emailController,
                        licenseNoController: _licenseNoController,
                        licenseExpiryController: _licenseExpiryController,
                        hireDateController: _hireDateController,
                        homeYardController: _homeYardController,
                        assignedVehicleController: _assignedVehicleController,
                        regionsController: _regionsController,
                        safetyScoreController: _safetyScoreController,
                        memoController: _memoController,
                        licenseType: _licenseType,
                        selectedStatus: _selectedStatus,
                        isActive: _isActive,
                        hazmatCertified: _hazmatCertified,
                        coldChainCertified: _coldChainCertified,
                        mobileAppReady: _mobileAppReady,
                        onLicenseTypeChanged: (value) =>
                            setState(() => _licenseType = value),
                        onStatusChanged: (value) =>
                            setState(() => _selectedStatus = value),
                        onActiveChanged: (value) =>
                            setState(() => _isActive = value),
                        onHazmatChanged: (value) =>
                            setState(() => _hazmatCertified = value),
                        onColdChainChanged: (value) =>
                            setState(() => _coldChainCertified = value),
                        onMobileAppChanged: (value) =>
                            setState(() => _mobileAppReady = value),
                        onSave: _saveRecord,
                      ),
                    ),
                  ],
                )
              else ...[
                _DriverEditorPanel(
                  selectedRecord: selectedRecord,
                  codeController: _codeController,
                  nameController: _nameController,
                  carrierController: _carrierController,
                  phoneController: _phoneController,
                  emailController: _emailController,
                  licenseNoController: _licenseNoController,
                  licenseExpiryController: _licenseExpiryController,
                  hireDateController: _hireDateController,
                  homeYardController: _homeYardController,
                  assignedVehicleController: _assignedVehicleController,
                  regionsController: _regionsController,
                  safetyScoreController: _safetyScoreController,
                  memoController: _memoController,
                  licenseType: _licenseType,
                  selectedStatus: _selectedStatus,
                  isActive: _isActive,
                  hazmatCertified: _hazmatCertified,
                  coldChainCertified: _coldChainCertified,
                  mobileAppReady: _mobileAppReady,
                  onLicenseTypeChanged: (value) =>
                      setState(() => _licenseType = value),
                  onStatusChanged: (value) =>
                      setState(() => _selectedStatus = value),
                  onActiveChanged: (value) => setState(() => _isActive = value),
                  onHazmatChanged: (value) =>
                      setState(() => _hazmatCertified = value),
                  onColdChainChanged: (value) =>
                      setState(() => _coldChainCertified = value),
                  onMobileAppChanged: (value) =>
                      setState(() => _mobileAppReady = value),
                  onSave: _saveRecord,
                ),
                const SizedBox(height: 16),
                _DriverDirectoryPanel(
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

class _DriverHeader extends StatelessWidget {
  const _DriverHeader({required this.onCreate});

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
              color: const Color(0xFF16A34A).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.badge_rounded,
              color: Color(0xFF16A34A),
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '기사 마스터',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.graphite,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '운송사별 기사, 면허, 안전점수, 앱 설치, 운행 가능 상태를 관리합니다.',
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
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 19),
            label: const Text('기사 등록'),
          ),
        ],
      ),
    );
  }
}

class _DriverStats extends StatelessWidget {
  const _DriverStats({required this.records});

  final List<_DriverRecord> records;

  @override
  Widget build(BuildContext context) {
    final active = records
        .where((record) => record.statusCode == 'ACTIVE')
        .length;
    final risk = records.where((record) => record.licenseRisk).length;
    final appReady = records.where((record) => record.mobileAppReady).length;
    final avgSafety = records.isEmpty
        ? 0
        : (records.fold<int>(0, (sum, record) => sum + record.safetyScore) /
                  records.length)
              .round();

    final metrics = [
      _DriverMetric(
        label: '등록 기사',
        value: records.length.toString(),
        icon: Icons.groups_rounded,
        color: AppTheme.teal,
      ),
      _DriverMetric(
        label: '운행 가능',
        value: active.toString(),
        icon: Icons.verified_rounded,
        color: const Color(0xFF16A34A),
      ),
      _DriverMetric(
        label: '면허 확인',
        value: risk.toString(),
        icon: Icons.warning_amber_rounded,
        color: AppTheme.amber,
      ),
      _DriverMetric(
        label: '앱 설치',
        value: '$appReady/${records.length}',
        icon: Icons.phone_android_rounded,
        color: const Color(0xFF2563EB),
      ),
      _DriverMetric(
        label: '평균 안전점수',
        value: '$avgSafety',
        icon: Icons.health_and_safety_rounded,
        color: const Color(0xFF7C3AED),
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
              _DriverMetricCard(metric: metrics[index]),
        );
      },
    );
  }
}

class _DriverToolbar extends StatelessWidget {
  const _DriverToolbar({
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
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 10,
        children: [
          SizedBox(
            width: 340,
            child: TextField(
              onChanged: onQueryChanged,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: '기사 코드, 기사명, 운송사, 담당차량, 권역',
              ),
            ),
          ),
          ...[
            const MapEntry('ALL', '전체'),
            const MapEntry('ACTIVE', '운행 가능'),
            const MapEntry('OFF_DUTY', '휴무'),
            const MapEntry('ON_LEAVE', '휴가'),
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

class _DriverDirectoryPanel extends StatelessWidget {
  const _DriverDirectoryPanel({
    required this.records,
    required this.selectedId,
    required this.onSelect,
  });

  final List<_DriverRecord> records;
  final int? selectedId;
  final ValueChanged<_DriverRecord> onSelect;

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
            icon: Icons.badge_rounded,
            title: '기사 기준정보',
            subtitle: 'drivers',
          ),
          if (records.isEmpty)
            const _EmptyState()
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AppTheme.panel),
                columns: const [
                  DataColumn(label: Text('기사 코드')),
                  DataColumn(label: Text('기사명')),
                  DataColumn(label: Text('운송사')),
                  DataColumn(label: Text('상태')),
                  DataColumn(label: Text('면허')),
                  DataColumn(label: Text('담당차량')),
                  DataColumn(label: Text('안전점수')),
                  DataColumn(label: Text('앱')),
                ],
                rows: records
                    .map(
                      (record) => DataRow(
                        selected: selectedId == record.id,
                        onSelectChanged: (_) => onSelect(record),
                        cells: [
                          DataCell(_StrongText(record.driverCode)),
                          DataCell(Text(record.driverName)),
                          DataCell(Text(record.carrierName)),
                          DataCell(_StatusPill(record: record)),
                          DataCell(Text(record.licenseType.label)),
                          DataCell(Text(record.assignedVehicle)),
                          DataCell(Text('${record.safetyScore}')),
                          DataCell(
                            Icon(
                              record.mobileAppReady
                                  ? Icons.check_circle_rounded
                                  : Icons.error_rounded,
                              size: 18,
                              color: record.mobileAppReady
                                  ? AppTheme.teal
                                  : AppTheme.amber,
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

class _DriverEditorPanel extends StatelessWidget {
  const _DriverEditorPanel({
    required this.selectedRecord,
    required this.codeController,
    required this.nameController,
    required this.carrierController,
    required this.phoneController,
    required this.emailController,
    required this.licenseNoController,
    required this.licenseExpiryController,
    required this.hireDateController,
    required this.homeYardController,
    required this.assignedVehicleController,
    required this.regionsController,
    required this.safetyScoreController,
    required this.memoController,
    required this.licenseType,
    required this.selectedStatus,
    required this.isActive,
    required this.hazmatCertified,
    required this.coldChainCertified,
    required this.mobileAppReady,
    required this.onLicenseTypeChanged,
    required this.onStatusChanged,
    required this.onActiveChanged,
    required this.onHazmatChanged,
    required this.onColdChainChanged,
    required this.onMobileAppChanged,
    required this.onSave,
  });

  final _DriverRecord? selectedRecord;
  final TextEditingController codeController;
  final TextEditingController nameController;
  final TextEditingController carrierController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final TextEditingController licenseNoController;
  final TextEditingController licenseExpiryController;
  final TextEditingController hireDateController;
  final TextEditingController homeYardController;
  final TextEditingController assignedVehicleController;
  final TextEditingController regionsController;
  final TextEditingController safetyScoreController;
  final TextEditingController memoController;
  final _DriverLicenseType licenseType;
  final _DriverStatus selectedStatus;
  final bool isActive;
  final bool hazmatCertified;
  final bool coldChainCertified;
  final bool mobileAppReady;
  final ValueChanged<_DriverLicenseType> onLicenseTypeChanged;
  final ValueChanged<_DriverStatus> onStatusChanged;
  final ValueChanged<bool> onActiveChanged;
  final ValueChanged<bool> onHazmatChanged;
  final ValueChanged<bool> onColdChainChanged;
  final ValueChanged<bool> onMobileAppChanged;
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
                  icon: Icons.manage_accounts_rounded,
                  title: selectedRecord == null ? '신규 기사 등록' : '기사 상세',
                  subtitle: selectedRecord?.driverCode ?? 'drivers',
                  compact: true,
                ),
              ),
              Switch(value: isActive, onChanged: onActiveChanged),
            ],
          ),
          const SizedBox(height: 14),
          _EditorGrid(
            children: [
              _DriverTextField(
                controller: codeController,
                label: '기사 코드',
                icon: Icons.tag_rounded,
              ),
              _DriverTextField(
                controller: nameController,
                label: '기사명',
                icon: Icons.person_rounded,
              ),
              _DriverTextField(
                controller: carrierController,
                label: '소속 운송사',
                icon: Icons.local_shipping_rounded,
              ),
              _DriverTextField(
                controller: phoneController,
                label: '휴대전화',
                icon: Icons.phone_iphone_rounded,
              ),
              _DriverTextField(
                controller: emailController,
                label: '이메일',
                icon: Icons.alternate_email_rounded,
              ),
              DropdownButtonFormField<_DriverStatus>(
                initialValue: selectedStatus,
                decoration: const InputDecoration(
                  labelText: '근무 상태',
                  prefixIcon: Icon(Icons.work_history_rounded),
                ),
                items: _DriverStatus.values
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
              _DriverTextField(
                controller: licenseNoController,
                label: '면허 번호',
                icon: Icons.credit_card_rounded,
              ),
              DropdownButtonFormField<_DriverLicenseType>(
                initialValue: licenseType,
                decoration: const InputDecoration(
                  labelText: '면허 구분',
                  prefixIcon: Icon(Icons.card_membership_rounded),
                ),
                items: _DriverLicenseType.values
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(type.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    onLicenseTypeChanged(value);
                  }
                },
              ),
              _DriverTextField(
                controller: licenseExpiryController,
                label: '면허 만료일',
                icon: Icons.event_available_rounded,
              ),
              _DriverTextField(
                controller: hireDateController,
                label: '입사/계약일',
                icon: Icons.event_note_rounded,
              ),
              _DriverTextField(
                controller: homeYardController,
                label: '기본 차고지',
                icon: Icons.warehouse_rounded,
              ),
              _DriverTextField(
                controller: assignedVehicleController,
                label: '담당차량',
                icon: Icons.fire_truck_rounded,
              ),
              _DriverTextField(
                controller: regionsController,
                label: '운행 권역',
                icon: Icons.map_rounded,
              ),
              _DriverTextField(
                controller: safetyScoreController,
                label: '안전점수',
                icon: Icons.health_and_safety_rounded,
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DriverSwitchTile(
            label: '모바일 앱 설치',
            value: mobileAppReady,
            onChanged: onMobileAppChanged,
            icon: Icons.phone_android_rounded,
          ),
          _DriverSwitchTile(
            label: '위험물 자격',
            value: hazmatCertified,
            onChanged: onHazmatChanged,
            icon: Icons.warning_amber_rounded,
          ),
          _DriverSwitchTile(
            label: '냉장/냉동 운송',
            value: coldChainCertified,
            onChanged: onColdChainChanged,
            icon: Icons.ac_unit_rounded,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: memoController,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: '운영 메모',
              prefixIcon: Icon(Icons.notes_rounded),
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
        final columns = constraints.maxWidth >= 620 ? 2 : 1;
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

class _DriverTextField extends StatelessWidget {
  const _DriverTextField({
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

class _DriverSwitchTile extends StatelessWidget {
  const _DriverSwitchTile({
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

class _DriverMetricCard extends StatelessWidget {
  const _DriverMetricCard({required this.metric});

  final _DriverMetric metric;

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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.record});

  final _DriverRecord record;

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
        '조회된 기사 기준정보가 없습니다.',
        style: TextStyle(color: AppTheme.slate, letterSpacing: 0),
      ),
    );
  }
}

enum _DriverLicenseType {
  large,
  cargo,
  trailer,
  special,
  hazmat;

  String get label => switch (this) {
    _DriverLicenseType.large => '1종 대형',
    _DriverLicenseType.cargo => '화물운송',
    _DriverLicenseType.trailer => '트레일러',
    _DriverLicenseType.special => '특수면허',
    _DriverLicenseType.hazmat => '위험물',
  };

  String get code => switch (this) {
    _DriverLicenseType.large => 'LARGE',
    _DriverLicenseType.cargo => 'CARGO',
    _DriverLicenseType.trailer => 'TRAILER',
    _DriverLicenseType.special => 'SPECIAL',
    _DriverLicenseType.hazmat => 'HAZMAT',
  };
}

enum _DriverStatus {
  active,
  offDuty,
  onLeave,
  inactive;

  String get code => switch (this) {
    _DriverStatus.active => 'ACTIVE',
    _DriverStatus.offDuty => 'OFF_DUTY',
    _DriverStatus.onLeave => 'ON_LEAVE',
    _DriverStatus.inactive => 'INACTIVE',
  };

  String get label => switch (this) {
    _DriverStatus.active => '운행 가능',
    _DriverStatus.offDuty => '휴무',
    _DriverStatus.onLeave => '휴가',
    _DriverStatus.inactive => '비활성',
  };

  Color get color => switch (this) {
    _DriverStatus.active => AppTheme.teal,
    _DriverStatus.offDuty => AppTheme.amber,
    _DriverStatus.onLeave => const Color(0xFF2563EB),
    _DriverStatus.inactive => AppTheme.slate,
  };
}

class _DriverRecord {
  const _DriverRecord({
    required this.id,
    required this.driverCode,
    required this.driverName,
    required this.carrierName,
    required this.phone,
    required this.email,
    required this.licenseNo,
    required this.licenseType,
    required this.licenseExpiryDate,
    required this.hireDate,
    required this.status,
    required this.isActive,
    required this.homeYard,
    required this.assignedVehicle,
    required this.serviceRegions,
    required this.safetyScore,
    required this.todayDispatchCount,
    required this.onTimeRate,
    required this.restComplianceRate,
    required this.hazmatCertified,
    required this.coldChainCertified,
    required this.mobileAppReady,
    required this.memo,
  });

  final int id;
  final String driverCode;
  final String driverName;
  final String carrierName;
  final String phone;
  final String email;
  final String licenseNo;
  final _DriverLicenseType licenseType;
  final String licenseExpiryDate;
  final String hireDate;
  final _DriverStatus status;
  final bool isActive;
  final String homeYard;
  final String assignedVehicle;
  final String serviceRegions;
  final int safetyScore;
  final int todayDispatchCount;
  final double onTimeRate;
  final double restComplianceRate;
  final bool hazmatCertified;
  final bool coldChainCertified;
  final bool mobileAppReady;
  final String memo;

  String get statusCode => isActive ? status.code : 'INACTIVE';

  bool get licenseRisk {
    return licenseExpiryDate.compareTo('2026-09-30') <= 0;
  }

  Map<String, Object?> toApiPayload() {
    return {
      'driver_code': driverCode,
      'driver_name': driverName,
      'carrier_name': carrierName,
      'phone': phone,
      'email': email,
      'license_no': licenseNo,
      'license_type': licenseType.code,
      'license_expiry_date': licenseExpiryDate,
      'hire_date': hireDate,
      'status': statusCode,
      'is_active': isActive,
      'metadata': {
        'home_yard': homeYard,
        'assigned_vehicle': assignedVehicle,
        'service_regions': serviceRegions,
        'safety_score': safetyScore,
        'today_dispatch_count': todayDispatchCount,
        'on_time_rate': onTimeRate,
        'rest_compliance_rate': restComplianceRate,
        'hazmat_certified': hazmatCertified,
        'cold_chain_certified': coldChainCertified,
        'mobile_app_ready': mobileAppReady,
        'memo': memo,
      },
    };
  }
}

class _DriverMetric {
  const _DriverMetric({
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

const _seedDrivers = [
  _DriverRecord(
    id: 1,
    driverCode: 'DRV0001',
    driverName: '김도윤',
    carrierName: 'CJ대한통운',
    phone: '010-4812-1901',
    email: 'doyun.kim@carrier.local',
    licenseNo: '11-24-889102-01',
    licenseType: _DriverLicenseType.large,
    licenseExpiryDate: '2028-04-30',
    hireDate: '2021-03-12',
    status: _DriverStatus.active,
    isActive: true,
    homeYard: '군포 차고지',
    assignedVehicle: '서울 82바 1901',
    serviceRegions: '수도권, 충청',
    safetyScore: 97,
    todayDispatchCount: 3,
    onTimeRate: 99.1,
    restComplianceRate: 99.8,
    hazmatCertified: false,
    coldChainCertified: false,
    mobileAppReady: true,
    memo: '수도권 순환 고정 배차 우선.',
  ),
  _DriverRecord(
    id: 2,
    driverCode: 'DRV0002',
    driverName: '박민재',
    carrierName: 'OO운송',
    phone: '010-7730-2044',
    email: 'minjae.park@carrier.local',
    licenseNo: '22-18-451009-02',
    licenseType: _DriverLicenseType.cargo,
    licenseExpiryDate: '2026-08-31',
    hireDate: '2020-09-01',
    status: _DriverStatus.active,
    isActive: true,
    homeYard: '대전 허브',
    assignedVehicle: '대전 91아 2044',
    serviceRegions: '충청, 전라',
    safetyScore: 92,
    todayDispatchCount: 2,
    onTimeRate: 97.4,
    restComplianceRate: 98.7,
    hazmatCertified: true,
    coldChainCertified: false,
    mobileAppReady: true,
    memo: '위험물 자격 보유, 유류/화학품 오더 가능.',
  ),
  _DriverRecord(
    id: 3,
    driverCode: 'DRV0003',
    driverName: '이서준',
    carrierName: '대한콜드체인',
    phone: '010-3019-7782',
    email: 'seojun.lee@carrier.local',
    licenseNo: '31-20-719202-03',
    licenseType: _DriverLicenseType.large,
    licenseExpiryDate: '2029-11-15',
    hireDate: '2022-01-18',
    status: _DriverStatus.active,
    isActive: true,
    homeYard: '이천 냉장센터',
    assignedVehicle: '경기 77자 7782',
    serviceRegions: '수도권, 강원',
    safetyScore: 95,
    todayDispatchCount: 4,
    onTimeRate: 98.6,
    restComplianceRate: 99.2,
    hazmatCertified: false,
    coldChainCertified: true,
    mobileAppReady: true,
    memo: '냉장/냉동 운행 우선 배정.',
  ),
  _DriverRecord(
    id: 4,
    driverCode: 'DRV0004',
    driverName: '최현우',
    carrierName: 'KCTC',
    phone: '010-9204-5510',
    email: 'hyunwoo.choi@carrier.local',
    licenseNo: '44-17-330410-04',
    licenseType: _DriverLicenseType.trailer,
    licenseExpiryDate: '2027-06-30',
    hireDate: '2019-06-20',
    status: _DriverStatus.offDuty,
    isActive: true,
    homeYard: '부산 신항',
    assignedVehicle: '부산 88사 5510',
    serviceRegions: '영남, 항만',
    safetyScore: 94,
    todayDispatchCount: 0,
    onTimeRate: 98.9,
    restComplianceRate: 99.5,
    hazmatCertified: false,
    coldChainCertified: false,
    mobileAppReady: true,
    memo: '항만 컨테이너 운행 숙련.',
  ),
  _DriverRecord(
    id: 5,
    driverCode: 'DRV0005',
    driverName: '정하준',
    carrierName: '한진',
    phone: '010-1160-4320',
    email: 'hajun.jung@carrier.local',
    licenseNo: '51-23-801120-05',
    licenseType: _DriverLicenseType.special,
    licenseExpiryDate: '2028-09-20',
    hireDate: '2023-02-06',
    status: _DriverStatus.onLeave,
    isActive: true,
    homeYard: '인천 허브',
    assignedVehicle: '인천 70하 4320',
    serviceRegions: '수도권, 항공',
    safetyScore: 90,
    todayDispatchCount: 0,
    onTimeRate: 96.8,
    restComplianceRate: 97.9,
    hazmatCertified: false,
    coldChainCertified: true,
    mobileAppReady: false,
    memo: '휴가 복귀 후 앱 재설치 확인 필요.',
  ),
  _DriverRecord(
    id: 6,
    driverCode: 'DRV0006',
    driverName: '윤지호',
    carrierName: '동부익스프레스',
    phone: '010-6401-3988',
    email: 'jiho.yoon@carrier.local',
    licenseNo: '61-19-610398-06',
    licenseType: _DriverLicenseType.large,
    licenseExpiryDate: '2030-01-31',
    hireDate: '2024-04-15',
    status: _DriverStatus.active,
    isActive: true,
    homeYard: '광주 거점',
    assignedVehicle: '광주 64다 3988',
    serviceRegions: '전라, 제주',
    safetyScore: 96,
    todayDispatchCount: 2,
    onTimeRate: 98.1,
    restComplianceRate: 98.8,
    hazmatCertified: false,
    coldChainCertified: false,
    mobileAppReady: true,
    memo: '장거리 운행 선호.',
  ),
];
