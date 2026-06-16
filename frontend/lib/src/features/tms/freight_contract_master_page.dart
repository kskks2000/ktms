import 'package:flutter/material.dart';

import '../../design/app_theme.dart';
import '../../design/numeric_input_formatters.dart';
import 'master_api.dart';

class FreightContractMasterPage extends StatefulWidget {
  const FreightContractMasterPage({super.key, this.compact = false});

  final bool compact;

  @override
  State<FreightContractMasterPage> createState() =>
      _FreightContractMasterPageState();
}

class _FreightContractMasterPageState extends State<FreightContractMasterPage> {
  final _agreementNoController = TextEditingController();
  final _agreementNameController = TextEditingController();
  final _partnerNameController = TextEditingController();
  final _partnerCodeController = TextEditingController();
  final _ownerController = TextEditingController();
  final _effectiveFromController = TextEditingController();
  final _effectiveToController = TextEditingController();
  final _paymentTermsController = TextEditingController();
  final _laneCodeController = TextEditingController();
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  final _serviceLevelController = TextEditingController();
  final _modeController = TextEditingController();
  final _equipmentController = TextEditingController();
  final _baseRateController = TextEditingController();
  final _minChargeController = TextEditingController();
  final _transitHoursController = TextEditingController();
  final _chargeCodeController = TextEditingController();
  final _chargeNameController = TextEditingController();
  final _unitCodeController = TextEditingController();
  final _rateAmountController = TextEditingController();
  final _minimumAmountController = TextEditingController();
  final _fuelIndexController = TextEditingController();
  final _baselineFuelController = TextEditingController();
  final _surchargePercentController = TextEditingController();
  final _memoController = TextEditingController();

  late final List<_RateRecord> _records;
  _AgreementType? _typeFilter;
  _AgreementType _selectedType = _AgreementType.sell;
  _AgreementStatus _selectedStatus = _AgreementStatus.active;
  _CalculationMethod _calculationMethod = _CalculationMethod.flat;
  String _statusFilter = 'ALL';
  String _query = '';
  int? _selectedId;
  bool _isActive = true;
  bool _autoRating = true;
  bool _tollIncluded = true;
  bool _taxIncluded = true;
  bool _fuelSurchargeEnabled = true;

  @override
  void initState() {
    super.initState();
    _records = List<_RateRecord>.from(_seedRates);
    _selectRecord(_records.first, notify: false);
  }

