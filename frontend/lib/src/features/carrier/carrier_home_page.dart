import 'package:flutter/material.dart';

import '../../design/app_theme.dart';
import '../../design/ktms_mark.dart';
import '../tms/master_api.dart';

class CarrierHomePage extends StatefulWidget {
  const CarrierHomePage({
    required this.displayName,
    required this.email,
    required this.onSignOut,
    this.carrierName = 'CJ대한통운',
    super.key,
  });

  final String displayName;
  final String email;
  final String carrierName;
  final VoidCallback onSignOut;

  @override
  State<CarrierHomePage> createState() => _CarrierHomePageState();
}

class _CarrierHomePageState extends State<CarrierHomePage> {
  late final List<_CarrierAssignment> _assignments = List.from(
    _seedCarrierAssignments,
  );

  int _selectedIndex = 0;
  int _selectedAssignmentId = 1;
  int _selectedVehicleId = 101;
  bool _busy = false;
  _CarrierDispatchResult? _lastResult;

  _CarrierAssignment get _selectedAssignment {
    return _assignments.firstWhere(
      (assignment) => assignment.id == _selectedAssignmentId,
      orElse: () => _assignments.first,
    );
  }

  _CarrierVehicle get _selectedVehicle {
    return _seedCarrierVehicles.firstWhere(
      (vehicle) => vehicle.id == _selectedVehicleId,
      orElse: () => _seedCarrierVehicles.first,
    );
  }

  int get _waitingCount {
    return _assignments.where((assignment) => !assignment.isConfirmed).length;
  }

  int get _confirmedCount {
    return _assignments.where((assignment) => assignment.isConfirmed).length;
  }

  void _selectAssignment(_CarrierAssignment assignment) {
    setState(() => _selectedAssignmentId = assignment.id);
  }

  Future<void> _confirmDispatch() async {
    if (_busy) {
      return;
    }

    final assignment = _selectedAssignment;
    final vehicle = _selectedVehicle;
    setState(() => _busy = true);

    final vehicleResult = await MasterApi.instance.saveVehicle(
      vehicle.toVehiclePayload(widget.carrierName, assignment.planNo),
    );
    final driverResult = await MasterApi.instance.saveDriver(
      vehicle.toDriverPayload(widget.carrierName),
    );
    final dispatchResult = await MasterApi.instance.confirmCarrierDispatch({
      'carrier_name': widget.carrierName,
      'manager_name': widget.displayName,
      'manager_email': widget.email,
      'plan_no': assignment.planNo,
      'tender_no': assignment.tenderNo,
      'vehicle_code': vehicle.vehicleCode,
      'vehicle_no': vehicle.vehicleNo,
      'vehicle_type': vehicle.vehicleType,
      'driver_code': vehicle.driverCode,
      'driver_name': vehicle.driverName,
      'driver_phone': vehicle.driverPhone,
      'driver_email': vehicle.driverEmail,
      'offered_amount': assignment.offeredAmount,
      'currency_code': 'KRW',
      'instructions': '${assignment.pickupName} ${assignment.pickupWindow} 상차',
      'latitude': assignment.latitude,
      'longitude': assignment.longitude,
      'location_text': '${assignment.pickupName} → ${assignment.deliveryName}',
      'metadata': {
        'app': 'ktms_carrier',
        'carrier_manager_email': widget.email,
        'route': assignment.routeName,
      },
    });

    if (!mounted) {
      return;
    }

    setState(() {
      _busy = false;
      final index = _assignments.indexWhere((item) => item.id == assignment.id);
      if (index != -1) {
        _assignments[index] = assignment.copyWith(
          statusCode: 'DISPATCH_CONFIRMED',
          confirmedVehicleNo: vehicle.vehicleNo,
          confirmedDriverName: vehicle.driverName,
        );
      }
      _lastResult = _CarrierDispatchResult(
        planNo: assignment.planNo,
        vehicleNo: vehicle.vehicleNo,
        driverName: vehicle.driverName,
        persisted:
            dispatchResult.persisted ||
            vehicleResult.persisted ||
            driverResult.persisted,
      );
    });

    final message = dispatchResult.persisted
        ? '${assignment.planNo} 배차 확정이 DB에 저장되었습니다.'
        : '${assignment.planNo} 배차 화면은 확정됐지만 DB 저장을 확인하지 못했습니다.';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 760;

    return Scaffold(
      backgroundColor: AppTheme.panel,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        titleSpacing: 16,
        title: const Row(
          children: [
            KtmsMark(size: 34),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'KTMS Carrier',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppTheme.graphite,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '알림',
            onPressed: () => setState(() => _selectedIndex = 3),
            icon: Badge(
              label: Text('$_waitingCount'),
              child: const Icon(Icons.notifications_none_rounded),
            ),
          ),
          IconButton(
            tooltip: '로그아웃',
            onPressed: widget.onSignOut,
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: _CarrierWorkspace(
          selectedIndex: _selectedIndex,
          compact: compact,
          carrierName: widget.carrierName,
          displayName: widget.displayName,
          email: widget.email,
          waitingCount: _waitingCount,
          confirmedCount: _confirmedCount,
          assignments: _assignments,
          selectedAssignment: _selectedAssignment,
          selectedVehicle: _selectedVehicle,
          selectedVehicleId: _selectedVehicleId,
          lastResult: _lastResult,
          busy: _busy,
          onSelect: (index) => setState(() => _selectedIndex = index),
          onAssignmentSelected: _selectAssignment,
          onVehicleSelected: (id) => setState(() => _selectedVehicleId = id),
          onConfirmDispatch: _confirmDispatch,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        height: 68,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: '홈',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_turned_in_outlined),
            selectedIcon: Icon(Icons.assignment_turned_in_rounded),
            label: '배차',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined),
            selectedIcon: Icon(Icons.local_shipping_rounded),
            label: '차량',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none_rounded),
            selectedIcon: Icon(Icons.notifications_rounded),
            label: '알림',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: '정산',
          ),
        ],
      ),
    );
  }
}

