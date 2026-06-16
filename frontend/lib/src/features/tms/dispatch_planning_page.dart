import 'package:flutter/material.dart';

import '../../design/app_theme.dart';

class DispatchPlanningPage extends StatefulWidget {
  const DispatchPlanningPage({super.key, this.compact = false});

  final bool compact;

  @override
  State<DispatchPlanningPage> createState() => _DispatchPlanningPageState();
}

class _DispatchPlanningPageState extends State<DispatchPlanningPage> {
  late final List<_DispatchPlan> _plans = List<_DispatchPlan>.from(
    _seedDispatchPlans,
  );
  int _selectedPlanId = 1;
  int _selectedVehicleId = 1;
  int _selectedCarrierId = 1;
  String _assignmentMode = 'CARRIER_DELEGATED';
  String _statusFilter = 'ALL';
  _DispatchIssueResult? _lastIssue;

  _DispatchPlan get _selectedPlan {
    return _plans.firstWhere(
      (plan) => plan.id == _selectedPlanId,
      orElse: () => _plans.first,
    );
  }

  _DispatchVehicle get _selectedVehicle {
    return _seedDispatchVehicles.firstWhere(
      (vehicle) => vehicle.id == _selectedVehicleId,
      orElse: () => _seedDispatchVehicles.first,
    );
  }

  _CarrierQuote get _selectedCarrier {
    return _seedCarrierQuotes.firstWhere(
      (quote) => quote.id == _selectedCarrierId,
      orElse: () => _seedCarrierQuotes.first,
    );
  }

  List<_DispatchPlan> get _filteredPlans {
    return _plans.where((plan) {
      return _statusFilter == 'ALL' || plan.statusCode == _statusFilter;
    }).toList();
  }

  int get _issuedCount {
    return _plans.where((plan) => plan.isIssued).length;
  }

  int get _ownFleetWaitingCount {
    return _plans
        .where((plan) => plan.isOwnFleetDispatch && !plan.isIssued)
        .length;
  }

  int get _carrierWaitingCount {
    return _plans
        .where((plan) => plan.isCarrierDelegated && !plan.isIssued)
        .length;
  }

  double get _averageMatchRate {
    if (_plans.isEmpty) {
      return 0;
    }
    return _plans.fold<double>(0, (sum, plan) => sum + plan.matchRate) /
        _plans.length;
  }

  void _selectPlan(_DispatchPlan plan) {
    setState(() {
      _selectedPlanId = plan.id;
      _selectedVehicleId = plan.recommendedVehicleId;
      _selectedCarrierId = plan.recommendedCarrierId;
      _assignmentMode = plan.assignmentTypeCode;
    });
  }

  void _autoRecommend() {
    setState(() {
      _assignmentMode = _selectedPlan.assignmentTypeCode;
      if (_assignmentMode == 'OWN_FLEET') {
        _selectedVehicleId = _selectedPlan.recommendedVehicleId;
      }
      _selectedCarrierId = _selectedPlan.recommendedCarrierId;
    });
    final target = _assignmentMode == 'OWN_FLEET' ? '내 소속 차량/기사' : '위탁 운송사';
    _showMessage('${_selectedPlan.planNo} 기준 최적 $target를 추천했습니다.');
  }

