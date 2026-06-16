import 'package:flutter/material.dart';

import '../../design/app_theme.dart';

enum SettlementWorkspaceTab { performance, revenue, purchase }

class PerformanceSettlementPage extends StatefulWidget {
  const PerformanceSettlementPage({
    super.key,
    this.compact = false,
    this.initialTab = SettlementWorkspaceTab.performance,
  });

  final bool compact;
  final SettlementWorkspaceTab initialTab;

  @override
  State<PerformanceSettlementPage> createState() =>
      _PerformanceSettlementPageState();
}

class _PerformanceSettlementPageState extends State<PerformanceSettlementPage> {
  late SettlementWorkspaceTab _activeTab = widget.initialTab;
  late final List<_TripPerformance> _trips = List<_TripPerformance>.from(
    _seedTripPerformances,
  );
  final Set<int> _selectedTripIds = {1, 2, 4};
  int _selectedRevenueId = 1;
  int _selectedPurchaseId = 1;
  _ActionResult? _lastAction;

  @override
  void didUpdateWidget(covariant PerformanceSettlementPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      _activeTab = widget.initialTab;
    }
  }

  List<_TripPerformance> get _selectedTrips {
    return _trips.where((trip) => _selectedTripIds.contains(trip.id)).toList();
  }

  List<_TripPerformance> get _pendingTrips {
    return _trips.where((trip) => trip.statusCode != 'CONFIRMED').toList();
  }

  int get _waitingConfirmCount {
    return _pendingTrips.length;
  }

  double get _revenueAmount {
    return _revenueSettlements.fold(0, (sum, item) => sum + item.amount);
  }

  double get _purchaseAmount {
    return _purchaseSettlements.fold(0, (sum, item) => sum + item.amount);
  }

  double get _marginAmount => _revenueAmount - _purchaseAmount;

  _RevenueSettlement get _selectedRevenue {
    return _revenueSettlements.firstWhere(
      (item) => item.id == _selectedRevenueId,
      orElse: () => _revenueSettlements.first,
    );
  }

  _PurchaseSettlement get _selectedPurchase {
    return _purchaseSettlements.firstWhere(
      (item) => item.id == _selectedPurchaseId,
      orElse: () => _purchaseSettlements.first,
    );
  }

  void _toggleTrip(_TripPerformance trip) {
    setState(() {
      if (_selectedTripIds.contains(trip.id)) {
        _selectedTripIds.remove(trip.id);
      } else {
        _selectedTripIds.add(trip.id);
      }
    });
  }

  void _confirmPerformance() {
    final targets = _selectedTrips
        .where((trip) => trip.statusCode != 'CONFIRMED')
        .toList();
    if (targets.isEmpty) {
      _showMessage('확정할 운송 실적을 선택하세요.');
      return;
    }

    setState(() {
      for (final target in targets) {
        final index = _trips.indexWhere((trip) => trip.id == target.id);
        if (index != -1) {
          _trips[index] = target.copyWith(statusCode: 'CONFIRMED');
        }
      }
      _selectedTripIds.removeAll(targets.map((target) => target.id));
      _lastAction = _ActionResult(
        title: '실적 확정 완료',
        message: '${targets.length}건의 운송 실적을 정산 가능 상태로 전환했습니다.',
        icon: Icons.fact_check_rounded,
        color: AppTheme.teal,
      );
    });
    _showMessage('${targets.length}건의 운송 실적이 확정되었습니다.');
  }

  void _createRevenueStatement() {
    final item = _selectedRevenue;
    setState(() {
      _lastAction = _ActionResult(
        title: '매출 거래명세서 생성',
        message:
            '${item.customerName} · ${item.statementNo} · ${_money(item.amount)} 청구안이 생성되었습니다.',
        icon: Icons.receipt_long_rounded,
        color: AppTheme.cyan,
      );
    });
    _showMessage('${item.customerName} 매출 거래명세서를 생성했습니다.');
  }

  void _confirmPurchaseSettlement() {
    final item = _selectedPurchase;
    setState(() {
      _lastAction = _ActionResult(
        title: '매입 정산 확정',
        message:
            '${item.payeeName} · ${item.statementNo} · ${_money(item.amount)} 지급 정산이 확정되었습니다.',
        icon: Icons.price_check_rounded,
        color: AppTheme.teal,
      );
    });
    _showMessage('${item.payeeName} 매입 정산을 확정했습니다.');
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
          _SettlementHeader(
            activeTab: _activeTab,
            onTabChanged: (tab) => setState(() => _activeTab = tab),
            onConfirmPerformance: _confirmPerformance,
            onCreateRevenue: _createRevenueStatement,
            onConfirmPurchase: _confirmPurchaseSettlement,
          ),
          const SizedBox(height: 16),
          _SettlementMetricStrip(
            waitingConfirmCount: _waitingConfirmCount,
            revenueAmount: _revenueAmount,
            purchaseAmount: _purchaseAmount,
            marginAmount: _marginAmount,
          ),
          const SizedBox(height: 16),
          if (_lastAction != null) ...[
            _ActionBanner(result: _lastAction!),
            const SizedBox(height: 16),
          ],
          switch (_activeTab) {
            SettlementWorkspaceTab.performance => _PerformanceTab(
              trips: _pendingTrips,
              selectedTripIds: _selectedTripIds,
              onToggleTrip: _toggleTrip,
              onConfirm: _confirmPerformance,
            ),
            SettlementWorkspaceTab.revenue => _RevenueSettlementTab(
              records: _revenueSettlements,
              selectedId: _selectedRevenueId,
              onSelect: (record) =>
                  setState(() => _selectedRevenueId = record.id),
              onCreateStatement: _createRevenueStatement,
            ),
            SettlementWorkspaceTab.purchase => _PurchaseSettlementTab(
              records: _purchaseSettlements,
              selectedId: _selectedPurchaseId,
              onSelect: (record) =>
                  setState(() => _selectedPurchaseId = record.id),
              onConfirm: _confirmPurchaseSettlement,
            ),
          },
        ],
      ),
    );
  }
}

