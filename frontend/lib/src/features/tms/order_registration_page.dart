import 'package:flutter/material.dart';

import '../../design/app_theme.dart';
import '../../design/numeric_input_formatters.dart';
import 'master_api.dart';

class OrderRegistrationPage extends StatefulWidget {
  const OrderRegistrationPage({super.key, this.compact = false});

  final bool compact;

  @override
  State<OrderRegistrationPage> createState() => _OrderRegistrationPageState();
}

class _OrderRegistrationPageState extends State<OrderRegistrationPage> {
  final _orderNoController = TextEditingController();
  final _externalOrderController = TextEditingController();
  final _customerController = TextEditingController();
  final _shipperController = TextEditingController();
  final _billToController = TextEditingController();
  final _pickupNameController = TextEditingController();
  final _pickupAddressController = TextEditingController();
  final _pickupStartController = TextEditingController();
  final _pickupEndController = TextEditingController();
  final _deliveryNameController = TextEditingController();
  final _deliveryAddressController = TextEditingController();
  final _deliveryStartController = TextEditingController();
  final _deliveryEndController = TextEditingController();
  final _itemController = TextEditingController();
  final _quantityController = TextEditingController();
  final _packageController = TextEditingController();
  final _weightController = TextEditingController();
  final _volumeController = TextEditingController();
  final _chargeController = TextEditingController();
  final _minTempController = TextEditingController();
  final _maxTempController = TextEditingController();
  final _instructionController = TextEditingController();

  late final List<_OrderRecord> _records;
  _OrderType _selectedType = _OrderType.standard;
  _Priority _selectedPriority = _Priority.normal;
  _TransportMode _selectedMode = _TransportMode.road;
  _ServiceLevel _selectedService = _ServiceLevel.standard;
  String _statusFilter = 'ALL';
  String _query = '';
  int? _selectedId;
  bool _appointmentRequired = true;
  bool _temperatureControlled = false;
  bool _hazmatRequired = false;
  bool _autoPlan = true;
  List<BusinessPartnerOption> _partnerOptions = _fallbackPartnerOptions;

  @override
  void initState() {
    super.initState();
    _records = List<_OrderRecord>.from(_seedOrders);
    _selectRecord(_records.first, notify: false);
    _loadPartnerOptions();
  }

  @override
  void dispose() {
    _orderNoController.dispose();
    _externalOrderController.dispose();
    _customerController.dispose();
    _shipperController.dispose();
    _billToController.dispose();
    _pickupNameController.dispose();
    _pickupAddressController.dispose();
    _pickupStartController.dispose();
    _pickupEndController.dispose();
    _deliveryNameController.dispose();
    _deliveryAddressController.dispose();
    _deliveryStartController.dispose();
    _deliveryEndController.dispose();
    _itemController.dispose();
    _quantityController.dispose();
    _packageController.dispose();
    _weightController.dispose();
    _volumeController.dispose();
    _chargeController.dispose();
    _minTempController.dispose();
    _maxTempController.dispose();
    _instructionController.dispose();
    super.dispose();
  }

  List<_OrderRecord> get _filteredRecords {
    final normalizedQuery = _query.trim().toLowerCase();
    return _records.where((record) {
      final matchesStatus =
          _statusFilter == 'ALL' || record.statusCode == _statusFilter;
      final matchesQuery =
          normalizedQuery.isEmpty ||
          record.orderNo.toLowerCase().contains(normalizedQuery) ||
          record.customerName.toLowerCase().contains(normalizedQuery) ||
          record.shipperName.toLowerCase().contains(normalizedQuery) ||
          record.pickupName.toLowerCase().contains(normalizedQuery) ||
          record.deliveryName.toLowerCase().contains(normalizedQuery) ||
          record.itemName.toLowerCase().contains(normalizedQuery);
      return matchesStatus && matchesQuery;
    }).toList();
  }

  _OrderRecord? get _selectedRecord {
    for (final record in _records) {
      if (record.id == _selectedId) {
        return record;
      }
    }
    return null;
  }

  void _selectRecord(_OrderRecord record, {bool notify = true}) {
    void apply() {
      _selectedId = record.id;
      _selectedType = record.orderType;
      _selectedPriority = record.priority;
      _selectedMode = record.mode;
      _selectedService = record.serviceLevel;
      _orderNoController.text = record.orderNo;
      _externalOrderController.text = record.externalOrderNo;
      _customerController.text = record.customerName;
      _shipperController.text = record.shipperName;
      _billToController.text = record.billToName;
      _pickupNameController.text = record.pickupName;
      _pickupAddressController.text = record.pickupAddress;
      _pickupStartController.text = record.pickupStart;
      _pickupEndController.text = record.pickupEnd;
      _deliveryNameController.text = record.deliveryName;
      _deliveryAddressController.text = record.deliveryAddress;
      _deliveryStartController.text = record.deliveryStart;
      _deliveryEndController.text = record.deliveryEnd;
      _itemController.text = record.itemName;
      _quantityController.text = record.quantity.toString();
      _packageController.text = record.packages.toString();
      _weightController.text = record.weightKg.toString();
      _volumeController.text = record.volumeCbm.toString();
      _chargeController.text = record.chargeAmount.toStringAsFixed(0);
      _minTempController.text = record.minTemperatureC;
      _maxTempController.text = record.maxTemperatureC;
      _instructionController.text = record.instructions;
      _appointmentRequired = record.appointmentRequired;
      _temperatureControlled = record.temperatureControlled;
      _hazmatRequired = record.hazmatRequired;
      _autoPlan = record.autoPlan;
    }

    if (notify) {
      setState(apply);
    } else {
      apply();
    }
  }

  void _clearEditor() {
    final nextNo = _nextOrderNo();
    _selectedId = null;
    _selectedType = _OrderType.standard;
    _selectedPriority = _Priority.normal;
    _selectedMode = _TransportMode.road;
    _selectedService = _ServiceLevel.standard;
    _orderNoController.text = nextNo;
    _externalOrderController.clear();
    _customerController.clear();
    _shipperController.clear();
    _billToController.clear();
    _pickupNameController.clear();
    _pickupAddressController.clear();
    _pickupStartController.text = '2026-06-15 09:00';
    _pickupEndController.text = '2026-06-15 11:00';
    _deliveryNameController.clear();
    _deliveryAddressController.clear();
    _deliveryStartController.text = '2026-06-15 14:00';
    _deliveryEndController.text = '2026-06-15 18:00';
    _itemController.clear();
    _quantityController.text = '1';
    _packageController.text = '1';
    _weightController.text = '0';
    _volumeController.text = '0';
    _chargeController.text = '0';
    _minTempController.clear();
    _maxTempController.clear();
    _instructionController.clear();
    _appointmentRequired = true;
    _temperatureControlled = false;
    _hazmatRequired = false;
    _autoPlan = true;
  }

  String _nextOrderNo() {
    final now = DateTime.now();
    final dateCode = [
      now.year.toString().padLeft(4, '0'),
      now.month.toString().padLeft(2, '0'),
      now.day.toString().padLeft(2, '0'),
    ].join();
    final orderNoPattern = RegExp('^KT-$dateCode-(\\d{4})\$');
    var maxSequence = 0;
    for (final record in _records) {
      final match = orderNoPattern.firstMatch(record.orderNo);
      if (match == null) {
        continue;
      }
      final sequence = int.tryParse(match.group(1) ?? '') ?? 0;
      if (sequence > maxSequence) {
        maxSequence = sequence;
      }
    }
    return 'KT-$dateCode-${(maxSequence + 1).toString().padLeft(4, '0')}';
  }