  @override
  void dispose() {
    _agreementNoController.dispose();
    _agreementNameController.dispose();
    _partnerNameController.dispose();
    _partnerCodeController.dispose();
    _ownerController.dispose();
    _effectiveFromController.dispose();
    _effectiveToController.dispose();
    _paymentTermsController.dispose();
    _laneCodeController.dispose();
    _originController.dispose();
    _destinationController.dispose();
    _serviceLevelController.dispose();
    _modeController.dispose();
    _equipmentController.dispose();
    _baseRateController.dispose();
    _minChargeController.dispose();
    _transitHoursController.dispose();
    _chargeCodeController.dispose();
    _chargeNameController.dispose();
    _unitCodeController.dispose();
    _rateAmountController.dispose();
    _minimumAmountController.dispose();
    _fuelIndexController.dispose();
    _baselineFuelController.dispose();
    _surchargePercentController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  List<_RateRecord> get _filteredRecords {
    final normalizedQuery = _query.trim().toLowerCase();
    return _records.where((record) {
      final matchesType = _typeFilter == null || record.type == _typeFilter;
      final matchesStatus =
          _statusFilter == 'ALL' || record.status.code == _statusFilter;
      final matchesQuery =
          normalizedQuery.isEmpty ||
          record.agreementNo.toLowerCase().contains(normalizedQuery) ||
          record.agreementName.toLowerCase().contains(normalizedQuery) ||
          record.partnerName.toLowerCase().contains(normalizedQuery) ||
          record.originName.toLowerCase().contains(normalizedQuery) ||
          record.destinationName.toLowerCase().contains(normalizedQuery) ||
          record.chargeCode.toLowerCase().contains(normalizedQuery);
      return matchesType && matchesStatus && matchesQuery;
    }).toList();
  }

  _RateRecord? get _selectedRecord {
    for (final record in _records) {
      if (record.id == _selectedId) {
        return record;
      }
    }
    return null;
  }

  void _selectRecord(_RateRecord record, {bool notify = true}) {
    void apply() {
      _selectedId = record.id;
      _selectedType = record.type;
      _selectedStatus = record.status;
      _calculationMethod = record.calculationMethod;
      _agreementNoController.text = record.agreementNo;
      _agreementNameController.text = record.agreementName;
      _partnerNameController.text = record.partnerName;
      _partnerCodeController.text = record.partnerCode;
      _ownerController.text = record.contractOwner;
      _effectiveFromController.text = record.effectiveFrom;
      _effectiveToController.text = record.effectiveTo;
      _paymentTermsController.text = record.paymentTerms;
      _laneCodeController.text = record.laneCode;
      _originController.text = record.originName;
      _destinationController.text = record.destinationName;
      _serviceLevelController.text = record.serviceLevel;
      _modeController.text = record.modeName;
      _equipmentController.text = record.equipmentName;
      _baseRateController.text = record.baseRateAmount.toStringAsFixed(0);
      _minChargeController.text = record.minChargeAmount.toStringAsFixed(0);
      _transitHoursController.text = record.transitHours.toString();
      _chargeCodeController.text = record.chargeCode;
      _chargeNameController.text = record.chargeName;
      _unitCodeController.text = record.unitCode;
      _rateAmountController.text = record.rateAmount.toStringAsFixed(0);
      _minimumAmountController.text = record.minimumAmount.toStringAsFixed(0);
      _fuelIndexController.text = record.fuelIndexName;
      _baselineFuelController.text = record.baselineFuelPrice.toStringAsFixed(
        0,
      );
      _surchargePercentController.text = record.surchargePercent.toString();
      _memoController.text = record.memo;
      _isActive = record.isActive;
      _autoRating = record.autoRating;
      _tollIncluded = record.tollIncluded;
      _taxIncluded = record.taxIncluded;
      _fuelSurchargeEnabled = record.fuelSurchargeEnabled;
    }

    if (notify) {
      setState(apply);
    } else {
      apply();
    }
  }

  void _clearEditor() {
    final type = _typeFilter ?? _AgreementType.sell;
    _selectedId = null;
    _selectedType = type;
    _selectedStatus = _AgreementStatus.draft;
    _calculationMethod = _CalculationMethod.flat;
    _agreementNoController.text = _nextAgreementNo(type);
    _agreementNameController.clear();
    _partnerNameController.clear();
    _partnerCodeController.clear();
    _ownerController.clear();
    _effectiveFromController.text = '2026-01-01';
    _effectiveToController.text = '2026-12-31';
    _paymentTermsController.text = '익월 말일';
    _laneCodeController.text = 'LANE-${type.code}-001';
    _originController.clear();
    _destinationController.clear();
    _serviceLevelController.text = 'STANDARD';
    _modeController.text = 'TRUCK';
    _equipmentController.text = '5톤 윙바디';
    _baseRateController.text = '0';
    _minChargeController.text = '0';
    _transitHoursController.text = '24';
    _chargeCodeController.text = 'BASE_FREIGHT';
    _chargeNameController.text = '기본 운임';
    _unitCodeController.text = 'TRIP';
    _rateAmountController.text = '0';
    _minimumAmountController.text = '0';
    _fuelIndexController.text = '한국석유공사 경유가';
    _baselineFuelController.text = '1500';
    _surchargePercentController.text = '0';
    _memoController.clear();
    _isActive = true;
    _autoRating = true;
    _tollIncluded = true;
    _taxIncluded = true;
    _fuelSurchargeEnabled = false;
  }

  String _nextAgreementNo(_AgreementType type) {
    final count = _records.where((record) => record.type == type).length + 1;
    return '${type.prefix}-${count.toString().padLeft(4, '0')}';
  }

  void _startCreate() {
    setState(_clearEditor);
  }

  Future<void> _saveRecord() async {
    final agreementName = _agreementNameController.text.trim();
    final partnerName = _partnerNameController.text.trim();
    if (agreementName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('계약명을 입력하세요.')));
      return;
    }
    if (partnerName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('거래처를 입력하세요.')));
      return;
    }

    final baseRate = double.tryParse(_baseRateController.text.trim()) ?? 0;
    final record = _RateRecord(
      id: _selectedId ?? _nextRecordId(),
      type: _selectedType,
      status: _selectedStatus,
      agreementNo: _agreementNoController.text.trim(),
      agreementName: agreementName,
      partnerName: partnerName,
      partnerCode: _partnerCodeController.text.trim(),
      contractOwner: _ownerController.text.trim(),
      effectiveFrom: _effectiveFromController.text.trim(),
      effectiveTo: _effectiveToController.text.trim(),
      paymentTerms: _paymentTermsController.text.trim(),
      laneCode: _laneCodeController.text.trim(),
      originName: _originController.text.trim(),
      destinationName: _destinationController.text.trim(),
      serviceLevel: _serviceLevelController.text.trim(),
      modeName: _modeController.text.trim(),
      equipmentName: _equipmentController.text.trim(),
      baseRateAmount: baseRate,
      minChargeAmount: double.tryParse(_minChargeController.text.trim()) ?? 0,
      transitHours: int.tryParse(_transitHoursController.text.trim()) ?? 0,
      chargeCode: _chargeCodeController.text.trim(),
      chargeName: _chargeNameController.text.trim(),
      calculationMethod: _calculationMethod,
      unitCode: _unitCodeController.text.trim(),
      rateAmount:
          double.tryParse(_rateAmountController.text.trim()) ?? baseRate,
      minimumAmount: double.tryParse(_minimumAmountController.text.trim()) ?? 0,
      fuelIndexName: _fuelIndexController.text.trim(),
      baselineFuelPrice:
          double.tryParse(_baselineFuelController.text.trim()) ?? 0,
      surchargePercent:
          double.tryParse(_surchargePercentController.text.trim()) ?? 0,
      isActive: _isActive,
      autoRating: _autoRating,
      tollIncluded: _tollIncluded,
      taxIncluded: _taxIncluded,
      fuelSurchargeEnabled: _fuelSurchargeEnabled,
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

    final result = await MasterApi.instance.saveRateAgreement(
      record.toApiPayload(),
    );
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.failed
              ? '${record.agreementName} 운임/계약 화면 반영 완료, DB 저장 실패: ${result.message}'
              : '${record.agreementName} 운임/계약 마스터가 반영되었습니다.',
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
              _RateHeader(onCreate: _startCreate),
              const SizedBox(height: 16),
              _RateStats(records: _records),
              const SizedBox(height: 16),
              _AgreementTypeSelector(
                selectedType: _typeFilter,
                counts: {
                  for (final type in _AgreementType.values)
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
              _RateToolbar(
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
                      child: _RateDirectoryPanel(
                        records: filteredRecords,
                        selectedId: _selectedId,
                        onSelect: _selectRecord,
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 456,
                      child: _RateEditorPanel(
                        selectedRecord: selectedRecord,
                        agreementNoController: _agreementNoController,
                        agreementNameController: _agreementNameController,
                        partnerNameController: _partnerNameController,
                        partnerCodeController: _partnerCodeController,
                        ownerController: _ownerController,
                        effectiveFromController: _effectiveFromController,
                        effectiveToController: _effectiveToController,
                        paymentTermsController: _paymentTermsController,
                        laneCodeController: _laneCodeController,
                        originController: _originController,
                        destinationController: _destinationController,
                        serviceLevelController: _serviceLevelController,
                        modeController: _modeController,
                        equipmentController: _equipmentController,
                        baseRateController: _baseRateController,
                        minChargeController: _minChargeController,
                        transitHoursController: _transitHoursController,
                        chargeCodeController: _chargeCodeController,
                        chargeNameController: _chargeNameController,
                        unitCodeController: _unitCodeController,
                        rateAmountController: _rateAmountController,
                        minimumAmountController: _minimumAmountController,
                        fuelIndexController: _fuelIndexController,
                        baselineFuelController: _baselineFuelController,
                        surchargePercentController: _surchargePercentController,
                        memoController: _memoController,
                        selectedType: _selectedType,
                        selectedStatus: _selectedStatus,
                        calculationMethod: _calculationMethod,
                        isActive: _isActive,
                        autoRating: _autoRating,
                        tollIncluded: _tollIncluded,
                        taxIncluded: _taxIncluded,
                        fuelSurchargeEnabled: _fuelSurchargeEnabled,
                        onTypeChanged: (value) => setState(() {
                          _selectedType = value;
                          if (_selectedId == null) {
                            _agreementNoController.text = _nextAgreementNo(
                              value,
                            );
                          }
                        }),
                        onStatusChanged: (value) =>
                            setState(() => _selectedStatus = value),
                        onCalculationMethodChanged: (value) =>
                            setState(() => _calculationMethod = value),
                        onActiveChanged: (value) =>
                            setState(() => _isActive = value),
                        onAutoRatingChanged: (value) =>
                            setState(() => _autoRating = value),
                        onTollChanged: (value) =>
                            setState(() => _tollIncluded = value),
                        onTaxChanged: (value) =>
                            setState(() => _taxIncluded = value),
                        onFuelChanged: (value) =>
                            setState(() => _fuelSurchargeEnabled = value),
                        onSave: _saveRecord,
                      ),
                    ),
                  ],
                )
              else ...[
                _RateEditorPanel(
                  selectedRecord: selectedRecord,
                  agreementNoController: _agreementNoController,
                  agreementNameController: _agreementNameController,
                  partnerNameController: _partnerNameController,
                  partnerCodeController: _partnerCodeController,
                  ownerController: _ownerController,
                  effectiveFromController: _effectiveFromController,
                  effectiveToController: _effectiveToController,
                  paymentTermsController: _paymentTermsController,
                  laneCodeController: _laneCodeController,
                  originController: _originController,
                  destinationController: _destinationController,
                  serviceLevelController: _serviceLevelController,
                  modeController: _modeController,
                  equipmentController: _equipmentController,
                  baseRateController: _baseRateController,
                  minChargeController: _minChargeController,
                  transitHoursController: _transitHoursController,
                  chargeCodeController: _chargeCodeController,
                  chargeNameController: _chargeNameController,
                  unitCodeController: _unitCodeController,
                  rateAmountController: _rateAmountController,
                  minimumAmountController: _minimumAmountController,
                  fuelIndexController: _fuelIndexController,
                  baselineFuelController: _baselineFuelController,
                  surchargePercentController: _surchargePercentController,
                  memoController: _memoController,
                  selectedType: _selectedType,
                  selectedStatus: _selectedStatus,
                  calculationMethod: _calculationMethod,
                  isActive: _isActive,
                  autoRating: _autoRating,
                  tollIncluded: _tollIncluded,
                  taxIncluded: _taxIncluded,
                  fuelSurchargeEnabled: _fuelSurchargeEnabled,
                  onTypeChanged: (value) => setState(() {
                    _selectedType = value;
                    if (_selectedId == null) {
                      _agreementNoController.text = _nextAgreementNo(value);
                    }
                  }),
                  onStatusChanged: (value) =>
                      setState(() => _selectedStatus = value),
                  onCalculationMethodChanged: (value) =>
                      setState(() => _calculationMethod = value),
                  onActiveChanged: (value) => setState(() => _isActive = value),
                  onAutoRatingChanged: (value) =>
                      setState(() => _autoRating = value),
                  onTollChanged: (value) =>
                      setState(() => _tollIncluded = value),
                  onTaxChanged: (value) => setState(() => _taxIncluded = value),
                  onFuelChanged: (value) =>
                      setState(() => _fuelSurchargeEnabled = value),
                  onSave: _saveRecord,
                ),
                const SizedBox(height: 16),
                _RateDirectoryPanel(
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

class _RateHeader extends StatelessWidget {
  const _RateHeader({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      padding: const EdgeInsets.all(22),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppTheme.amber.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.request_quote_rounded,
              color: AppTheme.amber,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '운임/계약 마스터',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.graphite,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '매출/매입 운임계약, 구간 단가, 부대비 규칙, 유류할증 기준을 관리합니다.',
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
            icon: const Icon(Icons.add_card_rounded, size: 19),
            label: const Text('계약 등록'),
          ),
        ],
      ),
    );
  }
}

class _RateStats extends StatelessWidget {
  const _RateStats({required this.records});

  final List<_RateRecord> records;

  @override
  Widget build(BuildContext context) {
    final active = records
        .where((record) => record.status == _AgreementStatus.active)
        .length;
    final sell = records
        .where((record) => record.type == _AgreementType.sell)
        .length;
    final buy = records
        .where((record) => record.type == _AgreementType.buy)
        .length;
    final fuel = records.where((record) => record.fuelSurchargeEnabled).length;

    final metrics = [
      _RateMetric(
        label: '유효 계약',
        value: '$active',
        icon: Icons.verified_rounded,
        color: AppTheme.teal,
      ),
      _RateMetric(
        label: '매출 운임',
        value: '$sell',
        icon: Icons.trending_up_rounded,
        color: const Color(0xFF2563EB),
      ),
      _RateMetric(
        label: '매입 운임',
        value: '$buy',
        icon: Icons.local_shipping_rounded,
        color: const Color(0xFF7C3AED),
      ),
      _RateMetric(
        label: '유류할증',
        value: '$fuel',
        icon: Icons.local_gas_station_rounded,
        color: AppTheme.amber,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 ? 4 : 2;
        final width = (constraints.maxWidth - ((columns - 1) * 12)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: metrics
              .map(
                (metric) => SizedBox(
                  width: width,
                  child: _RateMetricCard(metric: metric),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _AgreementTypeSelector extends StatelessWidget {
  const _AgreementTypeSelector({
    required this.selectedType,
    required this.counts,
    required this.onSelect,
  });

  final _AgreementType? selectedType;
  final Map<_AgreementType, int> counts;
  final ValueChanged<_AgreementType> onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth >= 720
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _AgreementType.values
              .map(
                (type) => SizedBox(
                  width: width,
                  child: _TypeCard(
                    type: type,
                    count: counts[type] ?? 0,
                    selected: selectedType == type,
                    onTap: () => onSelect(type),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _RateToolbar extends StatelessWidget {
  const _RateToolbar({
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
    return _Surface(
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 720;
          final search = TextField(
            onChanged: onQueryChanged,
            decoration: const InputDecoration(
              labelText: '계약, 거래처, 구간 검색',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          );
          final status = DropdownButtonFormField<String>(
            initialValue: statusFilter,
            decoration: const InputDecoration(
              labelText: '상태',
              prefixIcon: Icon(Icons.filter_alt_rounded),
            ),
            items: const [
              DropdownMenuItem(value: 'ALL', child: Text('전체')),
              DropdownMenuItem(value: 'DRAFT', child: Text('작성')),
              DropdownMenuItem(value: 'ACTIVE', child: Text('유효')),
              DropdownMenuItem(value: 'EXPIRED', child: Text('만료')),
              DropdownMenuItem(value: 'CANCELLED', child: Text('해지')),
            ],
            onChanged: (value) {
              if (value != null) {
                onStatusChanged(value);
              }
            },
          );

          if (narrow) {
            return Column(
              children: [search, const SizedBox(height: 10), status],
            );
          }
          return Row(
            children: [
              Expanded(child: search),
              const SizedBox(width: 12),
              SizedBox(width: 220, child: status),
            ],
          );
        },
      ),
    );
  }
}

class _RateDirectoryPanel extends StatelessWidget {
  const _RateDirectoryPanel({
    required this.records,
    required this.selectedId,
    required this.onSelect,
  });

  final List<_RateRecord> records;
  final int? selectedId;
  final ValueChanged<_RateRecord> onSelect;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelTitle(
            icon: Icons.table_chart_rounded,
            title: '계약 디렉터리',
            subtitle: 'rate_agreements / rate_agreement_lanes',
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingTextStyle: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(
                    color: AppTheme.slate,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
              dataTextStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.graphite,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
              columns: const [
                DataColumn(label: Text('구분')),
                DataColumn(label: Text('계약번호')),
                DataColumn(label: Text('계약명')),
                DataColumn(label: Text('거래처')),
                DataColumn(label: Text('구간')),
                DataColumn(label: Text('기준운임')),
                DataColumn(label: Text('기간')),
                DataColumn(label: Text('상태')),
              ],
              rows: records
                  .map(
                    (record) => DataRow(
                      selected: record.id == selectedId,
                      onSelectChanged: (_) => onSelect(record),
                      cells: [
                        DataCell(_TypePill(type: record.type)),
                        DataCell(Text(record.agreementNo)),
                        DataCell(
                          SizedBox(
                            width: 210,
                            child: Text(
                              record.agreementName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 150,
                            child: Text(
                              record.partnerName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            '${record.originName} → ${record.destinationName}',
                          ),
                        ),
                        DataCell(Text(_money(record.baseRateAmount))),
                        DataCell(
                          Text(
                            '${record.effectiveFrom} ~ ${record.effectiveTo}',
                          ),
                        ),
                        DataCell(_StatusChip(status: record.status)),
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

class _RateEditorPanel extends StatelessWidget {
  const _RateEditorPanel({
    required this.selectedRecord,
    required this.agreementNoController,
    required this.agreementNameController,
    required this.partnerNameController,
    required this.partnerCodeController,
    required this.ownerController,
    required this.effectiveFromController,
    required this.effectiveToController,
    required this.paymentTermsController,
    required this.laneCodeController,
    required this.originController,
    required this.destinationController,
    required this.serviceLevelController,
    required this.modeController,
    required this.equipmentController,
    required this.baseRateController,
    required this.minChargeController,
    required this.transitHoursController,
    required this.chargeCodeController,
    required this.chargeNameController,
    required this.unitCodeController,
    required this.rateAmountController,
    required this.minimumAmountController,
    required this.fuelIndexController,
    required this.baselineFuelController,
    required this.surchargePercentController,
    required this.memoController,
    required this.selectedType,
    required this.selectedStatus,
    required this.calculationMethod,
    required this.isActive,
    required this.autoRating,
    required this.tollIncluded,
    required this.taxIncluded,
    required this.fuelSurchargeEnabled,
    required this.onTypeChanged,
    required this.onStatusChanged,
    required this.onCalculationMethodChanged,
    required this.onActiveChanged,
    required this.onAutoRatingChanged,
    required this.onTollChanged,
    required this.onTaxChanged,
    required this.onFuelChanged,
    required this.onSave,
  });

  final _RateRecord? selectedRecord;
  final TextEditingController agreementNoController;
  final TextEditingController agreementNameController;
  final TextEditingController partnerNameController;
  final TextEditingController partnerCodeController;
  final TextEditingController ownerController;
  final TextEditingController effectiveFromController;
  final TextEditingController effectiveToController;
  final TextEditingController paymentTermsController;
  final TextEditingController laneCodeController;
  final TextEditingController originController;
  final TextEditingController destinationController;
  final TextEditingController serviceLevelController;
  final TextEditingController modeController;
  final TextEditingController equipmentController;
  final TextEditingController baseRateController;
  final TextEditingController minChargeController;
  final TextEditingController transitHoursController;
  final TextEditingController chargeCodeController;
  final TextEditingController chargeNameController;
  final TextEditingController unitCodeController;
  final TextEditingController rateAmountController;
  final TextEditingController minimumAmountController;
  final TextEditingController fuelIndexController;
  final TextEditingController baselineFuelController;
  final TextEditingController surchargePercentController;
  final TextEditingController memoController;
  final _AgreementType selectedType;
  final _AgreementStatus selectedStatus;
  final _CalculationMethod calculationMethod;
  final bool isActive;
  final bool autoRating;
  final bool tollIncluded;
  final bool taxIncluded;
  final bool fuelSurchargeEnabled;
  final ValueChanged<_AgreementType> onTypeChanged;
  final ValueChanged<_AgreementStatus> onStatusChanged;
  final ValueChanged<_CalculationMethod> onCalculationMethodChanged;
  final ValueChanged<bool> onActiveChanged;
  final ValueChanged<bool> onAutoRatingChanged;
  final ValueChanged<bool> onTollChanged;
  final ValueChanged<bool> onTaxChanged;
  final ValueChanged<bool> onFuelChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _PanelTitle(
                  icon: Icons.request_quote_rounded,
                  title: selectedRecord == null ? '신규 계약 등록' : '계약 상세',
                  subtitle: selectedRecord?.agreementNo ?? 'rate_agreements',
                  compact: true,
                ),
              ),
              Switch(value: isActive, onChanged: onActiveChanged),
            ],
          ),
          const SizedBox(height: 14),
          _SectionLabel(icon: Icons.assignment_rounded, label: '계약 기본'),
          _EditorGrid(
            children: [
              _RateTextField(
                controller: agreementNoController,
                label: '계약번호',
                icon: Icons.tag_rounded,
              ),
              _RateTextField(
                controller: agreementNameController,
                label: '계약명',
                icon: Icons.description_rounded,
              ),
              DropdownButtonFormField<_AgreementType>(
                initialValue: selectedType,
                decoration: const InputDecoration(
                  labelText: '계약 구분',
                  prefixIcon: Icon(Icons.swap_horiz_rounded),
                ),
                items: _AgreementType.values
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
              DropdownButtonFormField<_AgreementStatus>(
                initialValue: selectedStatus,
                decoration: const InputDecoration(
                  labelText: '상태',
                  prefixIcon: Icon(Icons.verified_rounded),
                ),
                items: _AgreementStatus.values
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
              _RateTextField(
                controller: partnerNameController,
                label: '거래처',
                icon: Icons.business_rounded,
              ),
              _RateTextField(
                controller: partnerCodeController,
                label: '거래처 코드',
                icon: Icons.badge_rounded,
              ),
              _RateTextField(
                controller: effectiveFromController,
                label: '시작일',
                icon: Icons.event_available_rounded,
              ),
              _RateTextField(
                controller: effectiveToController,
                label: '종료일',
                icon: Icons.event_busy_rounded,
              ),
              _RateTextField(
                controller: ownerController,
                label: '담당자',
                icon: Icons.person_rounded,
              ),
              _RateTextField(
                controller: paymentTermsController,
                label: '정산 조건',
                icon: Icons.payments_rounded,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionLabel(icon: Icons.alt_route_rounded, label: '구간 운임'),
          _EditorGrid(
            children: [
              _RateTextField(
                controller: laneCodeController,
                label: '구간 코드',
                icon: Icons.route_rounded,
              ),
              _RateTextField(
                controller: originController,
                label: '출발 권역/거점',
                icon: Icons.trip_origin_rounded,
              ),
              _RateTextField(
                controller: destinationController,
                label: '도착 권역/거점',
                icon: Icons.location_on_rounded,
              ),
              _RateTextField(
                controller: serviceLevelController,
                label: '서비스 레벨',
                icon: Icons.speed_rounded,
              ),
              _RateTextField(
                controller: modeController,
                label: '운송 모드',
                icon: Icons.local_shipping_rounded,
              ),
              _RateTextField(
                controller: equipmentController,
                label: '차량/장비',
                icon: Icons.fire_truck_rounded,
              ),
              _RateTextField(
                controller: baseRateController,
                label: '기준 운임',
                icon: Icons.price_change_rounded,
                keyboardType: TextInputType.number,
              ),
              _RateTextField(
                controller: minChargeController,
                label: '최저 운임',
                icon: Icons.vertical_align_bottom_rounded,
                keyboardType: TextInputType.number,
              ),
              _RateTextField(
                controller: transitHoursController,
                label: '리드타임(시간)',
                icon: Icons.timer_rounded,
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionLabel(icon: Icons.functions_rounded, label: '요율 규칙'),
          _EditorGrid(
            children: [
              _RateTextField(
                controller: chargeCodeController,
                label: '청구 코드',
                icon: Icons.confirmation_number_rounded,
              ),
              _RateTextField(
                controller: chargeNameController,
                label: '청구 항목명',
                icon: Icons.receipt_long_rounded,
              ),
              DropdownButtonFormField<_CalculationMethod>(
                initialValue: calculationMethod,
                decoration: const InputDecoration(
                  labelText: '계산 방식',
                  prefixIcon: Icon(Icons.calculate_rounded),
                ),
                items: _CalculationMethod.values
                    .map(
                      (method) => DropdownMenuItem(
                        value: method,
                        child: Text(method.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    onCalculationMethodChanged(value);
                  }
                },
              ),
              _RateTextField(
                controller: unitCodeController,
                label: '단위',
                icon: Icons.straighten_rounded,
              ),
              _RateTextField(
                controller: rateAmountController,
                label: '단가',
                icon: Icons.paid_rounded,
                keyboardType: TextInputType.number,
              ),
              _RateTextField(
                controller: minimumAmountController,
                label: '최소 청구액',
                icon: Icons.price_check_rounded,
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _RateSwitchTile(
            label: '자동 운임 산정',
            value: autoRating,
            onChanged: onAutoRatingChanged,
            icon: Icons.auto_awesome_rounded,
          ),
          _RateSwitchTile(
            label: '통행료 포함',
            value: tollIncluded,
            onChanged: onTollChanged,
            icon: Icons.toll_rounded,
          ),
          _RateSwitchTile(
            label: '부가세 대상',
            value: taxIncluded,
            onChanged: onTaxChanged,
            icon: Icons.percent_rounded,
          ),
          _RateSwitchTile(
            label: '유류할증 적용',
            value: fuelSurchargeEnabled,
            onChanged: onFuelChanged,
            icon: Icons.local_gas_station_rounded,
          ),
          if (fuelSurchargeEnabled) ...[
            const SizedBox(height: 12),
            _SectionLabel(icon: Icons.local_gas_station_rounded, label: '유류할증'),
            _EditorGrid(
              children: [
                _RateTextField(
                  controller: fuelIndexController,
                  label: '유가 지표',
                  icon: Icons.query_stats_rounded,
                ),
                _RateTextField(
                  controller: baselineFuelController,
                  label: '기준 유가',
                  icon: Icons.speed_rounded,
                  keyboardType: TextInputType.number,
                ),
                _RateTextField(
                  controller: surchargePercentController,
                  label: '할증률(%)',
                  icon: Icons.percent_rounded,
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: memoController,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: '계약/운임 메모',
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

class _Surface extends StatelessWidget {
  const _Surface({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
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
      child: child,
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.type,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final _AgreementType type;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected ? type.color.withValues(alpha: 0.09) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? type.color : AppTheme.line),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: type.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(type.icon, color: type.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.graphite,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      type.description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.slate,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$count',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: type.color,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
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
          Icon(icon, color: AppTheme.amber, size: compact ? 20 : 22),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.amber),
          const SizedBox(width: 7),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
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

class _RateTextField extends StatelessWidget {
  const _RateTextField({
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

class _RateSwitchTile extends StatelessWidget {
  const _RateSwitchTile({
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
          Icon(icon, color: value ? AppTheme.amber : AppTheme.slate, size: 20),
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

class _RateMetricCard extends StatelessWidget {
  const _RateMetricCard({required this.metric});

  final _RateMetric metric;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      padding: const EdgeInsets.all(14),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric.value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.graphite,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                Text(
                  metric.label,
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

  final _AgreementType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: type.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        type.label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: type.color,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final _AgreementStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: status.color,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

enum _AgreementType {
  sell,
  buy;

  String get label => switch (this) {
    _AgreementType.sell => '매출 계약',
    _AgreementType.buy => '매입 계약',
  };

  String get description => switch (this) {
    _AgreementType.sell => '고객사 청구 운임',
    _AgreementType.buy => '운송사 지급 운임',
  };

  String get code => switch (this) {
    _AgreementType.sell => 'SELL',
    _AgreementType.buy => 'BUY',
  };

  String get partnerType => switch (this) {
    _AgreementType.sell => 'CUSTOMER',
    _AgreementType.buy => 'CARRIER',
  };

  String get prefix => switch (this) {
    _AgreementType.sell => 'RA-S',
    _AgreementType.buy => 'RA-B',
  };

  IconData get icon => switch (this) {
    _AgreementType.sell => Icons.trending_up_rounded,
    _AgreementType.buy => Icons.local_shipping_rounded,
  };

  Color get color => switch (this) {
    _AgreementType.sell => AppTheme.teal,
    _AgreementType.buy => const Color(0xFF7C3AED),
  };
}

enum _AgreementStatus {
  draft,
  active,
  expired,
  cancelled;

  String get label => switch (this) {
    _AgreementStatus.draft => '작성',
    _AgreementStatus.active => '유효',
    _AgreementStatus.expired => '만료',
    _AgreementStatus.cancelled => '해지',
  };

  String get code => switch (this) {
    _AgreementStatus.draft => 'DRAFT',
    _AgreementStatus.active => 'ACTIVE',
    _AgreementStatus.expired => 'EXPIRED',
    _AgreementStatus.cancelled => 'CANCELLED',
  };

  Color get color => switch (this) {
    _AgreementStatus.draft => AppTheme.slate,
    _AgreementStatus.active => AppTheme.teal,
    _AgreementStatus.expired => AppTheme.amber,
    _AgreementStatus.cancelled => const Color(0xFFDC2626),
  };
}

enum _CalculationMethod {
  flat,
  perKm,
  perKg,
  perCbm,
  perPallet,
  perStop,
  percent;

  String get label => switch (this) {
    _CalculationMethod.flat => '고정',
    _CalculationMethod.perKm => 'KM당',
    _CalculationMethod.perKg => 'KG당',
    _CalculationMethod.perCbm => 'CBM당',
    _CalculationMethod.perPallet => 'PLT당',
    _CalculationMethod.perStop => '경유지당',
    _CalculationMethod.percent => '비율',
  };

  String get code => switch (this) {
    _CalculationMethod.flat => 'FLAT',
    _CalculationMethod.perKm => 'PER_KM',
    _CalculationMethod.perKg => 'PER_KG',
    _CalculationMethod.perCbm => 'PER_CBM',
    _CalculationMethod.perPallet => 'PER_PALLET',
    _CalculationMethod.perStop => 'PER_STOP',
    _CalculationMethod.percent => 'PERCENT',
  };
}

class _RateMetric {
  const _RateMetric({
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

class _RateRecord {
  const _RateRecord({
    required this.id,
    required this.type,
    required this.status,
    required this.agreementNo,
    required this.agreementName,
    required this.partnerName,
    required this.partnerCode,
    required this.contractOwner,
    required this.effectiveFrom,
    required this.effectiveTo,
    required this.paymentTerms,
    required this.laneCode,
    required this.originName,
    required this.destinationName,
    required this.serviceLevel,
    required this.modeName,
    required this.equipmentName,
    required this.baseRateAmount,
    required this.minChargeAmount,
    required this.transitHours,
    required this.chargeCode,
    required this.chargeName,
    required this.calculationMethod,
    required this.unitCode,
    required this.rateAmount,
    required this.minimumAmount,
    required this.fuelIndexName,
    required this.baselineFuelPrice,
    required this.surchargePercent,
    required this.isActive,
    required this.autoRating,
    required this.tollIncluded,
    required this.taxIncluded,
    required this.fuelSurchargeEnabled,
    required this.memo,
  });

  final int id;
  final _AgreementType type;
  final _AgreementStatus status;
  final String agreementNo;
  final String agreementName;
  final String partnerName;
  final String partnerCode;
  final String contractOwner;
  final String effectiveFrom;
  final String effectiveTo;
  final String paymentTerms;
  final String laneCode;
  final String originName;
  final String destinationName;
  final String serviceLevel;
  final String modeName;
  final String equipmentName;
  final double baseRateAmount;
  final double minChargeAmount;
  final int transitHours;
  final String chargeCode;
  final String chargeName;
  final _CalculationMethod calculationMethod;
  final String unitCode;
  final double rateAmount;
  final double minimumAmount;
  final String fuelIndexName;
  final double baselineFuelPrice;
  final double surchargePercent;
  final bool isActive;
  final bool autoRating;
  final bool tollIncluded;
  final bool taxIncluded;
  final bool fuelSurchargeEnabled;
  final String memo;

  Map<String, Object?> toApiPayload() {
    return {
      'agreement_no': agreementNo,
      'agreement_name': agreementName,
      'agreement_type': type.code,
      'partner_code': partnerCode,
      'partner_name': partnerName,
      'partner_type': type.partnerType,
      'currency_code': 'KRW',
      'effective_from': effectiveFrom,
      'effective_to': effectiveTo,
      'status': status.code,
      'is_active': isActive,
      'contract_owner': contractOwner,
      'payment_terms': paymentTerms,
      'auto_rating': autoRating,
      'toll_included': tollIncluded,
      'tax_included': taxIncluded,
      'lane_code': laneCode,
      'origin_name': originName,
      'destination_name': destinationName,
      'mode_code': modeName,
      'mode_name': modeName,
      'service_level_code': serviceLevel,
      'service_level_name': serviceLevel,
      'equipment_code': equipmentName,
      'equipment_name': equipmentName,
      'base_rate_amount': baseRateAmount,
      'min_charge_amount': minChargeAmount,
      'transit_hours': transitHours,
      'charge_code': chargeCode,
      'charge_name': chargeName,
      'charge_category': chargeCode == 'FUEL_SURCHARGE' ? 'FUEL' : 'BASE',
      'calculation_method': calculationMethod.code,
      'unit_code': unitCode,
      'rate_amount': rateAmount,
      'minimum_amount': minimumAmount,
      'fuel_surcharge_enabled': fuelSurchargeEnabled,
      'fuel_rule_code': '$agreementNo-FUEL',
      'fuel_rule_name': '$agreementName 유류할증',
      'fuel_index_name': fuelIndexName,
      'baseline_price': baselineFuelPrice,
      'surcharge_percent': surchargePercent,
      'memo': memo,
      'metadata': {
        'contract_owner': contractOwner,
        'payment_terms': paymentTerms,
        'memo': memo,
      },
    };
  }
}

String _money(double value) {
  final text = value.toStringAsFixed(0);
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    if (i > 0 && (text.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(text[i]);
  }
  return '₩$buffer';
}

const _seedRates = [
  _RateRecord(
    id: 1,
    type: _AgreementType.sell,
    status: _AgreementStatus.active,
    agreementNo: 'RA-S-0001',
    agreementName: '삼성전자 수도권 B2B 정기운송',
    partnerName: '삼성전자',
    partnerCode: 'CUS-SAMSUNG',
    contractOwner: '영업1팀',
    effectiveFrom: '2026-01-01',
    effectiveTo: '2026-12-31',
    paymentTerms: '익월 말일',
    laneCode: 'SEL-ICN-5T',
    originName: '수원 RDC',
    destinationName: '인천권역',
    serviceLevel: 'STANDARD',
    modeName: 'TRUCK',
    equipmentName: '5톤 윙바디',
    baseRateAmount: 185000,
    minChargeAmount: 160000,
    transitHours: 8,
    chargeCode: 'BASE_FREIGHT',
    chargeName: '기본 운임',
    calculationMethod: _CalculationMethod.flat,
    unitCode: 'TRIP',
    rateAmount: 185000,
    minimumAmount: 160000,
    fuelIndexName: '한국석유공사 경유가',
    baselineFuelPrice: 1500,
    surchargePercent: 3.5,
    isActive: true,
    autoRating: true,
    tollIncluded: true,
    taxIncluded: true,
    fuelSurchargeEnabled: true,
    memo: '월 300건 이상 물량 보장 기준.',
  ),
  _RateRecord(
    id: 2,
    type: _AgreementType.buy,
    status: _AgreementStatus.active,
    agreementNo: 'RA-B-0001',
    agreementName: 'CJ대한통운 간선 운송사 계약',
    partnerName: 'CJ대한통운',
    partnerCode: 'CAR-CJ',
    contractOwner: '운영정산팀',
    effectiveFrom: '2026-03-01',
    effectiveTo: '2027-02-28',
    paymentTerms: '마감 후 15일',
    laneCode: 'BUS-SEO-11T',
    originName: '부산 허브',
    destinationName: '수도권 허브',
    serviceLevel: 'EXPRESS',
    modeName: 'TRUCK',
    equipmentName: '11톤 윙바디',
    baseRateAmount: 520000,
    minChargeAmount: 480000,
    transitHours: 12,
    chargeCode: 'LINEHAUL',
    chargeName: '간선 운임',
    calculationMethod: _CalculationMethod.flat,
    unitCode: 'TRIP',
    rateAmount: 520000,
    minimumAmount: 480000,
    fuelIndexName: '한국석유공사 경유가',
    baselineFuelPrice: 1520,
    surchargePercent: 2.2,
    isActive: true,
    autoRating: true,
    tollIncluded: false,
    taxIncluded: true,
    fuelSurchargeEnabled: true,
    memo: '심야 출발 SLA 98% 조건.',
  ),
  _RateRecord(
    id: 3,
    type: _AgreementType.sell,
    status: _AgreementStatus.draft,
    agreementNo: 'RA-S-0002',
    agreementName: '냉장 신선식품 수도권 라스트마일',
    partnerName: '프레시푸드',
    partnerCode: 'CUS-FRESH',
    contractOwner: '콜드체인TF',
    effectiveFrom: '2026-07-01',
    effectiveTo: '2027-06-30',
    paymentTerms: '익월 15일',
    laneCode: 'COLD-SEO-LM',
    originName: '이천 콜드센터',
    destinationName: '수도권 매장',
    serviceLevel: 'COLD_CHAIN',
    modeName: 'TRUCK',
    equipmentName: '냉장 2.5톤',
    baseRateAmount: 92000,
    minChargeAmount: 80000,
    transitHours: 6,
    chargeCode: 'COLD_FREIGHT',
    chargeName: '냉장 운임',
    calculationMethod: _CalculationMethod.perStop,
    unitCode: 'STOP',
    rateAmount: 18000,
    minimumAmount: 80000,
    fuelIndexName: '한국석유공사 경유가',
    baselineFuelPrice: 1500,
    surchargePercent: 0,
    isActive: true,
    autoRating: true,
    tollIncluded: true,
    taxIncluded: true,
    fuelSurchargeEnabled: false,
    memo: '온도 이탈 패널티 별도 부과.',
  ),
];