  void _issueDispatch() {
    final plan = _selectedPlan;
    final carrierDelegated = _assignmentMode == 'CARRIER_DELEGATED';
    setState(() {
      final index = _plans.indexWhere((item) => item.id == plan.id);
      if (index != -1) {
        _plans[index] = plan.copyWith(
          statusCode: carrierDelegated ? 'CARRIER_ASSIGNED' : 'DISPATCHED',
          assignmentTypeCode: _assignmentMode,
        );
      }
      _lastIssue = _DispatchIssueResult(
        planNo: plan.planNo,
        assignmentTypeCode: _assignmentMode,
        vehicleNo: carrierDelegated ? null : _selectedVehicle.vehicleNo,
        driverName: carrierDelegated ? null : _selectedVehicle.driverName,
        carrierName: _selectedCarrier.carrierName,
        routeName: plan.routeName,
      );
    });
    final message = carrierDelegated ? '운송사 배정이 발행되었습니다.' : '직접 배차지시가 발행되었습니다.';
    _showMessage('${plan.planNo} $message');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
          _DispatchHeader(
            onAutoRecommend: _autoRecommend,
            onIssue: _issueDispatch,
          ),
          const SizedBox(height: 16),
          _DispatchMetricStrip(
            ownFleetWaitingCount: _ownFleetWaitingCount,
            carrierWaitingCount: _carrierWaitingCount,
            issuedCount: _issuedCount,
            averageMatchRate: _averageMatchRate,
            riskCount: _plans.where((plan) => plan.riskCode != 'GOOD').length,
          ),
          const SizedBox(height: 16),
          if (_lastIssue != null) ...[
            _DispatchIssueBanner(result: _lastIssue!),
            const SizedBox(height: 16),
          ],
          _DispatchToolbar(
            statusFilter: _statusFilter,
            onStatusChanged: (value) => setState(() => _statusFilter = value),
            onAutoRecommend: _autoRecommend,
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1280 && !widget.compact;
              if (!wide) {
                return Column(
                  children: [
                    _DispatchQueuePanel(
                      plans: _filteredPlans,
                      selectedPlanId: _selectedPlanId,
                      onSelect: _selectPlan,
                    ),
                    const SizedBox(height: 16),
                    _AssignmentBoard(
                      plan: _selectedPlan,
                      assignmentMode: _assignmentMode,
                      selectedCarrierId: _selectedCarrierId,
                      onCarrierSelected: (id) => setState(() {
                        _assignmentMode = 'CARRIER_DELEGATED';
                        _selectedCarrierId = id;
                      }),
                      selectedVehicleId: _selectedVehicleId,
                      onVehicleSelected: (id) => setState(() {
                        _assignmentMode = 'OWN_FLEET';
                        _selectedVehicleId = id;
                      }),
                    ),
                    const SizedBox(height: 16),
                    _DispatchCommandPanel(
                      plan: _selectedPlan,
                      assignmentMode: _assignmentMode,
                      vehicle: _selectedVehicle,
                      selectedCarrierId: _selectedCarrierId,
                      onIssue: _issueDispatch,
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 8,
                    child: _DispatchQueuePanel(
                      plans: _filteredPlans,
                      selectedPlanId: _selectedPlanId,
                      onSelect: _selectPlan,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 10,
                    child: _AssignmentBoard(
                      plan: _selectedPlan,
                      assignmentMode: _assignmentMode,
                      selectedCarrierId: _selectedCarrierId,
                      onCarrierSelected: (id) => setState(() {
                        _assignmentMode = 'CARRIER_DELEGATED';
                        _selectedCarrierId = id;
                      }),
                      selectedVehicleId: _selectedVehicleId,
                      onVehicleSelected: (id) => setState(() {
                        _assignmentMode = 'OWN_FLEET';
                        _selectedVehicleId = id;
                      }),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 8,
                    child: _DispatchCommandPanel(
                      plan: _selectedPlan,
                      assignmentMode: _assignmentMode,
                      vehicle: _selectedVehicle,
                      selectedCarrierId: _selectedCarrierId,
                      onIssue: _issueDispatch,
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

class _DispatchHeader extends StatelessWidget {
  const _DispatchHeader({required this.onAutoRecommend, required this.onIssue});

  final VoidCallback onAutoRecommend;
  final VoidCallback onIssue;

  @override
  Widget build(BuildContext context) {
    return _DispatchPanel(
      padding: const EdgeInsets.all(22),
      child: Wrap(
        spacing: 14,
        runSpacing: 14,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 650,
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppTheme.teal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.local_shipping_rounded,
                    color: AppTheme.teal,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '배정/배차',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: AppTheme.graphite,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '직접 배차는 내 소속 차량만, 외부 운송은 운송사에 배정해 배차를 위임합니다.',
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
                onPressed: onAutoRecommend,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('자동 추천'),
              ),
              FilledButton.icon(
                onPressed: onIssue,
                icon: const Icon(Icons.send_rounded),
                label: const Text('배정/배차 확정'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DispatchMetricStrip extends StatelessWidget {
  const _DispatchMetricStrip({
    required this.ownFleetWaitingCount,
    required this.carrierWaitingCount,
    required this.issuedCount,
    required this.averageMatchRate,
    required this.riskCount,
  });

  final int ownFleetWaitingCount;
  final int carrierWaitingCount;
  final int issuedCount;
  final double averageMatchRate;
  final int riskCount;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _DispatchMetric(
        label: '직접 배차 대기',
        value: '$ownFleetWaitingCount건',
        detail: '내 소속/위수탁/개별차량',
        icon: Icons.assignment_turned_in_rounded,
        color: AppTheme.teal,
      ),
      _DispatchMetric(
        label: '운송사 배정 대기',
        value: '$carrierWaitingCount건',
        detail: '차량/기사는 운송사 위임',
        icon: Icons.business_center_rounded,
        color: AppTheme.cyan,
      ),
      _DispatchMetric(
        label: '발행 완료',
        value: '$issuedCount건',
        detail: '배차지시/위탁배정',
        icon: Icons.send_rounded,
        color: const Color(0xFF2563EB),
      ),
      _DispatchMetric(
        label: '평균 매칭률',
        value: '${(averageMatchRate * 100).toStringAsFixed(0)}%',
        detail: '자원/운송사 추천',
        icon: Icons.speed_rounded,
        color: AppTheme.amber,
      ),
      _DispatchMetric(
        label: '주의 배차',
        value: '$riskCount건',
        detail: 'SLA/온도/도착시간',
        icon: Icons.warning_amber_rounded,
        color: const Color(0xFFDC2626),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1180
            ? 5
            : constraints.maxWidth >= 760
            ? 2
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
                (metric) => SizedBox(width: width, child: _MetricCard(metric)),
              )
              .toList(),
        );
      },
    );
  }
}

class _DispatchToolbar extends StatelessWidget {
  const _DispatchToolbar({
    required this.statusFilter,
    required this.onStatusChanged,
    required this.onAutoRecommend,
  });

  final String statusFilter;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onAutoRecommend;

  @override
  Widget build(BuildContext context) {
    return _DispatchPanel(
      padding: const EdgeInsets.all(14),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _FilterSegment(
            label: '상태',
            value: statusFilter,
            options: const {
              'ALL': '전체',
              'READY': '배차대기',
              'ASSIGNING': '배정중',
              'CARRIER_ASSIGNED': '운송사배정',
              'DISPATCHED': '직접배차',
            },
            onChanged: onStatusChanged,
          ),
          _LegendChip(
            label: '직접 배차',
            color: AppTheme.teal,
            icon: Icons.phone_iphone_rounded,
          ),
          _LegendChip(
            label: '운송사 위탁',
            color: AppTheme.cyan,
            icon: Icons.sync_alt_rounded,
          ),
          OutlinedButton.icon(
            onPressed: onAutoRecommend,
            icon: const Icon(Icons.tune_rounded),
            label: const Text('가용 자원 재계산'),
          ),
        ],
      ),
    );
  }
}

class _DispatchIssueBanner extends StatelessWidget {
  const _DispatchIssueBanner({required this.result});

  final _DispatchIssueResult result;

  @override
  Widget build(BuildContext context) {
    final carrierDelegated = result.assignmentTypeCode == 'CARRIER_DELEGATED';
    return _DispatchPanel(
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
              Icons.mark_email_read_rounded,
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
                  carrierDelegated
                      ? '${result.planNo} 운송사 배정 완료'
                      : '${result.planNo} 직접 배차 완료',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.graphite,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  carrierDelegated
                      ? '${result.carrierName}에 운송을 배정했습니다. 차량/기사 배차는 운송사 책임으로 위임됩니다. · ${result.routeName}'
                      : '${result.carrierName} · ${result.vehicleNo} · ${result.driverName} · ${result.routeName}',
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
          _SmallPill(
            label: carrierDelegated ? '위탁 배정' : '기사 앱 전송',
            color: carrierDelegated ? AppTheme.cyan : AppTheme.teal,
          ),
        ],
      ),
    );
  }
}

class _DispatchQueuePanel extends StatelessWidget {
  const _DispatchQueuePanel({
    required this.plans,
    required this.selectedPlanId,
    required this.onSelect,
  });

  final List<_DispatchPlan> plans;
  final int selectedPlanId;
  final ValueChanged<_DispatchPlan> onSelect;

  @override
  Widget build(BuildContext context) {
    return _DispatchPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.list_alt_rounded,
            title: '확정 상차조합 대기열',
            subtitle: '직접 배차 대상과 운송사 위탁 배정 대상을 구분합니다.',
          ),
          const SizedBox(height: 14),
          if (plans.isEmpty)
            const _EmptyState(
              icon: Icons.inbox_rounded,
              title: '조건에 맞는 배차 대기 건이 없습니다.',
              message: '상태 필터를 변경하거나 편성 화면에서 조합을 확정하세요.',
            )
          else
            for (final plan in plans) ...[
              _DispatchPlanTile(
                plan: plan,
                selected: selectedPlanId == plan.id,
                onTap: () => onSelect(plan),
              ),
              if (plan != plans.last) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _AssignmentBoard extends StatelessWidget {
  const _AssignmentBoard({
    required this.plan,
    required this.assignmentMode,
    required this.selectedCarrierId,
    required this.onCarrierSelected,
    required this.selectedVehicleId,
    required this.onVehicleSelected,
  });

  final _DispatchPlan plan;
  final String assignmentMode;
  final int selectedCarrierId;
  final ValueChanged<int> onCarrierSelected;
  final int selectedVehicleId;
  final ValueChanged<int> onVehicleSelected;

  @override
  Widget build(BuildContext context) {
    final directDispatch = assignmentMode == 'OWN_FLEET';
    final selectedCarrier = _seedCarrierQuotes.firstWhere(
      (quote) => quote.id == selectedCarrierId,
      orElse: () => _seedCarrierQuotes.first,
    );
    final selectedVehicle = _seedDispatchVehicles.firstWhere(
      (vehicle) => vehicle.id == selectedVehicleId,
      orElse: () => _seedDispatchVehicles.first,
    );

    return _DispatchPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.hub_rounded,
            title: '배정/배차 후보 선택',
            subtitle: '운송사를 선택하면 배정, 위수탁/개별차량을 선택하면 직접 배차됩니다.',
          ),
          const SizedBox(height: 14),
          _RouteBoard(plan: plan),
          const SizedBox(height: 14),
          _SelectedAssigneeSummary(
            carrierDelegated: !directDispatch,
            carrier: selectedCarrier,
            vehicle: selectedVehicle,
            plan: plan,
          ),
          const SizedBox(height: 14),
          Text(
            '통합 후보 리스트',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppTheme.graphite,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 10),
          for (final quote in _seedCarrierQuotes) ...[
            _CarrierQuoteTile(
              quote: quote,
              selected: !directDispatch && selectedCarrierId == quote.id,
              onTap: () => onCarrierSelected(quote.id),
            ),
            const SizedBox(height: 10),
          ],
          for (final vehicle in _seedDispatchVehicles) ...[
            _VehicleCandidateTile(
              vehicle: vehicle,
              selected: directDispatch && selectedVehicleId == vehicle.id,
              onTap: () => onVehicleSelected(vehicle.id),
            ),
            if (vehicle != _seedDispatchVehicles.last)
              const SizedBox(height: 10),
          ],
          const SizedBox(height: 14),
          _RuleCheckPanel(carrierDelegated: !directDispatch),
        ],
      ),
    );
  }
}

class _SelectedAssigneeSummary extends StatelessWidget {
  const _SelectedAssigneeSummary({
    required this.carrierDelegated,
    required this.carrier,
    required this.vehicle,
    required this.plan,
  });

  final bool carrierDelegated;
  final _CarrierQuote carrier;
  final _DispatchVehicle vehicle;
  final _DispatchPlan plan;

  @override
  Widget build(BuildContext context) {
    final capacityRate = plan.weightKg / vehicle.maxWeightKg;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: carrierDelegated
            ? AppTheme.cyan.withValues(alpha: 0.07)
            : AppTheme.teal.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: carrierDelegated
              ? AppTheme.cyan.withValues(alpha: 0.20)
              : AppTheme.teal.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: carrierDelegated
                    ? AppTheme.cyan.withValues(alpha: 0.22)
                    : AppTheme.teal.withValues(alpha: 0.22),
              ),
            ),
            child: Icon(
              carrierDelegated
                  ? Icons.business_center_rounded
                  : Icons.local_shipping_rounded,
              color: carrierDelegated ? AppTheme.cyan : AppTheme.teal,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  carrierDelegated
                      ? '${carrier.carrierName} 운송사 배정'
                      : '${vehicle.vehicleNo} 직접 배차',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.graphite,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  carrierDelegated
                      ? '차량/기사 배차는 운송사 책임으로 위임됩니다. SLA ${carrier.slaRate}% · 가용 ${carrier.availableVehicleCount}대'
                      : '${vehicle.driverName} · ${vehicle.vehicleType} · 적재율 ${(capacityRate * 100).toStringAsFixed(0)}% · ${vehicle.currentLocation}',
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
          _SmallPill(
            label: carrierDelegated ? '배정' : '배차',
            color: carrierDelegated ? AppTheme.cyan : AppTheme.teal,
          ),
        ],
      ),
    );
  }
}

class _DispatchCommandPanel extends StatelessWidget {
  const _DispatchCommandPanel({
    required this.plan,
    required this.assignmentMode,
    required this.vehicle,
    required this.selectedCarrierId,
    required this.onIssue,
  });

