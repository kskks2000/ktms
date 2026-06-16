import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../design/app_theme.dart';
import '../../design/ktms_mark.dart';
import '../tms/master_api.dart';

class DriverHomePage extends StatefulWidget {
  const DriverHomePage({
    required this.displayName,
    required this.email,
    required this.onSignOut,
    super.key,
  });

  final String displayName;
  final String email;
  final VoidCallback onSignOut;

  @override
  State<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends State<DriverHomePage> {
  int _selectedIndex = 0;
  double _progress = 0.84;
  int _etaMinutes = 63;
  String _lastSignal = '방금 전';
  bool _onDuty = true;

  Future<void> _syncGps() async {
    final nextProgress = math.min(1.0, _progress + 0.04);
    final position = _positionAlongRoute(nextProgress);
    final nextEta = math.max(0, _etaMinutes - 5);

    setState(() {
      _progress = nextProgress;
      _etaMinutes = nextEta;
      _lastSignal = '방금 전';
    });

    final result = await MasterApi.instance.saveTrackingPosition({
      'vehicle_no': '서울 82바 1724',
      'driver_name': '김도윤',
      'plan_no': 'LP-20260616-001',
      'status_label': nextProgress >= 0.96 ? '도착예정' : '운송중',
      'eta_label': _etaLabel(nextEta),
      'progress': nextProgress.toStringAsFixed(4),
      'latitude': position.latitude,
      'longitude': position.longitude,
      'speed_kph': 74,
      'heading_degree': position.headingDegree,
      'location_text': '수원 CDC → 부산 RDC',
      'notes': '기사 앱 GPS 갱신',
      'metadata': {
        'app': 'ktms_driver',
        'driver_email': widget.email,
        'route': '수원 CDC → 부산 RDC',
      },
    });

    if (!mounted) {
      return;
    }

    final message = result.persisted
        ? 'GPS 위치가 DB에 저장되었습니다.'
        : 'GPS 위치는 갱신됐지만 DB 저장을 확인하지 못했습니다.';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _toggleDuty(bool value) {
    setState(() => _onDuty = value);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(value ? '운행 가능 상태입니다.' : '휴식 상태입니다.')),
      );
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
                'KTMS Driver',
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
            icon: const Badge(
              label: Text('3'),
              child: Icon(Icons.notifications_none_rounded),
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
        child: _DriverWorkspace(
          selectedIndex: _selectedIndex,
          compact: compact,
          displayName: widget.displayName,
          email: widget.email,
          progress: _progress,
          etaMinutes: _etaMinutes,
          lastSignal: _lastSignal,
          onDuty: _onDuty,
          onDutyChanged: _toggleDuty,
          onSyncGps: _syncGps,
          onSelect: (index) => setState(() => _selectedIndex = index),
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
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route_rounded),
            label: '운행',
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
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: '내정보',
          ),
        ],
      ),
    );
  }
}

class _DriverWorkspace extends StatelessWidget {
  const _DriverWorkspace({
    required this.selectedIndex,
    required this.compact,
    required this.displayName,
    required this.email,
    required this.progress,
    required this.etaMinutes,
    required this.lastSignal,
    required this.onDuty,
    required this.onDutyChanged,
    required this.onSyncGps,
    required this.onSelect,
  });

  final int selectedIndex;
  final bool compact;
  final String displayName;
  final String email;
  final double progress;
  final int etaMinutes;
  final String lastSignal;
  final bool onDuty;
  final ValueChanged<bool> onDutyChanged;
  final Future<void> Function() onSyncGps;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final padding = compact
        ? const EdgeInsets.fromLTRB(16, 14, 16, 18)
        : const EdgeInsets.fromLTRB(28, 22, 28, 26);

    return SingleChildScrollView(
      padding: padding,
      child: switch (selectedIndex) {
        1 => _DriverRouteScreen(
          progress: progress,
          etaMinutes: etaMinutes,
          lastSignal: lastSignal,
          onSyncGps: onSyncGps,
        ),
        2 => const _DriverVehicleScreen(),
        3 => const _DriverNotificationScreen(),
        4 => _DriverProfileScreen(
          displayName: displayName,
          email: email,
          onDuty: onDuty,
          onDutyChanged: onDutyChanged,
        ),
        _ => _DriverDashboard(
          displayName: displayName,
          progress: progress,
          etaMinutes: etaMinutes,
          lastSignal: lastSignal,
          onSyncGps: onSyncGps,
          onSelect: onSelect,
        ),
      },
    );
  }
}

class _DriverDashboard extends StatelessWidget {
  const _DriverDashboard({
    required this.displayName,
    required this.progress,
    required this.etaMinutes,
    required this.lastSignal,
    required this.onSyncGps,
    required this.onSelect,
  });