class _SettlementHeader extends StatelessWidget {
  const _SettlementHeader({
    required this.activeTab,
    required this.onTabChanged,
    required this.onConfirmPerformance,
    required this.onCreateRevenue,
    required this.onConfirmPurchase,
  });

  final SettlementWorkspaceTab activeTab;
  final ValueChanged<SettlementWorkspaceTab> onTabChanged;
  final VoidCallback onConfirmPerformance;
  final VoidCallback onCreateRevenue;
  final VoidCallback onConfirmPurchase;

  @override
  Widget build(BuildContext context) {
    return _SettlementPanel(
      padding: const EdgeInsets.all(22),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
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
                    Icons.fact_check_rounded,
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
                        '실적 확정 및 정산',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: AppTheme.graphite,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '운송 완료 실적을 확정하고 고객 매출정산과 운송사/차량 매입정산을 분리 처리합니다.',
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
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _TabButton(
                selected: activeTab == SettlementWorkspaceTab.performance,
                label: '실적확정',
                icon: Icons.fact_check_rounded,
                onTap: () => onTabChanged(SettlementWorkspaceTab.performance),
              ),
              _TabButton(
                selected: activeTab == SettlementWorkspaceTab.revenue,
                label: '매출정산',
                icon: Icons.request_quote_rounded,
                onTap: () => onTabChanged(SettlementWorkspaceTab.revenue),
              ),
              _TabButton(
                selected: activeTab == SettlementWorkspaceTab.purchase,
                label: '매입정산',
                icon: Icons.payments_rounded,
                onTap: () => onTabChanged(SettlementWorkspaceTab.purchase),
              ),
              _HeaderActionButton(
                activeTab: activeTab,
                onConfirmPerformance: onConfirmPerformance,
                onCreateRevenue: onCreateRevenue,
                onConfirmPurchase: onConfirmPurchase,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({
    required this.activeTab,
    required this.onConfirmPerformance,
    required this.onCreateRevenue,
    required this.onConfirmPurchase,
  });

  final SettlementWorkspaceTab activeTab;
  final VoidCallback onConfirmPerformance;
  final VoidCallback onCreateRevenue;
  final VoidCallback onConfirmPurchase;

  @override
  Widget build(BuildContext context) {
    final label = switch (activeTab) {
      SettlementWorkspaceTab.performance => '선택 실적 확정',
      SettlementWorkspaceTab.revenue => '매출 거래명세서 생성',
      SettlementWorkspaceTab.purchase => '매입 정산 확정',
    };
    final icon = switch (activeTab) {
      SettlementWorkspaceTab.performance => Icons.task_alt_rounded,
      SettlementWorkspaceTab.revenue => Icons.receipt_long_rounded,
      SettlementWorkspaceTab.purchase => Icons.price_check_rounded,
    };
    final onPressed = switch (activeTab) {
      SettlementWorkspaceTab.performance => onConfirmPerformance,
      SettlementWorkspaceTab.revenue => onCreateRevenue,
      SettlementWorkspaceTab.purchase => onConfirmPurchase,
    };
    return SizedBox(
      width: 210,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}

class _SettlementMetricStrip extends StatelessWidget {
  const _SettlementMetricStrip({
    required this.waitingConfirmCount,
    required this.revenueAmount,
    required this.purchaseAmount,
    required this.marginAmount,
  });

  final int waitingConfirmCount;
  final double revenueAmount;
  final double purchaseAmount;
  final double marginAmount;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _SettlementMetric(
        label: '실적확정 대기',
        value: '$waitingConfirmCount건',
        detail: 'POD/온도/도착 검증',
        icon: Icons.fact_check_rounded,
        color: AppTheme.teal,
      ),
      _SettlementMetric(
        label: '매출정산',
        value: _money(revenueAmount),
        detail: '고객 청구 대상',
        icon: Icons.request_quote_rounded,
        color: AppTheme.cyan,
      ),
      _SettlementMetric(
        label: '매입정산',
        value: _money(purchaseAmount),
        detail: '운송사/차량 지급',
        icon: Icons.payments_rounded,
        color: const Color(0xFF2563EB),
      ),
      _SettlementMetric(
        label: '예상 마진',
        value: _money(marginAmount),
        detail: '매출 - 매입',
        icon: Icons.trending_up_rounded,
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
                (metric) => SizedBox(width: width, child: _MetricCard(metric)),
              )
              .toList(),
        );
      },
    );
  }
}

class _ActionBanner extends StatelessWidget {
  const _ActionBanner({required this.result});