  void _startCreate() {
    setState(_clearEditor);
  }

  void _regenerateOrderNo() {
    if (_selectedId != null) {
      return;
    }
    setState(() {
      _orderNoController.text = _nextOrderNo();
    });
  }

  Future<void> _loadPartnerOptions() async {
    final items = await MasterApi.instance.fetchBusinessPartners(limit: 160);
    if (!mounted || items.isEmpty) {
      return;
    }
    setState(() {
      _partnerOptions = _mergePartnerOptions(items);
    });
  }

  List<BusinessPartnerOption> _mergePartnerOptions(
    List<BusinessPartnerOption> items,
  ) {
    final merged = <String, BusinessPartnerOption>{};
    for (final option in [..._fallbackPartnerOptions, ...items]) {
      final key = [
        option.partnerType,
        option.partnerCode.trim().isNotEmpty
            ? option.partnerCode.trim()
            : option.partnerName.trim(),
      ].join(':');
      merged[key] = option;
    }
    return merged.values.toList();
  }

  void _selectCustomerPartner(BusinessPartnerOption option) {
    setState(() {
      _customerController.text = option.partnerName;
      if (_billToController.text.trim().isEmpty) {
        _billToController.text = option.partnerName;
      }
    });
  }

  void _selectShipperPartner(BusinessPartnerOption option) {
    setState(() {
      _shipperController.text = option.partnerName;
    });
  }

  void _selectBillToPartner(BusinessPartnerOption option) {
    setState(() {
      _billToController.text = option.partnerName;
    });
  }

  Future<void> _saveRecord() async {
    final orderNo = _orderNoController.text.trim().toUpperCase();
    final customerName = _customerController.text.trim();
    final pickupName = _pickupNameController.text.trim();
    final deliveryName = _deliveryNameController.text.trim();
    final itemName = _itemController.text.trim();

    if (orderNo.isEmpty) {
      _showMessage('오더번호를 입력하세요.');
      return;
    }
    if (customerName.isEmpty) {
      _showMessage('고객사를 입력하세요.');
      return;
    }
    if (pickupName.isEmpty) {
      _showMessage('상차지를 입력하세요.');
      return;
    }
    if (deliveryName.isEmpty) {
      _showMessage('하차지를 입력하세요.');
      return;
    }
    if (itemName.isEmpty) {
      _showMessage('품목을 입력하세요.');
      return;
    }

    final record = _OrderRecord(
      id: _selectedId ?? _nextRecordId(),
      orderNo: orderNo,
      externalOrderNo: _externalOrderController.text.trim(),
      customerName: customerName,
      shipperName: _shipperController.text.trim().isEmpty
          ? customerName
          : _shipperController.text.trim(),
      billToName: _billToController.text.trim().isEmpty
          ? customerName
          : _billToController.text.trim(),
      pickupName: pickupName,
      pickupAddress: _pickupAddressController.text.trim(),
      pickupStart: _pickupStartController.text.trim(),
      pickupEnd: _pickupEndController.text.trim(),
      deliveryName: deliveryName,
      deliveryAddress: _deliveryAddressController.text.trim(),
      deliveryStart: _deliveryStartController.text.trim(),
      deliveryEnd: _deliveryEndController.text.trim(),
      itemName: itemName,
      quantity: double.tryParse(_quantityController.text.trim()) ?? 0,
      packages: int.tryParse(_packageController.text.trim()) ?? 0,
      weightKg: double.tryParse(_weightController.text.trim()) ?? 0,
      volumeCbm: double.tryParse(_volumeController.text.trim()) ?? 0,
      chargeAmount: double.tryParse(_chargeController.text.trim()) ?? 0,
      orderType: _selectedType,
      priority: _selectedPriority,
      mode: _selectedMode,
      serviceLevel: _selectedService,
      statusCode: 'DRAFT',
      appointmentRequired: _appointmentRequired,
      temperatureControlled: _temperatureControlled,
      minTemperatureC: _minTempController.text.trim(),
      maxTemperatureC: _maxTempController.text.trim(),
      hazmatRequired: _hazmatRequired,
      autoPlan: _autoPlan,
      instructions: _instructionController.text.trim(),
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

    final result = await MasterApi.instance.saveTransportOrder(
      record.toApiPayload(),
    );
    if (!mounted) {
      return;
    }

    _showMessage(
      result.failed
          ? '${record.orderNo} 오더 화면 반영 완료, DB 저장 실패: ${result.message}'
          : '${record.orderNo} 운송오더가 등록되었습니다.',
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
              _OrderHeader(onCreate: _startCreate),
              const SizedBox(height: 16),
              _OrderStats(records: _records),
              const SizedBox(height: 16),
              _OrderToolbar(
                query: _query,
                statusFilter: _statusFilter,
                onQueryChanged: (value) => setState(() => _query = value),
                onStatusChanged: (value) =>
                    setState(() => _statusFilter = value),
              ),
              const SizedBox(height: 16),
              _OrderEditorPanel(
                selectedRecord: selectedRecord,
                orderNoController: _orderNoController,
                externalOrderController: _externalOrderController,
                customerController: _customerController,
                shipperController: _shipperController,
                billToController: _billToController,
                pickupNameController: _pickupNameController,
                pickupAddressController: _pickupAddressController,
                pickupStartController: _pickupStartController,
                pickupEndController: _pickupEndController,
                deliveryNameController: _deliveryNameController,
                deliveryAddressController: _deliveryAddressController,
                deliveryStartController: _deliveryStartController,
                deliveryEndController: _deliveryEndController,
                itemController: _itemController,
                quantityController: _quantityController,
                packageController: _packageController,
                weightController: _weightController,
                volumeController: _volumeController,
                chargeController: _chargeController,
                minTempController: _minTempController,
                maxTempController: _maxTempController,
                instructionController: _instructionController,
                partnerOptions: _partnerOptions,
                selectedType: _selectedType,
                selectedPriority: _selectedPriority,
                selectedMode: _selectedMode,
                selectedService: _selectedService,
                appointmentRequired: _appointmentRequired,
                temperatureControlled: _temperatureControlled,
                hazmatRequired: _hazmatRequired,
                autoPlan: _autoPlan,
                onTypeChanged: (value) => setState(() => _selectedType = value),
                onPriorityChanged: (value) =>
                    setState(() => _selectedPriority = value),
                onModeChanged: (value) => setState(() => _selectedMode = value),
                onServiceChanged: (value) =>
                    setState(() => _selectedService = value),
                onAppointmentChanged: (value) =>
                    setState(() => _appointmentRequired = value),
                onTemperatureChanged: (value) =>
                    setState(() => _temperatureControlled = value),
                onHazmatChanged: (value) =>
                    setState(() => _hazmatRequired = value),
                onAutoPlanChanged: (value) => setState(() => _autoPlan = value),
                onCustomerPartnerSelected: _selectCustomerPartner,
                onShipperPartnerSelected: _selectShipperPartner,
                onBillToPartnerSelected: _selectBillToPartner,
                onRegenerateOrderNo: _regenerateOrderNo,
                onSave: _saveRecord,
              ),
              const SizedBox(height: 16),
              _OrderDirectoryPanel(
                records: filteredRecords,
                selectedId: _selectedId,
                onSelect: _selectRecord,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OrderHeader extends StatelessWidget {
  const _OrderHeader({required this.onCreate});

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
              color: AppTheme.teal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.add_road_rounded,
              color: AppTheme.teal,
              size: 27,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '오더 등록',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.graphite,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '고객사, 화주, 상하차지, 품목, 운송조건, 청구운임을 등록합니다.',
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
            label: const Text('신규 오더'),
          ),
        ],
      ),
    );
  }
}

