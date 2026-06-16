import 'package:flutter/material.dart';

import '../../design/app_theme.dart';
import '../../design/numeric_input_formatters.dart';
import 'master_api.dart';

class ItemMasterPage extends StatefulWidget {
  const ItemMasterPage({super.key, this.compact = false});

  final bool compact;

  @override
  State<ItemMasterPage> createState() => _ItemMasterPageState();
}

class _ItemMasterPageState extends State<ItemMasterPage> {
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _uomController = TextEditingController();
  final _skuController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _hsCodeController = TextEditingController();
  final _nmfcCodeController = TextEditingController();
  final _weightController = TextEditingController();
  final _volumeController = TextEditingController();
  final _lengthController = TextEditingController();
  final _widthController = TextEditingController();
  final _heightController = TextEditingController();
  final _minTempController = TextEditingController();
  final _maxTempController = TextEditingController();
  final _hazardClassController = TextEditingController();
  final _shelfLifeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _memoController = TextEditingController();

  late final List<_ItemRecord> _records;
  _ItemKind? _kindFilter;
  _ItemKind _selectedKind = _ItemKind.general;
  String _statusFilter = 'ALL';
  String _query = '';
  int? _selectedId;
  bool _isActive = true;
  bool _hazardous = false;
  bool _temperatureControlled = false;
  bool _fragile = false;
  bool _stackable = true;
  bool _lotControlled = false;

  @override
  void initState() {
    super.initState();
    _records = List<_ItemRecord>.from(_seedItems);
    _selectRecord(_records.first, notify: false);
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _categoryController.dispose();
    _uomController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _hsCodeController.dispose();
    _nmfcCodeController.dispose();
    _weightController.dispose();
    _volumeController.dispose();
    _lengthController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _minTempController.dispose();
    _maxTempController.dispose();
    _hazardClassController.dispose();
    _shelfLifeController.dispose();
    _descriptionController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  List<_ItemRecord> get _filteredRecords {
    final normalizedQuery = _query.trim().toLowerCase();
    return _records.where((record) {
      final matchesKind = _kindFilter == null || record.kind == _kindFilter;
      final matchesStatus =
          _statusFilter == 'ALL' || record.statusCode == _statusFilter;
      final matchesQuery =
          normalizedQuery.isEmpty ||
          record.itemCode.toLowerCase().contains(normalizedQuery) ||
          record.itemName.toLowerCase().contains(normalizedQuery) ||
          record.categoryName.toLowerCase().contains(normalizedQuery) ||
          record.sku.toLowerCase().contains(normalizedQuery) ||
          record.barcode.toLowerCase().contains(normalizedQuery) ||
          record.hsCode.toLowerCase().contains(normalizedQuery);
      return matchesKind && matchesStatus && matchesQuery;
    }).toList();
  }

  _ItemRecord? get _selectedRecord {
    for (final record in _records) {
      if (record.id == _selectedId) {
        return record;
      }
    }
    return null;
  }

  void _selectRecord(_ItemRecord record, {bool notify = true}) {
    void apply() {
      _selectedId = record.id;
      _selectedKind = record.kind;
      _codeController.text = record.itemCode;
      _nameController.text = record.itemName;
      _categoryController.text = record.categoryName;
      _uomController.text = record.baseUomCode;
      _skuController.text = record.sku;
      _barcodeController.text = record.barcode;
      _hsCodeController.text = record.hsCode;
      _nmfcCodeController.text = record.nmfcCode;
      _weightController.text = record.unitWeightKg.toString();
      _volumeController.text = record.unitVolumeCbm.toString();
      _lengthController.text = record.lengthCm.toString();
      _widthController.text = record.widthCm.toString();
      _heightController.text = record.heightCm.toString();
      _minTempController.text = record.minTemperatureC;
      _maxTempController.text = record.maxTemperatureC;
      _hazardClassController.text = record.hazardousClass;
      _shelfLifeController.text = record.shelfLifeDays.toString();
      _descriptionController.text = record.description;
      _memoController.text = record.memo;
      _isActive = record.isActive;
      _hazardous = record.hazardous;
      _temperatureControlled = record.temperatureControlled;
      _fragile = record.fragile;
      _stackable = record.stackable;
      _lotControlled = record.lotControlled;
    }

    if (notify) {
      setState(apply);
    } else {
      apply();
    }
  }

  void _clearEditor() {
    _selectedId = null;
    _selectedKind = _kindFilter ?? _ItemKind.general;
    _codeController.text = _nextCode(_selectedKind);
    _nameController.clear();
    _categoryController.text = _selectedKind.categoryName;
    _uomController.text = 'EA';
    _skuController.clear();
    _barcodeController.clear();
    _hsCodeController.clear();
    _nmfcCodeController.clear();
    _weightController.text = '1.0';
    _volumeController.text = '0.01';
    _lengthController.text = '10';
    _widthController.text = '10';
    _heightController.text = '10';
    _minTempController.clear();
    _maxTempController.clear();
    _hazardClassController.clear();
    _shelfLifeController.text = '0';
    _descriptionController.clear();
    _memoController.clear();
    _isActive = true;
    _hazardous = false;
    _temperatureControlled =
        _selectedKind == _ItemKind.coldChain ||
        _selectedKind == _ItemKind.fresh;
    _fragile = _selectedKind == _ItemKind.electronics;
    _stackable = true;
    _lotControlled =
        _selectedKind == _ItemKind.fresh ||
        _selectedKind == _ItemKind.coldChain ||
        _selectedKind == _ItemKind.hazardous;
  }

  String _nextCode(_ItemKind kind) {
    final count = _records.where((record) => record.kind == kind).length + 1;
    return '${kind.prefix}${count.toString().padLeft(4, '0')}';
  }

  void _startCreate() {
    setState(_clearEditor);
  }

  Future<void> _saveRecord() async {
    final itemName = _nameController.text.trim();
    if (itemName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('품목명을 입력하세요.')));
      return;
    }