  final _ActionResult result;

  @override
  Widget build(BuildContext context) {
    return _SettlementPanel(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: result.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(result.icon, color: result.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.graphite,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  result.message,
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
          _SmallPill(label: '완료', color: result.color),
        ],
      ),
    );
  }
}

class _PerformanceTab extends StatelessWidget {
  const _PerformanceTab({
    required this.trips,
    required this.selectedTripIds,
    required this.onToggleTrip,
    required this.onConfirm,
  });

  final List<_TripPerformance> trips;
  final Set<int> selectedTripIds;
  final ValueChanged<_TripPerformance> onToggleTrip;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1180;
        final list = _SettlementPanel(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(
                icon: Icons.task_alt_rounded,
                title: '운송 실적 확정',
                subtitle: '확정 대기 오더의 POD, 도착시간, 온도 로그, 차이를 검증합니다.',
              ),
              const SizedBox(height: 14),
              if (trips.isEmpty)
                const _EmptyPendingPerformance()
              else
                for (final trip in trips) ...[
                  _TripPerformanceTile(
                    trip: trip,
                    selected: selectedTripIds.contains(trip.id),
                    onTap: () => onToggleTrip(trip),
                  ),
                  if (trip != trips.last) const SizedBox(height: 10),
                ],
            ],
          ),
        );
        final detail = _PerformanceAuditPanel(onConfirm: onConfirm);
        if (!wide) {
          return Column(children: [list, const SizedBox(height: 16), detail]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 13, child: list),
            const SizedBox(width: 16),
            Expanded(flex: 9, child: detail),
          ],
        );
      },
    );
  }
}