class _CarrierWorkspace extends StatelessWidget {
  const _CarrierWorkspace({
    required this.selectedIndex,
    required this.compact,
    required this.carrierName,
    required this.displayName,
    required this.email,
    required this.waitingCount,
    required this.confirmedCount,
    required this.assignments,
    required this.selectedAssignment,
    required this.selectedVehicle,
    required this.selectedVehicleId,
    required this.lastResult,
    required this.busy,
    required this.onSelect,
    required this.onAssignmentSelected,
    required this.onVehicleSelected,
    required this.onConfirmDispatch,
  });

  final int selectedIndex;
  final bool compact;
  final String carrierName;
  final String displayName;
  final String email;
  final int waitingCount;
  final int confirmedCount;
  final List<_CarrierAssignment> assignments;
  final _CarrierAssignment selectedAssignment;
  final _CarrierVehicle selectedVehicle;
  final int selectedVehicleId;
  final _CarrierDispatchResult? lastResult;
  final bool busy;
  final ValueChanged<int> onSelect;
  final ValueChanged<_CarrierAssignment> onAssignmentSelected;
  final ValueChanged<int> onVehicleSelected;
  final Future<void> Function() onConfirmDispatch;

  @override
  Widget build(BuildContext context) {
    final padding = compact
        ? const EdgeInsets.fromLTRB(16, 14, 16, 18)
        : const EdgeInsets.fromLTRB(28, 22, 28, 26);

    return SingleChildScrollView(
      padding: padding,
      child: switch (selectedIndex) {
        1 => _CarrierDispatchScreen(
          assignments: assignments,
          selectedAssignment: selectedAssignment,
          selectedVehicleId: selectedVehicleId,
          busy: busy,
          onAssignmentSelected: onAssignmentSelected,
          onVehicleSelected: onVehicleSelected,
          onConfirmDispatch: onConfirmDispatch,
        ),
        2 => const _CarrierFleetScreen(),
        3 => _CarrierAlertScreen(
          waitingCount: waitingCount,
          onDispatchTap: () => onSelect(1),
        ),
        4 => _CarrierSettlementScreen(carrierName: carrierName),
        _ => _CarrierDashboard(
          carrierName: carrierName,
          displayName: displayName,
          email: email,
          waitingCount: waitingCount,
          confirmedCount: confirmedCount,
          selectedAssignment: selectedAssignment,
          selectedVehicle: selectedVehicle,
          lastResult: lastResult,
          busy: busy,
          onDispatchTap: () => onSelect(1),
          onFleetTap: () => onSelect(2),
          onConfirmDispatch: onConfirmDispatch,
        ),
      },
    );
  }
}