  final String displayName;
  final double progress;
  final int etaMinutes;
  final String lastSignal;
  final Future<void> Function() onSyncGps;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DriverHeader(
          title: '김도윤 기사님',
          subtitle: '서울82바1724 · LP-20260616-001',
          trailing: _StatusPill(
            icon: Icons.sensors_rounded,
            label: 'GPS $lastSignal',
            color: AppTheme.teal,
          ),
        ),
        const SizedBox(height: 14),
        _TripHeroCard(
          progress: progress,
          etaMinutes: etaMinutes,
          onSyncGps: onSyncGps,
          onRouteTap: () => onSelect(1),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 720;
            final cards = [
              _QuickStatusCard(
                icon: Icons.inventory_2_rounded,
                title: '전자부품',
                value: '825.6 kg',
                detail: '상온 · 12.4 CBM',
                color: AppTheme.cyan,
              ),
              _QuickStatusCard(
                icon: Icons.access_time_filled_rounded,
                title: 'ETA',
                value: _etaLabel(etaMinutes),
                detail: '부산 RDC 도착 예정',
                color: AppTheme.amber,
              ),
              _QuickStatusCard(
                icon: Icons.assignment_turned_in_rounded,
                title: 'POD',
                value: '대기',
                detail: '도착 후 서명/사진 등록',
                color: AppTheme.teal,
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
        _DriverSection(
          title: '알림',
          action: TextButton(
            onPressed: () => onSelect(3),
            child: const Text('전체'),
          ),
          child: const Column(
            children: [
              _NotificationTile(
                icon: Icons.warning_amber_rounded,
                title: '부산권 진입 전 도착 예정 알림',
                detail: '고객사 자동 알림 후보입니다.',
                time: '10분 전',
                color: AppTheme.amber,
              ),
              Divider(height: 1, color: AppTheme.line),
              _NotificationTile(
                icon: Icons.local_shipping_rounded,
                title: '차량 마스터 연결 완료',
                detail: '서울82바1724 차량 기준으로 GPS가 저장됩니다.',
                time: '방금',
                color: AppTheme.teal,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DriverRouteScreen extends StatelessWidget {
  const _DriverRouteScreen({
    required this.progress,
    required this.etaMinutes,
    required this.lastSignal,
    required this.onSyncGps,
  });

  final double progress;
  final int etaMinutes;
  final String lastSignal;
  final Future<void> Function() onSyncGps;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DriverHeader(
          title: '운행 상세',
          subtitle: '수원 CDC → 옥천 HUB → 부산 RDC',
          trailing: _StatusPill(
            icon: Icons.route_rounded,
            label: '${(progress * 100).round()}%',
            color: AppTheme.cyan,
          ),
        ),
        const SizedBox(height: 14),
        _DriverSection(
          title: '현재 운송',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _RouteProgress(progress: progress),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _MetricPill(
                      label: '도착 예정',
                      value: _etaLabel(etaMinutes),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricPill(label: 'GPS', value: lastSignal),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: onSyncGps,
                icon: const Icon(Icons.my_location_rounded),
                label: const Text('GPS 갱신'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const _DriverSection(
          title: '경유지',
          child: Column(
            children: [
              _StopTile(
                sequence: '1',
                title: '수원 CDC',
                subtitle: '출발 완료 · 09:12',
                done: true,
              ),
              _StopTile(
                sequence: '2',
                title: '옥천 HUB',
                subtitle: '통과 완료 · 12:48',
                done: true,
              ),
              _StopTile(
                sequence: '3',
                title: '부산 RDC',
                subtitle: '도착 예정 · 18:00',
                done: false,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _DriverSection(
          title: '도착 처리',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.photo_camera_rounded),
                label: const Text('POD 사진 등록'),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.draw_rounded),
                label: const Text('수령 서명 받기'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DriverVehicleScreen extends StatelessWidget {
  const _DriverVehicleScreen();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DriverHeader(
          title: '내 차량',
          subtitle: '서울82바1724 · 5톤 윙바디',
          trailing: _StatusPill(
            icon: Icons.verified_rounded,
            label: '정상',
            color: AppTheme.teal,
          ),
        ),
        SizedBox(height: 14),
        _DriverSection(
          title: '차량 상태',
          child: Column(
            children: [
              _VehicleInfoRow(label: '차량번호', value: '서울82바1724'),
              _VehicleInfoRow(label: '차량코드', value: 'VEH-WB1724'),
              _VehicleInfoRow(label: '톤급/차종', value: '5톤 · 윙바디'),
              _VehicleInfoRow(label: '차고지', value: '수원 CDC'),
              _VehicleInfoRow(label: 'GPS 추적', value: '사용'),
            ],
          ),
        ),
        SizedBox(height: 14),
        _DriverSection(
          title: '점검',
          child: Column(
            children: [
              _InspectionTile(
                title: '타이어/브레이크',
                detail: '운행 전 점검 완료',
                status: '정상',
                color: AppTheme.teal,
              ),
              Divider(height: 1, color: AppTheme.line),
              _InspectionTile(
                title: '연료',
                detail: '디젤 · 예상 잔여 62%',
                status: '확인',
                color: AppTheme.cyan,
              ),
              Divider(height: 1, color: AppTheme.line),
              _InspectionTile(
                title: '보험/검사',
                detail: '검사 만료 2027-05-31',
                status: '유효',
                color: AppTheme.teal,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DriverNotificationScreen extends StatelessWidget {
  const _DriverNotificationScreen();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DriverHeader(
          title: '알림',
          subtitle: '운행, 도착, 차량 상태 알림',
          trailing: _StatusPill(
            icon: Icons.notifications_rounded,
            label: '3건',
            color: AppTheme.amber,
          ),
        ),
        SizedBox(height: 14),
        _DriverSection(
          title: '오늘',
          child: Column(
            children: [
              _NotificationTile(
                icon: Icons.route_rounded,
                title: '부산 RDC 도착 예정',
                detail: 'ETA 1시간 03분, 정상 운행 중입니다.',
                time: '방금',
                color: AppTheme.teal,
              ),
              Divider(height: 1, color: AppTheme.line),
              _NotificationTile(
                icon: Icons.assignment_rounded,
                title: 'POD 등록 필요',
                detail: '도착 후 사진과 수령 서명을 등록하세요.',
                time: '예약',
                color: AppTheme.cyan,
              ),
              Divider(height: 1, color: AppTheme.line),
              _NotificationTile(
                icon: Icons.warning_amber_rounded,
                title: '고객 도착 알림 후보',
                detail: '부산권 진입 시 자동 알림이 생성됩니다.',
                time: '10분 전',
                color: AppTheme.amber,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DriverProfileScreen extends StatelessWidget {
  const _DriverProfileScreen({
    required this.displayName,
    required this.email,
    required this.onDuty,
    required this.onDutyChanged,
  });

  final String displayName;
  final String email;
  final bool onDuty;
  final ValueChanged<bool> onDutyChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DriverHeader(
          title: '내정보',
          subtitle: email,
          trailing: Switch(value: onDuty, onChanged: onDutyChanged),
        ),
        const SizedBox(height: 14),
        _DriverSection(
          title: '기사 정보',
          child: Column(
            children: [
              _VehicleInfoRow(label: '기사명', value: displayName),
              const _VehicleInfoRow(label: '휴대폰', value: '010-4826-1724'),
              const _VehicleInfoRow(label: '면허', value: '1종 대형 · 유효'),
              const _VehicleInfoRow(label: '배정 차량', value: '서울82바1724'),
              _VehicleInfoRow(label: '운행 상태', value: onDuty ? '운행 가능' : '휴식'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const _DriverSection(
          title: '오늘 실적',
          child: Column(
            children: [
              _VehicleInfoRow(label: '운행 건수', value: '1건'),
              _VehicleInfoRow(label: '주행 거리', value: '390 km'),
              _VehicleInfoRow(label: 'GPS 전송', value: '3건'),
            ],
          ),
        ),
      ],
    );
  }
}

class _DriverHeader extends StatelessWidget {
  const _DriverHeader({
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

class _TripHeroCard extends StatelessWidget {
  const _TripHeroCard({
    required this.progress,
    required this.etaMinutes,
    required this.onSyncGps,
    required this.onRouteTap,
  });

  final double progress;
  final int etaMinutes;
  final Future<void> Function() onSyncGps;
  final VoidCallback onRouteTap;

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
                    Icons.local_shipping_rounded,
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
                        'LP-20260616-001',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0,
                            ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '수원 CDC → 부산 RDC',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFFCBD5E1),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                _DarkPill(label: _etaLabel(etaMinutes)),
              ],
            ),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 9,
                backgroundColor: Colors.white.withValues(alpha: 0.16),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF67E8F9),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '진행률 ${(progress * 100).round()}%',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFFE2E8F0),
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onRouteTap,
                    icon: const Icon(Icons.route_rounded),
                    label: const Text('운행 보기'),
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
                    onPressed: onSyncGps,
                    icon: const Icon(Icons.my_location_rounded),
                    label: const Text('GPS 갱신'),
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

class _DriverSection extends StatelessWidget {
  const _DriverSection({required this.title, required this.child, this.action});

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.line),
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

class _QuickStatusCard extends StatelessWidget {
  const _QuickStatusCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.detail,
    required this.color,
  });

  final IconData icon;
  final String title;
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
                    title,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
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

class _RouteProgress extends StatelessWidget {
  const _RouteProgress({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final stops = ['수원 CDC', '옥천 HUB', '부산 RDC'];
    return Column(
      children: [
        Row(
          children: [
            for (var index = 0; index < stops.length; index += 1) ...[
              _RouteStopDot(done: progress >= (index / (stops.length - 1))),
              if (index != stops.length - 1)
                Expanded(
                  child: Container(
                    height: 4,
                    color: progress >= ((index + 1) / (stops.length - 1))
                        ? AppTheme.teal
                        : AppTheme.line,
                  ),
                ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: stops
              .map(
                (stop) => Text(
                  stop,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.slate,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _RouteStopDot extends StatelessWidget {
  const _RouteStopDot({required this.done});

  final bool done;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: done ? AppTheme.teal : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: done ? AppTheme.teal : AppTheme.line,
          width: 2,
        ),
      ),
      child: done
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
          : null,
    );
  }
}

class _StopTile extends StatelessWidget {
  const _StopTile({
    required this.sequence,
    required this.title,
    required this.subtitle,
    required this.done,
  });

  final String sequence;
  final String title;
  final String subtitle;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: done ? AppTheme.teal : AppTheme.line,
        foregroundColor: done ? Colors.white : AppTheme.slate,
        child: Text(sequence),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: AppTheme.graphite,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: Icon(
        done
            ? Icons.check_circle_rounded
            : Icons.radio_button_unchecked_rounded,
        color: done ? AppTheme.teal : AppTheme.muted,
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
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

class _VehicleInfoRow extends StatelessWidget {
  const _VehicleInfoRow({required this.label, required this.value});

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

class _InspectionTile extends StatelessWidget {
  const _InspectionTile({
    required this.title,
    required this.detail,
    required this.status,
    required this.color,
  });

  final String title;
  final String detail;
  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: const TextStyle(
          color: AppTheme.graphite,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
      subtitle: Text(detail),
      trailing: _StatusPill(
        icon: Icons.verified_rounded,
        label: status,
        color: color,
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
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
            const SizedBox(height: 3),
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

class _RoutePoint {
  const _RoutePoint({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

class _DriverPosition {
  const _DriverPosition({
    required this.latitude,
    required this.longitude,
    required this.headingDegree,
  });

  final double latitude;
  final double longitude;
  final double headingDegree;
}

_DriverPosition _positionAlongRoute(double progress) {
  const points = [
    _RoutePoint(latitude: 37.2636, longitude: 127.0286),
    _RoutePoint(latitude: 36.3012, longitude: 127.5681),
    _RoutePoint(latitude: 35.1796, longitude: 129.0756),
  ];
  final clampedProgress = progress.clamp(0.0, 1.0);
  var totalDistance = 0.0;
  for (var index = 0; index < points.length - 1; index += 1) {
    totalDistance += _pointDistance(points[index], points[index + 1]);
  }
  var remaining = totalDistance * clampedProgress;
  for (var index = 0; index < points.length - 1; index += 1) {
    final start = points[index];
    final end = points[index + 1];
    final segment = _pointDistance(start, end);
    if (remaining > segment) {
      remaining -= segment;
      continue;
    }
    final ratio = segment == 0 ? 0.0 : remaining / segment;
    return _DriverPosition(
      latitude: start.latitude + (end.latitude - start.latitude) * ratio,
      longitude: start.longitude + (end.longitude - start.longitude) * ratio,
      headingDegree: _headingDegree(start, end),
    );
  }
  return _DriverPosition(
    latitude: points.last.latitude,
    longitude: points.last.longitude,
    headingDegree: _headingDegree(points[points.length - 2], points.last),
  );
}

double _pointDistance(_RoutePoint a, _RoutePoint b) {
  final latitude = a.latitude - b.latitude;
  final longitude = a.longitude - b.longitude;
  return math.sqrt(latitude * latitude + longitude * longitude);
}

double _headingDegree(_RoutePoint start, _RoutePoint end) {
  final radians = math.atan2(
    end.longitude - start.longitude,
    end.latitude - start.latitude,
  );
  final degree = radians * 180 / math.pi;
  return degree < 0 ? degree + 360 : degree;
}

String _etaLabel(int etaMinutes) {
  if (etaMinutes <= 0) {
    return '도착';
  }
  if (etaMinutes >= 60) {
    final hours = etaMinutes ~/ 60;
    final minutes = etaMinutes % 60;
    return minutes == 0 ? '$hours시간' : '$hours시간 $minutes분';
  }
  return '$etaMinutes분';
}