class _OrderStats extends StatelessWidget {
  const _OrderStats({required this.records});

  final List<_OrderRecord> records;

  @override
  Widget build(BuildContext context) {
    final urgent = records
        .where((record) => record.priority == _Priority.urgent)
        .length;
    final totalWeight = records.fold<double>(
      0,
      (sum, record) => sum + record.weightKg,
    );
    final charge = records.fold<double>(
      0,
      (sum, record) => sum + record.chargeAmount,
    );

    final metrics = [
      _OrderMetric(
        label: '등록 오더',
        value: records.length.toString(),
        icon: Icons.playlist_add_check_rounded,
        color: AppTheme.teal,
      ),
      _OrderMetric(
        label: '긴급',
        value: urgent.toString(),
        icon: Icons.priority_high_rounded,
        color: AppTheme.amber,
      ),
      _OrderMetric(
        label: '총 중량',
        value: '${totalWeight.toStringAsFixed(1)}kg',
        icon: Icons.scale_rounded,
        color: const Color(0xFF2563EB),
      ),
      _OrderMetric(
        label: '청구 운임',
        value: '₩${(charge / 1000000).toStringAsFixed(1)}M',
        icon: Icons.payments_rounded,
        color: const Color(0xFF16A34A),
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
              _OrderMetricCard(metric: metrics[index]),
        );
      },
    );
  }
}