  final _DispatchPlan plan;
  final String assignmentMode;
  final _DispatchVehicle vehicle;
  final int selectedCarrierId;
  final VoidCallback onIssue;

  @override
  Widget build(BuildContext context) {
    final selectedQuote = _seedCarrierQuotes.firstWhere(
      (quote) => quote.id == selectedCarrierId,
      orElse: () => _seedCarrierQuotes.first,
    );
    final carrierDelegated = assignmentMode == 'CARRIER_DELEGATED';
    return Column(
      children: [
        _DispatchPanel(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(
                icon: carrierDelegated
                    ? Icons.business_center_rounded
                    : Icons.send_to_mobile_rounded,
                title: carrierDelegated ? '운송사 배정 상세' : '직접 배차 상세',
                subtitle: carrierDelegated
                    ? '선택한 운송사에 오더를 배정하고 배차를 위임합니다.'
                    : '선택한 위수탁/개별차량과 기사에게 직접 배차합니다.',
              ),
              const SizedBox(height: 14),
              _CommandLine(label: '운송계획', value: plan.planNo),
              _CommandLine(
                label: carrierDelegated ? '운송사' : '차량/기사',
                value: carrierDelegated
                    ? selectedQuote.carrierName
                    : '${vehicle.vehicleNo} · ${vehicle.driverName}',
              ),
              _CommandLine(
                label: '처리 방식',
                value: carrierDelegated ? '운송사 배정' : '직접 배차',
              ),
              _CommandLine(
                label: '상차',
                value: '${plan.pickupName} · ${plan.pickupWindow}',
              ),
              _CommandLine(
                label: '하차',
                value: '${plan.deliveryName} · ${plan.deliveryWindow}',
              ),
              _CommandLine(
                label: carrierDelegated ? '계약 운임' : '지급 기준',
                value: carrierDelegated
                    ? '₩${(selectedQuote.costAmount / 10000).toStringAsFixed(0)}만'
                    : '내부 정산 기준 운임 적용',
              ),
              if (carrierDelegated)
                const _CommandLine(label: '배차 권한', value: '운송사 위임'),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onIssue,
                  icon: Icon(
                    carrierDelegated
                        ? Icons.business_center_rounded
                        : Icons.send_rounded,
                  ),
                  label: Text(carrierDelegated ? '운송사 배정 발행' : '직접 배차 발행'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _DispatchPanel(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(
                icon: Icons.info_outline_rounded,
                title: '처리 기준',
                subtitle: '선택한 후보 유형에 따라 시스템 상태가 자동 결정됩니다.',
              ),
              const SizedBox(height: 14),
              _AuthorityRow(
                icon: Icons.business_center_rounded,
                label: '운송사',
                value: '선택 시 운송사 배정으로 확정하고 차량/기사 배차는 위임',
                color: AppTheme.cyan,
              ),
              const SizedBox(height: 10),
              _AuthorityRow(
                icon: Icons.local_shipping_rounded,
                label: '차량',
                value: '선택 시 직접 배차로 확정하고 기사 앱/관제 단말로 지시',
                color: AppTheme.teal,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AuthorityRow extends StatelessWidget {
  const _AuthorityRow({
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 19),
        const SizedBox(width: 10),
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.slate,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.graphite,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _DispatchPlanTile extends StatelessWidget {
  const _DispatchPlanTile({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  final _DispatchPlan plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: plan.statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      plan.statusIcon,
                      color: plan.statusColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
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
              const SizedBox(height: 8),
              Text(
                '${plan.customerName} · ${plan.routeName}',
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
                    icon: Icons.inventory_2_rounded,
                    label: '${plan.orderCount}오더',
                  ),
                  _MetaChip(
                    icon: Icons.scale_rounded,
                    label: '${plan.weightKg.toStringAsFixed(0)}kg',
                  ),
                  _MetaChip(
                    icon: Icons.schedule_rounded,
                    label: plan.timeWindow,
                  ),
                  _MetaChip(
                    icon: Icons.thermostat_rounded,
                    label: plan.temperatureLabel,
                  ),
                  _MetaChip(
                    icon: plan.assignmentIcon,
                    label: plan.assignmentLabel,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _MiniProgress(
                label: '배정 적합도 ${(plan.matchRate * 100).toStringAsFixed(0)}%',
                value: plan.matchRate,
                color: plan.matchRate >= 0.88 ? AppTheme.teal : AppTheme.amber,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteBoard extends StatelessWidget {
  const _RouteBoard({required this.plan});

  final _DispatchPlan plan;

  @override
  Widget build(BuildContext context) {
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
              Expanded(
                child: Text(
                  '운송계획 루트',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
              _SmallPill(label: plan.temperatureLabel, color: AppTheme.cyan),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _RouteStop(
                label: plan.pickupName,
                caption: plan.pickupWindow,
                index: 1,
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Color(0xFF67E8F9),
                size: 20,
              ),
              if (plan.viaName != null) ...[
                _RouteStop(label: plan.viaName!, caption: '경유', index: 2),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Color(0xFF67E8F9),
                  size: 20,
                ),
                _RouteStop(
                  label: plan.deliveryName,
                  caption: plan.deliveryWindow,
                  index: 3,
                ),
              ] else
                _RouteStop(
                  label: plan.deliveryName,
                  caption: plan.deliveryWindow,
                  index: 2,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VehicleCandidateTile extends StatelessWidget {
  const _VehicleCandidateTile({
    required this.vehicle,
    required this.selected,
    required this.onTap,
  });

  final _DispatchVehicle vehicle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: selected ? AppTheme.cyan : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? AppTheme.cyan : AppTheme.line,
                    width: 1.4,
                  ),
                ),
                child: selected
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 16,
                      )
                    : null,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${vehicle.vehicleNo} · ${vehicle.driverName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.graphite,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _MetaChip(
                          icon: Icons.local_shipping_rounded,
                          label: vehicle.vehicleType,
                        ),
                        _MetaChip(
                          icon: Icons.pin_drop_rounded,
                          label: vehicle.currentLocation,
                        ),
                        _MetaChip(
                          icon: Icons.verified_user_rounded,
                          label: '준수 ${vehicle.complianceScore}%',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _SmallPill(
                label: vehicle.statusLabel,
                color: vehicle.statusColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CarrierQuoteTile extends StatelessWidget {
  const _CarrierQuoteTile({
    required this.quote,
    required this.selected,
    required this.onTap,
  });

  final _CarrierQuote quote;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      quote.carrierName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppTheme.graphite,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  _SmallPill(label: quote.gradeLabel, color: quote.gradeColor),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '₩${(quote.costAmount / 10000).toStringAsFixed(0)}만 · SLA ${quote.slaRate}% · 가용 ${quote.availableVehicleCount}대',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.slate,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 9),
              _MiniProgress(
                label: quote.comment,
                value: quote.score,
                color: quote.score >= 0.9 ? AppTheme.teal : AppTheme.amber,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RuleCheckPanel extends StatelessWidget {
  const _RuleCheckPanel({required this.carrierDelegated});

  final bool carrierDelegated;

  @override
  Widget build(BuildContext context) {
    final checks = carrierDelegated
        ? [
            const _RuleCheck('계약 운송사', '노선/온도조건 계약 운송사만 배정합니다.', true),
            const _RuleCheck('배차 책임', '차량번호와 기사는 운송사가 확정 후 회신합니다.', true),
            const _RuleCheck(
              '추적 연동',
              '운송사 EDI 또는 기사 앱 링크 수신 대상으로 등록합니다.',
              true,
            ),
            const _RuleCheck('SLA 통제', '상하차 시간창과 패널티 기준을 배정서에 포함합니다.', true),
          ]
        : [
            const _RuleCheck('면허/보험', '기사 면허와 차량 보험이 유효합니다.', true),
            const _RuleCheck('온도 조건', '오더 조건에 맞는 차량 타입만 직접 배차합니다.', true),
            const _RuleCheck('근무시간', '기사 잔여 근무시간 6.4시간 확보', true),
            const _RuleCheck('상차 도착', '첫 상차지까지 예상 이동 42분', true),
          ];

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            carrierDelegated ? '운송사 배정 규칙' : '직접 배차 규칙',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppTheme.graphite,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 10),
          for (final check in checks) ...[
            _RuleCheckRow(check: check),
            if (check != checks.last)
              const Divider(height: 18, color: AppTheme.line),
          ],
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
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
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

class _CommandLine extends StatelessWidget {
  const _CommandLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.slate,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.graphite,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
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

class _DispatchPanel extends StatelessWidget {
  const _DispatchPanel({required this.child, this.padding = EdgeInsets.zero});

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

class _MetricCard extends StatelessWidget {
  const _MetricCard(this.metric);

  final _DispatchMetric metric;

  @override
  Widget build(BuildContext context) {
    return _DispatchPanel(
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

class _LegendChip extends StatelessWidget {
  const _LegendChip({
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

class _RouteStop extends StatelessWidget {
  const _RouteStop({
    required this.label,
    required this.caption,
    required this.index,
  });

  final String label;
  final String caption;
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              Text(
                caption,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

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
      child: Row(
        children: [
          Icon(icon, color: AppTheme.slate, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.graphite,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.slate,
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

class _DispatchMetric {
  const _DispatchMetric({
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

class _DispatchIssueResult {
  const _DispatchIssueResult({
    required this.planNo,
    required this.assignmentTypeCode,
    required this.carrierName,
    required this.routeName,
    this.vehicleNo,
    this.driverName,
  });

  final String planNo;
  final String assignmentTypeCode;
  final String carrierName;
  final String routeName;
  final String? vehicleNo;
  final String? driverName;
}

class _DispatchPlan {
  const _DispatchPlan({
    required this.id,
    required this.planNo,
    required this.customerName,
    required this.routeName,
    required this.pickupName,
    required this.deliveryName,
    required this.pickupWindow,
    required this.deliveryWindow,
    required this.orderCount,
    required this.weightKg,
    required this.volumeCbm,
    required this.temperatureCode,
    required this.timeWindow,
    required this.statusCode,
    required this.assignmentTypeCode,
    required this.riskCode,
    required this.matchRate,
    required this.recommendedVehicleId,
    required this.recommendedCarrierId,
    this.viaName,
  });

  final int id;
  final String planNo;
  final String customerName;
  final String routeName;
  final String pickupName;
  final String deliveryName;
  final String pickupWindow;
  final String deliveryWindow;
  final int orderCount;
  final double weightKg;
  final double volumeCbm;
  final String temperatureCode;
  final String timeWindow;
  final String statusCode;
  final String assignmentTypeCode;
  final String riskCode;
  final double matchRate;
  final int recommendedVehicleId;
  final int recommendedCarrierId;
  final String? viaName;

  String get temperatureLabel => switch (temperatureCode) {
    'CHILLED' => '냉장',
    'FROZEN' => '냉동',
    _ => '상온',
  };

  String get statusLabel => switch (statusCode) {
    'CARRIER_ASSIGNED' => '운송사 배정',
    'DISPATCHED' => '직접 배차완료',
    'ASSIGNING' => '배정중',
    _ => '배차대기',
  };

  Color get statusColor => switch (statusCode) {
    'CARRIER_ASSIGNED' => AppTheme.cyan,
    'DISPATCHED' => AppTheme.teal,
    'ASSIGNING' => AppTheme.cyan,
    _ => AppTheme.amber,
  };

  IconData get statusIcon => switch (statusCode) {
    'CARRIER_ASSIGNED' => Icons.business_center_rounded,
    'DISPATCHED' => Icons.task_alt_rounded,
    'ASSIGNING' => Icons.assignment_ind_rounded,
    _ => Icons.schedule_rounded,
  };

  bool get isIssued =>
      statusCode == 'DISPATCHED' || statusCode == 'CARRIER_ASSIGNED';

  bool get isOwnFleetDispatch => assignmentTypeCode == 'OWN_FLEET';

  bool get isCarrierDelegated => assignmentTypeCode == 'CARRIER_DELEGATED';

  String get assignmentLabel => isOwnFleetDispatch ? '직접 배차' : '운송사 위탁';

  IconData get assignmentIcon => isOwnFleetDispatch
      ? Icons.local_shipping_rounded
      : Icons.business_center_rounded;

  _DispatchPlan copyWith({String? statusCode, String? assignmentTypeCode}) {
    return _DispatchPlan(
      id: id,
      planNo: planNo,
      customerName: customerName,
      routeName: routeName,
      pickupName: pickupName,
      deliveryName: deliveryName,
      pickupWindow: pickupWindow,
      deliveryWindow: deliveryWindow,
      orderCount: orderCount,
      weightKg: weightKg,
      volumeCbm: volumeCbm,
      temperatureCode: temperatureCode,
      timeWindow: timeWindow,
      statusCode: statusCode ?? this.statusCode,
      assignmentTypeCode: assignmentTypeCode ?? this.assignmentTypeCode,
      riskCode: riskCode,
      matchRate: matchRate,
      recommendedVehicleId: recommendedVehicleId,
      recommendedCarrierId: recommendedCarrierId,
      viaName: viaName,
    );
  }
}

class _DispatchVehicle {
  const _DispatchVehicle({
    required this.id,
    required this.vehicleNo,
    required this.vehicleType,
    required this.driverName,
    required this.currentLocation,
    required this.maxWeightKg,
    required this.statusCode,
    required this.complianceScore,
  });

  final int id;
  final String vehicleNo;
  final String vehicleType;
  final String driverName;
  final String currentLocation;
  final double maxWeightKg;
  final String statusCode;
  final int complianceScore;

  String get statusLabel => switch (statusCode) {
    'AVAILABLE' => '배차 가능',
    'RETURNING' => '복귀 중',
    _ => '점검 필요',
  };

  Color get statusColor => switch (statusCode) {
    'AVAILABLE' => AppTheme.teal,
    'RETURNING' => AppTheme.cyan,
    _ => AppTheme.amber,
  };
}

class _CarrierQuote {
  const _CarrierQuote({
    required this.id,
    required this.carrierName,
    required this.costAmount,
    required this.slaRate,
    required this.availableVehicleCount,
    required this.score,
    required this.gradeCode,
    required this.comment,
  });

  final int id;
  final String carrierName;
  final double costAmount;
  final int slaRate;
  final int availableVehicleCount;
  final double score;
  final String gradeCode;
  final String comment;

  String get gradeLabel => switch (gradeCode) {
    'A' => '우선',
    'B' => '대체',
    _ => '주의',
  };

  Color get gradeColor => switch (gradeCode) {
    'A' => AppTheme.teal,
    'B' => AppTheme.cyan,
    _ => AppTheme.amber,
  };
}

const _seedDispatchPlans = [
  _DispatchPlan(
    id: 1,
    planNo: 'LP-20260615-001',
    customerName: '프레시온',
    routeName: '김포/평택 → 서울권',
    pickupName: '김포 콜드체인',
    viaName: '평택 콜드센터',
    deliveryName: '서울 동부센터',
    pickupWindow: '06:00-08:00',
    deliveryWindow: '10:00-14:00',
    orderCount: 4,
    weightKg: 3920,
    volumeCbm: 29.1,
    temperatureCode: 'CHILLED',
    timeWindow: '06:00-14:00',
    statusCode: 'ASSIGNING',
    assignmentTypeCode: 'CARRIER_DELEGATED',
    riskCode: 'WATCH',
    matchRate: 0.92,
    recommendedVehicleId: 1,
    recommendedCarrierId: 1,
  ),
  _DispatchPlan(
    id: 2,
    planNo: 'LP-20260615-002',
    customerName: '삼성전자',
    routeName: '수원/용인 → 부산권',
    pickupName: '수원 CDC',
    viaName: '용인 냉동창고',
    deliveryName: '부산 RDC',
    pickupWindow: '09:00-11:00',
    deliveryWindow: '18:00-22:00',
    orderCount: 3,
    weightKg: 5120,
    volumeCbm: 34.4,
    temperatureCode: 'AMBIENT',
    timeWindow: '09:00-22:00',
    statusCode: 'READY',
    assignmentTypeCode: 'OWN_FLEET',
    riskCode: 'GOOD',
    matchRate: 0.88,
    recommendedVehicleId: 2,
    recommendedCarrierId: 2,
  ),
  _DispatchPlan(
    id: 3,
    planNo: 'LP-20260615-003',
    customerName: '이마트',
    routeName: '여주/이천 → 중부권',
    pickupName: '여주 CDC',
    deliveryName: '대전 RDC',
    pickupWindow: '10:00-12:00',
    deliveryWindow: '16:00-20:00',
    orderCount: 5,
    weightKg: 4380,
    volumeCbm: 31.2,
    temperatureCode: 'AMBIENT',
    timeWindow: '10:00-20:00',
    statusCode: 'DISPATCHED',
    assignmentTypeCode: 'OWN_FLEET',
    riskCode: 'GOOD',
    matchRate: 0.95,
    recommendedVehicleId: 3,
    recommendedCarrierId: 3,
  ),
  _DispatchPlan(
    id: 4,
    planNo: 'LP-20260615-004',
    customerName: '콜드프라임',
    routeName: '용인 → 부산 냉동권',
    pickupName: '용인 냉동창고',
    deliveryName: '부산 냉동센터',
    pickupWindow: '15:00-17:00',
    deliveryWindow: '23:00-02:00',
    orderCount: 2,
    weightKg: 1760,
    volumeCbm: 14.3,
    temperatureCode: 'FROZEN',
    timeWindow: '15:00-02:00',
    statusCode: 'READY',
    assignmentTypeCode: 'CARRIER_DELEGATED',
    riskCode: 'WATCH',
    matchRate: 0.84,
    recommendedVehicleId: 4,
    recommendedCarrierId: 2,
  ),
];

const _seedDispatchVehicles = [
  _DispatchVehicle(
    id: 1,
    vehicleNo: '서울 82바 1724',
    vehicleType: '5톤 냉탑',
    driverName: '김도윤',
    currentLocation: '김포 18km',
    maxWeightKg: 5000,
    statusCode: 'AVAILABLE',
    complianceScore: 98,
  ),
  _DispatchVehicle(
    id: 2,
    vehicleNo: '경기 91사 4402',
    vehicleType: '11톤 윙바디',
    driverName: '박민준',
    currentLocation: '수원 11km',
    maxWeightKg: 11000,
    statusCode: 'AVAILABLE',
    complianceScore: 96,
  ),
  _DispatchVehicle(
    id: 3,
    vehicleNo: '인천 77아 0931',
    vehicleType: '5톤 윙바디',
    driverName: '이서진',
    currentLocation: '이천 복귀',
    maxWeightKg: 5000,
    statusCode: 'RETURNING',
    complianceScore: 94,
  ),
  _DispatchVehicle(
    id: 4,
    vehicleNo: '부산 65자 8120',
    vehicleType: '5톤 냉동탑',
    driverName: '최현우',
    currentLocation: '용인 24km',
    maxWeightKg: 5000,
    statusCode: 'AVAILABLE',
    complianceScore: 91,
  ),
];

const _seedCarrierQuotes = [
  _CarrierQuote(
    id: 1,
    carrierName: 'CJ대한통운',
    costAmount: 1640000,
    slaRate: 98,
    availableVehicleCount: 12,
    score: 0.94,
    gradeCode: 'A',
    comment: '냉장 수도권 SLA 우수, 기사 앱 응답 빠름',
  ),
  _CarrierQuote(
    id: 2,
    carrierName: '한진',
    costAmount: 1710000,
    slaRate: 96,
    availableVehicleCount: 9,
    score: 0.88,
    gradeCode: 'B',
    comment: '장거리 간선 가용성 우수, 단가 보통',
  ),
  _CarrierQuote(
    id: 3,
    carrierName: 'OO운송',
    costAmount: 1510000,
    slaRate: 91,
    availableVehicleCount: 5,
    score: 0.82,
    gradeCode: 'C',
    comment: '단가는 낮지만 야간 응답 SLA 확인 필요',
  ),
];