class _EmptyPendingPerformance extends StatelessWidget {
  const _EmptyPendingPerformance();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.teal.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.teal.withValues(alpha: 0.18)),
      ),
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
              Icons.done_all_rounded,
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
                  '확정 대기 실적이 없습니다',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.graphite,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '선택한 운송 실적은 매출정산과 매입정산 대상으로 이동했습니다.',
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

class _RevenueSettlementTab extends StatelessWidget {
  const _RevenueSettlementTab({
    required this.records,
    required this.selectedId,
    required this.onSelect,
    required this.onCreateStatement,
  });

  final List<_RevenueSettlement> records;
  final int selectedId;
  final ValueChanged<_RevenueSettlement> onSelect;
  final VoidCallback onCreateStatement;

  @override
  Widget build(BuildContext context) {
    final selected = records.firstWhere(
      (record) => record.id == selectedId,
      orElse: () => records.first,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1180;
        final list = _SettlementPanel(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(
                icon: Icons.request_quote_rounded,
                title: '매출정산',
                subtitle: '고객사별 청구 운임, 부대비, 세금계산서 대상을 확정합니다.',
              ),
              const SizedBox(height: 14),
              for (final record in records) ...[
                _RevenueSettlementTile(
                  record: record,
                  selected: selectedId == record.id,
                  onTap: () => onSelect(record),
                ),
                if (record != records.last) const SizedBox(height: 10),
              ],
            ],
          ),
        );
        final detail = _RevenueDetailPanel(
          record: selected,
          onCreateStatement: onCreateStatement,
        );
        if (!wide) {
          return Column(children: [list, const SizedBox(height: 16), detail]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 12, child: list),
            const SizedBox(width: 16),
            Expanded(flex: 9, child: detail),
          ],
        );
      },
    );
  }
}

class _PurchaseSettlementTab extends StatelessWidget {
  const _PurchaseSettlementTab({
    required this.records,
    required this.selectedId,
    required this.onSelect,
    required this.onConfirm,
  });

  final List<_PurchaseSettlement> records;
  final int selectedId;
  final ValueChanged<_PurchaseSettlement> onSelect;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final selected = records.firstWhere(
      (record) => record.id == selectedId,
      orElse: () => records.first,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1180;
        final list = _SettlementPanel(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(
                icon: Icons.payments_rounded,
                title: '매입정산',
                subtitle: '운송사 위탁비, 위수탁/개별차량 지급액, 패널티를 확정합니다.',
              ),
              const SizedBox(height: 14),
              for (final record in records) ...[
                _PurchaseSettlementTile(
                  record: record,
                  selected: selectedId == record.id,
                  onTap: () => onSelect(record),
                ),
                if (record != records.last) const SizedBox(height: 10),
              ],
            ],
          ),
        );
        final detail = _PurchaseDetailPanel(
          record: selected,
          onConfirm: onConfirm,
        );
        if (!wide) {
          return Column(children: [list, const SizedBox(height: 16), detail]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 12, child: list),
            const SizedBox(width: 16),
            Expanded(flex: 9, child: detail),
          ],
        );
      },
    );
  }
}

class _TripPerformanceTile extends StatelessWidget {
  const _TripPerformanceTile({
    required this.trip,
    required this.selected,
    required this.onTap,
  });