class _CarrierDashboard extends StatelessWidget {
  const _CarrierDashboard({
    required this.carrierName,
    required this.displayName,
    required this.email,
    required this.waitingCount,
    required this.confirmedCount,
    required this.selectedAssignment,
    required this.selectedVehicle,
    required this.lastResult,
    required this.busy,
    required this.onDispatchTap,
    required this.onFleetTap,
    required this.onConfirmDispatch,
  });

  final String carrierName;
  final String displayName;
  final String email;
  final int waitingCount;
  final int confirmedCount;
  final _CarrierAssignment selectedAssignment;
  final _CarrierVehicle selectedVehicle;
  final _CarrierDispatchResult? lastResult;
  final bool busy;
  final VoidCallback onDispatchTap;
  final VoidCallback onFleetTap;
  final Future<void> Function() onConfirmDispatch;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CarrierHeader(
          title: '$carrierName 담당자',
          subtitle: '$displayName · $email',
          trailing: _StatusPill(
            icon: Icons.verified_rounded,
            label: '계약',
            color: AppTheme.teal,
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 720;
            final cards = [
              _MetricCard(
                icon: Icons.assignment_late_rounded,
                label: '위탁 배정',
                value: '$waitingCount건',
                detail: '배차 확정 대기',
                color: AppTheme.amber,
              ),
              _MetricCard(
                icon: Icons.task_alt_rounded,
                label: '확정',
                value: '$confirmedCount건',
                detail: '오늘 배차 회신',
                color: AppTheme.teal,
              ),
              _MetricCard(
                icon: Icons.local_shipping_rounded,
                label: '가용 차량',
                value: '6대',
                detail: '냉장 2 · 윙바디 4',
                color: AppTheme.cyan,
              ),
            ];

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: cards
                  .map(
                    (card) => SizedBox(
                      width: wide
                          ? (constraints.maxWidth - 24) / 3
                          : constraints.maxWidth,
                      child: card,
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 14),
        if (lastResult != null) ...[
          _CarrierSection(
            title: '최근 확정',
            child: _ResultTile(result: lastResult!),
          ),
          const SizedBox(height: 14),
        ],
        _CarrierSection(
          title: '운송사 배차',
          action: TextButton(onPressed: onDispatchTap, child: const Text('전체')),
          child: _SelectedDispatchCard(
            assignment: selectedAssignment,
            vehicle: selectedVehicle,
            busy: busy,
            onConfirmDispatch: onConfirmDispatch,
            onFleetTap: onFleetTap,
          ),
        ),
        const SizedBox(height: 14),
        _CarrierSection(
          title: '알림',
          child: Column(
            children: [
              _AlertTile(
                icon: Icons.business_center_rounded,
                title: '${selectedAssignment.planNo} 위탁 배정 접수',
                detail:
                    '${selectedAssignment.routeName} · ${selectedAssignment.timeWindow}',
                time: '방금',
                color: AppTheme.cyan,
              ),
              const Divider(height: 1, color: AppTheme.line),
              const _AlertTile(
                icon: Icons.receipt_long_rounded,
                title: '매입 정산 예정',
                detail: '오늘 확정 건은 익일 정산 후보로 반영됩니다.',
                time: '10분 전',
                color: AppTheme.teal,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CarrierDispatchScreen extends StatelessWidget {
  const _CarrierDispatchScreen({
    required this.assignments,
    required this.selectedAssignment,
    required this.selectedVehicleId,
    required this.busy,
    required this.onAssignmentSelected,
    required this.onVehicleSelected,
    required this.onConfirmDispatch,
  });

  final List<_CarrierAssignment> assignments;
  final _CarrierAssignment selectedAssignment;
  final int selectedVehicleId;
  final bool busy;
  final ValueChanged<_CarrierAssignment> onAssignmentSelected;
  final ValueChanged<int> onVehicleSelected;
  final Future<void> Function() onConfirmDispatch;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CarrierHeader(
          title: '운송사 배차',
          subtitle: 'CJ대한통운 위탁 배정',
          trailing: _StatusPill(
            icon: Icons.assignment_turned_in_rounded,
            label: selectedAssignment.statusLabel,
            color: selectedAssignment.statusColor,
          ),
        ),
        const SizedBox(height: 14),
        _CarrierSection(
          title: '배정 목록',
          child: Column(
            children: [
              for (final assignment in assignments) ...[
                _AssignmentTile(
                  assignment: assignment,
                  selected: assignment.id == selectedAssignment.id,
                  onTap: () => onAssignmentSelected(assignment),
                ),
                if (assignment != assignments.last)
                  const Divider(height: 1, color: AppTheme.line),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        _CarrierSection(
          title: '자사 차량 선택',
          child: Column(
            children: [
              for (final vehicle in _seedCarrierVehicles) ...[
                _VehicleChoiceTile(
                  vehicle: vehicle,
                  selected: vehicle.id == selectedVehicleId,
                  onTap: vehicle.available
                      ? () => onVehicleSelected(vehicle.id)
                      : null,
                ),
                if (vehicle != _seedCarrierVehicles.last)
                  const Divider(height: 1, color: AppTheme.line),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        _CarrierSection(
          title: '확정',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _InfoRow(label: '배정번호', value: selectedAssignment.tenderNo),
              _InfoRow(label: '상차', value: selectedAssignment.pickupName),
              _InfoRow(label: '하차', value: selectedAssignment.deliveryName),
              _InfoRow(label: '운임', value: selectedAssignment.amountLabel),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: busy ? null : onConfirmDispatch,
                icon: busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.task_alt_rounded),
                label: Text(busy ? '저장 중' : '배차 확정'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CarrierFleetScreen extends StatelessWidget {
  const _CarrierFleetScreen();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CarrierHeader(
          title: '자사 차량',
          subtitle: 'CJ대한통운 차량/기사',
          trailing: _StatusPill(
            icon: Icons.local_shipping_rounded,
            label: '6대',
            color: AppTheme.cyan,
          ),
        ),
        SizedBox(height: 14),
        _CarrierSection(
          title: '가용 차량',
          child: Column(
            children: [
              _FleetTile(
                vehicle: _CarrierVehicle(
                  id: 101,
                  vehicleCode: 'CJC-4402',
                  vehicleNo: '경기91사4402',
                  vehicleType: '11톤 윙바디',
                  driverCode: 'CJD-001',
                  driverName: '박민준',
                  driverPhone: '010-4402-1911',
                  driverEmail: 'minjun.park@cjlogistics.example',
                  statusCode: 'AVAILABLE',
                  location: '수원 11km',
                  maxWeightKg: 11000,
                  temperatureControlled: false,
                  complianceScore: 96,
                ),
              ),
              Divider(height: 1, color: AppTheme.line),
              _FleetTile(
                vehicle: _CarrierVehicle(
                  id: 102,
                  vehicleCode: 'CJC-0931',
                  vehicleNo: '인천77아0931',
                  vehicleType: '5톤 윙바디',
                  driverCode: 'CJD-002',
                  driverName: '이서진',
                  driverPhone: '010-0931-7700',
                  driverEmail: 'seojin.lee@cjlogistics.example',
                  statusCode: 'RETURNING',
                  location: '이천 복귀',
                  maxWeightKg: 5000,
                  temperatureControlled: false,
                  complianceScore: 94,
                ),
              ),
              Divider(height: 1, color: AppTheme.line),
              _FleetTile(
                vehicle: _CarrierVehicle(
                  id: 103,
                  vehicleCode: 'CJC-8120',
                  vehicleNo: '부산65자8120',
                  vehicleType: '5톤 냉동탑',
                  driverCode: 'CJD-003',
                  driverName: '최현우',
                  driverPhone: '010-8120-6500',
                  driverEmail: 'hyunwoo.choi@cjlogistics.example',
                  statusCode: 'AVAILABLE',
                  location: '용인 24km',
                  maxWeightKg: 5000,
                  temperatureControlled: true,
                  complianceScore: 91,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 14),
        _CarrierSection(
          title: '기사 앱',
          child: Column(
            children: [
              _InfoRow(label: '설치', value: '5명'),
              _InfoRow(label: '미설치', value: '1명'),
              _InfoRow(label: '알림 수신', value: '정상'),
            ],
          ),
        ),
      ],
    );
  }
}

class _CarrierAlertScreen extends StatelessWidget {
  const _CarrierAlertScreen({
    required this.waitingCount,
    required this.onDispatchTap,
  });

  final int waitingCount;
  final VoidCallback onDispatchTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CarrierHeader(
          title: '알림',
          subtitle: '위탁 배정, 배차, 정산',
          trailing: _StatusPill(
            icon: Icons.notifications_rounded,
            label: '$waitingCount건',
            color: AppTheme.amber,
          ),
        ),
        const SizedBox(height: 14),
        _CarrierSection(
          title: '오늘',
          action: TextButton(onPressed: onDispatchTap, child: const Text('배차')),
          child: const Column(
            children: [
              _AlertTile(
                icon: Icons.assignment_late_rounded,
                title: 'LP-20260616-004 배차 확정 필요',
                detail: '용인 냉동창고 → 부산 냉동센터 · 마감 14:30',
                time: '방금',
                color: AppTheme.amber,
              ),
              Divider(height: 1, color: AppTheme.line),
              _AlertTile(
                icon: Icons.local_shipping_rounded,
                title: '차량 가용성 확인',
                detail: '경기91사4402 차량이 추천되었습니다.',
                time: '5분 전',
                color: AppTheme.cyan,
              ),
              Divider(height: 1, color: AppTheme.line),
              _AlertTile(
                icon: Icons.receipt_long_rounded,
                title: '정산 후보 생성',
                detail: '배차 확정 후 매입 정산 후보로 반영됩니다.',
                time: '예약',
                color: AppTheme.teal,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CarrierSettlementScreen extends StatelessWidget {
  const _CarrierSettlementScreen({required this.carrierName});

  final String carrierName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CarrierHeader(
          title: '정산',
          subtitle: '$carrierName 매입 정산',
          trailing: _StatusPill(
            icon: Icons.receipt_long_rounded,
            label: '예정',
            color: AppTheme.teal,
          ),
        ),
        const SizedBox(height: 14),
        const _CarrierSection(
          title: '이번 주',
          child: Column(
            children: [
              _InfoRow(label: '확정 운임', value: '3,280,000원'),
              _InfoRow(label: '대기 건수', value: '2건'),
              _InfoRow(label: '지급 예정', value: '2026-06-19'),
              _InfoRow(label: 'POD 누락', value: '0건'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const _CarrierSection(
          title: '정산 목록',
          child: Column(
            children: [
              _SettlementTile(
                title: 'LP-20260616-004',
                detail: '용인 냉동창고 → 부산 냉동센터',
                amount: '1,510,000원',
                status: '확정대기',
              ),
              Divider(height: 1, color: AppTheme.line),
              _SettlementTile(
                title: 'LP-20260616-005',
                detail: '김포 콜드체인 → 서울 동부센터',
                amount: '1,420,000원',
                status: '배차대기',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SelectedDispatchCard extends StatelessWidget {
  const _SelectedDispatchCard({
    required this.assignment,
    required this.vehicle,
    required this.busy,
    required this.onConfirmDispatch,
    required this.onFleetTap,
  });

  final _CarrierAssignment assignment;
  final _CarrierVehicle vehicle;
  final bool busy;
  final Future<void> Function() onConfirmDispatch;
  final VoidCallback onFleetTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.graphite,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.business_center_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        assignment.planNo,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        assignment.routeName,
                        style: const TextStyle(
                          color: Color(0xFFCBD5E1),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                _DarkPill(label: assignment.amountLabel),
              ],
            ),
            const SizedBox(height: 16),
            _DarkInfoRow(label: '자사 차량', value: vehicle.vehicleNo),
            _DarkInfoRow(label: '기사', value: vehicle.driverName),
            _DarkInfoRow(label: '마감', value: assignment.confirmDeadline),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onFleetTap,
                    icon: const Icon(Icons.local_shipping_rounded),
                    label: const Text('차량 보기'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: busy ? null : onConfirmDispatch,
                    icon: busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.task_alt_rounded),
                    label: Text(busy ? '저장 중' : '배차 확정'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF67E8F9),
                      foregroundColor: AppTheme.graphite,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CarrierHeader extends StatelessWidget {
  const _CarrierHeader({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.graphite,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.slate,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ],
    );
  }
}

class _CarrierSection extends StatelessWidget {
  const _CarrierSection({
    required this.title,
    required this.child,
    this.action,
  });

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppTheme.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.graphite,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                ?action,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppTheme.slate,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.graphite,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  Text(
                    detail,
                    style: const TextStyle(
                      color: AppTheme.muted,
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
    );
  }
}

class _AssignmentTile extends StatelessWidget {
  const _AssignmentTile({
    required this.assignment,
    required this.selected,
    required this.onTap,
  });

  final _CarrierAssignment assignment;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      selected: selected,
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: selected
            ? assignment.statusColor.withValues(alpha: 0.14)
            : AppTheme.panel,
        foregroundColor: assignment.statusColor,
        child: Icon(assignment.statusIcon),
      ),
      title: Text(
        assignment.planNo,
        style: const TextStyle(
          color: AppTheme.graphite,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
      subtitle: Text('${assignment.routeName} · ${assignment.timeWindow}'),
      trailing: _StatusPill(
        icon: assignment.statusIcon,
        label: assignment.statusLabel,
        color: assignment.statusColor,
      ),
    );
  }
}

class _VehicleChoiceTile extends StatelessWidget {
  const _VehicleChoiceTile({
    required this.vehicle,
    required this.selected,
    required this.onTap,
  });

  final _CarrierVehicle vehicle;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: enabled,
      selected: selected,
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: selected
            ? AppTheme.teal.withValues(alpha: 0.14)
            : AppTheme.panel,
        foregroundColor: selected ? AppTheme.teal : AppTheme.slate,
        child: Icon(
          selected
              ? Icons.radio_button_checked_rounded
              : Icons.local_shipping_rounded,
        ),
      ),
      title: Text(
        vehicle.vehicleNo,
        style: const TextStyle(
          color: AppTheme.graphite,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
      subtitle: Text(
        '${vehicle.vehicleType} · ${vehicle.driverName} · ${vehicle.location}',
      ),
      trailing: _StatusPill(
        icon: vehicle.available
            ? Icons.check_circle_rounded
            : Icons.keyboard_return_rounded,
        label: vehicle.statusLabel,
        color: vehicle.statusColor,
      ),
    );
  }
}

class _FleetTile extends StatelessWidget {
  const _FleetTile({required this.vehicle});

  final _CarrierVehicle vehicle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: vehicle.statusColor.withValues(alpha: 0.1),
        foregroundColor: vehicle.statusColor,
        child: const Icon(Icons.local_shipping_rounded),
      ),
      title: Text(
        vehicle.vehicleNo,
        style: const TextStyle(
          color: AppTheme.graphite,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
      subtitle: Text(
        '${vehicle.vehicleType} · ${vehicle.driverName} · ${vehicle.location}',
      ),
      trailing: _StatusPill(
        icon: Icons.verified_rounded,
        label: '${vehicle.complianceScore}점',
        color: vehicle.statusColor,
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({
    required this.icon,
    required this.title,
    required this.detail,
    required this.time,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String detail;
  final String time;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.1),
        foregroundColor: color,
        child: Icon(icon),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: AppTheme.graphite,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
      subtitle: Text(detail),
      trailing: Text(
        time,
        style: const TextStyle(
          color: AppTheme.muted,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _SettlementTile extends StatelessWidget {
  const _SettlementTile({
    required this.title,
    required this.detail,
    required this.amount,
    required this.status,
  });

  final String title;
  final String detail;
  final String amount;
  final String status;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(
        backgroundColor: Color(0xFFE0F2FE),
        foregroundColor: AppTheme.cyan,
        child: Icon(Icons.receipt_long_rounded),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: AppTheme.graphite,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
      subtitle: Text(detail),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            amount,
            style: const TextStyle(
              color: AppTheme.graphite,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          Text(
            status,
            style: const TextStyle(
              color: AppTheme.muted,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.result});

  final _CarrierDispatchResult result;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: AppTheme.teal.withValues(alpha: 0.1),
        foregroundColor: AppTheme.teal,
        child: const Icon(Icons.task_alt_rounded),
      ),
      title: Text(
        '${result.planNo} 배차 확정',
        style: const TextStyle(
          color: AppTheme.graphite,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
      subtitle: Text('${result.vehicleNo} · ${result.driverName}'),
      trailing: _StatusPill(
        icon: result.persisted
            ? Icons.cloud_done_rounded
            : Icons.cloud_off_rounded,
        label: result.persisted ? '저장' : '대기',
        color: result.persisted ? AppTheme.teal : AppTheme.amber,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.slate,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
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

class _DarkInfoRow extends StatelessWidget {
  const _DarkInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFFCBD5E1),
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DarkPill extends StatelessWidget {
  const _DarkPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _CarrierDispatchResult {
  const _CarrierDispatchResult({
    required this.planNo,
    required this.vehicleNo,
    required this.driverName,
    required this.persisted,
  });

  final String planNo;
  final String vehicleNo;
  final String driverName;
  final bool persisted;
}

class _CarrierAssignment {
  const _CarrierAssignment({
    required this.id,
    required this.tenderNo,
    required this.planNo,
    required this.customerName,
    required this.routeName,
    required this.pickupName,
    required this.deliveryName,
    required this.pickupWindow,
    required this.deliveryWindow,
    required this.timeWindow,
    required this.confirmDeadline,
    required this.cargoSummary,
    required this.weightKg,
    required this.volumeCbm,
    required this.offeredAmount,
    required this.statusCode,
    required this.latitude,
    required this.longitude,
    this.confirmedVehicleNo,
    this.confirmedDriverName,
  });

  final int id;
  final String tenderNo;
  final String planNo;
  final String customerName;
  final String routeName;
  final String pickupName;
  final String deliveryName;
  final String pickupWindow;
  final String deliveryWindow;
  final String timeWindow;
  final String confirmDeadline;
  final String cargoSummary;
  final double weightKg;
  final double volumeCbm;
  final int offeredAmount;
  final String statusCode;
  final double latitude;
  final double longitude;
  final String? confirmedVehicleNo;
  final String? confirmedDriverName;

  bool get isConfirmed => statusCode == 'DISPATCH_CONFIRMED';

  String get amountLabel => '${(offeredAmount / 10000).round()}만원';

  String get statusLabel => switch (statusCode) {
    'DISPATCH_CONFIRMED' => '배차확정',
    'VIEWED' => '확인',
    _ => '배차대기',
  };

  Color get statusColor => switch (statusCode) {
    'DISPATCH_CONFIRMED' => AppTheme.teal,
    'VIEWED' => AppTheme.cyan,
    _ => AppTheme.amber,
  };

  IconData get statusIcon => switch (statusCode) {
    'DISPATCH_CONFIRMED' => Icons.task_alt_rounded,
    'VIEWED' => Icons.visibility_rounded,
    _ => Icons.assignment_late_rounded,
  };

  _CarrierAssignment copyWith({
    String? statusCode,
    String? confirmedVehicleNo,
    String? confirmedDriverName,
  }) {
    return _CarrierAssignment(
      id: id,
      tenderNo: tenderNo,
      planNo: planNo,
      customerName: customerName,
      routeName: routeName,
      pickupName: pickupName,
      deliveryName: deliveryName,
      pickupWindow: pickupWindow,
      deliveryWindow: deliveryWindow,
      timeWindow: timeWindow,
      confirmDeadline: confirmDeadline,
      cargoSummary: cargoSummary,
      weightKg: weightKg,
      volumeCbm: volumeCbm,
      offeredAmount: offeredAmount,
      statusCode: statusCode ?? this.statusCode,
      latitude: latitude,
      longitude: longitude,
      confirmedVehicleNo: confirmedVehicleNo ?? this.confirmedVehicleNo,
      confirmedDriverName: confirmedDriverName ?? this.confirmedDriverName,
    );
  }
}

class _CarrierVehicle {
  const _CarrierVehicle({
    required this.id,
    required this.vehicleCode,
    required this.vehicleNo,
    required this.vehicleType,
    required this.driverCode,
    required this.driverName,
    required this.driverPhone,
    required this.driverEmail,
    required this.statusCode,
    required this.location,
    required this.maxWeightKg,
    required this.temperatureControlled,
    required this.complianceScore,
  });

  final int id;
  final String vehicleCode;
  final String vehicleNo;
  final String vehicleType;
  final String driverCode;
  final String driverName;
  final String driverPhone;
  final String driverEmail;
  final String statusCode;
  final String location;
  final double maxWeightKg;
  final bool temperatureControlled;
  final int complianceScore;

  bool get available => statusCode == 'AVAILABLE';

  String get statusLabel => switch (statusCode) {
    'AVAILABLE' => '배차 가능',
    'RETURNING' => '복귀 중',
    _ => '점검',
  };

  Color get statusColor => switch (statusCode) {
    'AVAILABLE' => AppTheme.teal,
    'RETURNING' => AppTheme.cyan,
    _ => AppTheme.amber,
  };

  Map<String, Object?> toVehiclePayload(String carrierName, String planNo) {
    return {
      'vehicle_code': vehicleCode,
      'plate_no': vehicleNo,
      'carrier_name': carrierName,
      'vehicle_type': vehicleType,
      'driver_name': driverName,
      'tonnage': vehicleType.contains('11톤') ? '11톤' : '5톤',
      'fuel_type': 'DIESEL',
      'home_yard': location,
      'max_weight_kg': maxWeightKg,
      'max_volume_cbm': vehicleType.contains('11톤') ? 48 : 32,
      'temperature_controlled': temperatureControlled,
      'gps_enabled': true,
      'status': 'AVAILABLE',
      'is_active': true,
      'metadata': {
        'source': 'ktms_carrier',
        'driver_code': driverCode,
        'driver_email': driverEmail,
        'tracking_plan_no': planNo,
      },
    };
  }

  Map<String, Object?> toDriverPayload(String carrierName) {
    return {
      'driver_code': driverCode,
      'driver_name': driverName,
      'carrier_name': carrierName,
      'phone': driverPhone,
      'email': driverEmail,
      'license_type': vehicleType.contains('11톤') ? 'LARGE' : 'FIRST_CLASS',
      'license_expiry_date': '2027-05-31',
      'status': 'ACTIVE',
      'is_active': true,
      'metadata': {'source': 'ktms_carrier', 'assigned_vehicle_no': vehicleNo},
    };
  }
}

const _seedCarrierAssignments = [
  _CarrierAssignment(
    id: 1,
    tenderNo: 'CT-20260616-004',
    planNo: 'LP-20260616-004',
    customerName: '콜드프라임',
    routeName: '용인 냉동창고 → 부산 냉동센터',
    pickupName: '용인 냉동창고',
    deliveryName: '부산 냉동센터',
    pickupWindow: '15:00-17:00',
    deliveryWindow: '23:00-02:00',
    timeWindow: '15:00-02:00',
    confirmDeadline: '14:30',
    cargoSummary: '냉동식품 · 냉동',
    weightKg: 1760,
    volumeCbm: 14.3,
    offeredAmount: 1510000,
    statusCode: 'SENT',
    latitude: 37.2411,
    longitude: 127.1776,
  ),
  _CarrierAssignment(
    id: 2,
    tenderNo: 'CT-20260616-005',
    planNo: 'LP-20260616-005',
    customerName: '프레시온',
    routeName: '김포 콜드체인 → 서울 동부센터',
    pickupName: '김포 콜드체인',
    deliveryName: '서울 동부센터',
    pickupWindow: '06:00-08:00',
    deliveryWindow: '10:00-14:00',
    timeWindow: '06:00-14:00',
    confirmDeadline: '05:30',
    cargoSummary: '냉장식품 · 냉장',
    weightKg: 3920,
    volumeCbm: 29.1,
    offeredAmount: 1420000,
    statusCode: 'VIEWED',
    latitude: 37.6128,
    longitude: 126.8067,
  ),
];

const _seedCarrierVehicles = [
  _CarrierVehicle(
    id: 101,
    vehicleCode: 'CJC-4402',
    vehicleNo: '경기91사4402',
    vehicleType: '11톤 윙바디',
    driverCode: 'CJD-001',
    driverName: '박민준',
    driverPhone: '010-4402-1911',
    driverEmail: 'minjun.park@cjlogistics.example',
    statusCode: 'AVAILABLE',
    location: '수원 11km',
    maxWeightKg: 11000,
    temperatureControlled: false,
    complianceScore: 96,
  ),
  _CarrierVehicle(
    id: 102,
    vehicleCode: 'CJC-0931',
    vehicleNo: '인천77아0931',
    vehicleType: '5톤 윙바디',
    driverCode: 'CJD-002',
    driverName: '이서진',
    driverPhone: '010-0931-7700',
    driverEmail: 'seojin.lee@cjlogistics.example',
    statusCode: 'RETURNING',
    location: '이천 복귀',
    maxWeightKg: 5000,
    temperatureControlled: false,
    complianceScore: 94,
  ),
  _CarrierVehicle(
    id: 103,
    vehicleCode: 'CJC-8120',
    vehicleNo: '부산65자8120',
    vehicleType: '5톤 냉동탑',
    driverCode: 'CJD-003',
    driverName: '최현우',
    driverPhone: '010-8120-6500',
    driverEmail: 'hyunwoo.choi@cjlogistics.example',
    statusCode: 'AVAILABLE',
    location: '용인 24km',
    maxWeightKg: 5000,
    temperatureControlled: true,
    complianceScore: 91,
  ),
];