    final record = _ItemRecord(
      id: _selectedId ?? _nextRecordId(),
      kind: _selectedKind,
      itemCode: _codeController.text.trim(),
      itemName: itemName,
      categoryName: _categoryController.text.trim(),
      baseUomCode: _uomController.text.trim(),
      sku: _skuController.text.trim(),
      barcode: _barcodeController.text.trim(),
      hsCode: _hsCodeController.text.trim(),
      nmfcCode: _nmfcCodeController.text.trim(),
      hazardous: _hazardous,
      hazardousClass: _hazardClassController.text.trim(),
      temperatureControlled: _temperatureControlled,
      minTemperatureC: _minTempController.text.trim(),
      maxTemperatureC: _maxTempController.text.trim(),
      unitWeightKg: double.tryParse(_weightController.text.trim()) ?? 0,
      unitVolumeCbm: double.tryParse(_volumeController.text.trim()) ?? 0,
      lengthCm: double.tryParse(_lengthController.text.trim()) ?? 0,
      widthCm: double.tryParse(_widthController.text.trim()) ?? 0,
      heightCm: double.tryParse(_heightController.text.trim()) ?? 0,
      shelfLifeDays: int.tryParse(_shelfLifeController.text.trim()) ?? 0,
      fragile: _fragile,
      stackable: _stackable,
      lotControlled: _lotControlled,
      statusCode: _isActive ? 'ACTIVE' : 'INACTIVE',
      isActive: _isActive,
      description: _descriptionController.text.trim(),
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

    final result = await MasterApi.instance.saveItem(record.toApiPayload());
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.failed
              ? '${record.itemName} 품목 화면 반영 완료, DB 저장 실패: ${result.message}'
              : '${record.itemName} 품목 마스터가 반영되었습니다.',
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
              _ItemHeader(onCreate: _startCreate),
              const SizedBox(height: 16),
              _ItemStats(records: _records),
              const SizedBox(height: 16),
              _ItemKindSelector(
                selectedKind: _kindFilter,
                counts: {
                  for (final kind in _ItemKind.values)
                    kind: _records
                        .where((record) => record.kind == kind)
                        .length,
                },
                onSelect: (kind) => setState(() {
                  _kindFilter = _kindFilter == kind ? null : kind;
                  final records = _filteredRecords;
                  if (records.isNotEmpty) {
                    _selectRecord(records.first, notify: false);
                  }
                }),
              ),
              const SizedBox(height: 12),
              _ItemToolbar(
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
                      child: _ItemDirectoryPanel(
                        records: filteredRecords,
                        selectedId: _selectedId,
                        onSelect: _selectRecord,
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 440,
                      child: _ItemEditorPanel(
                        selectedRecord: selectedRecord,
                        codeController: _codeController,
                        nameController: _nameController,
                        categoryController: _categoryController,
                        uomController: _uomController,
                        skuController: _skuController,
                        barcodeController: _barcodeController,
                        hsCodeController: _hsCodeController,
                        nmfcCodeController: _nmfcCodeController,
                        weightController: _weightController,
                        volumeController: _volumeController,
                        lengthController: _lengthController,
                        widthController: _widthController,
                        heightController: _heightController,
                        minTempController: _minTempController,
                        maxTempController: _maxTempController,
                        hazardClassController: _hazardClassController,
                        shelfLifeController: _shelfLifeController,
                        descriptionController: _descriptionController,
                        memoController: _memoController,
                        selectedKind: _selectedKind,
                        isActive: _isActive,
                        hazardous: _hazardous,
                        temperatureControlled: _temperatureControlled,
                        fragile: _fragile,
                        stackable: _stackable,
                        lotControlled: _lotControlled,
                        onKindChanged: (value) {
                          setState(() {
                            _selectedKind = value;
                            _categoryController.text = value.categoryName;
                            if (_selectedId == null) {
                              _codeController.text = _nextCode(value);
                            }
                          });
                        },
                        onActiveChanged: (value) =>
                            setState(() => _isActive = value),
                        onHazardousChanged: (value) =>
                            setState(() => _hazardous = value),
                        onTemperatureChanged: (value) =>
                            setState(() => _temperatureControlled = value),
                        onFragileChanged: (value) =>
                            setState(() => _fragile = value),
                        onStackableChanged: (value) =>
                            setState(() => _stackable = value),
                        onLotChanged: (value) =>
                            setState(() => _lotControlled = value),
                        onSave: _saveRecord,
                      ),
                    ),
                  ],
                )
              else ...[
                _ItemEditorPanel(
                  selectedRecord: selectedRecord,
                  codeController: _codeController,
                  nameController: _nameController,
                  categoryController: _categoryController,
                  uomController: _uomController,
                  skuController: _skuController,
                  barcodeController: _barcodeController,
                  hsCodeController: _hsCodeController,
                  nmfcCodeController: _nmfcCodeController,
                  weightController: _weightController,
                  volumeController: _volumeController,
                  lengthController: _lengthController,
                  widthController: _widthController,
                  heightController: _heightController,
                  minTempController: _minTempController,
                  maxTempController: _maxTempController,
                  hazardClassController: _hazardClassController,
                  shelfLifeController: _shelfLifeController,
                  descriptionController: _descriptionController,
                  memoController: _memoController,
                  selectedKind: _selectedKind,
                  isActive: _isActive,
                  hazardous: _hazardous,
                  temperatureControlled: _temperatureControlled,
                  fragile: _fragile,
                  stackable: _stackable,
                  lotControlled: _lotControlled,
                  onKindChanged: (value) => setState(() {
                    _selectedKind = value;
                    _categoryController.text = value.categoryName;
                    if (_selectedId == null) {
                      _codeController.text = _nextCode(value);
                    }
                  }),
                  onActiveChanged: (value) => setState(() => _isActive = value),
                  onHazardousChanged: (value) =>
                      setState(() => _hazardous = value),
                  onTemperatureChanged: (value) =>
                      setState(() => _temperatureControlled = value),
                  onFragileChanged: (value) => setState(() => _fragile = value),
                  onStackableChanged: (value) =>
                      setState(() => _stackable = value),
                  onLotChanged: (value) =>
                      setState(() => _lotControlled = value),
                  onSave: _saveRecord,
                ),
                const SizedBox(height: 16),
                _ItemDirectoryPanel(
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

class _ItemHeader extends StatelessWidget {
  const _ItemHeader({required this.onCreate});

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
              Icons.inventory_2_rounded,
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
                  '품목 마스터',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.graphite,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '운송 품목의 SKU, 분류, 단위, 규격, 위험물, 온도 조건을 관리합니다.',
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
            label: const Text('품목 등록'),
          ),
        ],
      ),
    );
  }
}

