import 'package:flutter/material.dart';

import '../../design/app_theme.dart';

class LoadPlanningPage extends StatefulWidget {
  const LoadPlanningPage({super.key, this.compact = false});

  final bool compact;

  @override
  State<LoadPlanningPage> createState() => _LoadPlanningPageState();
}

class _LoadPlanningPageState extends State<LoadPlanningPage> {
  final Set<int> _selectedOrderIds = {1, 2, 4};
  final Set<int> _confirmedOrderIds = {};
  String _temperatureFilter = 'ALL';
  String _regionFilter = 'ALL';
  int _selectedPlanId = 1;
  _ConfirmationResult? _lastConfirmation;
  late final List<_PlanOrder> _orders = List<_PlanOrder>.from(_seedPlanOrders);
  late final List<_LoadPlan> _plans = List<_LoadPlan>.from(_seedLoadPlans);

  List<_PlanOrder> get _openOrders {
    return _orders
        .where((order) => !_confirmedOrderIds.contains(order.id))
        .toList();
  }

  List<_PlanOrder> get _filteredOrders {
    return _openOrders.where((order) {
      final matchesTemperature =
          _temperatureFilter == 'ALL' ||
          order.temperatureCode == _temperatureFilter;
      final matchesRegion =
          _regionFilter == 'ALL' || order.regionCode == _regionFilter;
      return matchesTemperature && matchesRegion;
    }).toList();
  }

  List<_PlanOrder> get _selectedOrders {
    return _openOrders
        .where((order) => _selectedOrderIds.contains(order.id))
        .toList();
  }

  _LoadPlan get _selectedPlan {
    return _plans.firstWhere(
      (plan) => plan.id == _selectedPlanId,
      orElse: () => _plans.first,
    );
  }

  double get _selectedWeightKg {
    return _selectedOrders.fold(0, (sum, order) => sum + order.weightKg);
  }

  double get _selectedVolumeCbm {
    return _selectedOrders.fold(0, (sum, order) => sum + order.volumeCbm);
  }

  int get _urgentCount {
    return _openOrders.where((order) => order.priorityCode == 'URGENT').length;
  }

  void _toggleOrder(_PlanOrder order) {
    setState(() {
      if (_selectedOrderIds.contains(order.id)) {
        _selectedOrderIds.remove(order.id);
      } else {
        _selectedOrderIds.add(order.id);
      }
    });
  }

  void _selectPlan(_LoadPlan plan) {
    setState(() => _selectedPlanId = plan.id);
  }

  void _autoCompose() {
    setState(() {
      _selectedOrderIds
        ..clear()
        ..addAll(
          _filteredOrders
              .where((order) => order.temperatureCode == 'CHILLED')
              .take(4)
              .map((order) => order.id),
        );
      if (_selectedOrderIds.isEmpty) {
        _selectedOrderIds.addAll(
          _filteredOrders.take(3).map((order) => order.id),
        );
      }
    });
    _showMessage('온도/권역/시간창 기준으로 상차조합 후보를 다시 계산했습니다.');
  }

  void _createLoadPlan() {
    if (_selectedOrders.isEmpty) {
      _showMessage('상차조합에 포함할 오더를 선택하세요.');
      return;
    }

    final nextId =
        (_plans.map((plan) => plan.id).reduce((a, b) => a > b ? a : b)) + 1;
    final newPlan = _LoadPlan(
      id: nextId,
      planNo: 'LP-20260615-${nextId.toString().padLeft(3, '0')}',
      routeName: _selectedOrders.first.routeName,
      vehicleType: _recommendedVehicleType(_selectedWeightKg),
      carrierName: '후보 운송사 검토',
      orderCount: _selectedOrders.length,
      weightKg: _selectedWeightKg,
      volumeCbm: _selectedVolumeCbm,
      maxWeightKg: _recommendedMaxWeight(_selectedWeightKg),
      maxVolumeCbm: 36,
      costAmount:
          _selectedOrders.fold(0.0, (sum, order) => sum + order.sellFare) *
          0.82,
      savingRate: 11.8,
      statusCode: 'DRAFT',
      riskCode: _selectedOrders.any((order) => order.priorityCode == 'URGENT')
          ? 'WATCH'
          : 'GOOD',
      timeWindow:
          '${_selectedOrders.first.pickupWindow} / ${_selectedOrders.last.deliveryWindow}',
    );

    setState(() {
      _plans.insert(0, newPlan);
      _selectedPlanId = newPlan.id;
    });
    _showMessage('${newPlan.planNo} 상차조합 후보를 생성했습니다.');
  }