  final _TripPerformance trip;
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
                            trip.orderNo,
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
                        _SmallPill(
                          label: trip.statusLabel,
                          color: trip.statusColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${trip.customerName} · ${trip.routeName}',
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
                          icon: Icons.flag_rounded,
                          label: trip.departureTime,
                        ),
                        _MetaChip(
                          icon: Icons.pin_drop_rounded,
                          label: trip.arrivalTime,
                        ),
                        _MetaChip(
                          icon: Icons.receipt_long_rounded,
                          label: trip.podStatus,
                        ),
                        _MetaChip(
                          icon: Icons.thermostat_rounded,
                          label: trip.temperatureStatus,
                        ),
                        _MetaChip(
                          icon: Icons.payments_rounded,
                          label: _money(trip.revenueAmount),
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

class _PerformanceAuditPanel extends StatelessWidget {
  const _PerformanceAuditPanel({required this.onConfirm});

  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final checks = [
      const _CheckItem('POD 수신', '전자서명 24건, 사진 POD 3건 정상 수신', true),
      const _CheckItem('도착 실적', '지연 허용범위 초과 1건은 패널티 후보 표시', true),
      const _CheckItem('온도 로그', '냉장/냉동 운송 8건 온도 이탈 없음', true),
      const _CheckItem('운임 차이', '수작업 조정 2건 승인 필요', false),
    ];
    return _SettlementPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.verified_rounded,
            title: 'POD/온도/도착 실적',
            subtitle: '정산 전 필수 증빙과 차이를 검증합니다.',
          ),
          const SizedBox(height: 14),
          for (final check in checks) ...[
            _CheckRow(item: check),
            if (check != checks.last)
              const Divider(height: 18, color: AppTheme.line),
          ],
          const SizedBox(height: 14),
          _SettlementNotice(
            icon: Icons.rule_rounded,
            title: '확정 기준',
            message: '실적 확정 후 매출정산과 매입정산 대상에 반영되며, 이후 운임 변경은 정산 조정으로 관리합니다.',
            color: AppTheme.cyan,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onConfirm,
              icon: const Icon(Icons.task_alt_rounded),
              label: const Text('선택 실적 확정'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RevenueSettlementTile extends StatelessWidget {
  const _RevenueSettlementTile({
    required this.record,
    required this.selected,
    required this.onTap,
  });

  final _RevenueSettlement record;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SettlementRecordTile(
      selected: selected,
      onTap: onTap,
      leadingIcon: Icons.request_quote_rounded,
      leadingColor: AppTheme.cyan,
      title: record.statementNo,
      subtitle: '${record.customerName} · ${record.period}',
      amount: _money(record.amount),
      statusLabel: record.statusLabel,
      statusColor: record.statusColor,
      chips: [
        _MetaChip(
          icon: Icons.inventory_2_rounded,
          label: '${record.orderCount}건',
        ),
        _MetaChip(
          icon: Icons.add_card_rounded,
          label: '부대비 ${_money(record.extraCharge)}',
        ),
        _MetaChip(icon: Icons.percent_rounded, label: 'VAT 별도'),
      ],
    );
  }
}

class _PurchaseSettlementTile extends StatelessWidget {
  const _PurchaseSettlementTile({
    required this.record,
    required this.selected,
    required this.onTap,
  });

  final _PurchaseSettlement record;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SettlementRecordTile(
      selected: selected,
      onTap: onTap,
      leadingIcon: record.payeeTypeCode == 'CARRIER'
          ? Icons.business_center_rounded
          : Icons.local_shipping_rounded,
      leadingColor: record.payeeTypeCode == 'CARRIER'
          ? AppTheme.cyan
          : AppTheme.teal,
      title: record.statementNo,
      subtitle: '${record.payeeName} · ${record.period}',
      amount: _money(record.amount),
      statusLabel: record.statusLabel,
      statusColor: record.statusColor,
      chips: [
        _MetaChip(
          icon: Icons.inventory_2_rounded,
          label: '${record.orderCount}건',
        ),
        _MetaChip(
          icon: Icons.remove_circle_outline_rounded,
          label: '공제 ${_money(record.deductionAmount)}',
        ),
        _MetaChip(
          icon: Icons.calendar_month_rounded,
          label: record.paymentDueDate,
        ),
      ],
    );
  }
}

class _SettlementRecordTile extends StatelessWidget {
  const _SettlementRecordTile({
    required this.selected,
    required this.onTap,
    required this.leadingIcon,
    required this.leadingColor,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.statusLabel,
    required this.statusColor,
    required this.chips,
  });

  final bool selected;
  final VoidCallback onTap;
  final IconData leadingIcon;
  final Color leadingColor;
  final String title;
  final String subtitle;
  final String amount;
  final String statusLabel;
  final Color statusColor;
  final List<Widget> chips;

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
                ? leadingColor.withValues(alpha: 0.08)
                : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? leadingColor.withValues(alpha: 0.35)
                  : AppTheme.line,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: leadingColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(leadingIcon, color: leadingColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
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
                        _SmallPill(label: statusLabel, color: statusColor),
                      ],
                    ),
                    const SizedBox(height: 4),
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
                    const SizedBox(height: 8),
                    Text(
                      amount,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.graphite,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 6, children: chips),
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

class _RevenueDetailPanel extends StatelessWidget {
  const _RevenueDetailPanel({
    required this.record,
    required this.onCreateStatement,
  });

  final _RevenueSettlement record;
  final VoidCallback onCreateStatement;

  @override
  Widget build(BuildContext context) {
    return _SettlementPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.receipt_long_rounded,
            title: '매출 거래명세서',
            subtitle: '고객 청구 항목과 세금계산서 발행 전 차이를 확인합니다.',
          ),
          const SizedBox(height: 14),
          _AmountLine(label: '기본 운임', value: _money(record.baseFare)),
          _AmountLine(label: '부대비', value: _money(record.extraCharge)),
          _AmountLine(label: '패널티/조정', value: _money(record.adjustmentAmount)),
          const Divider(height: 22, color: AppTheme.line),
          _AmountLine(
            label: '청구 합계',
            value: _money(record.amount),
            strong: true,
          ),
          const SizedBox(height: 14),
          _SettlementNotice(
            icon: Icons.mail_rounded,
            title: '고객 발행 대상',
            message:
                '${record.customerName} 정산 담당자에게 거래명세서와 세금계산서 발행 전표가 연결됩니다.',
            color: AppTheme.cyan,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onCreateStatement,
              icon: const Icon(Icons.receipt_long_rounded),
              label: const Text('매출 거래명세서 생성'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PurchaseDetailPanel extends StatelessWidget {
  const _PurchaseDetailPanel({required this.record, required this.onConfirm});

  final _PurchaseSettlement record;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return _SettlementPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.price_check_rounded,
            title: '매입 지급 정산',
            subtitle: '운송사/차량 지급액, 공제, 패널티, 지급예정일을 확인합니다.',
          ),
          const SizedBox(height: 14),
          _AmountLine(label: '계약 운임', value: _money(record.baseCost)),
          _AmountLine(label: '추가 지급', value: _money(record.extraCost)),
          _AmountLine(
            label: '공제/패널티',
            value: '-${_money(record.deductionAmount)}',
          ),
          const Divider(height: 22, color: AppTheme.line),
          _AmountLine(
            label: '지급 합계',
            value: _money(record.amount),
            strong: true,
          ),
          const SizedBox(height: 14),
          _SettlementNotice(
            icon: record.payeeTypeCode == 'CARRIER'
                ? Icons.business_center_rounded
                : Icons.local_shipping_rounded,
            title: record.payeeTypeCode == 'CARRIER' ? '운송사 지급' : '위수탁/개별차량 지급',
            message:
                '${record.payeeName} 지급예정일은 ${record.paymentDueDate}이며, 확정 후 지급 전표로 연결됩니다.',
            color: record.payeeTypeCode == 'CARRIER'
                ? AppTheme.cyan
                : AppTheme.teal,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onConfirm,
              icon: const Icon(Icons.price_check_rounded),
              label: const Text('매입 정산 확정'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountLine extends StatelessWidget {
  const _AmountLine({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: strong ? AppTheme.graphite : AppTheme.slate,
                fontWeight: strong ? FontWeight.w900 : FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: strong ? AppTheme.teal : AppTheme.graphite,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettlementNotice extends StatelessWidget {
  const _SettlementNotice({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.graphite,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.slate,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                    height: 1.32,
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

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.item});

  final _CheckItem item;

  @override
  Widget build(BuildContext context) {
    final color = item.passed ? AppTheme.teal : AppTheme.amber;
    return Row(
      children: [
        Icon(
          item.passed
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
                item.title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.graphite,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              Text(
                item.description,
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

class _SettlementPanel extends StatelessWidget {
  const _SettlementPanel({required this.child, this.padding = EdgeInsets.zero});

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

class _MetricCard extends StatelessWidget {
  const _MetricCard(this.metric);

  final _SettlementMetric metric;

  @override
  Widget build(BuildContext context) {
    return _SettlementPanel(
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

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.selected,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: onTap,
      avatar: Icon(
        icon,
        color: selected ? Colors.white : AppTheme.teal,
        size: 18,
      ),
      label: Text(label),
      backgroundColor: selected ? AppTheme.teal : Colors.white,
      side: BorderSide(color: selected ? AppTheme.teal : AppTheme.line),
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppTheme.graphite,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
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

class _SettlementMetric {
  const _SettlementMetric({
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

class _ActionResult {
  const _ActionResult({
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
  });

  final String title;
  final String message;
  final IconData icon;
  final Color color;
}

class _CheckItem {
  const _CheckItem(this.title, this.description, this.passed);

  final String title;
  final String description;
  final bool passed;
}

class _TripPerformance {
  const _TripPerformance({
    required this.id,
    required this.orderNo,
    required this.customerName,
    required this.routeName,
    required this.departureTime,
    required this.arrivalTime,
    required this.podStatus,
    required this.temperatureStatus,
    required this.revenueAmount,
    required this.statusCode,
  });

  final int id;
  final String orderNo;
  final String customerName;
  final String routeName;
  final String departureTime;
  final String arrivalTime;
  final String podStatus;
  final String temperatureStatus;
  final double revenueAmount;
  final String statusCode;

  String get statusLabel => statusCode == 'CONFIRMED' ? '확정' : '확정대기';

  Color get statusColor =>
      statusCode == 'CONFIRMED' ? AppTheme.teal : AppTheme.amber;

  _TripPerformance copyWith({String? statusCode}) {
    return _TripPerformance(
      id: id,
      orderNo: orderNo,
      customerName: customerName,
      routeName: routeName,
      departureTime: departureTime,
      arrivalTime: arrivalTime,
      podStatus: podStatus,
      temperatureStatus: temperatureStatus,
      revenueAmount: revenueAmount,
      statusCode: statusCode ?? this.statusCode,
    );
  }
}

class _RevenueSettlement {
  const _RevenueSettlement({
    required this.id,
    required this.statementNo,
    required this.customerName,
    required this.period,
    required this.orderCount,
    required this.baseFare,
    required this.extraCharge,
    required this.adjustmentAmount,
    required this.amount,
    required this.statusCode,
  });

  final int id;
  final String statementNo;
  final String customerName;
  final String period;
  final int orderCount;
  final double baseFare;
  final double extraCharge;
  final double adjustmentAmount;
  final double amount;
  final String statusCode;

  String get statusLabel => switch (statusCode) {
    'ISSUED' => '발행',
    'REVIEW' => '검토',
    _ => '작성중',
  };

  Color get statusColor => switch (statusCode) {
    'ISSUED' => AppTheme.teal,
    'REVIEW' => AppTheme.amber,
    _ => AppTheme.cyan,
  };
}

class _PurchaseSettlement {
  const _PurchaseSettlement({
    required this.id,
    required this.statementNo,
    required this.payeeName,
    required this.payeeTypeCode,
    required this.period,
    required this.orderCount,
    required this.baseCost,
    required this.extraCost,
    required this.deductionAmount,
    required this.amount,
    required this.paymentDueDate,
    required this.statusCode,
  });

  final int id;
  final String statementNo;
  final String payeeName;
  final String payeeTypeCode;
  final String period;
  final int orderCount;
  final double baseCost;
  final double extraCost;
  final double deductionAmount;
  final double amount;
  final String paymentDueDate;
  final String statusCode;

  String get statusLabel => switch (statusCode) {
    'CONFIRMED' => '확정',
    'REVIEW' => '검토',
    _ => '작성중',
  };

  Color get statusColor => switch (statusCode) {
    'CONFIRMED' => AppTheme.teal,
    'REVIEW' => AppTheme.amber,
    _ => AppTheme.cyan,
  };
}

String _money(double amount) => '₩${(amount / 10000).toStringAsFixed(0)}만';

const _seedTripPerformances = [
  _TripPerformance(
    id: 1,
    orderNo: 'KT-20260615-0001',
    customerName: '삼성전자',
    routeName: '수원 CDC → 부산 RDC',
    departureTime: '09:18 출발',
    arrivalTime: '20:42 도착',
    podStatus: 'POD 수신',
    temperatureStatus: '상온',
    revenueAmount: 1280000,
    statusCode: 'READY',
  ),
  _TripPerformance(
    id: 2,
    orderNo: 'KT-20260615-0002',
    customerName: '프레시온',
    routeName: '김포 콜드체인 → 서울 동부센터',
    departureTime: '06:21 출발',
    arrivalTime: '11:04 도착',
    podStatus: '전자서명',
    temperatureStatus: '냉장 정상',
    revenueAmount: 740000,
    statusCode: 'READY',
  ),
  _TripPerformance(
    id: 3,
    orderNo: 'KT-20260615-0003',
    customerName: 'K패션',
    routeName: '인천 반품센터 → 이천 물류센터',
    departureTime: '13:12 출발',
    arrivalTime: '18:03 도착',
    podStatus: '사진 POD',
    temperatureStatus: '상온',
    revenueAmount: 390000,
    statusCode: 'CONFIRMED',
  ),
  _TripPerformance(
    id: 4,
    orderNo: 'KT-20260615-0004',
    customerName: '신세계푸드',
    routeName: '평택 콜드센터 → 강남 점포권',
    departureTime: '07:34 출발',
    arrivalTime: '12:19 도착',
    podStatus: 'POD 수신',
    temperatureStatus: '냉장 정상',
    revenueAmount: 560000,
    statusCode: 'READY',
  ),
];

const _revenueSettlements = [
  _RevenueSettlement(
    id: 1,
    statementNo: 'AR-20260615-001',
    customerName: '삼성전자',
    period: '2026-06-01 ~ 2026-06-15',
    orderCount: 42,
    baseFare: 38400000,
    extraCharge: 2160000,
    adjustmentAmount: -480000,
    amount: 40080000,
    statusCode: 'DRAFT',
  ),
  _RevenueSettlement(
    id: 2,
    statementNo: 'AR-20260615-002',
    customerName: '프레시온',
    period: '2026-06-01 ~ 2026-06-15',
    orderCount: 31,
    baseFare: 21800000,
    extraCharge: 1320000,
    adjustmentAmount: 0,
    amount: 23120000,
    statusCode: 'REVIEW',
  ),
  _RevenueSettlement(
    id: 3,
    statementNo: 'AR-20260615-003',
    customerName: '이마트',
    period: '2026-06-01 ~ 2026-06-15',
    orderCount: 28,
    baseFare: 17300000,
    extraCharge: 920000,
    adjustmentAmount: -210000,
    amount: 18010000,
    statusCode: 'ISSUED',
  ),
];

const _purchaseSettlements = [
  _PurchaseSettlement(
    id: 1,
    statementNo: 'AP-20260615-001',
    payeeName: 'CJ대한통운',
    payeeTypeCode: 'CARRIER',
    period: '2026-06-01 ~ 2026-06-15',
    orderCount: 38,
    baseCost: 29100000,
    extraCost: 1180000,
    deductionAmount: 320000,
    amount: 29960000,
    paymentDueDate: '2026-06-30',
    statusCode: 'REVIEW',
  ),
  _PurchaseSettlement(
    id: 2,
    statementNo: 'AP-20260615-002',
    payeeName: '서울 82바 1724 · 김도윤',
    payeeTypeCode: 'OWN_FLEET',
    period: '2026-06-01 ~ 2026-06-15',
    orderCount: 17,
    baseCost: 9840000,
    extraCost: 460000,
    deductionAmount: 0,
    amount: 10300000,
    paymentDueDate: '2026-06-25',
    statusCode: 'DRAFT',
  ),
  _PurchaseSettlement(
    id: 3,
    statementNo: 'AP-20260615-003',
    payeeName: '한진',
    payeeTypeCode: 'CARRIER',
    period: '2026-06-01 ~ 2026-06-15',
    orderCount: 26,
    baseCost: 18800000,
    extraCost: 740000,
    deductionAmount: 610000,
    amount: 18930000,
    paymentDueDate: '2026-06-30',
    statusCode: 'CONFIRMED',
  ),
];