class _ItemStats extends StatelessWidget {
  const _ItemStats({required this.records});

  final List<_ItemRecord> records;

  @override
  Widget build(BuildContext context) {
    final active = records.where((record) => record.isActive).length;
    final cold = records.where((record) => record.temperatureControlled).length;
    final hazardous = records.where((record) => record.hazardous).length;
    final avgWeight = records.isEmpty
        ? 0.0
        : records.fold<double>(0, (sum, record) => sum + record.unitWeightKg) /
              records.length;

    final metrics = [
      _ItemMetric(
        label: '등록 품목',
        value: records.length.toString(),
        icon: Icons.inventory_2_rounded,
        color: AppTheme.teal,
      ),
      _ItemMetric(
        label: '사용 중',
        value: active.toString(),
        icon: Icons.verified_rounded,
        color: const Color(0xFF16A34A),
      ),
      _ItemMetric(
        label: '온도관리',
        value: cold.toString(),
        icon: Icons.ac_unit_rounded,
        color: AppTheme.cyan,
      ),
      _ItemMetric(
        label: '위험물',
        value: hazardous.toString(),
        icon: Icons.warning_amber_rounded,
        color: AppTheme.amber,
      ),
      _ItemMetric(
        label: '평균 중량',
        value: '${avgWeight.toStringAsFixed(1)}kg',
        icon: Icons.scale_rounded,
        color: const Color(0xFF2563EB),
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
              _ItemMetricCard(metric: metrics[index]),
        );
      },
    );
  }
}