  void _confirmPlan() {
    final confirmedOrders = _selectedOrders;
    if (confirmedOrders.isEmpty) {
      _showMessage('확정할 상차조합 오더를 먼저 선택하세요.');
      return;
    }

    final planNo = _selectedPlan.planNo;
    setState(() {
      final index = _plans.indexWhere((plan) => plan.id == _selectedPlanId);
      if (index != -1) {
        _plans[index] = _plans[index].copyWith(statusCode: 'CONFIRMED');
      }
      _confirmedOrderIds.addAll(confirmedOrders.map((order) => order.id));
      _selectedOrderIds.removeAll(confirmedOrders.map((order) => order.id));
      _lastConfirmation = _ConfirmationResult(
        planNo: planNo,
        orderCount: confirmedOrders.length,
        routeName: confirmedOrders.first.routeName,
        weightKg: confirmedOrders.fold(
          0.0,
          (sum, order) => sum + order.weightKg,
        ),
      );
    });
    _showMessage(
      '$planNo 확정 완료. ${confirmedOrders.length}건이 배정/배차 대기로 이동했습니다.',
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  double _recommendedMaxWeight(double weightKg) {
    if (weightKg <= 1100) {
      return 2500;
    }
    if (weightKg <= 4500) {
      return 5000;
    }
    return 11000;
  }

  String _recommendedVehicleType(double weightKg) {
    if (weightKg <= 1100) {
      return '1톤 냉탑';
    }
    if (weightKg <= 4500) {
      return '5톤 윙바디';
    }
    return '11톤 간선';
  }

  @override
  Widget build(BuildContext context) {
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
          _PlanningHeader(
            onAutoCompose: _autoCompose,
            onCreate: _createLoadPlan,
          ),
          const SizedBox(height: 16),
          _PlanningMetricStrip(
            orders: _openOrders,
            plans: _plans,
            urgentCount: _urgentCount,
            selectedWeightKg: _selectedWeightKg,
          ),
          const SizedBox(height: 16),
          if (_lastConfirmation != null) ...[
            _ConfirmationBanner(result: _lastConfirmation!),
            const SizedBox(height: 16),
          ],
          _PlanningToolbar(
            temperatureFilter: _temperatureFilter,
            regionFilter: _regionFilter,
            onTemperatureChanged: (value) =>
                setState(() => _temperatureFilter = value),
            onRegionChanged: (value) => setState(() => _regionFilter = value),
            onAutoCompose: _autoCompose,
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1260 && !widget.compact;
              if (!wide) {
                return Column(
                  children: [
                    _OrderPoolPanel(
                      orders: _filteredOrders,
                      selectedOrderIds: _selectedOrderIds,
                      onToggle: _toggleOrder,
                    ),
                    const SizedBox(height: 16),
                    _LoadPlanCanvas(
                      selectedOrders: _selectedOrders,
                      selectedPlan: _selectedPlan,
                      onCreate: _createLoadPlan,
                      onConfirm: _confirmPlan,
                    ),
                    const SizedBox(height: 16),
                    _PlanningIntelligencePanel(
                      plans: _plans,
                      selectedPlanId: _selectedPlanId,
                      onSelect: _selectPlan,
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 9,
                    child: _OrderPoolPanel(
                      orders: _filteredOrders,
                      selectedOrderIds: _selectedOrderIds,
                      onToggle: _toggleOrder,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 10,
                    child: _LoadPlanCanvas(
                      selectedOrders: _selectedOrders,
                      selectedPlan: _selectedPlan,
                      onCreate: _createLoadPlan,
                      onConfirm: _confirmPlan,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 7,
                    child: _PlanningIntelligencePanel(
                      plans: _plans,
                      selectedPlanId: _selectedPlanId,
                      onSelect: _selectPlan,
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

class _PlanningHeader extends StatelessWidget {
  const _PlanningHeader({required this.onAutoCompose, required this.onCreate});

  final VoidCallback onAutoCompose;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return _PlanningPanel(
      padding: const EdgeInsets.all(22),
      child: Wrap(
        spacing: 14,
        runSpacing: 14,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 620,
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppTheme.cyan.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.alt_route_rounded,
                    color: AppTheme.cyan,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '편성/상차조합',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: AppTheme.graphite,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '미편성 오더를 권역, 시간창, 온도조건, 적재율 기준으로 묶어 운송계획 후보를 만듭니다.',
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
            ),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: onAutoCompose,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('자동 조합'),
              ),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.playlist_add_check_rounded),
                label: const Text('상차조합 생성'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanningMetricStrip extends StatelessWidget {
  const _PlanningMetricStrip({
    required this.orders,
    required this.plans,
    required this.urgentCount,
    required this.selectedWeightKg,
  });

  final List<_PlanOrder> orders;
  final List<_LoadPlan> plans;
  final int urgentCount;
  final double selectedWeightKg;

  @override
  Widget build(BuildContext context) {
    final unplanned = orders
        .where((order) => order.statusCode == 'OPEN')
        .length;
    final confirmed = plans
        .where((plan) => plan.statusCode == 'CONFIRMED')
        .length;
    final avgUtilization =
        plans.fold<double>(0, (sum, plan) => sum + plan.weightUtilization) /
        plans.length;
    final metrics = [
      _PlanningMetric(
        label: '미편성 오더',
        value: '$unplanned건',
        detail: '긴급 $urgentCount건',
        icon: Icons.inbox_rounded,
        color: AppTheme.teal,
      ),
      _PlanningMetric(
        label: '후보 조합',
        value: '${plans.length}개',
        detail: '확정 $confirmed개',
        icon: Icons.schema_rounded,
        color: AppTheme.cyan,
      ),
      _PlanningMetric(
        label: '평균 적재율',
        value: '${(avgUtilization * 100).toStringAsFixed(0)}%',
        detail: '중량 기준',
        icon: Icons.speed_rounded,
        color: const Color(0xFF2563EB),
      ),
      _PlanningMetric(
        label: '선택 중량',
        value: '${selectedWeightKg.toStringAsFixed(0)}kg',
        detail: '조합 검토 중',
        icon: Icons.scale_rounded,
        color: AppTheme.amber,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1040
            ? 4
            : constraints.maxWidth >= 640
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
                (metric) =>
                    SizedBox(width: width, child: _PlanningMetricCard(metric)),
              )
              .toList(),
        );
      },
    );
  }
}

class _PlanningToolbar extends StatelessWidget {
  const _PlanningToolbar({
    required this.temperatureFilter,
    required this.regionFilter,
    required this.onTemperatureChanged,
    required this.onRegionChanged,
    required this.onAutoCompose,
  });

  final String temperatureFilter;
  final String regionFilter;
  final ValueChanged<String> onTemperatureChanged;
  final ValueChanged<String> onRegionChanged;
  final VoidCallback onAutoCompose;

  @override
  Widget build(BuildContext context) {
    return _PlanningPanel(
      padding: const EdgeInsets.all(14),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _FilterSegment(
            label: '온도',
            value: temperatureFilter,
            options: const {
              'ALL': '전체',
              'AMBIENT': '상온',
              'CHILLED': '냉장',
              'FROZEN': '냉동',
            },
            onChanged: onTemperatureChanged,
          ),
          _FilterSegment(
            label: '권역',
            value: regionFilter,
            options: const {
              'ALL': '전체',
              'SEOUL': '수도권',
              'YEONGNAM': '영남',
              'CENTRAL': '중부',
            },
            onChanged: onRegionChanged,
          ),
          _StatusLegend(
            label: 'SLA 주의',
            color: AppTheme.amber,
            icon: Icons.warning_amber_rounded,
          ),
          _StatusLegend(
            label: '적재율 우수',
            color: AppTheme.teal,
            icon: Icons.check_circle_rounded,
          ),
          OutlinedButton.icon(
            onPressed: onAutoCompose,
            icon: const Icon(Icons.tune_rounded),
            label: const Text('조건 기준 재계산'),
          ),
        ],
      ),
    );
  }
}

class _ConfirmationBanner extends StatelessWidget {
  const _ConfirmationBanner({required this.result});

  final _ConfirmationResult result;

  @override
  Widget build(BuildContext context) {
    return _PlanningPanel(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.teal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.task_alt_rounded,
              color: AppTheme.teal,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${result.planNo} 확정 완료',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.graphite,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${result.orderCount}건 · ${result.routeName} · ${result.weightKg.toStringAsFixed(0)}kg이 배정/배차 대기 단계로 이동했습니다.',
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
          const SizedBox(width: 10),
          _SmallPill(label: '배정/배차 대기', color: AppTheme.teal),
        ],
      ),
    );
  }
}

class _OrderPoolPanel extends StatelessWidget {
  const _OrderPoolPanel({
    required this.orders,
    required this.selectedOrderIds,
    required this.onToggle,
  });

  final List<_PlanOrder> orders;
  final Set<int> selectedOrderIds;
  final ValueChanged<_PlanOrder> onToggle;

  @override
  Widget build(BuildContext context) {
    return _PlanningPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PlanningSectionHeader(
            icon: Icons.inbox_rounded,
            title: '미편성 오더 풀',
            subtitle: '확정된 오더는 풀에서 사라지고 배정/배차 대기로 이동합니다.',
          ),
          const SizedBox(height: 14),
          if (orders.isEmpty)
            const _EmptyOrderPoolState()
          else
            for (final order in orders) ...[
              _PlanOrderTile(
                order: order,
                selected: selectedOrderIds.contains(order.id),
                onTap: () => onToggle(order),
              ),
              if (order != orders.last) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _LoadPlanCanvas extends StatelessWidget {
  const _LoadPlanCanvas({
    required this.selectedOrders,
    required this.selectedPlan,
    required this.onCreate,
    required this.onConfirm,
  });

  final List<_PlanOrder> selectedOrders;
  final _LoadPlan selectedPlan;
  final VoidCallback onCreate;
  final VoidCallback onConfirm;

  double get _weightKg {
    return selectedOrders.fold(0, (sum, order) => sum + order.weightKg);
  }

  double get _volumeCbm {
    return selectedOrders.fold(0, (sum, order) => sum + order.volumeCbm);
  }

  double get _sellFare {
    return selectedOrders.fold(0, (sum, order) => sum + order.sellFare);
  }

  @override
  Widget build(BuildContext context) {
    final maxWeight = selectedPlan.maxWeightKg;
    final maxVolume = selectedPlan.maxVolumeCbm;
    final weightRate = maxWeight == 0
        ? 0.0
        : (_weightKg / maxWeight).clamp(0.0, 1.0);
    final volumeRate = maxVolume == 0
        ? 0.0
        : (_volumeCbm / maxVolume).clamp(0.0, 1.0);

    return _PlanningPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PlanningSectionHeader(
            icon: Icons.hub_rounded,
            title: '상차조합 작업대',
            subtitle: selectedOrders.isEmpty
                ? '왼쪽 오더를 선택하면 조합 품질을 즉시 계산합니다.'
                : '${selectedOrders.length}건 선택 · ${selectedPlan.vehicleType} 기준 검토',
          ),
          const SizedBox(height: 14),
          _LoadRoutePreview(orders: selectedOrders),
          const SizedBox(height: 14),
          _CapacityBoard(
            weightRate: weightRate,
            volumeRate: volumeRate,
            weightText:
                '${_weightKg.toStringAsFixed(0)} / ${maxWeight.toStringAsFixed(0)}kg',
            volumeText:
                '${_volumeCbm.toStringAsFixed(1)} / ${maxVolume.toStringAsFixed(1)}CBM',
            fareText: '매출 ₩${(_sellFare / 10000).toStringAsFixed(0)}만',
          ),
          const SizedBox(height: 14),
          if (selectedOrders.isEmpty)
            const _EmptyCompositionState()
          else
            for (final order in selectedOrders) ...[
              _SelectedOrderChip(order: order),
              if (order != selectedOrders.last) const SizedBox(height: 8),
            ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 180,
                child: OutlinedButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.add_link_rounded),
                  label: const Text('후보 생성'),
                ),
              ),
              SizedBox(
                width: 180,
                child: ElevatedButton.icon(
                  onPressed: onConfirm,
                  icon: const Icon(Icons.task_alt_rounded),
                  label: const Text('조합 확정'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanningIntelligencePanel extends StatelessWidget {
  const _PlanningIntelligencePanel({
    required this.plans,
    required this.selectedPlanId,
    required this.onSelect,
  });

  final List<_LoadPlan> plans;
  final int selectedPlanId;
  final ValueChanged<_LoadPlan> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PlanningPanel(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _PlanningSectionHeader(
                icon: Icons.auto_graph_rounded,
                title: '조합 후보',
                subtitle: '비용, 적재율, SLA 위험도를 비교합니다.',
              ),
              const SizedBox(height: 14),
              for (final plan in plans.take(5)) ...[
                _LoadPlanCandidateTile(
                  plan: plan,
                  selected: selectedPlanId == plan.id,
                  onTap: () => onSelect(plan),
                ),
                if (plan != plans.take(5).last) const SizedBox(height: 10),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        const _PlanningPanel(
          padding: EdgeInsets.all(16),
          child: _RuleCheckPanel(),
        ),
      ],
    );
  }
}

class _PlanOrderTile extends StatelessWidget {
  const _PlanOrderTile({
    required this.order,
    required this.selected,
    required this.onTap,
  });

  final _PlanOrder order;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = order.temperatureColor;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.teal.withValues(alpha: 0.08)
                : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? AppTheme.teal.withValues(alpha: 0.35)
                  : AppTheme.line,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(value: selected, onChanged: (_) => onTap()),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            order.orderNo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: AppTheme.graphite,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0,
                                ),
                          ),
                        ),
                        _SmallPill(label: order.temperatureLabel, color: color),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${order.customerName} · ${order.itemName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.ink,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _MetaChip(
                          icon: Icons.upload_rounded,
                          label: order.pickupName,
                        ),
                        _MetaChip(
                          icon: Icons.download_rounded,
                          label: order.deliveryName,
                        ),
                        _MetaChip(
                          icon: Icons.schedule_rounded,
                          label: order.pickupWindow,
                        ),
                        _MetaChip(
                          icon: Icons.scale_rounded,
                          label: '${order.weightKg.toStringAsFixed(0)}kg',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadRoutePreview extends StatelessWidget {
  const _LoadRoutePreview({required this.orders});

  final List<_PlanOrder> orders;

  @override
  Widget build(BuildContext context) {
    final stops = orders.isEmpty
        ? const ['상차지 선택', '경유지', '하차지 선택']
        : [
            orders.first.pickupName,
            if (orders.length > 2) '${orders.length - 1}개 상차지',
            orders.last.deliveryName,
          ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.route_rounded, color: Colors.white, size: 19),
              const SizedBox(width: 8),
              Text(
                '상차 순서 미리보기',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var index = 0; index < stops.length; index++) ...[
                _RouteStopBadge(label: stops[index], index: index + 1),
                if (index != stops.length - 1)
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Color(0xFF67E8F9),
                    size: 20,
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _CapacityBoard extends StatelessWidget {
  const _CapacityBoard({
    required this.weightRate,
    required this.volumeRate,
    required this.weightText,
    required this.volumeText,
    required this.fareText,
  });

  final double weightRate;
  final double volumeRate;
  final String weightText;
  final String volumeText;
  final String fareText;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 640 ? 3 : 1;
        final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: width,
              child: _CapacityMeter(
                label: '중량 적재율',
                value: weightRate,
                detail: weightText,
                color: AppTheme.teal,
              ),
            ),
            SizedBox(
              width: width,
              child: _CapacityMeter(
                label: '부피 적재율',
                value: volumeRate,
                detail: volumeText,
                color: const Color(0xFF2563EB),
              ),
            ),
            SizedBox(
              width: width,
              child: _CapacityMeter(
                label: '예상 매출',
                value: 0.78,
                detail: fareText,
                color: AppTheme.amber,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SelectedOrderChip extends StatelessWidget {
  const _SelectedOrderChip({required this.order});

  final _PlanOrder order;

  @override
  Widget build(BuildContext context) {
    return Container(
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
              color: order.temperatureColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.inventory_2_rounded,
              color: order.temperatureColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${order.orderNo} · ${order.customerName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.graphite,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                Text(
                  '${order.pickupName} → ${order.deliveryName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.slate,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          _SmallPill(label: order.priorityLabel, color: order.priorityColor),
        ],
      ),
    );
  }
}

class _LoadPlanCandidateTile extends StatelessWidget {
  const _LoadPlanCandidateTile({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  final _LoadPlan plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final riskColor = plan.riskColor;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.cyan.withValues(alpha: 0.08)
                : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? AppTheme.cyan.withValues(alpha: 0.35)
                  : AppTheme.line,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      plan.planNo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppTheme.graphite,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  _SmallPill(label: plan.statusLabel, color: plan.statusColor),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                '${plan.routeName} · ${plan.vehicleType}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.slate,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 10),
              _MiniProgress(
                label: '적재율',
                value: plan.weightUtilization,
                color: plan.weightUtilization >= 0.82
                    ? AppTheme.teal
                    : AppTheme.amber,
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  _SmallPill(label: plan.riskLabel, color: riskColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '절감 ${plan.savingRate.toStringAsFixed(1)}% · ₩${(plan.costAmount / 10000).toStringAsFixed(0)}만',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.ink,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
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

class _RuleCheckPanel extends StatelessWidget {
  const _RuleCheckPanel();

  @override
  Widget build(BuildContext context) {
    final checks = [
      const _RuleCheck('시간창 충돌', '상차 09:00-11:00 내 조합 가능', true),
      const _RuleCheck('온도 조건', '냉장 오더는 냉탑 차량만 후보', true),
      const _RuleCheck('중량/CBM', '5톤 차량 기준 82% 이하 유지', true),
      const _RuleCheck('권역 혼재', '수도권/중부 혼재 1건 확인 필요', false),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PlanningSectionHeader(
          icon: Icons.rule_rounded,
          title: '편성 규칙 체크',
          subtitle: '조합 확정 전 운영 제약조건을 확인합니다.',
        ),
        const SizedBox(height: 14),
        for (final check in checks) ...[
          _RuleCheckRow(check: check),
          if (check != checks.last)
            const Divider(height: 18, color: AppTheme.line),
        ],
      ],
    );
  }
}

class _PlanningPanel extends StatelessWidget {
  const _PlanningPanel({required this.child, this.padding = EdgeInsets.zero});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x070F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _PlanningSectionHeader extends StatelessWidget {
  const _PlanningSectionHeader({
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
        Icon(icon, color: AppTheme.cyan, size: 22),
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
    );
  }
}

class _PlanningMetricCard extends StatelessWidget {
  const _PlanningMetricCard(this.metric);

  final _PlanningMetric metric;

  @override
  Widget build(BuildContext context) {
    return _PlanningPanel(
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: metric.color.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(metric.icon, color: metric.color, size: 21),
          ),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.graphite,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                Text(
                  metric.detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: metric.color,
                    fontWeight: FontWeight.w800,
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

class _FilterSegment extends StatelessWidget {
  const _FilterSegment({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.slate,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        for (final entry in options.entries)
          ChoiceChip(
            label: Text(entry.value),
            selected: value == entry.key,
            selectedColor: AppTheme.cyan.withValues(alpha: 0.12),
            checkmarkColor: AppTheme.cyan,
            onSelected: (_) => onChanged(entry.key),
            labelStyle: TextStyle(
              color: value == entry.key ? AppTheme.cyan : AppTheme.slate,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
      ],
    );
  }
}

class _StatusLegend extends StatelessWidget {
  const _StatusLegend({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.slate, size: 14),
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

class _SmallPill extends StatelessWidget {
  const _SmallPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

class _RouteStopBadge extends StatelessWidget {
  const _RouteStopBadge({required this.label, required this.index});

  final String label;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: const Color(0xFF67E8F9),
            child: Text(
              index.toString(),
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _CapacityMeter extends StatelessWidget {
  const _CapacityMeter({
    required this.label,
    required this.value,
    required this.detail,
    required this.color,
  });

  final String label;
  final double value;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.slate,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(value * 100).toStringAsFixed(0)}%',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppTheme.graphite,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 8),
          _MiniProgress(label: detail, value: value, color: color),
        ],
      ),
    );
  }
}

class _MiniProgress extends StatelessWidget {
  const _MiniProgress({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: value.clamp(0, 1),
            minHeight: 7,
            backgroundColor: AppTheme.line,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.slate,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _EmptyCompositionState extends StatelessWidget {
  const _EmptyCompositionState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.line),
      ),
      child: const Text(
        '선택된 오더가 없습니다. 왼쪽 미편성 오더 풀에서 상차조합 대상 오더를 선택하세요.',
        style: TextStyle(
          color: AppTheme.slate,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _EmptyOrderPoolState extends StatelessWidget {
  const _EmptyOrderPoolState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.teal.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.teal.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.teal.withValues(alpha: 0.18)),
            ),
            child: const Icon(
              Icons.task_alt_rounded,
              color: AppTheme.teal,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '현재 조건의 미편성 오더가 없습니다.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.graphite,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '확정된 조합은 배정/배차 대기로 이동했습니다. 필터를 변경하거나 신규 오더를 등록해 다음 조합을 진행하세요.',
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

class _RuleCheckRow extends StatelessWidget {
  const _RuleCheckRow({required this.check});

  final _RuleCheck check;

  @override
  Widget build(BuildContext context) {
    final color = check.passed ? AppTheme.teal : AppTheme.amber;
    return Row(
      children: [
        Icon(
          check.passed
              ? Icons.check_circle_rounded
              : Icons.warning_amber_rounded,
          color: color,
          size: 19,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                check.title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.graphite,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              Text(
                check.description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.slate,
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

class _PlanningMetric {
  const _PlanningMetric({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;
}

class _RuleCheck {
  const _RuleCheck(this.title, this.description, this.passed);

  final String title;
  final String description;
  final bool passed;
}

class _ConfirmationResult {
  const _ConfirmationResult({
    required this.planNo,
    required this.orderCount,
    required this.routeName,
    required this.weightKg,
  });

  final String planNo;
  final int orderCount;
  final String routeName;
  final double weightKg;
}

class _PlanOrder {
  const _PlanOrder({
    required this.id,
    required this.orderNo,
    required this.customerName,
    required this.shipperName,
    required this.pickupName,
    required this.deliveryName,
    required this.pickupWindow,
    required this.deliveryWindow,
    required this.itemName,
    required this.weightKg,
    required this.volumeCbm,
    required this.sellFare,
    required this.temperatureCode,
    required this.regionCode,
    required this.routeName,
    required this.priorityCode,
    required this.statusCode,
  });

  final int id;
  final String orderNo;
  final String customerName;
  final String shipperName;
  final String pickupName;
  final String deliveryName;
  final String pickupWindow;
  final String deliveryWindow;
  final String itemName;
  final double weightKg;
  final double volumeCbm;
  final double sellFare;
  final String temperatureCode;
  final String regionCode;
  final String routeName;
  final String priorityCode;
  final String statusCode;

  String get temperatureLabel => switch (temperatureCode) {
    'CHILLED' => '냉장',
    'FROZEN' => '냉동',
    _ => '상온',
  };

  Color get temperatureColor => switch (temperatureCode) {
    'CHILLED' => AppTheme.cyan,
    'FROZEN' => const Color(0xFF2563EB),
    _ => AppTheme.teal,
  };

  String get priorityLabel => priorityCode == 'URGENT' ? '긴급' : '일반';

  Color get priorityColor =>
      priorityCode == 'URGENT' ? AppTheme.amber : AppTheme.slate;
}

class _LoadPlan {
  const _LoadPlan({
    required this.id,
    required this.planNo,
    required this.routeName,
    required this.vehicleType,
    required this.carrierName,
    required this.orderCount,
    required this.weightKg,
    required this.volumeCbm,
    required this.maxWeightKg,
    required this.maxVolumeCbm,
    required this.costAmount,
    required this.savingRate,
    required this.statusCode,
    required this.riskCode,
    required this.timeWindow,
  });

  final int id;
  final String planNo;
  final String routeName;
  final String vehicleType;
  final String carrierName;
  final int orderCount;
  final double weightKg;
  final double volumeCbm;
  final double maxWeightKg;
  final double maxVolumeCbm;
  final double costAmount;
  final double savingRate;
  final String statusCode;
  final String riskCode;
  final String timeWindow;

  double get weightUtilization => maxWeightKg == 0 ? 0 : weightKg / maxWeightKg;

  String get statusLabel => switch (statusCode) {
    'CONFIRMED' => '확정',
    'REVIEW' => '검토',
    _ => '후보',
  };

  Color get statusColor => switch (statusCode) {
    'CONFIRMED' => AppTheme.teal,
    'REVIEW' => AppTheme.amber,
    _ => AppTheme.cyan,
  };

  String get riskLabel => switch (riskCode) {
    'GOOD' => '정상',
    'WATCH' => '주의',
    _ => '위험',
  };

  Color get riskColor => switch (riskCode) {
    'GOOD' => AppTheme.teal,
    'WATCH' => AppTheme.amber,
    _ => const Color(0xFFDC2626),
  };

  _LoadPlan copyWith({String? statusCode}) {
    return _LoadPlan(
      id: id,
      planNo: planNo,
      routeName: routeName,
      vehicleType: vehicleType,
      carrierName: carrierName,
      orderCount: orderCount,
      weightKg: weightKg,
      volumeCbm: volumeCbm,
      maxWeightKg: maxWeightKg,
      maxVolumeCbm: maxVolumeCbm,
      costAmount: costAmount,
      savingRate: savingRate,
      statusCode: statusCode ?? this.statusCode,
      riskCode: riskCode,
      timeWindow: timeWindow,
    );
  }
}

const _seedPlanOrders = [
  _PlanOrder(
    id: 1,
    orderNo: 'KT-20260615-0001',
    customerName: '삼성전자',
    shipperName: '수원 CDC',
    pickupName: '수원 CDC',
    deliveryName: '부산 RDC',
    pickupWindow: '09:00-11:00',
    deliveryWindow: '18:00-22:00',
    itemName: 'OLED TV',
    weightKg: 1197,
    volumeCbm: 20.1,
    sellFare: 1280000,
    temperatureCode: 'AMBIENT',
    regionCode: 'YEONGNAM',
    routeName: '수원 → 부산',
    priorityCode: 'HIGH',
    statusCode: 'OPEN',
  ),
  _PlanOrder(
    id: 2,
    orderNo: 'KT-20260615-0002',
    customerName: '프레시온',
    shipperName: '김포 콜드체인',
    pickupName: '김포 콜드체인',
    deliveryName: '서울 동부센터',
    pickupWindow: '06:00-08:00',
    deliveryWindow: '10:00-13:00',
    itemName: '냉장 밀키트',
    weightKg: 1344,
    volumeCbm: 10.2,
    sellFare: 740000,
    temperatureCode: 'CHILLED',
    regionCode: 'SEOUL',
    routeName: '김포 → 서울',
    priorityCode: 'URGENT',
    statusCode: 'OPEN',
  ),
  _PlanOrder(
    id: 3,
    orderNo: 'KT-20260615-0003',
    customerName: 'K패션',
    shipperName: '인천 반품센터',
    pickupName: '인천 반품센터',
    deliveryName: '이천 물류센터',
    pickupWindow: '13:00-15:00',
    deliveryWindow: '17:00-20:00',
    itemName: '의류 카톤',
    weightKg: 826,
    volumeCbm: 9.4,
    sellFare: 390000,
    temperatureCode: 'AMBIENT',
    regionCode: 'CENTRAL',
    routeName: '인천 → 이천',
    priorityCode: 'NORMAL',
    statusCode: 'OPEN',
  ),
  _PlanOrder(
    id: 4,
    orderNo: 'KT-20260615-0004',
    customerName: '신세계푸드',
    shipperName: '평택센터',
    pickupName: '평택 콜드센터',
    deliveryName: '강남 점포권',
    pickupWindow: '07:00-09:00',
    deliveryWindow: '11:00-14:00',
    itemName: '냉장 식자재',
    weightKg: 980,
    volumeCbm: 8.8,
    sellFare: 560000,
    temperatureCode: 'CHILLED',
    regionCode: 'SEOUL',
    routeName: '평택 → 강남',
    priorityCode: 'URGENT',
    statusCode: 'OPEN',
  ),
  _PlanOrder(
    id: 5,
    orderNo: 'KT-20260615-0005',
    customerName: '이마트',
    shipperName: '여주 CDC',
    pickupName: '여주 CDC',
    deliveryName: '대전 RDC',
    pickupWindow: '10:00-12:00',
    deliveryWindow: '16:00-19:00',
    itemName: '상온 생활용품',
    weightKg: 2410,
    volumeCbm: 18.6,
    sellFare: 910000,
    temperatureCode: 'AMBIENT',
    regionCode: 'CENTRAL',
    routeName: '여주 → 대전',
    priorityCode: 'NORMAL',
    statusCode: 'OPEN',
  ),
  _PlanOrder(
    id: 6,
    orderNo: 'KT-20260615-0006',
    customerName: '콜드프라임',
    shipperName: '용인 냉동창고',
    pickupName: '용인 냉동창고',
    deliveryName: '부산 냉동센터',
    pickupWindow: '15:00-17:00',
    deliveryWindow: '23:00-02:00',
    itemName: '냉동 간편식',
    weightKg: 1760,
    volumeCbm: 14.3,
    sellFare: 1180000,
    temperatureCode: 'FROZEN',
    regionCode: 'YEONGNAM',
    routeName: '용인 → 부산',
    priorityCode: 'HIGH',
    statusCode: 'OPEN',
  ),
];

const _seedLoadPlans = [
  _LoadPlan(
    id: 1,
    planNo: 'LP-20260615-001',
    routeName: '김포/평택 → 서울권',
    vehicleType: '5톤 냉탑',
    carrierName: 'CJ대한통운',
    orderCount: 4,
    weightKg: 3920,
    volumeCbm: 29.1,
    maxWeightKg: 5000,
    maxVolumeCbm: 36,
    costAmount: 1640000,
    savingRate: 13.4,
    statusCode: 'DRAFT',
    riskCode: 'WATCH',
    timeWindow: '06:00-14:00',
  ),
  _LoadPlan(
    id: 2,
    planNo: 'LP-20260615-002',
    routeName: '수원/용인 → 부산권',
    vehicleType: '11톤 윙바디',
    carrierName: '한진',
    orderCount: 3,
    weightKg: 5120,
    volumeCbm: 34.4,
    maxWeightKg: 11000,
    maxVolumeCbm: 52,
    costAmount: 2190000,
    savingRate: 9.8,
    statusCode: 'REVIEW',
    riskCode: 'GOOD',
    timeWindow: '09:00-22:00',
  ),
  _LoadPlan(
    id: 3,
    planNo: 'LP-20260615-003',
    routeName: '여주/이천 → 중부권',
    vehicleType: '5톤 윙바디',
    carrierName: 'OO운송',
    orderCount: 5,
    weightKg: 4380,
    volumeCbm: 31.2,
    maxWeightKg: 5000,
    maxVolumeCbm: 36,
    costAmount: 1320000,
    savingRate: 16.2,
    statusCode: 'CONFIRMED',
    riskCode: 'GOOD',
    timeWindow: '10:00-20:00',
  ),
];