class _OrderToolbar extends StatelessWidget {
  const _OrderToolbar({
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
                hintText: '오더번호, 고객사, 화주, 상차지, 하차지, 품목',
              ),
            ),
          ),
          ...[
            const MapEntry('ALL', '전체'),
            const MapEntry('DRAFT', '임시'),
            const MapEntry('CONFIRMED', '확정'),
            const MapEntry('PLANNED', '계획'),
            const MapEntry('DISPATCHED', '배차'),
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

class _OrderDirectoryPanel extends StatelessWidget {
  const _OrderDirectoryPanel({
    required this.records,
    required this.selectedId,
    required this.onSelect,
  });

  final List<_OrderRecord> records;
  final int? selectedId;
  final ValueChanged<_OrderRecord> onSelect;

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
            icon: Icons.receipt_long_rounded,
            title: '오더 접수 목록',
            subtitle: 'transport_orders / lines / stops',
          ),
          if (records.isEmpty)
            const _EmptyState()
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AppTheme.panel),
                columns: const [
                  DataColumn(label: Text('오더번호')),
                  DataColumn(label: Text('고객사')),
                  DataColumn(label: Text('화주')),
                  DataColumn(label: Text('상차지')),
                  DataColumn(label: Text('하차지')),
                  DataColumn(label: Text('품목')),
                  DataColumn(label: Text('중량')),
                  DataColumn(label: Text('운임')),
                  DataColumn(label: Text('상태')),
                ],
                rows: records
                    .map(
                      (record) => DataRow(
                        selected: selectedId == record.id,
                        onSelectChanged: (_) => onSelect(record),
                        cells: [
                          DataCell(_StrongText(record.orderNo)),
                          DataCell(Text(record.customerName)),
                          DataCell(Text(record.shipperName)),
                          DataCell(Text(record.pickupName)),
                          DataCell(Text(record.deliveryName)),
                          DataCell(Text(record.itemName)),
                          DataCell(Text('${record.weightKg}kg')),
                          DataCell(
                            Text('₩${record.chargeAmount.toStringAsFixed(0)}'),
                          ),
                          DataCell(_StatusPill(statusCode: record.statusCode)),
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

class _OrderEditorPanel extends StatelessWidget {
  const _OrderEditorPanel({
    required this.selectedRecord,
    required this.orderNoController,
    required this.externalOrderController,
    required this.customerController,
    required this.shipperController,
    required this.billToController,
    required this.pickupNameController,
    required this.pickupAddressController,
    required this.pickupStartController,
    required this.pickupEndController,
    required this.deliveryNameController,
    required this.deliveryAddressController,
    required this.deliveryStartController,
    required this.deliveryEndController,
    required this.itemController,
    required this.quantityController,
    required this.packageController,
    required this.weightController,
    required this.volumeController,
    required this.chargeController,
    required this.minTempController,
    required this.maxTempController,
    required this.instructionController,
    required this.partnerOptions,
    required this.selectedType,
    required this.selectedPriority,
    required this.selectedMode,
    required this.selectedService,
    required this.appointmentRequired,
    required this.temperatureControlled,
    required this.hazmatRequired,
    required this.autoPlan,
    required this.onTypeChanged,
    required this.onPriorityChanged,
    required this.onModeChanged,
    required this.onServiceChanged,
    required this.onAppointmentChanged,
    required this.onTemperatureChanged,
    required this.onHazmatChanged,
    required this.onAutoPlanChanged,
    required this.onCustomerPartnerSelected,
    required this.onShipperPartnerSelected,
    required this.onBillToPartnerSelected,
    required this.onRegenerateOrderNo,
    required this.onSave,
  });

  final _OrderRecord? selectedRecord;
  final TextEditingController orderNoController;
  final TextEditingController externalOrderController;
  final TextEditingController customerController;
  final TextEditingController shipperController;
  final TextEditingController billToController;
  final TextEditingController pickupNameController;
  final TextEditingController pickupAddressController;
  final TextEditingController pickupStartController;
  final TextEditingController pickupEndController;
  final TextEditingController deliveryNameController;
  final TextEditingController deliveryAddressController;
  final TextEditingController deliveryStartController;
  final TextEditingController deliveryEndController;
  final TextEditingController itemController;
  final TextEditingController quantityController;
  final TextEditingController packageController;
  final TextEditingController weightController;
  final TextEditingController volumeController;
  final TextEditingController chargeController;
  final TextEditingController minTempController;
  final TextEditingController maxTempController;
  final TextEditingController instructionController;
  final List<BusinessPartnerOption> partnerOptions;
  final _OrderType selectedType;
  final _Priority selectedPriority;
  final _TransportMode selectedMode;
  final _ServiceLevel selectedService;
  final bool appointmentRequired;
  final bool temperatureControlled;
  final bool hazmatRequired;
  final bool autoPlan;
  final ValueChanged<_OrderType> onTypeChanged;
  final ValueChanged<_Priority> onPriorityChanged;
  final ValueChanged<_TransportMode> onModeChanged;
  final ValueChanged<_ServiceLevel> onServiceChanged;
  final ValueChanged<bool> onAppointmentChanged;
  final ValueChanged<bool> onTemperatureChanged;
  final ValueChanged<bool> onHazmatChanged;
  final ValueChanged<bool> onAutoPlanChanged;
  final ValueChanged<BusinessPartnerOption> onCustomerPartnerSelected;
  final ValueChanged<BusinessPartnerOption> onShipperPartnerSelected;
  final ValueChanged<BusinessPartnerOption> onBillToPartnerSelected;
  final VoidCallback onRegenerateOrderNo;
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
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              SizedBox(
                width: 420,
                child: _PanelTitle(
                  icon: Icons.add_road_rounded,
                  title: selectedRecord == null ? '신규 오더 등록' : '오더 상세',
                  subtitle:
                      '${selectedRecord?.orderNo ?? '자동 오더번호'} · 접수 후 편성/배차로 연결',
                  compact: true,
                ),
              ),
              SizedBox(
                width: 170,
                child: ElevatedButton.icon(
                  onPressed: onSave,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('오더 저장'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _OrderSummaryStrip(
            orderNo: orderNoController.text,
            customer: customerController.text,
            route:
                '${pickupNameController.text} → ${deliveryNameController.text}',
            weightKg: weightController.text,
            chargeAmount: chargeController.text,
            serviceLevel: selectedService.label,
            statusCode: selectedRecord?.statusCode ?? 'DRAFT',
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1180;
              final firstColumn = Column(
                children: [
                  _FormSectionCard(
                    icon: Icons.assignment_rounded,
                    title: '접수 기본정보',
                    subtitle: '청구 대상과 실제 화물 주체를 먼저 확정합니다.',
                    children: [
                      _EditorGrid(
                        minItemWidth: 240,
                        maxColumns: wide ? 3 : 2,
                        children: [
                          _GeneratedOrderNumberField(
                            controller: orderNoController,
                            locked: selectedRecord != null,
                            onRegenerate: onRegenerateOrderNo,
                          ),
                          _OrderTextField(
                            controller: externalOrderController,
                            label: '외부오더번호',
                            icon: Icons.link_rounded,
                          ),
                          _PartnerLookupField(
                            controller: customerController,
                            label: '고객사',
                            helperText: '매출 청구 기준 고객',
                            icon: Icons.business_rounded,
                            partnerType: 'CUSTOMER',
                            options: partnerOptions,
                            accentColor: AppTheme.teal,
                            onSelected: onCustomerPartnerSelected,
                          ),
                          _PartnerLookupField(
                            controller: shipperController,
                            label: '화주',
                            helperText: '실제 화물/오더 주체',
                            icon: Icons.apartment_rounded,
                            partnerType: 'SHIPPER',
                            options: partnerOptions,
                            accentColor: AppTheme.cyan,
                            onSelected: onShipperPartnerSelected,
                          ),
                          _PartnerLookupField(
                            controller: billToController,
                            label: '청구처',
                            helperText: '거래명세서 발행 대상',
                            icon: Icons.receipt_rounded,
                            partnerType: 'CUSTOMER',
                            options: partnerOptions,
                            accentColor: const Color(0xFF7C3AED),
                            onSelected: onBillToPartnerSelected,
                          ),
                          DropdownButtonFormField<_Priority>(
                            initialValue: selectedPriority,
                            decoration: const InputDecoration(
                              labelText: '우선순위',
                              prefixIcon: Icon(Icons.priority_high_rounded),
                            ),
                            items: _Priority.values
                                .map(
                                  (priority) => DropdownMenuItem(
                                    value: priority,
                                    child: Text(priority.label),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                onPriorityChanged(value);
                              }
                            },
                          ),
                          DropdownButtonFormField<_OrderType>(
                            initialValue: selectedType,
                            decoration: const InputDecoration(
                              labelText: '오더 유형',
                              prefixIcon: Icon(Icons.category_rounded),
                            ),
                            items: _OrderType.values
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
                          DropdownButtonFormField<_TransportMode>(
                            initialValue: selectedMode,
                            decoration: const InputDecoration(
                              labelText: '운송 모드',
                              prefixIcon: Icon(Icons.local_shipping_rounded),
                            ),
                            items: _TransportMode.values
                                .map(
                                  (mode) => DropdownMenuItem(
                                    value: mode,
                                    child: Text(mode.label),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                onModeChanged(value);
                              }
                            },
                          ),
                          DropdownButtonFormField<_ServiceLevel>(
                            initialValue: selectedService,
                            decoration: const InputDecoration(
                              labelText: '운송조건',
                              prefixIcon: Icon(Icons.speed_rounded),
                            ),
                            items: _ServiceLevel.values
                                .map(
                                  (service) => DropdownMenuItem(
                                    value: service,
                                    child: Text(service.label),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                onServiceChanged(value);
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _FormSectionCard(
                    icon: Icons.route_rounded,
                    title: '상차/하차 계획',
                    subtitle: '도착 시간창과 주소를 한 묶음으로 보고 등록합니다.',
                    children: [
                      if (constraints.maxWidth >= 900)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _RouteLegCard(
                                accentColor: AppTheme.teal,
                                icon: Icons.upload_rounded,
                                title: '상차 정보',
                                locationController: pickupNameController,
                                addressController: pickupAddressController,
                                startController: pickupStartController,
                                endController: pickupEndController,
                                locationLabel: '상차지',
                                addressLabel: '상차지 주소',
                                startLabel: '상차 시작',
                                endLabel: '상차 종료',
                              ),
                            ),
                            const _TimelineConnector(),
                            Expanded(
                              child: _RouteLegCard(
                                accentColor: const Color(0xFF2563EB),
                                icon: Icons.download_rounded,
                                title: '하차 정보',
                                locationController: deliveryNameController,
                                addressController: deliveryAddressController,
                                startController: deliveryStartController,
                                endController: deliveryEndController,
                                locationLabel: '하차지',
                                addressLabel: '하차지 주소',
                                startLabel: '하차 시작',
                                endLabel: '하차 종료',
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _RouteLegCard(
                          accentColor: AppTheme.teal,
                          icon: Icons.upload_rounded,
                          title: '상차 정보',
                          locationController: pickupNameController,
                          addressController: pickupAddressController,
                          startController: pickupStartController,
                          endController: pickupEndController,
                          locationLabel: '상차지',
                          addressLabel: '상차지 주소',
                          startLabel: '상차 시작',
                          endLabel: '상차 종료',
                        ),
                        const SizedBox(height: 12),
                        _RouteLegCard(
                          accentColor: const Color(0xFF2563EB),
                          icon: Icons.download_rounded,
                          title: '하차 정보',
                          locationController: deliveryNameController,
                          addressController: deliveryAddressController,
                          startController: deliveryStartController,
                          endController: deliveryEndController,
                          locationLabel: '하차지',
                          addressLabel: '하차지 주소',
                          startLabel: '하차 시작',
                          endLabel: '하차 종료',
                        ),
                      ],
                    ],
                  ),
                ],
              );

              final secondColumn = Column(
                children: [
                  _FormSectionCard(
                    icon: Icons.inventory_2_rounded,
                    title: '품목/수량/운임',
                    subtitle: '편성, 배차, 정산에 필요한 핵심 수치를 함께 입력합니다.',
                    children: [
                      _EditorGrid(
                        minItemWidth: 190,
                        maxColumns: wide ? 3 : 2,
                        children: [
                          _OrderTextField(
                            controller: itemController,
                            label: '품목',
                            icon: Icons.inventory_2_rounded,
                          ),
                          _OrderTextField(
                            controller: quantityController,
                            label: '수량',
                            icon: Icons.numbers_rounded,
                            keyboardType: TextInputType.number,
                          ),
                          _OrderTextField(
                            controller: packageController,
                            label: '포장수',
                            icon: Icons.all_inbox_rounded,
                            keyboardType: TextInputType.number,
                          ),
                          _OrderTextField(
                            controller: weightController,
                            label: '중량(kg)',
                            icon: Icons.scale_rounded,
                            keyboardType: TextInputType.number,
                          ),
                          _OrderTextField(
                            controller: volumeController,
                            label: '부피(CBM)',
                            icon: Icons.view_in_ar_rounded,
                            keyboardType: TextInputType.number,
                          ),
                          _OrderTextField(
                            controller: chargeController,
                            label: '청구 운임',
                            icon: Icons.payments_rounded,
                            keyboardType: TextInputType.number,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _FormSectionCard(
                    icon: Icons.tune_rounded,
                    title: '운송 조건',
                    subtitle: '편성 가능 여부와 실행 제약조건을 즉시 판단합니다.',
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _ConditionToggle(
                            label: '예약 필수',
                            value: appointmentRequired,
                            onChanged: onAppointmentChanged,
                            icon: Icons.event_note_rounded,
                          ),
                          _ConditionToggle(
                            label: '온도관리',
                            value: temperatureControlled,
                            onChanged: onTemperatureChanged,
                            icon: Icons.ac_unit_rounded,
                          ),
                          _ConditionToggle(
                            label: '위험물',
                            value: hazmatRequired,
                            onChanged: onHazmatChanged,
                            icon: Icons.warning_amber_rounded,
                          ),
                          _ConditionToggle(
                            label: '자동 편성 대상',
                            value: autoPlan,
                            onChanged: onAutoPlanChanged,
                            icon: Icons.auto_awesome_rounded,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _EditorGrid(
                        minItemWidth: 190,
                        maxColumns: 2,
                        children: [
                          _OrderTextField(
                            controller: minTempController,
                            label: '최저 온도(C)',
                            icon: Icons.thermostat_rounded,
                            keyboardType: const TextInputType.numberWithOptions(
                              signed: true,
                              decimal: true,
                            ),
                          ),
                          _OrderTextField(
                            controller: maxTempController,
                            label: '최고 온도(C)',
                            icon: Icons.device_thermostat_rounded,
                            keyboardType: const TextInputType.numberWithOptions(
                              signed: true,
                              decimal: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: instructionController,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: '특이사항',
                          prefixIcon: Icon(Icons.edit_note_rounded),
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ),
                ],
              );

              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: firstColumn),
                    const SizedBox(width: 14),
                    Expanded(flex: 5, child: secondColumn),
                  ],
                );
              }

              return Column(
                children: [
                  firstColumn,
                  const SizedBox(height: 14),
                  secondColumn,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _OrderSummaryStrip extends StatelessWidget {
  const _OrderSummaryStrip({
    required this.orderNo,
    required this.customer,
    required this.route,
    required this.weightKg,
    required this.chargeAmount,
    required this.serviceLevel,
    required this.statusCode,
  });

  final String orderNo;
  final String customer;
  final String route;
  final String weightKg;
  final String chargeAmount;
  final String serviceLevel;
  final String statusCode;

  String _textOrFallback(String value, String fallback) {
    final normalized = value.trim();
    return normalized.isEmpty || normalized == '→' ? fallback : normalized;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.line),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final metrics = [
            _SummaryMetric(
              icon: Icons.confirmation_number_rounded,
              label: '오더',
              value: _textOrFallback(orderNo, '신규 오더'),
              color: AppTheme.teal,
            ),
            _SummaryMetric(
              icon: Icons.business_center_rounded,
              label: '고객사',
              value: _textOrFallback(customer, '고객사 미입력'),
              color: const Color(0xFF2563EB),
            ),
            _SummaryMetric(
              icon: Icons.alt_route_rounded,
              label: '운송 구간',
              value: _textOrFallback(route, '상차지 → 하차지'),
              color: AppTheme.amber,
            ),
            _SummaryMetric(
              icon: Icons.scale_rounded,
              label: '중량/조건',
              value: '${_textOrFallback(weightKg, '0')}kg · $serviceLevel',
              color: const Color(0xFF7C3AED),
            ),
            _SummaryMetric(
              icon: Icons.payments_rounded,
              label: '청구 운임',
              value: '₩${_textOrFallback(chargeAmount, '0')}',
              color: const Color(0xFF16A34A),
            ),
          ];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _StatusPill(statusCode: statusCode),
                  const Text(
                    '접수 정보가 저장되면 편성, 배정, 배차 계획의 기준 오더가 됩니다.',
                    style: TextStyle(
                      color: AppTheme.slate,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: metrics
                    .map(
                      (metric) => SizedBox(
                        width: compact
                            ? constraints.maxWidth
                            : (constraints.maxWidth - 40) / 5,
                        child: metric,
                      ),
                    )
                    .toList(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 74,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.line),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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

class _FormSectionCard extends StatelessWidget {
  const _FormSectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFE),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppTheme.teal.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppTheme.teal, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppTheme.graphite,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 2,
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
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _RouteLegCard extends StatelessWidget {
  const _RouteLegCard({
    required this.accentColor,
    required this.icon,
    required this.title,
    required this.locationController,
    required this.addressController,
    required this.startController,
    required this.endController,
    required this.locationLabel,
    required this.addressLabel,
    required this.startLabel,
    required this.endLabel,
  });

  final Color accentColor;
  final IconData icon;
  final String title;
  final TextEditingController locationController;
  final TextEditingController addressController;
  final TextEditingController startController;
  final TextEditingController endController;
  final String locationLabel;
  final String addressLabel;
  final String startLabel;
  final String endLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accentColor.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accentColor, size: 18),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.graphite,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _OrderTextField(
            controller: locationController,
            label: locationLabel,
            icon: Icons.warehouse_rounded,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: addressController,
            decoration: InputDecoration(
              labelText: addressLabel,
              prefixIcon: const Icon(Icons.pin_drop_rounded),
            ),
          ),
          const SizedBox(height: 10),
          _EditorGrid(
            minItemWidth: 190,
            maxColumns: 2,
            children: [
              _OrderDateTimeField(
                controller: startController,
                label: startLabel,
                icon: Icons.event_available_rounded,
                accentColor: accentColor,
              ),
              _OrderDateTimeField(
                controller: endController,
                label: endLabel,
                icon: Icons.event_busy_rounded,
                accentColor: accentColor,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimelineConnector extends StatelessWidget {
  const _TimelineConnector();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 250,
      child: Column(
        children: [
          const SizedBox(height: 42),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppTheme.panel,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.line),
            ),
            child: const Icon(
              Icons.arrow_forward_rounded,
              color: AppTheme.teal,
              size: 18,
            ),
          ),
          Expanded(
            child: Center(child: Container(width: 1.4, color: AppTheme.line)),
          ),
        ],
      ),
    );
  }
}

class _ConditionToggle extends StatelessWidget {
  const _ConditionToggle({
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
    final color = value ? AppTheme.teal : AppTheme.slate;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 185,
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: value ? AppTheme.teal.withValues(alpha: 0.09) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: value
                  ? AppTheme.teal.withValues(alpha: 0.38)
                  : AppTheme.line,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.graphite,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditorGrid extends StatelessWidget {
  const _EditorGrid({
    required this.children,
    this.minItemWidth = 260,
    this.maxColumns = 2,
  });

  final List<Widget> children;
  final double minItemWidth;
  final int maxColumns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final estimatedColumns = (constraints.maxWidth / minItemWidth).floor();
        final columns = estimatedColumns.clamp(1, maxColumns).toInt();
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

class _PartnerLookupField extends StatefulWidget {
  const _PartnerLookupField({
    required this.controller,
    required this.label,
    required this.helperText,
    required this.icon,
    required this.partnerType,
    required this.options,
    required this.accentColor,
    required this.onSelected,
  });

  final TextEditingController controller;
  final String label;
  final String helperText;
  final IconData icon;
  final String partnerType;
  final List<BusinessPartnerOption> options;
  final Color accentColor;
  final ValueChanged<BusinessPartnerOption> onSelected;

  @override
  State<_PartnerLookupField> createState() => _PartnerLookupFieldState();
}

class _PartnerLookupFieldState extends State<_PartnerLookupField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Iterable<BusinessPartnerOption> _filteredOptions(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    final typedOptions = widget.options.where(
      (option) => option.partnerType == widget.partnerType,
    );
    if (normalizedQuery.isEmpty) {
      return typedOptions.take(8);
    }

    return typedOptions
        .where((option) {
          return option.partnerCode.toLowerCase().contains(normalizedQuery) ||
              option.partnerName.toLowerCase().contains(normalizedQuery) ||
              option.partnerShortName.toLowerCase().contains(normalizedQuery) ||
              (option.phone ?? '').toLowerCase().contains(normalizedQuery);
        })
        .take(8);
  }

  BusinessPartnerOption _manualOption(String value) {
    final name = value.trim();
    return BusinessPartnerOption(
      id: 0,
      partnerCode: '',
      partnerName: name,
      partnerShortName: name,
      partnerType: widget.partnerType,
      status: 'NEW',
      isActive: true,
    );
  }

  void _applySelection(BusinessPartnerOption option) {
    widget.controller.text = option.partnerName;
    widget.onSelected(option);
  }

  Future<void> _openPicker() async {
    final searchController = TextEditingController(
      text: widget.controller.text,
    );
    final selected = await showModalBottomSheet<BusinessPartnerOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        var query = searchController.text;
        return StatefulBuilder(
          builder: (context, setModalState) {
            final items = _filteredOptions(query).take(40).toList();
            final manualText = searchController.text.trim();
            return SafeArea(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.74,
                ),
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.line),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x260F172A),
                      blurRadius: 30,
                      offset: Offset(0, 18),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: widget.accentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            widget.icon,
                            color: widget.accentColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${widget.label} 마스터 선택',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: AppTheme.graphite,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0,
                                    ),
                              ),
                              Text(
                                widget.helperText,
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
                        IconButton(
                          tooltip: '닫기',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: searchController,
                      autofocus: true,
                      onChanged: (value) => setModalState(() => query = value),
                      decoration: InputDecoration(
                        labelText: '${widget.label} 검색',
                        hintText: '거래처명, 코드, 약칭, 전화번호',
                        prefixIcon: const Icon(Icons.search_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (manualText.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () =>
                            Navigator.pop(context, _manualOption(manualText)),
                        icon: const Icon(Icons.add_business_rounded),
                        label: Text('"$manualText" 신규 입력값으로 사용'),
                      ),
                    if (manualText.isNotEmpty) const SizedBox(height: 10),
                    Expanded(
                      child: items.isEmpty
                          ? const _PartnerEmptyPickerState()
                          : ListView.separated(
                              itemCount: items.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final option = items[index];
                                return _PartnerOptionTile(
                                  option: option,
                                  accentColor: widget.accentColor,
                                  onTap: () => Navigator.pop(context, option),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    searchController.dispose();
    if (selected != null) {
      _applySelection(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<BusinessPartnerOption>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      displayStringForOption: (option) => option.partnerName,
      optionsBuilder: (textEditingValue) {
        return _filteredOptions(textEditingValue.text);
      },
      onSelected: _applySelection,
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
            return TextField(
              controller: textEditingController,
              focusNode: focusNode,
              decoration: InputDecoration(
                labelText: widget.label,
                helperText: widget.helperText,
                prefixIcon: Icon(widget.icon),
                suffixIcon: IconButton(
                  tooltip: '${widget.label} 마스터 선택',
                  icon: Icon(
                    Icons.manage_search_rounded,
                    color: widget.accentColor,
                  ),
                  onPressed: _openPicker,
                ),
              ),
            );
          },
      optionsViewBuilder: (context, onSelected, options) {
        final optionList = options.toList();
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 14,
            shadowColor: const Color(0x260F172A),
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460, maxHeight: 330),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.line),
                ),
                child: ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemCount: optionList.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final option = optionList[index];
                    return _PartnerOptionTile(
                      option: option,
                      accentColor: widget.accentColor,
                      compact: true,
                      onTap: () => onSelected(option),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PartnerOptionTile extends StatelessWidget {
  const _PartnerOptionTile({
    required this.option,
    required this.accentColor,
    required this.onTap,
    this.compact = false,
  });

  final BusinessPartnerOption option;
  final Color accentColor;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.all(compact ? 10 : 12),
          decoration: BoxDecoration(
            color: compact
                ? Colors.white
                : accentColor.withValues(alpha: 0.045),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: compact
                  ? AppTheme.line
                  : accentColor.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 34 : 40,
                height: compact ? 34 : 40,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    option.partnerShortName.isNotEmpty
                        ? option.partnerShortName.characters.first
                        : option.partnerName.characters.first,
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          option.partnerShortName.isEmpty
                              ? option.partnerName
                              : option.partnerShortName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppTheme.graphite,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0,
                              ),
                        ),
                        _PartnerTypePill(
                          label: option.typeLabel,
                          color: accentColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (option.partnerCode.isNotEmpty) option.partnerCode,
                        option.partnerName,
                        if ((option.paymentTerms ?? '').isNotEmpty)
                          option.paymentTerms!,
                      ].join(' · '),
                      maxLines: compact ? 1 : 2,
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
              const SizedBox(width: 8),
              Icon(
                Icons.check_circle_outline_rounded,
                color: accentColor,
                size: compact ? 18 : 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PartnerTypePill extends StatelessWidget {
  const _PartnerTypePill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _PartnerEmptyPickerState extends StatelessWidget {
  const _PartnerEmptyPickerState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '조건에 맞는 거래처 마스터가 없습니다.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppTheme.slate,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _OrderTextField extends StatelessWidget {
  const _OrderTextField({
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

class _GeneratedOrderNumberField extends StatelessWidget {
  const _GeneratedOrderNumberField({
    required this.controller,
    required this.locked,
    required this.onRegenerate,
  });

  final TextEditingController controller;
  final bool locked;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      readOnly: true,
      showCursor: false,
      enableInteractiveSelection: true,
      style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0),
      decoration: InputDecoration(
        labelText: '오더번호',
        helperText: locked ? '저장된 시스템 번호' : '시스템 자동발급',
        prefixIcon: const Icon(Icons.confirmation_number_rounded),
        suffixIcon: locked
            ? const Tooltip(
                message: '수정 불가',
                child: Icon(Icons.lock_rounded, color: AppTheme.slate),
              )
            : Tooltip(
                message: '새 번호 발급',
                child: IconButton(
                  onPressed: onRegenerate,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ),
      ),
    );
  }
}

class _OrderDateTimeField extends StatelessWidget {
  const _OrderDateTimeField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.accentColor,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final Color accentColor;

  DateTime? _parseDateTime(String value) {
    final match = RegExp(
      r'^(\d{4})-(\d{1,2})-(\d{1,2})(?:[ T](\d{1,2}):(\d{1,2}))?',
    ).firstMatch(value.trim());
    if (match == null) {
      return null;
    }

    try {
      return DateTime(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
        int.parse(match.group(4) ?? '9'),
        int.parse(match.group(5) ?? '0'),
      );
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  String _formatDateTime(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}';
  }

  Future<void> _pickDateTime(BuildContext context) async {
    final now = DateTime.now();
    final initialValue = _parseDateTime(controller.text) ?? now;
    final colorScheme = Theme.of(
      context,
    ).colorScheme.copyWith(primary: accentColor, secondary: AppTheme.cyan);

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialValue,
      firstDate: DateTime(now.year - 3, 1, 1),
      lastDate: DateTime(now.year + 5, 12, 31),
      helpText: '$label 날짜 선택',
      cancelText: '취소',
      confirmText: '시간 선택',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(colorScheme: colorScheme),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (pickedDate == null || !context.mounted) {
      return;
    }

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialValue),
      helpText: '$label 시간 선택',
      cancelText: '취소',
      confirmText: '적용',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(colorScheme: colorScheme),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (pickedTime == null) {
      return;
    }

    controller.text = _formatDateTime(
      DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      readOnly: true,
      onTap: () => _pickDateTime(context),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: IconButton(
          tooltip: '$label 선택',
          icon: Icon(Icons.calendar_month_rounded, color: accentColor),
          onPressed: () => _pickDateTime(context),
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

class _OrderMetricCard extends StatelessWidget {
  const _OrderMetricCard({required this.metric});

  final _OrderMetric metric;

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
  const _StatusPill({required this.statusCode});

  final String statusCode;

  @override
  Widget build(BuildContext context) {
    final color = switch (statusCode) {
      'DRAFT' => AppTheme.slate,
      'CONFIRMED' => AppTheme.teal,
      'PLANNED' => const Color(0xFF2563EB),
      'DISPATCHED' => const Color(0xFF7C3AED),
      _ => AppTheme.amber,
    };
    final label = switch (statusCode) {
      'DRAFT' => '임시',
      'CONFIRMED' => '확정',
      'PLANNED' => '계획',
      'DISPATCHED' => '배차',
      _ => statusCode,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
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
        '조회된 운송오더가 없습니다.',
        style: TextStyle(color: AppTheme.slate, letterSpacing: 0),
      ),
    );
  }
}

enum _OrderType {
  standard,
  returnOrder,
  transfer,
  expedited,
  consolidation;

  String get code => switch (this) {
    _OrderType.standard => 'STANDARD',
    _OrderType.returnOrder => 'RETURN',
    _OrderType.transfer => 'TRANSFER',
    _OrderType.expedited => 'EXPEDITED',
    _OrderType.consolidation => 'CONSOLIDATION',
  };

  String get label => switch (this) {
    _OrderType.standard => '일반',
    _OrderType.returnOrder => '반품',
    _OrderType.transfer => '이동',
    _OrderType.expedited => '긴급',
    _OrderType.consolidation => '합적',
  };
}

enum _Priority {
  low,
  normal,
  high,
  urgent;

  String get code => switch (this) {
    _Priority.low => 'LOW',
    _Priority.normal => 'NORMAL',
    _Priority.high => 'HIGH',
    _Priority.urgent => 'URGENT',
  };

  String get label => switch (this) {
    _Priority.low => '낮음',
    _Priority.normal => '보통',
    _Priority.high => '높음',
    _Priority.urgent => '긴급',
  };
}

enum _TransportMode {
  road,
  parcel,
  air,
  sea;

  String get code => switch (this) {
    _TransportMode.road => 'ROAD',
    _TransportMode.parcel => 'PARCEL',
    _TransportMode.air => 'AIR',
    _TransportMode.sea => 'SEA',
  };

  String get label => switch (this) {
    _TransportMode.road => '육상',
    _TransportMode.parcel => '택배',
    _TransportMode.air => '항공',
    _TransportMode.sea => '해상',
  };
}

enum _ServiceLevel {
  standard,
  sameDay,
  nextDay,
  coldChain;

  String get code => switch (this) {
    _ServiceLevel.standard => 'STANDARD',
    _ServiceLevel.sameDay => 'SAME_DAY',
    _ServiceLevel.nextDay => 'NEXT_DAY',
    _ServiceLevel.coldChain => 'COLD_CHAIN',
  };

  String get label => switch (this) {
    _ServiceLevel.standard => '표준',
    _ServiceLevel.sameDay => '당일',
    _ServiceLevel.nextDay => '익일',
    _ServiceLevel.coldChain => '콜드체인',
  };
}

class _OrderRecord {
  const _OrderRecord({
    required this.id,
    required this.orderNo,
    required this.externalOrderNo,
    required this.customerName,
    required this.shipperName,
    required this.billToName,
    required this.pickupName,
    required this.pickupAddress,
    required this.pickupStart,
    required this.pickupEnd,
    required this.deliveryName,
    required this.deliveryAddress,
    required this.deliveryStart,
    required this.deliveryEnd,
    required this.itemName,
    required this.quantity,
    required this.packages,
    required this.weightKg,
    required this.volumeCbm,
    required this.chargeAmount,
    required this.orderType,
    required this.priority,
    required this.mode,
    required this.serviceLevel,
    required this.statusCode,
    required this.appointmentRequired,
    required this.temperatureControlled,
    required this.minTemperatureC,
    required this.maxTemperatureC,
    required this.hazmatRequired,
    required this.autoPlan,
    required this.instructions,
  });

  final int id;
  final String orderNo;
  final String externalOrderNo;
  final String customerName;
  final String shipperName;
  final String billToName;
  final String pickupName;
  final String pickupAddress;
  final String pickupStart;
  final String pickupEnd;
  final String deliveryName;
  final String deliveryAddress;
  final String deliveryStart;
  final String deliveryEnd;
  final String itemName;
  final double quantity;
  final int packages;
  final double weightKg;
  final double volumeCbm;
  final double chargeAmount;
  final _OrderType orderType;
  final _Priority priority;
  final _TransportMode mode;
  final _ServiceLevel serviceLevel;
  final String statusCode;
  final bool appointmentRequired;
  final bool temperatureControlled;
  final String minTemperatureC;
  final String maxTemperatureC;
  final bool hazmatRequired;
  final bool autoPlan;
  final String instructions;

  Map<String, Object?> toApiPayload() {
    return {
      'order_no': orderNo,
      'external_order_no': externalOrderNo,
      'customer_name': customerName,
      'shipper_name': shipperName,
      'bill_to_name': billToName,
      'pickup_name': pickupName,
      'pickup_address': pickupAddress,
      'pickup_contact_name': '',
      'pickup_contact_phone': '',
      'requested_pickup_start': pickupStart,
      'requested_pickup_end': pickupEnd,
      'delivery_name': deliveryName,
      'delivery_address': deliveryAddress,
      'delivery_contact_name': '',
      'delivery_contact_phone': '',
      'requested_delivery_start': deliveryStart,
      'requested_delivery_end': deliveryEnd,
      'order_type': orderType.code,
      'order_status': statusCode,
      'priority_code': priority.code,
      'transport_mode_code': mode.code,
      'transport_mode_name': mode.label,
      'service_level_code': serviceLevel.code,
      'service_level_name': serviceLevel.label,
      'total_quantity': quantity,
      'total_packages': packages,
      'total_weight_kg': weightKg,
      'total_volume_cbm': volumeCbm,
      'charge_amount': chargeAmount,
      'currency_code': 'KRW',
      'incoterm_code': '',
      'temperature_min_c': minTemperatureC,
      'temperature_max_c': maxTemperatureC,
      'hazmat_required': hazmatRequired,
      'appointment_required': appointmentRequired,
      'special_instructions': instructions,
      'lines': [
        {
          'line_no': 1,
          'item_description': itemName,
          'quantity': quantity,
          'uom_code': 'EA',
          'package_count': packages,
          'gross_weight_kg': weightKg,
          'volume_cbm': volumeCbm,
          'temperature_min_c': minTemperatureC,
          'temperature_max_c': maxTemperatureC,
          'hazmat_class': hazmatRequired ? 'GENERAL_HAZMAT' : '',
        },
      ],
      'metadata': {
        'auto_plan': autoPlan,
        'shipper_name': shipperName,
        'bill_to_name': billToName,
        'pickup_name': pickupName,
        'pickup_address': pickupAddress,
        'delivery_name': deliveryName,
        'delivery_address': deliveryAddress,
        'item_name': itemName,
        'service_level_name': serviceLevel.label,
        'transport_mode_name': mode.label,
      },
    };
  }
}

class _OrderMetric {
  const _OrderMetric({
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

const _fallbackPartnerOptions = [
  BusinessPartnerOption(
    id: 1,
    partnerCode: 'CUST0001',
    partnerName: '삼성전자 주식회사',
    partnerShortName: '삼성전자',
    partnerType: 'CUSTOMER',
    status: 'ACTIVE',
    isActive: true,
    paymentTerms: '월말 +30일',
    phone: '02-2255-0114',
    email: 'logistics@samsung.example',
  ),
  BusinessPartnerOption(
    id: 2,
    partnerCode: 'CUST0002',
    partnerName: '이마트 주식회사',
    partnerShortName: '이마트',
    partnerType: 'CUSTOMER',
    status: 'ACTIVE',
    isActive: true,
    paymentTerms: '월말 +45일',
    phone: '02-380-5678',
    email: 'transport@emart.example',
  ),
  BusinessPartnerOption(
    id: 3,
    partnerCode: 'SHIP0001',
    partnerName: '삼성전자 물류센터',
    partnerShortName: '삼성전자 물류',
    partnerType: 'SHIPPER',
    status: 'ACTIVE',
    isActive: true,
    paymentTerms: '고객사 청구',
    phone: '031-200-1000',
    email: 'shipper.se@samsung.example',
  ),
  BusinessPartnerOption(
    id: 4,
    partnerCode: 'SHIP0002',
    partnerName: '신세계푸드 평택센터',
    partnerShortName: '신세계푸드',
    partnerType: 'SHIPPER',
    status: 'ACTIVE',
    isActive: true,
    paymentTerms: '월말 +30일',
    phone: '031-650-4100',
    email: 'dispatch@ssgfood.example',
  ),
];

const _seedOrders = [
  _OrderRecord(
    id: 1,
    orderNo: 'KT-20260615-0001',
    externalOrderNo: 'SO-882103',
    customerName: '삼성전자',
    shipperName: '삼성전자 수원사업장',
    billToName: '삼성전자',
    pickupName: '수원 CDC',
    pickupAddress: '경기 수원시 영통구 삼성로 129',
    pickupStart: '2026-06-15 09:00',
    pickupEnd: '2026-06-15 11:00',
    deliveryName: '부산 RDC',
    deliveryAddress: '부산 강서구 녹산산단',
    deliveryStart: '2026-06-15 18:00',
    deliveryEnd: '2026-06-15 22:00',
    itemName: 'OLED TV 65인치',
    quantity: 42,
    packages: 42,
    weightKg: 1197,
    volumeCbm: 20.1,
    chargeAmount: 1280000,
    orderType: _OrderType.standard,
    priority: _Priority.high,
    mode: _TransportMode.road,
    serviceLevel: _ServiceLevel.nextDay,
    statusCode: 'DRAFT',
    appointmentRequired: true,
    temperatureControlled: false,
    minTemperatureC: '',
    maxTemperatureC: '',
    hazmatRequired: false,
    autoPlan: true,
    instructions: '파손주의. 상차 전 외관 사진 필요.',
  ),
  _OrderRecord(
    id: 2,
    orderNo: 'KT-20260615-0002',
    externalOrderNo: 'FOOD-20260615-18',
    customerName: '프레시온',
    shipperName: '프레시온 김포센터',
    billToName: '프레시온',
    pickupName: '김포 콜드체인 센터',
    pickupAddress: '경기 김포시 고촌읍',
    pickupStart: '2026-06-15 06:00',
    pickupEnd: '2026-06-15 08:00',
    deliveryName: '서울 동부 배송센터',
    deliveryAddress: '서울 송파구 장지동',
    deliveryStart: '2026-06-15 10:00',
    deliveryEnd: '2026-06-15 13:00',
    itemName: '냉장 밀키트 박스',
    quantity: 320,
    packages: 320,
    weightKg: 1344,
    volumeCbm: 10.2,
    chargeAmount: 740000,
    orderType: _OrderType.standard,
    priority: _Priority.urgent,
    mode: _TransportMode.road,
    serviceLevel: _ServiceLevel.coldChain,
    statusCode: 'CONFIRMED',
    appointmentRequired: true,
    temperatureControlled: true,
    minTemperatureC: '2',
    maxTemperatureC: '8',
    hazmatRequired: false,
    autoPlan: true,
    instructions: '온도 로그 POD 첨부 필수.',
  ),
  _OrderRecord(
    id: 3,
    orderNo: 'KT-20260615-0003',
    externalOrderNo: 'RTN-55092',
    customerName: 'K패션',
    shipperName: 'K패션 온라인몰',
    billToName: 'K패션',
    pickupName: '인천 반품센터',
    pickupAddress: '인천 서구 오류동',
    pickupStart: '2026-06-15 13:00',
    pickupEnd: '2026-06-15 15:00',
    deliveryName: '이천 물류센터',
    deliveryAddress: '경기 이천시 마장면',
    deliveryStart: '2026-06-15 17:00',
    deliveryEnd: '2026-06-15 20:00',
    itemName: '시즌 의류 카톤',
    quantity: 86,
    packages: 86,
    weightKg: 825.6,
    volumeCbm: 9.4,
    chargeAmount: 390000,
    orderType: _OrderType.returnOrder,
    priority: _Priority.normal,
    mode: _TransportMode.parcel,
    serviceLevel: _ServiceLevel.standard,
    statusCode: 'PLANNED',
    appointmentRequired: false,
    temperatureControlled: false,
    minTemperatureC: '',
    maxTemperatureC: '',
    hazmatRequired: false,
    autoPlan: false,
    instructions: '반품 박스 파손 여부 확인.',
  ),
];