class _ItemKindSelector extends StatelessWidget {
  const _ItemKindSelector({
    required this.selectedKind,
    required this.counts,
    required this.onSelect,
  });

  final _ItemKind? selectedKind;
  final Map<_ItemKind, int> counts;
  final ValueChanged<_ItemKind> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _ItemKind.values.map((kind) {
        final selected = selectedKind == kind;
        return ChoiceChip(
          avatar: Icon(
            kind.icon,
            size: 17,
            color: selected ? kind.color : AppTheme.slate,
          ),
          label: Text('${kind.label} ${counts[kind] ?? 0}'),
          selected: selected,
          selectedColor: kind.color.withValues(alpha: 0.12),
          checkmarkColor: kind.color,
          onSelected: (_) => onSelect(kind),
          labelStyle: TextStyle(
            color: selected ? kind.color : AppTheme.slate,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        );
      }).toList(),
    );
  }
}

class _ItemToolbar extends StatelessWidget {
  const _ItemToolbar({
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
                hintText: '품목 코드, 품목명, SKU, 바코드, HS Code',
              ),
            ),
          ),
          ...[
            const MapEntry('ALL', '전체'),
            const MapEntry('ACTIVE', '사용 중'),
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

class _ItemDirectoryPanel extends StatelessWidget {
  const _ItemDirectoryPanel({
    required this.records,
    required this.selectedId,
    required this.onSelect,
  });

  final List<_ItemRecord> records;
  final int? selectedId;
  final ValueChanged<_ItemRecord> onSelect;

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
            icon: Icons.inventory_2_rounded,
            title: '품목 기준정보',
            subtitle: 'items',
          ),
          if (records.isEmpty)
            const _EmptyState()
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AppTheme.panel),
                columns: const [
                  DataColumn(label: Text('품목 코드')),
                  DataColumn(label: Text('품목명')),
                  DataColumn(label: Text('분류')),
                  DataColumn(label: Text('SKU')),
                  DataColumn(label: Text('단위')),
                  DataColumn(label: Text('중량')),
                  DataColumn(label: Text('CBM')),
                  DataColumn(label: Text('운송조건')),
                  DataColumn(label: Text('상태')),
                ],
                rows: records
                    .map(
                      (record) => DataRow(
                        selected: selectedId == record.id,
                        onSelectChanged: (_) => onSelect(record),
                        cells: [
                          DataCell(_StrongText(record.itemCode)),
                          DataCell(Text(record.itemName)),
                          DataCell(_KindPill(kind: record.kind)),
                          DataCell(Text(record.sku)),
                          DataCell(Text(record.baseUomCode)),
                          DataCell(Text('${record.unitWeightKg}kg')),
                          DataCell(Text('${record.unitVolumeCbm}')),
                          DataCell(_ConditionIcons(record: record)),
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

class _ItemEditorPanel extends StatelessWidget {
  const _ItemEditorPanel({
    required this.selectedRecord,
    required this.codeController,
    required this.nameController,
    required this.categoryController,
    required this.uomController,
    required this.skuController,
    required this.barcodeController,
    required this.hsCodeController,
    required this.nmfcCodeController,
    required this.weightController,
    required this.volumeController,
    required this.lengthController,
    required this.widthController,
    required this.heightController,
    required this.minTempController,
    required this.maxTempController,
    required this.hazardClassController,
    required this.shelfLifeController,
    required this.descriptionController,
    required this.memoController,
    required this.selectedKind,
    required this.isActive,
    required this.hazardous,
    required this.temperatureControlled,
    required this.fragile,
    required this.stackable,
    required this.lotControlled,
    required this.onKindChanged,
    required this.onActiveChanged,
    required this.onHazardousChanged,
    required this.onTemperatureChanged,
    required this.onFragileChanged,
    required this.onStackableChanged,
    required this.onLotChanged,
    required this.onSave,
  });

  final _ItemRecord? selectedRecord;
  final TextEditingController codeController;
  final TextEditingController nameController;
  final TextEditingController categoryController;
  final TextEditingController uomController;
  final TextEditingController skuController;
  final TextEditingController barcodeController;
  final TextEditingController hsCodeController;
  final TextEditingController nmfcCodeController;
  final TextEditingController weightController;
  final TextEditingController volumeController;
  final TextEditingController lengthController;
  final TextEditingController widthController;
  final TextEditingController heightController;
  final TextEditingController minTempController;
  final TextEditingController maxTempController;
  final TextEditingController hazardClassController;
  final TextEditingController shelfLifeController;
  final TextEditingController descriptionController;
  final TextEditingController memoController;
  final _ItemKind selectedKind;
  final bool isActive;
  final bool hazardous;
  final bool temperatureControlled;
  final bool fragile;
  final bool stackable;
  final bool lotControlled;
  final ValueChanged<_ItemKind> onKindChanged;
  final ValueChanged<bool> onActiveChanged;
  final ValueChanged<bool> onHazardousChanged;
  final ValueChanged<bool> onTemperatureChanged;
  final ValueChanged<bool> onFragileChanged;
  final ValueChanged<bool> onStackableChanged;
  final ValueChanged<bool> onLotChanged;
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
                  icon: Icons.inventory_rounded,
                  title: selectedRecord == null ? '신규 품목 등록' : '품목 상세',
                  subtitle: selectedRecord?.itemCode ?? 'items',
                  compact: true,
                ),
              ),
              Switch(value: isActive, onChanged: onActiveChanged),
            ],
          ),
          const SizedBox(height: 14),
          _EditorGrid(
            children: [
              _ItemTextField(
                controller: codeController,
                label: '품목 코드',
                icon: Icons.tag_rounded,
              ),
              _ItemTextField(
                controller: nameController,
                label: '품목명',
                icon: Icons.inventory_2_rounded,
              ),
              DropdownButtonFormField<_ItemKind>(
                initialValue: selectedKind,
                decoration: const InputDecoration(
                  labelText: '품목 구분',
                  prefixIcon: Icon(Icons.category_rounded),
                ),
                items: _ItemKind.values
                    .map(
                      (kind) => DropdownMenuItem(
                        value: kind,
                        child: Text(kind.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    onKindChanged(value);
                  }
                },
              ),
              _ItemTextField(
                controller: categoryController,
                label: '품목 분류',
                icon: Icons.account_tree_rounded,
              ),
              _ItemTextField(
                controller: uomController,
                label: '기준 단위',
                icon: Icons.straighten_rounded,
              ),
              _ItemTextField(
                controller: skuController,
                label: 'SKU',
                icon: Icons.qr_code_2_rounded,
              ),
              _ItemTextField(
                controller: barcodeController,
                label: '바코드',
                icon: Icons.document_scanner_rounded,
              ),
              _ItemTextField(
                controller: hsCodeController,
                label: 'HS Code',
                icon: Icons.public_rounded,
              ),
              _ItemTextField(
                controller: nmfcCodeController,
                label: 'NMFC Code',
                icon: Icons.local_shipping_rounded,
              ),
              _ItemTextField(
                controller: weightController,
                label: '단위 중량(kg)',
                icon: Icons.scale_rounded,
                keyboardType: TextInputType.number,
              ),
              _ItemTextField(
                controller: volumeController,
                label: '단위 부피(CBM)',
                icon: Icons.view_in_ar_rounded,
                keyboardType: TextInputType.number,
              ),
              _ItemTextField(
                controller: lengthController,
                label: '길이(cm)',
                icon: Icons.height_rounded,
                keyboardType: TextInputType.number,
              ),
              _ItemTextField(
                controller: widthController,
                label: '폭(cm)',
                icon: Icons.swap_horiz_rounded,
                keyboardType: TextInputType.number,
              ),
              _ItemTextField(
                controller: heightController,
                label: '높이(cm)',
                icon: Icons.vertical_align_top_rounded,
                keyboardType: TextInputType.number,
              ),
              _ItemTextField(
                controller: minTempController,
                label: '최저 온도(C)',
                icon: Icons.thermostat_rounded,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                  decimal: true,
                ),
              ),
              _ItemTextField(
                controller: maxTempController,
                label: '최고 온도(C)',
                icon: Icons.device_thermostat_rounded,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                  decimal: true,
                ),
              ),
              _ItemTextField(
                controller: hazardClassController,
                label: '위험물 등급',
                icon: Icons.warning_amber_rounded,
              ),
              _ItemTextField(
                controller: shelfLifeController,
                label: '유통기한 일수',
                icon: Icons.event_rounded,
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ItemSwitchTile(
            label: '위험물',
            value: hazardous,
            onChanged: onHazardousChanged,
            icon: Icons.warning_amber_rounded,
          ),
          _ItemSwitchTile(
            label: '온도관리',
            value: temperatureControlled,
            onChanged: onTemperatureChanged,
            icon: Icons.ac_unit_rounded,
          ),
          _ItemSwitchTile(
            label: '파손주의',
            value: fragile,
            onChanged: onFragileChanged,
            icon: Icons.new_releases_rounded,
          ),
          _ItemSwitchTile(
            label: '적재 가능',
            value: stackable,
            onChanged: onStackableChanged,
            icon: Icons.layers_rounded,
          ),
          _ItemSwitchTile(
            label: 'LOT 관리',
            value: lotControlled,
            onChanged: onLotChanged,
            icon: Icons.pin_rounded,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: descriptionController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: '품목 설명',
              prefixIcon: Icon(Icons.description_rounded),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 10),
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

class _ItemTextField extends StatelessWidget {
  const _ItemTextField({
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

class _ItemSwitchTile extends StatelessWidget {
  const _ItemSwitchTile({
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

class _ItemMetricCard extends StatelessWidget {
  const _ItemMetricCard({required this.metric});

  final _ItemMetric metric;

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

class _KindPill extends StatelessWidget {
  const _KindPill({required this.kind});

  final _ItemKind kind;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: kind.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        kind.label,
        style: TextStyle(
          color: kind.color,
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

  final _ItemRecord record;

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

class _ConditionIcons extends StatelessWidget {
  const _ConditionIcons({required this.record});

  final _ItemRecord record;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      if (record.temperatureControlled)
        const _TinyCondition(icon: Icons.ac_unit_rounded, label: '온도'),
      if (record.hazardous)
        const _TinyCondition(icon: Icons.warning_amber_rounded, label: '위험'),
      if (record.fragile)
        const _TinyCondition(icon: Icons.new_releases_rounded, label: '파손'),
      if (record.lotControlled)
        const _TinyCondition(icon: Icons.pin_rounded, label: 'LOT'),
    ];
    if (chips.isEmpty) {
      return const Text('일반');
    }
    return Wrap(spacing: 6, runSpacing: 6, children: chips);
  }
}

class _TinyCondition extends StatelessWidget {
  const _TinyCondition({required this.icon, required this.label});

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
        '조회된 품목 기준정보가 없습니다.',
        style: TextStyle(color: AppTheme.slate, letterSpacing: 0),
      ),
    );
  }
}

enum _ItemKind {
  general,
  electronics,
  fresh,
  coldChain,
  hazardous,
  apparel,
  bulk;

  String get code => switch (this) {
    _ItemKind.general => 'GENERAL',
    _ItemKind.electronics => 'ELECTRONICS',
    _ItemKind.fresh => 'FRESH',
    _ItemKind.coldChain => 'COLD_CHAIN',
    _ItemKind.hazardous => 'HAZARDOUS',
    _ItemKind.apparel => 'APPAREL',
    _ItemKind.bulk => 'BULK',
  };

  String get label => switch (this) {
    _ItemKind.general => '일반',
    _ItemKind.electronics => '전자제품',
    _ItemKind.fresh => '신선식품',
    _ItemKind.coldChain => '콜드체인',
    _ItemKind.hazardous => '위험물',
    _ItemKind.apparel => '패션',
    _ItemKind.bulk => '벌크',
  };

  String get categoryName => switch (this) {
    _ItemKind.general => '일반화물',
    _ItemKind.electronics => '전자제품',
    _ItemKind.fresh => '신선식품',
    _ItemKind.coldChain => '냉장냉동',
    _ItemKind.hazardous => '위험물',
    _ItemKind.apparel => '패션잡화',
    _ItemKind.bulk => '벌크화물',
  };

  String get prefix => switch (this) {
    _ItemKind.general => 'ITM',
    _ItemKind.electronics => 'ELE',
    _ItemKind.fresh => 'FRS',
    _ItemKind.coldChain => 'CLD',
    _ItemKind.hazardous => 'HAZ',
    _ItemKind.apparel => 'APP',
    _ItemKind.bulk => 'BLK',
  };

  IconData get icon => switch (this) {
    _ItemKind.general => Icons.inventory_2_rounded,
    _ItemKind.electronics => Icons.devices_rounded,
    _ItemKind.fresh => Icons.eco_rounded,
    _ItemKind.coldChain => Icons.ac_unit_rounded,
    _ItemKind.hazardous => Icons.warning_amber_rounded,
    _ItemKind.apparel => Icons.checkroom_rounded,
    _ItemKind.bulk => Icons.grain_rounded,
  };

  Color get color => switch (this) {
    _ItemKind.general => AppTheme.teal,
    _ItemKind.electronics => const Color(0xFF2563EB),
    _ItemKind.fresh => const Color(0xFF16A34A),
    _ItemKind.coldChain => AppTheme.cyan,
    _ItemKind.hazardous => AppTheme.amber,
    _ItemKind.apparel => const Color(0xFF7C3AED),
    _ItemKind.bulk => const Color(0xFFB45309),
  };
}

class _ItemRecord {
  const _ItemRecord({
    required this.id,
    required this.kind,
    required this.itemCode,
    required this.itemName,
    required this.categoryName,
    required this.baseUomCode,
    required this.sku,
    required this.barcode,
    required this.hsCode,
    required this.nmfcCode,
    required this.hazardous,
    required this.hazardousClass,
    required this.temperatureControlled,
    required this.minTemperatureC,
    required this.maxTemperatureC,
    required this.unitWeightKg,
    required this.unitVolumeCbm,
    required this.lengthCm,
    required this.widthCm,
    required this.heightCm,
    required this.shelfLifeDays,
    required this.fragile,
    required this.stackable,
    required this.lotControlled,
    required this.statusCode,
    required this.isActive,
    required this.description,
    required this.memo,
  });

  final int id;
  final _ItemKind kind;
  final String itemCode;
  final String itemName;
  final String categoryName;
  final String baseUomCode;
  final String sku;
  final String barcode;
  final String hsCode;
  final String nmfcCode;
  final bool hazardous;
  final String hazardousClass;
  final bool temperatureControlled;
  final String minTemperatureC;
  final String maxTemperatureC;
  final double unitWeightKg;
  final double unitVolumeCbm;
  final double lengthCm;
  final double widthCm;
  final double heightCm;
  final int shelfLifeDays;
  final bool fragile;
  final bool stackable;
  final bool lotControlled;
  final String statusCode;
  final bool isActive;
  final String description;
  final String memo;

  Map<String, Object?> toApiPayload() {
    return {
      'item_code': itemCode,
      'item_name': itemName,
      'item_description': description,
      'category_code': kind.code,
      'category_name': categoryName,
      'base_uom_code': baseUomCode,
      'sku': sku,
      'barcode': barcode,
      'nmfc_code': nmfcCode,
      'hs_code': hsCode,
      'is_hazardous': hazardous,
      'hazardous_class': hazardousClass,
      'temperature_controlled': temperatureControlled,
      'min_temperature_c': minTemperatureC,
      'max_temperature_c': maxTemperatureC,
      'unit_weight_kg': unitWeightKg,
      'unit_volume_cbm': unitVolumeCbm,
      'length_cm': lengthCm,
      'width_cm': widthCm,
      'height_cm': heightCm,
      'status': statusCode,
      'is_active': isActive,
      'metadata': {
        'item_kind': kind.code,
        'category_name': categoryName,
        'base_uom_code': baseUomCode,
        'shelf_life_days': shelfLifeDays,
        'fragile': fragile,
        'stackable': stackable,
        'lot_controlled': lotControlled,
        'memo': memo,
      },
    };
  }
}

class _ItemMetric {
  const _ItemMetric({
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

const _seedItems = [
  _ItemRecord(
    id: 1,
    kind: _ItemKind.electronics,
    itemCode: 'ELE0001',
    itemName: 'OLED TV 65인치',
    categoryName: '전자제품',
    baseUomCode: 'EA',
    sku: 'SKU-TV-OLED65',
    barcode: '8801234567001',
    hsCode: '8528.72',
    nmfcCode: '62820',
    hazardous: false,
    hazardousClass: '',
    temperatureControlled: false,
    minTemperatureC: '',
    maxTemperatureC: '',
    unitWeightKg: 28.5,
    unitVolumeCbm: 0.48,
    lengthCm: 162,
    widthCm: 22,
    heightCm: 96,
    shelfLifeDays: 0,
    fragile: true,
    stackable: false,
    lotControlled: true,
    statusCode: 'ACTIVE',
    isActive: true,
    description: '대형 디스플레이 완제품. 충격 방지 적재 필요.',
    memo: '상차 시 세로 적재 금지.',
  ),
  _ItemRecord(
    id: 2,
    kind: _ItemKind.coldChain,
    itemCode: 'CLD0001',
    itemName: '냉장 밀키트 박스',
    categoryName: '냉장냉동',
    baseUomCode: 'BOX',
    sku: 'SKU-FOOD-MEALKIT',
    barcode: '8801234567002',
    hsCode: '2106.90',
    nmfcCode: '',
    hazardous: false,
    hazardousClass: '',
    temperatureControlled: true,
    minTemperatureC: '2',
    maxTemperatureC: '8',
    unitWeightKg: 4.2,
    unitVolumeCbm: 0.032,
    lengthCm: 42,
    widthCm: 32,
    heightCm: 24,
    shelfLifeDays: 5,
    fragile: false,
    stackable: true,
    lotControlled: true,
    statusCode: 'ACTIVE',
    isActive: true,
    description: '냉장 온도 유지가 필요한 식품 박스.',
    memo: 'POD 온도 로그 필수.',
  ),
  _ItemRecord(
    id: 3,
    kind: _ItemKind.hazardous,
    itemCode: 'HAZ0001',
    itemName: '리튬이온 배터리 팩',
    categoryName: '위험물',
    baseUomCode: 'EA',
    sku: 'SKU-BAT-LI-01',
    barcode: '8801234567003',
    hsCode: '8507.60',
    nmfcCode: '60720',
    hazardous: true,
    hazardousClass: 'Class 9',
    temperatureControlled: false,
    minTemperatureC: '',
    maxTemperatureC: '',
    unitWeightKg: 12.0,
    unitVolumeCbm: 0.055,
    lengthCm: 52,
    widthCm: 34,
    heightCm: 31,
    shelfLifeDays: 0,
    fragile: true,
    stackable: false,
    lotControlled: true,
    statusCode: 'ACTIVE',
    isActive: true,
    description: 'UN3480 취급 기준 적용 대상.',
    memo: '위험물 자격 기사와 지정 차량 필요.',
  ),
  _ItemRecord(
    id: 4,
    kind: _ItemKind.fresh,
    itemCode: 'FRS0001',
    itemName: '친환경 딸기 팩',
    categoryName: '신선식품',
    baseUomCode: 'BOX',
    sku: 'SKU-FRESH-STRAWBERRY',
    barcode: '8801234567004',
    hsCode: '0810.10',
    nmfcCode: '',
    hazardous: false,
    hazardousClass: '',
    temperatureControlled: true,
    minTemperatureC: '1',
    maxTemperatureC: '5',
    unitWeightKg: 2.8,
    unitVolumeCbm: 0.026,
    lengthCm: 38,
    widthCm: 29,
    heightCm: 24,
    shelfLifeDays: 3,
    fragile: true,
    stackable: true,
    lotControlled: true,
    statusCode: 'ACTIVE',
    isActive: true,
    description: '충격과 온도 편차에 민감한 농산물.',
    memo: '상단 적재 권장.',
  ),
  _ItemRecord(
    id: 5,
    kind: _ItemKind.apparel,
    itemCode: 'APP0001',
    itemName: '시즌 의류 카톤',
    categoryName: '패션잡화',
    baseUomCode: 'CTN',
    sku: 'SKU-APP-SEASON',
    barcode: '8801234567005',
    hsCode: '6204.42',
    nmfcCode: '49880',
    hazardous: false,
    hazardousClass: '',
    temperatureControlled: false,
    minTemperatureC: '',
    maxTemperatureC: '',
    unitWeightKg: 9.6,
    unitVolumeCbm: 0.11,
    lengthCm: 60,
    widthCm: 45,
    heightCm: 40,
    shelfLifeDays: 0,
    fragile: false,
    stackable: true,
    lotControlled: false,
    statusCode: 'ACTIVE',
    isActive: true,
    description: '매장 납품용 의류 카톤.',
    memo: '박스 훼손 클레임 관리.',
  ),
  _ItemRecord(
    id: 6,
    kind: _ItemKind.bulk,
    itemCode: 'BLK0001',
    itemName: '팔레트 원지',
    categoryName: '벌크화물',
    baseUomCode: 'PLT',
    sku: 'SKU-BULK-PAPER',
    barcode: '',
    hsCode: '4805.19',
    nmfcCode: '153200',
    hazardous: false,
    hazardousClass: '',
    temperatureControlled: false,
    minTemperatureC: '',
    maxTemperatureC: '',
    unitWeightKg: 620.0,
    unitVolumeCbm: 1.35,
    lengthCm: 120,
    widthCm: 110,
    heightCm: 160,
    shelfLifeDays: 0,
    fragile: false,
    stackable: true,
    lotControlled: false,
    statusCode: 'ACTIVE',
    isActive: true,
    description: '팔레트 단위 원지 출고 품목.',
    memo: '중량 제한 확인 후 배차.',
  ),
];
